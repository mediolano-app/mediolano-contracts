use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TimeCapsule {
    pub owner: ContractAddress,
    pub metadata_hash: felt252,
    pub unvesting_timestamp: u64
}