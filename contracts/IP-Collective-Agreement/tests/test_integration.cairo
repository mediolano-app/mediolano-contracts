#[test]
fn test_license_execution_with_insufficient_funds() {
    let (
        contract_address,
        _,
        asset_dispatcher,
        _,
        _,
        licensing_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];
    let licensee = USER();

    // Give licensee insufficient funds
    start_cheat_caller_address(erc20_dispatcher.contract_address, SPENDER());
    erc20_dispatcher.transfer(licensee, 50_u256); // Only $0.50
    stop_cheat_caller_address(erc20_dispatcher.contract_address);

    start_cheat_caller_address(erc20_dispatcher.contract_address, licensee);
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20_dispatcher.contract_address);

    // Create license requiring $1.00 fee
    start_cheat_caller_address(contract_address, creator1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            100_u256,
            200_u256,
            0,
            erc20_dispatcher.contract_address,
            create_basic_license_terms(),
            "ipfs://expensive-license",
        );
    stop_cheat_caller_address(contract_address);

    // Try to execute (should fail due to insufficient funds)
    start_cheat_caller_address(contract_address, licensee);

    licensing_dispatcher.execute_license(license_id);

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_rapid_sequential_operations() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        _,
        revenue_dispatcher,
        licensing_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];
    let licensee = USER();
    let erc20 = erc20_dispatcher.contract_address;

    // Rapid sequence: create license, execute, report usage, pay royalties, receive revenue,
    // distribute
    setup_licensee_payment(contract_address, erc20_dispatcher, licensee, 5000_u256);

    // 1. Create license
    start_cheat_caller_address(contract_address, creator1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            100_u256,
            500_u256,
            0,
            erc20,
            create_basic_license_terms(),
            "ipfs://rapid-license",
        );
    stop_cheat_caller_address(contract_address);

    // 2. Execute immediately
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.execute_license(license_id);

    // 3. Report usage immediately
    licensing_dispatcher.report_usage_revenue(license_id, 1000_u256, 50_u256);

    // 4. Pay royalties immediately
    licensing_dispatcher.pay_royalties(license_id, 50_u256); // 5% of 1000
    stop_cheat_caller_address(contract_address);

    // 5. Receive additional revenue
    start_cheat_caller_address(contract_address, SPENDER());
    revenue_dispatcher.receive_revenue(asset_id, erc20, 2000_u256);
    stop_cheat_caller_address(contract_address);

    // 6. Distribute immediately
    start_cheat_caller_address(contract_address, creator1);
    revenue_dispatcher.distribute_all_revenue(asset_id, erc20);
    stop_cheat_caller_address(contract_address);

    // Verify everything worked correctly
    assert!(licensing_dispatcher.is_license_valid(license_id), "License should be valid");
    let royalty_info = licensing_dispatcher.get_royalty_info(license_id);
    assert!(royalty_info.total_royalties_paid == 50, "Royalties should be paid");

    let creator1_pending = revenue_dispatcher.get_pending_revenue(asset_id, creator1, erc20);
    // Should have: 50% of (100 license fee + 50 royalties + 2000 additional) = 50% of 2150 = 1075
    assert!(creator1_pending == 1075, "Creator1 should have correct pending amount");
}
