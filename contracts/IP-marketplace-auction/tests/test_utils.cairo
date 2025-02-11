use core::num::traits::Bounded;
use marketplace_auction::interface::{
    IMarketPlace, IMarketPlaceDispatcher, IMarketPlaceDispatcherTrait
};
use marketplace_auction::mock::erc721::{IMyNFTDispatcher, IMyNFTDispatcherTrait};
use marketplace_auction::utils::{constants};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp_global, start_cheat_caller_address,
    stop_cheat_block_timestamp_global, stop_cheat_caller_address, start_cheat_block_timestamp,
    stop_cheat_block_timestamp, cheat_caller_address, CheatSpan, stop_cheat_caller_address_global
};
use starknet::{ContractAddress, get_block_timestamp};

pub const TIMESTAMP: u64 = 23_000_000;
pub const AUCTION_DURATION: u64 = 1;
pub const REVEAL_DURATION: u64 = 1;

pub fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

pub fn BOB() -> ContractAddress {
    'BOB'.try_into().unwrap()
}

pub fn ALICE() -> ContractAddress {
    'ALICE'.try_into().unwrap()
}

pub fn TOKEN_ADDRESS() -> ContractAddress {
    'TOKEN_ADDRESS'.try_into().unwrap()
}

pub fn TOKEN_ID() -> u256 {
    1
}

pub fn STARTING_PRICE() -> u256 {
    200
}

pub fn SALT() -> felt252 {
    'salt'.try_into().unwrap()
}

pub fn setup() -> (IMarketPlaceDispatcher, IERC721Dispatcher, u256, IERC20Dispatcher) {
    let marketplace = deploy_marketplace();
    let (erc721, token_id) = deploy_erc721();
    let erc20 = deploy_erc20();

    // approve marketplace to spend token for BOB
    start_cheat_caller_address(erc20.contract_address, BOB());
    erc20.approve(marketplace.contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20.contract_address);

    // approve marketplace to spend token for ALICE
    start_cheat_caller_address(erc20.contract_address, ALICE());
    erc20.approve(marketplace.contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20.contract_address);

    start_cheat_block_timestamp(marketplace.contract_address, TIMESTAMP);

    (marketplace, erc721, token_id, erc20)
}


fn deploy_marketplace() -> IMarketPlaceDispatcher {
    let contract = declare("MarketPlace").unwrap().contract_class();
    let mut constructor_calldata = array![AUCTION_DURATION.into(), REVEAL_DURATION.into()];

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

fn deploy_erc20() -> IERC20Dispatcher {
    let contract = declare("MyToken").unwrap().contract_class();
    let mut constructor_calldata: Array<felt252> = array![BOB().into()];

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    // fund alice
    start_cheat_caller_address(contract_address, BOB());
    IERC20Dispatcher { contract_address }.transfer(ALICE(), 10_000);
    stop_cheat_caller_address(contract_address);

    IERC20Dispatcher { contract_address }
}

/// Advances the blockchain timestamp for marketplace contract.
///
/// # Arguments
/// * `marketplace_address` - The address of the marketplace contract.
/// * `to` - The number of days to fast-forward the timestamp.
///
/// This function calculates the new timestamp by adding `to` days (converted to seconds)
/// to the current `TIMESTAMP` and applies it using `start_cheat_block_timestamp`.
pub fn fast_forward(marketplace_address: ContractAddress, to: u64) {
    let forward_timestamp: u64 = TIMESTAMP + (to * constants::DAY_IN_SECONDS);

    start_cheat_block_timestamp(marketplace_address, forward_timestamp);
}
