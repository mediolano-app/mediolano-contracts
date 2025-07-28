use starknet::ContractAddress;

// Berne Convention compliance tracking
#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct ComplianceRecord {
    pub asset_id: u256,
    pub compliance_status: felt252,
    pub country_of_origin: felt252, // ISO country code where work was first published
    pub publication_date: u64, // First publication timestamp
    pub registration_authority: ContractAddress, // Who verified compliance
    pub verification_timestamp: u64, // When compliance was verified
    pub compliance_evidence_uri: ByteArray, // IPFS link to compliance documentation
    pub automatic_protection_count: u32, // Countries with automatic protection
    pub manual_registration_count: u32, // Countries requiring manual registration
    pub protection_duration: u64, // Protection duration in seconds
    pub is_anonymous_work: bool, // Anonymous or pseudonymous work
    pub is_collective_work: bool, // Work created by multiple authors
    pub renewal_required: bool, // Whether protection needs renewal
    pub next_renewal_date: u64 // When next renewal is due
}

// Compliance verification request
#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct ComplianceVerificationRequest {
    pub request_id: u256,
    pub asset_id: u256,
    pub requester: ContractAddress,
    pub requested_status: felt252,
    pub evidence_uri: ByteArray, // Documentation proving compliance
    pub country_of_origin: felt252,
    pub publication_date: u64,
    pub work_type: felt252, // Literary, artistic, musical, etc.
    pub is_original_work: bool, // Original vs derivative work
    pub authors_count: u32, // All authors/creators
    pub request_timestamp: u64,
    pub is_processed: bool,
    pub is_approved: bool,
    pub verifier_notes: ByteArray,
}

// Country-specific compliance requirements
#[derive(Drop, Serde, starknet::Store, Copy)]
pub struct CountryComplianceRequirements {
    pub country_code: felt252, // ISO country code
    pub is_berne_signatory: bool, // Member of Berne Convention
    pub automatic_protection: bool, // Automatic copyright protection
    pub registration_required: bool, // Requires formal registration
    pub protection_duration_years: u16, // Years of protection (typically life + 50/70)
    pub notice_required: bool, // Copyright notice requirement
    pub deposit_required: bool, // Deposit copy requirement
    pub translation_rights_duration: u16, // Duration of translation rights
    pub moral_rights_protected: bool // Protects moral rights
}

// Work type classifications under Berne Convention
#[derive(Drop, Serde, starknet::Store)]
pub enum WorkType {
    Literary, // Books, articles, poems
    Artistic, // Paintings, sculptures, drawings
    Musical, // Songs, compositions, scores
    Dramatic, // Plays, screenplays
    Choreographic, // Dance works
    Architectural, // Building designs
    Photographic, // Photos, visual art
    Cinematographic, // Films, videos
    Software, // Computer programs
    Database // Compiled databases
}

impl WorkTypeIntoFelt252 of Into<WorkType, felt252> {
    fn into(self: WorkType) -> felt252 {
        match self {
            WorkType::Literary => 'LITERARY',
            WorkType::Artistic => 'ARTISTIC',
            WorkType::Musical => 'MUSICAL',
            WorkType::Dramatic => 'DRAMATIC',
            WorkType::Choreographic => 'CHOREOGRAPHIC',
            WorkType::Architectural => 'ARCHITECTURAL',
            WorkType::Photographic => 'PHOTOGRAPHIC',
            WorkType::Cinematographic => 'CINEMATOGRAPHIC',
            WorkType::Software => 'SOFTWARE',
            WorkType::Database => 'DATABASE',
        }
    }
}

#[derive(Drop, Serde, starknet::Store)]
pub enum ComplianceStatus {
    Pending,
    BerneCompliant,
    NonCompliant,
    UnderReview,
}

impl ComplianceStatusIntoFelt252 of Into<ComplianceStatus, felt252> {
    fn into(self: ComplianceStatus) -> felt252 {
        match self {
            ComplianceStatus::Pending => 'PENDING',
            ComplianceStatus::BerneCompliant => 'BERNE_COMPLIANT',
            ComplianceStatus::NonCompliant => 'NON_COMPLIANT',
            ComplianceStatus::UnderReview => 'UNDER_REVIEW',
        }
    }
}

impl Felt252TryIntoComplianceStatus of TryInto<felt252, ComplianceStatus> {
    fn try_into(self: felt252) -> Option<ComplianceStatus> {
        if self == 'PENDING' {
            Option::Some(ComplianceStatus::Pending)
        } else if self == 'BERNE_COMPLIANT' {
            Option::Some(ComplianceStatus::BerneCompliant)
        } else if self == 'NON_COMPLIANT' {
            Option::Some(ComplianceStatus::NonCompliant)
        } else if self == 'UNDER_REVIEW' {
            Option::Some(ComplianceStatus::UnderReview)
        } else {
            Option::None
        }
    }
}

// Compliance authority roles
#[derive(Drop, Serde, starknet::Store)]
pub struct ComplianceAuthority {
    pub authority_address: ContractAddress,
    pub authority_name: ByteArray,
    pub authorized_countries_count: u32,
    pub authority_type: felt252, // 'GOVERNMENT', 'CERTIFIED_ORG', 'LEGAL_EXPERT'
    pub is_active: bool,
    pub verification_count: u256, // Number of verifications performed
    pub registration_timestamp: u64,
    pub credentials_uri: ByteArray // Link to authority credentials
}

// Events
#[derive(Drop, starknet::Event)]
pub struct ComplianceVerificationRequested {
    pub request_id: u256,
    pub asset_id: u256,
    pub requester: ContractAddress,
    pub requested_status: felt252,
    pub country_of_origin: felt252,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ComplianceVerified {
    pub asset_id: u256,
    pub new_status: felt252,
    pub verified_by: ContractAddress,
    pub country_of_origin: felt252,
    pub protection_duration: u64,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ComplianceAuthorityRegistered {
    pub authority_address: ContractAddress,
    pub authority_name: ByteArray,
    pub authority_type: felt252,
    pub authorized_countries_count: u32,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ProtectionRenewalRequired {
    pub asset_id: u256,
    pub current_status: felt252,
    pub renewal_deadline: u64,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ProtectionExpired {
    pub asset_id: u256,
    pub previous_status: felt252,
    pub expiration_timestamp: u64,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct CrossBorderProtectionUpdated {
    pub asset_id: u256,
    pub country_code: felt252,
    pub protection_status: bool,
    pub updated_by: ContractAddress,
    pub timestamp: u64,
}
