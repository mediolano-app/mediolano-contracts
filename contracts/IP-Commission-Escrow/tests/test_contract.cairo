use core::traits::TryInto;
use ip_smart_transaction::mock_erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    start_cheat_caller_address, stop_cheat_caller_address, declare, ContractClassTrait,
    DeclareResultTrait,
};
use ip_smart_transaction::ip_commission_escrow::{
    IIPCommissionEscrowDispatcher, IIPCommissionEscrowDispatcherTrait,
};
// Helper function to deploy the ERC20 contract
fn deploy_erc20() -> IERC20Dispatcher {
    let contract = declare("ERC20");
    let mut constructor_calldata = array![];
    let (contract_address, _) = contract
        .unwrap()
        .contract_class()
        .deploy(@constructor_calldata)
        .unwrap();
    IERC20Dispatcher { contract_address }
}

// Helper function to deploy the IPCommissionEscrow contract
fn deploy_escrow(token_address: ContractAddress) -> IIPCommissionEscrowDispatcher {
    let contract = declare("IPCommissionEscrow");
    let constructor_calldata = array![token_address.into()];
    let (contract_address, _) = contract
        .unwrap()
        .contract_class()
        .deploy(@constructor_calldata)
        .unwrap();
    IIPCommissionEscrowDispatcher { contract_address }
}
// Helper function to create a u256 from two felts
fn create_u256(low: felt252, high: felt252) -> u256 {
    u256 { low: low.try_into().unwrap(), high: high.try_into().unwrap() }
}

fn USER1() -> ContractAddress {
    contract_address_const::<'USER1'>()
}

#[test]
fn test_create_order() {
    // Define initial parameters
    let initial_supply = 1000;
    let creator: ContractAddress = 123.try_into().unwrap();
    let supplier: ContractAddress = 456.try_into().unwrap();
    let artwork_conditions: felt252 = 'ipfs_hash';
    let ip_license: felt252 = 'MIT';
    let amount = create_u256(100, 0);
    // Deploy ERC20 token
    let erc20_dispatcher = deploy_erc20();
    erc20_dispatcher.mint(USER1(), initial_supply);
    // Deploy IPCommissionEscrow contract
    let escrow_dispatcher = deploy_escrow(erc20_dispatcher.contract_address);
    // Cheat the caller address to be the creator
    start_cheat_caller_address(escrow_dispatcher.contract_address, creator);
    // Create the order
    let order_id = escrow_dispatcher.create_order(amount, supplier, artwork_conditions, ip_license);
    // Get order details
    let (
        order_creator,
        order_supplier,
        order_amount,
        order_state,
        order_artwork_conditions,
        order_ip_license,
    ) =
        escrow_dispatcher
        .get_order_details(order_id);

    // Assert the order details
    assert(order_creator == creator, 'Wrong creator');
    assert(order_supplier == supplier, 'Wrong supplier');
    assert(order_amount == amount, 'Wrong amount');
    assert(order_state == 'NotPaid', 'Wrong state');
    assert(order_artwork_conditions == artwork_conditions, 'Wrong artwork conditions');
    assert(order_ip_license == ip_license, 'Wrong IP license');
    // Stop cheating the caller address
    stop_cheat_caller_address(escrow_dispatcher.contract_address);
}

