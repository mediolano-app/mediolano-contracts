use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct OwnershipInfo {
    pub total_owners: u32,
    pub is_active: bool,
    pub registration_timestamp: u64,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct OwnerRevenueInfo {
    pub total_earned: u256,
    pub total_withdrawn: u256,
    pub last_withdrawal_timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct CollectiveOwnershipRegistered {
    pub asset_id: u256,
    pub total_owners: u32,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct IPOwnershipTransferred {
    pub asset_id: u256,
    pub from: ContractAddress,
    pub to: ContractAddress,
    pub percentage: u256,
    pub timestamp: u64,
}

