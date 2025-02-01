use core::option::OptionTrait;
use core::starknet::SyscallResultTrait;
use starknet::testing::set_block_timestamp;
use core::result::ResultTrait;
use core::traits::{TryInto, Into};
use core::byte_array::ByteArray;

use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, spy_events, EventSpyAssertionsTrait, get_class_hash
};

use openzeppelin::{token::erc721::interface::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait}};

use starknet::{ContractAddress, ClassHash, get_block_timestamp};

use ip_licensing::interfaces::IIPLicensingNFT::{IIPLicensingNFTDispatcher, IIPLicensingNFTDispatcherTrait};
use ip_licensing::interfaces::IERC721::{IERC721Dispatcher ,IERC721DispatcherTrait};


const ADMIN: felt252 = 'ADMIN';

fn OWNER() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn USER() -> ContractAddress {
    'recipient'.try_into().unwrap()
}

fn __setup__() ->  ContractAddress {

    let nft_address = __deploy_WeaverNFT__();
   
 nft_address
}

fn __deploy_WeaverNFT__() -> ContractAddress {
    let nft_class_hash = declare("IPLicensingNFT").unwrap().contract_class();

    let mut events_constructor_calldata: Array<felt252> = array![ADMIN];
    let (nft_contract_address, _) = nft_class_hash.deploy(@events_constructor_calldata).unwrap();

    return nft_contract_address;
}


#[test]
fn test_Licensing_nft_minted_extended() {
    let nft_address = __setup__();
    let nft_dispatcher = IIPLicensingNFTDispatcher { contract_address: nft_address };

    let user: ContractAddress = USER();
    let valid_url: ByteArray = "QmfVMAmNM1kDEBYrC2TPzQDoCRFH6F5tE1e9Mr4FkkR5Xr";
    
    println!("Starting NFT Licensing Minting Tests");
    
    // 1. Mint first token and validate ID
    let first_token_id = nft_dispatcher.mint_Licensing_nft(user, valid_url.clone());
    assert_eq!(first_token_id, 1, "Token ID must be 1");
    println!("Firt License minted! Token ID: {:?}", first_token_id);

    // 2. Mint second token and verify ID increments
    let second_token_id = nft_dispatcher.mint_Licensing_nft(user, valid_url.clone());
    assert_eq!(second_token_id, 2, "Token ID must be 2");
    println!("Minted second Token ID: {:?}", second_token_id);
    
    // 3. Ensure last minted ID is updated
    let last_minted_id = nft_dispatcher.get_last_minted_id();
    println!("Last minted token ID: {:?}", last_minted_id);
    assert_eq!(second_token_id, last_minted_id, "Last minted token ID should be the latest");
    
    // 4. Verify mint timestamp matches block timestamp
    let mint_timestamp = nft_dispatcher.get_token_mint_timestamp(first_token_id);
    let current_block_timestamp = get_block_timestamp();
    println!("Mint timestamp: {:?}, Current block timestamp: {:?}", mint_timestamp, current_block_timestamp);
    assert_eq!(mint_timestamp, current_block_timestamp, "Mint timestamp not matched");
    
    // 5. Ensure token uri is correct
    let token_uri = nft_dispatcher.get_token_uri(first_token_id);
    println!("first token uri: {:?}", token_uri);
    assert_eq!(token_uri, valid_url, "Mismatch token uri");

    // 6. Check owner of token id


}

#[test]
#[should_panic(expected : 'EMPTY_ADDRESS')]
fn test_invalid_user_mint() {
    let nft_address = __setup__();
    let nft_dispatcher = IIPLicensingNFTDispatcher { contract_address: nft_address };
    let invalid_user: ContractAddress = ''.try_into().unwrap();
    let valid_url: ByteArray = "QmfVMAmNM1kDEBYrC2TPzQDoCRFH6F5tE1e9Mr4FkkR5Xr";
    
    println!("Testing minting with an invalid user");
    nft_dispatcher.mint_Licensing_nft(invalid_user, valid_url.clone());
}

#[test]
#[should_panic(expected : 'EMPTY_URI')]
fn test_empty_uri_mint() {
    let nft_address = __setup__();
    let nft_dispatcher = IIPLicensingNFTDispatcher { contract_address: nft_address };
    let valid_user: ContractAddress = USER();
    let empty_url: ByteArray = "";
    
    println!("Testing minting with an empty token URI");
    nft_dispatcher.mint_Licensing_nft(valid_user, empty_url.clone());
}