use ip_id::IPIdentity::{IIPIdentityDispatcher, IIPIdentityDispatcherTrait,};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, cheat_caller_address,
    start_cheat_block_timestamp, stop_cheat_block_timestamp, CheatSpan,
};
use starknet::{ContractAddress, contract_address_const};
use core::serde::Serde;

// Helper functions to get test addresses
fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn non_owner() -> ContractAddress {
    contract_address_const::<'non_owner'>()
}

fn user() -> ContractAddress {
    contract_address_const::<'user'>()
}

// Helper function to deploy the contract
fn deploy_ip_identity() -> (IIPIdentityDispatcher, ContractAddress) {
    // Declare IPIdentity contract
    let contract_class = declare("IPIdentity").unwrap().contract_class();

    // Prepare constructor calldata
    let owner_addr = owner();
    let name: ByteArray = "IPIdentity";
    let symbol: ByteArray = "IPID";
    let base_uri: ByteArray = "https://ipfs.io/ipfs/";

    let mut calldata = array![];
    owner_addr.serialize(ref calldata);
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);

    // Deploy contract
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    let ip_identity = IIPIdentityDispatcher { contract_address };

    (ip_identity, owner_addr)
}

#[test]
#[should_panic(expected: ('IP ID already registered',))]
fn test_register_ip_id_already_registered() {
    let (ip_identity, _) = deploy_ip_identity();
    let caller = user();
    let ip_id = 123;
    let metadata_uri: ByteArray = "ipfs://metadata";
    let ip_type: ByteArray = "image";
    let license_terms: ByteArray = "MIT";

    // Register IP ID first time
    cheat_caller_address(ip_identity.contract_address, caller, CheatSpan::TargetCalls(1));
    ip_identity.register_ip_id(ip_id, metadata_uri.clone(), ip_type.clone(), license_terms.clone());

    // Attempt to register same IP ID again
    cheat_caller_address(ip_identity.contract_address, caller, CheatSpan::TargetCalls(1));
    ip_identity.register_ip_id(ip_id, metadata_uri, ip_type, license_terms);
}

#[test]
fn test_update_ip_id_metadata_success() {
    let (ip_identity, _) = deploy_ip_identity();
    let caller = user();
    let ip_id = 123;
    let metadata_uri: ByteArray = "ipfs://metadata";
    let new_metadata_uri: ByteArray = "ipfs://new_metadata";
    let ip_type: ByteArray = "image";
    let license_terms: ByteArray = "MIT";

    // Register IP ID
    cheat_caller_address(ip_identity.contract_address, caller, CheatSpan::TargetCalls(1));
    ip_identity.register_ip_id(ip_id, metadata_uri, ip_type, license_terms);

    // Update metadata
    cheat_caller_address(ip_identity.contract_address, caller, CheatSpan::TargetCalls(1));
    start_cheat_block_timestamp(ip_identity.contract_address, 2000);
    ip_identity.update_ip_id_metadata(ip_id, new_metadata_uri.clone());
    stop_cheat_block_timestamp(ip_identity.contract_address);

    // Verify updated data
    let ip_data = ip_identity.get_ip_id_data(ip_id);
    assert(ip_data.metadata_uri == new_metadata_uri, 'Invalid new metadata URI');
    assert(ip_data.updated_at == 2000, 'Invalid updated_at');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_update_ip_id_metadata_not_owner() {
    let (ip_identity, _) = deploy_ip_identity();
    let owner = user();
    let non_owner_addr = non_owner();
    let ip_id = 123;
    let metadata_uri: ByteArray = "ipfs://metadata";
    let new_metadata_uri: ByteArray = "ipfs://new_metadata";
    let ip_type: ByteArray = "image";
    let license_terms: ByteArray = "MIT";

    // Register IP ID
    cheat_caller_address(ip_identity.contract_address, owner, CheatSpan::TargetCalls(1));
    ip_identity.register_ip_id(ip_id, metadata_uri, ip_type, license_terms);

    // Attempt to update metadata as non-owner
    cheat_caller_address(ip_identity.contract_address, non_owner_addr, CheatSpan::TargetCalls(1));
    ip_identity.update_ip_id_metadata(ip_id, new_metadata_uri);
}

#[test]
#[should_panic(expected: ('Invalid IP ID',))]
fn test_update_ip_id_metadata_invalid_id() {
    let (ip_identity, _) = deploy_ip_identity();
    let caller = user();
    let ip_id = 123;
    let new_metadata_uri: ByteArray = "ipfs://new_metadata";

    // Attempt to update metadata for non-existent IP ID
    cheat_caller_address(ip_identity.contract_address, caller, CheatSpan::TargetCalls(1));
    ip_identity.update_ip_id_metadata(ip_id, new_metadata_uri);
}

#[test]
fn test_verify_ip_id_success() {
    let (ip_identity, owner_addr) = deploy_ip_identity();
    let user_addr = user();
    let ip_id = 123;
    let metadata_uri: ByteArray = "ipfs://metadata";
    let ip_type: ByteArray = "image";
    let license_terms: ByteArray = "MIT";

    // Register IP ID
    cheat_caller_address(ip_identity.contract_address, user_addr, CheatSpan::TargetCalls(1));
    ip_identity.register_ip_id(ip_id, metadata_uri, ip_type, license_terms);

    // Verify IP ID
    cheat_caller_address(ip_identity.contract_address, owner_addr, CheatSpan::TargetCalls(1));
    start_cheat_block_timestamp(ip_identity.contract_address, 2000);
    ip_identity.verify_ip_id(ip_id);
    stop_cheat_block_timestamp(ip_identity.contract_address);

    // Verify updated data
    let ip_data = ip_identity.get_ip_id_data(ip_id);
    assert(ip_data.is_verified, 'Should be verified');
    assert(ip_data.updated_at == 2000, 'Invalid updated_at');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_verify_ip_id_not_owner() {
    let (ip_identity, _) = deploy_ip_identity();
    let caller = user();
    let ip_id = 123;
    let metadata_uri: ByteArray = "ipfs://metadata";
    let ip_type: ByteArray = "image";
    let license_terms: ByteArray = "MIT";

    // Register IP ID
    cheat_caller_address(ip_identity.contract_address, caller, CheatSpan::TargetCalls(1));
    ip_identity.register_ip_id(ip_id, metadata_uri, ip_type, license_terms);

    // Attempt to verify as non-owner
    cheat_caller_address(ip_identity.contract_address, caller, CheatSpan::TargetCalls(1));
    ip_identity.verify_ip_id(ip_id);
}

#[test]
#[should_panic(expected: ('Invalid IP ID',))]
fn test_verify_ip_id_invalid_id() {
    let (ip_identity, owner_addr) = deploy_ip_identity();
    let ip_id = 123;

    // Attempt to verify non-existent IP ID
    cheat_caller_address(ip_identity.contract_address, owner_addr, CheatSpan::TargetCalls(1));
    ip_identity.verify_ip_id(ip_id);
}

#[test]
#[should_panic(expected: ('Invalid IP ID',))]
fn test_get_ip_id_data_invalid_id() {
    let (ip_identity, _) = deploy_ip_identity();
    let ip_id = 999;

    // Attempt to get data for non-existent IP ID
    ip_identity.get_ip_id_data(ip_id);
}
