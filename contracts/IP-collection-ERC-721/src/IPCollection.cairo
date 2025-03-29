#[cfg(test)]
mod IPCollectionTests {
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use starknet::testing::{set_caller_address, set_contract_address};
    use super::IPCollection;
    use super::IIPCollectionDispatcher;
    use super::IIPCollectionDispatcherTrait;
    use super::IERC20Dispatcher;
    use super::IERC20DispatcherTrait;

    fn setup() -> (IIPCollectionDispatcher, ContractAddress, ContractAddress, ContractAddress) {
        let owner = contract_address_const::<1>();
        let user = contract_address_const::<2>();
        let fee_token = contract_address_const::<3>();

        // Deploy the contract (mock deployment for testing)
        let contract = starknet::deploy_syscall(
            IPCollection::TEST_CLASS_HASH,
            0,
            array![owner.into()].span(),
            false
        ).unwrap().0;

        let dispatcher = IIPCollectionDispatcher { contract_address: contract };
        (dispatcher, owner, user, fee_token)
    }

    #[test]
    #[available_gas(2000000)]
    fn test_create_community() {
        let (dispatcher, _, user, fee_token) = setup();
        set_caller_address(user);

        let community_id = dispatcher.create_community(
            "Test Community",
            "A test community",
            100,
            fee_token,
            user,
            contract_address_const::<4>(),
            1
        );

        assert(community_id == 1, 'Community ID should be 1');
    }

    #[test]
    #[available_gas(3000000)]
    fn test_mint_and_membership() {
        let (dispatcher, _, user, fee_token) = setup();
        set_caller_address(user);

        // Create a community
        let community_id = dispatcher.create_community(
            "Test Community",
            "A test community",
            100,
            fee_token,
            user,
            contract_address_const::<4>(),
            1
        );

        // Mock ERC20 transfer (assume success for testing)
        set_contract_address(fee_token);
        let erc20 = IERC20Dispatcher { contract_address: fee_token };
        // Normally, you'd mock this call, but for simplicity, assume it works

        set_caller_address(user);
        let token_id = dispatcher.mint(community_id);
        assert(token_id == 1, 'Token ID should be 1');

        let is_member = dispatcher.is_member(user, community_id);
        assert(is_member, 'User should be a member');
    }

    #[test]
    #[available_gas(2000000)]
    fn test_list_user_tokens() {
        let (dispatcher, _, user, fee_token) = setup();
        set_caller_address(user);

        let community_id = dispatcher.create_community(
            "Test Community",
            "A test community",
            100,
            fee_token,
            user,
            contract_address_const::<4>(),
            1
        );

        let token_id = dispatcher.mint(community_id);
        let tokens = dispatcher.list_user_tokens(user);
        assert(tokens.len() == 1, 'User should have 1 token');
        assert(*tokens.at(0) == token_id, 'Token ID mismatch');
    }

    #[test]
    #[should_panic(expected: ('Community does not exist',))]
    #[available_gas(2000000)]
    fn test_mint_invalid_community() {
        let (dispatcher, _, user, _) = setup();
        set_caller_address(user);
        dispatcher.mint(999); // Non-existent community
    }
}