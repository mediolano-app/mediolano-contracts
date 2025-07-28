#[cfg(test)]
mod tests {
    // Import necessary modules and traits for testing
    use core::array::ArrayTrait;
    use core::integer::{u256, u64}; // Import required integer types
    use core::option::OptionTrait;
    use core::result::ResultTrait;
    use core::traits::Into;

    // Import the contract module itself
    use ip_launchpad::crowd_funding::Crowdfunding;
    // Make the required inner structs available in scope for event assertions
    use ip_launchpad::crowd_funding::Crowdfunding::{
        AssetCreated, CreatorWithdrawal, Funded, FundingClosed, InvestorWithdrawal,
    };
    // Traits derived from the contract interface, allowing interaction with a deployed contract
    use ip_launchpad::interfaces::ICrowdfunding::{
        ICrowdfundingDispatcher, ICrowdfundingDispatcherTrait,
    };
    use ip_launchpad::interfaces::IERC20::IERC20Dispatcher;

    // Required for declaring and deploying a contract using Starknet Foundry
    use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
    // Cheatcodes to spy on events and assert their emissions
    use snforge_std::{EventSpyAssertionsTrait, spy_events};
    // Cheatcodes to cheat environment values (caller address, block timestamp)
    use snforge_std::{
        start_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_block_timestamp,
        stop_cheat_caller_address,
    };
    use starknet::ContractAddress;
    use crate::interfaces::IERC20::IERC20DispatcherTrait;

    // Define some constant addresses for testing
    const OWNER_ADDRESS: ContractAddress = 100.try_into().unwrap();
    const CREATOR_ADDRESS: ContractAddress = 200.try_into().unwrap();
    const INVESTOR_ADDRESS_1: ContractAddress = 300.try_into().unwrap();
    const INVESTOR_ADDRESS_2: ContractAddress = 400.try_into().unwrap();
    const OTHER_ADDRESS: ContractAddress = 500.try_into().unwrap();
    const TOKEN_ADDRESS: ContractAddress = 600.try_into().unwrap(); // Dummy ERC20 token address

    // Helper function to deploy the Crowdfunding contract
    // It takes the contract owner and the ERC20 token address as constructor arguments
    fn deploy_crowdfunding_contract(
        owner: ContractAddress,
    ) -> (ICrowdfundingDispatcher, IERC20Dispatcher) {
        // 1. Declare the contract class
        let contract = declare("Crowdfunding");

        let erc20_dispatcher = deploy_mock_erc20(owner);

        // 2. Create constructor arguments - serialize each one into a felt252 array
        let mut constructor_args = array![];
        // The constructor expects owner and ip_token_contract
        Serde::serialize(@owner, ref constructor_args);
        Serde::serialize(@erc20_dispatcher.contract_address, ref constructor_args);

        // 3. Deploy the contract and retrieve its address
        let (contract_address, _) = contract
            .unwrap()
            .contract_class()
            .deploy(@constructor_args)
            .unwrap();

        // 4. Create a dispatcher to interact with the contract using its interface
        (ICrowdfundingDispatcher { contract_address }, erc20_dispatcher)
    }

    fn deploy_mock_erc20(owner: ContractAddress) -> IERC20Dispatcher {
        // 1. Declare the contract class, identified by its module name "MockToken"
        let contract = declare("MockToken");

        // 2. Create constructor arguments - serialize each one into a felt252 array
        let mut constructor_args = array![];

        Serde::serialize(@owner, ref constructor_args);

        // 3. Deploy the contract and retrieve its address
        let (contract_address, _) = contract
            .unwrap()
            .contract_class()
            .deploy(@constructor_args)
            .unwrap();

        // 4. Create a dispatcher to interact with the contract using its interface
        IERC20Dispatcher { contract_address }
    }

