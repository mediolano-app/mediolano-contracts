use marketplace_auction::interface::{
    IMarketPlace, IMarketPlaceDispatcher, IMarketPlaceDispatcherTrait
};
use marketplace_auction::mock::erc721::{IMyNFTDispatcher, IMyNFTDispatcherTrait};
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp_global, start_cheat_caller_address,
    stop_cheat_block_timestamp_global, stop_cheat_caller_address,
};
use starknet::{ContractAddress, get_block_timestamp};


fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn BOB() -> ContractAddress {
    'BOB'.try_into().unwrap()
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

fn setup() -> (IMarketPlaceDispatcher, IERC721Dispatcher, u256) {
    let marketplace = deploy_marketplace();
    let (erc721, token_id) = deploy_erc721();

    (marketplace, erc721, token_id)
}


fn deploy_marketplace() -> IMarketPlaceDispatcher {
    let contract = declare("MarketPlace").unwrap().contract_class();
    let mut constructor_calldata = array![];

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    IMarketPlaceDispatcher { contract_address }
}

fn deploy_erc721() -> (IERC721Dispatcher, u256) {
    let contract = declare("MyNFT").unwrap().contract_class();
    let mut constructor_calldata: Array<felt252> = array![OWNER().into()];

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    // mint token
    start_cheat_caller_address(contract_address, OWNER());
    let token_id = IMyNFTDispatcher { contract_address }.mint(OWNER());

    (IERC721Dispatcher { contract_address }, token_id)
}

#[test]
#[should_panic(expected: ('Caller is not owner',))]
fn test_create_auction_non_owner() {
    let (marketplace, my_nft, token_id) = setup();

    let auction_id = marketplace
        .create_auction(my_nft.contract_address, token_id, STARTING_PRICE());

    let auction = marketplace.get_auction(auction_id);
}

#[test]
#[should_panic(expected: ('Start price is zero',))]
fn test_create_auction_start_price_is_zero() {
    let (marketplace, my_nft, token_id) = setup();

    let auction_id = marketplace.create_auction(my_nft.contract_address, token_id, 0);

    let auction = marketplace.get_auction(auction_id);
}

#[test]
fn test_create_auction_ok() {
    let (marketplace, my_nft, token_id) = setup();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(my_nft.contract_address, token_id, STARTING_PRICE());

    let auction = marketplace.get_auction(auction_id);

    assert(auction.owner == OWNER(), 'wrong owner');
    assert(auction.token_address == my_nft.contract_address, 'wrong token address');
    assert(auction.token_id == token_id, 'wrong token id');
    assert(auction.start_price == STARTING_PRICE(), 'wrong start price');
    assert(auction.highest_bid == 0, 'wrong highest bid');
    assert(auction.highest_bidder == 0.try_into().unwrap(), 'wrong highest bidder');
    assert(auction.active, 'wrong active status');
}

#[test]
#[should_panic(expected: ('Invalid auction',))]
fn test_commit_bid_invalid_auction() {
    let (marketplace, _, _) = setup();

    let invalid_auction_id = 2_u64;

    marketplace.commit_bid(invalid_auction_id, 200_u256, SALT());
}

#[test]
#[should_panic(expected: ('Bidder is owner',))]
fn test_commit_bid_owner_is_bidder() {
    let (marketplace, my_nft, token_id) = setup();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(my_nft.contract_address, token_id, STARTING_PRICE());

    marketplace.commit_bid(auction_id, 200_u256, SALT());
}

// #[test]
// #[should_panic(expected: ('Auction is not active',))]
// fn test_commit_bid_non_active() {
//     let (marketplace, _) = setup();

//     start_cheat_caller_address(marketplace.contract_address, OWNER());
//     let auction_id = marketplace.create_auction(TOKEN_ADDRESS(), TOKEN_ID(), STARTING_PRICE());

//     marketplace.commit_bid(auction_id, 200_u256, SALT());
// }

#[test]
#[should_panic(expected: ('Amount less than start price',))]
fn test_commit_bid_amount_less_than_start_price() {
    let (marketplace, my_nft, token_id) = setup();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(my_nft.contract_address, token_id, STARTING_PRICE());
    stop_cheat_caller_address(marketplace.contract_address);

    marketplace.commit_bid(auction_id, 0_u256, SALT());
}

#[test]
#[should_panic(expected: ('salt is zero',))]
fn test_commit_bid_salt_is_zero() {
    let (marketplace, my_nft, token_id) = setup();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(my_nft.contract_address, token_id, STARTING_PRICE());
    stop_cheat_caller_address(marketplace.contract_address);

    marketplace.commit_bid(auction_id, STARTING_PRICE(), 0.try_into().unwrap());
}

#[test]
fn test_commit_bid_ok() {
    let (marketplace, my_nft, token_id) = setup();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(my_nft.contract_address, token_id, STARTING_PRICE());
    stop_cheat_caller_address(marketplace.contract_address);

    marketplace.commit_bid(auction_id, STARTING_PRICE(), SALT());
    let bid_count = marketplace.get_auction_bid_count(auction_id);

    assert(bid_count == 1, 'wrong bid count');

    marketplace.commit_bid(auction_id, STARTING_PRICE(), SALT());
    let bid_count = marketplace.get_auction_bid_count(auction_id);

    assert(bid_count == 2, 'wrong bid count');
}

#[test]
#[should_panic(expected: ('No bid found',))]
fn test_reveal_bid_no_bid_found() {
    let (marketplace, my_nft, token_id) = setup();

    let bid_amount = 200_u256;

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(my_nft.contract_address, token_id, STARTING_PRICE());
    stop_cheat_caller_address(marketplace.contract_address);

    // reveal bid
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.reveal_bid(auction_id, bid_amount, SALT());
}

#[test]
#[should_panic(expected: ('Wrong amount or salt',))]
fn test_reveal_bid_wrong_amount() {
    let (marketplace, my_nft, token_id) = setup();

    let bid_amount = 200_u256;
    let wrong_bid_amount = 500_u256;

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(my_nft.contract_address, token_id, STARTING_PRICE());
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, bid_amount, SALT());

    // reveal bid
    marketplace.reveal_bid(auction_id, wrong_bid_amount, SALT());
}

#[test]
#[should_panic(expected: ('Wrong amount or salt',))]
fn test_reveal_bid_wrong_salt() {
    let (marketplace, my_nft, token_id) = setup();

    let bid_amount = 200_u256;

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(my_nft.contract_address, token_id, STARTING_PRICE());
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, bid_amount, SALT());

    // reveal bid
    marketplace.reveal_bid(auction_id, bid_amount, 'wrong_salt'.try_into().unwrap());
}

#[test]
fn test_reveal_bid_ok() {
    let (marketplace, my_nft, token_id) = setup();

    let bid_amount = 200_u256;

    // create auction
    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(my_nft.contract_address, token_id, STARTING_PRICE());
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, bid_amount, SALT());

    // reveal bid
    marketplace.reveal_bid(auction_id, bid_amount, SALT());

    let bids = marketplace.get_revealed_bids(auction_id);
    let (amount, bidder) = bids.at(0);

    assert(bids.len() == 1, 'wrong number of bids');
    assert(*amount == bid_amount, 'wrong bid amount');
    assert(*bidder == BOB(), 'wrong bidder');
}
