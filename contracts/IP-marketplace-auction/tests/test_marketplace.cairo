use marketplace_auction::interface::{IMarketPlaceDispatcher, IMarketPlaceDispatcherTrait};
use marketplace_auction::mock::erc721::{IMyNFTDispatcher, IMyNFTDispatcherTrait};
use marketplace_auction::utils::{constants};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use snforge_std::{
    EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    start_cheat_block_timestamp, stop_cheat_caller_address_global
};
use starknet::{ContractAddress, get_block_timestamp};

use super::test_utils::{
    TIMESTAMP, AUCTION_DURATION, REVEAL_DURATION, OWNER, BOB, ALICE, TOKEN_ADDRESS, TOKEN_ID,
    STARTING_PRICE, SALT, fast_forward, setup
};

#[test]
#[should_panic(expected: ('Caller is not owner',))]
fn test_create_auction_non_owner() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );

    marketplace.get_auction(auction_id);
}

#[test]
#[should_panic(expected: ('Start price is zero',))]
fn test_create_auction_start_price_is_zero() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    let auction_id = marketplace
        .create_auction(my_nft.contract_address, token_id, 0, my_token.contract_address);

    marketplace.get_auction(auction_id);
}

#[test]
#[should_panic(expected: ('Currency address is zero',))]
fn test_create_auction_currency_address_is_zero() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(my_nft.contract_address, token_id, STARTING_PRICE(), 0.try_into().unwrap());

    marketplace.get_auction(auction_id);
}

#[test]
fn test_create_auction_ok() {
    let (marketplace, my_nft, token_id, my_token) = setup();
    let expected_timestamp: u64 = TIMESTAMP + (1 * constants::DAY_IN_SECONDS);

    // approve marketplace
    start_cheat_caller_address(my_nft.contract_address, OWNER());
    my_nft.approve(marketplace.contract_address, token_id);
    stop_cheat_caller_address(my_nft.contract_address);

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );

    let auction = marketplace.get_auction(auction_id);

    assert(auction.owner == OWNER(), 'wrong owner');
    assert(auction.token_address == my_nft.contract_address, 'wrong token address');
    assert(auction.token_id == token_id, 'wrong token id');
    assert(auction.start_price == STARTING_PRICE(), 'wrong start price');
    assert(auction.highest_bid == 0, 'wrong highest bid');
    assert(auction.highest_bidder == 0.try_into().unwrap(), 'wrong highest bidder');
    assert(auction.is_open, 'wrong open status');
    assert(!auction.is_finalized, 'should not be finalized');
    assert(auction.end_time == expected_timestamp, 'wrong end time');

    assert(my_nft.owner_of(token_id) == marketplace.contract_address, 'asset transfer failed');
}

#[test]
#[should_panic(expected: ('Invalid auction',))]
fn test_commit_bid_invalid_auction() {
    let (marketplace, _, _, _) = setup();

    let invalid_auction_id = 2_u64;

    marketplace.commit_bid(invalid_auction_id, 200_u256, SALT());
}

#[test]
#[should_panic(expected: ('Bidder is owner',))]
fn test_commit_bid_owner_is_bidder() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );

    marketplace.commit_bid(auction_id, 200_u256, SALT());
}

#[test]
#[should_panic(expected: ('Auction closed',))]
fn test_commit_bid_auction_closed() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    fast_forward(marketplace.contract_address, AUCTION_DURATION);

    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, 200_u256, SALT());
}

#[test]
#[should_panic(expected: ('Amount less than start price',))]
fn test_commit_bid_amount_less_than_start_price() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    marketplace.commit_bid(auction_id, 0_u256, SALT());
}

#[test]
#[should_panic(expected: ('Salt is zero',))]
fn test_commit_bid_salt_is_zero() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    marketplace.commit_bid(auction_id, STARTING_PRICE(), 0.try_into().unwrap());
}

#[test]
#[should_panic(expected: ('Insufficient funds',))]
fn test_commit_bid_insufficient_funds() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    marketplace.commit_bid(auction_id, STARTING_PRICE(), SALT());
}

#[test]
fn test_commit_bid_ok() {
    let (marketplace, my_nft, token_id, my_token) = setup();
    let bid_amount = 200_u256;

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    let balance_before = my_token.balance_of(marketplace.contract_address);

    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, bid_amount, SALT());
    let bid_count = marketplace.get_auction_bid_count(auction_id);

    assert(bid_count == 1, 'wrong bid count');

    marketplace.commit_bid(auction_id, bid_amount, SALT());
    let bid_count = marketplace.get_auction_bid_count(auction_id);

    assert(bid_count == 2, 'wrong bid count');

    let balance_after = my_token.balance_of(marketplace.contract_address);

    assert(balance_after - balance_before == 400_u256, 'wrong balance');
}

