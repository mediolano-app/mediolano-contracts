// Test module for the IPAssignment contract
#[cfg(test)]
mod tests {
    // Import necessary types from starknet
    use starknet::ContractAddress;

    // Import the contract module itself and relevant structs/events
    use programmable_ip_assignment::IPAssignment::IPAssignment;
    use programmable_ip_assignment::IPAssignment::IPAssignment::{
        IPCreated, IPAssigned, IPOwnershipTransferred
    };

    // Import the dispatcher trait derived from the interface to interact with the deployed contract
    use programmable_ip_assignment::interface::IIPAssignment::{IIPAssignmentDispatcher, IIPAssignmentDispatcherTrait, AssignmentData};

    // Import necessary testing utilities from snforge_std
    use snforge_std::{
        declare, DeclareResultTrait, ContractClassTrait,
        EventSpyAssertionsTrait, spy_events,
        start_cheat_caller_address, stop_cheat_caller_address,
        start_cheat_block_timestamp, stop_cheat_block_timestamp,
    };
    use starknet::contract_address_const;

    fn CONTRACT_OWNER() -> ContractAddress {
        contract_address_const::<'CONTRACT_OWNER'>()
    }
    fn IP_OWNER() -> ContractAddress {
        contract_address_const::<'IP_OWNER'>()
    }
    fn NEW_IP_OWNER() -> ContractAddress {
        contract_address_const::<'NEW_IP_OWNER'>()
    }
    fn ASSIGNEE_1() -> ContractAddress {
        contract_address_const::<'ASSIGNEE_1'>()
    }
    fn ASSIGNEE_2() -> ContractAddress {
        contract_address_const::<'ASSIGNEE_2'>()
    }
    fn OTHER_ADDRESS() -> ContractAddress {
        contract_address_const::<'OTHER_ADDRESS'>()
    }

    const IP_ID_1: felt252 = 'my_first_ip';
    const IP_ID_2: felt252 = 'another_ip';

    // Helper function to deploy the contract with an initial owner
    fn deploy_contract(initial_owner: ContractAddress) -> IIPAssignmentDispatcher {
        // Declare the contract class
        let contract = declare("IPAssignment").unwrap();

        // Serialize constructor arguments: initial_owner
        let mut constructor_args = array![];
        initial_owner.serialize(ref constructor_args);

        // Deploy the contract
        let (contract_address, _err) = contract
            .contract_class()
            .deploy(@constructor_args)
            .unwrap();

        // Create a dispatcher to interact with the contract
        IIPAssignmentDispatcher { contract_address }
    }

    // --- Test Cases ---