#[test]
fn test_pay_order() {
    // Define initial parameters
    let initial_supply = create_u256(1000, 0);
    let creator: ContractAddress = USER1();
    let supplier: ContractAddress = 456.try_into().unwrap();
    let artwork_conditions: felt252 = 'ipfs_hash';
    let ip_license: felt252 = 'MIT';
    let amount = create_u256(100, 0);
    // Deploy ERC20 token
    let erc20_dispatcher = deploy_erc20();
    erc20_dispatcher.mint(creator, initial_supply);
    // Deploy IPCommissionEscrow contract
    let escrow_dispatcher = deploy_escrow(erc20_dispatcher.contract_address);
    // Cheat the caller address to be the creator
    start_cheat_caller_address(escrow_dispatcher.contract_address, creator);
    // Create the order
    let order_id = escrow_dispatcher.create_order(amount, supplier, artwork_conditions, ip_license);
    // Stop cheating the caller address
    stop_cheat_caller_address(escrow_dispatcher.contract_address);
    // Approve the escrow contract to spend tokens on behalf of the creator
    start_cheat_caller_address(erc20_dispatcher.contract_address, creator);
    erc20_dispatcher.approve(escrow_dispatcher.contract_address, amount);
    stop_cheat_caller_address(erc20_dispatcher.contract_address);
    // Pay the order
    start_cheat_caller_address(escrow_dispatcher.contract_address, creator);
    escrow_dispatcher.pay_order(order_id);
    stop_cheat_caller_address(escrow_dispatcher.contract_address);
    // Get order details
    let (
        order_creator,
        order_supplier,
        order_amount,
        order_state,
        order_artwork_conditions,
        order_ip_license,
    ) =
        escrow_dispatcher
        .get_order_details(order_id);
    // Assert the order details
    assert(order_creator == creator, 'Wrong creator');
    assert(order_supplier == supplier, 'Wrong supplier');
    assert(order_amount == amount, 'Wrong amount');
    assert(order_state == 'Paid', 'Wrong state');
    assert(order_artwork_conditions == artwork_conditions, 'Wrong artwork conditions');
    assert(order_ip_license == ip_license, 'Wrong IP license');
}
#[test]
fn test_complete_order() {
    // Define initial parameters
    let initial_supply = create_u256(1000, 0);
    let creator: ContractAddress = 123.try_into().unwrap();
    let supplier: ContractAddress = 456.try_into().unwrap();
    let artwork_conditions: felt252 = 'ipfs_hash';
    let ip_license: felt252 = 'MIT';
    let amount = create_u256(100, 0);
    // Deploy ERC20 token
    let erc20_dispatcher = deploy_erc20();
    erc20_dispatcher.mint(creator, initial_supply);
    // Deploy IPCommissionEscrow contract
    let escrow_dispatcher = deploy_escrow(erc20_dispatcher.contract_address);
    // Cheat the caller address to be the creator
    start_cheat_caller_address(escrow_dispatcher.contract_address, creator);
    // Create the order
    let order_id = escrow_dispatcher.create_order(amount, supplier, artwork_conditions, ip_license);
    // Stop cheating the caller address
    stop_cheat_caller_address(escrow_dispatcher.contract_address);
    // Approve the escrow contract to spend tokens on behalf of the creator
    start_cheat_caller_address(erc20_dispatcher.contract_address, creator);
    erc20_dispatcher.approve(escrow_dispatcher.contract_address, amount);
    stop_cheat_caller_address(erc20_dispatcher.contract_address);
    // Pay the order
    start_cheat_caller_address(escrow_dispatcher.contract_address, creator);
    escrow_dispatcher.pay_order(order_id);
    stop_cheat_caller_address(escrow_dispatcher.contract_address);
    // Complete the order
    start_cheat_caller_address(escrow_dispatcher.contract_address, creator);
    escrow_dispatcher.complete_order(order_id);
    stop_cheat_caller_address(escrow_dispatcher.contract_address);
    // Get order details
    let (
        order_creator,
        order_supplier,
        order_amount,
        order_state,
        order_artwork_conditions,
        order_ip_license,
    ) =
        escrow_dispatcher
        .get_order_details(order_id);
    // Assert the order details
    assert(order_creator == creator, 'Wrong creator');
    assert(order_supplier == supplier, 'Wrong supplier');
    assert(order_amount == amount, 'Wrong amount');
    assert(order_state == 'Completed', 'Wrong state');
    assert(order_artwork_conditions == artwork_conditions, 'Wrong artwork conditions');
    assert(order_ip_license == ip_license, 'Wrong IP license');
}
#[test]
fn test_cancel_order() {
    // Define initial parameters
    let initial_supply = create_u256(1000, 0);
    let creator: ContractAddress = 123.try_into().unwrap();
    let supplier: ContractAddress = 456.try_into().unwrap();
    let artwork_conditions: felt252 = 'ipfs_hash';
    let ip_license: felt252 = 'MIT';
    let amount = create_u256(100, 0);
    // Deploy ERC20 token
    let erc20_dispatcher = deploy_erc20();
    erc20_dispatcher.mint(creator, initial_supply);
    // Deploy IPCommissionEscrow contract
    let escrow_dispatcher = deploy_escrow(erc20_dispatcher.contract_address);
    // Cheat the caller address to be the creator
    start_cheat_caller_address(escrow_dispatcher.contract_address, creator);
    // Create the order
    let order_id = escrow_dispatcher.create_order(amount, supplier, artwork_conditions, ip_license);
    // Cancel the order
    escrow_dispatcher.cancel_order(order_id);
    // Stop cheating the caller address
    stop_cheat_caller_address(escrow_dispatcher.contract_address);
    // Get order details
    let (
        order_creator,
        order_supplier,
        order_amount,
        order_state,
        order_artwork_conditions,
        order_ip_license,
    ) =
        escrow_dispatcher
        .get_order_details(order_id);
    // Assert the order details
    assert(order_creator == creator, 'Wrong creator');
    assert(order_supplier == supplier, 'Wrong supplier');
    assert(order_amount == amount, 'Wrong amount');
    assert(order_state == 'Cancelled', 'Wrong state');
    assert(order_artwork_conditions == artwork_conditions, 'Wrong artwork conditions');
    assert(order_ip_license == ip_license, 'Wrong IP license');
}
