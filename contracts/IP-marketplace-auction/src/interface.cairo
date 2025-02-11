use starknet::{ContractAddress};

#[starknet::interface]
pub trait IMarketPlace<TContractState> {
    fn create_auction(
        ref self: TContractState,
        token_address: ContractAddress,
        token_id: u256,
        start_price: u256,
        currency_address: ContractAddress,
    ) -> u64;
    fn get_auction(self: @TContractState, auction_id: u64) -> Auction;
    fn commit_bid(ref self: TContractState, auction_id: u64, amount: u256, salt: felt252);
    fn get_auction_bid_count(self: @TContractState, auction_id: u64) -> u64;
    fn reveal_bid(ref self: TContractState, auction_id: u64, amount: u256, salt: felt252);
    fn get_revealed_bids(self: @TContractState, auction_id: u64) -> Span<(u256, ContractAddress)>;
    fn finalize_auction(ref self: TContractState, auction_id: u64);
    fn withdraw_unrevealed_bid(
        ref self: TContractState, auction_id: u64, amount: u256, salt: felt252
    );
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
    pub is_open: bool, // Whether the auction is still open within the specified duration
    pub is_finalized: bool, // Whether the auction is finalized and winner is determined
    pub currency_address: ContractAddress, // Contract address of the currency used for the payment
}
