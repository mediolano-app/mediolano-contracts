use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use ip_collective_agreement::interfaces::{ICollectiveIPDispatcher, ICollectiveIPDispatcherTrait};

// Test constants
const OWNER: felt252 = 0x123;
const USER1: felt252 = 0x456;
const USER2: felt252 = 0x789;
const DISPUTE_RESOLVER: felt252 = 0xabc;

// Deploy the contract
fn deploy_contract(name: ByteArray, calldata: Array<felt252>) -> ContractAddress {
    let contract_class = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
}

fn setup() -> (ICollectiveIPDispatcher, ContractAddress) {
    let owner = contract_address_const::<OWNER>();
    let uri: ByteArray = "ipfs://QmBaseUri";
    let dispute_resolver = contract_address_const::<DISPUTE_RESOLVER>();

    let mut calldata = array![];
    owner.serialize(ref calldata);
    uri.serialize(ref calldata);
    dispute_resolver.serialize(ref calldata);

    let contract_address = deploy_contract("CollectiveIPAgreement", calldata);
    let dispatcher = ICollectiveIPDispatcher { contract_address };
    (dispatcher, contract_address)
}

// Helper function to create test IP data
fn create_test_ip_data(
    token_id: u256,
) -> (u256, ByteArray, Array<ContractAddress>, Array<u256>, u256, u64, ByteArray) {
    let metadata_uri: ByteArray = "ipfs://QmTest";
    let owners = array![contract_address_const::<USER1>(), contract_address_const::<USER2>()];
    let ownership_shares = array![500_u256, 500_u256]; // 50% each
    let royalty_rate: u256 = 100; // 10%
    let expiry_date: u64 = 1735689600; // Some future date
    let license_terms: ByteArray = "Standard";

    (token_id, metadata_uri, owners, ownership_shares, royalty_rate, expiry_date, license_terms)
}

