use starknet::ContractAddress;
use ip_collective_agreement::types::{OwnershipInfo};

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
