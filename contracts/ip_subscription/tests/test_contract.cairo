// Import the contract module itself
use ip_subscription::Subscription;
// Make the required inner structs available in scope
use ip_subscription::Subscription::Subscription::{
    PlanCreated, Subscribed, Unsubscribed, SubscriptionRenewed, SubscriptionUpgraded
};

// Traits derived from the interface, allowing to interact with a deployed contract
use ip_subscription::interface::{ISubscriptionDispatcher, ISubscriptionDispatcherTrait};

// Required for declaring and deploying a contract
use snforge_std::{declare, DeclareResultTrait, ContractClassTrait};
// Cheatcodes to spy on events and assert their emissions
use snforge_std::{EventSpyAssertionsTrait, spy_events};
// Cheatcodes to cheat environment values - more cheatcodes exist
use snforge_std::{
    start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

// Helper function to deploy the contract
fn deploy_contract(owner: ContractAddress) -> ISubscriptionDispatcher {
    // Deploy the contract -
    // 1. Declare the contract class
    // 2. Create constructor arguments - serialize each one in a felt252 array
    // 3. Deploy the contract
    // 4. Create a dispatcher to interact with the contract
    let contract = declare("Subscription");
    let mut constructor_args = array![owner.into()];
    //Serde::serialize(@1_u8, ref constructor_args);
    let (contract_address, _err) = contract
        .unwrap()
        .contract_class()
        .deploy(@constructor_args)
        .unwrap();
    // Create a dispatcher to interact with the contract
    ISubscriptionDispatcher { contract_address }
}

#[test]
fn test_create_plan() {
    // Set up
    let owner: ContractAddress = 123.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let mut spy = spy_events();

    // Create plan
    let plan_id: felt252 = 100.try_into().unwrap();
    let price: u256 = u256 { low: 1000, high: 0 };
    let duration: u64 = 3600; // 1 hour
    let tier: felt252 = 1.try_into().unwrap();
    dispatcher.create_plan(plan_id, price, duration, tier);

    // Verify event emission
    let expected_event = Subscription::Subscription::Event::PlanCreated(
        PlanCreated { plan_id: plan_id, price: price, duration: duration, tier: tier }
    );
    let expected_events = array![(dispatcher.contract_address, expected_event)];
    spy.assert_emitted(@expected_events);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_subscribe() {
    // Set up
    let owner: ContractAddress = 123.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let mut spy = spy_events();

    // Create plan
    let plan_id: felt252 = 100.try_into().unwrap();
    let price: u256 = u256 { low: 1000, high: 0 };
    let duration: u64 = 3600; // 1 hour
    let tier: felt252 = 1.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.create_plan(plan_id, price, duration, tier);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Subscribe
    let subscriber: ContractAddress = 456.try_into().unwrap();
    start_cheat_caller_address(dispatcher.contract_address, subscriber);
    dispatcher.subscribe(plan_id);

    // Verify subscription status
    let is_subscribed = dispatcher.get_subscription_status();
    assert(is_subscribed == true, 'Should be subscribed');

    // Verify event emission
    let expected_event = Subscription::Subscription::Event::Subscribed(
        Subscribed { subscriber: subscriber, plan_id: plan_id }
    );
    let expected_events = array![(dispatcher.contract_address, expected_event)];
    spy.assert_emitted(@expected_events);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_unsubscribe() {
    // Set up
    let owner: ContractAddress = 123.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let mut spy = spy_events();

    // Create plan
    let plan_id: felt252 = 100.try_into().unwrap();
    let price: u256 = u256 { low: 1000, high: 0 };
    let duration: u64 = 3600; // 1 hour
    let tier: felt252 = 1.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.create_plan(plan_id, price, duration, tier);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Subscribe
    let subscriber: ContractAddress = 456.try_into().unwrap();
    start_cheat_caller_address(dispatcher.contract_address, subscriber);
    dispatcher.subscribe(plan_id);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Unsubscribe
    start_cheat_caller_address(dispatcher.contract_address, subscriber);
    dispatcher.unsubscribe();

    // Verify subscription status
    let is_subscribed = dispatcher.get_subscription_status();
    assert(is_subscribed == false, 'Should not be subscribed');

    // Verify event emission
    let expected_event = Subscription::Subscription::Event::Unsubscribed(
        Unsubscribed { subscriber: subscriber }
    );
    let expected_events = array![(dispatcher.contract_address, expected_event)];
    spy.assert_emitted(@expected_events);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_renew_subscription() {
    // Set up
    let owner: ContractAddress = 123.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let mut spy = spy_events();

    // Create plan
    let plan_id: felt252 = 100.try_into().unwrap();
    let price: u256 = u256 { low: 1000, high: 0 };
    let duration: u64 = 3600; // 1 hour
    let tier: felt252 = 1.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.create_plan(plan_id, price, duration, tier);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Subscribe
    let subscriber: ContractAddress = 456.try_into().unwrap();
    start_cheat_caller_address(dispatcher.contract_address, subscriber);
    dispatcher.subscribe(plan_id);
    stop_cheat_caller_address(dispatcher.contract_address);

    //Renew subscription
    start_cheat_caller_address(dispatcher.contract_address, subscriber);
    dispatcher.renew_subscription();

    let expected_event = Subscription::Subscription::Event::SubscriptionRenewed(
        SubscriptionRenewed { subscriber: subscriber }
    );
    let expected_events = array![(dispatcher.contract_address, expected_event)];
    spy.assert_emitted(@expected_events);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_upgrade_subscription() {
    // Set up
    let owner: ContractAddress = 123.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let mut spy = spy_events();

    // Create plan 1
    let plan_id_1: felt252 = 100.try_into().unwrap();
    let price_1: u256 = u256 { low: 1000, high: 0 };
    let duration: u64 = 3600; // 1 hour
    let tier_1: felt252 = 1.try_into().unwrap();

    // Create plan 2
    let plan_id_2: felt252 = 200.try_into().unwrap();
    let price_2: u256 = u256 { low: 2000, high: 0 };
    let tier_2: felt252 = 2.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.create_plan(plan_id_1, price_1, duration, tier_1);
    dispatcher.create_plan(plan_id_2, price_2, duration, tier_2);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Subscribe to plan 1
    let subscriber: ContractAddress = 456.try_into().unwrap();
    start_cheat_caller_address(dispatcher.contract_address, subscriber);
    dispatcher.subscribe(plan_id_1);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Upgrade subscription to plan 2
    start_cheat_caller_address(dispatcher.contract_address, subscriber);
    dispatcher.upgrade_subscription(plan_id_2);

    // Verify event emission
    let expected_event = Subscription::Subscription::Event::SubscriptionUpgraded(
        SubscriptionUpgraded { subscriber: subscriber, new_plan_id: plan_id_2 }
    );
    let expected_events = array![(dispatcher.contract_address, expected_event)];
    spy.assert_emitted(@expected_events);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'Only owner can create plans')]
fn test_create_plan_not_owner() {
    // Set up
    let owner: ContractAddress = 123.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Try to create plan with non-owner
    let plan_id: felt252 = 100.try_into().unwrap();
    let price: u256 = u256 { low: 1000, high: 0 };
    let duration: u64 = 3600; // 1 hour
    let tier: felt252 = 1.try_into().unwrap();

    let non_owner: ContractAddress = 456.try_into().unwrap();
    start_cheat_caller_address(dispatcher.contract_address, non_owner);
    dispatcher.create_plan(plan_id, price, duration, tier);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'Plan does not exist')]
fn test_subscribe_nonexistent_plan() {
    // Set up
    let owner: ContractAddress = 123.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Try to subscribe to a non-existent plan
    let plan_id: felt252 = 100.try_into().unwrap();

    let subscriber: ContractAddress = 456.try_into().unwrap();
    start_cheat_caller_address(dispatcher.contract_address, subscriber);
    dispatcher.subscribe(plan_id);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'Not currently subscribed')]
fn test_unsubscribe_not_subscribed() {
    // Set up
    let owner: ContractAddress = 123.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Try to unsubscribe without subscribing first
    let subscriber: ContractAddress = 456.try_into().unwrap();
    start_cheat_caller_address(dispatcher.contract_address, subscriber);
    dispatcher.unsubscribe();
    stop_cheat_caller_address(dispatcher.contract_address);
}