#[test]
fn test_register_ip() {
    let (dispatcher, address) = setup();
    let owner = contract_address_const::<OWNER>();
    let token_id: u256 = 1;
    let (
        token_id, metadata_uri, owners, ownership_shares, royalty_rate, expiry_date, license_terms,
    ) =
        create_test_ip_data(
        token_id,
    );

    start_cheat_caller_address(address, owner);
    dispatcher
        .register_ip(
            token_id,
            metadata_uri.clone(),
            owners,
            ownership_shares,
            royalty_rate,
            expiry_date,
            license_terms.clone(),
        );
    stop_cheat_caller_address(address);

    // Verify IP data
    let ip_data = dispatcher.get_ip_metadata(token_id);
    assert(ip_data.metadata_uri == metadata_uri, 'Wrong metadata URI');
    assert(ip_data.owner_count == 2, 'Wrong owner count');
    assert(ip_data.royalty_rate == royalty_rate, 'Wrong royalty rate');
    assert(ip_data.expiry_date == expiry_date, 'Wrong expiry date');
    assert(ip_data.license_terms == license_terms, 'Wrong license terms');

    // Verify owners and shares
    assert(dispatcher.get_owner(token_id, 0) == contract_address_const::<USER1>(), 'Wrong owner 1');
    assert(dispatcher.get_owner(token_id, 1) == contract_address_const::<USER2>(), 'Wrong owner 2');
    assert(
        dispatcher.get_ownership_share(token_id, contract_address_const::<USER1>()) == 500,
        'Wrong share 1',
    );
    assert(
        dispatcher.get_ownership_share(token_id, contract_address_const::<USER2>()) == 500,
        'Wrong share 2',
    );

    // Verify total supply
    assert(dispatcher.get_total_supply(token_id) == 1000, 'Wrong total supply');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_register_ip_not_owner() {
    let (dispatcher, address) = setup();
    let non_owner = contract_address_const::<USER1>();
    let token_id: u256 = 1;
    let (
        token_id, metadata_uri, owners, ownership_shares, royalty_rate, expiry_date, license_terms,
    ) =
        create_test_ip_data(
        token_id,
    );

    start_cheat_caller_address(address, non_owner);
    dispatcher
        .register_ip(
            token_id,
            metadata_uri,
            owners,
            ownership_shares,
            royalty_rate,
            expiry_date,
            license_terms,
        );
}

#[test]
fn test_distribute_royalties() {
    let (dispatcher, address) = setup();
    let owner = contract_address_const::<OWNER>();
    let token_id: u256 = 1;
    let (
        token_id, metadata_uri, owners, ownership_shares, royalty_rate, expiry_date, license_terms,
    ) =
        create_test_ip_data(
        token_id,
    );

    // Register IP
    start_cheat_caller_address(address, owner);
    dispatcher
        .register_ip(
            token_id,
            metadata_uri,
            owners,
            ownership_shares,
            royalty_rate,
            expiry_date,
            license_terms,
        );

    // Distribute royalties
    let total_amount: u256 = 1000;
    dispatcher.distribute_royalties(token_id, total_amount);
    stop_cheat_caller_address(address);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_distribute_royalties_not_owner() {
    let (dispatcher, address) = setup();
    let owner = contract_address_const::<OWNER>();
    let non_owner = contract_address_const::<USER1>();
    let token_id: u256 = 1;
    let (
        token_id, metadata_uri, owners, ownership_shares, royalty_rate, expiry_date, license_terms,
    ) =
        create_test_ip_data(
        token_id,
    );

    // Register IP
    start_cheat_caller_address(address, owner);
    dispatcher
        .register_ip(
            token_id,
            metadata_uri,
            owners,
            ownership_shares,
            royalty_rate,
            expiry_date,
            license_terms,
        );
    stop_cheat_caller_address(address);

    // Attempt to distribute royalties as non-owner
    start_cheat_caller_address(address, non_owner);
    dispatcher.distribute_royalties(token_id, 1000);
}

#[test]
fn test_create_proposal() {
    let (dispatcher, address) = setup();
    let owner = contract_address_const::<OWNER>();
    let user1 = contract_address_const::<USER1>();
    let token_id: u256 = 1;
    let (
        token_id, metadata_uri, owners, ownership_shares, royalty_rate, expiry_date, license_terms,
    ) =
        create_test_ip_data(
        token_id,
    );

    // Register IP
    start_cheat_caller_address(address, owner);
    dispatcher
        .register_ip(
            token_id,
            metadata_uri,
            owners,
            ownership_shares,
            royalty_rate,
            expiry_date,
            license_terms,
        );
    stop_cheat_caller_address(address);

    // Create proposal
    let description: ByteArray = "Update license terms";
    start_cheat_caller_address(address, user1);
    dispatcher.create_proposal(token_id, description.clone());
    stop_cheat_caller_address(address);

    // Verify proposal
    let proposal = dispatcher.get_proposal(1);
    assert(proposal.proposer == user1, 'Wrong proposer');
    assert(proposal.description == description, 'Wrong description');
    assert(proposal.vote_count == 0, 'Wrong vote count');
    assert(proposal.executed == false, 'Wrong executed status');
    assert(proposal.deadline == get_block_timestamp() + 604800, 'Wrong deadline');
}

#[test]
#[should_panic(expected: ('Not an owner',))]
fn test_create_proposal_not_owner() {
    let (dispatcher, address) = setup();
    let owner = contract_address_const::<OWNER>();
    let non_owner = contract_address_const::<0x999>();
    let token_id: u256 = 1;
    let (
        token_id, metadata_uri, owners, ownership_shares, royalty_rate, expiry_date, license_terms,
    ) =
        create_test_ip_data(
        token_id,
    );

    // Register IP
    start_cheat_caller_address(address, owner);
    dispatcher
        .register_ip(
            token_id,
            metadata_uri,
            owners,
            ownership_shares,
            royalty_rate,
            expiry_date,
            license_terms,
        );
    stop_cheat_caller_address(address);

    // Attempt to create proposal as non-owner
    let description: ByteArray = "Update license terms";
    start_cheat_caller_address(address, non_owner);
    dispatcher.create_proposal(token_id, description);
}

#[test]
fn test_resolve_dispute() {
    let (dispatcher, address) = setup();
    let owner = contract_address_const::<OWNER>();
    let dispute_resolver = contract_address_const::<DISPUTE_RESOLVER>();
    let token_id: u256 = 1;
    let (
        token_id, metadata_uri, owners, ownership_shares, royalty_rate, expiry_date, license_terms,
    ) =
        create_test_ip_data(
        token_id,
    );

    // Register IP
    start_cheat_caller_address(address, owner);
    dispatcher
        .register_ip(
            token_id,
            metadata_uri,
            owners,
            ownership_shares,
            royalty_rate,
            expiry_date,
            license_terms,
        );
    stop_cheat_caller_address(address);

    // Resolve dispute
    let resolution: ByteArray = "Dispute resolved in favor of owner";
    start_cheat_caller_address(address, dispute_resolver);
    dispatcher.resolve_dispute(token_id, resolution.clone());
    stop_cheat_caller_address(address);
}

#[test]
#[should_panic(expected: ('Not dispute resolver',))]
fn test_resolve_dispute_not_resolver() {
    let (dispatcher, address) = setup();
    let owner = contract_address_const::<OWNER>();
    let non_resolver = contract_address_const::<USER1>();
    let token_id: u256 = 1;
    let (
        token_id, metadata_uri, owners, ownership_shares, royalty_rate, expiry_date, license_terms,
    ) =
        create_test_ip_data(
        token_id,
    );

    // Register IP
    start_cheat_caller_address(address, owner);
    dispatcher
        .register_ip(
            token_id,
            metadata_uri,
            owners,
            ownership_shares,
            royalty_rate,
            expiry_date,
            license_terms,
        );
    stop_cheat_caller_address(address);

    // Attempt to resolve dispute as non-resolver
    let resolution: ByteArray = "Dispute resolved in favor of owner";
    start_cheat_caller_address(address, non_resolver);
    dispatcher.resolve_dispute(token_id, resolution);
}

#[test]
fn test_set_dispute_resolver() {
    let (dispatcher, address) = setup();
    let owner = contract_address_const::<OWNER>();
    let new_resolver = contract_address_const::<0xdef>();

    start_cheat_caller_address(address, owner);
    dispatcher.set_dispute_resolver(new_resolver);
    stop_cheat_caller_address(address);

    // Verify indirectly via resolve_dispute
    let token_id: u256 = 1;
    let (
        token_id, metadata_uri, owners, ownership_shares, royalty_rate, expiry_date, license_terms,
    ) =
        create_test_ip_data(
        token_id,
    );
    start_cheat_caller_address(address, owner);
    dispatcher
        .register_ip(
            token_id,
            metadata_uri,
            owners,
            ownership_shares,
            royalty_rate,
            expiry_date,
            license_terms,
        );
    stop_cheat_caller_address(address);

    let resolution: ByteArray = "Dispute resolved";
    start_cheat_caller_address(address, new_resolver);
    dispatcher.resolve_dispute(token_id, resolution);
    stop_cheat_caller_address(address);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_dispute_resolver_not_owner() {
    let (dispatcher, address) = setup();
    let non_owner = contract_address_const::<USER1>();
    let new_resolver = contract_address_const::<0xdef>();

    start_cheat_caller_address(address, non_owner);
    dispatcher.set_dispute_resolver(new_resolver);
}
