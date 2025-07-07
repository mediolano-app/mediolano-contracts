use ip_time_capsule::interfaces::{ITimeCapsuleDispatcher, ITimeCapsuleDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp,
    start_cheat_caller_address, stop_cheat_block_timestamp, stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp, get_caller_address};

// Test constants
const OWNER: felt252 = 0x123;
const USER1: felt252 = 0x456;
const USER2: felt252 = 0x789;
const RECIEVER: felt252 = 0x456;

fn deploy_contract(name: ByteArray, calldata: Array<felt252>) -> ContractAddress {
    let contract_class = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
}

fn setup() -> (ITimeCapsuleDispatcher, ContractAddress) {
    let name: ByteArray = "IpTimelock";
    let owner = contract_address_const::<OWNER>();
    let base_uri: ByteArray = "ipfs://QmBaseUri";
    let symbol: ByteArray = "ITL";

    let mut calldata = array![];
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    owner.serialize(ref calldata);

    let contract_address = deploy_contract("IPTimeCapsule", calldata);
    let dispatcher = ITimeCapsuleDispatcher { contract_address };
    (dispatcher, contract_address)
}

#[test]
fn test_mint_and_metadata() {
    let (dispatcher, _) = setup();
    let recipient = contract_address_const::<RECIEVER>();
    let metadata_hash = 0x123456789;
    let unvesting_timestamp = get_block_timestamp() + 86400;

    // Set the caller address to the owner for minting
    start_cheat_caller_address(dispatcher.contract_address, contract_address_const::<OWNER>());

    let token_id = dispatcher.mint(recipient, metadata_hash, unvesting_timestamp);

    stop_cheat_caller_address(dispatcher.contract_address);

    // let owner = get_caller_address();
    // assert(owner == recipient, 'recipient: Wrong Owner');
    assert(token_id == 1, 'Wrong token ID');

    // Test that metadata is hidden before unvesting
    let metadata = dispatcher.get_metadata(token_id);
    assert(metadata == 0, 'Metadata should be hidden');

    start_cheat_block_timestamp(dispatcher.contract_address, unvesting_timestamp + 1);
    let revealed_metadata = dispatcher.get_metadata(token_id);
    stop_cheat_block_timestamp(dispatcher.contract_address);
    assert(revealed_metadata == metadata_hash, 'Metadata should be revealed');
}

#[test]
#[should_panic(expected: ('Not yet Unvested',))]
fn test_set_metadata_before_unvesting_should_fail() {
    let (dispatcher, _) = setup();
    let recipient = contract_address_const::<RECIEVER>();
    let metadata_hash = 0x123456789;
    let new_metadata_hash = 0x723459358;
    let unvesting_timestamp = get_block_timestamp() + 86400;

    start_cheat_caller_address(dispatcher.contract_address, contract_address_const::<OWNER>());
    let token_id = dispatcher.mint(recipient, metadata_hash, unvesting_timestamp);
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, recipient);
    dispatcher.set_metadata(token_id, new_metadata_hash);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_set_metadata_after_unvesting() {
    let (dispatcher, _) = setup();
    let recipient = contract_address_const::<RECIEVER>();
    let metadata_hash = 0x123456789;
    let new_metadata_hash = 0x723459358;
    let unvesting_timestamp = get_block_timestamp() + 86400;

    start_cheat_caller_address(dispatcher.contract_address, contract_address_const::<OWNER>());
    let token_id = dispatcher.mint(recipient, metadata_hash, unvesting_timestamp);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward time to after unvesting
    start_cheat_block_timestamp(dispatcher.contract_address, unvesting_timestamp + 1);

    // Set metadata after unvesting as the token owner (recipient)
    start_cheat_caller_address(dispatcher.contract_address, recipient);
    dispatcher.set_metadata(token_id, new_metadata_hash);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check that metadata is updated
    let updated_metadata = dispatcher.get_metadata(token_id);
    assert(updated_metadata == new_metadata_hash, 'Metadata not updated');
    stop_cheat_block_timestamp(dispatcher.contract_address);
}

