use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use ip_leasing::interfaces::{IIPLeasingDispatcher, IIPLeasingDispatcherTrait};
use core::result::ResultTrait;

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
fn EXTRA_ACCOUNT() -> ContractAddress {
    contract_address_const::<0x999>()
}
const TOKEN_ID: u256 = 1;
const AMOUNT: u256 = 100;
const LEASE_FEE: u256 = 10;
const DURATION: u64 = 86400; // 1 day

// Deploy a contract (IPLeasing)
fn deploy_contract(name: ByteArray, calldata: Array<felt252>) -> ContractAddress {
    let declare_result = declare(name).expect('Failed to declare contract');
    let contract_class = declare_result.contract_class();
    let (contract_address, _) = contract_class
        .deploy(@calldata)
        .expect('Failed to deploy contract');
    contract_address
}

// Setup the IPLeasing contract
fn setup() -> (IIPLeasingDispatcher, ContractAddress) {
    let owner = OWNER();
    let mut calldata = array![];
    owner.serialize(ref calldata);
    let uri: ByteArray = "ipfs://QmBaseUri";
    uri.serialize(ref calldata);

    let contract_address = deploy_contract("IPLeasing", calldata);
    let dispatcher = IIPLeasingDispatcher { contract_address };
    (dispatcher, contract_address)
}

// Helper function to create test lease offer data
fn create_test_lease_offer_data() -> (u256, u256, u256, u64, ByteArray) {
    let license_terms_uri: ByteArray = "ipfs://QmLicenseTerms";
    (TOKEN_ID, AMOUNT, LEASE_FEE, DURATION, license_terms_uri)
}

// Helper function to set up IP and lease offer
fn setup_ip_and_offer(
    dispatcher: IIPLeasingDispatcher, address: ContractAddress,
) -> (ContractAddress, u256, u256, u256, u64, ByteArray) {
    let owner = OWNER();

    // Mint IP to contract address
    start_cheat_caller_address(address, owner);
    dispatcher.mint_ip(address, TOKEN_ID, AMOUNT);
    stop_cheat_caller_address(address);

    // Create lease offer
    let (token_id, amount, lease_fee, duration, license_terms_uri) = create_test_lease_offer_data();
    start_cheat_caller_address(address, owner);
    dispatcher.create_lease_offer(token_id, amount, lease_fee, duration, license_terms_uri.clone());
    stop_cheat_caller_address(address);

    (address, token_id, amount, lease_fee, duration, license_terms_uri)
}


#[test]
#[should_panic(expected: ('No active offer',))]
fn test_cancel_lease_offer_no_offer() {
    let (dispatcher, address) = setup();
    let owner = OWNER();
    let token_id = TOKEN_ID;

    start_cheat_caller_address(address, owner);
    dispatcher.cancel_lease_offer(token_id);
}

#[test]
#[should_panic(expected: ('No active offer',))]
fn test_start_lease_no_offer() {
    let (dispatcher, address) = setup();
    let lessee = USER1();
    let token_id = TOKEN_ID;

    start_cheat_caller_address(address, lessee);
    dispatcher.start_lease(token_id);
}


#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_mint_ip_not_owner() {
    let (dispatcher, address) = setup();
    let non_owner = USER1();

    start_cheat_caller_address(address, non_owner);
    dispatcher.mint_ip(address, TOKEN_ID, AMOUNT);
}

#[test]
#[should_panic(expected: ('Not token owner',))]
fn test_create_lease_offer_not_owner() {
    let (dispatcher, address) = setup();
    let non_owner = USER1();
    let (token_id, amount, lease_fee, duration, license_terms_uri) = create_test_lease_offer_data();

    start_cheat_caller_address(address, non_owner);
    dispatcher.create_lease_offer(token_id, amount, lease_fee, duration, license_terms_uri);
}

#[test]
#[should_panic(expected: ('No active lease',))]
fn test_renew_lease_no_lease() {
    let (dispatcher, address) = setup();
    let lessee = USER1();
    let token_id = TOKEN_ID;

    // Attempt to renew non-existent lease
    start_cheat_caller_address(address, lessee);
    dispatcher.renew_lease(token_id, DURATION);
}