    // --- Test Cases ---
    #[test]
    fn test_constructor() {
        // Deploy the contract with specific owner and token address
        let (dispatcher, token_dispatcher) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Use cheatcode to mock the caller address for checking the owner set in constructor
        start_cheat_caller_address(dispatcher.contract_address, OWNER_ADDRESS);

        let asset_count = dispatcher.get_asset_count();
        let token_addr = dispatcher.get_token_address();

        assert!(asset_count == 0, "Initial asset_count not 0");
        assert!(
            token_addr == token_dispatcher.contract_address,
            "Initial token_address not set correctly",
        );

        // Stop mocking caller address
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_create_asset() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Setup cheatcodes: mock caller and block timestamp
        let creator = CREATOR_ADDRESS;
        start_cheat_caller_address(dispatcher.contract_address, creator);
        let start_time: u64 = 1000;
        start_cheat_block_timestamp(dispatcher.contract_address, start_time);

        // Setup event spy to capture emitted events
        let mut spy = spy_events();

        // Define asset parameters
        let goal: u256 = 10000.into();
        let duration: u64 = 86400; // 1 day
        let base_price: u256 = 100.into();
        let ipfs_hash_parts = array![123, 456, 789];
        let expected_asset_id: u64 = 0; // First asset created will have ID 0

        // Call the create_asset function
        dispatcher.create_asset(goal, duration, base_price, ipfs_hash_parts.clone());

        // Stop mocking
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Verify state updates
        let asset_count = dispatcher.get_asset_count();
        assert(asset_count == 1, 'asset_count not incremented');

        let asset_data = dispatcher.get_asset_data(expected_asset_id);
        assert!(asset_data.creator == creator, "Wrong asset creator");
        assert!(asset_data.goal == goal, "Wrong asset goal");
        assert!(asset_data.raised == 0.into(), "Initial raised amount not 0");
        assert!(asset_data.start_time == start_time, "Wrong asset start_time");
        assert!(asset_data.end_time == start_time + duration, "Wrong asset end_time");
        assert!(asset_data.base_price == base_price, "Wrong asset base_price");
        assert!(!asset_data.is_closed, "Asset should not be closed initially");
        assert!(asset_data.ipfs_hash_len == ipfs_hash_parts.len().into(), "Wrong ipfs_hash_len");

        let stored_ipfs_hash = dispatcher.get_asset_ipfs_hash(expected_asset_id);
        assert!(
            stored_ipfs_hash.len() == ipfs_hash_parts.len(), "Stored IPFS hash length mismatch",
        );
        // Verify each part of the IPFS hash
        let mut i: usize = 0;
        while i != ipfs_hash_parts.len() {
            assert(*stored_ipfs_hash.at(i) == *ipfs_hash_parts.at(i), 'IPFS hash part mismatch');
            i += 1;
        }

        // Verify event emission
        let expected_event = Crowdfunding::Event::AssetCreated(
            AssetCreated {
                asset_id: expected_asset_id,
                creator: creator,
                goal: goal,
                start_time: start_time,
                duration: duration,
                base_price: base_price,
                ipfs_hash_len: ipfs_hash_parts.len().into(),
                ipfs_hash: ipfs_hash_parts.span() // Events emit Span
            },
        );
        let expected_events = array![(dispatcher.contract_address, expected_event)];
        spy.assert_emitted(@expected_events);
    }

