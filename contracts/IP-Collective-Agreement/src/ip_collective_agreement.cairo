#[starknet::contract]
mod CollectiveIPCore {
    use ip_collective_agreement::types::{
        OwnershipInfo, IPAssetInfo, IPAssetType, ComplianceStatus, RevenueInfo, OwnerRevenueInfo,
    };
    use ip_collective_agreement::interface::{
        IOwnershipRegistry, IIPAssetManager, IRevenueDistribution,
    };
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StorageMapReadAccess,
        StorageMapWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, get_contract_address};
    use core::array::ArrayTrait;
    use openzeppelin::token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::access::ownable::OwnableComponent;
    use core::num::traits::Zero;

    // Component declarations
    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // ERC1155 Mixin
    #[abi(embed_v0)]
    impl ERC1155MixinImpl = ERC1155Component::ERC1155MixinImpl<ContractState>;
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;
    impl ERC1155HooksImpl = ERC1155HooksEmptyImpl<ContractState>;

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        // OpenZeppelin Components
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        // Ownership Registry Storage
        ownership_info: Map<u256, OwnershipInfo>,
        owner_percentage: Map<(u256, ContractAddress), u256>,
        governance_weight: Map<(u256, ContractAddress), u256>,
        asset_owners: Map<(u256, u32), ContractAddress>, // (asset_id, owner_index) -> owner_address
        // IP Asset Manager Storage
        asset_info: Map<u256, IPAssetInfo>,
        asset_creators: Map<
            (u256, u32), ContractAddress,
        >, // (asset_id, creator_index) -> creator_address
        // Global state
        next_asset_id: u256,
        paused: bool,
        revenue_info: Map<(u256, ContractAddress), RevenueInfo>,
        pending_revenue: Map<
            (u256, ContractAddress, ContractAddress), u256,
        >, // (asset_id, owner, token) -> amount
        owner_revenue_info: Map<
            (u256, ContractAddress, ContractAddress), OwnerRevenueInfo,
        > // (asset_id, owner, token) -> info
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        // OpenZeppelin Component Events
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        // Custom Events
        CollectiveOwnershipRegistered: CollectiveOwnershipRegistered,
        IPOwnershipTransferred: IPOwnershipTransferred,
        AssetRegistered: AssetRegistered,
        MetadataUpdated: MetadataUpdated,
        RevenueReceived: RevenueReceived,
        RevenueDistributed: RevenueDistributed,
        RevenueWithdrawn: RevenueWithdrawn,
    }

    #[derive(Drop, starknet::Event)]
    struct CollectiveOwnershipRegistered {
        asset_id: u256,
        total_owners: u32,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct IPOwnershipTransferred {
        asset_id: u256,
        from: ContractAddress,
        to: ContractAddress,
        percentage: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct AssetRegistered {
        asset_id: u256,
        asset_type: felt252,
        total_creators: u32,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct MetadataUpdated {
        asset_id: u256,
        old_metadata_uri: ByteArray,
        new_metadata_uri: ByteArray,
        updated_by: ContractAddress,
        timestamp: u64,
    }

    /// Revenue Distribution Events
    #[derive(Drop, starknet::Event)]
    pub struct RevenueReceived {
        pub asset_id: u256,
        pub token_address: ContractAddress,
        pub amount: u256,
        pub from: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RevenueDistributed {
        pub asset_id: u256,
        pub token_address: ContractAddress,
        pub total_amount: u256,
        pub recipients_count: u32,
        pub distributed_by: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RevenueWithdrawn {
        pub asset_id: u256,
        pub owner: ContractAddress,
        pub token_address: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, base_uri: ByteArray) {
        self.ownable.initializer(owner);
        self.erc1155.initializer(base_uri);
        self.next_asset_id.write(1);
        self.paused.write(false);
    }

    #[abi(embed_v0)]
    impl OwnershipRegistryImpl of IOwnershipRegistry<ContractState> {
        fn register_collective_ownership(
            ref self: ContractState,
            asset_id: u256,
            owners: Span<ContractAddress>,
            ownership_percentages: Span<u256>,
            governance_weights: Span<u256>,
        ) -> bool {
            // Validation
            assert(!self.paused.read(), 'Contract is paused');
            assert!(
                owners.len() == ownership_percentages.len(),
                "Owners and percentages length mismatch",
            );
            assert!(
                owners.len() == governance_weights.len(),
                "Owners and governance weights length mismatch",
            );
            assert!(owners.len() > 0, "At least one owner required");

            // Validate total percentage equals 100%
            let mut total_percentage: u256 = 0;
            let mut i = 0;
            loop {
                if i >= ownership_percentages.len() {
                    break;
                }
                total_percentage += *ownership_percentages.at(i);
                i += 1;
            };
            assert!(total_percentage == 100, "Total ownership must equal 100%");

            // Store ownership information
            let ownership_info = OwnershipInfo {
                total_owners: owners.len(),
                is_active: true,
                registration_timestamp: get_block_timestamp(),
            };

            self.ownership_info.write(asset_id, ownership_info);

            // Store individual owner data for quick lookup
            i = 0;
            loop {
                if i >= owners.len() {
                    break;
                }
                let owner = *owners.at(i);
                let percentage = *ownership_percentages.at(i);
                let gov_weight = *governance_weights.at(i);

                self.owner_percentage.write((asset_id, owner), percentage);
                self.governance_weight.write((asset_id, owner), gov_weight);
                self.asset_owners.write((asset_id, i), owner);
                i += 1;
            };

            // Emit event
            self
                .emit(
                    CollectiveOwnershipRegistered {
                        asset_id, total_owners: owners.len(), timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn get_ownership_info(self: @ContractState, asset_id: u256) -> OwnershipInfo {
            self.ownership_info.read(asset_id)
        }

        fn get_owner_percentage(
            self: @ContractState, asset_id: u256, owner: ContractAddress,
        ) -> u256 {
            self.owner_percentage.read((asset_id, owner))
        }

        fn transfer_ownership_share(
            ref self: ContractState,
            asset_id: u256,
            from: ContractAddress,
            to: ContractAddress,
            percentage: u256,
        ) -> bool {
            let caller = get_caller_address();
            assert!(caller == from, "Only owner can transfer their share");

            let current_percentage = self.owner_percentage.read((asset_id, from));
            assert!(current_percentage >= percentage, "Insufficient ownership share");

            // Update ownership percentages
            self.owner_percentage.write((asset_id, from), current_percentage - percentage);
            let to_current = self.owner_percentage.read((asset_id, to));
            self.owner_percentage.write((asset_id, to), to_current + percentage);

            if to_current == 0 {
                // New owner - add to asset_owners mapping
                let ownership_info = self.ownership_info.read(asset_id);
                self.asset_owners.write((asset_id, ownership_info.total_owners), to);

                // Update total_owners count
                let mut updated_ownership_info = ownership_info;
                updated_ownership_info.total_owners += 1;
                self.ownership_info.write(asset_id, updated_ownership_info);
            }

            // Update governance weights proportionally
            let from_gov_weight = self.governance_weight.read((asset_id, from));
            let weight_to_transfer = (from_gov_weight * percentage) / current_percentage;
            self.governance_weight.write((asset_id, from), from_gov_weight - weight_to_transfer);
            let to_gov_weight = self.governance_weight.read((asset_id, to));
            self.governance_weight.write((asset_id, to), to_gov_weight + weight_to_transfer);

            self
                .emit(
                    IPOwnershipTransferred {
                        asset_id, from, to, percentage, timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn is_owner(self: @ContractState, asset_id: u256, address: ContractAddress) -> bool {
            self.owner_percentage.read((asset_id, address)) > 0
        }

        fn has_governance_rights(
            self: @ContractState, asset_id: u256, address: ContractAddress,
        ) -> bool {
            self.governance_weight.read((asset_id, address)) > 0
        }

        fn get_governance_weight(
            self: @ContractState, asset_id: u256, owner: ContractAddress,
        ) -> u256 {
            self.governance_weight.read((asset_id, owner))
        }
    }

    #[abi(embed_v0)]
    impl IPAssetManagerImpl of IIPAssetManager<ContractState> {
        fn register_ip_asset(
            ref self: ContractState,
            asset_type: felt252,
            metadata_uri: ByteArray,
            creators: Span<ContractAddress>,
            ownership_percentages: Span<u256>,
            governance_weights: Span<u256>,
        ) -> u256 {
            assert!(!self.paused.read(), "Contract is paused");
            assert!(creators.len() > 0, "At least one creator required");
            assert!(
                creators.len() == ownership_percentages.len(),
                "Creators and percentages length mismatch",
            );
            assert!(
                creators.len() == governance_weights.len(),
                "Creators and governance weights length mismatch",
            );

            // Validate total percentage equals 100%
            let mut total_percentage: u256 = 0;
            let mut i = 0;
            loop {
                if i >= ownership_percentages.len() {
                    break;
                }
                total_percentage += *ownership_percentages.at(i);
                i += 1;
            };
            assert!(total_percentage == 100, "Total ownership must equal 100%");

            let asset_id = self.next_asset_id.read();
            self.next_asset_id.write(asset_id + 1);

            let asset_info = IPAssetInfo {
                asset_id,
                asset_type,
                metadata_uri: metadata_uri.clone(),
                total_supply: 1000, // Standard initial supply for IP tokens
                creation_timestamp: get_block_timestamp(),
                is_verified: false,
                compliance_status: ComplianceStatus::Pending.into(),
            };

            self.asset_info.write(asset_id, asset_info);

            // Store creators in separate mapping
            let mut i = 0;
            loop {
                if i >= creators.len() {
                    break;
                }
                let creator = *creators.at(i);
                self.asset_creators.write((asset_id, i), creator);
                i += 1;
            };

            // Register collective ownership
            self
                .register_collective_ownership(
                    asset_id, creators, ownership_percentages, governance_weights,
                );

            // Mint initial tokens to creators based on ownership percentages
            i = 0;
            loop {
                if i >= creators.len() {
                    break;
                }
                let creator = *creators.at(i);
                let percentage = *ownership_percentages.at(i);
                let token_amount = (1000 * percentage) / 100; // Calculate based on percentage

                self
                    .erc1155
                    .mint_with_acceptance_check(creator, asset_id, token_amount, array![].span());
                i += 1;
            };

            self
                .emit(
                    AssetRegistered {
                        asset_id,
                        asset_type,
                        total_creators: creators.len(),
                        timestamp: get_block_timestamp(),
                    },
                );

            asset_id
        }

        fn get_asset_info(self: @ContractState, asset_id: u256) -> IPAssetInfo {
            self.asset_info.read(asset_id)
        }

        fn update_asset_metadata(
            ref self: ContractState, asset_id: u256, new_metadata_uri: ByteArray,
        ) -> bool {
            let caller = get_caller_address();
            assert!(self.is_owner(asset_id, caller), "Only owners can update metadata");

            let mut asset_info = self.asset_info.read(asset_id);
            let old_metadata_uri = asset_info.metadata_uri.clone();
            asset_info.metadata_uri = new_metadata_uri.clone();
            self.asset_info.write(asset_id, asset_info);

            self
                .emit(
                    MetadataUpdated {
                        asset_id,
                        old_metadata_uri,
                        new_metadata_uri,
                        updated_by: caller,
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn mint_additional_tokens(
            ref self: ContractState, asset_id: u256, to: ContractAddress, amount: u256,
        ) -> bool {
            let caller = get_caller_address();
            assert!(self.is_owner(asset_id, caller), "Only owners can mint tokens");

            let mut asset_info = self.asset_info.read(asset_id);
            asset_info.total_supply += amount;
            self.asset_info.write(asset_id, asset_info);

            self.erc1155.mint_with_acceptance_check(to, asset_id, amount, array![].span());

            true
        }

        fn verify_asset_ownership(self: @ContractState, asset_id: u256) -> bool {
            let asset_info = self.asset_info.read(asset_id);
            let ownership_info = self.ownership_info.read(asset_id);

            if asset_info.asset_id == 0 || !ownership_info.is_active {
                return false;
            }

            true
        }

        fn get_total_supply(self: @ContractState, asset_id: u256) -> u256 {
            let asset_info = self.asset_info.read(asset_id);
            asset_info.total_supply
        }

        fn get_asset_uri(self: @ContractState, token_id: u256) -> ByteArray {
            let asset_info = self.asset_info.read(token_id);
            asset_info.metadata_uri
        }

        fn pause_contract(ref self: ContractState) {
            self.pause();
        }

        fn unpause_contract(ref self: ContractState) {
            self.unpause();
        }
    }

    #[abi(embed_v0)]
    impl RevenueDistributionImpl of IRevenueDistribution<ContractState> {
        fn receive_revenue(
            ref self: ContractState, asset_id: u256, token_address: ContractAddress, amount: u256,
        ) -> bool {
            let caller = get_caller_address();

            // Validate asset exists
            assert(self.verify_asset_ownership(asset_id), 'Invalid asset ID');
            assert!(amount > 0, "Amount must be greater than zero");

            // Transfer tokens from caller to contract
            if !token_address.is_zero() {
                let erc20 = IERC20Dispatcher { contract_address: token_address };
                let success = erc20.transfer_from(caller, get_contract_address(), amount);
                assert!(success, "Token transfer failed");
            }

            // Update revenue tracking
            let mut revenue_info = self.revenue_info.read((asset_id, token_address));
            revenue_info.total_received += amount;
            revenue_info.accumulated_revenue += amount;
            self.revenue_info.write((asset_id, token_address), revenue_info);

            // Emit event
            self
                .emit(
                    RevenueReceived {
                        asset_id,
                        token_address,
                        amount,
                        from: caller,
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn distribute_revenue(
            ref self: ContractState, asset_id: u256, token_address: ContractAddress, amount: u256,
        ) -> bool {
            let caller = get_caller_address();

            // Only owners can trigger distribution
            assert!(self.is_owner(asset_id, caller), "Only owners can distribute revenue");

            // Validate asset and amount
            assert(self.verify_asset_ownership(asset_id), 'Invalid asset ID');
            assert!(amount > 0, "Amount must be greater than zero");

            // Check we have enough accumulated revenue
            let mut revenue_info = self.revenue_info.read((asset_id, token_address));
            assert!(revenue_info.accumulated_revenue >= amount, "Insufficient accumulated revenue");

            // Check minimum distribution amount
            assert!(
                amount >= revenue_info.minimum_distribution, "Amount below minimum distribution",
            );

            // Get owners and their percentages
            let (owners, percentages) = self.get_asset_owners_with_percentages(asset_id);

            // Distribute to each owner
            let mut i = 0;
            let mut total_distributed = 0;

            loop {
                if i >= owners.len() {
                    break;
                }

                let owner = *owners.at(i);
                let percentage = *percentages.at(i);
                let owner_share = (amount * percentage) / 100;

                if owner_share > 0 {
                    // Add to owner's pending revenue
                    let current_pending = self
                        .pending_revenue
                        .read((asset_id, owner, token_address));
                    self
                        .pending_revenue
                        .write((asset_id, owner, token_address), current_pending + owner_share);

                    // Update owner revenue tracking
                    let mut owner_info = self
                        .owner_revenue_info
                        .read((asset_id, owner, token_address));
                    owner_info.total_earned += owner_share;
                    self.owner_revenue_info.write((asset_id, owner, token_address), owner_info);

                    total_distributed += owner_share;
                }

                i += 1;
            };

            // Update revenue info
            revenue_info.accumulated_revenue -= total_distributed;
            revenue_info.total_distributed += total_distributed;
            revenue_info.last_distribution_timestamp = get_block_timestamp();
            revenue_info.distribution_count += 1;
            self.revenue_info.write((asset_id, token_address), revenue_info);

            // Emit event
            self
                .emit(
                    RevenueDistributed {
                        asset_id,
                        token_address,
                        total_amount: total_distributed,
                        recipients_count: owners.len(),
                        distributed_by: caller,
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn distribute_all_revenue(
            ref self: ContractState, asset_id: u256, token_address: ContractAddress,
        ) -> bool {
            // Get all accumulated revenue for this asset
            let revenue_info = self.revenue_info.read((asset_id, token_address));
            let accumulated = revenue_info.accumulated_revenue;

            if accumulated > 0 {
                self.distribute_revenue(asset_id, token_address, accumulated)
            } else {
                false
            }
        }

        fn withdraw_pending_revenue(
            ref self: ContractState, asset_id: u256, token_address: ContractAddress,
        ) -> u256 {
            let caller = get_caller_address();

            // Verify caller is an owner
            assert(self.is_owner(asset_id, caller), 'Not an asset owner');

            // Get pending revenue
            let pending_amount = self.pending_revenue.read((asset_id, caller, token_address));
            assert!(pending_amount > 0, "No pending revenue");

            // Clear pending revenue
            self.pending_revenue.write((asset_id, caller, token_address), 0);

            // Update owner revenue info
            let mut owner_info = self.owner_revenue_info.read((asset_id, caller, token_address));
            owner_info.total_withdrawn += pending_amount;
            owner_info.last_withdrawal_timestamp = get_block_timestamp();
            self.owner_revenue_info.write((asset_id, caller, token_address), owner_info);

            // Transfer tokens from contract to owner
            if !token_address.is_zero() {
                let erc20 = IERC20Dispatcher { contract_address: token_address };
                let success = erc20.transfer(caller, pending_amount);
                assert!(success, "Token transfer failed");
            }

            // Emit event
            self
                .emit(
                    RevenueWithdrawn {
                        asset_id,
                        owner: caller,
                        token_address,
                        amount: pending_amount,
                        timestamp: get_block_timestamp(),
                    },
                );

            pending_amount
        }

        fn get_accumulated_revenue(
            self: @ContractState, asset_id: u256, token_address: ContractAddress,
        ) -> u256 {
            let revenue_info = self.revenue_info.read((asset_id, token_address));
            revenue_info.accumulated_revenue
        }

        fn get_pending_revenue(
            self: @ContractState,
            asset_id: u256,
            owner: ContractAddress,
            token_address: ContractAddress,
        ) -> u256 {
            self.pending_revenue.read((asset_id, owner, token_address))
        }

        fn get_total_revenue_distributed(
            self: @ContractState, asset_id: u256, token_address: ContractAddress,
        ) -> u256 {
            let revenue_info = self.revenue_info.read((asset_id, token_address));
            revenue_info.total_distributed
        }

        fn get_owner_total_earned(
            self: @ContractState,
            asset_id: u256,
            owner: ContractAddress,
            token_address: ContractAddress,
        ) -> u256 {
            let owner_info = self.owner_revenue_info.read((asset_id, owner, token_address));
            owner_info.total_earned
        }

        fn set_minimum_distribution(
            ref self: ContractState,
            asset_id: u256,
            min_amount: u256,
            token_address: ContractAddress,
        ) -> bool {
            let caller = get_caller_address();

            // Verify caller is an owner
            assert!(self.is_owner(asset_id, caller), "Not an asset owner");

            // Update minimum distribution
            let mut revenue_info = self.revenue_info.read((asset_id, token_address));
            revenue_info.minimum_distribution = min_amount;
            self.revenue_info.write((asset_id, token_address), revenue_info);

            true
        }

        fn get_minimum_distribution(
            self: @ContractState, asset_id: u256, token_address: ContractAddress,
        ) -> u256 {
            let revenue_info = self.revenue_info.read((asset_id, token_address));
            revenue_info.minimum_distribution
        }
    }


    // Internal helper functions
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn only_owner(self: @ContractState) {
            self.ownable.assert_only_owner();
        }

        fn pause(ref self: ContractState) {
            self.only_owner();
            self.paused.write(true);
        }

        fn unpause(ref self: ContractState) {
            self.only_owner();
            self.paused.write(false);
        }

        fn get_asset_owners(self: @ContractState, asset_id: u256) -> Array<ContractAddress> {
            let ownership_info = self.ownership_info.read(asset_id);
            let mut owners = ArrayTrait::new();
            let mut i = 0;

            loop {
                if i >= ownership_info.total_owners {
                    break;
                }
                let owner = self.asset_owners.read((asset_id, i));
                owners.append(owner);
                i += 1;
            };

            owners
        }

        fn get_asset_creators(self: @ContractState, asset_id: u256) -> Array<ContractAddress> {
            let asset_info = self.asset_info.read(asset_id);
            let mut creators = ArrayTrait::new();
            let mut i = 0;

            // We need to determine the number of creators - we can use ownership info as a proxy
            // since creators are typically the initial owners
            let ownership_info = self.ownership_info.read(asset_id);
            loop {
                if i >= ownership_info.total_owners {
                    break;
                }
                let creator = self.asset_creators.read((asset_id, i));
                if creator.is_non_zero() {
                    creators.append(creator);
                }
                i += 1;
            };

            creators
        }

        fn get_asset_owners_with_percentages(
            self: @ContractState, asset_id: u256,
        ) -> (Span<ContractAddress>, Span<u256>) {
            let ownership_info = self.ownership_info.read(asset_id);
            let mut owners = ArrayTrait::new();
            let mut percentages = ArrayTrait::new();
            let mut i = 0;

            loop {
                if i >= ownership_info.total_owners {
                    break;
                }
                let owner = self.asset_owners.read((asset_id, i));
                let percentage = self.owner_percentage.read((asset_id, owner));
                owners.append(owner);
                percentages.append(percentage);
                i += 1;
            };

            (owners.span(), percentages.span())
        }
    }
}
