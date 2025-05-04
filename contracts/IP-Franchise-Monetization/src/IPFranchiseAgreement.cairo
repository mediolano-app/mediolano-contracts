use super::errors;
use super::interfaces;
use super::types;
use super::events;

pub const FRANCHISEE_ROLE: felt252 = selector!("FRANCHISER_ROLE");
pub const APPROVED_BUYER_ROLE: felt252 = selector!("APPROVED_BUYER");

#[starknet::contract]
pub mod IPFranchisingAgreement {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use core::array::{ArrayTrait, Array};
    use core::felt252;
    use core::panic_with_felt252;
    use core::option::{Option, OptionTrait};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin_access::accesscontrol::AccessControlComponent::InternalTrait;
    use openzeppelin_introspection::src5::SRC5Component;

    use super::{FRANCHISEE_ROLE, APPROVED_BUYER_ROLE};
    use core::starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry,
    };
    use starknet::event::EventEmitter;
    use super::types::{
        FranchiseTerms, RoyaltyPayment, FranchiseSaleRequest, PaymentModel, FranchiseSaleStatus,
        ExclusivityType,
    };
    use super::events::{
        FranchiseAgreementActivated, SaleRequestInitiated, SaleRequestApproved, SaleRequestRejected,
        SaleRequestFinalized, RoyaltyPaymentMade, FranchiseLicenseRevoked,
        FranchiseLicenseReinstated,
    };
    use super::interfaces::{
        IIPFranchiseAgreement, FranchiseTermsTrait, IIPFranchiseManagerDispatcher,
        IIPFranchiseManagerDispatcherTrait, RoyaltyFeesTrait,
    };
    use super::errors::FranchiseAgreementErrors;

    // *************************************************************************
    //                             COMPONENTS
    // *************************************************************************
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // External
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;


    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        agreement_id: u256,
        franchise_manager: ContractAddress,
        franchisee: ContractAddress,
        franchise_terms: FranchiseTerms,
        sale_request: Option<FranchiseSaleRequest>,
        payment_token: ContractAddress,
        royalty_payments: Map<u32, RoyaltyPayment>,
        is_active: bool,
        is_revoked: bool,
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
        AccessControlEvent: AccessControlComponent::Event,
        FranchiseAgreementActivated: FranchiseAgreementActivated,
        SaleRequestInitiated: SaleRequestInitiated,
        SaleRequestApproved: SaleRequestApproved,
        SaleRequestRejected: SaleRequestRejected,
        SaleRequestFinalized: SaleRequestFinalized,
        RoyaltyPaymentMade: RoyaltyPaymentMade,
        FranchiseLicenseRevoked: FranchiseLicenseRevoked,
        FranchiseLicenseReinstated: FranchiseLicenseReinstated,
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(
        ref self: ContractState,
        agreement_id: u256,
        franchise_manager: ContractAddress,
        franchisee: ContractAddress,
        payment_model: PaymentModel,
        payment_token: ContractAddress,
        franchise_fee: u256,
        license_start: u64,
        license_end: u64,
        exclusivity: ExclusivityType,
        territory_id: u256,
    ) {
        self.ownable.initializer(franchise_manager);

        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, franchise_manager);
        self.accesscontrol._grant_role(FRANCHISEE_ROLE, franchisee);

        // construct franchise terms
        let franchise_terms = FranchiseTerms {
            payment_model,
            payment_token,
            franchise_fee,
            license_start,
            license_end,
            exclusivity,
            territory_id,
        };

        self.agreement_id.write(agreement_id);
        self.franchise_manager.write(franchise_manager);
        self.franchise_terms.write(franchise_terms);
        self.franchisee.write(franchisee);
        self.is_revoked.write(false);
        self.is_active.write(false);
    }

    // *************************************************************************
    //                             IMPLEMENTATIONS
    // *************************************************************************
    #[abi(embed_v0)]
    impl IIPFranchiseAgreementImpl of IIPFranchiseAgreement<ContractState> {
        /// Pays the franchise fee to the franchise manager to activate the franchise agreement
        /// # Access Control
        /// Only current franchisee can create sale requests
        fn activate_franchise(ref self: ContractState) {
            // Only franchisee can activate the agreement
            self.accesscontrol.assert_only_role(FRANCHISEE_ROLE);

            let caller = get_caller_address();
            let manager_address = self.franchise_manager.read();

            // Get franchise manager contract dispatcher
            let franchise_manager = IIPFranchiseManagerDispatcher {
                contract_address: manager_address,
            };

            // Verify IP asset is still linked in manager contract
            assert(
                franchise_manager.is_ip_asset_linked(),
                FranchiseAgreementErrors::FranchiseIpNotLinked,
            );

            // Get franchise terms and calculate total fee
            let franchise_terms = self.franchise_terms.read();
            let total_fee_to_pay = franchise_terms.get_total_franchise_fee();

            // Get payment token contract dispatcher
            let dispatcher = IERC20Dispatcher { contract_address: franchise_terms.payment_token };

            // Transfer franchise fee from caller to franchise manager
            let result = dispatcher
                .transfer_from(caller, franchise_manager.contract_address, total_fee_to_pay);

            // Verify transfer was successful
            assert(result, FranchiseAgreementErrors::Erc20TransferFailed);

            // Mark agreement as active
            self.is_active.write(true);

            let agreement_id = self.get_agreement_id();

            // Emit activation event
            self
                .emit(
                    FranchiseAgreementActivated { agreement_id, timestamp: get_block_timestamp() },
                );
        }

        /// Creates a new request to sell the franchise to a new buyer
        /// # Arguments
        /// * `to` - Address of the potential buyer
        /// * `sale_price` - Proposed sale price of the franchise
        /// # Access Control
        /// Only current franchisee can create sale requests
        fn create_sale_request(ref self: ContractState, to: ContractAddress, sale_price: u256) {
            // Verify caller has franchisee role
            self.accesscontrol.assert_only_role(FRANCHISEE_ROLE);

            let manager_address = self.franchise_manager.read();

            // Verify franchise agreement is active
            assert(self.is_active(), FranchiseAgreementErrors::FranchiseAgreementNotActive);

            // Check franchise IP status via manager contract
            let franchise_manager = IIPFranchiseManagerDispatcher {
                contract_address: manager_address,
            };
            assert(
                franchise_manager.is_ip_asset_linked(),
                FranchiseAgreementErrors::FranchiseIpNotLinked,
            );

            // Verify no active sale request exists
            if let Option::Some(request) = self.get_sale_request() {
                assert(
                    request.status == FranchiseSaleStatus::Rejected
                        || request.status == FranchiseSaleStatus::Rejected,
                    FranchiseAgreementErrors::ActiveSaleRequestInProgress,
                );
            }

            let agreement_id = self.get_agreement_id();

            // Notify franchise manager contract
            franchise_manager.initiate_franchise_sale(agreement_id);

            // Create and store sale request
            let transfer_request = FranchiseSaleRequest {
                from: self.franchisee.read(), to, sale_price, status: FranchiseSaleStatus::Pending,
            };
            self.sale_request.write(Option::Some(transfer_request));

            // Emit sale request initiated event
            self
                .emit(
                    SaleRequestInitiated {
                        agreement_id, sale_price, to, timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Approves a pending franchise sale request and grants buyer role
        /// # Arguments
        /// None - uses the sale request stored in contract state
        /// # Access Control
        /// Only admin (franchise manager) can approve sale requests
        fn approve_franchise_sale(ref self: ContractState) {
            // Verify caller has admin role
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);

            // Get and validate sale request exists
            let sale_request = self.sale_request.read();
            assert(sale_request.is_some(), FranchiseAgreementErrors::SaleRequestNotFound);

            // Get sale request data
            let mut sale_request = sale_request.unwrap();

            // Verify sale request is in pending status
            assert(
                sale_request.status == FranchiseSaleStatus::Pending,
                FranchiseAgreementErrors::InvalidSaleStatus,
            );

            // Update status to approved
            sale_request.status = FranchiseSaleStatus::Approved;

            // Grant approved buyer role to the buyer
            self.accesscontrol.grant_role(APPROVED_BUYER_ROLE, sale_request.to);

            // Save updated sale request
            self.sale_request.write(Option::Some(sale_request));

            // Get agreement ID for event
            let agreement_id = self.get_agreement_id();

            // Emit approval event
            self.emit(SaleRequestApproved { agreement_id, timestamp: get_block_timestamp() });
        }

        /// Rejects a pending franchise sale request
        /// # Arguments
        /// None - uses the sale request stored in contract state
        /// # Access Control
        /// Only admin (franchise manager) can reject a sale request
        fn reject_franchise_sale(ref self: ContractState) {
            // Verify caller has admin role
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);

            // Get and validate sale request exists
            let sale_request = self.sale_request.read();
            assert(sale_request.is_some(), FranchiseAgreementErrors::SaleRequestNotFound);

            // Get sale request data
            let mut sale_request = sale_request.unwrap();

            // Verify sale request is in pending status
            assert(
                sale_request.status == FranchiseSaleStatus::Pending,
                FranchiseAgreementErrors::InvalidSaleStatus,
            );

            // Update status to rejected
            sale_request.status = FranchiseSaleStatus::Rejected;

            // Save updated sale request
            self.sale_request.write(Option::Some(sale_request));

            // Get agreement ID for event
            let agreement_id = self.get_agreement_id();

            // Emit rejection event
            self.emit(SaleRequestRejected { agreement_id, timestamp: get_block_timestamp() });
        }

        /// Finalizes the sale of a franchise agreement to an approved buyer
        /// # Arguments
        /// None - relies on the sale request stored in contract state
        /// # Access Control
        /// Only approved buyer can call this function
        fn finalize_franchise_sale(ref self: ContractState) {
            // Verify caller has approved buyer role
            self.accesscontrol.assert_only_role(APPROVED_BUYER_ROLE);

            let caller = get_caller_address();

            // Get and validate sale request exists
            let maybe_sale_request = self.sale_request.read();
            assert(maybe_sale_request.is_some(), FranchiseAgreementErrors::SaleRequestNotFound);

            let mut sale_request = maybe_sale_request.unwrap();

            let franchise_buyer = sale_request.to;

            // Verify caller is the approved buyer
            assert(caller == franchise_buyer, FranchiseAgreementErrors::OnlyBuyerCanFinalizeSale);

            // Verify sale request is in approved status
            assert(
                sale_request.status == FranchiseSaleStatus::Approved,
                FranchiseAgreementErrors::InvalidSaleStatus,
            );

            // Get payment details from franchise terms
            let franchise_terms = self.franchise_terms.read();
            let payment_token = franchise_terms.payment_token;

            // Calculate payment splits (20% fee to manager, 80% to seller)
            let franchise_fee = sale_request.sale_price * 20_u256 / 100_u256; // 20% fee
            let seller_amount = sale_request.sale_price - franchise_fee; // 80% to seller

            let dispatcher = IERC20Dispatcher { contract_address: payment_token };

            // Process franchise fee payment to manager
            let fee_result = dispatcher
                .transfer_from(caller, self.franchise_manager.read(), franchise_fee);
            assert(fee_result, FranchiseAgreementErrors::Erc20TransferFailed);

            // Process sale proceeds payment to seller
            let current_franchisee = self.franchisee.read();
            let seller_result = dispatcher.transfer_from(caller, current_franchisee, seller_amount);
            assert(seller_result, FranchiseAgreementErrors::Erc20TransferFailed);

            // Update access control roles
            self.accesscontrol._revoke_role(FRANCHISEE_ROLE, current_franchisee);
            self.accesscontrol._revoke_role(APPROVED_BUYER_ROLE, franchise_buyer);
            self.accesscontrol._grant_role(FRANCHISEE_ROLE, franchise_buyer);

            // Update franchisee address
            self.franchisee.write(franchise_buyer);

            // Mark sale request as completed
            sale_request.status = FranchiseSaleStatus::Completed;
            self.sale_request.write(Option::Some(sale_request));

            let agreement_id = self.get_agreement_id();

            // Emit sale finalized event
            self
                .emit(
                    SaleRequestFinalized {
                        agreement_id, new_franchisee: caller, timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Makes royalty payments based on reported revenues
        /// # Arguments
        /// * `reported_revenues` - Array of revenues for each missed payment period
        fn make_royalty_payments(ref self: ContractState, reported_revenues: Array<u256>) {
            let caller = get_caller_address();

            let mut franchise_terms = self.franchise_terms.read();

            // Initialize totals
            let mut total_royalty: u256 = 0_u256;
            let mut total_revenue: u256 = 0_256;

            // Handle royalty-based payment model
            if let PaymentModel::RoyaltyBased(mut royalty_fees) = franchise_terms
                .payment_model
                .clone() {
                let block_timestamp = get_block_timestamp();

                let last_payment_id = royalty_fees.last_payment_id;

                // Calculate number of missed payments
                let missed_payments = royalty_fees
                    .calculate_missed_payments(franchise_terms.license_start, block_timestamp);

                // Verify reported revenues match missed payments
                assert(
                    reported_revenues.len() == missed_payments,
                    FranchiseAgreementErrors::RevenueMismatch,
                );

                // Process each payment period
                for mut index in 0..missed_payments {
                    let revenue = match reported_revenues.get(index) {
                        Option::Some(rev) => *rev.unbox(),
                        Option::None => panic!("out of bounds"),
                    };

                    // Increment index by 1 since payment IDs start from 1
                    index += 1;

                    // Validate revenue amount
                    assert(revenue > 0_u256, FranchiseAgreementErrors::InvalidRevenueAmount);

                    // Calculate royalty amount for this period
                    let royalty_amount = royalty_fees.get_royalty_due(revenue);

                    assert(royalty_amount > 0_u256, FranchiseAgreementErrors::InvalidRoyaltyAmount);

                    // Update totals
                    total_royalty += royalty_amount;
                    total_revenue += revenue;

                    let next_payment_id = last_payment_id + index;

                    // Record payment details
                    let royalty_payment = RoyaltyPayment {
                        payment_id: next_payment_id,
                        royalty_paid: royalty_amount,
                        reported_revenue: revenue,
                        timestamp: block_timestamp,
                    };

                    self.royalty_payments.entry(next_payment_id).write(royalty_payment);
                };

                // Transfer total royalty amount
                let dispatcher = IERC20Dispatcher {
                    contract_address: franchise_terms.payment_token,
                };

                let result = dispatcher
                    .transfer_from(caller, self.franchise_manager.read(), total_royalty);
                assert(result, FranchiseAgreementErrors::Erc20TransferFailed);

                // Update payment tracking
                royalty_fees.last_payment_id = last_payment_id + missed_payments;
                franchise_terms.payment_model = PaymentModel::RoyaltyBased(royalty_fees);
            } else {
                panic_with_felt252(FranchiseAgreementErrors::OnlyRoyaltyPayments)
            }

            // Update franchise terms and emit event
            self.franchise_terms.write(franchise_terms);

            let agreement_id = self.get_agreement_id();

            self
                .emit(
                    RoyaltyPaymentMade {
                        agreement_id,
                        total_revenue,
                        total_royalty,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        // Function to revoke a franchise license by the admin (franchise manager)
        fn revoke_franchise_license(ref self: ContractState) {
            // Ensure caller has admin role
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);

            let franchise_terms = self.get_franchise_terms();

            // Check if payment model is royalty based
            if let PaymentModel::RoyaltyBased(royalty_fees) = franchise_terms
                .payment_model
                .clone() {
                let block_timestamp = get_block_timestamp();

                // Calculate number of missed royalty payments
                let missed_payments = royalty_fees
                    .calculate_missed_payments(franchise_terms.license_start, block_timestamp);

                // Can only revoke if missed payments exceed maximum allowed
                assert(
                    missed_payments >= royalty_fees.max_missed_payments,
                    FranchiseAgreementErrors::MaxMissedPaymentsNotReached,
                );
            }

            // Set revoked status to true
            self.is_revoked.write(true);

            let agreement_id = self.get_agreement_id();

            // Emit revocation event
            self.emit(FranchiseLicenseRevoked { agreement_id, timestamp: get_block_timestamp() });
        }


        /// Reinstates a previously revoked franchise license
        /// Only admin can reinstate a license if missed payments are within allowed limit
        fn reinstate_franchise_license(ref self: ContractState) {
            // Verify caller has admin (franchise manager) role
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);

            // Get current franchise terms
            let franchise_terms = self.get_franchise_terms();

            // If payment model is royalty based, check missed payments
            if let PaymentModel::RoyaltyBased(royalty_fees) = franchise_terms
                .payment_model
                .clone() {
                let block_timestamp = get_block_timestamp();

                // Calculate number of missed royalty payments
                let missed_payments = royalty_fees
                    .calculate_missed_payments(franchise_terms.license_start, block_timestamp);

                // Can only reinstate if missed payments are less than maximum allowed
                assert(
                    royalty_fees.max_missed_payments > missed_payments,
                    FranchiseAgreementErrors::MissedPaymentsExceedsMax,
                );
            }

            // Set revoked status to false
            self.is_revoked.write(false);

            // Get agreement ID for event
            let agreement_id = self.get_agreement_id();

            // Emit reinstatement event
            self
                .emit(
                    FranchiseLicenseReinstated { agreement_id, timestamp: get_block_timestamp() },
                );
        }

        // *************************************************************************
        //                              VIEW FUNCTIONS
        // *************************************************************************

        // ───────────── Core Fields
        // ─────────────

        fn get_agreement_id(self: @ContractState) -> u256 {
            self.agreement_id.read()
        }

        fn get_franchise_manager(self: @ContractState) -> ContractAddress {
            self.franchise_manager.read()
        }

        fn get_franchisee(self: @ContractState) -> ContractAddress {
            self.franchisee.read()
        }

        fn get_payment_token(self: @ContractState) -> ContractAddress {
            self.payment_token.read()
        }

        // ───────────── Franchise Terms
        // ─────────────

        fn get_franchise_terms(self: @ContractState) -> FranchiseTerms {
            self.franchise_terms.read()
        }

        // ───────────── Sale Request
        // ─────────────

        fn get_sale_request(self: @ContractState) -> Option<FranchiseSaleRequest> {
            self.sale_request.read()
        }

        // ───────────── Royalty Payments
        // ─────────────

        fn get_royalty_payment_info(self: @ContractState, payment_id: u32) -> RoyaltyPayment {
            self.royalty_payments.entry(payment_id).read()
        }

        // ───────────── Status Flags
        // ─────────────

        fn is_active(self: @ContractState) -> bool {
            let franchise_terms = self.get_franchise_terms();
            let current_time = get_block_timestamp();

            if franchise_terms.license_end > current_time {
                self.is_active.read()
            } else {
                false
            }
        }

        fn is_revoked(self: @ContractState) -> bool {
            self.is_revoked.read()
        }

        fn get_activation_fee(self: @ContractState) -> u256 {
            let franchise_terms = self.get_franchise_terms();

            franchise_terms.get_total_franchise_fee()
        }

        fn get_total_missed_payments(self: @ContractState) -> u32 {
            let franchise_terms = self.get_franchise_terms();
            match franchise_terms.payment_model {
                PaymentModel::OneTime(_) => 0,
                PaymentModel::RoyaltyBased(royalty_fees) => {
                    let block_timestamp = get_block_timestamp();
                    royalty_fees
                        .calculate_missed_payments(franchise_terms.license_start, block_timestamp)
                },
            }
        }
    }
}
