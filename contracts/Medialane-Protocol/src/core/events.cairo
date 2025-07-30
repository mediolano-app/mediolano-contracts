use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct OrderCreated {
    #[key]
    pub order_hash: felt252,
    #[key]
    pub offerer: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct OrderFulfilled {
    #[key]
    pub order_hash: felt252,
    #[key]
    pub offerer: ContractAddress,
    #[key]
    pub fulfiller: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct OrderCancelled {
    #[key]
    pub order_hash: felt252,
    #[key]
    pub offerer: ContractAddress,
}
