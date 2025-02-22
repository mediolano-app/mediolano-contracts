#[starknet::contract]
mod IPCrowdfunding {
    use core::{
        array::ArrayTrait, traits::Into,
        starknet::{ContractAddress, get_caller_address, get_block_timestamp, get_contract_address}
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::super::types::{
        Campaign, CampaignStats, MIN_DURATION, MAX_DURATION, ERROR_INVALID_DURATION,
        ERROR_INVALID_GOAL, ERROR_CAMPAIGN_NOT_FOUND, ERROR_CAMPAIGN_ENDED, ERROR_CAMPAIGN_ACTIVE,
        ERROR_ALREADY_WITHDRAWN, ERROR_NOT_CREATOR, ERROR_NO_CONTRIBUTION
    };
    use core::starknet::storage::{
        StoragePointerWriteAccess, StoragePointerReadAccess, StorageMapReadAccess,
        StorageMapWriteAccess
    };
    use super::super::interfaces::IIPCrowdfunding;


    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        campaign_count: u256,
        campaigns: LegacyMap<u256, Campaign>,
        contributions: LegacyMap<(u256, ContractAddress), u256>,
        campaign_stats: LegacyMap<u256, CampaignStats>,
        accepted_token: ContractAddress,
        tokenizer_contract: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CampaignCreated: CampaignCreated,
        ContributionReceived: ContributionReceived,
        FundsWithdrawn: FundsWithdrawn,
        RefundProcessed: RefundProcessed,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    struct CampaignCreated {
        campaign_id: u256,
        creator: ContractAddress,
        asset_id: u256,
        funding_goal: u256,
        duration: u64
    }

    #[derive(Drop, starknet::Event)]
    struct ContributionReceived {
        campaign_id: u256,
        contributor: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct FundsWithdrawn {
        campaign_id: u256,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct RefundProcessed {
        campaign_id: u256,
        contributor: ContractAddress,
        amount: u256
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        accepted_token: ContractAddress,
        tokenizer_contract: ContractAddress
    ) {
        self.ownable.initializer(owner);
        self.accepted_token.write(accepted_token);
        self.tokenizer_contract.write(tokenizer_contract);
        self.campaign_count.write(0);
    }

    #[abi(embed_v0)]
    impl IPCrowdfundingImpl of IIPCrowdfunding<ContractState> {
        // Implementation remains the same as in the previous version
        fn create_campaign(
            ref self: ContractState,
            asset_id: u256,
            funding_goal: u256,
            duration: u64,
            reward_terms: ByteArray
        ) -> u256 {
            self.pausable.assert_not_paused();

            assert(funding_goal > 0, ERROR_INVALID_GOAL);
            assert(duration >= MIN_DURATION && duration <= MAX_DURATION, ERROR_INVALID_DURATION);

            let creator = get_caller_address();
            let start_time = get_block_timestamp();
            let end_time = start_time + duration;

            let campaign_id = self.campaign_count.read() + 1;
            self.campaign_count.write(campaign_id);

            let campaign = Campaign {
                creator,
                asset_id,
                funding_goal,
                total_raised: 0,
                start_time,
                end_time,
                reward_terms,
                is_active: true,
                is_funded: false,
                funds_withdrawn: false
            };

            self.campaigns.write(campaign_id, campaign);

            // Initialize campaign stats
            let stats = CampaignStats {
                total_contributors: 0,
                avg_contribution: 0,
                largest_contribution: 0,
                funding_progress: 0
            };
            self.campaign_stats.write(campaign_id, stats);

            self.emit(CampaignCreated { campaign_id, creator, asset_id, funding_goal, duration });

            campaign_id
        }

        fn contribute(ref self: ContractState, campaign_id: u256, amount: u256) {
            self.pausable.assert_not_paused();

            let mut campaign = self.campaigns.read(campaign_id);
            assert(campaign.is_active, ERROR_CAMPAIGN_NOT_FOUND);
            assert(get_block_timestamp() <= campaign.end_time, ERROR_CAMPAIGN_ENDED);

            let contributor = get_caller_address();

            let token = IERC20Dispatcher { contract_address: self.accepted_token.read() };
            token.transfer_from(contributor, get_contract_address(), amount);

            let current_contribution = self.contributions.read((campaign_id, contributor));
            self.contributions.write((campaign_id, contributor), current_contribution + amount);

            let total_raised = campaign.total_raised + amount;
            let funding_goal = campaign.funding_goal; // Save funding_goal before moving campaign

            campaign.total_raised = total_raised;
            campaign.is_funded = total_raised >= funding_goal;

            self.campaigns.write(campaign_id, campaign);

            // Update campaign stats
            let mut stats = self.campaign_stats.read(campaign_id);
            if current_contribution == 0 {
                stats.total_contributors += 1;
            }
            stats.avg_contribution = total_raised / stats.total_contributors.into();
            if amount > stats.largest_contribution {
                stats.largest_contribution = amount;
            }
            stats.funding_progress = (total_raised * 100) / funding_goal;
            self.campaign_stats.write(campaign_id, stats);

            self.emit(ContributionReceived { campaign_id, contributor, amount });
        }


        fn withdraw_funds(ref self: ContractState, campaign_id: u256) {
            self.pausable.assert_not_paused();

            let mut campaign = self.campaigns.read(campaign_id);
            assert(campaign.is_active, ERROR_CAMPAIGN_NOT_FOUND);
            assert(get_caller_address() == campaign.creator, ERROR_NOT_CREATOR);
            assert(!campaign.funds_withdrawn, ERROR_ALREADY_WITHDRAWN);
            assert(
                campaign.is_funded || get_block_timestamp() > campaign.end_time,
                ERROR_CAMPAIGN_ACTIVE
            );

            // Store the total_raised value before the move
            let total_raised = campaign.total_raised;

            let token = IERC20Dispatcher { contract_address: self.accepted_token.read() };
            token.transfer(campaign.creator, total_raised);

            campaign.funds_withdrawn = true;
            campaign.is_active = false;
            self.campaigns.write(campaign_id, campaign);

            self.emit(FundsWithdrawn { campaign_id, amount: total_raised });
        }

        fn refund(ref self: ContractState, campaign_id: u256) {
            self.pausable.assert_not_paused();

            let campaign = self.campaigns.read(campaign_id);
            assert(campaign.is_active, ERROR_CAMPAIGN_NOT_FOUND);
            assert(
                get_block_timestamp() > campaign.end_time && !campaign.is_funded,
                ERROR_CAMPAIGN_ACTIVE
            );

            let contributor = get_caller_address();
            let contribution = self.contributions.read((campaign_id, contributor));
            assert(contribution > 0, ERROR_NO_CONTRIBUTION);

            let token = IERC20Dispatcher { contract_address: self.accepted_token.read() };
            token.transfer(contributor, contribution);

            self.contributions.write((campaign_id, contributor), 0);

            self.emit(RefundProcessed { campaign_id, contributor, amount: contribution });
        }

        fn get_campaign(self: @ContractState, campaign_id: u256) -> Campaign {
            self.campaigns.read(campaign_id)
        }

        fn get_contribution(
            self: @ContractState, campaign_id: u256, contributor: ContractAddress
        ) -> u256 {
            self.contributions.read((campaign_id, contributor))
        }
    }
}
