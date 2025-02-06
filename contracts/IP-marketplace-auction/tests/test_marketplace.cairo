use marketplace_auction::interface::{
    IMarketPlace, IMarketPlaceDispatcher, IMarketPlaceDispatcherTrait
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp_global, start_cheat_caller_address,
    stop_cheat_block_timestamp_global, stop_cheat_caller_address,
};
use starknet::{ContractAddress, get_block_timestamp};


fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn TOKEN_ADDRESS() -> ContractAddress {
    'TOKEN_ADDRESS'.try_into().unwrap()
}

fn TOKEN_ID() -> u256 {
    1
}

fn STARTING_PRICE() -> u256 {
    200
}

fn SALT() -> felt252 {
    'salt'.try_into().unwrap()
}


fn deploy() -> IMarketPlaceDispatcher {
    let contract = declare("MarketPlace").unwrap().contract_class();
    let mut constructor_calldata = array![];

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    IMarketPlaceDispatcher { contract_address }
}

#[test]
fn test_create_auction() {
    let marketplace = deploy();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace.create_auction(TOKEN_ADDRESS(), TOKEN_ID(), STARTING_PRICE());

    let auction = marketplace.get_auction(auction_id);

    assert(auction.owner == OWNER(), 'wrong owner');
    assert(auction.token_address == TOKEN_ADDRESS(), 'wrong token address');
    assert(auction.token_id == TOKEN_ID(), 'wrong token id');
    assert(auction.start_price == STARTING_PRICE(), 'wrong start price');
    assert(auction.highest_bid == 0, 'wrong highest bid');
    assert(auction.highest_bidder == 0.try_into().unwrap(), 'wrong highest bidder');
    assert(auction.active, 'wrong active status');
}

#[test]
#[should_panic(expected: ('Invalid auction',))]
fn test_commit_bid_invalid_auction() {
    let marketplace = deploy();

    let invalid_auction_id = 2_u64;

    marketplace.commit_bid(invalid_auction_id, 200_u256, SALT());
}

#[test]
#[should_panic(expected: ('Bidder is owner',))]
fn test_commit_bid_owner_is_bidder() {
    let marketplace = deploy();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace.create_auction(TOKEN_ADDRESS(), TOKEN_ID(), STARTING_PRICE());

    marketplace.commit_bid(auction_id, 200_u256, SALT());
}

// #[test]
// #[should_panic(expected: ('Auction is not active',))]
// fn test_commit_bid_non_active() {
//     let marketplace = deploy();

//     start_cheat_caller_address(marketplace.contract_address, OWNER());
//     let auction_id = marketplace.create_auction(TOKEN_ADDRESS(), TOKEN_ID(), STARTING_PRICE());

//     marketplace.commit_bid(auction_id, 200_u256, SALT());
// }

#[test]
#[should_panic(expected: ('Amount less than start price',))]
fn test_commit_bid_amount_less_than_start_price() {
    let marketplace = deploy();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace.create_auction(TOKEN_ADDRESS(), TOKEN_ID(), STARTING_PRICE());
    stop_cheat_caller_address(marketplace.contract_address);

    marketplace.commit_bid(auction_id, 0_u256, SALT());
}

#[test]
#[should_panic(expected: ('salt is zero',))]
fn test_commit_bid_salt_is_zero() {
    let marketplace = deploy();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace.create_auction(TOKEN_ADDRESS(), TOKEN_ID(), STARTING_PRICE());
    stop_cheat_caller_address(marketplace.contract_address);

    marketplace.commit_bid(auction_id, STARTING_PRICE(), 0.try_into().unwrap());
}

#[test]
fn test_commit_bid_ok() {
    let marketplace = deploy();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace.create_auction(TOKEN_ADDRESS(), TOKEN_ID(), STARTING_PRICE());
    stop_cheat_caller_address(marketplace.contract_address);

    marketplace.commit_bid(auction_id, STARTING_PRICE(), SALT());
    let bid_count = marketplace.get_auction_bid_count(auction_id);

    assert(bid_count == 1, 'wrong bid count');

    marketplace.commit_bid(auction_id, STARTING_PRICE(), SALT());
    let bid_count = marketplace.get_auction_bid_count(auction_id);

    assert(bid_count == 2, 'wrong bid count');
}
