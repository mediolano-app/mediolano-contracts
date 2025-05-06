use starknet::ContractAddress;
use super::types::{
    FranchiseApplication, FranchiseTerms, Territory, PaymentModel, FranchiseSaleRequest,
    RoyaltyPayment,
};
use starknet::ClassHash;

#[starknet::interface]
pub trait IIPFranchiseManager<TContractState> {
    fn link_ip_asset(ref self: TContractState);
    fn unlink_ip_asset(ref self: TContractState);

    fn add_franchise_territory(ref self: TContractState, name: ByteArray);
    fn deactivate_franchise_territory(ref self: TContractState, territory_id: u256);

    fn create_direct_franchise_agreement(
        ref self: TContractState, franchisee: ContractAddress, franchise_terms: FranchiseTerms,
    );
    fn create_franchise_agreement_from_application(ref self: TContractState, application_id: u256);

    fn apply_for_franchise(ref self: TContractState, franchise_terms: FranchiseTerms);
    fn cancel_franchise_application(ref self: TContractState, application_id: u256);
    fn revise_franchise_application(
        ref self: TContractState, application_id: u256, new_terms: FranchiseTerms,
    );
    fn accept_franchise_application_revision(ref self: TContractState, application_id: u256);
    fn approve_franchise_application(ref self: TContractState, application_id: u256);
    fn reject_franchise_application(ref self: TContractState, application_id: u256);

    fn revoke_franchise_license(ref self: TContractState, agreement_id: u256);
    fn reinstate_franchise_license(ref self: TContractState, agreement_id: u256);

    fn initiate_franchise_sale(ref self: TContractState, agreement_id: u256);
    fn approve_franchise_sale(ref self: TContractState, agreement_id: u256);
    fn reject_franchise_sale(ref self: TContractState, agreement_id: u256);

    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);

    // ───────────── IP NFT Info ─────────────
    fn get_ip_nft_id(self: @TContractState) -> u256;
    fn get_ip_nft_address(self: @TContractState) -> ContractAddress;
    fn is_ip_asset_linked(self: @TContractState) -> bool;

    // ───────────── Territory Info
    // ─────────────
    fn get_territory_info(self: @TContractState, territory_id: u256) -> Territory;
    fn get_total_territories(self: @TContractState) -> u256;

    // ───────────── Franchise Agreements
    // ─────────────
    fn get_franchise_agreement_address(
        self: @TContractState, agreement_id: u256,
    ) -> ContractAddress;
    fn get_franchise_agreement_id(
        self: @TContractState, agreement_address: ContractAddress,
    ) -> u256;
    fn get_total_franchise_agreements(self: @TContractState) -> u256;
    fn get_franchisee_agreement(
        self: @TContractState, franchisee: ContractAddress, index: u256,
    ) -> u256;
    fn get_franchisee_agreement_count(self: @TContractState, franchisee: ContractAddress) -> u256;

    // ───────────── Franchise Applications
    // ─────────────
    fn get_franchise_application(
        self: @TContractState, application_id: u256, version: u8,
    ) -> FranchiseApplication;
    fn get_franchise_application_version(self: @TContractState, application_id: u256) -> u8;
    fn get_total_franchise_applications(self: @TContractState) -> u256;
    fn get_franchisee_application(
        self: @TContractState, franchisee: ContractAddress, index: u256,
    ) -> u256;
    fn get_franchisee_application_count(self: @TContractState, franchisee: ContractAddress) -> u256;

    // Franchise Sales

    fn is_franchise_sale_requested(self: @TContractState, agreement_id: u256) -> bool;
    fn get_total_franchise_sale_requests(self: @TContractState) -> u256;

    // ───────────── Config / Defaults
    // ─────────────
    fn get_preferred_payment_model(self: @TContractState) -> PaymentModel;
    fn get_default_franchise_fee(self: @TContractState) -> u256;
}


#[starknet::interface]
pub trait IIPFranchiseAgreement<TContractState> {
    fn activate_franchise(ref self: TContractState);

    fn create_sale_request(ref self: TContractState, to: ContractAddress, sale_price: u256);
    fn approve_franchise_sale(ref self: TContractState);
    fn reject_franchise_sale(ref self: TContractState);
    fn finalize_franchise_sale(ref self: TContractState);

    fn make_royalty_payments(ref self: TContractState, reported_revenues: Array<u256>);

    fn revoke_franchise_license(ref self: TContractState);
    fn reinstate_franchise_license(ref self: TContractState);

    // ───────────── Core Fields ─────────────
    fn get_agreement_id(self: @TContractState) -> u256;
    fn get_franchise_manager(self: @TContractState) -> ContractAddress;
    fn get_franchisee(self: @TContractState) -> ContractAddress;
    fn get_payment_token(self: @TContractState) -> ContractAddress;

    // ───────────── Franchise Terms
    // ─────────────
    fn get_franchise_terms(self: @TContractState) -> FranchiseTerms;

    // ───────────── Sale Request ─────────────
    fn get_sale_request(self: @TContractState) -> Option<FranchiseSaleRequest>;

    // ───────────── Royalty Payments
    // ─────────────
    fn get_royalty_payment_info(self: @TContractState, payment_id: u32) -> RoyaltyPayment;

    // ───────────── Status Flags ─────────────
    fn is_active(self: @TContractState) -> bool;
    fn is_revoked(self: @TContractState) -> bool;

    // ____________ Activation Fee ____________
    fn get_activation_fee(self: @TContractState) -> u256;

    // ___________ Missed Payments ____________
    fn get_total_missed_payments(self: @TContractState) -> u32;
}

/// A trait to describe order capability.
pub trait FranchiseTermsTrait<T, +Serde<T>, +Drop<T>> {
    fn validate_terms_data(self: @T, block_timestamp: u64);
    fn get_total_franchise_fee(self: @T) -> u256;
    fn get_last_payment_id(self: @T) -> u32;
}

pub trait RoyaltyFeesTrait<T, +Serde<T>, +Drop<T>> {
    fn get_payment_interval(self: @T) -> u64;

    fn calculate_missed_payments(self: @T, license_start: u64, block_timestamp: u64) -> u32;

    fn is_royalty_due(self: @T, license_start: u64, block_timestamp: u64) -> bool;

    fn get_next_payment_due(self: @T, license_start: u64) -> u64;

    fn get_royalty_due(self: @T, revenue: u256) -> u256;

    fn get_total_no_expected_payments(self: @T, duration: u64) -> u64;
}
