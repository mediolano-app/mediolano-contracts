use core::starknet::ContractAddress;
use core::byte_array::ByteArray;

#[derive(Drop, Serde, starknet::Store)]
pub struct Campaign {
    pub creator: ContractAddress,
    pub asset_id: u256,
    pub funding_goal: u256,
    pub total_raised: u256,
    pub start_time: u64,
    pub end_time: u64,
    pub reward_terms: ByteArray,
    pub is_active: bool,
    pub is_funded: bool,
    pub funds_withdrawn: bool
}

#[derive(Drop, Serde, starknet::Store)]
pub struct CampaignStats {
    pub total_contributors: u32,
    pub avg_contribution: u256,
    pub largest_contribution: u256,
    pub funding_progress: u256
}

// Constants
pub const MIN_DURATION: u64 = 86400; // 1 day in seconds
pub const MAX_DURATION: u64 = 7776000; // 90 days in seconds
pub const ERROR_INVALID_DURATION: felt252 = 'Invalid campaign duration';
pub const ERROR_INVALID_GOAL: felt252 = 'Invalid funding goal';
pub const ERROR_CAMPAIGN_NOT_FOUND: felt252 = 'Campaign not found';
pub const ERROR_CAMPAIGN_ENDED: felt252 = 'Campaign has ended';
pub const ERROR_CAMPAIGN_ACTIVE: felt252 = 'Campaign still active';
pub const ERROR_ALREADY_WITHDRAWN: felt252 = 'Funds already withdrawn';
pub const ERROR_NOT_FUNDED: felt252 = 'Campaign not funded';
pub const ERROR_NOT_CREATOR: felt252 = 'Not campaign creator';
pub const ERROR_NO_CONTRIBUTION: felt252 = 'No contribution found';
