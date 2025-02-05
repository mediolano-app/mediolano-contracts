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
