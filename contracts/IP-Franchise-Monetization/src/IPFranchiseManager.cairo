use super::errors;
use super::interfaces;
use super::types;
use super::events;

#[starknet::contract]
pub mod IPFranchiseManager {
    use starknet::{
        ContractAddress, get_caller_address, get_contract_address, get_block_timestamp, ClassHash,
    };
    use starknet::event::EventEmitter;
    use starknet::syscalls::deploy_syscall;

    use core::array::ArrayTrait;
    use core::felt252;

    use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_introspection::src5::SRC5Component;

    use core::starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry,
    };

    use super::types::{
        FranchiseApplication, FranchiseTerms, ApplicationStatus, PaymentModel, Territory,
        ExclusivityType,
    };

    use super::errors::Errors;
    use super::events::{
        IPAssetLinked, IPAssetUnLinked, FranchiseAgreementCreated, NewFranchiseApplication,
        FranchiseApplicationRevised, FranchiseApplicationCanceled, FranchiseApplicationRejected,
        FranchiseApplicationApproved, FranchiseSaleInitiated, FranchiseSaleApproved,
        FranchiseSaleRejected, FranchiseAgreementReinstated, FranchiseAgreementRevoked,
        ApplicationRevisionAccepted, TerritoryDeactivated, NewTerritoryAdded,
    };
    use super::interfaces::{
        IIPFranchiseManager, FranchiseTermsTrait, IIPFranchiseAgreementDispatcher,
        IIPFranchiseAgreementDispatcherTrait,
    };

    // *************************************************************************
    //                             COMPONENTS
    // *************************************************************************
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        ip_nft_id: u256,
        ip_nft_address: ContractAddress,
        // Territory ID to Territory mapping
        territories: Map<u256, Territory>,
        territories_count: u256,
        // Class hash of the IP Licensing Agreement contract
        franchise_agreement_class_hash: ClassHash,
        // Mapping from agreement ID to agreement contract address
        franchise_agreements: Map<u256, ContractAddress>,
        // Mapping from agreement contract address to agreement ID
        franchise_agreement_ids: Map<ContractAddress, u256>,
        // Total number of agreements created
        franchise_agreement_count: u256,
        // Mapping from Franchisee address to array of agreement IDs they are involved in
        franchisee_agreements: Map<(ContractAddress, u256), u256>,
        // Count of agreements per Franchisee
        franchisee_agreement_count: Map<ContractAddress, u256>,
        // Mapping from Franchise applications to application id and application version
        franchise_applications: Map<(u256, u8), FranchiseApplication>,
        // Mapping from version to Franchise application ID
        francise_application_version: Map<u256, u8>,
        // Total number of agreements created
        franchise_applications_count: u256,
        // Mapping from Franchisee address to array of application IDs they are involved in
        franchisee_applications: Map<(ContractAddress, u256), u256>,
        // Counts of applications per Franchisee
        franchisee_application_count: Map<ContractAddress, u256>,
        // Mapping from Agreement Id to sale status
        franchise_sale_requested: Map<u256, bool>,
        // Counts of agreements listed for sale
        franchise_sale_requests_count: u256,
        // Preferred payment Models:
        preferred_payment_model: PaymentModel,
        // Default franchise fee
        default_franchise_fee: u256,
        // Check if IP NFT is link
        ip_asset_linked: bool,
    }

    // *************************************************************************
    //                             EVENTS
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        IPAssetLinked: IPAssetLinked,
        IPAssetUnLinked: IPAssetUnLinked,
        FranchiseAgreementCreated: FranchiseAgreementCreated,
        NewFranchiseApplication: NewFranchiseApplication,
        FranchiseApplicationRevised: FranchiseApplicationRevised,
        FranchiseApplicationCanceled: FranchiseApplicationCanceled,
        FranchiseApplicationRejected: FranchiseApplicationRejected,
        FranchiseApplicationApproved: FranchiseApplicationApproved,
        FranchiseSaleInitiated: FranchiseSaleInitiated,
        FranchiseSaleApproved: FranchiseSaleApproved,
        FranchiseSaleRejected: FranchiseSaleRejected,
        FranchiseAgreementReinstated: FranchiseAgreementReinstated,
        FranchiseAgreementRevoked: FranchiseAgreementRevoked,
        ApplicationRevisionAccepted: ApplicationRevisionAccepted,
        TerritoryDeactivated: TerritoryDeactivated,
        NewTerritoryAdded: NewTerritoryAdded,
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        ip_id: u256,
        ip_nft_address: ContractAddress,
        agreement_class_hash: ClassHash,
        default_franchise_fee: u256,
        preferred_payment_model: PaymentModel,
    ) {
        self.ownable.initializer(owner);
        self.ip_nft_id.write(ip_id);
        self.ip_nft_address.write(ip_nft_address);
        self.franchise_agreement_class_hash.write(agreement_class_hash);
        self.franchise_agreement_count.write(0);
        self.default_franchise_fee.write(default_franchise_fee);
        self.preferred_payment_model.write(preferred_payment_model);
        self.ip_asset_linked.write(false);
    }

    // *************************************************************************
    //                             IMPLEMENTATIONS
    // *************************************************************************

    #[abi(embed_v0)]
    impl IPFranchiseManagerImpl of IIPFranchiseManager<ContractState> {
        /// Links an IP asset (NFT) to the franchise manager contract
        /// The NFT will be held by the contract and used to prove IP ownership
        /// # Arguments
        /// None - NFT must be pre-approved for transfer to this contract
        /// # Access Control
        /// Only IP asset owner can link their NFT
        /// # Effects
        /// * Transfers NFT from caller to this contract
        /// * Records IP asset details in contract storage
        fn link_ip_asset(ref self: ContractState) {
            // Only contract owner can link IP asset
            self.ownable.assert_only_owner();
            let caller = get_caller_address();

            // Verify asset isn't already linked
            assert(!self.ip_asset_linked.read(), Errors::IpAssetAlreadyLinked);

            // Get NFT details from storage
            let token_id = self.ip_nft_id.read();
            let ip_nft_address = self.ip_nft_address.read();

            // Create dispatcher to interact with ERC721 contract
            let erc721_dispatcher = IERC721Dispatcher { contract_address: ip_nft_address };

            // Verify caller owns the NFT
            assert(erc721_dispatcher.owner_of(token_id) == caller, Errors::NotOwner);

            // Check this contract has approval to transfer the NFT
            assert(
                erc721_dispatcher.is_approved_for_all(caller, get_contract_address()),
                Errors::NotApproved,
            );

            // Transfer NFT from caller to this contract
            erc721_dispatcher.transfer_from(caller, get_contract_address(), token_id);

            // Update linked status
            self.ip_asset_linked.write(true);

            // Emit event for NFT link
            self
                .emit(
                    IPAssetLinked {
                        ip_token_id: token_id,
                        ip_token_address: ip_nft_address,
                        owner: caller,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Unlinks an IP asset (NFT) from the franchise manager contract
        /// The NFT will be returned to the original owner
        /// # Arguments
        /// None
        /// # Access Control
        /// Only contract owner can unlink their NFT
        fn unlink_ip_asset(ref self: ContractState) {
            // Only contract owner can unlink IP asset
            self.ownable.assert_only_owner();
            let caller = get_caller_address();
            let this_contract = get_contract_address();

            // Verify asset is currently linked
            assert(self.ip_asset_linked.read(), 'nft not linked');

            // Check that all franchise agreements are inactive/expired
            let total_agreements = self.franchise_agreement_count.read();
            for id in 0..total_agreements {
                let agreement_address = self.get_franchise_agreement_address(id);
                let franchise_agreement = IIPFranchiseAgreementDispatcher {
                    contract_address: agreement_address,
                };
                assert(!franchise_agreement.is_active(), Errors::AgreementLicenseNotOver);
            };

            // Get NFT details from storage
            let token_id = self.ip_nft_id.read();
            let ip_nft_address = self.ip_nft_address.read();

            let erc721_dispatcher = IERC721Dispatcher { contract_address: ip_nft_address };

            // Verify this contract still owns the NFT
            assert(erc721_dispatcher.owner_of(token_id) == this_contract, Errors::NotOwner);

            // Transfer NFT back to owner
            erc721_dispatcher.transfer_from(this_contract, caller, token_id);

            // Update linked status
            self.ip_asset_linked.write(false);

            // Emit event for NFT unlink
            self
                .emit(
                    IPAssetUnLinked {
                        ip_token_id: token_id,
                        ip_token_address: ip_nft_address,
                        owner: caller,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Adds a new franchise territory to be available for franchisees
        /// # Arguments
        /// * `name` - Name of the territory to add
        /// # Access Control
        /// Only contract owner can add territories
        fn add_franchise_territory(ref self: ContractState, name: ByteArray) {
            // Check caller is contract owner
            self.ownable.assert_only_owner();

            // Get next territory ID from count
            let territory_id = self.territories_count.read();

            // Create new territory struct
            let territory = Territory {
                id: 0, // ID is set to 0 since it's stored in mapping key
                name: name.clone(),
                exclusive_to_agreement: Option::None, // No exclusive agreement initially
                active: true // Territory starts as active
            };

            // Store territory in mapping
            self.territories.entry(territory_id).write(territory);

            // Increment territory count
            self.territories_count.write(territory_id + 1);

            // Emit event for territory creation
            self.emit(NewTerritoryAdded { territory_id, name, timestamp: get_block_timestamp() });
        }

        /// Deactivates a franchise territory, making it inactive
        /// # Arguments
        /// * `self` - Contract state
        /// * `territory_id` - Unique identifier of the territory to deactivate
        /// # Access
        /// * Only contract owner can call this function
        fn deactivate_franchise_territory(ref self: ContractState, territory_id: u256) {
            self.ownable.assert_only_owner();

            let mut territory = self.territories.entry(territory_id).read();

            // Sets territory's active status to false
            territory.active = false;

            self.territories.entry(territory_id).write(territory);

            // Emit an event for the territory deactivated
            self.emit(TerritoryDeactivated { territory_id, timestamp: get_block_timestamp() });
        }

        /// Creates a direct franchise agreement without going through application process
        /// # Arguments
        /// * `franchisee` - Address of the franchisee
        /// * `franchise_terms` - Terms of the franchise agreement
        /// # Access Control
        /// Only contract owner can create direct agreements
        fn create_direct_franchise_agreement(
            ref self: ContractState, franchisee: ContractAddress, franchise_terms: FranchiseTerms,
        ) {
            // Verify caller is contract owner
            self.ownable.assert_only_owner();

            // Check IP NFT is linked
            assert(self.ip_asset_linked.read(), Errors::IpAssetNotLinked);

            let block_timestamp = get_block_timestamp();

            // Validate the franchise terms
            franchise_terms.validate_terms_data(block_timestamp);

            // Create the franchise agreement contract
            let (agreement_id, agreement_address) = self
                ._create_franchise_agreement(franchisee, franchise_terms);

            // Emit event for agreement creation
            self
                .emit(
                    FranchiseAgreementCreated {
                        agreement_id,
                        agreement_address,
                        franchisee,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Creates a franchise agreement from an approved application
        /// # Arguments
        /// * `application_id` - ID of the approved franchise application
        /// # Access Control
        /// Only contract owner can create agreements
        fn create_franchise_agreement_from_application(
            ref self: ContractState, application_id: u256,
        ) {
            // Verify caller is contract owner
            self.ownable.assert_only_owner();

            // Check IP NFT is linked
            assert(self.ip_asset_linked.read(), Errors::IpAssetNotLinked);

            // Get latest version of application
            let application_version = self
                .francise_application_version
                .entry(application_id)
                .read();

            // Get application details
            let application = self.get_franchise_application(application_id, application_version);

            // Verify application is approved
            assert(
                application.status == ApplicationStatus::Approved, Errors::ApplicationNotApproved,
            );

            let block_timestamp = get_block_timestamp();

            // Validate terms are still valid
            application.current_terms.validate_terms_data(block_timestamp);

            // Create franchise agreement contract
            let (agreement_id, agreement_address) = self
                ._create_franchise_agreement(application.franchisee, application.current_terms);

            // Emit event for agreement creation
            self
                .emit(
                    FranchiseAgreementCreated {
                        agreement_id,
                        agreement_address,
                        franchisee: application.franchisee,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Allows a potential franchisee to apply for a franchise agreement
        /// # Arguments
        /// * `franchise_terms` - Terms of the proposed franchise agreement including territory,
        /// exclusivity, etc # Access Control
        /// Any address can submit an application
        fn apply_for_franchise(ref self: ContractState, franchise_terms: FranchiseTerms) {
            // Verify IP asset is linked before accepting applications
            assert(self.ip_asset_linked.read(), Errors::IpAssetNotLinked);

            let caller = get_caller_address();

            let block_timestamp = get_block_timestamp();

            // Validate the franchise terms data
            franchise_terms.validate_terms_data(block_timestamp);

            // Get territory info and validate it's available
            let territory_info = self.get_territory_info(franchise_terms.territory_id);
            assert(territory_info.exclusive_to_agreement.is_none(), Errors::TerritoryAlreadyLinked);
            assert(territory_info.active, Errors::TerritoryNotActive);

            // Get next application ID
            let application_id = self.franchise_applications_count.read();

            // Get current application version (should be 0 for new application)
            let application_version = self
                .francise_application_version
                .entry(application_id)
                .read();

            // Create new application record
            let application = FranchiseApplication {
                application_id: application_id,
                franchisee: caller,
                current_terms: franchise_terms,
                status: ApplicationStatus::Pending,
                last_proposed_by: caller,
                version: application_version,
            };

            // Store application in mapping
            self
                .franchise_applications
                .entry((application_id, application_version))
                .write(application);

            // Increment total application count
            self.franchise_applications_count.write(self.franchise_applications_count.read() + 1);

            // Add application to franchisee's list
            let franchisee_application_count = self
                .franchisee_application_count
                .entry(caller)
                .read();

            self
                .franchisee_applications
                .entry((caller, franchisee_application_count))
                .write(application_id);

            // Increment franchisee's application count
            self.franchisee_application_count.entry(caller).write(franchisee_application_count + 1);

            // Emit event for new application
            self
                .emit(
                    NewFranchiseApplication {
                        application_id, franchisee: caller, timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Revises the terms of an existing franchise application
        /// # Arguments
        /// * `application_id` - ID of the application to revise
        /// * `new_terms` - New proposed franchise terms
        /// # Access Control
        /// Only the original applicant or contract owner can revise terms
        fn revise_franchise_application(
            ref self: ContractState, application_id: u256, new_terms: FranchiseTerms,
        ) {
            let caller = get_caller_address();

            let block_timestamp = get_block_timestamp();

            // Validate the proposed new terms
            new_terms.validate_terms_data(block_timestamp);

            // Get current version of application
            let application_version = self
                .francise_application_version
                .entry(application_id)
                .read();

            // Get current application details
            let mut application = self
                .get_franchise_application(application_id, application_version);

            // Verify caller is either applicant or contract owner
            assert(
                application.franchisee == caller || self.ownable.owner() == caller,
                Errors::NotAuthorized,
            );

            // Can only revise pending or previously revised applications
            assert(
                application.status == ApplicationStatus::Pending
                    || application.status == ApplicationStatus::Revised,
                Errors::InvalidApplicationStatus,
            );

            // Verify territory is available
            let territory_info = self.get_territory_info(new_terms.territory_id);
            assert(territory_info.exclusive_to_agreement.is_none(), Errors::TerritoryAlreadyLinked);
            assert(territory_info.active, Errors::TerritoryNotActive);

            // Update application with new terms
            application.current_terms = new_terms;
            application.last_proposed_by = caller;
            application.status = ApplicationStatus::Revised;

            // Increment and update version number
            let new_application_version = application_version + 1;
            self.francise_application_version.entry(application_id).write(new_application_version);

            // Store updated application
            self
                .franchise_applications
                .entry((application_id, new_application_version))
                .write(application);

            // Emit event for revision
            self
                .emit(
                    FranchiseApplicationRevised {
                        application_id,
                        reviser: caller,
                        application_version: new_application_version,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Allows a franchisee to accept a revision made to their franchise application
        /// # Arguments
        /// * `application_id` - ID of the application to accept revision for
        /// # Access Control
        /// Only the original applicant/franchisee can accept revisions
        fn accept_franchise_application_revision(ref self: ContractState, application_id: u256) {
            let caller = get_caller_address();

            // Get current version of the application
            let application_version = self
                .francise_application_version
                .entry(application_id)
                .read();

            // Get application details
            let mut application = self
                .get_franchise_application(application_id, application_version);

            // Verify caller is the original applicant
            assert(application.franchisee == caller, Errors::NotAuthorized);

            // Can only accept applications in Revised status
            assert(
                application.status == ApplicationStatus::Revised, Errors::InvalidApplicationStatus,
            );

            // Update status to RevisionAccepted
            application.status = ApplicationStatus::RevisionAccepted;

            // Save updated application
            self
                .franchise_applications
                .entry((application_id, application_version))
                .write(application);

            // Emit event for revision acceptance
            self
                .emit(
                    ApplicationRevisionAccepted {
                        application_id, franchisee: caller, timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Cancels a pending franchise application
        /// # Arguments
        /// * `application_id` - ID of the application to cancel
        /// # Access Control
        /// Only the original applicant/franchisee can cancel their application
        fn cancel_franchise_application(ref self: ContractState, application_id: u256) {
            let caller = get_caller_address();

            // Get current version of the application
            let application_version = self
                .francise_application_version
                .entry(application_id)
                .read();

            // Get application details
            let mut application = self
                .get_franchise_application(application_id, application_version);

            // Verify caller is the original applicant
            assert(application.franchisee == caller, Errors::NotApplicationOwner);

            // Can only cancel applications in Pending status
            assert(
                application.status == ApplicationStatus::Pending, Errors::CannotCancelApplication,
            );

            // Update status to Cancelled
            application.status = ApplicationStatus::Cancelled;

            // Save updated application
            self
                .franchise_applications
                .entry((application_id, application_version))
                .write(application);

            // Emit event for cancellation
            self
                .emit(
                    FranchiseApplicationCanceled {
                        application_id, franchisee: caller, timestamp: get_block_timestamp(),
                    },
                );
        }


        /// Approve a franchise application for a potential franchisee
        /// # Arguments
        /// * `application_id` - ID of the application to approve
        /// # Access Control
        /// * Only contract owner can approve applications
        fn approve_franchise_application(ref self: ContractState, application_id: u256) {
            // Verify caller is contract owner
            self.ownable.assert_only_owner();

            // Get current version of the application
            let application_version = self
                .francise_application_version
                .entry(application_id)
                .read();

            // Retrieve application details from storage
            let mut application = self
                .get_franchise_application(application_id, application_version);

            // Can only approve applications that are Pending or RevisionAccepted
            assert(
                application.status == ApplicationStatus::Pending
                    || application.status == ApplicationStatus::RevisionAccepted,
                Errors::InvalidApplicationStatus,
            );

            // Update application status to Approved
            application.status = ApplicationStatus::Approved;

            // Save updated application back to storage
            self
                .franchise_applications
                .entry((application_id, application_version))
                .write(application);

            // Emit event for application approval
            self
                .emit(
                    FranchiseApplicationApproved {
                        application_id, timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Rejects a franchise application
        /// # Arguments
        /// * `application_id` - ID of the application to reject
        /// # Access Control
        /// * Only contract owner can reject applications
        fn reject_franchise_application(ref self: ContractState, application_id: u256) {
            // Verify caller is contract owner
            self.ownable.assert_only_owner();

            // Get current version of the application
            let application_version = self
                .francise_application_version
                .entry(application_id)
                .read();

            // Get application details from storage
            let mut application = self
                .get_franchise_application(application_id, application_version);

            // Can only reject applications that are Pending or RevisionAccepted
            assert(
                application.status == ApplicationStatus::Pending
                    || application.status == ApplicationStatus::RevisionAccepted,
                Errors::InvalidApplicationStatus,
            );

            // Update application status to Rejected
            application.status = ApplicationStatus::Rejected;

            // Save updated application back to storage
            self
                .franchise_applications
                .entry((application_id, application_version))
                .write(application);

            // Emit event for application rejection
            self
                .emit(
                    FranchiseApplicationRejected {
                        application_id, timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Initiates a sale request for a franchise agreement
        /// # Arguments
        /// * `agreement_id` - ID of the agreement to list for sale
        /// # Access Control
        /// Only the agreement contract can initiate a sale
        fn initiate_franchise_sale(ref self: ContractState, agreement_id: u256) {
            let caller = get_caller_address();

            // Get agreement address from storage
            let agreement_address = self.franchise_agreements.entry(agreement_id).read();

            // Verify caller is the agreement contract
            assert(caller == agreement_address, Errors::NotAuthorized);

            // Mark agreement as listed for sale
            self.franchise_sale_requested.entry(agreement_id).write(true);

            // Get next sale ID from total count
            let sale_id = self.get_total_franchise_sale_requests();

            // Increment total sale requests count
            self.franchise_sale_requests_count.write(sale_id + 1);

            // Emit sale initiation event
            self
                .emit(
                    FranchiseSaleInitiated {
                        agreement_id, sale_id, timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Approves a franchise sale request
        /// # Arguments
        /// * `agreement_id` - ID of the agreement to approve sale for
        /// # Access Control
        /// Only contract owner can approve sales
        fn approve_franchise_sale(ref self: ContractState, agreement_id: u256) {
            // Verify caller is contract owner
            self.ownable.assert_only_owner();

            // Check agreement is actually listed for sale
            assert(
                self.is_franchise_sale_requested(agreement_id), Errors::FranchiseAgreementNotListed,
            );

            // Get agreement contract address
            let agreement_address = self.get_franchise_agreement_address(agreement_id);

            // Create dispatcher to interact with agreement contract
            let franchise_agreement = IIPFranchiseAgreementDispatcher {
                contract_address: agreement_address,
            };

            // Call approve sale on agreement contract
            franchise_agreement.approve_franchise_sale();

            // Emit approval event
            self
                .emit(
                    FranchiseSaleApproved {
                        agreement_id, agreement_address, timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Rejects a franchise sale request
        /// # Arguments
        /// * `agreement_id` - ID of the agreement to reject sale for
        /// # Access Control
        /// Only contract owner can reject sales
        fn reject_franchise_sale(ref self: ContractState, agreement_id: u256) {
            // Verify caller is contract owner
            self.ownable.assert_only_owner();

            // Check agreement is actually listed for sale
            assert(
                self.is_franchise_sale_requested(agreement_id), Errors::FranchiseAgreementNotListed,
            );

            // Get agreement contract address
            let agreement_address = self.get_franchise_agreement_address(agreement_id);

            // Create dispatcher to interact with agreement contract
            let franchise_agreement = IIPFranchiseAgreementDispatcher {
                contract_address: agreement_address,
            };

            // Call reject sale on agreement contract
            franchise_agreement.reject_franchise_sale();

            // Emit rejection event
            self
                .emit(
                    FranchiseSaleRejected {
                        agreement_id, agreement_address, timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Revokes a franchise license agreement
        /// # Arguments
        /// * `agreement_id` - ID of the agreement to revoke
        /// # Access Control
        /// Only contract owner can revoke licenses
        fn revoke_franchise_license(ref self: ContractState, agreement_id: u256) {
            // Verify caller is contract owner
            self.ownable.assert_only_owner();

            // Get agreement contract address
            let agreement_address = self.get_franchise_agreement_address(agreement_id);

            // Create dispatcher to interact with agreement contract
            let franchise_agreement = IIPFranchiseAgreementDispatcher {
                contract_address: agreement_address,
            };

            // Call revoke on agreement contract
            franchise_agreement.revoke_franchise_license();

            // Emit revocation event
            self
                .emit(
                    FranchiseAgreementRevoked {
                        agreement_id, agreement_address, timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Reinstates a previously revoked franchise license
        /// # Arguments
        /// * `agreement_id` - ID of the agreement to reinstate
        /// # Access Control
        /// Only contract owner can reinstate licenses
        fn reinstate_franchise_license(ref self: ContractState, agreement_id: u256) {
            // Verify caller is contract owner
            self.ownable.assert_only_owner();

            // Get agreement contract address
            let agreement_address = self.get_franchise_agreement_address(agreement_id);

            // Create dispatcher to interact with agreement contract
            let franchise_agreement = IIPFranchiseAgreementDispatcher {
                contract_address: agreement_address,
            };

            // Call reinstate on agreement contract
            franchise_agreement.reinstate_franchise_license();

            // Emit reinstatement event
            self
                .emit(
                    FranchiseAgreementReinstated {
                        agreement_id, agreement_address, timestamp: get_block_timestamp(),
                    },
                );
        }


        // *************************************************************************
        //                              VIEW FUNCTIONS
        // *************************************************************************

        // Get the IP NFT ID
        fn get_ip_nft_id(self: @ContractState) -> u256 {
            self.ip_nft_id.read()
        }

        // Get the IP NFT Contract Address
        fn get_ip_nft_address(self: @ContractState) -> ContractAddress {
            self.ip_nft_address.read()
        }

        // Get Territory Information
        fn get_territory_info(self: @ContractState, territory_id: u256) -> Territory {
            self.territories.entry(territory_id).read()
        }

        fn get_total_territories(self: @ContractState) -> u256 {
            self.territories_count.read()
        }

        // Get Franchise Agreement Address by ID
        fn get_franchise_agreement_address(
            self: @ContractState, agreement_id: u256,
        ) -> ContractAddress {
            self.franchise_agreements.entry(agreement_id).read()
        }

        // Get Franchise Agreement ID by Address
        fn get_franchise_agreement_id(
            self: @ContractState, agreement_address: ContractAddress,
        ) -> u256 {
            self.franchise_agreement_ids.entry(agreement_address).read()
        }

        // Get Total Number of Franchise Agreements
        fn get_total_franchise_agreements(self: @ContractState) -> u256 {
            self.franchise_agreement_count.read()
        }

        // Get Agreement ID of a Franchisee by Index
        fn get_franchisee_agreement(
            self: @ContractState, franchisee: ContractAddress, index: u256,
        ) -> u256 {
            self.franchisee_agreements.entry((franchisee, index)).read()
        }

        // Get Number of Agreements for a Franchisee
        fn get_franchisee_agreement_count(
            self: @ContractState, franchisee: ContractAddress,
        ) -> u256 {
            self.franchisee_agreement_count.entry(franchisee).read()
        }

        // Get Franchise Application by ID and Version
        fn get_franchise_application(
            self: @ContractState, application_id: u256, version: u8,
        ) -> FranchiseApplication {
            self.franchise_applications.entry((application_id, version)).read()
        }

        // Get Version Number of a Franchise Application
        fn get_franchise_application_version(self: @ContractState, application_id: u256) -> u8 {
            self.francise_application_version.entry(application_id).read()
        }

        // Get Total Number of Franchise Applications
        fn get_total_franchise_applications(self: @ContractState) -> u256 {
            self.franchise_applications_count.read()
        }

        // Get Application ID of a Franchisee by Index
        fn get_franchisee_application(
            self: @ContractState, franchisee: ContractAddress, index: u256,
        ) -> u256 {
            self.franchisee_applications.entry((franchisee, index)).read()
        }

        // Get Number of Applications for a Franchisee
        fn get_franchisee_application_count(
            self: @ContractState, franchisee: ContractAddress,
        ) -> u256 {
            self.franchisee_application_count.entry(franchisee).read()
        }

        // Get Preferred Payment Model
        fn get_preferred_payment_model(self: @ContractState) -> PaymentModel {
            self.preferred_payment_model.read()
        }

        // Get Default Franchise Fee
        fn get_default_franchise_fee(self: @ContractState) -> u256 {
            self.default_franchise_fee.read()
        }

        // Check if IP Asset is Linked
        fn is_ip_asset_linked(self: @ContractState) -> bool {
            self.ip_asset_linked.read()
        }

        /// Check if a sale has been requested for a given Agreement ID
        fn is_franchise_sale_requested(self: @ContractState, agreement_id: u256) -> bool {
            self.franchise_sale_requested.entry(agreement_id).read()
        }

        /// Get the total number of franchise sales listed
        fn get_total_franchise_sale_requests(self: @ContractState) -> u256 {
            self.franchise_sale_requests_count.read()
        }

        // UPGRADE
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _create_franchise_agreement(
            ref self: ContractState, franchisee: ContractAddress, franchise_terms: FranchiseTerms,
        ) -> (u256, ContractAddress) {
            self.ownable.assert_only_owner();

            assert(self.ip_asset_linked.read(), Errors::IpAssetNotLinked);

            let territory_info = self.get_territory_info(franchise_terms.territory_id);

            // Check territory information
            assert(territory_info.exclusive_to_agreement.is_none(), Errors::TerritoryAlreadyLinked);
            assert(territory_info.active, Errors::TerritoryNotActive);

            let territory_id = franchise_terms.territory_id.clone();
            let exclusivity = franchise_terms.exclusivity.clone();

            let agreement_id = self.franchise_agreement_count.read();

            let mut constructor_calldata: Array::<felt252> = array![];

            let franchise_manager = get_contract_address();

            (
                agreement_id,
                franchise_manager,
                franchisee,
                franchise_terms.payment_model,
                franchise_terms.payment_token,
                franchise_terms.franchise_fee,
                franchise_terms.license_start,
                franchise_terms.license_end,
                franchise_terms.exclusivity,
                franchise_terms.territory_id,
            )
                .serialize(ref constructor_calldata);

            let (agreement_address, _) = deploy_syscall(
                self.franchise_agreement_class_hash.read(), 0, constructor_calldata.span(), false,
            )
                .unwrap();

            // Store the agreement address in the mapping
            self.franchise_agreements.entry(agreement_id).write(agreement_address);

            // Store the agreement ID in the mapping
            self.franchise_agreement_ids.entry(agreement_address).write(agreement_id);

            self.franchise_agreement_count.write(self.franchise_agreement_count.read() + 1);

            // Add the agreement to the franchisee's list of agreements
            let franchisee_agreement_count = self
                .franchisee_agreement_count
                .entry(franchisee)
                .read();

            self
                .franchisee_agreements
                .entry((franchisee, franchisee_agreement_count))
                .write(agreement_id);

            self.franchisee_agreement_count.entry(franchisee).write(franchisee_agreement_count + 1);

            // Add territory information

            if exclusivity == ExclusivityType::Exclusive {
                let mut territory = self.territories.entry(territory_id).read();
                territory.exclusive_to_agreement = Option::Some(agreement_id.clone());
                self.territories.entry(territory_id).write(territory);
            }

            (agreement_id, agreement_address)
        }
    }
}
