use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub enum ProposalType {
    LicenseApproval, // Original license proposals
    AssetManagement, // Metadata updates, compliance changes
    RevenuePolicy, // Distribution policies, minimum amounts
    Emergency // Suspension, urgent actions
}

impl ProposalTypeIntoFelt252 of Into<ProposalType, felt252> {
    fn into(self: ProposalType) -> felt252 {
        match self {
            ProposalType::LicenseApproval => 'LICENSE_APPROVAL',
            ProposalType::AssetManagement => 'ASSET_MANAGEMENT',
            ProposalType::RevenuePolicy => 'REVENUE_POLICY',
            ProposalType::Emergency => 'EMERGENCY',
        }
    }
}

impl Felt252TryIntoProposalType of TryInto<felt252, ProposalType> {
    fn try_into(self: felt252) -> Option<ProposalType> {
        if self == 'LICENSE_APPROVAL' {
            Option::Some(ProposalType::LicenseApproval)
        } else if self == 'ASSET_MANAGEMENT' {
            Option::Some(ProposalType::AssetManagement)
        } else if self == 'REVENUE_POLICY' {
            Option::Some(ProposalType::RevenuePolicy)
        } else if self == 'EMERGENCY' {
            Option::Some(ProposalType::Emergency)
        } else {
            Option::None
        }
    }
}

// Governance proposal structure
#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct GovernanceProposal {
    pub proposal_id: u256,
    pub asset_id: u256,
    pub proposal_type: felt252,
    pub proposer: ContractAddress,
    pub votes_for: u256,
    pub votes_against: u256,
    pub total_voting_weight: u256, // Total governance weight at proposal creation
    pub quorum_required: u256, // Minimum participation required
    pub voting_deadline: u64,
    pub execution_deadline: u64,
    pub is_executed: bool,
    pub is_cancelled: bool,
    pub description: ByteArray,
}

// Asset management proposal data
#[derive(Drop, Serde, starknet::Store)]
pub struct AssetManagementProposal {
    pub new_metadata_uri: ByteArray,
    pub new_compliance_status: felt252,
    pub update_metadata: bool,
    pub update_compliance: bool,
}

// Revenue policy proposal data
#[derive(Drop, Serde, starknet::Store)]
pub struct RevenuePolicyProposal {
    pub token_address: ContractAddress,
    pub new_minimum_distribution: u256,
    pub new_distribution_frequency: u64 // Seconds between required distributions
}

// Emergency proposal data
#[derive(Drop, Serde, starknet::Store)]
pub struct EmergencyProposal {
    pub action_type: felt252, // 'SUSPEND_ASSET', 'SUSPEND_LICENSE', 'EMERGENCY_PAUSE'
    pub target_id: u256, // Asset ID or License ID
    pub suspension_duration: u64,
    pub reason: ByteArray,
}

// Governance settings
#[derive(Drop, Serde, starknet::Store, Copy)]
pub struct GovernanceSettings {
    pub default_quorum_percentage: u256, // Basis points (e.g., 5000 = 50%)
    pub emergency_quorum_percentage: u256, // Lower threshold for emergency proposals
    pub license_quorum_percentage: u256, // Threshold for license proposals
    pub asset_mgmt_quorum_percentage: u256, // Threshold for asset management
    pub revenue_policy_quorum_percentage: u256, // Threshold for revenue policy
    pub default_voting_duration: u64, // Default voting period
    pub emergency_voting_duration: u64, // Shorter period for emergency proposals
    pub execution_delay: u64 // Time between approval and execution
}

// Governance events
#[derive(Drop, starknet::Event)]
pub struct GovernanceProposalCreated {
    pub proposal_id: u256,
    pub asset_id: u256,
    pub proposal_type: felt252,
    pub proposer: ContractAddress,
    pub quorum_required: u256,
    pub voting_deadline: u64,
    pub description: ByteArray,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ProposalQuorumReached {
    pub proposal_id: u256,
    pub total_votes: u256,
    pub quorum_required: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct AssetManagementExecuted {
    pub proposal_id: u256,
    pub asset_id: u256,
    pub metadata_updated: bool,
    pub compliance_updated: bool,
    pub executed_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RevenuePolicyUpdated {
    pub proposal_id: u256,
    pub asset_id: u256,
    pub token_address: ContractAddress,
    pub new_minimum_distribution: u256,
    pub executed_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct EmergencyActionExecuted {
    pub proposal_id: u256,
    pub action_type: felt252,
    pub target_id: u256,
    pub executed_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct GovernanceSettingsUpdated {
    pub asset_id: u256,
    pub updated_by: ContractAddress,
    pub timestamp: u64,
}
