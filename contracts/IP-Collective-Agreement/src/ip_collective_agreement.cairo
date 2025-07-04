/// # Collective IP Core Contract
///
/// A comprehensive smart contract system for managing intellectual property assets
/// through collective ownership, licensing, revenue distribution, and compliance tracking.
///
/// ## Features
///
/// - **Collective Ownership**: Multiple owners with configurable ownership percentages and
/// governance weights - **Asset Management**: Registration and management of various IP asset types
/// with ERC1155 token representation - **Revenue Distribution**: Automated distribution of revenue
/// to asset owners based on ownership percentages - **Licensing System**: Create, approve, execute,
/// and manage various types of IP licenses - **Governance**: Proposal-based decision making for
/// asset management, licensing, and policy changes - **Berne Convention Compliance**: Full
/// compliance tracking and verification system for international IP protection
///
/// ## Architecture
///
/// The contract is built using OpenZeppelin components and follows modular design principles:
/// - ERC1155 for tokenized IP asset representation
/// - Ownable for access control
/// - Custom interfaces for each functional domain
///
/// ## Usage
///
/// 1. Register IP assets with collective ownership structure
/// 2. Create licensing proposals and execute approved licenses
/// 3. Receive and distribute revenue automatically
/// 4. Manage governance through weighted voting
/// 5. Maintain compliance with international IP laws
#[starknet::contract]
mod CollectiveIPCore {
    use ip_collective_agreement::types::{
        OwnershipInfo, IPAssetInfo, ComplianceStatus, RevenueInfo, OwnerRevenueInfo,
        RevenueReceived, RevenueDistributed, RevenueWithdrawn, CollectiveOwnershipRegistered,
        IPOwnershipTransferred, AssetRegistered, LicenseInfo, LicenseTerms, LicenseProposal,
        RoyaltyInfo, MetadataUpdated, LicenseOfferCreated, LicenseApproved, LicenseExecuted,
        LicenseRevoked, LicenseSuspended, LicenseTransferred, RoyaltyPaid, UsageReported,
        LicenseProposalCreated, LicenseProposalVoted, LicenseProposalExecuted, LicenseReactivated,
        GovernanceProposal, AssetManagementProposal, RevenuePolicyProposal, EmergencyProposal,
        GovernanceSettings, ProposalType, GovernanceProposalCreated, ProposalQuorumReached,
        AssetManagementExecuted, RevenuePolicyUpdated, EmergencyActionExecuted,
        GovernanceSettingsUpdated, ComplianceRecord, ComplianceVerificationRequest,
        CountryComplianceRequirements, ComplianceAuthority, WorkType,
        ComplianceVerificationRequested, ComplianceVerified, ComplianceAuthorityRegistered,
        ProtectionRenewalRequired, ProtectionExpired, CrossBorderProtectionUpdated,
    };
    use ip_collective_agreement::interface::{
        IOwnershipRegistry, IIPAssetManager, IRevenueDistribution, ILicenseManager, IGovernance,
        IBerneCompliance,
    };
    use ip_collective_agreement::constants::{THIRTY_DAYS, STANDARD_INITIAL_SUPPLY};
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

    /// # Contract Storage
    ///
    /// Comprehensive storage structure organizing all contract state across multiple functional
    /// domains.
    /// Uses Maps for efficient key-value storage and supports complex relationships between
    /// entities.
    #[storage]
    struct Storage {
        // OpenZeppelin Components
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        ///////////////////
        // Ownership Storage
        ///////////////////

        /// Maps asset ID to ownership information including total owners and registration status
        ownership_info: Map<u256, OwnershipInfo>,
        /// Maps (asset_id, owner_address) to ownership percentage (0-100)
        owner_percentage: Map<(u256, ContractAddress), u256>,
        /// Maps (asset_id, owner_address) to governance voting weight
        governance_weight: Map<(u256, ContractAddress), u256>,
        /// Maps (asset_id, owner_index) to owner address for enumeration
        asset_owners: Map<(u256, u32), ContractAddress>, // (asset_id, owner_index) -> owner_address
        ///////////////////
        // Asset Storage
        ///////////////////

        /// Maps asset ID to complete asset information including metadata and compliance status
        asset_info: Map<u256, IPAssetInfo>,
        /// Maps (asset_id, creator_index) to creator address for enumeration
        asset_creators: Map<
            (u256, u32), ContractAddress,
        >, // (asset_id, creator_index) -> creator_address
        /// Global counter for generating unique asset IDs
        next_asset_id: u256,
        /// Contract pause state for emergency stops
        paused: bool,
        ///////////////////
        // Revenue Storage
        ///////////////////

        /// Maps (asset_id, token_address) to revenue tracking information
        revenue_info: Map<(u256, ContractAddress), RevenueInfo>,
        /// Maps (asset_id, owner, token) to pending withdrawal amount
        pending_revenue: Map<
            (u256, ContractAddress, ContractAddress), u256,
        >, // (asset_id, owner, token) -> amount
        /// Maps (asset_id, owner, token) to owner's revenue statistics
        owner_revenue_info: Map<
            (u256, ContractAddress, ContractAddress), OwnerRevenueInfo,
        >, // (asset_id, owner, token) -> info
        ///////////////////
        // Licensing Storage
        ///////////////////

        /// Maps license ID to complete license information
        license_info: Map<u256, LicenseInfo>,
        /// Maps license ID to specific license terms and conditions
        license_terms: Map<u256, LicenseTerms>,
        /// Global counter for generating unique license IDs
        next_license_id: u256,
        // Asset licensing mappings
        /// Maps (asset_id, index) to license ID for asset enumeration
        asset_licenses: Map<(u256, u32), u256>, // (asset_id, index) -> license_id
        /// Maps asset ID to total number of licenses created for that asset
        asset_license_count: Map<u256, u32>, // asset_id -> count
        // Licensee mappings (populated during execution)
        /// Maps (licensee, index) to license ID for licensee enumeration
        licensee_licenses: Map<(ContractAddress, u32), u256>, // (licensee, index) -> license_id
        /// Maps licensee address to total number of licenses they hold
        licensee_license_count: Map<ContractAddress, u32>, // licensee -> count
        // Royalty tracking (created during execution)
        /// Maps license ID to royalty payment tracking information
        royalty_info: Map<u256, RoyaltyInfo>, // license_id -> royalty info
        // Governance proposals for licensing
        /// Maps proposal ID to license proposal information
        license_proposals: Map<u256, LicenseProposal>,
        /// Maps (proposal_id, voter) to their vote (true=for, false=against)
        proposal_votes: Map<(u256, ContractAddress), bool>, // (proposal_id, voter) -> vote
        /// Maps proposal ID to the proposed license details
        proposed_licenses: Map<u256, LicenseInfo>, // (proposal_id) -> proposed license
        /// Maps proposal ID to proposed license terms
        proposal_terms: Map<u256, LicenseTerms>, // (proposal_id) -> proposed terms
        /// Global counter for generating unique proposal IDs
        next_proposal_id: u256,
        /// Maps (proposal_id, voter) to whether they have already voted
        has_voted: Map<(u256, ContractAddress), bool>,
        // Default terms
        /// Maps asset ID to default license terms for that asset
        default_license_terms: Map<u256, LicenseTerms>, // asset_id -> default terms
        /// Total number of assets created (for enumeration)
        total_assets: u256, // Track total number of assets created
        ///////////////////
        // Governance Storage
        ///////////////////

        /// Maps proposal ID to governance proposal details
        governance_proposals: Map<u256, GovernanceProposal>,
        /// Maps proposal ID to asset management proposal specifics
        asset_management_proposals: Map<u256, AssetManagementProposal>,
        /// Maps proposal ID to revenue policy proposal specifics
        revenue_policy_proposals: Map<u256, RevenuePolicyProposal>,
        /// Maps proposal ID to emergency proposal specifics
        emergency_proposals: Map<u256, EmergencyProposal>,
        /// Maps asset ID to governance settings (quorum, voting duration, etc.)
        governance_settings: Map<u256, GovernanceSettings>, // asset_id -> settings
        /// Maps (proposal_id, voter) to their governance vote
        governance_proposal_votes: Map<
            (u256, ContractAddress), bool,
        >, // (proposal_id, voter) -> vote
        /// Maps (proposal_id, voter) to whether they have voted on governance proposal
        governance_has_voted: Map<
            (u256, ContractAddress), bool,
        >, // (proposal_id, voter) -> has_voted
        /// Global counter for generating unique governance proposal IDs
        next_governance_proposal_id: u256,
        /// Maps (asset_id, index) to proposal ID for asset enumeration
        active_proposals_for_asset: Map<(u256, u32), u256>, // (asset_id, index) -> proposal_id
        /// Maps asset ID to number of active proposals
        active_proposal_count: Map<u256, u32>, // asset_id -> count
        ///////////////////
        // Compliance Storage
        ///////////////////

