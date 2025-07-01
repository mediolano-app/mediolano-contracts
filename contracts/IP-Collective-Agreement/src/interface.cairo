use starknet::ContractAddress;
use ip_collective_agreement::types::{OwnershipInfo, IPAssetInfo, IPAssetType, ComplianceStatus};

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
