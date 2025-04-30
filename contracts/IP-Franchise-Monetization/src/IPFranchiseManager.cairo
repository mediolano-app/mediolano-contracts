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

    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;

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
        ApplicationRevisionAccepted,
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
        // Mapping from Agreement ID to sales Ids
        franchise_sale_agreement_ids: Map<u256, u256>,
        // Counts of agreements listed for sale
        franchise_sale_count: u256,
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
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        ip_id: u256,
        ip_nft_address: ContractAddress,
        agreement_class_hash: ClassHash,
        default_franchise_fee: u256,
        preferred_payment_model: PaymentModel,
    ) {
        self.ownable.initializer(admin);
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
        // Send NFT to the franchise Manager Contract
        fn link_ip_asset(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let caller = get_caller_address();

            assert(!self.ip_asset_linked.read(), 'nft already linked');

            let token_id = self.ip_nft_id.read();
            let ip_nft_address = self.ip_nft_address.read();

            let erc721_dispatcher = IERC721Dispatcher { contract_address: ip_nft_address };

            // check whether asset is caller asset
            assert(erc721_dispatcher.owner_of(token_id) == caller, Errors::NOT_OWNER);

            // check whether contract has approval to move asset
            assert(
                erc721_dispatcher.is_approved_for_all(caller, get_contract_address()),
                Errors::NOT_APPROVED,
            );

            erc721_dispatcher
                .safe_transfer_from(caller, get_contract_address(), token_id, array![].span());

            self.ip_asset_linked.write(true);

            // Add nft link event
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

        // Unlink NFT from the franchise Manager Contract
        fn unlink_ip_asset(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let caller = get_caller_address();
            let this_contract = get_contract_address();

            assert(self.ip_asset_linked.read(), 'nft not linked');

            // check that all licenses are over
            let total_agreements = self.franchise_agreement_count.read();

            for id in 0..total_agreements {
                let agreement_address = self.get_franchise_agreement_address(id);
                let franchise_agreement = IIPFranchiseAgreementDispatcher {
                    contract_address: agreement_address,
                };
                assert(!franchise_agreement.is_active(), Errors::AgreementLicenseNotOver);
            };

            let token_id = self.ip_nft_id.read();
            let ip_nft_address = self.ip_nft_address.read();

            let erc721_dispatcher = IERC721Dispatcher { contract_address: ip_nft_address };

            // check whether asset is caller asset
            assert(erc721_dispatcher.owner_of(token_id) == this_contract, Errors::NOT_OWNER);

            erc721_dispatcher.safe_transfer_from(this_contract, caller, token_id, array![].span());

            self.ip_asset_linked.write(false);

            // Add nft unlink event
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


        // Create a direct Franchise Agreement
        fn create_direct_franchise_agreement(
            ref self: ContractState, franchisee: ContractAddress, franchise_terms: FranchiseTerms,
        ) {
            self.ownable.assert_only_owner();

            assert(self.ip_asset_linked.read(), Errors::IP_ASSET_NOT_LINKED);

            let block_timestamp = get_block_timestamp();

            franchise_terms.validate_terms_data(block_timestamp);

            let (agreement_id, agreement_address) = self
                ._create_franchise_agreement(franchisee, franchise_terms);

            // Add Franchise agreement created event
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

        // Create Franchise Agreement from application
        fn create_franchise_agreement_from_application(
            ref self: ContractState, application_id: u256,
        ) {
            self.ownable.assert_only_owner();

            assert(self.ip_asset_linked.read(), Errors::IP_ASSET_NOT_LINKED);

            let application_version = self
                .francise_application_version
                .entry(application_id)
                .read();

            let application = self.get_franchise_application(application_id, application_version);

            assert(
                application.status == ApplicationStatus::Approved, Errors::ApplicationNotApproved,
            );

            let block_timestamp = get_block_timestamp();

            application.current_terms.validate_terms_data(block_timestamp);

            let (agreement_id, agreement_address) = self
                ._create_franchise_agreement(application.franchisee, application.current_terms);

            // Emit an event for the new Franchise Agreement
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

        // Apply for a Franchise Agreement
        fn apply_for_franchise(ref self: ContractState, franchise_terms: FranchiseTerms) {
            assert(self.ip_asset_linked.read(), Errors::IP_ASSET_NOT_LINKED);

            let caller = get_caller_address();

            let block_timestamp = get_block_timestamp();

            franchise_terms.validate_terms_data(block_timestamp);

            let territory_info = self.get_territory_info(franchise_terms.territory_id);

            if (territory_info.exclusivity == ExclusivityType::Exclusive) {
                assert(
                    territory_info.exclusive_to_agreement.is_none(), Errors::TerritoryAlreadyLinked,
                );
            }

            let application_id = self.franchise_applications_count.read();

            let application_version = self
                .francise_application_version
                .entry(application_id)
                .read();

            let application = FranchiseApplication {
                application_id: application_id,
                franchisee: caller,
                current_terms: franchise_terms,
                status: ApplicationStatus::Pending,
                last_proposed_by: caller,
                version: application_version,
            };

            self
                .franchise_applications
                .entry((application_id, application_version))
                .write(application);

            self.franchise_applications_count.write(self.franchise_applications_count.read() + 1);

            let franchisee_application_count = self
                .franchisee_application_count
                .entry(caller)
                .read();

            self
                .franchisee_applications
                .entry((caller, franchisee_application_count))
                .write(application_id);

            self.franchisee_application_count.entry(caller).write(franchisee_application_count + 1);

            // Emit an event for the new Franchise Application
            self
                .emit(
                    NewFranchiseApplication {
                        application_id, franchisee: caller, timestamp: get_block_timestamp(),
                    },
                );
        }

        // Revise franchise application
        fn revise_franchise_application(
            ref self: ContractState, application_id: u256, new_terms: FranchiseTerms,
        ) {
            let caller = get_caller_address();

            let block_timestamp = get_block_timestamp();

            new_terms.validate_terms_data(block_timestamp);

            let application_version = self
                .francise_application_version
                .entry(application_id)
                .read();

            let mut application = self
                .get_franchise_application(application_id, application_version);

            assert(
                application.franchisee == caller || self.ownable.owner() == caller,
                Errors::NotAuthorized,
            );

            assert(
                application.status == ApplicationStatus::Pending
                    || application.status == ApplicationStatus::Revised,
                Errors::InvalidApplicationStatus,
            );

            let territory_info = self.get_territory_info(new_terms.territory_id);

            if (territory_info.exclusivity == ExclusivityType::Exclusive) {
                assert(
                    territory_info.exclusive_to_agreement.is_none(), Errors::TerritoryAlreadyLinked,
                );
            }
            application.current_terms = new_terms;
            application.last_proposed_by = caller;

            // Update the application version
            let new_application_version = application_version + 1;
            self.francise_application_version.entry(application_id).write(new_application_version);

            // Update the application in the mapping
            self
                .franchise_applications
                .entry((application_id, new_application_version))
                .write(application);

            // Emit an event for the revision Franchise Application
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

        // Revise franchise application
        fn accept_franchise_application_revision(ref self: ContractState, application_id: u256) {
            let caller = get_caller_address();

            let application_version = self
                .francise_application_version
                .entry(application_id)
                .read();

            let mut application = self
                .get_franchise_application(application_id, application_version);

            assert(application.franchisee == caller, Errors::NotAuthorized);

            assert(
                application.status == ApplicationStatus::Revised, Errors::InvalidApplicationStatus,
            );

            application.status = ApplicationStatus::RevisionAccepted;

            self
                .franchise_applications
                .entry((application_id, application_version))
                .write(application);

            // Emit an event for the revision Franchise ACceptance
            self
                .emit(
                    ApplicationRevisionAccepted {
                        application_id, franchisee: caller, timestamp: get_block_timestamp(),
                    },
                );
        }

        // Cancel franchise application
        fn cancel_franchise_application(ref self: ContractState, application_id: u256) {
            let caller = get_caller_address();

            let application_version = self
                .francise_application_version
                .entry(application_id)
                .read();

            let mut application = self
                .get_franchise_application(application_id, application_version);
            assert(application.franchisee == caller, Errors::NotApplicationOwner);
            assert(
                application.status == ApplicationStatus::Pending, Errors::CannotCancelApplication,
            );

            application.status = ApplicationStatus::Cancelled;

            self
                .franchise_applications
                .entry((application_id, application_version))
                .write(application);

            // Emit an event for the cancelled Franchise Application
            self
                .emit(
                    FranchiseApplicationCanceled {
                        application_id, franchisee: caller, timestamp: get_block_timestamp(),
                    },
                );
        }


        // Approve franchise application
        fn approve_franchise_application(ref self: ContractState, application_id: u256) {
            self.ownable.assert_only_owner();

            let application_version = self
                .francise_application_version
                .entry(application_id)
                .read();

            let mut application = self
                .get_franchise_application(application_id, application_version);

            assert(
                application.status == ApplicationStatus::Pending
                    || application.status == ApplicationStatus::RevisionAccepted,
                Errors::InvalidApplicationStatus,
            );

            application.status = ApplicationStatus::Approved;

            self
                .franchise_applications
                .entry((application_id, application_version))
                .write(application);

            // Emit an event for the approved Franchise Application
            self
                .emit(
                    FranchiseApplicationApproved {
                        application_id, timestamp: get_block_timestamp(),
                    },
                );
        }

        fn reject_franchise_application(ref self: ContractState, application_id: u256) {
            self.ownable.assert_only_owner();

            let application_version = self
                .francise_application_version
                .entry(application_id)
                .read();

            let mut application = self
                .get_franchise_application(application_id, application_version);

            assert(
                application.status == ApplicationStatus::Pending
                    || application.status == ApplicationStatus::RevisionAccepted,
                Errors::InvalidApplicationStatus,
            );

            application.status = ApplicationStatus::Rejected;

            self
                .franchise_applications
                .entry((application_id, application_version))
                .write(application);

            // Emit an event for the rejected Franchise Application
            self
                .emit(
                    FranchiseApplicationRejected {
                        application_id, timestamp: get_block_timestamp(),
                    },
                );
        }

        // Approve Franchise Sale
        fn initiate_franchise_sale(ref self: ContractState, agreement_id: u256) {
            let caller = get_caller_address();

            let agreement_address = self.franchise_agreements.entry(agreement_id).read();

            assert(caller == agreement_address, Errors::NotAuthorized);

            self.franchise_sale_requested.entry(agreement_id).write(true);

            let sale_id = self.get_total_franchise_sales();

            self.franchise_sale_agreement_ids.entry(sale_id).write(agreement_id);

            self.franchise_sale_count.write(sale_id + 1);

            self
                .emit(
                    FranchiseSaleInitiated {
                        agreement_id, sale_id, timestamp: get_block_timestamp(),
                    },
                );
        }

        // Approve Franchise Sale
        fn approve_franchise_sale(ref self: ContractState, agreement_id: u256) {
            self.ownable.assert_only_owner();

            let agreement_address = self.get_franchise_agreement_address(agreement_id);

            let franchise_agreement = IIPFranchiseAgreementDispatcher {
                contract_address: agreement_address,
            };

            // Approve the license sale
            franchise_agreement.approve_franchise_sale();

            // Emit an event for the approved Franchise License
            self
                .emit(
                    FranchiseSaleApproved {
                        agreement_id, agreement_address, timestamp: get_block_timestamp(),
                    },
                );
        }


        // Reject Franchise Sale
        fn reject_franchise_sale(ref self: ContractState, agreement_id: u256) {
            self.ownable.assert_only_owner();

            let agreement_address = self.get_franchise_agreement_address(agreement_id);

            let franchise_agreement = IIPFranchiseAgreementDispatcher {
                contract_address: agreement_address,
            };

            // Reject the license sale
            franchise_agreement.reject_franchise_sale();

            // Emit an event for the approved Rejected License sale
            self
                .emit(
                    FranchiseSaleRejected {
                        agreement_id, agreement_address, timestamp: get_block_timestamp(),
                    },
                );
        }

        fn revoke_franchise_license(ref self: ContractState, agreement_id: u256) {
            self.ownable.assert_only_owner();

            let agreement_address = self.get_franchise_agreement_address(agreement_id);

            let franchise_agreement = IIPFranchiseAgreementDispatcher {
                contract_address: agreement_address,
            };

            // Revoke the license
            franchise_agreement.revoke_franchise_license();

            // Emit an event for the revoked Franchise License
            self
                .emit(
                    FranchiseAgreementRevoked {
                        agreement_id, agreement_address, timestamp: get_block_timestamp(),
                    },
                );
        }

        fn reinstate_franchise_license(ref self: ContractState, agreement_id: u256) {
            self.ownable.assert_only_owner();

            let agreement_address = self.get_franchise_agreement_address(agreement_id);

            let franchise_agreement = IIPFranchiseAgreementDispatcher {
                contract_address: agreement_address,
            };

            // ReinState the license
            franchise_agreement.reinstate_franchise_license();

            // Emit an event for the revoked Franchise License
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

        /// Get the Agreement ID associated with a given Sale ID
        fn get_franchise_sale_agreement_id(self: @ContractState, sale_id: u256) -> u256 {
            self.franchise_sale_agreement_ids.entry(sale_id).read()
        }

        /// Get the total number of franchise sales listed
        fn get_total_franchise_sales(self: @ContractState) -> u256 {
            self.franchise_sale_count.read()
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

            assert(self.ip_asset_linked.read(), Errors::IP_ASSET_NOT_LINKED);

            let territory_info = self.get_territory_info(franchise_terms.territory_id);

            if (territory_info.exclusivity == ExclusivityType::Exclusive) {
                assert(
                    territory_info.exclusive_to_agreement.is_none(), Errors::TerritoryAlreadyLinked,
                );
            }

            let agreement_id = self.franchise_agreement_count.read();
            let mut constructor_calldata = ArrayTrait::<felt252>::new();
            constructor_calldata.append(agreement_id.try_into().unwrap());
            let franchise_manager: felt252 = get_contract_address().into();
            constructor_calldata.append(franchise_manager);
            let franchisee_felt: felt252 = franchisee.into();
            constructor_calldata.append(franchisee_felt);
            let franchise_terms: Array<felt252> = franchise_terms.into();
            constructor_calldata.append_span(franchise_terms.span());

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

            (agreement_id, agreement_address)
        }
    }
}
