use starknet::ContractAddress;
use ip_collective_agreement::types::{
    OwnershipInfo, IPAssetInfo, IPAssetType, ComplianceStatus, RevenueInfo, OwnerRevenueInfo,
};

#[starknet::interface]
pub trait IOwnershipRegistry<TContractState> {
    // Ownership Management
    fn register_collective_ownership(
        ref self: TContractState,
        asset_id: u256,
        owners: Span<ContractAddress>,
        ownership_percentages: Span<u256>,
        governance_weights: Span<u256>,
    ) -> bool;

    fn get_ownership_info(self: @TContractState, asset_id: u256) -> OwnershipInfo;
    fn get_owner_percentage(self: @TContractState, asset_id: u256, owner: ContractAddress) -> u256;
    fn transfer_ownership_share(
        ref self: TContractState,
        asset_id: u256,
        from: ContractAddress,
        to: ContractAddress,
        percentage: u256,
    ) -> bool;

    // Access Control
    fn is_owner(self: @TContractState, asset_id: u256, address: ContractAddress) -> bool;
    fn has_governance_rights(
        self: @TContractState, asset_id: u256, address: ContractAddress,
    ) -> bool;
    fn get_governance_weight(self: @TContractState, asset_id: u256, owner: ContractAddress) -> u256;
}

#[starknet::interface]
pub trait IIPAssetManager<TContractState> {
    // Asset Registration
    fn register_ip_asset(
        ref self: TContractState,
        asset_type: felt252,
        metadata_uri: ByteArray,
        creators: Span<ContractAddress>,
        ownership_percentages: Span<u256>,
        governance_weights: Span<u256>,
    ) -> u256;

    // Asset Management
    fn get_asset_info(self: @TContractState, asset_id: u256) -> IPAssetInfo;
    fn update_asset_metadata(
        ref self: TContractState, asset_id: u256, new_metadata_uri: ByteArray,
    ) -> bool;
    fn mint_additional_tokens(
        ref self: TContractState, asset_id: u256, to: ContractAddress, amount: u256,
    ) -> bool;

    // Verification
    fn verify_asset_ownership(self: @TContractState, asset_id: u256) -> bool;
    fn get_total_supply(self: @TContractState, asset_id: u256) -> u256;
    fn get_asset_uri(self: @TContractState, token_id: u256) -> ByteArray;

    fn pause_contract(ref self: TContractState);
    fn unpause_contract(ref self: TContractState);
}

/// Revenue Distribution Interface
#[starknet::interface]
pub trait IRevenueDistribution<TContractState> {
    fn receive_revenue(
        ref self: TContractState, asset_id: u256, token_address: ContractAddress, amount: u256,
    ) -> bool;

    fn distribute_revenue(
        ref self: TContractState, asset_id: u256, token_address: ContractAddress, amount: u256,
    ) -> bool;

    fn distribute_all_revenue(
        ref self: TContractState, asset_id: u256, token_address: ContractAddress,
    ) -> bool;

    // Withdrawal functions
    fn withdraw_pending_revenue(
        ref self: TContractState, asset_id: u256, token_address: ContractAddress,
    ) -> u256;

    fn get_accumulated_revenue(
        self: @TContractState, asset_id: u256, token_address: ContractAddress,
    ) -> u256;

    // Revenue tracking
    fn get_pending_revenue(
        self: @TContractState,
        asset_id: u256,
        owner: ContractAddress,
        token_address: ContractAddress,
    ) -> u256;

    fn get_total_revenue_distributed(
        self: @TContractState, asset_id: u256, token_address: ContractAddress,
    ) -> u256;

    fn get_owner_total_earned(
        self: @TContractState,
        asset_id: u256,
        owner: ContractAddress,
        token_address: ContractAddress,
    ) -> u256;

    // Settings
    fn set_minimum_distribution(
        ref self: TContractState, asset_id: u256, min_amount: u256, token_address: ContractAddress,
    ) -> bool;
    fn get_minimum_distribution(
        self: @TContractState, asset_id: u256, token_address: ContractAddress,
    ) -> u256;
}
