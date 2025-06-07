#[cfg(test)]
mod tests {
    use ip_drop::interface::{ClaimConditions, IIPDropDispatcher, IIPDropDispatcherTrait};
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
        start_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_block_timestamp,
        stop_cheat_caller_address,
    };
    use starknet::{ContractAddress, contract_address_const};

    fn NAME() -> ByteArray {
        let name: ByteArray = "IP Drop Collection";
        name
    }

    fn SYMBOL() -> ByteArray {
        let symbol: ByteArray = "IPDC";
        symbol
    }

    fn BASE_URI() -> ByteArray {
        let base_uri: ByteArray = "https://api.example.com/metadata/";
        base_uri
    }

    fn setup_contract() -> (IIPDropDispatcher, ContractAddress, ContractAddress) {
        let owner = contract_address_const::<0x123>();
        let user = contract_address_const::<0x456>();

        let conditions = ClaimConditions {
            start_time: 1000,
            end_time: 2000,
            price: 0,
            max_quantity_per_wallet: 5,
            payment_token: contract_address_const::<0>(),
        };

        let contract = declare("IPDrop").unwrap().contract_class();
        let max_supply: u256 = 1000;
        let allowlist_enabled: bool = true;

        let mut constructor_calldata: Array<felt252> = array![];

        NAME().serialize(ref constructor_calldata);
        SYMBOL().serialize(ref constructor_calldata);
        BASE_URI().serialize(ref constructor_calldata);
        max_supply.serialize(ref constructor_calldata);
        owner.serialize(ref constructor_calldata);
        conditions.serialize(ref constructor_calldata);
        allowlist_enabled.serialize(ref constructor_calldata);

        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        let dispatcher = IIPDropDispatcher { contract_address };

        (dispatcher, owner, user)
    }

    #[test]
    fn test_deployment_and_initialization() {
        let (contract, _, _) = setup_contract();

        // Test basic contract info
        assert(contract.name() == NAME(), 'Wrong name');
        assert(contract.symbol() == SYMBOL(), 'Wrong symbol');
        assert(contract.max_supply() == 1000, 'Wrong max supply');
        assert(contract.total_supply() == 0, 'Wrong initial supply');
        assert(contract.is_allowlist_enabled(), 'Allowlist should be enabled');

        // Test claim conditions
        let conditions = contract.get_claim_conditions();
        assert(conditions.start_time == 1000, 'Wrong start time');
        assert(conditions.end_time == 2000, 'Wrong end time');
        assert(conditions.price == 0, 'Wrong price');
        assert(conditions.max_quantity_per_wallet == 5, 'Wrong max per wallet');
    }

    #[test]
    fn test_allowlist_management() {
        let (contract, owner, user) = setup_contract();

        // Initially user should not be allowlisted
        assert(!contract.is_allowlisted(user), 'User should not be allowlisted');

        start_cheat_caller_address(contract.contract_address, owner);
        // Add user to allowlist
        contract.add_to_allowlist(user);
        assert(contract.is_allowlisted(user), 'User should be allowlisted');

        // Remove user from allowlist
        contract.remove_from_allowlist(user);
        assert!(!contract.is_allowlisted(user), "User should not be allowlisted after removal");
    }

    #[test]
    fn test_batch_allowlist_operations() {
        let (contract, owner, _) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);

        let user1 = contract_address_const::<0x111>();
        let user2 = contract_address_const::<0x222>();
        let user3 = contract_address_const::<0x333>();

        let batch_addresses = array![user1, user2, user3];

        // Add batch to allowlist
        contract.add_batch_to_allowlist(batch_addresses.span());

        // Verify all users are allowlisted
        assert(contract.is_allowlisted(user1), 'User1 should be allowlisted');
        assert(contract.is_allowlisted(user2), 'User2 should be allowlisted');
        assert(contract.is_allowlisted(user3), 'User3 should be allowlisted');
    }

    #[test]
    fn test_successful_free_claim() {
        let (contract, owner, user) = setup_contract();

        // Add user to allowlist
        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        // Set time within claim window
        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);

        // Claim 3 NFTs
        contract.claim(3);

        // Verify results
        assert(contract.total_supply() == 3, 'Wrong total supply');
        assert(contract.balance_of(user) == 3, 'Wrong user balance');
        assert(contract.claimed_by_wallet(user) == 3, 'Wrong claimed amount');
        assert(contract.owner_of(1) == user, 'Wrong owner of token 1');
        assert(contract.owner_of(2) == user, 'Wrong owner of token 2');
        assert(contract.owner_of(3) == user, 'Wrong owner of token 3');
    }

    #[test]
    fn test_claim_with_payment_setup() {
        let (contract, owner, user) = setup_contract();

        // Set up paid claim conditions
        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        let erc20_token = contract_address_const::<0x999>();
        let paid_conditions = ClaimConditions {
            start_time: 1000,
            end_time: 2000,
            price: 1000000000000000000,
            max_quantity_per_wallet: 5,
            payment_token: erc20_token,
        };
        contract.set_claim_conditions(paid_conditions);

        // Verify conditions were set correctly
        let conditions = contract.get_claim_conditions();
        assert(conditions.price == 1000000000000000000, 'Wrong price set');
        assert(conditions.payment_token == erc20_token, 'Wrong payment token');
    }

    #[test]
    #[should_panic(expected: ('Not on allowlist',))]
    fn test_claim_fails_when_not_allowlisted() {
        let (contract, _, user) = setup_contract();

        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);

        // User not on allowlist should fail
        contract.claim(1);
    }

    #[test]
    #[should_panic(expected: ('Claim not started',))]
    fn test_claim_fails_before_start_time() {
        let (contract, owner, user) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        start_cheat_block_timestamp(contract.contract_address, 500); // Before start time (1000)
        start_cheat_caller_address(contract.contract_address, user);

        contract.claim(1);
    }

    #[test]
    #[should_panic(expected: ('Claim ended',))]
    fn test_claim_fails_after_end_time() {
        let (contract, owner, user) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        start_cheat_block_timestamp(contract.contract_address, 2500); // After end time (2000)
        start_cheat_caller_address(contract.contract_address, user);

        contract.claim(1);
    }

    #[test]
    #[should_panic(expected: ('Exceeds wallet limit',))]
    fn test_claim_fails_exceeding_wallet_limit() {
        let (contract, owner, user) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);

        // Try to claim more than wallet limit (5)
        contract.claim(6);
    }

    #[test]
    fn test_multiple_claims_within_limit() {
        let (contract, owner, user) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);

        // First claim
        contract.claim(2);
        assert(contract.balance_of(user) == 2, 'Wrong balance after first claim');
        assert(contract.claimed_by_wallet(user) == 2, 'Wrong claimed count after first');

        // Second claim
        contract.claim(2);
        assert!(contract.balance_of(user) == 4, "Wrong balance after second claim");
        assert!(contract.claimed_by_wallet(user) == 4, "Wrong claimed count after second");

        // Third claim (1 more to reach limit of 5)
        contract.claim(1);
        assert(contract.balance_of(user) == 5, 'Wrong balance after third claim');
        assert(contract.claimed_by_wallet(user) == 5, 'Wrong claimed count after third');
    }

    #[test]
    #[should_panic(expected: ('Exceeds wallet limit',))]
    fn test_cumulative_claims_exceed_limit() {
        let (contract, owner, user) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);

        // Claim up to limit
        contract.claim(3);
        contract.claim(2); // Total: 5 (at limit)

        contract.claim(1); // Would make total 6, exceeding limit of 5
    }

    #[test]
    #[should_panic(expected: ('Exceeds max supply',))]
    fn test_claim_fails_exceeding_max_supply() {
        let (contract, owner, user) = setup_contract();

        // Set conditions with high wallet limit to test max supply
        start_cheat_caller_address(contract.contract_address, owner);
        let conditions = ClaimConditions {
            start_time: 1000,
            end_time: 2000,
            price: 0,
            max_quantity_per_wallet: 2000, // High limit to test max supply
            payment_token: 0.try_into().unwrap(),
        };
        contract.set_claim_conditions(conditions);
        contract.add_to_allowlist(user);

        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);

        // Try to claim more than max supply
        contract.claim(1001); // Exceeds max supply of 1000
    }

    #[test]
    fn test_public_mint_when_allowlist_disabled() {
        let (contract, owner, user) = setup_contract();

        // Disable allowlist
        start_cheat_caller_address(contract.contract_address, owner);
        contract.set_allowlist_enabled(false);

        assert(!contract.is_allowlist_enabled(), 'Allowlist should be disabled');

        // User should be able to claim without being on allowlist
        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);

        start_cheat_caller_address(contract.contract_address, user);
        contract.claim(2);
        assert(contract.balance_of(user) == 2, 'Public mint failed');
    }

    #[test]
    fn test_token_uri_generation() {
        let (contract, owner, user) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);

        contract.claim(1);

        let uri = contract.token_uri(1);
        assert(uri == "https://api.example.com/metadata/1", 'Wrong token URI');
    }

    #[test]
    fn test_base_uri_update() {
        let (contract, owner, user) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        // Mint a token first
        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);
        contract.claim(1);

        // Update base URI
        start_cheat_caller_address(contract.contract_address, owner);
        contract.set_base_uri("https://newapi.com/nft/");

        // Check updated URI
        let new_uri = contract.token_uri(1);
        assert(new_uri == "https://newapi.com/nft/1", 'Base URI not updated');
    }

    #[test]
    fn test_transfer_functionality() {
        let (contract, owner, user) = setup_contract();
        let receiver = contract_address_const::<0x789>();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);

        // Claim tokens
        contract.claim(2);
        assert(contract.owner_of(1) == user, 'Wrong initial owner token 1');
        assert(contract.owner_of(2) == user, 'Wrong initial owner token 2');
        assert(contract.balance_of(user) == 2, 'Wrong initial balance');

        // Transfer token 1
        contract.transfer_from(user, receiver, 1);

        // Verify ownership after transfer
        assert(contract.owner_of(1) == receiver, 'Transfer failed');
        assert!(contract.owner_of(2) == user, "Token 2 owner changed incorrectly");

        // Verify balances after transfer
        assert!(contract.balance_of(user) == 1, "User balance wrong after transfer");
        assert!(contract.balance_of(receiver) == 1, "Receiver balance wrong after transfer");

        // Transfer token 2 as well to test further
        contract.transfer_from(user, receiver, 2);

        // Verify final state
        assert(contract.owner_of(1) == receiver, 'Final token 1 owner wrong');
        assert(contract.owner_of(2) == receiver, 'Final token 2 owner wrong');
        assert(contract.balance_of(user) == 0, 'Final user balance wrong');
        assert(contract.balance_of(receiver) == 2, 'Final receiver balance wrong');
    }

    #[test]
    fn test_erc721a_ownership_resolution_after_transfers() {
        let (contract, owner, user) = setup_contract();
        let user2 = contract_address_const::<0x777>();
        let user3 = contract_address_const::<0x888>();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);

        // Claim a batch of 5 tokens
        contract.claim(5);

        // Verify initial ownership (all should belong to user)
        assert(contract.owner_of(1) == user, 'Initial token 1 owner wrong');
        assert(contract.owner_of(2) == user, 'Initial token 2 owner wrong');
        assert(contract.owner_of(3) == user, 'Initial token 3 owner wrong');
        assert(contract.owner_of(4) == user, 'Initial token 4 owner wrong');
        assert(contract.owner_of(5) == user, 'Initial token 5 owner wrong');

        // Transfer token 1 (first in batch)
        contract.transfer_from(user, user2, 1);

        // Verify that other tokens in batch still belong to original owner
        assert(contract.owner_of(1) == user2, 'Token 1 transfer failed');
        assert!(contract.owner_of(2) == user, "Token 2 owner changed after token 1 transfer");
        assert!(contract.owner_of(3) == user, "Token 3 owner changed after token 1 transfer");
        assert!(contract.owner_of(4) == user, "Token 4 owner changed after token 1 transfer");
        assert!(contract.owner_of(5) == user, "Token 5 owner changed after token 1 transfer");

        // Transfer token 3 (middle of batch)
        contract.transfer_from(user, user3, 3);

        // Verify ownership resolution still works correctly
        assert(contract.owner_of(1) == user2, 'Token 1 owner changed');
        assert!(contract.owner_of(2) == user, "Token 2 owner changed after token 3 transfer");
        assert(contract.owner_of(3) == user3, 'Token 3 transfer failed');
        assert!(contract.owner_of(4) == user, "Token 4 owner changed after token 3 transfer");
        assert!(contract.owner_of(5) == user, "Token 5 owner changed after token 3 transfer");

        // Verify balances
        assert!(contract.balance_of(user) == 3, "User balance wrong after transfers");
        assert(contract.balance_of(user2) == 1, 'User2 balance wrong');
        assert(contract.balance_of(user3) == 1, 'User3 balance wrong');
    }

    #[test]
    fn test_multiple_batch_transfers() {
        let (contract, owner, _) = setup_contract();
        let user1 = contract_address_const::<0x111>();
        let user2 = contract_address_const::<0x222>();
        let receiver = contract_address_const::<0x999>();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user1);
        contract.add_to_allowlist(user2);

        start_cheat_block_timestamp(contract.contract_address, 1500);

        // User1 claims first batch (tokens 1-3)
        start_cheat_caller_address(contract.contract_address, user1);
        contract.claim(3);

        // User2 claims second batch (tokens 4-6)
        start_cheat_caller_address(contract.contract_address, user2);
        contract.claim(3);

        // Verify initial state
        assert(contract.owner_of(1) == user1, 'Batch 1 token 1 wrong owner');
        assert(contract.owner_of(3) == user1, 'Batch 1 token 3 wrong owner');
        assert(contract.owner_of(4) == user2, 'Batch 2 token 4 wrong owner');
        assert(contract.owner_of(6) == user2, 'Batch 2 token 6 wrong owner');

        // Transfer from first batch
        start_cheat_caller_address(contract.contract_address, user1);
        contract.transfer_from(user1, receiver, 2);

        // Transfer from second batch
        start_cheat_caller_address(contract.contract_address, user2);
        contract.transfer_from(user2, receiver, 5);

        // Verify that transfers don't affect other tokens in their respective batches
        assert!(contract.owner_of(1) == user1, "Batch 1 token 1 affected by token 2 transfer");
        assert(contract.owner_of(2) == receiver, 'Token 2 transfer failed');
        assert!(contract.owner_of(3) == user1, "Batch 1 token 3 affected by token 2 transfer");
        assert!(contract.owner_of(4) == user2, "Batch 2 token 4 affected by token 5 transfer");
        assert(contract.owner_of(5) == receiver, 'Token 5 transfer failed');
        assert!(contract.owner_of(6) == user2, "Batch 2 token 6 affected by token 5 transfer");

        // Verify balances
        assert(contract.balance_of(user1) == 2, 'User1 balance wrong');
        assert(contract.balance_of(user2) == 2, 'User2 balance wrong');
        assert(contract.balance_of(receiver) == 2, 'Receiver balance wrong');
    }

    #[test]
    fn test_approval_and_transfer() {
        let (contract, owner, user) = setup_contract();
        let approved = contract_address_const::<0x789>();
        let receiver = contract_address_const::<0xabc>();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);

        // Claim token
        contract.claim(1);

        // Approve
        contract.approve(approved, 1);
        assert(contract.get_approved(1) == approved, 'Approval failed');

        // Approved address transfers
        start_cheat_caller_address(contract.contract_address, approved);

        contract.transfer_from(user, receiver, 1);
        assert(contract.owner_of(1) == receiver, 'Approved transfer failed');
    }

    #[test]
    fn test_approval_for_all() {
        let (contract, owner, user) = setup_contract();
        let operator = contract_address_const::<0x789>();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        start_cheat_caller_address(contract.contract_address, user);

        // Set approval for all
        contract.set_approval_for_all(operator, true);
        assert(contract.is_approved_for_all(user, operator), 'Approval for all failed');

        // Remove approval
        contract.set_approval_for_all(operator, false);
        assert(!contract.is_approved_for_all(user, operator), 'Remove approval failed');
    }

    #[test]
    fn test_claim_conditions_update() {
        let (contract, owner, _) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);

        let new_conditions = ClaimConditions {
            start_time: 3000,
            end_time: 4000,
            price: 500000000000000000,
            max_quantity_per_wallet: 10,
            payment_token: contract_address_const::<0x888>(),
        };

        contract.set_claim_conditions(new_conditions);

        let updated = contract.get_claim_conditions();
        assert(updated.start_time == 3000, 'Start time not updated');
        assert(updated.end_time == 4000, 'End time not updated');
        assert(updated.price == 500000000000000000, 'Price not updated');
        assert(updated.max_quantity_per_wallet == 10, 'Max quantity not updated');
        assert(
            updated.payment_token == contract_address_const::<0x888>(), 'Payment token not updated',
        );
    }

    #[test]
    fn test_multiple_users_claiming() {
        let (contract, owner, _) = setup_contract();

        let user1 = contract_address_const::<0x111>();
        let user2 = contract_address_const::<0x222>();
        let user3 = contract_address_const::<0x333>();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user1);
        contract.add_to_allowlist(user2);
        contract.add_to_allowlist(user3);

        start_cheat_block_timestamp(contract.contract_address, 1500);

        // User1 claims 2 tokens
        start_cheat_caller_address(contract.contract_address, user1);
        contract.claim(2);

        // User2 claims 3 tokens
        start_cheat_caller_address(contract.contract_address, user2);
        contract.claim(3);

        // User3 claims 1 token
        start_cheat_caller_address(contract.contract_address, user3);
        contract.claim(1);

        // Verify individual balances
        assert(contract.balance_of(user1) == 2, 'User1 balance wrong');
        assert(contract.balance_of(user2) == 3, 'User2 balance wrong');
        assert(contract.balance_of(user3) == 1, 'User3 balance wrong');
        assert(contract.total_supply() == 6, 'Total supply wrong');

        // Verify token ownership
        assert(contract.owner_of(1) == user1, 'Token 1 wrong owner');
        assert(contract.owner_of(2) == user1, 'Token 2 wrong owner');
        assert(contract.owner_of(3) == user2, 'Token 3 wrong owner');
        assert(contract.owner_of(4) == user2, 'Token 4 wrong owner');
        assert(contract.owner_of(5) == user2, 'Token 5 wrong owner');
        assert(contract.owner_of(6) == user3, 'Token 6 wrong owner');
    }

    #[test]
    fn test_edge_case_timing() {
        let (contract, owner, user) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        start_cheat_caller_address(contract.contract_address, user);

        // Test claiming exactly at start time
        start_cheat_block_timestamp(contract.contract_address, 1000);
        contract.claim(1);

        // Test claiming exactly at end time
        start_cheat_block_timestamp(contract.contract_address, 2000);
        contract.claim(1);

        assert(contract.balance_of(user) == 2, 'Edge case timing failed');
    }

    #[test]
    #[should_panic(expected: ('Not owner nor approved',))]
    fn test_unauthorized_approval() {
        let (contract, owner, user) = setup_contract();
        let unauthorized = contract_address_const::<0x789>();
        let spender = contract_address_const::<0xabc>();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);
        contract.claim(1);

        // Unauthorized user tries to approve
        start_cheat_caller_address(contract.contract_address, unauthorized);
        contract.approve(spender, 1);
    }

    #[test]
    #[should_panic(expected: ('Not authorized',))]
    fn test_unauthorized_transfer() {
        let (contract, owner, user) = setup_contract();
        let unauthorized = contract_address_const::<0x789>();
        let receiver = contract_address_const::<0xabc>();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);
        contract.claim(1);

        // Unauthorized user tries to transfer
        start_cheat_caller_address(contract.contract_address, unauthorized);
        contract.transfer_from(user, receiver, 1);
    }

    #[test]
    #[should_panic(expected: ('Payment required',))]
    fn test_paid_mint_using_wrong_function() {
        let (contract, owner, user) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        // Set paid conditions
        let paid_conditions = ClaimConditions {
            start_time: 1000,
            end_time: 2000,
            price: 1000000000000000000,
            max_quantity_per_wallet: 5,
            payment_token: contract_address_const::<0>(),
        };
        contract.set_claim_conditions(paid_conditions);

        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);

        // Should fail because price > 0 but using free claim function
        contract.claim(1);
    }

    #[test]
    #[should_panic(expected: ('No payment required - use claim',))]
    fn test_free_mint_using_payment_function() {
        let (contract, owner, user) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);

        // Should fail because price = 0 but using payment function
        contract.claim_with_payment(1);
    }

    #[test]
    fn test_large_batch_minting_efficiency() {
        let (contract, owner, user) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        // Set higher wallet limit for testing
        let conditions = ClaimConditions {
            start_time: 1000,
            end_time: 2000,
            price: 0,
            max_quantity_per_wallet: 50,
            payment_token: contract_address_const::<0>(),
        };
        contract.set_claim_conditions(conditions);

        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);

        // Large batch claim
        contract.claim(20);

        assert(contract.balance_of(user) == 20, 'Large batch failed');
        assert(contract.total_supply() == 20, 'Large batch supply wrong');

        // Verify ownership of random tokens in the batch
        assert(contract.owner_of(1) == user, 'First token wrong owner');
        assert(contract.owner_of(10) == user, 'Middle token wrong owner');
        assert(contract.owner_of(20) == user, 'Last token wrong owner');
    }

    #[test]
    #[should_panic(expected: ('Invalid address',))]
    fn test_add_zero_address_to_allowlist() {
        let (contract, owner, _) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(contract_address_const::<0>());
    }

    #[test]
    #[should_panic(expected: ('Invalid address in batch',))]
    fn test_batch_add_with_zero_address() {
        let (contract, owner, _) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);

        let user1 = contract_address_const::<0x111>();
        let zero_address = contract_address_const::<0>();
        let user2 = contract_address_const::<0x222>();

        let batch_with_zero = array![user1, zero_address, user2];
        contract.add_batch_to_allowlist(batch_with_zero.span());
    }

    #[test]
    #[should_panic(expected: ('Invalid time range',))]
    fn test_invalid_claim_conditions_time_range() {
        let (contract, owner, _) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);

        let invalid_conditions = ClaimConditions {
            start_time: 2000,
            end_time: 1000, // End before start
            price: 0,
            max_quantity_per_wallet: 5,
            payment_token: contract_address_const::<0>(),
        };

        contract.set_claim_conditions(invalid_conditions);
    }

    #[test]
    #[should_panic(expected: ('Invalid max quantity',))]
    fn test_invalid_claim_conditions_zero_quantity() {
        let (contract, owner, _) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);

        let invalid_conditions = ClaimConditions {
            start_time: 1000,
            end_time: 2000,
            price: 0,
            max_quantity_per_wallet: 0, // Invalid zero quantity
            payment_token: contract_address_const::<0>(),
        };

        contract.set_claim_conditions(invalid_conditions);
    }

    #[test]
    #[should_panic(expected: ('Invalid quantity',))]
    fn test_claim_zero_quantity() {
        let (contract, owner, user) = setup_contract();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user);

        start_cheat_block_timestamp(contract.contract_address, 1500);
        start_cheat_caller_address(contract.contract_address, user);

        contract.claim(0);
    }

    #[test]
    #[should_panic(expected: ('Token does not exist',))]
    fn test_token_uri_nonexistent_token() {
        let (contract, _, _) = setup_contract();

        contract.token_uri(999);
    }

    #[test]
    #[should_panic(expected: ('Token does not exist',))]
    fn test_get_approved_nonexistent_token() {
        let (contract, _, _) = setup_contract();

        contract.get_approved(999);
    }

    #[test]
    #[should_panic(expected: ('Token does not exist',))]
    fn test_owner_of_nonexistent_token() {
        let (contract, _, _) = setup_contract();

        contract.owner_of(999);
    }

    #[test]
    fn test_erc721a_gas_optimization_verification() {
        let (contract, owner, _) = setup_contract();

        let user1 = contract_address_const::<0x111>();
        let user2 = contract_address_const::<0x222>();

        start_cheat_caller_address(contract.contract_address, owner);
        contract.add_to_allowlist(user1);
        contract.add_to_allowlist(user2);

        start_cheat_block_timestamp(contract.contract_address, 1500);

        // User1 claims a batch
        start_cheat_caller_address(contract.contract_address, user1);
        contract.claim(3);

        // User2 claims a single token
        start_cheat_caller_address(contract.contract_address, user2);
        contract.claim(1);

        // Tokens 1-3 should belong to user1
        assert(contract.owner_of(1) == user1, 'Token 1 wrong owner');
        assert(contract.owner_of(2) == user1, 'Token 2 wrong owner');
        assert(contract.owner_of(3) == user1, 'Token 3 wrong owner');

        // Token 4 should belong to user2
        assert(contract.owner_of(4) == user2, 'Token 4 wrong owner');
    }
}
