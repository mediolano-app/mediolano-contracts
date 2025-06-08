// Imports
use starknet::ContractAddress;

// Storage imports
use starknet::storage::*;

// Structs for Storage - Must derive Copy, Drop, and starknet::Store
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Asset {
    pub creator: ContractAddress,
    pub goal: u256,
    pub raised: u256,
    pub start_time: u64,
    pub end_time: u64,
    pub base_price: u256,
    pub is_closed: bool, // Use bool type
    pub ipfs_hash_len: u64,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Investment {
    pub amount: u256,
    pub timestamp: u64,
}

// Define the contract interface
#[starknet::interface]
pub trait ICrowdfunding<TContractState> {
    fn create_asset(
        ref self: TContractState,
        goal: u256,
        duration: u64,
        base_price: u256,
        ipfs_hash: Array<felt252>
    );

    fn fund(ref self: TContractState, asset_id: u64, amount: u256); // Payable functions receive amount

    fn close_funding(ref self: TContractState, asset_id: u64);

    fn withdraw_creator(ref self: TContractState, asset_id: u64);

    fn withdraw_investor(ref self: TContractState, asset_id: u64);

    // View functions
    fn get_asset_count(self: @TContractState) -> u64;
    fn get_asset_data(self: @TContractState, asset_id: u64) -> Asset;
    fn get_asset_ipfs_hash(self: @TContractState, asset_id: u64) -> Array<felt252>;
    fn get_investor_data(self: @TContractState, asset_id: u64, investor: ContractAddress) -> Investment;
}