use starknet::ContractAddress;
use starknet::{get_caller_address, get_block_timestamp};

#[starknet::interface]
pub trait IIPTicketService<TContractState> {
    fn create_ip_asset(
        ref self: TContractState,
        price: u256,
        max_supply: u256,
        expiration: u256,
        royalty_percentage: u256,
        metadata_uri: felt252,
    ) -> u256;

    fn mint_ticket(ref self: TContractState, ip_asset_id: u256);

    fn has_valid_ticket(self: @TContractState, user: ContractAddress, ip_asset_id: u256) -> bool;

    fn royaltyInfo(
        self: @TContractState, token_id: u256, sale_price: u256,
    ) -> (ContractAddress, u256);
}
