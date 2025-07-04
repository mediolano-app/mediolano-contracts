use starknet::get_caller_address;

use ip_time_capsule::interfaces::{ ITimeCapsuleDispatcher, ITimeCapsuleDispatcherTrait};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address};
    use snforge_std::{start_cheat_block_timestamp, stop_cheat_block_timestamp};

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

// fn setup() -> (ContractAddress, IPTimeCapsuleDispatcher) {
//     let owner = starknet::contract_address_const::<0x123>();
//     set_contract_address(owner);
//     let mut calldata = array![];
//     Serde::serialize(@"IP Time Capsule", ref calldata);
//     Serde::serialize(@"IPTC", ref calldata);
//     Serde::serialize(@"", ref calldata);
//     Serde::serialize(@owner, ref calldata);
//     let (target, _) = starknet::deploy_syscall(
//         IPTimeCapsule::TEST_CLASS_HASH, 0, calldata.span(), false,
//     )
//         .unwrap();
//     (owner, IIPTimeCapsuleDispatcher { contract_address: target })
// }

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
