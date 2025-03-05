use core::num::traits::Bounded;
use ip_syndication::contract::asset_nft::{IAssetNFTDispatcher, IAssetNFTDispatcherTrait};
use ip_syndication::interface::{IIPSyndicationDispatcher, IIPSyndicationDispatcherTrait};
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp_global, start_cheat_caller_address,
    stop_cheat_block_timestamp_global, stop_cheat_caller_address, start_cheat_block_timestamp,
    stop_cheat_block_timestamp, cheat_caller_address, CheatSpan, stop_cheat_caller_address_global
};


use starknet::{ContractAddress, get_block_timestamp};

pub fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

pub fn BOB() -> ContractAddress {
    'BOB'.try_into().unwrap()
}

pub fn ALICE() -> ContractAddress {
    'ALICE'.try_into().unwrap()
}

pub fn setup() -> (
    IIPSyndicationDispatcher, IAssetNFTDispatcher, IERC20Dispatcher, ContractAddress
) {
    let asset_nft = deploy_asset_nft();
    let ip_syndication = deploy_ip_syndication(asset_nft.contract_address);
    let erc20 = deploy_erc20();
    let mike = deploy_mock_receiver();

    start_cheat_caller_address(erc20.contract_address, OWNER());
    // approve ip_syndicate to spend token for OWNER
    erc20.approve(ip_syndication.contract_address, Bounded::<u256>::MAX);
    // fund alice
    erc20.transfer(ALICE(), 10_000);
    // fund mike
    erc20.transfer(mike, 10_000);
    stop_cheat_caller_address(erc20.contract_address);

    // approve ip_syndicate to spend token for ALICE
    start_cheat_caller_address(erc20.contract_address, ALICE());
    erc20.approve(ip_syndication.contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20.contract_address);

    // approve ip_syndicate to spend token for mike
    start_cheat_caller_address(erc20.contract_address, mike);
    erc20.approve(ip_syndication.contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20.contract_address);

    (ip_syndication, asset_nft, erc20, mike)
}


fn deploy_ip_syndication(asset_nft_address: ContractAddress) -> IIPSyndicationDispatcher {
    let contract = declare("IPSyndication").unwrap().contract_class();
    let mut constructor_calldata = array![asset_nft_address.into()];

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    IIPSyndicationDispatcher { contract_address }
}

fn deploy_asset_nft() -> IAssetNFTDispatcher {
    let contract = declare("AssetNFT").unwrap().contract_class();
    let uri: ByteArray = format!("uri/");

    let mut constructor_calldata: Array<felt252> = array![];
    uri.serialize(ref constructor_calldata);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    IAssetNFTDispatcher { contract_address }
}

fn deploy_erc20() -> IERC20Dispatcher {
    let contract = declare("MyToken").unwrap().contract_class();
    let mut constructor_calldata: Array<felt252> = array![OWNER().into()];

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    IERC20Dispatcher { contract_address }
}

// deploy the MockERC1155Receiver contract
fn deploy_mock_receiver() -> ContractAddress {
    let contract = declare("MockERC1155Receiver").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();

    contract_address
}
