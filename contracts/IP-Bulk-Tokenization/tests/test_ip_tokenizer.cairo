use starknet::{ContractAddress, contract_address_const};

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};
use bulk_ip_tokenization::interfaces::{IIPNFTDispatcher, IIPTokenizerDispatcher, IIPTokenizerDispatcherTrait};
use bulk_ip_tokenization::types::{IPAssetData, AssetType, LicenseTerms};

// Test setup and constants
const OWNER: felt252 = 0x123;
const USER: felt252 = 0x456;

fn deploy_contract (name: ByteArray, calldata: Array<felt252>) -> ContractAddress {
    let contract_class = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
}

fn deploy_nft_contract () -> (IIPNFTDispatcher, ContractAddress) {
    let name: ByteArray = "MEDIOLANO";
    let symbol: ByteArray = "MDL";
    let token_uri: ByteArray = "https://example.com/token-metadata/1";
    
    let mut calldata = array![];
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    token_uri.serialize(ref calldata);

    let contract_address = deploy_contract("IPNFT", calldata);
    let dispatcher = IIPNFTDispatcher { contract_address };
    (dispatcher, contract_address)
} 


fn setup() -> (IIPTokenizerDispatcher, ContractAddress) {
    // Deploy dependencies first
    let (_, nft_contract_address) = deploy_nft_contract();
    
    let gateway: ByteArray = "https://example.com/token-metadata/1";
    let mut calldata = array![];
    OWNER.serialize(ref calldata);
    gateway.serialize(ref calldata);
    nft_contract_address.serialize(ref calldata);
    
    let contract_address = deploy_contract("IPTokenizer", calldata);
    let dispatcher = IIPTokenizerDispatcher { contract_address };
    (dispatcher, contract_address)
}

#[test]
fn test_bulk_tokenize() {
    let (dispatcher, address) = setup();
    let owner = contract_address_const::<OWNER>();
    
    // Create test assets
    let mut assets = ArrayTrait::new();
    assets.append(create_test_asset(1));
    assets.append(create_test_asset(2));
    
    start_cheat_caller_address(address, owner);
    let token_ids = dispatcher.bulk_tokenize(assets);
    assert(token_ids.len() == 2, 'Should mint 2 tokens');
    stop_cheat_caller_address(address);
}

// Helper functions...
fn create_test_asset(id: u256) -> IPAssetData {
    IPAssetData {
        metadata_uri: "ipfs://QmTest",
        metadata_hash: "QmTest",
        owner: contract_address_const::<USER>(),
        asset_type: AssetType::Patent,
        license_terms: LicenseTerms::Standard,
        expiry_date: 1735689600 // Some future date
    }
}

