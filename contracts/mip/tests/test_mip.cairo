use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use core::result::ResultTrait;
use mip::interfaces::{
    IMIPDispatcher, IMIPDispatcherTrait, IERC721Dispatcher, IERC721DispatcherTrait,
    IERC721MetadataDispatcher, IERC721MetadataDispatcherTrait, IERC721EnumerableDispatcher,
    IERC721EnumerableDispatcherTrait, IOwnableDispatcher, IOwnableDispatcherTrait,
    ICounterDispatcher, ICounterDispatcherTrait,
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

// Deploy the MIP contract
fn deploy_contract() -> (IMIPDispatcher, ContractAddress) {
    let owner = OWNER();
    let mut calldata = array![];
    owner.serialize(ref calldata);

    let declare_result = declare("MIP").expect('Failed to declare contract');
    let contract_class = declare_result.contract_class();
    let (contract_address, _) = contract_class
        .deploy(@calldata)
        .expect('Failed to deploy contract');

    let dispatcher = IMIPDispatcher { contract_address };
    (dispatcher, contract_address)
}

// Helper function to create dispatchers for different interfaces
fn create_erc721_dispatcher(contract_address: ContractAddress) -> IERC721Dispatcher {
    IERC721Dispatcher { contract_address }
}

fn create_erc721_metadata_dispatcher(
    contract_address: ContractAddress,
) -> IERC721MetadataDispatcher {
    IERC721MetadataDispatcher { contract_address }
}

fn create_erc721_enumerable_dispatcher(
    contract_address: ContractAddress,
) -> IERC721EnumerableDispatcher {
    IERC721EnumerableDispatcher { contract_address }
}

fn create_ownable_dispatcher(contract_address: ContractAddress) -> IOwnableDispatcher {
    IOwnableDispatcher { contract_address }
}

fn create_counter_dispatcher(contract_address: ContractAddress) -> ICounterDispatcher {
    ICounterDispatcher { contract_address }
}

#[test]
fn test_contract_deployment() {
    let (_mip_dispatcher, contract_address) = deploy_contract();

    // Create dispatchers for different interfaces
    let ownable_dispatcher = create_ownable_dispatcher(contract_address);
    let counter_dispatcher = create_counter_dispatcher(contract_address);
    let erc721_metadata_dispatcher = create_erc721_metadata_dispatcher(contract_address);
    let erc721_enumerable_dispatcher = create_erc721_enumerable_dispatcher(contract_address);

    // Test that owner is set correctly
    let owner = ownable_dispatcher.owner();
    assert(owner == OWNER(), 'Wrong owner');

    // Test that counter starts at 0
    let counter_value = counter_dispatcher.current();
    assert(counter_value == 0, 'Counter should start at 0');

    // Test ERC721 metadata
    let name = erc721_metadata_dispatcher.name();
    assert(name == "MIP Protocol", 'Wrong name');

    let symbol = erc721_metadata_dispatcher.symbol();
    assert(symbol == "MIP", 'Wrong symbol');

    // Test total supply starts at 0
    let total_supply = erc721_enumerable_dispatcher.total_supply();
    assert(total_supply == 0, 'Total supply should start at 0');
}

#[test]
fn test_mint_item() {
    let (mip_dispatcher, contract_address) = deploy_contract();
    let recipient = USER1();

    // Mint first token
    let token_id = mip_dispatcher.mint_item(recipient, "ipfs://QmTest123");
    assert(token_id == 1, 'First token should have ID 1');

    // Create dispatchers for verification
    let erc721_dispatcher = create_erc721_dispatcher(contract_address);
    let counter_dispatcher = create_counter_dispatcher(contract_address);
    let erc721_enumerable_dispatcher = create_erc721_enumerable_dispatcher(contract_address);

    // Check token ownership
    let token_owner = erc721_dispatcher.owner_of(token_id);
    assert(token_owner == recipient, 'Wrong token owner');

    // Check balance
    let balance = erc721_dispatcher.balance_of(recipient);
    assert(balance == 1, 'Wrong balance');

    // Check counter
    let counter_value = counter_dispatcher.current();
    assert(counter_value == 1, 'Counter should be 1');

    // Check total supply
    let total_supply = erc721_enumerable_dispatcher.total_supply();
    assert(total_supply == 1, 'Total supply should be 1');
}

#[test]
fn test_mint_multiple_items() {
    let (mip_dispatcher, contract_address) = deploy_contract();
    let recipient1 = USER1();
    let recipient2 = USER2();

    // Mint first token
    let token_id1 = mip_dispatcher.mint_item(recipient1, "ipfs://QmTest1");
    assert(token_id1 == 1, 'First token should have ID 1');

    // Mint second token
    let token_id2 = mip_dispatcher.mint_item(recipient2, "ipfs://QmTest2");
    assert(token_id2 == 2, 'Second token should have ID 2');

    // Create dispatchers for verification
    let erc721_dispatcher = create_erc721_dispatcher(contract_address);
    let counter_dispatcher = create_counter_dispatcher(contract_address);
    let erc721_enumerable_dispatcher = create_erc721_enumerable_dispatcher(contract_address);

    // Check balances
    let balance1 = erc721_dispatcher.balance_of(recipient1);
    assert(balance1 == 1, 'User1 should have 1 token');

    let balance2 = erc721_dispatcher.balance_of(recipient2);
    assert(balance2 == 1, 'User2 should have 1 token');

    // Check counter
    let counter_value = counter_dispatcher.current();
    assert(counter_value == 2, 'Counter should be 2');

    // Check total supply
    let total_supply = erc721_enumerable_dispatcher.total_supply();
    assert(total_supply == 2, 'Total supply should be 2');
}

#[test]
fn test_transfer_from() {
    let (mip_dispatcher, contract_address) = deploy_contract();
    let recipient = USER1();
    let new_owner = USER2();

    // Mint a token
    let token_id = mip_dispatcher.mint_item(recipient, "ipfs://QmTest");

    // Create ERC721 dispatcher for transfer
    let erc721_dispatcher = create_erc721_dispatcher(contract_address);

    // Set caller as the token owner for transfer
    start_cheat_caller_address(contract_address, recipient);

    // Transfer the token
    erc721_dispatcher.transfer_from(recipient, new_owner, token_id);

    // Stop cheating caller address
    stop_cheat_caller_address(contract_address);

    // Check new ownership
    let token_owner = erc721_dispatcher.owner_of(token_id);
    assert(token_owner == new_owner, 'Token should be td to new owner');
    // assert(token_owner == new_owner, 'Token should be transferred to new owner');

    // Check balances
    let balance_old = erc721_dispatcher.balance_of(recipient);
    assert(balance_old == 0, 'Old owner should have 0 tokens');

    let balance_new = erc721_dispatcher.balance_of(new_owner);
    assert(balance_new == 1, 'New owner should have 1 token');
}

#[test]
fn test_counter_operations() {
    let (_, contract_address) = deploy_contract();
    let counter_dispatcher = create_counter_dispatcher(contract_address);

    // Test initial state
    let initial_value = counter_dispatcher.current();
    assert(initial_value == 0, 'Counter should start at 0');

    // Test increment
    counter_dispatcher.increment();
    let after_increment = counter_dispatcher.current();
    assert(after_increment == 1, 'Counter should be 1');
    // assert(after_increment == 1, 'Counter should be 1 after increment');

    // Test decrement
    counter_dispatcher.decrement();
    let after_decrement = counter_dispatcher.current();
    assert(after_decrement == 0, 'Counter should be 0');
    // assert(after_decrement == 0, 'Counter should be 0 after decrement');
}

#[test]
fn test_ownership_transfer() {
    let (_, contract_address) = deploy_contract();
    let ownable_dispatcher = create_ownable_dispatcher(contract_address);
    let new_owner = USER1();

    // Check initial owner
    let initial_owner = ownable_dispatcher.owner();
    assert(initial_owner == OWNER(), 'Wrong initial owner');

    // Set caller as the current owner for ownership transfer
    start_cheat_caller_address(contract_address, OWNER());

    // Transfer ownership
    ownable_dispatcher.transfer_ownership(new_owner);

    // Stop cheating caller address
    stop_cheat_caller_address(contract_address);

    // Check new owner
    let final_owner = ownable_dispatcher.owner();
    assert(final_owner == new_owner, 'Ownership should be transferred');
}

#[test]
fn test_erc721_enumerable() {
    let (mip_dispatcher, contract_address) = deploy_contract();
    let owner1 = USER1();
    let owner2 = USER2();

    // Mint tokens
    let _token_id1 = mip_dispatcher.mint_item(owner1, "ipfs://QmTest1");
    let _token_id2 = mip_dispatcher.mint_item(owner2, "ipfs://QmTest2");
    let _token_id3 = mip_dispatcher.mint_item(owner1, "ipfs://QmTest3");

    // Create ERC721Enumerable dispatcher
    let erc721_enumerable_dispatcher = create_erc721_enumerable_dispatcher(contract_address);

    // Test total supply
    let total_supply = erc721_enumerable_dispatcher.total_supply();
    assert(total_supply == 3, 'Total supply should be 3');

    // Test token by index
    let token_at_0 = erc721_enumerable_dispatcher.token_by_index(0);
    let token_at_1 = erc721_enumerable_dispatcher.token_by_index(1);
    let token_at_2 = erc721_enumerable_dispatcher.token_by_index(2);

    assert(token_at_0 == 1, 'Token at index 0 should be 1');
    assert(token_at_1 == 2, 'Token at index 1 should be 2');
    assert(token_at_2 == 3, 'Token at index 2 should be 3');

    // Test token of owner by index
    let owner1_token_0 = erc721_enumerable_dispatcher.token_of_owner_by_index(owner1, 0);
    let owner1_token_1 = erc721_enumerable_dispatcher.token_of_owner_by_index(owner1, 1);
    let owner2_token_0 = erc721_enumerable_dispatcher.token_of_owner_by_index(owner2, 0);

    assert(owner1_token_0 == 1, 'Owner1 first token should be 1');
    assert(owner1_token_1 == 3, 'Owner1 second token should be 3');
    assert(owner2_token_0 == 2, 'Owner2 first token should be 2');
}