#[test]
#[should_panic(expected: ('No bid found',))]
fn test_reveal_bid_when_no_bid() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    let bid_amount = 200_u256;

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    fast_forward(marketplace.contract_address, AUCTION_DURATION);

    // reveal bid
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.reveal_bid(auction_id, bid_amount, SALT());
}

#[test]
#[should_panic(expected: ('Auction is still open',))]
fn test_reveal_bid_when_auction_open() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    let bid_amount = 200_u256;

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, bid_amount, SALT());

    // reveal bid
    marketplace.reveal_bid(auction_id, bid_amount, SALT());
}

#[test]
#[should_panic(expected: ('Wrong amount or salt',))]
fn test_reveal_bid_wrong_amount() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    let bid_amount = 200_u256;
    let wrong_bid_amount = 500_u256;

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, bid_amount, SALT());

    fast_forward(marketplace.contract_address, AUCTION_DURATION);

    // reveal bid
    marketplace.reveal_bid(auction_id, wrong_bid_amount, SALT());
}

#[test]
#[should_panic(expected: ('Wrong amount or salt',))]
fn test_reveal_bid_wrong_salt() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    let bid_amount = 200_u256;

    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, bid_amount, SALT());

    fast_forward(marketplace.contract_address, AUCTION_DURATION);

    // reveal bid
    marketplace.reveal_bid(auction_id, bid_amount, 'wrong_salt'.try_into().unwrap());
}

#[test]
fn test_reveal_bid_ok() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    let bid_amount = 200_u256;

    // create auction
    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, bid_amount, SALT());

    fast_forward(marketplace.contract_address, AUCTION_DURATION);

    // reveal bid
    marketplace.reveal_bid(auction_id, bid_amount, SALT());

    let bids = marketplace.get_revealed_bids(auction_id);
    let (amount, bidder) = bids.at(0);

    assert(bids.len() == 1, 'wrong number of bids');
    assert(*amount == bid_amount, 'wrong bid amount');
    assert(*bidder == BOB(), 'wrong bidder');
}

#[test]
#[should_panic(expected: ('Auction is still open',))]
fn test_finalize_auction_when_open() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    let bid_amount = 200_u256;

    // create auction
    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, bid_amount, SALT());

    // reveal bid
    marketplace.reveal_bid(auction_id, bid_amount, SALT());

    let bids = marketplace.get_revealed_bids(auction_id);
    let (amount, bidder) = bids.at(0);

    // finalize bid
    marketplace.finalize_auction(auction_id);
}

#[test]
#[should_panic(expected: ('Reveal time not over',))]
fn test_finalize_auction_during_reveal_time() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    let bid_amount = 200_u256;

    // create auction
    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, bid_amount, SALT());

    fast_forward(marketplace.contract_address, AUCTION_DURATION);

    // reveal bid
    marketplace.reveal_bid(auction_id, bid_amount, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    let bids = marketplace.get_revealed_bids(auction_id);
    let (amount, bidder) = bids.at(0);

    // stop_cheat_caller_address(marketplace.contract_address);
    stop_cheat_caller_address_global();
    // finalize bid
    marketplace.finalize_auction(auction_id);
    marketplace.finalize_auction(auction_id);
}

#[test]
#[should_panic(expected: ('Auction already finalized',))]
fn test_finalize_auction_when_finalized() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    let bid_amount = 200_u256;

    // create auction
    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, bid_amount, SALT());

    fast_forward(marketplace.contract_address, AUCTION_DURATION);

    // reveal bid
    marketplace.reveal_bid(auction_id, bid_amount, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    let bids = marketplace.get_revealed_bids(auction_id);
    let (amount, bidder) = bids.at(0);

    fast_forward(marketplace.contract_address, AUCTION_DURATION + REVEAL_DURATION);

    // stop_cheat_caller_address(marketplace.contract_address);
    stop_cheat_caller_address_global();
    // finalize bid
    marketplace.finalize_auction(auction_id);
    marketplace.finalize_auction(auction_id);
}