    #[test]
    #[should_panic(expected: ('DURATION_MUST_BE_POSITIVE',))]
    fn test_create_asset_panic_zero_duration() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);
        start_cheat_caller_address(dispatcher.contract_address, CREATOR_ADDRESS);
        dispatcher.create_asset(1000.into(), 0, 100.into(), array![]);
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('GOAL_MUST_BE_POSITIVE',))]
    fn test_create_asset_panic_zero_goal() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);
        start_cheat_caller_address(dispatcher.contract_address, CREATOR_ADDRESS);
        dispatcher.create_asset(0.into(), 86400, 100.into(), array![]);
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('BASE_PRICE_MUST_BE_POSITIVE',))]
    fn test_create_asset_panic_zero_base_price() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);
        start_cheat_caller_address(dispatcher.contract_address, CREATOR_ADDRESS);
        dispatcher.create_asset(1000.into(), 86400, 0.into(), array![]);
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_fund_success() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Create an asset first
        let creator = CREATOR_ADDRESS;
        start_cheat_caller_address(dispatcher.contract_address, creator);
        let start_time: u64 = 1000;
        start_cheat_block_timestamp(dispatcher.contract_address, start_time);
        let goal: u256 = 10000.into();
        let duration: u64 = 86400;
        let base_price: u256 = 100.into(); // Discounted price will be 90 (min 10% discount)
        let ipfs_hash_parts = array![];
        dispatcher.create_asset(goal, duration, base_price, ipfs_hash_parts.clone());
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Move block timestamp to within the funding period
        let fund_time = start_time + 100; // 100 seconds into the funding
        start_cheat_block_timestamp(dispatcher.contract_address, fund_time);

        // Setup event spy
        let mut spy = spy_events();

        // Fund the asset
        let investor = INVESTOR_ADDRESS_1;
        let amount_to_fund: u256 = 90.into(); // Fund exactly the discounted price (90)
        start_cheat_caller_address(dispatcher.contract_address, investor);
        let asset_id: u64 = 0;
        dispatcher.fund(asset_id, amount_to_fund);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Verify state updates
        let asset_data = dispatcher.get_asset_data(asset_id);
        assert(asset_data.raised == amount_to_fund, 'Asset raised amount not updated');

        let investor_data = dispatcher.get_investor_data(asset_id, investor);
        assert!(investor_data.amount == amount_to_fund, "Investor investment amount not updated");
        assert!(investor_data.timestamp == fund_time, "Investor investment timestamp not updated");

        // Verify event emission
        let expected_event = Crowdfunding::Event::Funded(
            Funded {
                asset_id: asset_id,
                investor: investor,
                amount: amount_to_fund,
                timestamp: fund_time,
            },
        );
        let expected_events = array![(dispatcher.contract_address, expected_event)];
        spy.assert_emitted(@expected_events);
    }

    #[test]
    #[should_panic(expected: ('AMOUNT_ZERO',))]
    fn test_fund_panic_zero_amount() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Create an asset first
        start_cheat_caller_address(dispatcher.contract_address, CREATOR_ADDRESS);
        start_cheat_block_timestamp(dispatcher.contract_address, 1000);
        dispatcher.create_asset(1000.into(), 86400, 100.into(), array![]);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Attempt to fund with zero amount
        start_cheat_caller_address(dispatcher.contract_address, INVESTOR_ADDRESS_1);
        start_cheat_block_timestamp(
            dispatcher.contract_address, 1000 + 100,
        ); // Within funding period
        dispatcher.fund(0, 0.into());
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('FUNDING_NOT_STARTED',))]
    fn test_fund_panic_before_start() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Create an asset first
        start_cheat_caller_address(dispatcher.contract_address, CREATOR_ADDRESS);
        let start_time: u64 = 1000;
        start_cheat_block_timestamp(dispatcher.contract_address, start_time);
        dispatcher.create_asset(1000.into(), 86400, 100.into(), array![]);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Attempt to fund before start time
        start_cheat_caller_address(dispatcher.contract_address, INVESTOR_ADDRESS_1);
        start_cheat_block_timestamp(
            dispatcher.contract_address, start_time - 1,
        ); // Before funding period
        dispatcher.fund(0, 100.into());
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('FUNDING_ENDED',))]
    fn test_fund_panic_after_end() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Create an asset first
        start_cheat_caller_address(dispatcher.contract_address, CREATOR_ADDRESS);
        let start_time: u64 = 1000;
        let duration: u64 = 100; // Short duration for easy testing
        start_cheat_block_timestamp(dispatcher.contract_address, start_time);
        dispatcher.create_asset(1000.into(), duration, 100.into(), array![]);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Attempt to fund after end time
        start_cheat_caller_address(dispatcher.contract_address, INVESTOR_ADDRESS_1);
        start_cheat_block_timestamp(
            dispatcher.contract_address, start_time + duration + 1,
        ); // After funding period
        dispatcher.fund(0, 100.into());
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('INSUFFICIENT_FUNDS',))]
    fn test_fund_panic_insufficient_funds() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Create an asset first
        start_cheat_caller_address(dispatcher.contract_address, CREATOR_ADDRESS);
        let start_time: u64 = 1000;
        start_cheat_block_timestamp(dispatcher.contract_address, start_time);
        let base_price: u256 = 100.into(); // Discounted price will be 90 (min 10% discount)
        dispatcher.create_asset(1000.into(), 86400, base_price, array![]);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Attempt to fund with less than the discounted price (e.g., 89)
        start_cheat_caller_address(dispatcher.contract_address, INVESTOR_ADDRESS_1);
        start_cheat_block_timestamp(
            dispatcher.contract_address, start_time + 100,
        ); // Within funding period
        dispatcher.fund(0, 89.into());
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);
    }


    #[test]
    fn test_close_funding_success() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Create an asset
        let creator = CREATOR_ADDRESS;
        start_cheat_caller_address(dispatcher.contract_address, creator);
        let start_time: u64 = 1000;
        let duration: u64 = 100;
        let goal: u256 = 100.into();
        start_cheat_block_timestamp(dispatcher.contract_address, start_time);
        dispatcher.create_asset(goal, duration, 100.into(), array![]);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Fund the asset to meet the goal
        let investor = INVESTOR_ADDRESS_1;
        let amount_to_fund: u256 = 100
            .into(); // Fund enough to meet or exceed goal (discounted price 90)
        start_cheat_caller_address(dispatcher.contract_address, investor);
        start_cheat_block_timestamp(
            dispatcher.contract_address, start_time + 10,
        ); // Within funding period
        dispatcher.fund(0, amount_to_fund);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Move block timestamp past the funding end time
        let end_time = start_time + duration;
        start_cheat_block_timestamp(dispatcher.contract_address, end_time + 1);

        // Setup event spy
        let mut spy = spy_events();

        // Close the funding as the creator
        start_cheat_caller_address(dispatcher.contract_address, creator);
        dispatcher.close_funding(0);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Verify state update
        let asset_data = dispatcher.get_asset_data(0);
        assert(asset_data.is_closed, 'Asset should be closed');

        // Verify event emission
        let expected_event = Crowdfunding::Event::FundingClosed(
            FundingClosed { asset_id: 0, total_raised: asset_data.raised, success: true },
        );
        let expected_events = array![(dispatcher.contract_address, expected_event)];
        spy.assert_emitted(@expected_events);
    }

    #[test]
    #[should_panic(expected: ('INSUFFICIENT_FUNDS',))]
    fn test_close_funding_failure() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Create an asset
        let creator = CREATOR_ADDRESS;
        start_cheat_caller_address(dispatcher.contract_address, creator);
        let start_time: u64 = 1000;
        let duration: u64 = 100;
        let goal: u256 = 1000.into(); // Goal is high
        start_cheat_block_timestamp(dispatcher.contract_address, start_time);
        dispatcher.create_asset(goal, duration, 100.into(), array![]);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Fund the asset, but not enough to meet the goal
        let investor = INVESTOR_ADDRESS_1;
        let amount_to_fund: u256 = 50.into(); // Less than goal
        start_cheat_caller_address(dispatcher.contract_address, investor);
        start_cheat_block_timestamp(
            dispatcher.contract_address, start_time + 10,
        ); // Within funding period
        dispatcher.fund(0, amount_to_fund);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Move block timestamp past the funding end time
        let end_time = start_time + duration;
        start_cheat_block_timestamp(dispatcher.contract_address, end_time + 1);

        // Setup event spy
        let mut spy = spy_events();

        // Close the funding as the creator
        start_cheat_caller_address(dispatcher.contract_address, creator);
        dispatcher.close_funding(0);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Verify state update
        let asset_data = dispatcher.get_asset_data(0);
        assert(asset_data.is_closed, 'Asset should be closed');

        // Verify event emission
        let expected_event = Crowdfunding::Event::FundingClosed(
            FundingClosed { asset_id: 0, total_raised: asset_data.raised, success: false },
        );
        let expected_events = array![(dispatcher.contract_address, expected_event)];
        spy.assert_emitted(@expected_events);
    }


    #[test]
    #[should_panic(expected: ('NOT_CREATOR',))]
    fn test_close_funding_panic_not_creator() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Create an asset
        start_cheat_caller_address(dispatcher.contract_address, CREATOR_ADDRESS);
        start_cheat_block_timestamp(dispatcher.contract_address, 1000);
        dispatcher.create_asset(1000.into(), 100, 100.into(), array![]);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Move block timestamp past the funding end time
        start_cheat_block_timestamp(dispatcher.contract_address, 1000 + 100 + 1);

        // Attempt to close funding as a different address
        start_cheat_caller_address(dispatcher.contract_address, OTHER_ADDRESS);
        dispatcher.close_funding(0);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('FUNDING_NOT_ENDED',))]
    fn test_close_funding_panic_before_end() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Create an asset
        start_cheat_caller_address(dispatcher.contract_address, CREATOR_ADDRESS);
        start_cheat_block_timestamp(dispatcher.contract_address, 1000);
        dispatcher.create_asset(1000.into(), 100, 100.into(), array![]);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Attempt to close funding before end time
        start_cheat_caller_address(dispatcher.contract_address, CREATOR_ADDRESS);
        start_cheat_block_timestamp(
            dispatcher.contract_address, 1000 + 50,
        ); // Within funding period
        dispatcher.close_funding(0);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);
    }

    #[test]
    fn test_withdraw_creator_success() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Create and fund an asset to meet the goal
        let creator = CREATOR_ADDRESS;
        let investor = INVESTOR_ADDRESS_1;
        let start_time: u64 = 1000;
        let duration: u64 = 100;
        let goal: u256 = 100.into();
        let amount_to_fund: u256 = 100.into();

        start_cheat_caller_address(dispatcher.contract_address, creator);
        start_cheat_block_timestamp(dispatcher.contract_address, start_time);
        dispatcher.create_asset(goal, duration, 100.into(), array![]);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        start_cheat_caller_address(dispatcher.contract_address, investor);
        start_cheat_block_timestamp(dispatcher.contract_address, start_time + 10);
        dispatcher.fund(0, amount_to_fund);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Close the funding (goal met)
        let end_time = start_time + duration;
        start_cheat_caller_address(dispatcher.contract_address, creator);
        start_cheat_block_timestamp(dispatcher.contract_address, end_time + 1);
        dispatcher.close_funding(0);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Setup event spy
        let mut spy = spy_events();

        let token_address = dispatcher.get_token_address();

        let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

        start_cheat_caller_address(token_dispatcher.contract_address, OWNER_ADDRESS);
        token_dispatcher.mint(dispatcher.contract_address, amount_to_fund); // Mint tokens
        stop_cheat_caller_address(token_dispatcher.contract_address);

        // Withdraw as the creator
        start_cheat_caller_address(dispatcher.contract_address, creator);
        dispatcher.withdraw_creator(0);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Verify event emission
        let expected_event = Crowdfunding::Event::CreatorWithdrawal(
            CreatorWithdrawal {
                asset_id: 0, amount: amount_to_fund,
            } // Amount should be total raised
        );
        let expected_events = array![(dispatcher.contract_address, expected_event)];
        spy.assert_emitted(@expected_events);
    }

    #[test]
    #[should_panic(expected: ('GOAL_NOT_REACHED',))]
    fn test_withdraw_creator_panic_goal_not_reached() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Create and fund an asset below the goal
        let creator = CREATOR_ADDRESS;
        let investor = INVESTOR_ADDRESS_1;
        let start_time: u64 = 1000;
        let duration: u64 = 100;
        let goal: u256 = 1000.into(); // High goal
        let amount_to_fund: u256 = 100.into(); // Low funding

        start_cheat_caller_address(dispatcher.contract_address, creator);
        start_cheat_block_timestamp(dispatcher.contract_address, start_time);
        dispatcher.create_asset(goal, duration, 100.into(), array![]);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        start_cheat_caller_address(dispatcher.contract_address, investor);
        start_cheat_block_timestamp(dispatcher.contract_address, start_time + 10);
        dispatcher.fund(0, amount_to_fund);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Close the funding (goal not met)
        let end_time = start_time + duration;
        start_cheat_caller_address(dispatcher.contract_address, creator);
        start_cheat_block_timestamp(dispatcher.contract_address, end_time + 1);
        dispatcher.close_funding(0);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Attempt to withdraw as the creator
        start_cheat_caller_address(dispatcher.contract_address, creator);
        dispatcher.withdraw_creator(0); // Should panic because goal not reached
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_withdraw_investor_success() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Create and fund an asset below the goal
        let creator = CREATOR_ADDRESS;
        let investor = INVESTOR_ADDRESS_1;
        let start_time: u64 = 1000;
        let duration: u64 = 100;
        let goal: u256 = 1000.into(); // High goal
        let amount_to_fund: u256 = 100.into(); // Low funding

        start_cheat_caller_address(dispatcher.contract_address, creator);
        start_cheat_block_timestamp(dispatcher.contract_address, start_time);
        dispatcher.create_asset(goal, duration, 100.into(), array![]);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        start_cheat_caller_address(dispatcher.contract_address, investor);
        start_cheat_block_timestamp(dispatcher.contract_address, start_time + 10);
        dispatcher.fund(0, amount_to_fund);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Close the funding (goal not met)
        let end_time = start_time + duration;
        start_cheat_caller_address(dispatcher.contract_address, creator);
        start_cheat_block_timestamp(dispatcher.contract_address, end_time + 1);
        dispatcher.close_funding(0);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Verify investor data before withdrawal
        let investor_data_before = dispatcher.get_investor_data(0, investor);
        assert!(
            investor_data_before.amount == amount_to_fund,
            "Investment amount incorrect before withdrawal",
        );

        // Setup event spy
        let mut spy = spy_events();

        let token_address = dispatcher.get_token_address();

        let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

        start_cheat_caller_address(token_dispatcher.contract_address, OWNER_ADDRESS);
        token_dispatcher.mint(dispatcher.contract_address, amount_to_fund); // Mint tokens
        stop_cheat_caller_address(token_dispatcher.contract_address);

        // Withdraw as the investor
        start_cheat_caller_address(dispatcher.contract_address, investor);

        dispatcher.withdraw_investor(0);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Verify state update: investor's amount should be reset
        let investor_data_after = dispatcher.get_investor_data(0, investor);
        assert!(
            investor_data_after.amount == 0.into(), "Investment amount not reset after withdrawal",
        );

        // Verify event emission
        let expected_event = Crowdfunding::Event::InvestorWithdrawal(
            InvestorWithdrawal { asset_id: 0, investor: investor, amount: amount_to_fund },
        );
        let expected_events = array![(dispatcher.contract_address, expected_event)];
        spy.assert_emitted(@expected_events);
    }

    #[test]
    #[should_panic(expected: "GOAL_REACHED")]
    fn test_withdraw_investor_panic_goal_reached() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Create and fund an asset to meet the goal
        let creator = CREATOR_ADDRESS;
        let investor = INVESTOR_ADDRESS_1;
        let start_time: u64 = 1000;
        let duration: u64 = 100;
        let goal: u256 = 100.into(); // Low goal
        let amount_to_fund: u256 = 100.into(); // Fund enough

        start_cheat_caller_address(dispatcher.contract_address, creator);
        start_cheat_block_timestamp(dispatcher.contract_address, start_time);
        dispatcher.create_asset(goal, duration, 100.into(), array![]);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        start_cheat_caller_address(dispatcher.contract_address, investor);
        start_cheat_block_timestamp(dispatcher.contract_address, start_time + 10);
        dispatcher.fund(0, amount_to_fund);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Close the funding (goal met)
        let end_time = start_time + duration;
        start_cheat_caller_address(dispatcher.contract_address, creator);
        start_cheat_block_timestamp(dispatcher.contract_address, end_time + 1);
        dispatcher.close_funding(0);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Attempt to withdraw as the investor (should panic)
        start_cheat_caller_address(dispatcher.contract_address, investor);
        dispatcher.withdraw_investor(0); // Should panic because goal was reached
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_set_token_address_success() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Set caller address to the owner
        start_cheat_caller_address(dispatcher.contract_address, OWNER_ADDRESS);

        let new_token_address: ContractAddress = 777.try_into().unwrap();
        dispatcher.set_token_address(new_token_address);

        // Stop mocking
        stop_cheat_caller_address(dispatcher.contract_address);

        // Verify state update using load (since no public getter for token_address)
        let token_address_loaded = dispatcher.get_token_address();
        assert(token_address_loaded == new_token_address, 'Token address not updated');
    }

    #[test]
    #[should_panic(expected: ('NOT_CONTRACT_OWNER',))]
    fn test_set_token_address_panic_not_owner() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Set caller address to a non-owner address
        start_cheat_caller_address(dispatcher.contract_address, OTHER_ADDRESS);

        let new_token_address: ContractAddress = 777.try_into().unwrap();
        dispatcher.set_token_address(new_token_address); // Should panic

        // Stop mocking
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    // Test view functions (getters)
    // These tests primarily verify that the getter functions return the correct data
    // after state-mutating functions have been called and verified.

    #[test]
    fn test_getters() {
        let (dispatcher, _) = deploy_crowdfunding_contract(OWNER_ADDRESS);

        // Test initial asset count
        assert(dispatcher.get_asset_count() == 0, 'Initial asset count incorrect');

        // Create an asset to populate state
        let creator = CREATOR_ADDRESS;
        let investor = INVESTOR_ADDRESS_1;
        let start_time: u64 = 1000;
        let duration: u64 = 86400;
        let goal: u256 = 10000.into();
        let base_price: u256 = 100.into();
        let ipfs_hash_parts = array![123, 456];

        start_cheat_caller_address(dispatcher.contract_address, creator);
        start_cheat_block_timestamp(dispatcher.contract_address, start_time);
        dispatcher.create_asset(goal, duration, base_price, ipfs_hash_parts.clone());
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Test get_asset_count after creating one asset
        assert!(dispatcher.get_asset_count() == 1, "Asset count incorrect after creation");

        // Test get_asset_data
        let asset_data = dispatcher.get_asset_data(0);
        assert!(asset_data.creator == creator, "get_asset_data: Wrong creator");
        assert!(asset_data.goal == goal, "get_asset_data: Wrong goal");
        assert!(asset_data.start_time == start_time, "get_asset_data: Wrong start_time");

        // Test get_asset_ipfs_hash
        let stored_ipfs_hash = dispatcher.get_asset_ipfs_hash(0);
        assert!(
            stored_ipfs_hash.len() == ipfs_hash_parts.len(), "get_asset_ipfs_hash: Length mismatch",
        );
        let mut i: usize = 0;
        while i != ipfs_hash_parts.len() {
            assert!(
                *stored_ipfs_hash.at(i) == *ipfs_hash_parts.at(i),
                "get_asset_ipfs_hash: Part mismatch",
            );
            i += 1;
        }

        // Fund the asset to populate investor data
        let amount_to_fund: u256 = 100.into();
        let fund_time = start_time + 100;
        start_cheat_caller_address(dispatcher.contract_address, investor);
        start_cheat_block_timestamp(dispatcher.contract_address, fund_time);
        dispatcher.fund(0, amount_to_fund);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);

        // Test get_investor_data
        let investor_data = dispatcher.get_investor_data(0, investor);
        assert!(investor_data.amount == amount_to_fund, "get_investor_data: Wrong amount");
        assert!(investor_data.timestamp == fund_time, "get_investor_data: Wrong timestamp");

        // Test get_investor_data for a non-existent investor (should return default/zero values)
        let non_existent_investor_data = dispatcher.get_investor_data(0, OTHER_ADDRESS);
        assert!(
            non_existent_investor_data.amount == 0.into(),
            "get_investor_data: Non-existent investor amount not zero",
        );
        assert!(
            non_existent_investor_data.timestamp == 0,
            "get_investor_data: Non-existent investor timestamp not zero",
        );
    }
}
