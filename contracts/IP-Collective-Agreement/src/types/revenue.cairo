use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store, Copy)]
pub struct RevenueInfo {
    pub total_received: u256, // Total revenue received for this asset
    pub total_distributed: u256, // Total revenue distributed to owners
    pub accumulated_revenue: u256, // Revenue waiting to be distributed
    pub last_distribution_timestamp: u64,
    pub minimum_distribution: u256,
    pub distribution_count: u32,
}

/// Revenue Distribution Events
#[derive(Drop, starknet::Event)]
pub struct RevenueReceived {
    pub asset_id: u256,
    pub token_address: ContractAddress,
    pub amount: u256,
    pub from: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RevenueDistributed {
    pub asset_id: u256,
    pub token_address: ContractAddress,
    pub total_amount: u256,
    pub recipients_count: u32,
    pub distributed_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RevenueWithdrawn {
    pub asset_id: u256,
    pub owner: ContractAddress,
    pub token_address: ContractAddress,
    pub amount: u256,
    pub timestamp: u64,
}

