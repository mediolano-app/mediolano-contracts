use core::starknet::ContractAddress;
use core::byte_array::ByteArray;
use super::types::Campaign;

#[starknet::interface]
pub trait IIPCrowdfunding<TContractState> {
    fn create_campaign(
        ref self: TContractState,
        asset_id: u256,
        funding_goal: u256,
        duration: u64,
        reward_terms: ByteArray
    ) -> u256;
    fn contribute(ref self: TContractState, campaign_id: u256, amount: u256);
    fn withdraw_funds(ref self: TContractState, campaign_id: u256);
    fn refund(ref self: TContractState, campaign_id: u256);
    fn get_campaign(self: @TContractState, campaign_id: u256) -> Campaign;
    fn get_contribution(
        self: @TContractState, campaign_id: u256, contributor: ContractAddress
    ) -> u256;
}