        /// Maps asset ID to compliance record including verification and protection status
        compliance_records: Map<u256, ComplianceRecord>, // asset_id -> record
        /// Maps authority address to their registration and authorization information
        compliance_authorities: Map<ContractAddress, ComplianceAuthority>, // authority -> info
        /// Maps country code to that country's compliance requirements
        country_requirements: Map<
            felt252, CountryComplianceRequirements,
        >, // country -> requirements
        /// Maps request ID to compliance verification request details
        compliance_verification_requests: Map<
            u256, ComplianceVerificationRequest,
        >, // request_id -> request
        /// Global counter for generating unique verification request IDs
        next_verification_request_id: u256,
        /// Maps (authority, index) to authorized country for enumeration
        authority_countries: Map<(ContractAddress, u32), felt252>, // (authority, index) -> country
        /// Maps (asset_id, index) to country with automatic protection
        automatic_protection_countries: Map<(u256, u32), felt252>, // (asset_id, index) -> country
        /// Maps (asset_id, index) to country requiring manual registration
        manual_registration_countries: Map<(u256, u32), felt252>, // (asset_id, index) -> country
        /// Maps (request_id, index) to author address for verification requests
        verification_authors: Map<(u256, u32), ContractAddress>, // (request_id, index) -> author
        /// Maps (authority, index) to pending request ID for enumeration
        authority_pending_requests: Map<
            (ContractAddress, u32), u256,
        >, // (authority, index) -> request_id
        /// Maps authority to number of pending requests
        authority_request_count: Map<ContractAddress, u32>, // authority -> count
        /// Maps (status, index) to asset ID for status-based enumeration
        assets_by_status: Map<(felt252, u32), u256>, // (status, index) -> asset_id
        /// Maps compliance status to number of assets with that status
        asset_status_count: Map<felt252, u32>, // status -> count
        /// Maps (asset_id, country) to protection status in that country
        international_protection: Map<(u256, felt252), bool> // (asset_id, country) -> protected
    }

