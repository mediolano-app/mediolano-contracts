use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct LicenseInfo {
    pub license_id: u256,
    pub asset_id: u256,
    pub licensor: ContractAddress, // Who granted the license
    pub licensee: ContractAddress, // Who received the license
    pub license_type: felt252, // Type of license (see LicenseType enum)
    pub usage_rights: felt252, // Usage rights granted (see UsageRights enum)
    pub territory: felt252, // Geographic territory (GLOBAL, US, EU, etc.)
    pub license_fee: u256, // Fee amount for the license
    pub royalty_rate: u256, // Percentage (basis points: 100 = 1%)
    pub start_timestamp: u64, // When license becomes active
    pub end_timestamp: u64, // When license expires (0 = perpetual)
    pub is_active: bool, // Current status
    pub requires_approval: bool, // Whether license needs owner approval
    pub is_approved: bool, // Approval status
    pub payment_token: ContractAddress, // Token for payments (0 = ETH)
    pub metadata_uri: ByteArray, // Additional license terms
    pub is_suspended: bool,
    pub suspension_end_timestamp: u64,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum LicenseType {
    Exclusive, // Only one licensee can use
    NonExclusive, // Multiple licensees allowed
    SoleExclusive, // Licensee + licensor can use
    Sublicensable // Licensee can grant sublicenses
}

#[derive(Drop, Serde, starknet::Store)]
pub enum UsageRights {
    Commercial, // Commercial use allowed
    NonCommercial, // Non-commercial only
    Educational, // Educational use only
    Derivative, // Can create derivative works
    Distribution, // Can distribute/sell
    Display, // Can publicly display
    Performance, // Can perform (music, etc.)
    Reproduction, // Can reproduce/copy
    All // All rights granted
}

#[derive(Drop, Serde, starknet::Store)]
pub enum LicenseStatus {
    Pending, // Awaiting approval
    Active, // Currently valid
    Expired, // Time expired
    Revoked, // Manually revoked
    Suspended // Temporarily suspended
}

#[derive(Drop, Serde, starknet::Store, Copy)]
pub struct LicenseTerms {
    pub max_usage_count: u256, // Maximum number of uses (0 = unlimited)
    pub current_usage_count: u256, // Current usage count
    pub attribution_required: bool, // Must credit original creators
    pub modification_allowed: bool, // Can modify the work
    pub commercial_revenue_share: u256, // Additional revenue share for commercial use
    pub termination_notice_period: u64 // Days notice required for termination
}

#[derive(Drop, Serde, starknet::Store)]
pub struct LicenseProposal {
    pub proposal_id: u256,
    pub asset_id: u256,
    pub proposer: ContractAddress,
    pub votes_for: u256,
    pub votes_against: u256,
    pub voting_deadline: u64,
    pub execution_deadline: u64,
    pub is_executed: bool,
    pub is_cancelled: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct RoyaltyInfo {
    pub asset_id: u256,
    pub licensee: ContractAddress,
    pub total_revenue_reported: u256,
    pub total_royalties_paid: u256,
    pub last_payment_timestamp: u64,
    pub payment_frequency: u64, // Seconds between required payments
    pub next_payment_due: u64,
}

// Conversion implementations for LicenseType
impl LicenseTypeIntoFelt252 of Into<LicenseType, felt252> {
    fn into(self: LicenseType) -> felt252 {
        match self {
            LicenseType::Exclusive => 'EXCLUSIVE',
            LicenseType::NonExclusive => 'NON_EXCLUSIVE',
            LicenseType::SoleExclusive => 'SOLE_EXCLUSIVE',
            LicenseType::Sublicensable => 'SUBLICENSABLE',
        }
    }
}

impl Felt252TryIntoLicenseType of TryInto<felt252, LicenseType> {
    fn try_into(self: felt252) -> Option<LicenseType> {
        if self == 'EXCLUSIVE' {
            Option::Some(LicenseType::Exclusive)
        } else if self == 'NON_EXCLUSIVE' {
            Option::Some(LicenseType::NonExclusive)
        } else if self == 'SOLE_EXCLUSIVE' {
            Option::Some(LicenseType::SoleExclusive)
        } else if self == 'SUBLICENSABLE' {
            Option::Some(LicenseType::Sublicensable)
        } else {
            Option::None
        }
    }
}

// Conversion implementations for UsageRights
impl UsageRightsIntoFelt252 of Into<UsageRights, felt252> {
    fn into(self: UsageRights) -> felt252 {
        match self {
            UsageRights::Commercial => 'COMMERCIAL',
            UsageRights::NonCommercial => 'NON_COMMERCIAL',
            UsageRights::Educational => 'EDUCATIONAL',
            UsageRights::Derivative => 'DERIVATIVE',
            UsageRights::Distribution => 'DISTRIBUTION',
            UsageRights::Display => 'DISPLAY',
            UsageRights::Performance => 'PERFORMANCE',
            UsageRights::Reproduction => 'REPRODUCTION',
            UsageRights::All => 'ALL',
        }
    }
}

impl Felt252TryIntoUsageRights of TryInto<felt252, UsageRights> {
    fn try_into(self: felt252) -> Option<UsageRights> {
        if self == 'COMMERCIAL' {
            Option::Some(UsageRights::Commercial)
        } else if self == 'NON_COMMERCIAL' {
            Option::Some(UsageRights::NonCommercial)
        } else if self == 'EDUCATIONAL' {
            Option::Some(UsageRights::Educational)
        } else if self == 'DERIVATIVE' {
            Option::Some(UsageRights::Derivative)
        } else if self == 'DISTRIBUTION' {
            Option::Some(UsageRights::Distribution)
        } else if self == 'DISPLAY' {
            Option::Some(UsageRights::Display)
        } else if self == 'PERFORMANCE' {
            Option::Some(UsageRights::Performance)
        } else if self == 'REPRODUCTION' {
            Option::Some(UsageRights::Reproduction)
        } else if self == 'ALL' {
            Option::Some(UsageRights::All)
        } else {
            Option::None
        }
    }
}

// Events
#[derive(Drop, starknet::Event)]
pub struct LicenseOfferCreated {
    pub license_id: u256,
    pub asset_id: u256,
    pub licensee: ContractAddress,
    pub license_type: felt252,
    pub license_fee: u256,
    pub requires_approval: bool,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct LicenseApproved {
    pub license_id: u256,
    pub approved_by: ContractAddress,
    pub approved: bool,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct LicenseExecuted {
    pub license_id: u256,
    pub licensee: ContractAddress,
    pub executed_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct LicenseRevoked {
    pub license_id: u256,
    pub revoked_by: ContractAddress,
    pub reason: ByteArray,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct LicenseSuspended {
    pub license_id: u256,
    pub suspended_by: ContractAddress,
    pub suspension_duration: u64,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct LicenseTransferred {
    pub license_id: u256,
    pub old_licensee: ContractAddress,
    pub new_licensee: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RoyaltyPaid {
    pub license_id: u256,
    pub payer: ContractAddress,
    pub amount: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct UsageReported {
    pub license_id: u256,
    pub reporter: ContractAddress,
    pub revenue_amount: u256,
    pub usage_count: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct LicenseProposalCreated {
    pub proposal_id: u256,
    pub asset_id: u256,
    pub proposer: ContractAddress,
    pub voting_deadline: u64,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct LicenseProposalVoted {
    pub proposal_id: u256,
    pub voter: ContractAddress,
    pub vote_for: bool,
    pub voting_weight: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct LicenseProposalExecuted {
    pub proposal_id: u256,
    pub license_id: u256,
    pub executed_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct LicenseReactivated {
    pub license_id: u256,
    pub reactivated_by: ContractAddress,
    pub timestamp: u64,
}