#[test]
fn test_list_user_tokens() {
    let (dispatcher, _) = setup();
    let user1 = contract_address_const::<RECIEVER>();
    let user2 = contract_address_const::<USER2>();
    let metadata_hash = 0x123456789;
    let unvesting_timestamp = get_block_timestamp() + 86400;

    // Test empty list for new user
    let empty_tokens = dispatcher.list_user_tokens(user1);
    assert(empty_tokens.len() == 0, 'Should have no tokens initially');

    // Mint tokens to user1
    start_cheat_caller_address(dispatcher.contract_address, contract_address_const::<OWNER>());

    let token_id_1 = dispatcher.mint(user1, metadata_hash, unvesting_timestamp);
    println!("Minted token_id_1: {}", token_id_1);
    let token_id_2 = dispatcher.mint(user1, metadata_hash + 1, unvesting_timestamp + 100);
    println!("Minted token_id_2: {}", token_id_2);
    let token_id_3 = dispatcher.mint(user1, metadata_hash + 2, unvesting_timestamp + 200);
    println!("Minted token_id_3: {}", token_id_3);

    // Mint one token to user2
    let token_id_4 = dispatcher.mint(user2, metadata_hash + 3, unvesting_timestamp + 300);
    println!("Minted token_id_4: {}", token_id_4);

    stop_cheat_caller_address(dispatcher.contract_address);

    // Test user1 tokens
    let user1_tokens = dispatcher.list_user_tokens(user1);
    println!("User1 tokens: {:?}", user1_tokens);
    println!("User1 tokens length: {}", user1_tokens.len());
    assert(user1_tokens.len() == 3, 'User1 should have 3 tokens');
    assert(*user1_tokens.at(0) == token_id_1, '1st token should be token_id_1');
    assert(*user1_tokens.at(1) == token_id_2, '2nd token should be token_id_2');
    assert(*user1_tokens.at(2) == token_id_3, '3rd token should be token_id_3');

    // Test user2 tokens
    let user2_tokens = dispatcher.list_user_tokens(user2);
    println!("User22222 tokens: {:?}", user2_tokens);
    println!("User22222 tokens length: {}", user1_tokens.len());
    assert(user2_tokens.len() == 1, 'User2 should have 1 token');
    assert(*user2_tokens.at(0) == token_id_4, 'User2 tk should be token_id_4');

    // Test with non-existent user
    let non_existent_user = contract_address_const::<0x999>();
    let no_tokens = dispatcher.list_user_tokens(non_existent_user);
    assert(no_tokens.len() == 0, 'No token for non-existent users');
}

#[test]
fn test_list_user_tokens_edge_cases() {
    let (dispatcher, _) = setup();
    let user = contract_address_const::<RECIEVER>();
    let metadata_hash = 0x123456789;
    let unvesting_timestamp = get_block_timestamp() + 86400;

    // Test with single token
    start_cheat_caller_address(dispatcher.contract_address, contract_address_const::<OWNER>());
    let token_id = dispatcher.mint(user, metadata_hash, unvesting_timestamp);
    stop_cheat_caller_address(dispatcher.contract_address);

    let user_tokens = dispatcher.list_user_tokens(user);
    assert(user_tokens.len() == 1, 'Should have exactly 1 token');
    assert(*user_tokens.at(0) == token_id, 'Token ID should match');

    // Test that token order is preserved across multiple mints
    start_cheat_caller_address(dispatcher.contract_address, contract_address_const::<OWNER>());
    let token_id_2 = dispatcher.mint(user, metadata_hash + 1, unvesting_timestamp + 100);
    let token_id_3 = dispatcher.mint(user, metadata_hash + 2, unvesting_timestamp + 200);
    stop_cheat_caller_address(dispatcher.contract_address);

    let updated_tokens = dispatcher.list_user_tokens(user);
    assert(updated_tokens.len() == 3, 'Should have 3 tokens total');
    assert(*updated_tokens.at(0) == token_id, 'First token should be original');
    assert(*updated_tokens.at(1) == token_id_2, '2nd token should be token_id_2');
    assert(*updated_tokens.at(2) == token_id_3, '3rd token should be token_id_3');
}
