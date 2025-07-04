use starknet::ContractAddress;

#[starknet::interface]

pub trait ITimeCapsule<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, metadata_hash: felt252, unvesting_timestamp: u64) -> u256;
    fn get_metadata(self: @TContractState, token_id: u256) -> felt252;
    fn set_metadata(ref self: TContractState, token_id: u256, metadata_hash: felt252);
}