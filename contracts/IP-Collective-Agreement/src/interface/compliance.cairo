use starknet::ContractAddress;
use ip_collective_agreement::types::{
    ComplianceRecord, ComplianceVerificationRequest, CountryComplianceRequirements,
    ComplianceAuthority, WorkType,
};

#[starknet::interface]
pub trait IBerneCompliance<TContractState> {
    // Authority Management
    fn register_compliance_authority(
        ref self: TContractState,
        authority_address: ContractAddress,
        authority_name: ByteArray,
        authorized_countries: Span<felt252>,
        authority_type: felt252,
        credentials_uri: ByteArray,
    ) -> bool;

    fn deactivate_compliance_authority(
        ref self: TContractState, authority_address: ContractAddress,
    ) -> bool;

    fn get_compliance_authority(
        self: @TContractState, authority_address: ContractAddress,
    ) -> ComplianceAuthority;

    fn is_authorized_for_country(
        self: @TContractState, authority_address: ContractAddress, country_code: felt252,
    ) -> bool;

    // Country Requirements Management
    fn set_country_requirements(
        ref self: TContractState,
        country_code: felt252,
        requirements: CountryComplianceRequirements,
    ) -> bool;

    fn get_country_requirements(
        self: @TContractState, country_code: felt252,
    ) -> CountryComplianceRequirements;

    fn get_berne_signatory_countries(self: @TContractState) -> Span<felt252>;

    // Compliance Verification Workflow
    fn request_compliance_verification(
        ref self: TContractState,
        asset_id: u256,
        requested_status: felt252,
        evidence_uri: ByteArray,
        country_of_origin: felt252,
        publication_date: u64,
        work_type: felt252,
        is_original_work: bool,
        authors: Span<ContractAddress>,
    ) -> u256;

    fn process_compliance_verification(
        ref self: TContractState,
        request_id: u256,
        approved: bool,
        verifier_notes: ByteArray,
        protection_duration: u64,
        automatic_protection_countries: Span<felt252>,
        manual_registration_required: Span<felt252>,
    ) -> bool;

    // Compliance Status Management
    fn update_compliance_status(
        ref self: TContractState, asset_id: u256, new_status: felt252, evidence_uri: ByteArray,
    ) -> bool;

    fn get_compliance_record(self: @TContractState, asset_id: u256) -> ComplianceRecord;

    fn check_protection_validity(
        self: @TContractState, asset_id: u256, country_code: felt252,
    ) -> bool;

    // Protection Duration and Renewal
    fn calculate_protection_duration(
        self: @TContractState,
        country_code: felt252,
        work_type: felt252,
        publication_date: u64,
        is_anonymous: bool,
    ) -> u64;

    fn check_renewal_requirements(
        self: @TContractState, asset_id: u256,
    ) -> (bool, u64); // (renewal_required, deadline)

    fn renew_protection(
        ref self: TContractState, asset_id: u256, renewal_evidence_uri: ByteArray,
    ) -> bool;

    fn mark_protection_expired(ref self: TContractState, asset_id: u256) -> bool;

    // Cross-Border Protection
    fn register_international_protection(
        ref self: TContractState,
        asset_id: u256,
        target_countries: Span<felt252>,
        registration_evidence: Span<ByteArray>,
    ) -> bool;

    fn check_international_protection_status(
        self: @TContractState, asset_id: u256,
    ) -> (Span<felt252>, Span<felt252>); // (protected_countries, registration_required)

    // Licensing Compliance Integration
    fn validate_license_compliance(
        self: @TContractState,
        asset_id: u256,
        licensee_country: felt252,
        license_territory: felt252,
        usage_rights: felt252,
    ) -> bool;

    fn get_licensing_restrictions(
        self: @TContractState, asset_id: u256, target_country: felt252,
    ) -> Span<felt252>; // Array of restricted usage types

    // Query Functions
    fn get_compliance_verification_request(
        self: @TContractState, request_id: u256,
    ) -> ComplianceVerificationRequest;

    fn get_pending_verification_requests(
        self: @TContractState, authority_address: ContractAddress,
    ) -> Span<u256>;

    fn get_assets_by_compliance_status(self: @TContractState, status: felt252) -> Span<u256>;

    fn get_expiring_protections(self: @TContractState, within_days: u64) -> Span<u256>;

    // Utility Functions
    fn is_work_in_public_domain(
        self: @TContractState, asset_id: u256, country_code: felt252,
    ) -> bool;

    fn get_moral_rights_status(
        self: @TContractState, asset_id: u256, country_code: felt252,
    ) -> bool;

    fn calculate_licensing_fees_by_jurisdiction(
        self: @TContractState, asset_id: u256, base_fee: u256, target_countries: Span<felt252>,
    ) -> Span<u256>; // Adjusted fees per jurisdiction

    // Helper functions to get stored arrays
    fn get_authority_countries(
        self: @TContractState, authority_address: ContractAddress,
    ) -> Span<felt252>;

    fn get_automatic_protection_countries(self: @TContractState, asset_id: u256) -> Span<felt252>;

    fn get_manual_registration_countries(self: @TContractState, asset_id: u256) -> Span<felt252>;

    fn get_verification_authors(self: @TContractState, request_id: u256) -> Span<ContractAddress>;
}
