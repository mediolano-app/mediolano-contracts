use starknet::{ContractAddress, contract_address_const};

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};
use bulk_ip_tokenization::interfaces::{IIPNFTDispatcher, IIPNFTDispatcherTrait};

const OWNER: felt252 = 0x123;
const USER: felt252 = 0x456;

fn setup () -> (ContractAddress, IIPNFTDispatcher) {
    let contract_class = declare("IPNFT").unwrap().contract_class();
    let name: ByteArray = "MEDIOLANO";
    let symbol: ByteArray = "MDL";
    let token_uri: ByteArray = "https://example.com/token-metadata/1";

    let mut calldata = array![];
    OWNER.serialize(ref calldata);
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    token_uri.serialize(ref calldata);

    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    let dispatcher = IIPNFTDispatcher { contract_address };
    (contract_address, dispatcher)
} 

#[test]
fn test_mint() {
    let (address, dispatcher) = setup();
    let owner = contract_address_const::<OWNER>();
    let user = contract_address_const::<USER>();
    
    start_cheat_caller_address(address, owner);
    let token_id = dispatcher.mint(user);
    assert(token_id == 1, 'First token should be ID 1');
    assert(dispatcher.ownerOf(token_id) == user, 'Wrong token owner');
    stop_cheat_caller_address(address);
}

#[test]
#[should_panic]
fn test_transfer_restriction() {
    let (address, dispatcher) = setup();
    let user = contract_address_const::<USER>();
    let other_user = contract_address_const::<0x789>();
    
    start_cheat_caller_address(address, user);
    dispatcher.transferFrom(user, other_user, 1);
}

