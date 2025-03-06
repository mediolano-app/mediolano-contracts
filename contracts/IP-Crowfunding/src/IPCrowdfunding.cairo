use starknet::ContractAddress;

#[starknet::interface]
trait IERC20<TContractState> {
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Campaign {
    pub creator: ContractAddress,
    pub title: felt252,
    pub description: felt252,
    pub goal_amount: u256,
    pub raised_amount: u256,
    pub start_time: u64,
    pub end_time: u64,
    pub completed: bool,
    pub refunded: bool,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Contribution {
    contributor: ContractAddress,
    amount: u256,
    timestamp: u64,
}

#[starknet::interface]
pub trait IIPCrowdfunding<TContractState> {
    // Campaign functions
    fn create_campaign(
        ref self: TContractState,
        title: felt252,
        description: felt252,
        goal_amount: u256,
        duration: u64,
    );
    fn contribute(ref self: TContractState, campaign_id: u256, amount: u256);
    fn withdraw_funds(ref self: TContractState, campaign_id: u256);
    fn refund_contributions(ref self: TContractState, campaign_id: u256);

    // Query functions
    fn get_campaign(self: @TContractState, campaign_id: u256) -> Campaign;
    fn get_contributions(self: @TContractState, campaign_id: u256) -> Array<Contribution>;
}

#[starknet::contract]
pub mod IPCrowdfunding {
    use super::{Campaign, Contribution, IERC20DispatcherTrait, IERC20Dispatcher};
    use starknet::{
        ContractAddress, get_caller_address, get_block_timestamp, contract_address_const
    };
    use core::array::ArrayTrait;
    use core::starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };

    #[storage]
    struct Storage {
        owner: ContractAddress,
        token: ContractAddress,
        campaigns_count: u256,
        campaigns: Map<u256, Campaign>,
        contributions: Map<(u256, u256), Contribution>, // (campaign_id, contribution_id)
        campaign_contributions_count: Map<u256, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CampaignCreated: CampaignCreated,
        ContributionMade: ContributionMade,
        FundsWithdrawn: FundsWithdrawn,
        ContributionsRefunded: ContributionsRefunded,
    }

    #[derive(Drop, starknet::Event)]
    struct CampaignCreated {
        #[key]
        campaign_id: u256,
        creator: ContractAddress,
        title: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct ContributionMade {
        #[key]
        campaign_id: u256,
        contributor: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct FundsWithdrawn {
        #[key]
        campaign_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ContributionsRefunded {
        #[key]
        campaign_id: u256,
        amount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, token: ContractAddress) {
        self.owner.write(owner);
        self.token.write(token);
        self.campaigns_count.write(0);
    }

    #[abi(embed_v0)]
    impl IPCrowdfundingImpl of super::IIPCrowdfunding<ContractState> {
        fn create_campaign(
            ref self: ContractState,
            title: felt252,
            description: felt252,
            goal_amount: u256,
            duration: u64,
        ) {
            let caller = get_caller_address();
            let campaign_id = self.campaigns_count.read() + 1;
            let current_time = get_block_timestamp();

            let campaign = Campaign {
                creator: caller,
                title,
                description,
                goal_amount,
                raised_amount: 0.into(),
                start_time: current_time,
                end_time: current_time + duration,
                completed: false,
                refunded: false,
            };

            self.campaigns.entry(campaign_id).write(campaign);
            self.campaigns_count.write(campaign_id);

            self
                .emit(
                    Event::CampaignCreated(CampaignCreated { campaign_id, creator: caller, title }),
                );
        }

        fn contribute(ref self: ContractState, campaign_id: u256, amount: u256) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            let campaign = self.campaigns.entry(campaign_id).read();
            assert(current_time >= campaign.start_time, 'Campaign not started');
            assert(current_time <= campaign.end_time, 'Campaign ended');
            assert(!campaign.completed, 'Campaign completed');
            assert(!campaign.refunded, 'Campaign refunded');

            // Transfer tokens from contributor to contract
            let token = IERC20Dispatcher { contract_address: self.token.read() };
            assert(
                token.transfer_from(caller, contract_address_const::<0>(), amount),
                'Token transfer failed'
            );

            let contribution_id = self.campaign_contributions_count.entry(campaign_id).read() + 1;

            let contribution = Contribution {
                contributor: caller, amount, timestamp: current_time,
            };

            self.contributions.entry((campaign_id, contribution_id)).write(contribution);
            self.campaign_contributions_count.entry(campaign_id).write(contribution_id);

            let new_raised_amount = campaign.raised_amount + amount;
            let updated_campaign = Campaign { raised_amount: new_raised_amount, ..campaign };
            self.campaigns.entry(campaign_id).write(updated_campaign);

            self
                .emit(
                    Event::ContributionMade(
                        ContributionMade { campaign_id, contributor: caller, amount },
                    ),
                );
        }

        fn withdraw_funds(ref self: ContractState, campaign_id: u256) {
            let caller = get_caller_address();
            let campaign = self.campaigns.entry(campaign_id).read();
            assert(caller == campaign.creator, 'Not the creator');
            assert(!campaign.completed, 'Campaign completed');
            assert(campaign.raised_amount >= campaign.goal_amount, 'Goal not reached');

            // Transfer tokens to campaign creator
            let token = IERC20Dispatcher { contract_address: self.token.read() };
            assert(
                token.transfer(campaign.creator, campaign.raised_amount), 'Token transfer failed'
            );

            let updated_campaign = Campaign { completed: true, ..campaign };
            self.campaigns.entry(campaign_id).write(updated_campaign);

            self.emit(Event::FundsWithdrawn(FundsWithdrawn { campaign_id }));
        }

        fn refund_contributions(ref self: ContractState, campaign_id: u256) {
            let campaign = self.campaigns.entry(campaign_id).read();
            assert(!campaign.completed, 'Campaign completed');
            assert(!campaign.refunded, 'Already refunded');
            assert(campaign.raised_amount < campaign.goal_amount, 'Goal reached');
            assert(get_block_timestamp() > campaign.end_time, 'Campaign not ended');

            let token = IERC20Dispatcher { contract_address: self.token.read() };

            let contributions_count = self.campaign_contributions_count.entry(campaign_id).read();
            let mut i: u256 = 1;

            loop {
                if i > contributions_count {
                    break;
                }
                let contribution = self.contributions.entry((campaign_id, i)).read();
                // Refund tokens to contributor
                assert(
                    token.transfer(contribution.contributor, contribution.amount),
                    'Token transfer failed'
                );
                i += 1;
            };

            let updated_campaign = Campaign { refunded: true, ..campaign };
            self.campaigns.entry(campaign_id).write(updated_campaign);
        }

        // Query functions
        fn get_campaign(self: @ContractState, campaign_id: u256) -> Campaign {
            self.campaigns.entry(campaign_id).read()
        }

        fn get_contributions(self: @ContractState, campaign_id: u256) -> Array<Contribution> {
            let contributions_count = self.campaign_contributions_count.entry(campaign_id).read();
            let mut contributions = ArrayTrait::new();

            let mut i: u256 = 1;
            loop {
                if i > contributions_count {
                    break;
                }
                let contribution = self.contributions.entry((campaign_id, i)).read();
                contributions.append(contribution);
                i += 1;
            };

            contributions
        }
    }
}