#[test]
fn test_finalize_auction_ok() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    let bid_amount_bob = 200_u256;
    let bid_amount_alice = 500_u256;

    // create auction
    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid BOB
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, bid_amount_bob, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid ALICE
    start_cheat_caller_address(marketplace.contract_address, ALICE());
    marketplace.commit_bid(auction_id, bid_amount_alice, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    // fast forward block timestamp to after the auction duration i.e when auction is closed
    fast_forward(marketplace.contract_address, AUCTION_DURATION);

    // reveal bid BOB
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.reveal_bid(auction_id, bid_amount_bob, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    // reveal bid ALICE
    start_cheat_caller_address(marketplace.contract_address, ALICE());
    marketplace.reveal_bid(auction_id, bid_amount_alice, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    // fast forward block timestamp to after the reveal duration i.e when auction can be finalized
    fast_forward(marketplace.contract_address, AUCTION_DURATION + REVEAL_DURATION);

    // let bids = marketplace.get_revealed_bids(auction_id);
    // let (amount, bidder) = bids.at(0);

    let bob_balance_before = my_token.balance_of(BOB());
    let alice_balance_before = my_token.balance_of(ALICE());
    let marketplace_balance_before = my_token.balance_of(marketplace.contract_address);

    stop_cheat_caller_address_global();
    // finalize bid
    marketplace.finalize_auction(auction_id);

    assert(my_nft.owner_of(token_id) == ALICE(), 'wrong owner');
    assert(my_token.balance_of(BOB()) == bob_balance_before + bid_amount_bob, 'wrong bob balance');
    assert(my_token.balance_of(ALICE()) == alice_balance_before, 'wrong alice balance');
    assert(my_token.balance_of(OWNER()) == bid_amount_alice, 'wrong owner balance');
    assert(my_token.balance_of(marketplace.contract_address) == 0, 'wrong market balance');
}

#[test]
#[should_panic(expected: ('Bid refunded',))]
fn test_withdraw_when_refunded() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    let bid_amount_bob = 200_u256;
    let bid_amount_alice = 500_u256;

    // create auction
    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid BOB
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, bid_amount_bob, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid ALICE
    start_cheat_caller_address(marketplace.contract_address, ALICE());
    marketplace.commit_bid(auction_id, bid_amount_alice, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    // fast forward block timestamp to after the reveal duration
    fast_forward(marketplace.contract_address, AUCTION_DURATION);

    // reveal bid BOB
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.reveal_bid(auction_id, bid_amount_bob, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    // reveal bid ALICE
    start_cheat_caller_address(marketplace.contract_address, ALICE());
    marketplace.reveal_bid(auction_id, bid_amount_alice, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    fast_forward(marketplace.contract_address, AUCTION_DURATION + REVEAL_DURATION);

    stop_cheat_caller_address_global();

    // finalize bid
    marketplace.finalize_auction(auction_id);

    // withdraw
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.withdraw_unrevealed_bid(auction_id, bid_amount_bob, SALT());
}

#[test]
#[should_panic(expected: ('Caller already won auction',))]
fn test_withdraw_by_auction_winner() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    let bid_amount_bob = 200_u256;
    let bid_amount_alice = 500_u256;

    // create auction
    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid BOB
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, bid_amount_bob, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid ALICE
    start_cheat_caller_address(marketplace.contract_address, ALICE());
    marketplace.commit_bid(auction_id, bid_amount_alice, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    // fast forward block timestamp to after the reveal duration
    fast_forward(marketplace.contract_address, AUCTION_DURATION);

    // reveal bid BOB
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.reveal_bid(auction_id, bid_amount_bob, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    // reveal bid ALICE
    start_cheat_caller_address(marketplace.contract_address, ALICE());
    marketplace.reveal_bid(auction_id, bid_amount_alice, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    fast_forward(marketplace.contract_address, AUCTION_DURATION + REVEAL_DURATION);

    stop_cheat_caller_address_global();

    // finalize bid
    marketplace.finalize_auction(auction_id);

    // withdraw
    start_cheat_caller_address(marketplace.contract_address, ALICE());
    marketplace.withdraw_unrevealed_bid(auction_id, bid_amount_bob, SALT());
}

#[test]
fn test_withdraw_ok() {
    let (marketplace, my_nft, token_id, my_token) = setup();

    let bid_amount_bob = 200_u256;
    let bid_amount_alice = 500_u256;

    // create auction
    start_cheat_caller_address(marketplace.contract_address, OWNER());
    let auction_id = marketplace
        .create_auction(
            my_nft.contract_address, token_id, STARTING_PRICE(), my_token.contract_address
        );
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid BOB
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.commit_bid(auction_id, bid_amount_bob, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    // commit bid ALICE
    start_cheat_caller_address(marketplace.contract_address, ALICE());
    marketplace.commit_bid(auction_id, bid_amount_alice, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    // fast forward block timestamp to after the reveal duration
    fast_forward(marketplace.contract_address, AUCTION_DURATION);

    // reveal bid BOB
    start_cheat_caller_address(marketplace.contract_address, BOB());
    marketplace.reveal_bid(auction_id, bid_amount_bob, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    fast_forward(marketplace.contract_address, AUCTION_DURATION + REVEAL_DURATION);

    // reveal bid ALICE
    start_cheat_caller_address(marketplace.contract_address, ALICE());
    marketplace.reveal_bid(auction_id, bid_amount_alice, SALT());
    stop_cheat_caller_address(marketplace.contract_address);

    stop_cheat_caller_address_global();

    // finalize bid
    marketplace.finalize_auction(auction_id);

    let alice_balance_before = my_token.balance_of(ALICE());

    // withdraw
    start_cheat_caller_address(marketplace.contract_address, ALICE());
    marketplace.withdraw_unrevealed_bid(auction_id, bid_amount_alice, SALT());

    let alice_balance_after = my_token.balance_of(ALICE());

    assert(alice_balance_after == alice_balance_before + bid_amount_alice, 'wrong alice balance')
}