    /// # Contract Events
    ///
    /// Comprehensive event system for tracking all contract activities across different functional
    /// domains.
    /// Events are emitted for ownership changes, asset management, revenue distribution, licensing
    /// actions, governance decisions, and compliance verification.
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        // Ownership Events
        CollectiveOwnershipRegistered: CollectiveOwnershipRegistered,
        IPOwnershipTransferred: IPOwnershipTransferred,
        // Asset Events
        AssetRegistered: AssetRegistered,
        MetadataUpdated: MetadataUpdated,
        // Revenue Events
        RevenueReceived: RevenueReceived,
        RevenueDistributed: RevenueDistributed,
        RevenueWithdrawn: RevenueWithdrawn,
        // Licensing Events
        LicenseOfferCreated: LicenseOfferCreated,
        LicenseApproved: LicenseApproved,
        LicenseExecuted: LicenseExecuted,
        LicenseRevoked: LicenseRevoked,
        LicenseSuspended: LicenseSuspended,
        LicenseTransferred: LicenseTransferred,
        RoyaltyPaid: RoyaltyPaid,
        UsageReported: UsageReported,
        LicenseProposalCreated: LicenseProposalCreated,
        LicenseProposalVoted: LicenseProposalVoted,
        LicenseProposalExecuted: LicenseProposalExecuted,
        LicenseReactivated: LicenseReactivated,
        // Governance Events
        GovernanceProposalCreated: GovernanceProposalCreated,
        ProposalQuorumReached: ProposalQuorumReached,
        AssetManagementExecuted: AssetManagementExecuted,
        RevenuePolicyUpdated: RevenuePolicyUpdated,
        EmergencyActionExecuted: EmergencyActionExecuted,
        GovernanceSettingsUpdated: GovernanceSettingsUpdated,
        // Compliance Events
        ComplianceVerificationRequested: ComplianceVerificationRequested,
        ComplianceVerified: ComplianceVerified,
        ComplianceAuthorityRegistered: ComplianceAuthorityRegistered,
        ProtectionRenewalRequired: ProtectionRenewalRequired,
        ProtectionExpired: ProtectionExpired,
        CrossBorderProtectionUpdated: CrossBorderProtectionUpdated,
    }

    /// # Contract Constructor
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, base_uri: ByteArray) {
        self.ownable.initializer(owner);
        self.erc1155.initializer(base_uri);
        self.next_asset_id.write(1);
        self.paused.write(false);
        self.next_license_id.write(1);
        self.next_proposal_id.write(1);
        self.total_assets.write(0);
        self.next_governance_proposal_id.write(1);
        self.next_verification_request_id.write(1);
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

            // Store individual owner data
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
                total_supply: STANDARD_INITIAL_SUPPLY, // Standard initial supply for IP tokens
                creation_timestamp: get_block_timestamp(),
                is_verified: false,
                compliance_status: ComplianceStatus::Pending.into(),
            };

            self.asset_info.write(asset_id, asset_info);

            let current_total = self.total_assets.read();
            self.total_assets.write(current_total + 1);

            // Store creators
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
                let token_amount = (STANDARD_INITIAL_SUPPLY * percentage)
                    / 100; // Calculate based on percentage

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

    #[abi(embed_v0)]
    impl LicenseManagerImpl of ILicenseManager<ContractState> {
        fn create_license_request(
            ref self: ContractState,
            asset_id: u256,
            licensee: ContractAddress,
            license_type: felt252,
            usage_rights: felt252,
            territory: felt252,
            license_fee: u256,
            royalty_rate: u256,
            duration_seconds: u64,
            payment_token: ContractAddress,
            terms: LicenseTerms,
            metadata_uri: ByteArray,
        ) -> u256 {
            assert!(!self.paused.read(), "Contract is paused");
            assert(self.verify_asset_ownership(asset_id), 'Asset does not exist');
            assert!(licensee.is_non_zero(), "Invalid licensee address");
            assert!(royalty_rate <= 10000, "Royalty rate cannot exceed 100%");

            let caller = get_caller_address();
            // Only asset owners can create license offers
            assert!(self.is_owner(asset_id, caller), "Only asset owners can create license offers");

            let license_id = self.next_license_id.read();
            self.next_license_id.write(license_id + 1);

            let current_time = get_block_timestamp();
            let end_timestamp = if duration_seconds == 0 {
                0 // Perpetual license
            } else {
                current_time + duration_seconds
            };

            // Determine if governance approval is required for high-value licenses
            let requires_approval = self
                ._requires_governance_approval(asset_id, license_type, license_fee);

            let license_info = LicenseInfo {
                license_id,
                asset_id,
                licensor: caller,
                licensee,
                license_type,
                usage_rights,
                territory,
                license_fee,
                royalty_rate,
                start_timestamp: current_time,
                end_timestamp,
                is_active: false, // Never auto-activate - licensee must execute
                requires_approval, // May require governance approval
                is_approved: !requires_approval, // Auto-approve if no governance needed
                payment_token,
                metadata_uri: metadata_uri.clone(),
                is_suspended: false,
                suspension_end_timestamp: 0,
            };

            // Store license info and terms
            self.license_info.write(license_id, license_info);
            self.license_terms.write(license_id, terms);

            // Update asset licenses mapping only
            let asset_license_count = self.asset_license_count.read(asset_id);
            self.asset_licenses.write((asset_id, asset_license_count), license_id);
            self.asset_license_count.write(asset_id, asset_license_count + 1);

            self
                .emit(
                    LicenseOfferCreated {
                        license_id,
                        asset_id,
                        licensee,
                        license_type,
                        license_fee,
                        requires_approval,
                        timestamp: current_time,
                    },
                );

            license_id
        }

        fn approve_license(ref self: ContractState, license_id: u256, approve: bool) -> bool {
            let caller = get_caller_address();
            let mut license_info = self.license_info.read(license_id);

            assert!(license_info.license_id != 0, "License does not exist");
            assert!(license_info.requires_approval, "License does not require approval");
            assert!(!license_info.is_approved, "License already processed");

            // Check if caller has authority to approve
            assert!(
                self.is_owner(license_info.asset_id, caller),
                "Only asset owners can approve licenses",
            );

            license_info.is_approved = approve;

            self.license_info.write(license_id, license_info);

            self
                .emit(
                    LicenseApproved {
                        license_id,
                        approved_by: caller,
                        approved: approve,
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn execute_license(ref self: ContractState, license_id: u256) -> bool {
            let caller = get_caller_address();
            let mut license_info = self.license_info.read(license_id);

            assert!(license_info.license_id != 0, "License does not exist");
            assert!(
                caller == license_info.licensee, "Only designated licensee can execute license",
            );
            assert!(license_info.is_approved, "License not approved");
            assert!(!license_info.is_active, "License already active");

            // Check if license is not expired
            let current_time = get_block_timestamp();
            if license_info.end_timestamp != 0 {
                assert!(current_time < license_info.end_timestamp, "License has expired");
            }

            // Process payment from licensee
            if license_info.license_fee > 0 {
                self._process_license_payment(license_id);
            }

            // Activate the license
            license_info.is_active = true;
            self.license_info.write(license_id, license_info.clone());

            // Update licensee mappings
            let licensee_license_count = self.licensee_license_count.read(license_info.licensee);
            self
                .licensee_licenses
                .write((license_info.licensee, licensee_license_count), license_id);
            self.licensee_license_count.write(license_info.licensee, licensee_license_count + 1);

            // initialize royalty tracking
            let royalty_info = RoyaltyInfo {
                asset_id: license_info.asset_id,
                licensee: license_info.licensee,
                total_revenue_reported: 0,
                total_royalties_paid: 0,
                last_payment_timestamp: 0,
                payment_frequency: THIRTY_DAYS, // 30 days default
                next_payment_due: current_time + THIRTY_DAYS,
            };
            self.royalty_info.write(license_id, royalty_info);

            self
                .emit(
                    LicenseExecuted {
                        license_id,
                        licensee: license_info.licensee,
                        executed_by: caller,
                        timestamp: current_time,
                    },
                );

            true
        }

        fn revoke_license(ref self: ContractState, license_id: u256, reason: ByteArray) -> bool {
            let caller = get_caller_address();
            let mut license_info = self.license_info.read(license_id);

            assert!(license_info.license_id != 0, "License does not exist");
            assert!(license_info.is_active, "License not active");

            // Only asset owners can revoke
            assert!(
                self.is_owner(license_info.asset_id, caller),
                "Only asset owners can revoke licenses",
            );

            license_info.is_active = false;
            self.license_info.write(license_id, license_info);

            self
                .emit(
                    LicenseRevoked {
                        license_id,
                        revoked_by: caller,
                        reason: reason.clone(),
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn suspend_license(
            ref self: ContractState, license_id: u256, suspension_duration: u64,
        ) -> bool {
            let caller = get_caller_address();
            let mut license_info = self.license_info.read(license_id);
            let current_time = get_block_timestamp();

            assert!(license_info.license_id != 0, "License does not exist");
            assert!(license_info.is_active, "License not active");

            // Only asset owners can suspend
            assert!(
                self.is_owner(license_info.asset_id, caller),
                "Only asset owners can suspend licenses",
            );

            // Temporarily deactivate
            license_info.is_active = false;
            license_info.is_suspended = true;
            license_info.suspension_end_timestamp = current_time + suspension_duration;
            self.license_info.write(license_id, license_info);

            self
                .emit(
                    LicenseSuspended {
                        license_id,
                        suspended_by: caller,
                        suspension_duration,
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn transfer_license(
            ref self: ContractState, license_id: u256, new_licensee: ContractAddress,
        ) -> bool {
            let caller = get_caller_address();
            let mut license_info = self.license_info.read(license_id);

            assert!(license_info.license_id != 0, "License does not exist");
            assert!(caller == license_info.licensee, "Only licensee can transfer");
            assert!(new_licensee.is_non_zero(), "Invalid new licensee");
            assert!(license_info.is_active, "License must be active to transfer");

            let old_licensee = license_info.licensee;
            license_info.licensee = new_licensee;
            self.license_info.write(license_id, license_info);

            // Update licensee mappings
            let new_licensee_count = self.licensee_license_count.read(new_licensee);
            self.licensee_licenses.write((new_licensee, new_licensee_count), license_id);
            self.licensee_license_count.write(new_licensee, new_licensee_count + 1);

            // Update royalty info
            let mut royalty_info = self.royalty_info.read(license_id);
            royalty_info.licensee = new_licensee;
            self.royalty_info.write(license_id, royalty_info);

            self
                .emit(
                    LicenseTransferred {
                        license_id, old_licensee, new_licensee, timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn report_usage_revenue(
            ref self: ContractState, license_id: u256, revenue_amount: u256, usage_count: u256,
        ) -> bool {
            let caller = get_caller_address();
            let license_info = self.license_info.read(license_id);

            assert!(license_info.license_id != 0, "License does not exist");
            assert!(caller == license_info.licensee, "Only licensee can report usage");
            assert!(license_info.is_active, "License not active");

            // Update usage tracking
            let mut terms = self.license_terms.read(license_id);
            terms.current_usage_count += usage_count;

            // Check usage limits
            if terms.max_usage_count > 0 {
                assert!(terms.current_usage_count <= terms.max_usage_count, "Usage limit exceeded");
            }

            self.license_terms.write(license_id, terms);

            // Update royalty tracking
            let mut royalty_info = self.royalty_info.read(license_id);
            royalty_info.total_revenue_reported += revenue_amount;
            self.royalty_info.write(license_id, royalty_info);

            self
                .emit(
                    UsageReported {
                        license_id,
                        reporter: caller,
                        revenue_amount,
                        usage_count,
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn pay_royalties(ref self: ContractState, license_id: u256, amount: u256) -> bool {
            let caller = get_caller_address();
            let license_info = self.license_info.read(license_id);

            assert!(license_info.license_id != 0, "License does not exist");
            assert!(caller == license_info.licensee, "Only licensee can pay royalties");
            assert!(amount > 0, "Amount must be greater than zero");

            // Transfer payment to contract
            if !license_info.payment_token.is_zero() {
                let erc20 = IERC20Dispatcher { contract_address: license_info.payment_token };
                let success = erc20.transfer_from(caller, get_contract_address(), amount);
                assert!(success, "Payment transfer failed");
            }

            // Update royalty tracking
            let mut royalty_info = self.royalty_info.read(license_id);
            royalty_info.total_royalties_paid += amount;
            royalty_info.last_payment_timestamp = get_block_timestamp();
            royalty_info.next_payment_due = get_block_timestamp() + royalty_info.payment_frequency;
            self.royalty_info.write(license_id, royalty_info);

            // Distribute royalties to asset owners
            self._distribute_royalties(license_info.asset_id, license_info.payment_token, amount);

            self
                .emit(
                    RoyaltyPaid {
                        license_id, payer: caller, amount, timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn calculate_due_royalties(self: @ContractState, license_id: u256) -> u256 {
            let license_info = self.license_info.read(license_id);
            let royalty_info = self.royalty_info.read(license_id);

            if license_info.royalty_rate == 0 {
                return 0;
            }

            // Calculate based on reported revenue
            let total_royalties_due = (royalty_info.total_revenue_reported
                * license_info.royalty_rate)
                / 10000;

            if total_royalties_due > royalty_info.total_royalties_paid {
                total_royalties_due - royalty_info.total_royalties_paid
            } else {
                0
            }
        }

        fn check_and_reactivate_license(ref self: ContractState, license_id: u256) -> bool {
            let mut license_info = self.license_info.read(license_id);

            if !license_info.is_suspended {
                return false; // Not suspended
            }

            let current_time = get_block_timestamp();
            if current_time >= license_info.suspension_end_timestamp {
                // Suspension period ended, reactivate
                license_info.is_active = true;
                license_info.is_suspended = false;
                license_info.suspension_end_timestamp = 0;
                self.license_info.write(license_id, license_info);

                self
                    .emit(
                        LicenseReactivated {
                            license_id,
                            reactivated_by: get_caller_address(),
                            timestamp: current_time,
                        },
                    );

                return true;
            }

            false
        }

        fn reactivate_suspended_license(ref self: ContractState, license_id: u256) -> bool {
            let caller = get_caller_address();
            let mut license_info = self.license_info.read(license_id);

            assert!(license_info.license_id != 0, "License does not exist");
            assert!(license_info.is_suspended, "License is not suspended");
            assert!(
                self.is_owner(license_info.asset_id, caller),
                "Only asset owners can manually reactivate",
            );

            // Manual reactivation by owner, ignores suspension time
            license_info.is_active = true;
            license_info.is_suspended = false;
            license_info.suspension_end_timestamp = 0;
            self.license_info.write(license_id, license_info);

            self
                .emit(
                    LicenseReactivated {
                        license_id, reactivated_by: caller, timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn get_license_status(self: @ContractState, license_id: u256) -> felt252 {
            let license_info = self.license_info.read(license_id);

            if license_info.license_id == 0 {
                return 'NOT_FOUND';
            }

            if !license_info.is_approved {
                return 'PENDING_APPROVAL';
            }

            if !license_info.is_active && !license_info.is_suspended {
                return 'INACTIVE';
            }

            if license_info.is_suspended {
                let current_time = get_block_timestamp();
                if current_time >= license_info.suspension_end_timestamp {
                    return 'SUSPENSION_EXPIRED'; // Can be reactivated
                } else {
                    return 'SUSPENDED';
                }
            }

            // Check expiration
            let current_time = get_block_timestamp();
            if license_info.end_timestamp != 0 && current_time >= license_info.end_timestamp {
                return 'EXPIRED';
            }

            'ACTIVE'
        }

        fn get_license_info(self: @ContractState, license_id: u256) -> LicenseInfo {
            self.license_info.read(license_id)
        }

        fn get_license_terms(self: @ContractState, license_id: u256) -> LicenseTerms {
            self.license_terms.read(license_id)
        }

        fn get_asset_licenses(self: @ContractState, asset_id: u256) -> Array<u256> {
            let license_count = self.asset_license_count.read(asset_id);
            let mut licenses = ArrayTrait::new();
            let mut i = 0;

            loop {
                if i >= license_count {
                    break;
                }
                let license_id = self.asset_licenses.read((asset_id, i));
                licenses.append(license_id);
                i += 1;
            };

            licenses
        }

        fn get_licensee_licenses(self: @ContractState, licensee: ContractAddress) -> Array<u256> {
            let license_count = self.licensee_license_count.read(licensee);
            let mut licenses = ArrayTrait::new();
            let mut i = 0;

            loop {
                if i >= license_count {
                    break;
                }
                let license_id = self.licensee_licenses.read((licensee, i));
                licenses.append(license_id);
                i += 1;
            };

            licenses
        }

        fn is_license_valid(self: @ContractState, license_id: u256) -> bool {
            let license_info = self.license_info.read(license_id);

            if license_info.license_id == 0
                || !license_info.is_active
                || !license_info.is_approved {
                return false;
            }

            // Check expiration
            let current_time = get_block_timestamp();
            if license_info.end_timestamp != 0 && current_time >= license_info.end_timestamp {
                return false;
            }

            // Check usage limits
            let terms = self.license_terms.read(license_id);
            if terms.max_usage_count > 0 && terms.current_usage_count > terms.max_usage_count {
                return false;
            }

            true
        }

        fn get_royalty_info(self: @ContractState, license_id: u256) -> RoyaltyInfo {
            self.royalty_info.read(license_id)
        }

        fn get_license_proposal(self: @ContractState, proposal_id: u256) -> LicenseProposal {
            self.license_proposals.read(proposal_id)
        }

        fn get_proposed_license(self: @ContractState, proposal_id: u256) -> LicenseInfo {
            self.proposed_licenses.read(proposal_id)
        }

        fn get_available_licenses(self: @ContractState, asset_id: u256) -> Array<u256> {
            let license_count = self.asset_license_count.read(asset_id);
            let mut available_licenses = ArrayTrait::new();
            let mut i = 0;

            loop {
                if i >= license_count {
                    break;
                }
                let license_id = self.asset_licenses.read((asset_id, i));
                let license_info = self.license_info.read(license_id);

                // Include licenses that are approved but not yet active - available for execution
                if license_info.is_approved && !license_info.is_active {
                    // Also check if not expired
                    let current_time = get_block_timestamp();
                    if license_info.end_timestamp == 0
                        || current_time < license_info.end_timestamp {
                        available_licenses.append(license_id);
                    }
                }
                i += 1;
            };

            available_licenses
        }

        fn get_pending_licenses_for_licensee(
            self: @ContractState, licensee: ContractAddress,
        ) -> Array<u256> {
            let mut pending_licenses = ArrayTrait::new();
            let total_assets = self.total_assets.read();

            let mut asset_id = 1;
            loop {
                if asset_id > total_assets {
                    break;
                }

                let available_licenses = self.get_available_licenses(asset_id);
                let mut i = 0;
                loop {
                    if i >= available_licenses.len() {
                        break;
                    }
                    let license_id = *available_licenses.at(i);
                    let license_info = self.license_info.read(license_id);

                    if license_info.licensee == licensee {
                        pending_licenses.append(license_id);
                    }
                    i += 1;
                };

                asset_id += 1;
            };

            pending_licenses
        }

        fn set_default_license_terms(
            ref self: ContractState, asset_id: u256, terms: LicenseTerms,
        ) -> bool {
            let caller = get_caller_address();
            assert!(self.is_owner(asset_id, caller), "Only asset owners can set default terms");

            self.default_license_terms.write(asset_id, terms);
            true
        }

        fn propose_license_terms(
            ref self: ContractState,
            asset_id: u256,
            proposed_license: LicenseInfo,
            voting_duration: u64,
        ) -> u256 {
            let caller = get_caller_address();
            assert!(self.is_owner(asset_id, caller), "Only asset owners can propose licenses");
            assert(self.verify_asset_ownership(asset_id), 'Asset does not exist');

            let proposal_id = self.next_proposal_id.read();
            self.next_proposal_id.write(proposal_id + 1);

            let current_time = get_block_timestamp();
            let voting_deadline = current_time + voting_duration;
            let execution_deadline = voting_deadline + 86400; // 24 hours after voting ends

            let proposal = LicenseProposal {
                proposal_id,
                asset_id,
                proposer: caller,
                votes_for: 0,
                votes_against: 0,
                voting_deadline,
                execution_deadline,
                is_executed: false,
                is_cancelled: false,
            };

            self.license_proposals.write(proposal_id, proposal);

            // Store the proposed license
            self.proposed_licenses.write(proposal_id, proposed_license);

            // Store default terms for this proposal
            let default_terms = self.default_license_terms.read(asset_id);
            self.proposal_terms.write(proposal_id, default_terms);

            self
                .emit(
                    LicenseProposalCreated {
                        proposal_id,
                        asset_id,
                        proposer: caller,
                        voting_deadline,
                        timestamp: current_time,
                    },
                );

            proposal_id
        }

        fn vote_on_license_proposal(
            ref self: ContractState, proposal_id: u256, vote_for: bool,
        ) -> bool {
            let caller = get_caller_address();
            let mut proposal = self.license_proposals.read(proposal_id);

            assert!(proposal.proposal_id != 0, "Proposal does not exist");
            assert!(!proposal.is_executed, "Proposal already executed");
            assert!(!proposal.is_cancelled, "Proposal cancelled");
            assert!(get_block_timestamp() < proposal.voting_deadline, "Voting period ended");

            let asset_id = proposal.asset_id;
            assert!(self.is_owner(asset_id, caller), "Only asset owners can vote");

            // Update vote function:
            let has_already_voted = self.has_voted.read((proposal_id, caller));
            assert!(!has_already_voted, "Already voted on this proposal");

            self.has_voted.write((proposal_id, caller), true);
            self.proposal_votes.write((proposal_id, caller), vote_for);

            // Get voting weight
            let voting_weight = self.get_governance_weight(asset_id, caller);

            if vote_for {
                proposal.votes_for += voting_weight;
            } else {
                proposal.votes_against += voting_weight;
            }

            self.license_proposals.write(proposal_id, proposal);

            self
                .emit(
                    LicenseProposalVoted {
                        proposal_id,
                        voter: caller,
                        vote_for,
                        voting_weight,
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn execute_license_proposal(ref self: ContractState, proposal_id: u256) -> bool {
            let caller = get_caller_address();
            let mut proposal = self.license_proposals.read(proposal_id);

            assert!(proposal.proposal_id != 0, "Proposal does not exist");
            assert!(!proposal.is_executed, "Proposal already executed");
            assert!(!proposal.is_cancelled, "Proposal cancelled");

            let current_time = get_block_timestamp();
            assert!(current_time > proposal.voting_deadline, "Voting period not ended");
            assert!(current_time <= proposal.execution_deadline, "Execution period expired");

            // Check if proposal passed (simple majority)
            assert!(proposal.votes_for > proposal.votes_against, "Proposal did not pass");

            // Get the proposed license
            let mut proposed_license = self.proposed_licenses.read(proposal_id);
            let license_id = self.next_license_id.read();

            // Update the proposed license with execution details
            proposed_license.license_id = license_id;
            proposed_license.licensor = proposal.proposer;
            proposed_license.is_approved = true; // Approved through governance
            proposed_license.is_active = false; // Still needs execution by licensee
            proposed_license.is_suspended = false;
            proposed_license.suspension_end_timestamp = 0;

            self.next_license_id.write(license_id + 1);
            self.license_info.write(license_id, proposed_license);

            let proposal_terms = self.proposal_terms.read(proposal_id);
            self.license_terms.write(license_id, proposal_terms);

            // Update asset mappings
            let asset_license_count = self.asset_license_count.read(proposal.asset_id);
            self.asset_licenses.write((proposal.asset_id, asset_license_count), license_id);
            self.asset_license_count.write(proposal.asset_id, asset_license_count + 1);

            // Mark proposal as executed
            proposal.is_executed = true;
            self.license_proposals.write(proposal_id, proposal);

            self
                .emit(
                    LicenseProposalExecuted {
                        proposal_id, license_id, executed_by: caller, timestamp: current_time,
                    },
                );

            true
        }
    }

    #[abi(embed_v0)]
    impl GovernanceImpl of IGovernance<ContractState> {
        fn set_governance_settings(
            ref self: ContractState, asset_id: u256, settings: GovernanceSettings,
        ) -> bool {
            let caller = get_caller_address();
            assert!(
                self.is_owner(asset_id, caller), "Only asset owners can set governance settings",
            );

            // Validate settings
            assert!(settings.default_quorum_percentage <= 10000, "Quorum cannot exceed 100%");
            assert!(
                settings.emergency_quorum_percentage <= settings.default_quorum_percentage,
                "Emergency quorum cannot be higher than default",
            );
            assert!(settings.execution_delay >= 3600, "Execution delay must be at least 1 hour");

            self.governance_settings.write(asset_id, settings);

            self
                .emit(
                    GovernanceSettingsUpdated {
                        asset_id, updated_by: caller, timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn get_governance_settings(self: @ContractState, asset_id: u256) -> GovernanceSettings {
            let settings = self.governance_settings.read(asset_id);

            // Return default settings if none set
            if settings.default_quorum_percentage == 0 {
                GovernanceSettings {
                    default_quorum_percentage: 5000, // 50%
                    emergency_quorum_percentage: 3000, // 30%
                    license_quorum_percentage: 4000, // 40%
                    asset_mgmt_quorum_percentage: 6000, // 60%
                    revenue_policy_quorum_percentage: 5500, // 55%
                    default_voting_duration: 259200, // 3 days
                    emergency_voting_duration: 86400, // 1 day
                    execution_delay: 86400 // 1 day
                }
            } else {
                settings
            }
        }

        fn propose_asset_management(
            ref self: ContractState,
            asset_id: u256,
            proposal_data: AssetManagementProposal,
            voting_duration: u64,
            description: ByteArray,
        ) -> u256 {
            let caller = get_caller_address();
            assert!(self.is_owner(asset_id, caller), "Only asset owners can create proposals");
            assert(self.verify_asset_ownership(asset_id), 'Asset does not exist');

            let proposal_id = self
                ._create_governance_proposal(
                    asset_id,
                    ProposalType::AssetManagement.into(),
                    caller,
                    voting_duration,
                    description,
                );

            self.asset_management_proposals.write(proposal_id, proposal_data);
            proposal_id
        }

        fn propose_revenue_policy(
            ref self: ContractState,
            asset_id: u256,
            proposal_data: RevenuePolicyProposal,
            voting_duration: u64,
            description: ByteArray,
        ) -> u256 {
            let caller = get_caller_address();
            assert!(self.is_owner(asset_id, caller), "Only asset owners can create proposals");
            assert(self.verify_asset_ownership(asset_id), 'Asset does not exist');

            let proposal_id = self
                ._create_governance_proposal(
                    asset_id,
                    ProposalType::RevenuePolicy.into(),
                    caller,
                    voting_duration,
                    description,
                );

            self.revenue_policy_proposals.write(proposal_id, proposal_data);
            proposal_id
        }

        fn propose_emergency_action(
            ref self: ContractState,
            asset_id: u256,
            proposal_data: EmergencyProposal,
            description: ByteArray,
        ) -> u256 {
            let caller = get_caller_address();
            assert!(
                self.is_owner(asset_id, caller), "Only asset owners can create emergency proposals",
            );
            assert(self.verify_asset_ownership(asset_id), 'Asset does not exist');

            let settings = self.get_governance_settings(asset_id);

            let proposal_id = self
                ._create_governance_proposal(
                    asset_id,
                    ProposalType::Emergency.into(),
                    caller,
                    settings.emergency_voting_duration,
                    description,
                );

            self.emergency_proposals.write(proposal_id, proposal_data);
            proposal_id
        }

        fn vote_on_governance_proposal(
            ref self: ContractState, proposal_id: u256, vote_for: bool,
        ) -> bool {
            let caller = get_caller_address();
            let mut proposal = self.governance_proposals.read(proposal_id);

            assert!(proposal.proposal_id != 0, "Proposal does not exist");
            assert!(!proposal.is_executed, "Proposal already executed");
            assert!(!proposal.is_cancelled, "Proposal cancelled");
            assert!(get_block_timestamp() < proposal.voting_deadline, "Voting period ended");

            let asset_id = proposal.asset_id;
            assert!(self.is_owner(asset_id, caller), "Only asset owners can vote");

            // Prevent double voting
            let has_already_voted = self.governance_has_voted.read((proposal_id, caller));
            assert!(!has_already_voted, "Already voted on this proposal");

            self.governance_has_voted.write((proposal_id, caller), true);
            self.governance_proposal_votes.write((proposal_id, caller), vote_for);

            // Get voting weight
            let voting_weight = self.get_governance_weight(asset_id, caller);

            if vote_for {
                proposal.votes_for += voting_weight;
            } else {
                proposal.votes_against += voting_weight;
            }

            self.governance_proposals.write(proposal_id, proposal.clone());

            // Check if quorum reached
            let total_votes = proposal.votes_for + proposal.votes_against;
            if total_votes >= proposal.quorum_required {
                self
                    .emit(
                        ProposalQuorumReached {
                            proposal_id,
                            total_votes,
                            quorum_required: proposal.quorum_required,
                            timestamp: get_block_timestamp(),
                        },
                    );
            }

            true
        }

        fn execute_asset_management_proposal(ref self: ContractState, proposal_id: u256) -> bool {
            let caller = get_caller_address();
            assert!(self._can_execute_proposal(proposal_id), "Cannot execute proposal");

            let proposal = self.governance_proposals.read(proposal_id);
            let proposal_data = self.asset_management_proposals.read(proposal_id);

            // Mark as executed
            let mut updated_proposal = proposal.clone();
            updated_proposal.is_executed = true;
            self.governance_proposals.write(proposal_id, updated_proposal);

            // Execute the proposal
            let mut metadata_updated = false;
            let mut compliance_updated = false;

            if proposal_data.update_metadata {
                let mut asset_info = self.asset_info.read(proposal.asset_id.clone());
                asset_info.metadata_uri = proposal_data.new_metadata_uri.clone();
                self.asset_info.write(proposal.asset_id.clone(), asset_info);
                metadata_updated = true;
            }

            if proposal_data.update_compliance {
                let mut asset_info = self.asset_info.read(proposal.asset_id.clone());
                asset_info.compliance_status = proposal_data.new_compliance_status;
                self.asset_info.write(proposal.asset_id.clone(), asset_info);
                compliance_updated = true;
            }

            self
                .emit(
                    AssetManagementExecuted {
                        proposal_id,
                        asset_id: proposal.asset_id,
                        metadata_updated,
                        compliance_updated,
                        executed_by: caller,
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn execute_revenue_policy_proposal(ref self: ContractState, proposal_id: u256) -> bool {
            let caller = get_caller_address();
            assert!(self._can_execute_proposal(proposal_id), "Cannot execute proposal");

            let proposal = self.governance_proposals.read(proposal_id);
            let proposal_data = self.revenue_policy_proposals.read(proposal_id);

            // Mark as executed
            let mut updated_proposal = proposal.clone();
            updated_proposal.is_executed = true;
            self.governance_proposals.write(proposal_id, updated_proposal);

            // Update revenue settings
            let mut revenue_info = self
                .revenue_info
                .read((proposal.asset_id.clone(), proposal_data.token_address));
            revenue_info.minimum_distribution = proposal_data.new_minimum_distribution;
            self
                .revenue_info
                .write((proposal.asset_id.clone(), proposal_data.token_address), revenue_info);

            self
                .emit(
                    RevenuePolicyUpdated {
                        proposal_id,
                        asset_id: proposal.asset_id.clone(),
                        token_address: proposal_data.token_address,
                        new_minimum_distribution: proposal_data.new_minimum_distribution,
                        executed_by: caller,
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn execute_emergency_proposal(ref self: ContractState, proposal_id: u256) -> bool {
            let caller = get_caller_address();
            assert!(self._can_execute_proposal(proposal_id), "Cannot execute proposal");

            let proposal = self.governance_proposals.read(proposal_id);
            let proposal_data = self.emergency_proposals.read(proposal_id);

            // Mark as executed
            let mut updated_proposal = proposal.clone();
            updated_proposal.is_executed = true;
            self.governance_proposals.write(proposal_id, updated_proposal);

            // Execute emergency action
            if proposal_data.action_type == 'SUSPEND_LICENSE' {
                // Suspend the license
                let mut license_info = self.license_info.read(proposal_data.target_id);
                let license_info_copy = license_info.clone();
                if license_info_copy.license_id != 0 && license_info_copy.is_active {
                    license_info.is_active = false;
                    license_info.is_suspended = true;
                    license_info.suspension_end_timestamp = get_block_timestamp()
                        + proposal_data.suspension_duration;
                    self.license_info.write(proposal_data.target_id, license_info);
                }
            } else if proposal_data.action_type == 'SUSPEND_ASSET' {
                // Suspend all licenses for the asset
                let asset_license_count = self.asset_license_count.read(proposal.asset_id);
                let mut i = 0;
                loop {
                    if i >= asset_license_count {
                        break;
                    }
                    let license_id = self.asset_licenses.read((proposal.asset_id, i));
                    let mut license_info = self.license_info.read(license_id);
                    let license_info_copy = license_info.clone();
                    if license_info_copy.is_active {
                        license_info.is_active = false;
                        license_info.is_suspended = true;
                        license_info.suspension_end_timestamp = get_block_timestamp()
                            + proposal_data.suspension_duration;
                        self.license_info.write(license_id, license_info);
                    }
                    i += 1;
                };
            }

            self
                .emit(
                    EmergencyActionExecuted {
                        proposal_id,
                        action_type: proposal_data.action_type,
                        target_id: proposal_data.target_id,
                        executed_by: caller,
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn get_governance_proposal(self: @ContractState, proposal_id: u256) -> GovernanceProposal {
            self.governance_proposals.read(proposal_id)
        }

        fn get_asset_management_proposal(
            self: @ContractState, proposal_id: u256,
        ) -> AssetManagementProposal {
            self.asset_management_proposals.read(proposal_id)
        }

        fn get_revenue_policy_proposal(
            self: @ContractState, proposal_id: u256,
        ) -> RevenuePolicyProposal {
            self.revenue_policy_proposals.read(proposal_id)
        }

        fn get_emergency_proposal(self: @ContractState, proposal_id: u256) -> EmergencyProposal {
            self.emergency_proposals.read(proposal_id)
        }

        fn check_quorum_reached(self: @ContractState, proposal_id: u256) -> bool {
            let proposal = self.governance_proposals.read(proposal_id);
            let total_votes = proposal.votes_for + proposal.votes_against;
            total_votes >= proposal.quorum_required
        }

        fn get_proposal_participation_rate(self: @ContractState, proposal_id: u256) -> u256 {
            let proposal = self.governance_proposals.read(proposal_id);
            let total_votes = proposal.votes_for + proposal.votes_against;
            if proposal.total_voting_weight == 0 {
                0
            } else {
                (total_votes * 10000) / proposal.total_voting_weight // Return as basis points
            }
        }

        fn can_execute_proposal(self: @ContractState, proposal_id: u256) -> bool {
            self._can_execute_proposal(proposal_id)
        }

        fn get_active_proposals_for_asset(self: @ContractState, asset_id: u256) -> Array<u256> {
            let proposal_count = self.active_proposal_count.read(asset_id);
            let mut proposals = ArrayTrait::new();
            let mut i = 0;

            loop {
                if i >= proposal_count {
                    break;
                }
                let proposal_id = self.active_proposals_for_asset.read((asset_id, i));
                let proposal = self.governance_proposals.read(proposal_id);

                // Only include non-executed, non-cancelled proposals
                if !proposal.is_executed && !proposal.is_cancelled {
                    proposals.append(proposal_id);
                }
                i += 1;
            };

            proposals
        }
    }

    #[abi(embed_v0)]
    impl BerneComplianceImpl of IBerneCompliance<ContractState> {
        fn register_compliance_authority(
            ref self: ContractState,
            authority_address: ContractAddress,
            authority_name: ByteArray,
            authorized_countries: Span<felt252>,
            authority_type: felt252,
            credentials_uri: ByteArray,
        ) -> bool {
            // Only contract owner can register authorities initially
            self.only_owner();

            assert!(authority_address.is_non_zero(), "Invalid authority address");
            assert!(
                authority_type == 'GOVERNMENT'
                    || authority_type == 'CERTIFIED_ORG'
                    || authority_type == 'LEGAL_EXPERT',
                "Invalid authority type",
            );

            let authority = ComplianceAuthority {
                authority_address,
                authority_name: authority_name.clone(),
                authorized_countries_count: authorized_countries.len(),
                authority_type,
                is_active: true,
                verification_count: 0,
                registration_timestamp: get_block_timestamp(),
                credentials_uri: credentials_uri.clone(),
            };

            self.compliance_authorities.write(authority_address, authority);
            let mut i = 0;
            loop {
                if i >= authorized_countries.len() {
                    break;
                }
                self.authority_countries.write((authority_address, i), *authorized_countries.at(i));
                i += 1;
            };

            self
                .emit(
                    ComplianceAuthorityRegistered {
                        authority_address,
                        authority_name,
                        authority_type,
                        authorized_countries_count: authorized_countries.len(),
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn deactivate_compliance_authority(
            ref self: ContractState, authority_address: ContractAddress,
        ) -> bool {
            self.only_owner();

            let mut authority = self.compliance_authorities.read(authority_address);
            assert!(authority.authority_address.is_non_zero(), "Authority not found");

            authority.is_active = false;
            self.compliance_authorities.write(authority_address, authority);

            true
        }

        fn get_compliance_authority(
            self: @ContractState, authority_address: ContractAddress,
        ) -> ComplianceAuthority {
            self.compliance_authorities.read(authority_address)
        }

        fn is_authorized_for_country(
            self: @ContractState, authority_address: ContractAddress, country_code: felt252,
        ) -> bool {
            let authority = self.compliance_authorities.read(authority_address);
            if !authority.is_active {
                return false;
            }

            let mut res = false;
            let mut i = 0;
            while i <= authority.authorized_countries_count {
                let country = self.authority_countries.read((authority_address, i));
                if country == country_code {
                    res = true;
                }
                i += 1;
            };

            res
        }

        fn set_country_requirements(
            ref self: ContractState,
            country_code: felt252,
            requirements: CountryComplianceRequirements,
        ) -> bool {
            self.only_owner();

            assert!(country_code != 0, "Invalid country code");
            self.country_requirements.write(country_code, requirements);

            true
        }

        fn get_country_requirements(
            self: @ContractState, country_code: felt252,
        ) -> CountryComplianceRequirements {
            let requirements = self.country_requirements.read(country_code);

            // Return default if not set (assumes Berne Convention standards)
            if requirements.country_code == 0 {
                CountryComplianceRequirements {
                    country_code,
                    is_berne_signatory: true,
                    automatic_protection: true,
                    registration_required: false,
                    protection_duration_years: 70, // Life + 70 years (modern standard)
                    notice_required: false,
                    deposit_required: false,
                    translation_rights_duration: 10,
                    moral_rights_protected: true,
                }
            } else {
                requirements
            }
        }

        fn get_berne_signatory_countries(self: @ContractState) -> Span<felt252> {
            // TODO: form a comprehensive list
            array![
                'US',
                'UK',
                'FR',
                'DE',
                'JP',
                'CA',
                'AU',
                'IT',
                'ES',
                'NL',
                'SE',
                'CH',
                'NO',
                'DK',
                'FI',
                'AT',
                'BE',
                'PT',
                'GR',
                'IE',
            ]
                .span()
        }

        fn request_compliance_verification(
            ref self: ContractState,
            asset_id: u256,
            requested_status: felt252,
            evidence_uri: ByteArray,
            country_of_origin: felt252,
            publication_date: u64,
            work_type: felt252,
            is_original_work: bool,
            authors: Span<ContractAddress>,
        ) -> u256 {
            let caller = get_caller_address();
            assert!(self.is_owner(asset_id, caller), "Only asset owners can request verification");
            assert(self.verify_asset_ownership(asset_id), 'Asset does not exist');
            assert!(country_of_origin != 0, "Country of origin required");
            assert!(publication_date > 0, "Publication date required");

            let request_id = self.next_verification_request_id.read();
            self.next_verification_request_id.write(request_id + 1);

            let request = ComplianceVerificationRequest {
                request_id,
                asset_id,
                requester: caller,
                requested_status,
                evidence_uri: evidence_uri.clone(),
                country_of_origin,
                publication_date,
                work_type,
                is_original_work,
                authors_count: authors.len(),
                request_timestamp: get_block_timestamp(),
                is_processed: false,
                is_approved: false,
                verifier_notes: "",
            };

            self.compliance_verification_requests.write(request_id, request);
            let mut i = 0;
            loop {
                if i >= authors.len() {
                    break;
                }
                self.verification_authors.write((request_id, i), *authors.at(i));
                i += 1;
            };

            self
                .emit(
                    ComplianceVerificationRequested {
                        request_id,
                        asset_id,
                        requester: caller,
                        requested_status,
                        country_of_origin,
                        timestamp: get_block_timestamp(),
                    },
                );

            request_id
        }

        fn process_compliance_verification(
            ref self: ContractState,
            request_id: u256,
            approved: bool,
            verifier_notes: ByteArray,
            protection_duration: u64,
            automatic_protection_countries: Span<felt252>,
            manual_registration_required: Span<felt252>,
        ) -> bool {
            let caller = get_caller_address();
            let authority = self.compliance_authorities.read(caller);
            assert!(authority.is_active, "Not an active compliance authority");

            let mut request = self.compliance_verification_requests.read(request_id);
            assert!(request.request_id != 0, "Verification request not found");
            assert!(!request.is_processed, "Request already processed");
            assert!(
                self.is_authorized_for_country(caller, request.country_of_origin),
                "Not authorized for this country",
            );

            // Update request
            request.is_processed = true;
            request.is_approved = approved;
            request.verifier_notes = verifier_notes.clone();
            self.compliance_verification_requests.write(request_id, request.clone());

            if approved {
                // Create or update compliance record
                let compliance_record = ComplianceRecord {
                    asset_id: request.asset_id,
                    compliance_status: request.requested_status,
                    country_of_origin: request.country_of_origin,
                    publication_date: request.publication_date,
                    registration_authority: caller,
                    verification_timestamp: get_block_timestamp(),
                    compliance_evidence_uri: request.evidence_uri.clone(),
                    automatic_protection_count: automatic_protection_countries.len(),
                    manual_registration_count: manual_registration_required.len(),
                    protection_duration,
                    is_anonymous_work: false, // Could be derived from authors
                    is_collective_work: request.authors_count > 1,
                    renewal_required: protection_duration > 0,
                    next_renewal_date: if protection_duration > 0 {
                        get_block_timestamp() + protection_duration
                    } else {
                        0
                    },
                };

                self.compliance_records.write(request.asset_id, compliance_record);

                // Update asset compliance status
                let mut asset_info = self.asset_info.read(request.asset_id);
                asset_info.compliance_status = request.requested_status;
                self.asset_info.write(request.asset_id, asset_info);

                // Update authority stats
                let mut updated_authority = authority;
                updated_authority.verification_count += 1;
                self.compliance_authorities.write(caller, updated_authority);

                // Set international protection
                let mut i = 0;
                loop {
                    if i >= automatic_protection_countries.len() {
                        break;
                    }
                    self
                        .international_protection
                        .write((request.asset_id, *automatic_protection_countries.at(i)), true);
                    i += 1;
                };

                let mut i = 0;
                loop {
                    if i >= automatic_protection_countries.len() {
                        break;
                    }
                    self
                        .automatic_protection_countries
                        .write((request.asset_id, i), *automatic_protection_countries.at(i));
                    i += 1;
                };

                let mut i = 0;
                loop {
                    if i >= manual_registration_required.len() {
                        break;
                    }
                    self
                        .manual_registration_countries
                        .write((request.asset_id, i), *manual_registration_required.at(i));
                    i += 1;
                };

                self
                    .emit(
                        ComplianceVerified {
                            asset_id: request.asset_id,
                            new_status: request.requested_status,
                            verified_by: caller,
                            country_of_origin: request.country_of_origin,
                            protection_duration,
                            timestamp: get_block_timestamp(),
                        },
                    );
            }

            true
        }

        fn update_compliance_status(
            ref self: ContractState, asset_id: u256, new_status: felt252, evidence_uri: ByteArray,
        ) -> bool {
            let caller = get_caller_address();
            let authority = self.compliance_authorities.read(caller);
            assert!(authority.is_active, "Not an active compliance authority");

            let mut compliance_record = self.compliance_records.read(asset_id);
            assert!(compliance_record.asset_id != 0, "No compliance record found");

            compliance_record.compliance_status = new_status;
            compliance_record.compliance_evidence_uri = evidence_uri;
            compliance_record.verification_timestamp = get_block_timestamp();
            self.compliance_records.write(asset_id, compliance_record);

            // Update asset info
            let mut asset_info = self.asset_info.read(asset_id);
            asset_info.compliance_status = new_status;
            self.asset_info.write(asset_id, asset_info);

            true
        }

        fn get_compliance_record(self: @ContractState, asset_id: u256) -> ComplianceRecord {
            self.compliance_records.read(asset_id)
        }

        fn check_protection_validity(
            self: @ContractState, asset_id: u256, country_code: felt252,
        ) -> bool {
            let compliance_record = self.compliance_records.read(asset_id);
            if compliance_record.asset_id == 0 {
                return false;
            }

            // Check if protection has expired
            if compliance_record.protection_duration > 0 {
                let current_time = get_block_timestamp();
                let protection_end = compliance_record.publication_date
                    + compliance_record.protection_duration;
                if current_time >= protection_end {
                    return false;
                }
            }

            // Check international protection
            self.international_protection.read((asset_id, country_code))
        }

        fn calculate_protection_duration(
            self: @ContractState,
            country_code: felt252,
            work_type: felt252,
            publication_date: u64,
            is_anonymous: bool,
        ) -> u64 {
            let requirements = self.get_country_requirements(country_code);
            let years = requirements.protection_duration_years;

            // Convert years to seconds
            let seconds_per_year: u64 = 31536000_u64; // 365 days
            let duration: u64 = seconds_per_year * years.into();

            // Anonymous works often have different duration
            if is_anonymous {
                // Typically 70 years from publication for anonymous works
                70 * seconds_per_year
            } else {
                duration
            }
        }

        fn check_renewal_requirements(self: @ContractState, asset_id: u256) -> (bool, u64) {
            let compliance_record = self.compliance_records.read(asset_id);
            if compliance_record.asset_id == 0 {
                return (false, 0);
            }

            (compliance_record.renewal_required, compliance_record.next_renewal_date)
        }

        fn renew_protection(
            ref self: ContractState, asset_id: u256, renewal_evidence_uri: ByteArray,
        ) -> bool {
            let caller = get_caller_address();
            assert!(self.is_owner(asset_id, caller), "Only asset owners can renew protection");

            let mut compliance_record = self.compliance_records.read(asset_id);
            assert!(compliance_record.asset_id != 0, "No compliance record found");
            assert!(compliance_record.renewal_required, "Renewal not required");

            // Update renewal date
            let current_time = get_block_timestamp();
            compliance_record.next_renewal_date = current_time + 31536000; // 1 year
            compliance_record.compliance_evidence_uri = renewal_evidence_uri;

            self.compliance_records.write(asset_id, compliance_record);

            true
        }

        fn mark_protection_expired(ref self: ContractState, asset_id: u256) -> bool {
            let caller = get_caller_address();
            let authority = self.compliance_authorities.read(caller);
            assert!(authority.is_active, "Not an active compliance authority");

            let mut compliance_record = self.compliance_records.read(asset_id);
            assert!(compliance_record.asset_id != 0, "No compliance record found");

            let previous_status = compliance_record.compliance_status;
            compliance_record.compliance_status = ComplianceStatus::NonCompliant.into();
            self.compliance_records.write(asset_id, compliance_record);

            // Update asset info
            let mut asset_info = self.asset_info.read(asset_id);
            asset_info.compliance_status = ComplianceStatus::NonCompliant.into();
            self.asset_info.write(asset_id, asset_info);

            self
                .emit(
                    ProtectionExpired {
                        asset_id,
                        previous_status,
                        expiration_timestamp: get_block_timestamp(),
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn register_international_protection(
            ref self: ContractState,
            asset_id: u256,
            target_countries: Span<felt252>,
            registration_evidence: Span<ByteArray>,
        ) -> bool {
            let caller = get_caller_address();
            assert!(
                self.is_owner(asset_id, caller),
                "Only asset owners can register international protection",
            );
            assert!(
                target_countries.len() == registration_evidence.len(), "Evidence count mismatch",
            );

            let mut i = 0;
            loop {
                if i >= target_countries.len() {
                    break;
                }
                let country = *target_countries.at(i);
                self.international_protection.write((asset_id, country), true);

                self
                    .emit(
                        CrossBorderProtectionUpdated {
                            asset_id,
                            country_code: country,
                            protection_status: true,
                            updated_by: caller,
                            timestamp: get_block_timestamp(),
                        },
                    );
                i += 1;
            };

            true
        }

        fn check_international_protection_status(
            self: @ContractState, asset_id: u256,
        ) -> (Span<felt252>, Span<felt252>) {
            let compliance_record = self.compliance_records.read(asset_id);
            if compliance_record.asset_id == 0 {
                return (array![].span(), array![].span());
            }

            let automatic_countries = self.get_automatic_protection_countries(asset_id);
            let manual_countries = self.get_manual_registration_countries(asset_id);

            (automatic_countries, manual_countries)
        }

        fn validate_license_compliance(
            self: @ContractState,
            asset_id: u256,
            licensee_country: felt252,
            license_territory: felt252,
            usage_rights: felt252,
        ) -> bool {
            let compliance_record = self.compliance_records.read(asset_id);
            if compliance_record.asset_id == 0 {
                return false;
            }

            // Check if work is protected in the licensee's country
            if !self.check_protection_validity(asset_id, licensee_country) {
                return false;
            }

            // Check if license territory has valid protection
            if license_territory != 'GLOBAL'
                && !self.check_protection_validity(asset_id, license_territory) {
                return false;
            }

            // Check specific usage restrictions based on country requirements
            let country_reqs = self.get_country_requirements(licensee_country);

            // Some countries may have moral rights restrictions
            if !country_reqs.moral_rights_protected && usage_rights == 'DERIVATIVE' {
                return false;
            }

            true
        }

        fn get_licensing_restrictions(
            self: @ContractState, asset_id: u256, target_country: felt252,
        ) -> Span<felt252> {
            let mut restrictions = array![];
            let compliance_record = self.compliance_records.read(asset_id);

            if compliance_record.asset_id == 0 {
                restrictions.append('NO_COMPLIANCE_RECORD');
                return restrictions.span();
            }

            // Check if protection exists in target country
            if !self.check_protection_validity(asset_id, target_country) {
                restrictions.append('NO_PROTECTION');
                return restrictions.span();
            }

            let country_reqs = self.get_country_requirements(target_country);

            // Add country-specific restrictions
            if country_reqs.notice_required {
                restrictions.append('NOTICE_REQUIRED');
            }

            if !country_reqs.moral_rights_protected {
                restrictions.append('NO_MORAL_RIGHTS');
            }

            // Check if registration is required but not completed
            if country_reqs.registration_required
                && !self.international_protection.read((asset_id, target_country)) {
                restrictions.append('REGISTRATION_REQUIRED');
            }

            restrictions.span()
        }

        fn get_compliance_verification_request(
            self: @ContractState, request_id: u256,
        ) -> ComplianceVerificationRequest {
            self.compliance_verification_requests.read(request_id)
        }

        fn get_pending_verification_requests(
            self: @ContractState, authority_address: ContractAddress,
        ) -> Span<u256> {
            let request_count = self.authority_request_count.read(authority_address);
            let mut pending_requests = array![];
            let mut i = 0;

            loop {
                if i >= request_count {
                    break;
                }
                let request_id = self.authority_pending_requests.read((authority_address, i));
                let request = self.compliance_verification_requests.read(request_id);

                if !request.is_processed
                    && self
                        .is_authorized_for_country(authority_address, request.country_of_origin) {
                    pending_requests.append(request_id);
                }
                i += 1;
            };

            pending_requests.span()
        }

        fn get_assets_by_compliance_status(self: @ContractState, status: felt252) -> Span<u256> {
            let asset_count = self.asset_status_count.read(status);
            let mut assets = array![];
            let mut i = 0;

            loop {
                if i >= asset_count {
                    break;
                }
                let asset_id = self.assets_by_status.read((status, i));
                assets.append(asset_id);
                i += 1;
            };

            assets.span()
        }

        fn get_expiring_protections(self: @ContractState, within_days: u64) -> Span<u256> {
            let mut expiring_assets = array![];
            let current_time = get_block_timestamp();
            let threshold_time = current_time + (within_days * 86400); // Convert days to seconds

            let total_assets = self.total_assets.read();
            let mut asset_id = 1;

            loop {
                if asset_id > total_assets {
                    break;
                }

                let compliance_record = self.compliance_records.read(asset_id);
                if compliance_record.asset_id != 0 && compliance_record.renewal_required {
                    if compliance_record.next_renewal_date <= threshold_time
                        && compliance_record.next_renewal_date > current_time {
                        expiring_assets.append(asset_id);
                    }
                }

                asset_id += 1;
            };

            expiring_assets.span()
        }

        fn is_work_in_public_domain(
            self: @ContractState, asset_id: u256, country_code: felt252,
        ) -> bool {
            let compliance_record = self.compliance_records.read(asset_id);
            if compliance_record.asset_id == 0 {
                return false;
            }

            // Check if explicitly marked as public domain
            if compliance_record.protection_duration > 0 {
                let current_time = get_block_timestamp();
                let protection_end = compliance_record.publication_date
                    + compliance_record.protection_duration;
                if current_time >= protection_end {
                    return true;
                }
            }

            false
        }

        fn get_moral_rights_status(
            self: @ContractState, asset_id: u256, country_code: felt252,
        ) -> bool {
            let country_reqs = self.get_country_requirements(country_code);
            let compliance_record = self.compliance_records.read(asset_id);

            // Moral rights exist if country protects them and work is still under protection
            country_reqs.moral_rights_protected
                && compliance_record.asset_id != 0
                && self.check_protection_validity(asset_id, country_code)
        }

        fn calculate_licensing_fees_by_jurisdiction(
            self: @ContractState, asset_id: u256, base_fee: u256, target_countries: Span<felt252>,
        ) -> Span<u256> {
            let mut adjusted_fees = array![];
            let mut i = 0;

            loop {
                if i >= target_countries.len() {
                    break;
                }

                let country = *target_countries.at(i);
                let mut adjusted_fee = base_fee;

                // Apply country-specific adjustments
                let country_reqs = self.get_country_requirements(country);

                // Higher fees for countries requiring registration
                if country_reqs.registration_required {
                    adjusted_fee = (adjusted_fee * 120) / 100; // 20% increase
                }

                // Lower fees for countries with shorter protection
                if country_reqs.protection_duration_years < 70 {
                    adjusted_fee = (adjusted_fee * 90) / 100; // 10% decrease
                }

                // Check if additional compliance costs apply
                let restrictions = self.get_licensing_restrictions(asset_id, country);
                if restrictions.len() > 0 {
                    adjusted_fee = (adjusted_fee * 110) / 100; // 10% compliance overhead
                }

                adjusted_fees.append(adjusted_fee);
                i += 1;
            };

            adjusted_fees.span()
        }

        fn get_authority_countries(
            self: @ContractState, authority_address: ContractAddress,
        ) -> Span<felt252> {
            let authority = self.compliance_authorities.read(authority_address);
            let mut countries = array![];
            let mut i = 0;

            loop {
                if i >= authority.authorized_countries_count {
                    break;
                }
                let country = self.authority_countries.read((authority_address, i));
                countries.append(country);
                i += 1;
            };

            countries.span()
        }

        fn get_automatic_protection_countries(
            self: @ContractState, asset_id: u256,
        ) -> Span<felt252> {
            let compliance_record = self.compliance_records.read(asset_id);
            let mut countries = array![];
            let mut i = 0;

            loop {
                if i >= compliance_record.automatic_protection_count {
                    break;
                }
                let country = self.automatic_protection_countries.read((asset_id, i));
                countries.append(country);
                i += 1;
            };

            countries.span()
        }

        fn get_manual_registration_countries(
            self: @ContractState, asset_id: u256,
        ) -> Span<felt252> {
            let compliance_record = self.compliance_records.read(asset_id);
            let mut countries = array![];
            let mut i = 0;

            loop {
                if i >= compliance_record.manual_registration_count {
                    break;
                }
                let country = self.manual_registration_countries.read((asset_id, i));
                countries.append(country);
                i += 1;
            };

            countries.span()
        }

        fn get_verification_authors(
            self: @ContractState, request_id: u256,
        ) -> Span<ContractAddress> {
            let request = self.compliance_verification_requests.read(request_id);
            let mut authors = array![];
            let mut i = 0;

            loop {
                if i >= request.authors_count {
                    break;
                }
                let author = self.verification_authors.read((request_id, i));
                authors.append(author);
                i += 1;
            };

            authors.span()
        }
    }

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
            let mut creators = ArrayTrait::new();
            let mut i = 0;

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

    #[generate_trait]
    impl ComplianceInternalFunctions of ComplianceInternalFunctionsTrait {
        fn _add_to_status_index(ref self: ContractState, asset_id: u256, status: felt252) {
            let current_count = self.asset_status_count.read(status);
            self.assets_by_status.write((status, current_count), asset_id);
            self.asset_status_count.write(status, current_count + 1);
        }

        fn _check_protection_expiry_batch(ref self: ContractState) {
            let current_time = get_block_timestamp();
            let total_assets = self.total_assets.read();
            let mut asset_id = 1;

            loop {
                if asset_id > total_assets {
                    break;
                }

                let compliance_record = self.compliance_records.read(asset_id);
                if compliance_record.asset_id != 0 && compliance_record.protection_duration > 0 {
                    let protection_end = compliance_record.publication_date
                        + compliance_record.protection_duration;

                    if current_time >= protection_end
                        && compliance_record
                            .compliance_status != ComplianceStatus::NonCompliant
                            .into() {
                        // Mark as expired
                        let mut updated_record = compliance_record.clone();
                        updated_record.compliance_status = ComplianceStatus::NonCompliant.into();
                        self.compliance_records.write(asset_id, updated_record);

                        // Update asset info
                        let mut asset_info: IPAssetInfo = self.asset_info.read(asset_id);
                        asset_info.compliance_status = ComplianceStatus::NonCompliant.into();
                        self.asset_info.write(asset_id, asset_info);

                        self
                            .emit(
                                ProtectionExpired {
                                    asset_id,
                                    previous_status: compliance_record.compliance_status,
                                    expiration_timestamp: protection_end,
                                    timestamp: current_time,
                                },
                            );
                    }
                }

                asset_id += 1;
            };
        }

        fn _validate_berne_compliance_requirements(
            self: @ContractState, work_type: felt252, country_of_origin: felt252, is_original: bool,
        ) -> bool {
            let country_reqs = self.get_country_requirements(country_of_origin);

            // Must be from a Berne signatory country
            if !country_reqs.is_berne_signatory {
                return false;
            }

            // Original works get stronger protection
            if !is_original && work_type == WorkType::Software.into() {
                // Some jurisdictions don't protect derivative software works
                return false;
            }

            true
        }
    }

    #[generate_trait]
    impl GovernanceInternalFunctions of GovernanceInternalFunctionsTrait {
        fn _create_governance_proposal(
            ref self: ContractState,
            asset_id: u256,
            proposal_type: felt252,
            proposer: ContractAddress,
            voting_duration: u64,
            description: ByteArray,
        ) -> u256 {
            let proposal_id = self.next_governance_proposal_id.read();
            self.next_governance_proposal_id.write(proposal_id + 1);

            let settings = self.get_governance_settings(asset_id);
            let current_time = get_block_timestamp();

            // Calculate total voting weight and quorum
            let total_voting_weight = self._calculate_total_voting_weight(asset_id);
            let quorum_required = self
                ._calculate_quorum_required(proposal_type, total_voting_weight, settings);

            let proposal = GovernanceProposal {
                proposal_id,
                asset_id,
                proposal_type,
                proposer,
                votes_for: 0,
                votes_against: 0,
                total_voting_weight,
                quorum_required,
                voting_deadline: current_time + voting_duration,
                execution_deadline: current_time + voting_duration + settings.execution_delay,
                is_executed: false,
                is_cancelled: false,
                description: description.clone(),
            };

            self.governance_proposals.write(proposal_id, proposal.clone());

            // Add to active proposals for asset
            let active_count = self.active_proposal_count.read(asset_id);
            self.active_proposals_for_asset.write((asset_id, active_count), proposal_id);
            self.active_proposal_count.write(asset_id, active_count + 1);

            self
                .emit(
                    GovernanceProposalCreated {
                        proposal_id,
                        asset_id,
                        proposal_type,
                        proposer,
                        quorum_required,
                        voting_deadline: proposal.voting_deadline,
                        description,
                        timestamp: current_time,
                    },
                );

            proposal_id
        }

        fn _calculate_total_voting_weight(self: @ContractState, asset_id: u256) -> u256 {
            let ownership_info = self.ownership_info.read(asset_id);
            let mut total_weight = 0;
            let mut i = 0;

            loop {
                if i >= ownership_info.total_owners {
                    break;
                }
                let owner = self.asset_owners.read((asset_id, i));
                let weight = self.governance_weight.read((asset_id, owner));
                total_weight += weight;
                i += 1;
            };

            total_weight
        }

        fn _calculate_quorum_required(
            self: @ContractState,
            proposal_type: felt252,
            total_voting_weight: u256,
            settings: GovernanceSettings,
        ) -> u256 {
            let quorum_percentage = if proposal_type == ProposalType::Emergency.into() {
                settings.emergency_quorum_percentage
            } else if proposal_type == ProposalType::LicenseApproval.into() {
                settings.license_quorum_percentage
            } else if proposal_type == ProposalType::AssetManagement.into() {
                settings.asset_mgmt_quorum_percentage
            } else if proposal_type == ProposalType::RevenuePolicy.into() {
                settings.revenue_policy_quorum_percentage
            } else {
                settings.default_quorum_percentage
            };

            (total_voting_weight * quorum_percentage) / 10000
        }

        fn _can_execute_proposal(self: @ContractState, proposal_id: u256) -> bool {
            let proposal = self.governance_proposals.read(proposal_id);

            if proposal.proposal_id == 0 || proposal.is_executed || proposal.is_cancelled {
                return false;
            }

            let current_time = get_block_timestamp();

            // Check voting period ended
            if current_time <= proposal.voting_deadline {
                return false;
            }

            // Check execution deadline not passed
            if current_time > proposal.execution_deadline {
                return false;
            }

            // Check quorum reached
            if !self.check_quorum_reached(proposal_id) {
                return false;
            }

            // Check majority approval
            if proposal.votes_for <= proposal.votes_against {
                return false;
            }

            true
        }
    }

    #[generate_trait]
    impl LicensingInternalFunctions of LicensingInternalFunctionsTrait {
        fn _requires_governance_approval(
            self: @ContractState, asset_id: u256, license_type: felt252, license_fee: u256,
        ) -> bool {
            // Require governance approval for:
            // 1. Exclusive licenses (high impact)
            // 2. High-value licenses (above a reasonable threshold)

            if license_type == 'EXCLUSIVE' || license_type == 'SOLE_EXCLUSIVE' {
                return true;
            }

            // Check if fee exceeds a high-value threshold
            if license_fee > 500 { // $500+ requires governance
                return true;
            }

            false
        }

        fn _process_license_payment(ref self: ContractState, license_id: u256) {
            let license_info = self.license_info.read(license_id);

            if license_info.license_fee > 0 {
                // Transfer payment from licensee to contract
                if !license_info.payment_token.is_zero() {
                    let erc20 = IERC20Dispatcher { contract_address: license_info.payment_token };
                    let success = erc20
                        .transfer_from(
                            license_info.licensee, // Payment comes from licensee
                            get_contract_address(),
                            license_info.license_fee,
                        );
                    assert!(success, "License fee payment failed");
                }

                // Distribute license fee to asset owners immediately
                self
                    ._distribute_license_fee(
                        license_info.asset_id, license_info.payment_token, license_info.license_fee,
                    );
            }
        }

        fn _distribute_license_fee(
            ref self: ContractState, asset_id: u256, token_address: ContractAddress, amount: u256,
        ) {
            let mut revenue_info = self.revenue_info.read((asset_id, token_address));
            revenue_info.total_received += amount;
            revenue_info.accumulated_revenue += amount;
            self.revenue_info.write((asset_id, token_address), revenue_info);

            // Auto-distribute license fees immediately
            let (owners, percentages) = self.get_asset_owners_with_percentages(asset_id);
            let mut i = 0;

            loop {
                if i >= owners.len() {
                    break;
                }

                let owner = *owners.at(i);
                let percentage = *percentages.at(i);
                let owner_share = (amount * percentage) / 100;

                if owner_share > 0 {
                    let current_pending = self
                        .pending_revenue
                        .read((asset_id, owner, token_address));
                    self
                        .pending_revenue
                        .write((asset_id, owner, token_address), current_pending + owner_share);

                    let mut owner_info = self
                        .owner_revenue_info
                        .read((asset_id, owner, token_address));
                    owner_info.total_earned += owner_share;
                    self.owner_revenue_info.write((asset_id, owner, token_address), owner_info);
                }

                i += 1;
            };

            // Update revenue tracking
            revenue_info.accumulated_revenue -= amount;
            revenue_info.total_distributed += amount;
            revenue_info.last_distribution_timestamp = get_block_timestamp();
            revenue_info.distribution_count += 1;
            self.revenue_info.write((asset_id, token_address), revenue_info);
        }

        fn _distribute_royalties(
            ref self: ContractState, asset_id: u256, token_address: ContractAddress, amount: u256,
        ) {
            self._distribute_license_fee(asset_id, token_address, amount);
        }
    }
}
