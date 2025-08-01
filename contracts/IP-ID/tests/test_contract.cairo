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
    ip_identity.register_ip_id(
        ip_id,
        metadata_uri.clone(),
        ip_type.clone(),
        license_terms.clone(),
        1, // collection_id
        250, // royalty_rate (2.5%)
        1000, // licensing_fee
        true, // commercial_use
        true, // derivative_works
        true, // attribution_required
        "ERC721", // metadata_standard
        "https://example.com", // external_url
        "art,digital", // tags
        "US" // jurisdiction
    );

    // Attempt to register same IP ID again
    cheat_caller_address(ip_identity.contract_address, caller, CheatSpan::TargetCalls(1));
    ip_identity.register_ip_id(
        ip_id,
        metadata_uri,
        ip_type,
        license_terms,
        1, // collection_id
        250, // royalty_rate
        1000, // licensing_fee
        true, // commercial_use
        true, // derivative_works
        true, // attribution_required
        "ERC721", // metadata_standard
        "https://example.com", // external_url
        "art,digital", // tags
        "US" // jurisdiction
    );
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
    ip_identity.register_ip_id(
        ip_id,
        metadata_uri,
        ip_type,
        license_terms,
        1, // collection_id
        250, // royalty_rate
        1000, // licensing_fee
        true, // commercial_use
        true, // derivative_works
        true, // attribution_required
        "ERC721", // metadata_standard
        "https://example.com", // external_url
        "art,digital", // tags
        "US" // jurisdiction
    );

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
    ip_identity.register_ip_id(
        ip_id,
        metadata_uri,
        ip_type,
        license_terms,
        1, // collection_id
        250, // royalty_rate
        1000, // licensing_fee
        true, // commercial_use
        true, // derivative_works
        true, // attribution_required
        "ERC721", // metadata_standard
        "https://example.com", // external_url
        "art,digital", // tags
        "US" // jurisdiction
    );

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
    ip_identity.register_ip_id(
        ip_id,
        metadata_uri,
        ip_type,
        license_terms,
        1, // collection_id
        250, // royalty_rate
        1000, // licensing_fee
        true, // commercial_use
        true, // derivative_works
        true, // attribution_required
        "ERC721", // metadata_standard
        "https://example.com", // external_url
        "art,digital", // tags
        "US" // jurisdiction
    );

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
    ip_identity.register_ip_id(
        ip_id,
        metadata_uri,
        ip_type,
        license_terms,
        1, // collection_id
        250, // royalty_rate
        1000, // licensing_fee
        true, // commercial_use
        true, // derivative_works
        true, // attribution_required
        "ERC721", // metadata_standard
        "https://example.com", // external_url
        "art,digital", // tags
        "US" // jurisdiction
    );

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

// Enhanced functionality tests

#[test]
fn test_enhanced_ip_registration() {
    let (ip_identity, _) = deploy_ip_identity();
    let caller = user();
    let ip_id = 123;
    let metadata_uri: ByteArray = "ipfs://metadata";
    let ip_type: ByteArray = "image";
    let license_terms: ByteArray = "MIT";

    cheat_caller_address(ip_identity.contract_address, caller, CheatSpan::TargetCalls(1));
    let token_id = ip_identity.register_ip_id(
        ip_id,
        metadata_uri.clone(),
        ip_type.clone(),
        license_terms.clone(),
        1, // collection_id
        250, // royalty_rate (2.5%)
        1000, // licensing_fee
        true, // commercial_use
        true, // derivative_works
        true, // attribution_required
        "ERC721", // metadata_standard
        "https://example.com", // external_url
        "art,digital", // tags
        "US" // jurisdiction
    );

    // Verify enhanced data
    let ip_data = ip_identity.get_ip_id_data(ip_id);
    assert(ip_data.collection_id == 1, 'Invalid collection_id');
    assert(ip_data.royalty_rate == 250, 'Invalid royalty_rate');
    assert(ip_data.licensing_fee == 1000, 'Invalid licensing_fee');
    assert(ip_data.commercial_use == true, 'Invalid commercial_use');
    assert(ip_data.derivative_works == true, 'Invalid derivative_works');
    assert(ip_data.attribution_required == true, 'Invalid attribution_required');
    assert(ip_data.metadata_standard == "ERC721", 'Invalid metadata_standard');
    assert(ip_data.external_url == "https://example.com", 'Invalid external_url');
    assert(ip_data.tags == "art,digital", 'Invalid tags');
    assert(ip_data.jurisdiction == "US", 'Invalid jurisdiction');

    // Test utility functions
    assert(ip_identity.is_ip_id_registered(ip_id), 'IP should be registered');
    assert(ip_identity.can_use_commercially(ip_id), 'Should allow commercial use');
    assert(ip_identity.can_create_derivatives(ip_id), 'Should allow derivatives');
    assert(ip_identity.requires_attribution(ip_id), 'Should require attribution');
    assert(ip_identity.get_total_registered_ips() == 1, 'Total should be 1');
}

