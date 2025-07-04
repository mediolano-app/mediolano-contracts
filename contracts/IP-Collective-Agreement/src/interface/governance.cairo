use starknet::ContractAddress;
use ip_collective_agreement::types::{
    GovernanceProposal, AssetManagementProposal, RevenuePolicyProposal, EmergencyProposal,
    GovernanceSettings, ProposalType,
};

#[starknet::interface]
pub trait IGovernance<TContractState> {
    // Governance Settings Management
    fn set_governance_settings(
        ref self: TContractState, asset_id: u256, settings: GovernanceSettings,
    ) -> bool;

    fn get_governance_settings(self: @TContractState, asset_id: u256) -> GovernanceSettings;

    // Asset Management Proposals
    fn propose_asset_management(
        ref self: TContractState,
        asset_id: u256,
        proposal_data: AssetManagementProposal,
        voting_duration: u64,
        description: ByteArray,
    ) -> u256;

    // Revenue Policy Proposals
    fn propose_revenue_policy(
        ref self: TContractState,
        asset_id: u256,
        proposal_data: RevenuePolicyProposal,
        voting_duration: u64,
        description: ByteArray,
    ) -> u256;

    // Emergency Proposals
    fn propose_emergency_action(
        ref self: TContractState,
        asset_id: u256,
        proposal_data: EmergencyProposal,
        description: ByteArray,
    ) -> u256;

    // Voting with Quorum
    fn vote_on_governance_proposal(
        ref self: TContractState, proposal_id: u256, vote_for: bool,
    ) -> bool;

    // Proposal Execution
    fn execute_asset_management_proposal(ref self: TContractState, proposal_id: u256) -> bool;

    fn execute_revenue_policy_proposal(ref self: TContractState, proposal_id: u256) -> bool;

    fn execute_emergency_proposal(ref self: TContractState, proposal_id: u256) -> bool;

    // Query Functions
    fn get_governance_proposal(self: @TContractState, proposal_id: u256) -> GovernanceProposal;

    fn get_asset_management_proposal(
        self: @TContractState, proposal_id: u256,
    ) -> AssetManagementProposal;

    fn get_revenue_policy_proposal(
        self: @TContractState, proposal_id: u256,
    ) -> RevenuePolicyProposal;

    fn get_emergency_proposal(self: @TContractState, proposal_id: u256) -> EmergencyProposal;

    // Utility Functions
    fn check_quorum_reached(self: @TContractState, proposal_id: u256) -> bool;

    fn get_proposal_participation_rate(self: @TContractState, proposal_id: u256) -> u256;

    fn can_execute_proposal(self: @TContractState, proposal_id: u256) -> bool;

    fn get_active_proposals_for_asset(self: @TContractState, asset_id: u256) -> Array<u256>;
}
