use starknet::{ContractAddress};

#[starknet::interface]
pub trait IMarketPlace<TContractState> {
    fn create_auction(
        ref self: TContractState, token_address: ContractAddress, token_id: u256, start_price: u256
    ) -> u64;
    fn get_auction(self: @TContractState, auction_id: u64) -> Auction;
    fn commit_bid(ref self: TContractState);
    fn reveal_bid(ref self: TContractState);
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct Auction {
    pub owner: ContractAddress, // Seller's address
    pub token_address: ContractAddress, // NFT contract address
    pub token_id: u256, // NFT Token ID
    pub start_price: u256, // Minimum bid price
    pub highest_bid: u256, // Highest revealed bid
    pub highest_bidder: ContractAddress, // Address of highest bidder
    pub end_time: u64, // Auction end time
    pub active: bool // Whether the auction is active
}