    #[test]
    fn test_constructor_sets_owner() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());

        // Verify the contract owner was set correctly
        let contract_owner = dispatcher.get_contract_owner();
        assert(contract_owner == CONTRACT_OWNER(), 'Constructor: Wrong owner');
    }

    #[test]
    fn test_create_ip() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());
        let mut spy = spy_events();

        // Set caller to be the IP owner
        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        let start_timestamp = 1000_u64; // Example timestamp
        start_cheat_block_timestamp(dispatcher.contract_address, start_timestamp);

        // Create the IP
        dispatcher.create_ip(IP_ID_1);

        // Verify IP owner and creation timestamp in storage
        let ip_owner = dispatcher.get_ip_owner(IP_ID_1);
        // Note: cannot directly read ip_created_at via dispatcher as it's not a view function
        // We rely on the event or other means if available, or use load/contract_state_for_testing for internal state checks.
        // For this external test, we primarily check owner and event.
        assert(ip_owner == IP_OWNER(), 'CreateIP: Wrong owner');

        // Verify event emission
        let expected_event = IPAssignment::Event::IPCreated(
            IPCreated {
                ip_id: IP_ID_1,
                owner: IP_OWNER(),
                timestamp: start_timestamp
            },
        );
        let expected_events = array![(dispatcher.contract_address, expected_event)];
        spy.assert_emitted(@expected_events);

        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('IP: Already exists',))]
    fn test_create_ip_already_exists() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1); // Create it first
        dispatcher.create_ip(IP_ID_1); // Try to create again
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_transfer_ip_ownership() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());
        let mut spy = spy_events();

        // Create IP first
        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Transfer ownership as current owner
        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.transfer_ip_ownership(IP_ID_1, NEW_IP_OWNER());

        // Verify new owner
        let new_owner = dispatcher.get_ip_owner(IP_ID_1);
        assert(new_owner == NEW_IP_OWNER(), 'Transfer: Wrong new owner');

        // Verify event emission
        let expected_event = IPAssignment::Event::IPOwnershipTransferred(
            IPOwnershipTransferred {
                ip_id: IP_ID_1,
                previous_owner: IP_OWNER(),
                new_owner: NEW_IP_OWNER()
            },
        );
        let expected_events = array![(dispatcher.contract_address, expected_event)];
        spy.assert_emitted(@expected_events);

        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('IP: Caller not owner',))]
    fn test_transfer_ip_ownership_not_owner() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());

        // Create IP first
        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Try to transfer ownership as someone else
        start_cheat_caller_address(dispatcher.contract_address, OTHER_ADDRESS());
        dispatcher.transfer_ip_ownership(IP_ID_1, NEW_IP_OWNER());
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_assign_ip() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());
        let mut spy = spy_events();

        // Create IP first
        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Define assignment conditions
        let conditions = AssignmentData {
            start_time: 1000,
            end_time: 2000,
            royalty_rate: 500, // 5%
            rights_percentage: 20,
            is_exclusive: false,
        };

        // Assign IP rights as owner
        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_1(), conditions.clone());

        // Verify assignment data in storage via getter
        let stored_conditions = dispatcher.get_assignment_data(IP_ID_1, ASSIGNEE_1());
        assert(stored_conditions.start_time == conditions.start_time, 'AssignIP: Wrong start_time');
        assert(stored_conditions.end_time == conditions.end_time, 'AssignIP: Wrong end_time');
        assert(stored_conditions.royalty_rate == conditions.royalty_rate, 'AssignIP: Wrong royalty_rate');
        assert!(stored_conditions.rights_percentage == conditions.rights_percentage, "AssignIP: Wrong rights_percentage");
        assert(stored_conditions.is_exclusive == conditions.is_exclusive, 'AssignIP: Wrong is_exclusive');

        // Verify event emission
        let expected_event = IPAssignment::Event::IPAssigned(
            IPAssigned {
                ip_id: IP_ID_1,
                assignee: ASSIGNEE_1(),
                conditions: conditions.clone()
            },
        );
        let expected_events = array![(dispatcher.contract_address, expected_event)];
        spy.assert_emitted(@expected_events);

        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('IP: Caller not owner',))]
    fn test_assign_ip_not_owner() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());

        // Create IP first
        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Define assignment conditions
        let conditions = AssignmentData {
            start_time: 1000,
            end_time: 2000,
            royalty_rate: 500,
            rights_percentage: 20,
            is_exclusive: false,
        };

        // Try to assign as someone else
        start_cheat_caller_address(dispatcher.contract_address, OTHER_ADDRESS());
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_1(), conditions.clone());
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('IP: Invalid time range',))]
    fn test_assign_ip_invalid_time_range() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Define invalid assignment conditions (end_time <= start_time)
        let conditions = AssignmentData {
            start_time: 2000,
            end_time: 1000,
            royalty_rate: 500,
            rights_percentage: 20,
            is_exclusive: false,
        };

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_1(), conditions.clone());
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('IP: Rights exceed 100%',))]
    fn test_assign_ip_rights_exceed_100() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Define invalid assignment conditions (rights_percentage > 100)
        let conditions = AssignmentData {
            start_time: 1000,
            end_time: 2000,
            royalty_rate: 500,
            rights_percentage: 101, // Invalid
            is_exclusive: false,
        };

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_1(), conditions.clone());
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('IP: Exclusive exists',))]
    fn test_assign_ip_exclusive_exists() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Assign first exclusive assignment
        let conditions1 = AssignmentData {
            start_time: 1000,
            end_time: 3000,
            royalty_rate: 500,
            rights_percentage: 50,
            is_exclusive: true,
        };
        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_1(), conditions1.clone());
        stop_cheat_caller_address(dispatcher.contract_address);

        // Try to assign second exclusive assignment for the same IP
        let conditions2 = AssignmentData {
            start_time: 1500,
            end_time: 2500,
            royalty_rate: 600,
            rights_percentage: 40,
            is_exclusive: true,
        };
        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_2(), conditions2.clone()); // Should panic
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('IP: Rights exceeded',))]
    fn test_assign_ip_total_rights_exceeded() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Assign first assignment with 60% rights
        let conditions1 = AssignmentData {
            start_time: 1000,
            end_time: 3000,
            royalty_rate: 500,
            rights_percentage: 60,
            is_exclusive: false,
        };
        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_1(), conditions1.clone());
        stop_cheat_caller_address(dispatcher.contract_address);

        // Try to assign second assignment with 50% rights (total 110%)
        let conditions2 = AssignmentData {
            start_time: 1500,
            end_time: 2500,
            royalty_rate: 600,
            rights_percentage: 50, // Exceeds 100% total
            is_exclusive: false,
        };
        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_2(), conditions2.clone()); // Should panic
        stop_cheat_caller_address(dispatcher.contract_address);
    }


    #[test]
    fn test_get_assignment_data() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);
        stop_cheat_caller_address(dispatcher.contract_address);

        let conditions = AssignmentData {
            start_time: 1000,
            end_time: 2000,
            royalty_rate: 500,
            rights_percentage: 20,
            is_exclusive: false,
        };

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_1(), conditions.clone());
        stop_cheat_caller_address(dispatcher.contract_address);

        // Retrieve and verify the stored data
        let retrieved_conditions = dispatcher.get_assignment_data(IP_ID_1, ASSIGNEE_1());
        assert!(retrieved_conditions.start_time == conditions.start_time, "GetAssignment: start_time mismatch");
        assert!(retrieved_conditions.end_time == conditions.end_time, "GetAssignment: end_time mismatch");
        assert!(retrieved_conditions.royalty_rate == conditions.royalty_rate, "GetAssignment: royalty_rate mismatch");
        assert!(retrieved_conditions.rights_percentage == conditions.rights_percentage, "GetAssignment: rights_percentage mismatch");
        assert!(retrieved_conditions.is_exclusive == conditions.is_exclusive, "GetAssignment: is_exclusive mismatch");
    }

    #[test]
    fn test_check_assignment_condition_valid() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);
        stop_cheat_caller_address(dispatcher.contract_address);

        let conditions = AssignmentData {
            start_time: 1000,
            end_time: 2000,
            royalty_rate: 500,
            rights_percentage: 20,
            is_exclusive: false,
        };

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_1(), conditions.clone());
        stop_cheat_caller_address(dispatcher.contract_address);

        // Cheat block timestamp to be within the valid range
        start_cheat_block_timestamp(dispatcher.contract_address, 1500_u64);
        // Cheat caller address to be the assignee (not strictly needed for non-exclusive, but good practice)
        start_cheat_caller_address(dispatcher.contract_address, ASSIGNEE_1());

        // Check condition - should be true
        let is_valid = dispatcher.check_assignment_condition(IP_ID_1, ASSIGNEE_1());
        assert(is_valid == true, 'CheckCondition: Should be valid');

        stop_cheat_block_timestamp(dispatcher.contract_address);
        stop_cheat_caller_address(dispatcher.contract_address);
    }

     #[test]
    fn test_check_assignment_condition_valid_exclusive() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);
        stop_cheat_caller_address(dispatcher.contract_address);

        let conditions = AssignmentData {
            start_time: 1000,
            end_time: 2000,
            royalty_rate: 500,
            rights_percentage: 20,
            is_exclusive: true, // Exclusive
        };

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_1(), conditions.clone());
        stop_cheat_caller_address(dispatcher.contract_address);

        // Cheat block timestamp within range and caller is the exclusive assignee
        start_cheat_block_timestamp(dispatcher.contract_address, 1500_u64);
        start_cheat_caller_address(dispatcher.contract_address, ASSIGNEE_1());

        // Check condition - should be true
        let is_valid = dispatcher.check_assignment_condition(IP_ID_1, ASSIGNEE_1());
        assert!(is_valid == true, "CheckConditionExclusive: Should be valid");

        stop_cheat_block_timestamp(dispatcher.contract_address);
        stop_cheat_caller_address(dispatcher.contract_address);
    }


    #[test]
    fn test_check_assignment_condition_invalid_time() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);
        stop_cheat_caller_address(dispatcher.contract_address);

        let conditions = AssignmentData {
            start_time: 1000,
            end_time: 2000,
            royalty_rate: 500,
            rights_percentage: 20,
            is_exclusive: false,
        };

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_1(), conditions.clone());
        stop_cheat_caller_address(dispatcher.contract_address);

        // Cheat block timestamp to be outside the valid range (before start)
        start_cheat_block_timestamp(dispatcher.contract_address, 500_u64);
        start_cheat_caller_address(dispatcher.contract_address, ASSIGNEE_1());


        // Check condition - should be false
        let is_valid = dispatcher.check_assignment_condition(IP_ID_1, ASSIGNEE_1());
        assert!(is_valid == false, "CheckCondition: Should be invalid (time)");

        stop_cheat_block_timestamp(dispatcher.contract_address);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Cheat block timestamp to be outside the valid range (after end)
        start_cheat_block_timestamp(dispatcher.contract_address, 3000_u64);
        start_cheat_caller_address(dispatcher.contract_address, ASSIGNEE_1());

        // Check condition - should be false
        let is_valid = dispatcher.check_assignment_condition(IP_ID_1, ASSIGNEE_1());
        assert!(is_valid == false, "CheckCondition: Should be invalid (time after)");

        stop_cheat_block_timestamp(dispatcher.contract_address);
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_check_assignment_condition_invalid_exclusivity() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);
        stop_cheat_caller_address(dispatcher.contract_address);

        let conditions = AssignmentData {
            start_time: 1000,
            end_time: 2000,
            royalty_rate: 500,
            rights_percentage: 20,
            is_exclusive: true, // Exclusive
        };

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_1(), conditions.clone());
        stop_cheat_caller_address(dispatcher.contract_address);

        // Cheat block timestamp within range
        start_cheat_block_timestamp(dispatcher.contract_address, 1500_u64);
        // Cheat caller address to be someone other than the exclusive assignee
        start_cheat_caller_address(dispatcher.contract_address, OTHER_ADDRESS());

        // Check condition - should be false due to exclusivity
        let _is_valid = dispatcher.check_assignment_condition(IP_ID_1, ASSIGNEE_1());

        stop_cheat_block_timestamp(dispatcher.contract_address);
        stop_cheat_caller_address(dispatcher.contract_address);
    }


    #[test]
    fn test_receive_royalty_single_assignee() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());
        let mut _spy = spy_events();

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);

        let assignee1_conditions = AssignmentData {
            start_time: 1000,
            end_time: 3000,
            royalty_rate: 500, // 5%
            rights_percentage: 20,
            is_exclusive: false,
        };
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_1(), assignee1_conditions.clone());
        stop_cheat_caller_address(dispatcher.contract_address);

        // Cheat block timestamp to make assignment active
        start_cheat_block_timestamp(dispatcher.contract_address, 1500_u64);

        let royalty_amount = 10000_u128; // Total royalty received
        let expected_assignee1_share = royalty_amount * 500 / 10000; // 5% of 10000 = 500
        let _expected_owner_share = royalty_amount - expected_assignee1_share; // 9500

        // Receive royalty
        start_cheat_caller_address(dispatcher.contract_address, OTHER_ADDRESS()); // Caller doesn't matter for distribution logic
        dispatcher.receive_royalty(IP_ID_1, royalty_amount);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);
    }

    #[test]
    fn test_receive_royalty_multiple_assignees() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());
        let mut _spy = spy_events();

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);

        let assignee1_conditions = AssignmentData {
            start_time: 1000,
            end_time: 3000,
            royalty_rate: 500, // 5%
            rights_percentage: 20,
            is_exclusive: false,
        };
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_1(), assignee1_conditions.clone());

        let assignee2_conditions = AssignmentData {
            start_time: 1000,
            end_time: 3000,
            royalty_rate: 1000, // 10%
            rights_percentage: 30,
            is_exclusive: false,
        };
        dispatcher.assign_ip(IP_ID_1, ASSIGNEE_2(), assignee2_conditions.clone());

        stop_cheat_caller_address(dispatcher.contract_address);

        // Cheat block timestamp to make assignments active
        start_cheat_block_timestamp(dispatcher.contract_address, 1500_u64);

        let royalty_amount = 20000_u128; // Total royalty received
        let expected_assignee1_share = royalty_amount * 500 / 10000; // 5% of 20000 = 1000
        let expected_assignee2_share = royalty_amount * 1000 / 10000; // 10% of 20000 = 2000
        let total_assigned_royalty = expected_assignee1_share + expected_assignee2_share; // 1000 + 2000 = 3000
        let _expected_owner_share = royalty_amount - total_assigned_royalty; // 20000 - 3000 = 17000

        // Receive royalty
        start_cheat_caller_address(dispatcher.contract_address, OTHER_ADDRESS());
        dispatcher.receive_royalty(IP_ID_1, royalty_amount);
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('IP: No balance',))]
    fn test_withdraw_royalties_no_balance() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());

        // Try to withdraw royalties for an IP/assignee with no balance
        start_cheat_caller_address(dispatcher.contract_address, ASSIGNEE_1());
        dispatcher.withdraw_royalties(IP_ID_1); // Should panic
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_get_contract_owner() {
        let dispatcher = deploy_contract(CONTRACT_OWNER());
        let owner = dispatcher.get_contract_owner();
        assert(owner == CONTRACT_OWNER(), 'GetContractOwner: Wrong owner');
    }

    #[test]
    fn test_get_ip_owner() {
         let dispatcher = deploy_contract(CONTRACT_OWNER());

        start_cheat_caller_address(dispatcher.contract_address, IP_OWNER());
        dispatcher.create_ip(IP_ID_1);
        stop_cheat_caller_address(dispatcher.contract_address);

        let owner = dispatcher.get_ip_owner(IP_ID_1);
        assert(owner == IP_OWNER(), 'GetIPOwner: Wrong owner');
    }
}
