use starknet::ContractAddress;
use ip_collective_agreement::types::{LicenseInfo, LicenseTerms, LicenseProposal, RoyaltyInfo};

#[starknet::interface]
pub trait ILicenseManager<TContractState> {
    fn create_license_request(
        ref self: TContractState,
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
    ) -> u256;

    fn approve_license(ref self: TContractState, license_id: u256, approve: bool) -> bool;

    fn execute_license(ref self: TContractState, license_id: u256) -> bool;

    // License Operations
    fn revoke_license(ref self: TContractState, license_id: u256, reason: ByteArray) -> bool;

    fn suspend_license(
        ref self: TContractState, license_id: u256, suspension_duration: u64,
    ) -> bool;

    fn transfer_license(
        ref self: TContractState, license_id: u256, new_licensee: ContractAddress,
    ) -> bool;

    // Royalty Management
    fn report_usage_revenue(
        ref self: TContractState, license_id: u256, revenue_amount: u256, usage_count: u256,
    ) -> bool;

    fn pay_royalties(ref self: TContractState, license_id: u256, amount: u256) -> bool;

    fn calculate_due_royalties(self: @TContractState, license_id: u256) -> u256;

    // Governance Integration
    fn propose_license_terms(
        ref self: TContractState,
        asset_id: u256,
        proposed_license: LicenseInfo,
        voting_duration: u64,
    ) -> u256;

    fn vote_on_license_proposal(
        ref self: TContractState, proposal_id: u256, vote_for: bool,
    ) -> bool;

    fn execute_license_proposal(ref self: TContractState, proposal_id: u256) -> bool;

    fn check_and_reactivate_license(
        ref self: TContractState,
        license_id: u256,
    ) -> bool;

    fn reactivate_suspended_license(
        ref self: TContractState,
        license_id: u256,
    ) -> bool;

    fn get_license_status(
        self: @TContractState,
        license_id: u256,
    ) -> felt252;

    // Query Functions
    fn get_license_info(self: @TContractState, license_id: u256) -> LicenseInfo;

    fn get_license_terms(self: @TContractState, license_id: u256) -> LicenseTerms;

    fn get_asset_licenses(self: @TContractState, asset_id: u256) -> Array<u256>;

    fn get_licensee_licenses(self: @TContractState, licensee: ContractAddress) -> Array<u256>;

    fn is_license_valid(self: @TContractState, license_id: u256) -> bool;

    fn get_royalty_info(self: @TContractState, license_id: u256) -> RoyaltyInfo;

    fn get_license_proposal(self: @TContractState, proposal_id: u256) -> LicenseProposal;

    fn get_proposed_license(self: @TContractState, proposal_id: u256) -> LicenseInfo;

    // Helper functions for license discovery
    fn get_available_licenses(self: @TContractState, asset_id: u256) -> Array<u256>;

    fn get_pending_licenses_for_licensee(
        self: @TContractState, licensee: ContractAddress,
    ) -> Array<u256>;

    // Settings
    fn set_default_license_terms(
        ref self: TContractState, asset_id: u256, terms: LicenseTerms,
    ) -> bool;
}