#[test]
fn test_licensing_update() {
    let (ip_identity, _) = deploy_ip_identity();
    let caller = user();
    let ip_id = 123;
    let metadata_uri: ByteArray = "ipfs://metadata";
    let ip_type: ByteArray = "image";
    let license_terms: ByteArray = "MIT";

    // Register IP ID
    cheat_caller_address(ip_identity.contract_address, caller, CheatSpan::TargetCalls(1));
    ip_identity.register_ip_id(
        ip_id,
        metadata_uri,
        ip_type,
        license_terms,
        1, // collection_id
        250, // royalty_rate
        1000, // licensing_fee
        true, // commercial_use
        true, // derivative_works
        true, // attribution_required
        "ERC721", // metadata_standard
        "https://example.com", // external_url
        "art,digital", // tags
        "US" // jurisdiction
    );

    // Update licensing
    let new_license_terms: ByteArray = "Apache 2.0";
    cheat_caller_address(ip_identity.contract_address, caller, CheatSpan::TargetCalls(1));
    ip_identity.update_ip_id_licensing(
        ip_id,
        new_license_terms.clone(),
        500, // new royalty_rate (5%)
        2000, // new licensing_fee
        false, // commercial_use
        false, // derivative_works
        false, // attribution_required
    );

    // Verify updated licensing
    let (license, royalty, fee, commercial, derivatives, attribution) = ip_identity.get_ip_licensing_terms(ip_id);
    assert(license == new_license_terms, 'License not updated');
    assert(royalty == 500, 'Royalty not updated');
    assert(fee == 2000, 'Fee not updated');
    assert(commercial == false, 'Commercial use not updated');
    assert(derivatives == false, 'Derivatives not updated');
    assert(attribution == false, 'Attribution not updated');
}

#[test]
fn test_ownership_transfer() {
    let (ip_identity, _) = deploy_ip_identity();
    let original_owner = user();
    let new_owner = non_owner();
    let ip_id = 123;
    let metadata_uri: ByteArray = "ipfs://metadata";
    let ip_type: ByteArray = "image";
    let license_terms: ByteArray = "MIT";

    // Register IP ID
    cheat_caller_address(ip_identity.contract_address, original_owner, CheatSpan::TargetCalls(1));
    ip_identity.register_ip_id(
        ip_id,
        metadata_uri,
        ip_type,
        license_terms,
        1, // collection_id
        250, // royalty_rate
        1000, // licensing_fee
        true, // commercial_use
        true, // derivative_works
        true, // attribution_required
        "ERC721", // metadata_standard
        "https://example.com", // external_url
        "art,digital", // tags
        "US" // jurisdiction
    );

    // Verify original owner
    assert(ip_identity.get_ip_owner(ip_id) == original_owner, 'Wrong original owner');

    // Transfer ownership
    cheat_caller_address(ip_identity.contract_address, original_owner, CheatSpan::TargetCalls(1));
    ip_identity.transfer_ip_ownership(ip_id, new_owner);

    // Verify new owner
    assert(ip_identity.get_ip_owner(ip_id) == new_owner, 'Transfer failed');
}

#[test]
fn test_batch_queries() {
    let (ip_identity, _) = deploy_ip_identity();
    let owner1 = user();
    let owner2 = non_owner();

    // Register multiple IP IDs
    cheat_caller_address(ip_identity.contract_address, owner1, CheatSpan::TargetCalls(2));
    ip_identity.register_ip_id(
        123, "ipfs://metadata1", "image", "MIT", 1, 250, 1000,
        true, true, true, "ERC721", "https://example1.com", "art", "US"
    );
    ip_identity.register_ip_id(
        124, "ipfs://metadata2", "video", "Apache", 1, 300, 1500,
        false, true, false, "ERC721", "https://example2.com", "video", "EU"
    );

    cheat_caller_address(ip_identity.contract_address, owner2, CheatSpan::TargetCalls(1));
    ip_identity.register_ip_id(
        125, "ipfs://metadata3", "image", "GPL", 2, 400, 2000,
        true, false, true, "ERC1155", "https://example3.com", "art,nft", "UK"
    );

    // Test owner queries
    let owner1_ips = ip_identity.get_owner_ip_ids(owner1);
    assert(owner1_ips.len() == 2, 'Owner1 should have 2 IPs');

    let owner2_ips = ip_identity.get_owner_ip_ids(owner2);
    assert(owner2_ips.len() == 1, 'Owner2 should have 1 IP');

    // Test collection queries
    let collection1_ips = ip_identity.get_ip_ids_by_collection(1);
    assert(collection1_ips.len() == 2, 'Collection 1 should have 2 IPs');

    let collection2_ips = ip_identity.get_ip_ids_by_collection(2);
    assert(collection2_ips.len() == 1, 'Collection 2 should have 1 IP');

    // Test type queries
    let image_ips = ip_identity.get_ip_ids_by_type("image");
    assert(image_ips.len() == 2, 'Should have 2 image IPs');

    let video_ips = ip_identity.get_ip_ids_by_type("video");
    assert(video_ips.len() == 1, 'Should have 1 video IP');

    // Test total count
    assert(ip_identity.get_total_registered_ips() == 3, 'Total should be 3');
}

#[test]
fn test_verification_workflow() {
    let (ip_identity, owner_addr) = deploy_ip_identity();
    let user_addr = user();
    let ip_id = 123;

    // Register IP ID
    cheat_caller_address(ip_identity.contract_address, user_addr, CheatSpan::TargetCalls(1));
    ip_identity.register_ip_id(
        ip_id, "ipfs://metadata", "image", "MIT", 1, 250, 1000,
        true, true, true, "ERC721", "https://example.com", "art", "US"
    );

    // Initially not verified
    assert(!ip_identity.is_ip_verified(ip_id), 'Should not be verified initially');

    // Verify IP ID
    cheat_caller_address(ip_identity.contract_address, owner_addr, CheatSpan::TargetCalls(1));
    ip_identity.verify_ip_id(ip_id);

    // Now should be verified
    assert(ip_identity.is_ip_verified(ip_id), 'Should be verified now');

    // Test verified IPs query
    let verified_ips = ip_identity.get_verified_ip_ids(10, 0);
    assert(verified_ips.len() == 1, 'Should have 1 verified IP');
    assert(*verified_ips.at(0) == ip_id, 'Wrong verified IP ID');
}
