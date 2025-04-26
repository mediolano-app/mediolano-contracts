use starknet::ContractAddress;
use super::types::{IPData, Proposal};

#[starknet::interface]
pub trait ICollectiveIP<TContractState> {
    fn register_ip(
        ref self: TContractState,
        token_id: u256,
        metadata_uri: ByteArray,
        owners: Array<ContractAddress>,
        ownership_shares: Array<u256>,
        royalty_rate: u256,
        expiry_date: u64,
        license_terms: ByteArray
    );
    fn distribute_royalties(ref self: TContractState, token_id: u256, total_amount: u256);
    fn create_proposal(ref self: TContractState, token_id: u256, description: ByteArray);
    fn vote(ref self: TContractState, token_id: u256, proposal_id: u256, support: bool);
    fn execute_proposal(ref self: TContractState, token_id: u256, proposal_id: u256);
    fn resolve_dispute(ref self: TContractState, token_id: u256, resolution: ByteArray);
    fn get_ip_metadata(self: @TContractState, token_id: u256) -> IPData;
    fn get_owner(self: @TContractState, token_id: u256, index: u32) -> ContractAddress;
    fn get_ownership_share(self: @TContractState, token_id: u256, owner: ContractAddress) -> u256;
    fn get_proposal(self: @TContractState, proposal_id: u256) -> Proposal;
    fn get_total_supply(self: @TContractState, token_id: u256) -> u256;
    fn set_dispute_resolver(ref self: TContractState, new_resolver: ContractAddress);
}