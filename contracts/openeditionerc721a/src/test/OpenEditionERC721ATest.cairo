use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use core::result::ResultTrait;
use openeditionerc721a::OpenEditionERC721A::{
    IOpenEditionERC721ADispatcher, IOpenEditionERC721ADispatcherTrait,
};

// Test constants
fn OWNER() -> ContractAddress {
    contract_address_const::<0x123>()
}
fn USER1() -> ContractAddress {
    contract_address_const::<0x456>()
}
fn USER2() -> ContractAddress {
    contract_address_const::<0x789>()
}
const PHASE_ID: u256 = 1;
const PRICE: u256 = 1000;
const START_TIME: u64 = 1000;
const END_TIME: u64 = 2000;

// Deploy the OpenEditionERC721A contract
fn deploy_contract() -> (IOpenEditionERC721ADispatcher, ContractAddress) {
    let owner = OWNER();
    let mut calldata = array![];
    let name: ByteArray = "Open Edition NFT";
    let symbol: ByteArray = "OEN";
    let base_uri: ByteArray = "ipfs://QmBaseUri";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    owner.serialize(ref calldata);

    let declare_result = declare("OpenEditionERC721A").expect('Failed to declare contract');
    let _contract_class = declare_result.contract_class();
    let (contract_address, _) = _contract_class
        .deploy(@calldata)
        .expect('Failed to deploy contract');

    let dispatcher = IOpenEditionERC721ADispatcher { contract_address };
    (dispatcher, contract_address)
}

// Helper function to create a test claim phase
fn setup_claim_phase(
    dispatcher: IOpenEditionERC721ADispatcher,
    address: ContractAddress,
    phase_id: u256,
    is_public: bool,
    whitelist: Array<ContractAddress>,
) {
    let owner = OWNER();
    start_cheat_caller_address(address, owner);
    dispatcher.create_claim_phase(phase_id, PRICE, START_TIME, END_TIME, is_public, whitelist);
    stop_cheat_caller_address(address);
}

#[test]
fn test_create_claim_phase() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let whitelist = array![USER1()];
    start_cheat_caller_address(address, owner);

    dispatcher.create_claim_phase(PHASE_ID, PRICE, START_TIME, END_TIME, true, whitelist);

    let phase = dispatcher.get_claim_phase(PHASE_ID);
    assert(phase.price == PRICE, 'Price mismatch');
    assert(phase.start_time == START_TIME, 'Start time mismatch');
    assert(phase.end_time == END_TIME, 'End time mismatch');
    assert(phase.is_public, 'Should be public');
    assert(dispatcher.is_whitelisted(PHASE_ID, USER1()), 'USER1 should be whitelisted');
    assert(!dispatcher.is_whitelisted(PHASE_ID, USER2()), 'USER2 should not be whitelisted');

    stop_cheat_caller_address(address);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_create_claim_phase_not_owner() {
    let (dispatcher, address) = deploy_contract();
    let non_owner = USER1();
    start_cheat_caller_address(address, non_owner);
    dispatcher.create_claim_phase(PHASE_ID, PRICE, START_TIME, END_TIME, true, array![]);
}

#[test]
#[should_panic(expected: ('Invalid time range',))]
fn test_create_claim_phase_invalid_time() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    start_cheat_caller_address(address, owner);
    dispatcher.create_claim_phase(PHASE_ID, PRICE, END_TIME, START_TIME, true, array![]);
}

#[test]
#[should_panic(expected: ('Phase ended',))]
fn test_create_claim_phase_already_ended() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    start_cheat_block_timestamp(address, END_TIME + 1);
    start_cheat_caller_address(address, owner);
    dispatcher.create_claim_phase(PHASE_ID, PRICE, START_TIME, END_TIME, true, array![]);
    stop_cheat_block_timestamp(address);
}

#[test]
fn test_update_metadata() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let new_base_uri: ByteArray = "ipfs://QmNewBaseUri";
    start_cheat_caller_address(address, owner);

    dispatcher.update_metadata(new_base_uri.clone());
    let token_uri = dispatcher.get_metadata(1);
    assert(token_uri == new_base_uri, 'Metadata URI mismatch');

    stop_cheat_caller_address(address);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_update_metadata_not_owner() {
    let (dispatcher, address) = deploy_contract();
    let non_owner = USER1();
    start_cheat_caller_address(address, non_owner);
    dispatcher.update_metadata("ipfs://QmNewBaseUri");
}

