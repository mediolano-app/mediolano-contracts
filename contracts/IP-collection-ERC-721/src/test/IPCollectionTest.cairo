use core::starknet::{ContractAddress, contract_address_const};
use ip_collection::IPCollection::{IIPCollectionDispatcher, IIPCollectionDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};

const COLLECTION_ID: u256 = 1;
const TOKEN_ID: u256 = 1;

fn OWNER() -> ContractAddress {
    contract_address_const::<0x123>()
}

fn USER1() -> ContractAddress {
    contract_address_const::<0x456>()
}

fn USER2() -> ContractAddress {
    contract_address_const::<0x789>()
}

fn deploy_contract() -> (IIPCollectionDispatcher, ContractAddress) {
    let contract = declare("IPCollection").unwrap().contract_class();
    let name: ByteArray = "IP Collection";
    let symbol: ByteArray = "IPC";
    let base_uri: ByteArray = "ipfs://QmBaseUri";
    let owner = OWNER();
    let mut calldata = array![];
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    owner.serialize(ref calldata);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = IIPCollectionDispatcher { contract_address };
    (dispatcher, contract_address)
}

fn setup_collection(dispatcher: IIPCollectionDispatcher, address: ContractAddress) -> u256 {
    let owner = OWNER();
    let name: ByteArray = "Test Collection";
    let symbol: ByteArray = "TST";
    let base_uri: ByteArray = "ipfs://QmCollectionBaseUri";
    start_cheat_caller_address(address, owner);
    let collection_id = dispatcher.create_collection(name, symbol, base_uri);
    stop_cheat_caller_address(address);
    collection_id
}

#[test]
#[should_panic(expected: ('Caller is zero address',))]
fn test_create_collection_zero_address() {
    let (dispatcher, address) = deploy_contract();
    start_cheat_caller_address(address, contract_address_const::<0>());
    dispatcher.create_collection("Test", "TST", "ipfs://QmBaseUri");
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_mint_not_owner() {
    let (dispatcher, address) = deploy_contract();
    let non_owner = USER1();
    let recipient = USER1();
    let collection_id = setup_collection(dispatcher, address);

    start_cheat_caller_address(address, non_owner);
    dispatcher.mint(collection_id, recipient);
}

#[test]
#[should_panic(expected: ('Recipient is zero address',))]
fn test_mint_zero_recipient() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let collection_id = setup_collection(dispatcher, address);

    start_cheat_caller_address(address, owner);
    dispatcher.mint(collection_id, contract_address_const::<0>());
}

#[test]
#[should_panic(expected: ('Caller is zero address',))]
fn test_mint_zero_caller() {
    let (dispatcher, address) = deploy_contract();
    let recipient = USER1();
    let collection_id = setup_collection(dispatcher, address);

    start_cheat_caller_address(address, contract_address_const::<0>());
    dispatcher.mint(collection_id, recipient);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_FAILED',))]
fn test_burn_not_owner() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let recipient = USER1();
    let non_owner = USER2();
    let collection_id = setup_collection(dispatcher, address);

    start_cheat_caller_address(address, owner);
    let token_id = dispatcher.mint(collection_id, recipient);
    stop_cheat_caller_address(address);

    start_cheat_caller_address(address, non_owner);
    dispatcher.burn(token_id);
}

#[test]
#[should_panic(expected: ('Contract not approved',))]
fn test_transfer_token_not_approved() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let from = USER1();
    let to = USER2();
    let collection_id = setup_collection(dispatcher, address);

    start_cheat_caller_address(address, owner);
    let token_id = dispatcher.mint(collection_id, from);
    stop_cheat_caller_address(address);

    start_cheat_caller_address(address, from);
    dispatcher.transfer_token(from, to, token_id);
}

#[test]
#[should_panic(expected: ('Caller is zero address',))]
fn test_transfer_token_zero_caller() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let from = USER1();
    let to = USER2();
    let collection_id = setup_collection(dispatcher, address);

    start_cheat_caller_address(address, owner);
    let token_id = dispatcher.mint(collection_id, from);
    stop_cheat_caller_address(address);

    start_cheat_caller_address(address, contract_address_const::<0>());
    dispatcher.transfer_token(from, to, token_id);
}
