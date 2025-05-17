use core::option::OptionTrait;
use core::starknet::SyscallResultTrait;
use starknet::testing::set_block_timestamp;
use core::result::ResultTrait;
use core::traits::{TryInto, Into};
use core::byte_array::ByteArray;

use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, spy_events, EventSpyAssertionsTrait, get_class_hash,
};

use openzeppelin::token::erc721::interface::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use starknet::{ContractAddress, ClassHash, get_block_timestamp};
use ip_licensing::interfaces::IIPLicensingNFT::{
    IIPLicensingNFTDispatcher, IIPLicensingNFTDispatcherTrait,
};
use ip_licensing::interfaces::IERC721::{IERC721Dispatcher, IERC721DispatcherTrait};

const ADMIN: felt252 = 'ADMIN';

fn OWNER() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn USER() -> ContractAddress {
    'recipient'.try_into().unwrap()
}

fn __setup__() -> ContractAddress {
    __deploy_IPLicensingNFT__()
}

fn __deploy_IPLicensingNFT__() -> ContractAddress {
    let nft_class_hash = declare("IPLicensingNFT").unwrap().contract_class();
    let mut events_constructor_calldata: Array<felt252> = array![ADMIN];
    let (nft_contract_address, _) = nft_class_hash.deploy(@events_constructor_calldata).unwrap();
    nft_contract_address
}

#[test]
fn test_Licensing_nft_minted_extended() {
    let nft_address = __setup__();
    let nft_dispatcher = IIPLicensingNFTDispatcher { contract_address: nft_address };
    let user: ContractAddress = USER();
    let valid_url: ByteArray = "QmfVMAmNM1kDEBYrC2TPzQDoCRFH6F5tE1e9Mr4FkkR5Xr";
    let license_data: ByteArray = "LicenseDataExample";

    let token_id = nft_dispatcher.mint_nft(user, valid_url.clone());

    println!("Starting NFT Licensing Minting Tests");

    start_cheat_caller_address(nft_address, user);

    // Mint first token and validate ID
    let first_token_id = nft_dispatcher
        .mint_Licensing_nft(user, token_id, valid_url.clone(), license_data.clone());
    assert_eq!(first_token_id, 2, "Token ID must be 2");
    println!("First License minted! Token ID: {:?}", first_token_id);

    // Mint second token and verify ID increments
    let second_token_id = nft_dispatcher
        .mint_Licensing_nft(user, token_id, valid_url.clone(), license_data.clone());
    assert_eq!(second_token_id, 3, "Token ID must be 3");
    println!("Minted second Token ID: {:?}", second_token_id);

    stop_cheat_caller_address(nft_address);

    // Ensure last minted ID is updated
    let last_minted_id = nft_dispatcher.get_last_minted_id();
    println!("Last minted token ID: {:?}", last_minted_id);
    assert_eq!(second_token_id, last_minted_id, "Last minted token ID should be the latest");

    // Verify mint timestamp matches block timestamp
    let mint_timestamp = nft_dispatcher.get_token_mint_timestamp(first_token_id);
    let current_block_timestamp = get_block_timestamp();
    println!(
        "Mint timestamp: {:?}, Current block timestamp: {:?}",
        mint_timestamp,
        current_block_timestamp,
    );
    assert_eq!(mint_timestamp, current_block_timestamp, "Mint timestamp not matched");

    // Ensure token URI is correct
    let token_uri = nft_dispatcher.get_token_uri(first_token_id);
    println!("First token URI: {:?}", token_uri);
    assert_eq!(token_uri, valid_url, "Mismatch token URI");

    // Check owner of second minted token
    let owner_second = nft_dispatcher.get_owner_of_token(second_token_id);
    println!("Owner of second minted token: {:?}", owner_second);
    assert_eq!(owner_second, user, "Owner of second token should be the user");
}


#[test]
#[should_panic(expected: 'EMPTY_ADDRESS')]
fn test_invalid_user_mint() {
    let nft_address = __setup__();
    let nft_dispatcher = IIPLicensingNFTDispatcher { contract_address: nft_address };
    let invalid_user: ContractAddress = ''.try_into().unwrap();
    let valid_url: ByteArray = "QmfVMAmNM1kDEBYrC2TPzQDoCRFH6F5tE1e9Mr4FkkR5Xr";
    let license_data: ByteArray = "LicenseDataExample";
    let user: ContractAddress = USER();
    let token_id = nft_dispatcher.mint_nft(user, valid_url.clone());

    println!("Testing minting with an invalid user");

    start_cheat_caller_address(nft_address, user);
    nft_dispatcher
        .mint_Licensing_nft(invalid_user, token_id, valid_url.clone(), license_data.clone());
}

#[test]
#[should_panic(expected: 'EMPTY_URI')]
fn test_empty_uri_mint() {
    let nft_address = __setup__();
    let nft_dispatcher = IIPLicensingNFTDispatcher { contract_address: nft_address };
    let valid_user: ContractAddress = USER();
    let empty_url: ByteArray = "";
    let license_data: ByteArray = "LicenseDataExample";
    let user: ContractAddress = USER();
    let valid_url: ByteArray = "QmfVMAmNM1kDEBYrC2TPzQDoCRFH6F5tE1e9Mr4FkkR5Xr";
    let token_id = nft_dispatcher.mint_nft(user, valid_url.clone());

    println!("Testing minting with an empty token URI");

    start_cheat_caller_address(nft_address, user);
    nft_dispatcher
        .mint_Licensing_nft(valid_user, token_id, empty_url.clone(), license_data.clone());
}
