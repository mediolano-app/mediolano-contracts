#[starknet::contract]
pub mod CollectiveIPAgreement {
    // use ERC1155Component::InternalTrait;
    use core::array::ArrayTrait;
    use core::starknet::{
        ContractAddress, get_caller_address, get_block_timestamp,
        storage::{
            StoragePointerReadAccess, StoragePointerWriteAccess, Map, StorageMapReadAccess,
            StorageMapWriteAccess,
        },
    };
    use openzeppelin::token::erc1155::{ERC1155Component};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use super::super::types::{
        IPData, Proposal, INVALID_METADATA_URI, MISMATCHED_OWNERS_SHARES, NO_OWNERS,
        INVALID_ROYALTY_RATE, INVALID_SHARES_SUM, NO_IP_DATA, NOT_OWNER, PROPOSAL_EXECUTED,
        VOTING_ENDED, ALREADY_VOTED, VOTING_NOT_ENDED, INSUFFICIENT_VOTES, NOT_DISPUTE_RESOLVER,
    };
    // use super::super::interfaces::ICollectiveIP;
    use super::super::interfaces::ICollectiveIP;
    // use super::super::ICollectiveIP;
    // Components
    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC1155 External
    #[abi(embed_v0)]
    impl ERC1155Impl = ERC1155Component::ERC1155Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1155MetadataURIImpl =
        ERC1155Component::ERC1155MetadataURIImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    // Internal
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Empty ERC1155 Hooks Implementation
    impl ERC1155HooksImpl of ERC1155Component::ERC1155HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC1155Component::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
        ) {}

        fn after_update(
            ref self: ERC1155Component::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
        ) {}
    }

    // Storage
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        ip_data: Map<u256, IPData>, // Token ID -> IP metadata
        owners: Map<(u256, u32), ContractAddress>, // (Token ID, Index) -> Owner
        ownership_shares: Map<(u256, ContractAddress), u256>, // (Token ID, Owner) -> Share
        total_supply: Map<u256, u256>, // Token ID -> Total supply
        proposals: Map<u256, Proposal>, // Proposal ID -> Proposal data
        votes: Map<(u256, ContractAddress), bool>, // (Proposal ID, Voter) -> Voted
        proposal_count: u256,
        dispute_resolver: ContractAddress // Address authorized to mediate disputes
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        IPRegistered: IPRegistered,
        RoyaltyDistributed: RoyaltyDistributed,
        ProposalCreated: ProposalCreated,
        Voted: Voted,
        ProposalExecuted: ProposalExecuted,
        DisputeResolved: DisputeResolved,
    }

    #[derive(Drop, starknet::Event)]
    struct IPRegistered {
        token_id: u256,
        owner_count: u32,
        metadata_uri: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    struct RoyaltyDistributed {
        token_id: u256,
        amount: u256,
        recipient: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalCreated {
        proposal_id: u256,
        proposer: ContractAddress,
        description: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    struct Voted {
        proposal_id: u256,
        voter: ContractAddress,
        vote: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalExecuted {
        proposal_id: u256,
        success: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct DisputeResolved {
        token_id: u256,
        resolver: ContractAddress,
        resolution: ByteArray,
    }

    // Constructor
    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        uri: ByteArray,
        dispute_resolver: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.erc1155.initializer(uri);
        self.dispute_resolver.write(dispute_resolver);
    }

    // External Functions
    #[abi(embed_v0)]
    impl CollectiveIPImpl of ICollectiveIP<ContractState> {
        // Register a new collective IP
        fn register_ip(
            ref self: ContractState,
            token_id: u256,
            metadata_uri: ByteArray,
            owners: Array<ContractAddress>,
            ownership_shares: Array<u256>,
            royalty_rate: u256,
            expiry_date: u64,
            license_terms: ByteArray,
        ) {
            self.ownable.assert_only_owner();
            assert(metadata_uri.len() > 0, INVALID_METADATA_URI);
            assert(owners.len() == ownership_shares.len(), MISMATCHED_OWNERS_SHARES);
            assert(owners.len() > 0, NO_OWNERS);
            assert(royalty_rate <= 1000, INVALID_ROYALTY_RATE); // 1000 = 100%

            // Validate ownership shares sum to 1000 (100%)
            let mut sum_shares: u256 = 0;
            let mut i: u32 = 0;
            while i < ownership_shares.len() {
                sum_shares += *ownership_shares.at(i);
                i += 1;
            };
            assert(sum_shares == 1000, INVALID_SHARES_SUM);

            // Store IP data
            let ip_data = IPData {
                metadata_uri: metadata_uri.clone(), // Clone to avoid move
                owner_count: owners.len(),
                royalty_rate,
                expiry_date,
                license_terms,
            };
            self.ip_data.write(token_id, ip_data);

            // Store owners and shares
            let mut i: u32 = 0;
            while i < owners.len() {
                let owner = *owners.at(i);
                let share = *ownership_shares.at(i);
                self.owners.write((token_id, i), owner);
                self.ownership_shares.write((token_id, owner), share);
                self
                    .erc1155
                    .batch_mint_with_acceptance_check(
                        owner, array![token_id].span(), array![share].span(), array![].span(),
                    );
                i += 1;
            };

            self.total_supply.write(token_id, 1000); // Total supply is 1000 (100%)

            self.emit(IPRegistered { token_id, owner_count: owners.len(), metadata_uri });
        }

        // Distribute royalties to co-owners
        fn distribute_royalties(ref self: ContractState, token_id: u256, total_amount: u256) {
            self.ownable.assert_only_owner();
            let ip_data = self.ip_data.read(token_id);
            assert(ip_data.owner_count > 0, NO_IP_DATA);

            let royalty_amount = (total_amount * ip_data.royalty_rate) / 1000;
            let mut i: u32 = 0;
            while i < ip_data.owner_count {
                let owner = self.owners.read((token_id, i));
                let share = self.ownership_shares.read((token_id, owner));
                let owner_amount = (royalty_amount * share) / 1000;
                // In a real implementation, transfer funds (e.g., via ERC-20)
                self.emit(RoyaltyDistributed { token_id, amount: owner_amount, recipient: owner });
                i += 1;
            }
        }

        // Create a governance proposal
        // Create a governance proposal
        fn create_proposal(ref self: ContractState, token_id: u256, description: ByteArray) {
            let ip_data = self.ip_data.read(token_id);
            let caller = get_caller_address();
            assert(self._is_owner(token_id, ip_data.owner_count, caller), NOT_OWNER);

            let proposal_id = self.proposal_count.read() + 1;
            self.proposal_count.write(proposal_id);

            let proposal = Proposal {
                proposer: caller,
                description: description.clone(), // Clone to avoid move
                vote_count: 0,
                executed: false,
                deadline: get_block_timestamp() + 604800 // 7 days
            };
            self.proposals.write(proposal_id, proposal);

            self.emit(ProposalCreated { proposal_id, proposer: caller, description });
        }

        // Vote on a proposal
        fn vote(ref self: ContractState, token_id: u256, proposal_id: u256, support: bool) {
            let ip_data = self.ip_data.read(token_id);
            let caller = get_caller_address();
            assert(self._is_owner(token_id, ip_data.owner_count, caller), NOT_OWNER);

            let mut proposal = self.proposals.read(proposal_id);
            assert(!proposal.executed, PROPOSAL_EXECUTED);
            assert(get_block_timestamp() <= proposal.deadline, VOTING_ENDED);
            assert(!self.votes.read((proposal_id, caller)), ALREADY_VOTED);

            let share = self.ownership_shares.read((token_id, caller));
            proposal.vote_count += share;
            self.proposals.write(proposal_id, proposal);
            self.votes.write((proposal_id, caller), true);

            self.emit(Voted { proposal_id, voter: caller, vote: support });
        }

        // Execute a proposal if it has majority support
        fn execute_proposal(ref self: ContractState, token_id: u256, proposal_id: u256) {
            let mut proposal = self.proposals.read(proposal_id);
            assert(!proposal.executed, PROPOSAL_EXECUTED);
            assert(get_block_timestamp() > proposal.deadline, VOTING_NOT_ENDED);

            let total_votes = proposal.vote_count;
            assert(total_votes > 500, INSUFFICIENT_VOTES); // >50% required

            proposal.executed = true;
            self.proposals.write(proposal_id, proposal);

            // Execute proposal logic (e.g., update license terms, transfer ownership)
            // Placeholder: Emit event for now
            self.emit(ProposalExecuted { proposal_id, success: true });
        }

        // Resolve a dispute (only by dispute resolver)
        fn resolve_dispute(ref self: ContractState, token_id: u256, resolution: ByteArray) {
            let caller = get_caller_address();
            assert(caller == self.dispute_resolver.read(), NOT_DISPUTE_RESOLVER);

            self.emit(DisputeResolved { token_id, resolver: caller, resolution });
        }

        // Get IP metadata
        fn get_ip_metadata(self: @ContractState, token_id: u256) -> IPData {
            self.ip_data.read(token_id)
        }

        // Get owner at index
        fn get_owner(self: @ContractState, token_id: u256, index: u32) -> ContractAddress {
            let ip_data = self.ip_data.read(token_id);
            assert(index < ip_data.owner_count, 'Index out of bounds');
            self.owners.read((token_id, index))
        }

        // Get ownership share for an owner
        fn get_ownership_share(
            self: @ContractState, token_id: u256, owner: ContractAddress,
        ) -> u256 {
            self.ownership_shares.read((token_id, owner))
        }

        // Get proposal details
        fn get_proposal(self: @ContractState, proposal_id: u256) -> Proposal {
            self.proposals.read(proposal_id)
        }

        // Get total supply of a token
        fn get_total_supply(self: @ContractState, token_id: u256) -> u256 {
            self.total_supply.read(token_id)
        }

        // Update dispute resolver
        fn set_dispute_resolver(ref self: ContractState, new_resolver: ContractAddress) {
            self.ownable.assert_only_owner();
            self.dispute_resolver.write(new_resolver);
        }
    }

    // Internal Functions
    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn _is_owner(
            self: @ContractState, token_id: u256, owner_count: u32, address: ContractAddress,
        ) -> bool {
            let mut i: u32 = 0;
            let mut is_owner: bool = false;
            while i < owner_count {
                if self.owners.read((token_id, i)) == address {
                    is_owner = true;
                    break;
                }
                i += 1;
            };
            is_owner
        }
    }
}