#[test]
fn test_mint_public_phase() {
    let (dispatcher, address) = deploy_contract();
    let user = USER1();
    setup_claim_phase(dispatcher, address, PHASE_ID, true, array![]);

    start_cheat_block_timestamp(address, START_TIME);
    start_cheat_caller_address(address, user);
    let first_token_id = dispatcher.mint(PHASE_ID, 2);
    assert(first_token_id == 1, 'First token ID should be 1');
    assert(dispatcher.get_current_token_id() == 2, 'Current token ID should be 2');
    assert(dispatcher.get_metadata(1) == "ipfs://QmBaseUri", 'Token 1 URI mismatch');
    assert(dispatcher.get_metadata(2) == "ipfs://QmBaseUri", 'Token 2 URI mismatch');

    stop_cheat_caller_address(address);
    stop_cheat_block_timestamp(address);
}

#[test]
fn test_mint_whitelist_phase() {
    let (dispatcher, address) = deploy_contract();
    let user = USER1();
    setup_claim_phase(dispatcher, address, PHASE_ID, false, array![user]);

    start_cheat_block_timestamp(address, START_TIME);
    start_cheat_caller_address(address, user);
    let first_token_id = dispatcher.mint(PHASE_ID, 1);
    assert(first_token_id == 1, 'First token ID should be 1');
    assert(dispatcher.get_current_token_id() == 1, 'Current token ID should be 1');
    assert(dispatcher.get_metadata(1) == "ipfs://QmBaseUri", 'Token 1 URI mismatch');

    stop_cheat_caller_address(address);
    stop_cheat_block_timestamp(address);
}

#[test]
#[should_panic(expected: ('Not whitelisted',))]
fn test_mint_whitelist_phase_not_whitelisted() {
    let (dispatcher, address) = deploy_contract();
    let user = USER2();
    setup_claim_phase(dispatcher, address, PHASE_ID, false, array![USER1()]);

    start_cheat_block_timestamp(address, START_TIME);
    start_cheat_caller_address(address, user);
    dispatcher.mint(PHASE_ID, 1);
    stop_cheat_caller_address(address);
    stop_cheat_block_timestamp(address);
}

#[test]
#[should_panic(expected: ('Phase not started',))]
fn test_mint_before_phase_start() {
    let (dispatcher, address) = deploy_contract();
    let user = USER1();
    setup_claim_phase(dispatcher, address, PHASE_ID, true, array![]);

    start_cheat_block_timestamp(address, START_TIME - 1);
    start_cheat_caller_address(address, user);
    dispatcher.mint(PHASE_ID, 1);
    stop_cheat_caller_address(address);
    stop_cheat_block_timestamp(address);
}

#[test]
#[should_panic(expected: ('Phase ended',))]
fn test_mint_after_phase_end() {
    let (dispatcher, address) = deploy_contract();
    let user = USER1();
    setup_claim_phase(dispatcher, address, PHASE_ID, true, array![]);

    start_cheat_block_timestamp(address, END_TIME + 1);
    start_cheat_caller_address(address, user);
    dispatcher.mint(PHASE_ID, 1);
    stop_cheat_caller_address(address);
    stop_cheat_block_timestamp(address);
}

#[test]
#[should_panic(expected: ('Caller is zero address',))]
fn test_mint_zero_caller() {
    let (dispatcher, address) = deploy_contract();
    setup_claim_phase(dispatcher, address, PHASE_ID, true, array![]);

    start_cheat_block_timestamp(address, START_TIME);
    start_cheat_caller_address(address, contract_address_const::<0>());
    dispatcher.mint(PHASE_ID, 1);
    stop_cheat_caller_address(address);
    stop_cheat_block_timestamp(address);
}

#[test]
#[should_panic(expected: ('Invalid quantity',))]
fn test_mint_zero_quantity() {
    let (dispatcher, address) = deploy_contract();
    let user = USER1();
    setup_claim_phase(dispatcher, address, PHASE_ID, true, array![]);

    start_cheat_block_timestamp(address, START_TIME);
    start_cheat_caller_address(address, user);
    dispatcher.mint(PHASE_ID, 0);
    stop_cheat_caller_address(address);
    stop_cheat_block_timestamp(address);
}

#[test]
#[should_panic(expected: ('Phase ended',))]
fn test_mint_ended_phase() {
    let (dispatcher, address) = deploy_contract();
    let user = USER1();

    start_cheat_block_timestamp(address, START_TIME);
    start_cheat_caller_address(address, user);
    dispatcher.mint(999, 1); // This should panic
    stop_cheat_caller_address(address);
    stop_cheat_block_timestamp(address);
}
