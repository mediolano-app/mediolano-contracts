use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp,
    stop_cheat_block_timestamp,
};
use ip_collective_agreement::types::{LicenseInfo, LicenseTerms, LicenseType, UsageRights};
use ip_collective_agreement::interface::{
    IOwnershipRegistryDispatcher, IOwnershipRegistryDispatcherTrait, IIPAssetManagerDispatcher,
    IIPAssetManagerDispatcherTrait, IRevenueDistributionDispatcher,
    IRevenueDistributionDispatcherTrait, ILicenseManagerDispatcher, ILicenseManagerDispatcherTrait,
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use core::num::traits::Bounded;

use super::test_utils::{
    USER, SPENDER, MARKETPLACE, setup, register_test_asset, create_basic_license_terms,
    deploy_erc1155_receiver, create_proposed_license, setup_licensee_payment,
    create_and_execute_license, create_and_execute_license_with_terms,
};

#[test]
fn test_create_license_offer_simple() {
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

    // Register test asset
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];
    let licensee = USER();
    let erc20 = erc20_dispatcher.contract_address;

    // Create simple license offer (should auto-approve)
    let license_terms = create_basic_license_terms();

    start_cheat_caller_address(contract_address, creator1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            500_u256, // Small fee
            250_u256, // 2.5% royalty
            0, // Perpetual
            erc20,
            license_terms,
            "ipfs://license-offer",
        );
    stop_cheat_caller_address(contract_address);

    assert!(license_id == 1, "License ID should be 1");

    // Verify license offer was created correctly
    let license_info = licensing_dispatcher.get_license_info(license_id);
    assert!(license_info.license_id == license_id, "Wrong license ID");
    assert!(license_info.asset_id == asset_id, "Wrong asset ID");
    assert!(license_info.licensee == licensee, "Wrong licensee");
    assert!(license_info.licensor == creator1, "Wrong licensor");
    assert!(!license_info.requires_approval, "Simple license should not require approval");
    assert!(license_info.is_approved, "Simple license should be auto-approved");
    assert!(!license_info.is_active, "License should not be active until executed");

    // Verify license is available for execution
    let available_licenses = licensing_dispatcher.get_available_licenses(asset_id);
    assert!(available_licenses.len() == 1, "Should have 1 available license");
    assert!(*available_licenses[0] == license_id, "Available license should match created license");
}

#[test]
fn test_create_exclusive_license_requires_approval() {
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
    let erc20 = erc20_dispatcher.contract_address;

    let license_terms = create_basic_license_terms();

    start_cheat_caller_address(contract_address, creator1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::Exclusive.into(),
            UsageRights::All.into(),
            'GLOBAL',
            100_u256,
            500_u256, // 5% royalty
            31536000, // 1 year
            erc20,
            license_terms,
            "ipfs://exclusive-license-offer",
        );
    stop_cheat_caller_address(contract_address);

    // Verify license requires approval
    let license_info = licensing_dispatcher.get_license_info(license_id);
    assert!(license_info.requires_approval, "Exclusive license should require approval");
    assert!(!license_info.is_approved, "Should not be auto-approved");
    assert!(!license_info.is_active, "Should not be active");

    // Should not be in available licenses until approved
    let available_licenses = licensing_dispatcher.get_available_licenses(asset_id);
    assert!(available_licenses.len() == 0, "Should have no available licenses until approved");
}

#[test]
fn test_approve_and_execute_license_flow() {
    let (
        contract_address,
        _,
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
    let creator2 = *creators[1];
    let licensee = USER();
    let erc20 = erc20_dispatcher.contract_address;

    // Fund licensee for license fee
    start_cheat_caller_address(erc20, SPENDER());
    erc20_dispatcher.transfer(licensee, 15000_u256);
    stop_cheat_caller_address(erc20);

    start_cheat_caller_address(erc20, licensee);
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20);

    let license_terms = create_basic_license_terms();

    // Create exclusive license offer
    start_cheat_caller_address(contract_address, creator1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::Exclusive.into(),
            UsageRights::All.into(),
            'US',
            100_u256,
            500_u256,
            31536000,
            erc20,
            license_terms,
            "ipfs://exclusive-license",
        );
    stop_cheat_caller_address(contract_address);

    // Approve license as asset owner
    start_cheat_caller_address(contract_address, creator2);
    let approval_success = licensing_dispatcher.approve_license(license_id, true);
    stop_cheat_caller_address(contract_address);

    assert!(approval_success, "License approval should succeed");

    // Verify license is now approved but still not active
    let license_info = licensing_dispatcher.get_license_info(license_id);
    assert!(license_info.is_approved, "License should be approved");
    assert!(!license_info.is_active, "License should not be active until executed");

    // Verify license is now available for execution
    let available_licenses = licensing_dispatcher.get_available_licenses(asset_id);
    assert!(available_licenses.len() == 1, "Should have 1 available license after approval");

    // Execute license as licensee
    start_cheat_caller_address(contract_address, licensee);
    let execution_success = licensing_dispatcher.execute_license(license_id);
    stop_cheat_caller_address(contract_address);

    assert!(execution_success, "License execution should succeed");

    // Verify license is now active
    let executed_license = licensing_dispatcher.get_license_info(license_id);
    assert!(executed_license.is_active, "License should be active after execution");
    assert!(licensing_dispatcher.is_license_valid(license_id), "License should be valid");

    // Verify license fee was distributed to owners
    let creator1_pending = revenue_dispatcher.get_pending_revenue(asset_id, creator1, erc20);
    let creator2_pending = revenue_dispatcher.get_pending_revenue(asset_id, creator2, erc20);

    assert!(creator1_pending == 50, "Creator1 should receive 50% of license fee"); // 50% of 100
    assert!(creator2_pending == 30, "Creator2 should receive 30% of license fee"); // 30% of 100

    // Verify licensee mappings were created during execution
    let licensee_licenses = licensing_dispatcher.get_licensee_licenses(licensee);
    assert!(licensee_licenses.len() == 1, "Licensee should have 1 license");
    assert!(*licensee_licenses[0] == license_id, "Licensee license should match");
}

#[test]
fn test_execute_license_with_usage_and_royalties() {
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
    let erc20 = erc20_dispatcher.contract_address;

    // Fund licensee
    start_cheat_caller_address(erc20, SPENDER());
    erc20_dispatcher.transfer(licensee, 20000_u256);
    stop_cheat_caller_address(erc20);

    start_cheat_caller_address(erc20, licensee);
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20);

    let license_terms = create_basic_license_terms();

    // Create and execute license
    start_cheat_caller_address(contract_address, creator1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            500_u256,
            1000_u256, // 10% royalty
            0,
            erc20,
            license_terms,
            "ipfs://commercial-license",
        );
    stop_cheat_caller_address(contract_address);

    // Execute license (should auto-approve and then execute)
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.execute_license(license_id);
    stop_cheat_caller_address(contract_address);

    // Report usage revenue
    start_cheat_caller_address(contract_address, licensee);
    let report_success = licensing_dispatcher
        .report_usage_revenue(license_id, 500_u256, // $500 revenue
        10_u256 // 10 uses
        );
    stop_cheat_caller_address(contract_address);

    assert!(report_success, "Usage reporting should succeed");

    // Check calculated royalties due
    let due_royalties = licensing_dispatcher.calculate_due_royalties(license_id);
    assert!(due_royalties == 50, "Should owe 10% of $500 = $50"); // 10% of 500

    // Pay royalties
    start_cheat_caller_address(contract_address, licensee);
    let payment_success = licensing_dispatcher.pay_royalties(license_id, 50_u256);
    stop_cheat_caller_address(contract_address);

    assert!(payment_success, "Royalty payment should succeed");

    // Verify royalty tracking
    let royalty_info = licensing_dispatcher.get_royalty_info(license_id);
    assert!(royalty_info.total_revenue_reported == 500, "Wrong total revenue reported");
    assert!(royalty_info.total_royalties_paid == 50, "Wrong total royalties paid");

    // Verify no more royalties due
    let remaining_due = licensing_dispatcher.calculate_due_royalties(license_id);
    assert!(remaining_due == 0, "No royalties should be due after payment");
}

#[test]
fn test_license_transfer_after_execution() {
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
    let original_licensee = USER();
    let new_licensee = deploy_erc1155_receiver();
    let erc20 = erc20_dispatcher.contract_address;

    // Fund original licensee
    start_cheat_caller_address(erc20, SPENDER());
    erc20_dispatcher.transfer(original_licensee, 5000_u256);
    stop_cheat_caller_address(erc20);

    start_cheat_caller_address(erc20, original_licensee);
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20);

    let license_terms = create_basic_license_terms();

    // Create and execute license
    start_cheat_caller_address(contract_address, creator1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            original_licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            10_u256,
            200_u256,
            0,
            erc20,
            license_terms,
            "ipfs://transferable-license",
        );
    stop_cheat_caller_address(contract_address);

    // Execute license
    start_cheat_caller_address(contract_address, original_licensee);
    licensing_dispatcher.execute_license(license_id);
    stop_cheat_caller_address(contract_address);

    // Transfer license
    start_cheat_caller_address(contract_address, original_licensee);
    let transfer_success = licensing_dispatcher.transfer_license(license_id, new_licensee);
    stop_cheat_caller_address(contract_address);

    assert!(transfer_success, "License transfer should succeed");

    // Verify transfer
    let license_info = licensing_dispatcher.get_license_info(license_id);
    assert!(license_info.licensee == new_licensee, "Licensee should be updated");

    // Verify new licensee can operate the license
    start_cheat_caller_address(contract_address, new_licensee);
    let report_success = licensing_dispatcher.report_usage_revenue(license_id, 1000_u256, 5_u256);
    stop_cheat_caller_address(contract_address);

    assert!(report_success, "New licensee should be able to report usage");
}

#[test]
fn test_license_with_usage_limits() {
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
    let erc20 = erc20_dispatcher.contract_address;

    // Fund licensee
    start_cheat_caller_address(erc20, SPENDER());
    erc20_dispatcher.transfer(licensee, 5000_u256);
    stop_cheat_caller_address(erc20);

    start_cheat_caller_address(erc20, licensee);
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20);

    // Create license terms with usage limit
    let mut license_terms = create_basic_license_terms();
    license_terms.max_usage_count = 5; // Only 5 uses allowed

    // Create and execute license
    start_cheat_caller_address(contract_address, creator1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            500_u256,
            200_u256,
            0,
            erc20,
            license_terms,
            "ipfs://limited-usage-license",
        );
    stop_cheat_caller_address(contract_address);

    // Execute license
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.execute_license(license_id);
    stop_cheat_caller_address(contract_address);

    // Verify license is valid initially
    assert!(licensing_dispatcher.is_license_valid(license_id), "License should be valid initially");

    // Verify initial usage count is zero
    let initial_terms = licensing_dispatcher.get_license_terms(license_id);
    assert!(initial_terms.current_usage_count == 0, "Initial usage count should be 0");
    assert!(initial_terms.max_usage_count == 5, "Max usage count should be 5");

    // Report usage (within limit)
    start_cheat_caller_address(contract_address, licensee);
    let report_success = licensing_dispatcher
        .report_usage_revenue(license_id, 10000_u256, 3_u256 // 3 uses, within limit
        );
    stop_cheat_caller_address(contract_address);

    assert!(report_success, "Usage reporting within limit should succeed");
    assert!(licensing_dispatcher.is_license_valid(license_id), "License should still be valid");

    // Verify usage count was tracked
    let terms_after_first = licensing_dispatcher.get_license_terms(license_id);
    assert!(terms_after_first.current_usage_count == 3, "Usage count should be 3");

    // Report more usage (exactly at limit)
    start_cheat_caller_address(contract_address, licensee);
    let report_success2 = licensing_dispatcher
        .report_usage_revenue(
            license_id, 5000_u256, 2_u256 // 2 more uses, total = 5, exactly at limit
        );
    stop_cheat_caller_address(contract_address);

    assert!(report_success2, "Usage reporting at limit should succeed");

    // License should still be valid when exactly at limit
    assert!(
        licensing_dispatcher.is_license_valid(license_id), "License should be valid at exact limit",
    );

    // Verify final usage count
    let terms_at_limit = licensing_dispatcher.get_license_terms(license_id);
    assert!(terms_at_limit.current_usage_count == 5, "Usage count should be 5 (at limit)");

    println!("Usage limits test completed successfully");
}

#[test]
#[should_panic(expected: "Usage limit exceeded")]
fn test_usage_limit_exceeded_panics() {
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
    let erc20 = erc20_dispatcher.contract_address;

    // Fund licensee
    start_cheat_caller_address(erc20, SPENDER());
    erc20_dispatcher.transfer(licensee, 5000_u256);
    stop_cheat_caller_address(erc20);

    start_cheat_caller_address(erc20, licensee);
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20);

    // Create license with strict usage limit
    let mut license_terms = create_basic_license_terms();
    license_terms.max_usage_count = 1; // Only 1 use allowed

    start_cheat_caller_address(contract_address, creator1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            500_u256,
            200_u256,
            0,
            erc20,
            license_terms,
            "ipfs://single-use-license",
        );
    stop_cheat_caller_address(contract_address);

    // Execute license
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.execute_license(license_id);
    stop_cheat_caller_address(contract_address);

    // Use the license once (should succeed)
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.report_usage_revenue(license_id, 1000_u256, 1_u256);
    stop_cheat_caller_address(contract_address);

    // Try to use again (should panic)
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.report_usage_revenue(license_id, 1000_u256, 1_u256);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_governance_license_proposal_and_execution() {
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
    let creator2 = *creators[1];
    let creator3 = *creators[2];
    let licensee = USER();
    let erc20 = erc20_dispatcher.contract_address;

    // Fund licensee for when they execute the license
    start_cheat_caller_address(erc20, SPENDER());
    erc20_dispatcher.transfer(licensee, 25000_u256);
    stop_cheat_caller_address(erc20);

    start_cheat_caller_address(erc20, licensee);
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20);

    // Create proposed license
    let proposed_license = LicenseInfo {
        license_id: 0, // Will be set during execution
        asset_id,
        licensor: creator1,
        licensee,
        license_type: LicenseType::Exclusive.into(),
        usage_rights: UsageRights::All.into(),
        territory: 'GLOBAL',
        license_fee: 20000_u256,
        royalty_rate: 1000_u256, // 10%
        start_timestamp: get_block_timestamp(),
        end_timestamp: 0, // Perpetual
        is_active: false,
        requires_approval: false,
        is_approved: false,
        payment_token: erc20,
        metadata_uri: "ipfs://governance-license",
        is_suspended: false,
        suspension_end_timestamp: 0,
    };

    // Propose license through governance
    start_cheat_caller_address(contract_address, creator1);
    let proposal_id = licensing_dispatcher
        .propose_license_terms(asset_id, proposed_license, 86400 // 24 hours voting period
        );
    stop_cheat_caller_address(contract_address);

    assert!(proposal_id == 1, "Proposal ID should be 1");

    // Vote on proposal
    start_cheat_caller_address(contract_address, creator1);
    let vote1_success = licensing_dispatcher.vote_on_license_proposal(proposal_id, true);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator2);
    let vote2_success = licensing_dispatcher.vote_on_license_proposal(proposal_id, true);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator3);
    let vote3_success = licensing_dispatcher.vote_on_license_proposal(proposal_id, false);
    stop_cheat_caller_address(contract_address);

    assert!(vote1_success && vote2_success && vote3_success, "All votes should succeed");

    // Fast forward past voting deadline
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 86401);

    // Execute proposal (should pass with creator1: 40 + creator2: 35 = 75 vs creator3: 25)
    start_cheat_caller_address(contract_address, creator1);
    let execution_success = licensing_dispatcher.execute_license_proposal(proposal_id);
    stop_cheat_caller_address(contract_address);

    assert!(execution_success, "Proposal execution should succeed");

    // Verify proposal was executed
    let proposal = licensing_dispatcher.get_license_proposal(proposal_id);
    assert!(proposal.is_executed, "Proposal should be marked as executed");

    // Get the created license (should be license_id 1)
    let created_license = licensing_dispatcher.get_license_info(1);
    assert!(created_license.license_id == 1, "License should be created with ID 1");
    assert!(created_license.is_approved, "License should be approved through governance");
    assert!(!created_license.is_active, "License should not be active until executed by licensee");

    // Now licensee can execute the license
    start_cheat_caller_address(contract_address, licensee);
    let licensee_execution_success = licensing_dispatcher.execute_license(1);
    stop_cheat_caller_address(contract_address);

    assert!(licensee_execution_success, "Licensee execution should succeed");

    // Verify license is now active
    let final_license = licensing_dispatcher.get_license_info(1);
    assert!(final_license.is_active, "License should be active after licensee execution");

    stop_cheat_block_timestamp(contract_address);
}

#[test]
#[should_panic(expected: "Only asset owners can create license offers")]
fn test_create_license_unauthorized() {
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

    let (asset_id, _, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let non_owner = USER();
    let licensee = deploy_erc1155_receiver();
    let erc20 = erc20_dispatcher.contract_address;

    let license_terms = create_basic_license_terms();

    // Try to create license as non-owner
    start_cheat_caller_address(contract_address, non_owner);
    licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            10_u256,
            200_u256,
            0,
            erc20,
            license_terms,
            "ipfs://unauthorized-license",
        );
}

#[test]
#[should_panic(expected: "Only designated licensee can execute license")]
fn test_execute_license_wrong_licensee() {
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
    let wrong_user = deploy_erc1155_receiver();
    let erc20 = erc20_dispatcher.contract_address;

    let license_terms = create_basic_license_terms();

    // Create license
    start_cheat_caller_address(contract_address, creator1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            10_u256,
            200_u256,
            0,
            erc20,
            license_terms,
            "ipfs://license",
        );
    stop_cheat_caller_address(contract_address);

    // Try to execute as wrong user
    start_cheat_caller_address(contract_address, wrong_user);
    licensing_dispatcher.execute_license(license_id);
}

#[test]
#[should_panic(expected: "License already active")]
fn test_execute_license_already_active() {
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
    let erc20 = erc20_dispatcher.contract_address;

    // Fund licensee
    start_cheat_caller_address(erc20, SPENDER());
    erc20_dispatcher.transfer(licensee, 5000_u256);
    stop_cheat_caller_address(erc20);

    start_cheat_caller_address(erc20, licensee);
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20);

    let license_terms = create_basic_license_terms();

    // Create license
    start_cheat_caller_address(contract_address, creator1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            10_u256,
            200_u256,
            0,
            erc20,
            license_terms,
            "ipfs://license",
        );
    stop_cheat_caller_address(contract_address);

    // Execute license first time
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.execute_license(license_id);
    stop_cheat_caller_address(contract_address);

    // Try to execute again (should panic)
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.execute_license(license_id);
}

#[test]
#[should_panic(expected: "License must be active to transfer")]
fn test_transfer_inactive_license() {
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
    let new_licensee = deploy_erc1155_receiver();
    let erc20 = erc20_dispatcher.contract_address;

    let license_terms = create_basic_license_terms();

    // Create license but don't execute it
    start_cheat_caller_address(contract_address, creator1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            10_u256,
            200_u256,
            0,
            erc20,
            license_terms,
            "ipfs://license",
        );
    stop_cheat_caller_address(contract_address);

    // Try to transfer inactive license
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.transfer_license(license_id, new_licensee);
}

#[test]
fn test_complete_license_discovery_flow() {
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
    let creator2 = *creators[1];
    let licensee1 = USER();
    let licensee2 = deploy_erc1155_receiver();
    let erc20 = erc20_dispatcher.contract_address;

    let license_terms = create_basic_license_terms();

    // Create multiple license offers
    start_cheat_caller_address(contract_address, creator1);

    // Simple license (auto-approved)
    let license1 = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee1,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'US',
            100_u256,
            200_u256,
            31536000,
            erc20,
            license_terms,
            "ipfs://license1",
        );

    // Exclusive license (requires approval)
    let license2 = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee2,
            LicenseType::Exclusive.into(),
            UsageRights::All.into(),
            'GLOBAL',
            100_u256,
            500_u256,
            0,
            erc20,
            license_terms,
            "ipfs://license2",
        );

    stop_cheat_caller_address(contract_address);

    // Check available licenses (only simple one should be available)
    let available = licensing_dispatcher.get_available_licenses(asset_id);
    assert!(available.len() == 1, "Should have 1 available license");
    assert!(*available[0] == license1, "Available license should be the simple one");

    // Approve the exclusive license
    start_cheat_caller_address(contract_address, creator2);
    licensing_dispatcher.approve_license(license2, true);
    stop_cheat_caller_address(contract_address);

    // Now both should be available
    let available_after_approval = licensing_dispatcher.get_available_licenses(asset_id);
    assert!(available_after_approval.len() == 2, "Should have 2 available licenses after approval");

    // Fund licensees and execute
    start_cheat_caller_address(erc20, SPENDER());
    erc20_dispatcher.transfer(licensee1, 5000_u256);
    erc20_dispatcher.transfer(licensee2, 15000_u256);
    stop_cheat_caller_address(erc20);

    start_cheat_caller_address(erc20, licensee1);
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20);

    start_cheat_caller_address(erc20, licensee2);
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20);

    // Execute licenses
    start_cheat_caller_address(contract_address, licensee1);
    licensing_dispatcher.execute_license(license1);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, licensee2);
    licensing_dispatcher.execute_license(license2);
    stop_cheat_caller_address(contract_address);

    // Verify no more available licenses (all executed)
    let available_after_execution = licensing_dispatcher.get_available_licenses(asset_id);
    assert!(
        available_after_execution.len() == 0, "Should have no available licenses after execution",
    );

    // Verify licensee mappings
    let licensee1_licenses = licensing_dispatcher.get_licensee_licenses(licensee1);
    let licensee2_licenses = licensing_dispatcher.get_licensee_licenses(licensee2);

    assert!(licensee1_licenses.len() == 1, "Licensee1 should have 1 license");
    assert!(licensee2_licenses.len() == 1, "Licensee2 should have 1 license");
}

#[test]
fn test_revoke_active_license() {
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
    let creator2 = *creators[1];
    let licensee = USER();
    let erc20 = erc20_dispatcher.contract_address;

    // Fund licensee
    start_cheat_caller_address(erc20, SPENDER());
    erc20_dispatcher.transfer(licensee, 5000_u256);
    stop_cheat_caller_address(erc20);

    start_cheat_caller_address(erc20, licensee);
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20);

    let license_terms = create_basic_license_terms();

    // Create and execute license
    start_cheat_caller_address(contract_address, creator1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            10_u256,
            200_u256,
            0,
            erc20,
            license_terms,
            "ipfs://revocable-license",
        );
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.execute_license(license_id);
    stop_cheat_caller_address(contract_address);

    // Verify license is valid
    assert!(licensing_dispatcher.is_license_valid(license_id), "License should be valid initially");

    // Revoke license as asset owner
    start_cheat_caller_address(contract_address, creator2);
    let revoke_success = licensing_dispatcher.revoke_license(license_id, "License violated terms");
    stop_cheat_caller_address(contract_address);

    assert!(revoke_success, "License revocation should succeed");

    // Verify license is no longer valid
    assert!(
        !licensing_dispatcher.is_license_valid(license_id),
        "License should be invalid after revocation",
    );

    let license_info = licensing_dispatcher.get_license_info(license_id);
    assert!(!license_info.is_active, "License should not be active after revocation");
}

#[test]
fn test_integration_with_corrected_flow() {
    let (
        contract_address,
        _,
        asset_dispatcher,
        _,
        revenue_dispatcher,
        licensing_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();

    // === PHASE 1: IP ASSET CREATION ===
    let artist1 = deploy_erc1155_receiver();
    let artist2 = deploy_erc1155_receiver();
    let studio = deploy_erc1155_receiver();

    let creators = array![artist1, artist2, studio].span();
    let ownership_percentages = array![40_u256, 35_u256, 25_u256].span();
    let governance_weights = array![45_u256, 35_u256, 20_u256].span();

    // Register a music IP asset
    start_cheat_caller_address(contract_address, owner_address);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            'MUSIC',
            "ipfs://QmMusicAsset/metadata.json",
            creators,
            ownership_percentages,
            governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // === PHASE 2: LICENSE OFFER CREATION ===
    let streaming_service = USER();
    let erc20 = erc20_dispatcher.contract_address;

    // Fund the streaming service
    start_cheat_caller_address(erc20, SPENDER());
    erc20_dispatcher.transfer(streaming_service, 50000_u256);
    stop_cheat_caller_address(erc20);

    start_cheat_caller_address(erc20, streaming_service);
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20);

    // Set default licensing terms
    let default_terms = LicenseTerms {
        max_usage_count: 1000000, // 1M streams max
        current_usage_count: 0,
        attribution_required: true,
        modification_allowed: false,
        commercial_revenue_share: 0,
        termination_notice_period: 2592000 // 30 days notice
    };

    start_cheat_caller_address(contract_address, artist1);
    licensing_dispatcher.set_default_license_terms(asset_id, default_terms);
    stop_cheat_caller_address(contract_address);

    // === PHASE 3: CREATE STREAMING LICENSE OFFER ===
    start_cheat_caller_address(contract_address, artist1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            streaming_service,
            LicenseType::NonExclusive.into(),
            UsageRights::Performance.into(),
            'GLOBAL',
            150_u256, // $150 upfront license fee
            300_u256, // 3% royalty on streaming revenue
            31536000, // 1 year duration
            erc20,
            default_terms,
            "ipfs://streaming-license-terms.json",
        );
    stop_cheat_caller_address(contract_address);

    // License should be auto-approved (not exclusive, reasonable fee)
    let license_info = licensing_dispatcher.get_license_info(license_id);
    assert!(license_info.is_approved, "Non-exclusive license should be auto-approved");
    assert!(!license_info.is_active, "License should not be active until executed");

    // === PHASE 4: STREAMING SERVICE DISCOVERS AND ACCEPTS OFFER ===
    let available_licenses = licensing_dispatcher.get_available_licenses(asset_id);
    assert!(available_licenses.len() == 1, "Should have 1 available license");

    // Execute license (streaming service accepts and pays)
    start_cheat_caller_address(contract_address, streaming_service);
    licensing_dispatcher.execute_license(license_id);
    stop_cheat_caller_address(contract_address);

    // Verify license is now active
    let executed_license = licensing_dispatcher.get_license_info(license_id);
    assert!(executed_license.is_active, "License should be active after execution");

    // Check that license fee was distributed to owners
    let artist1_pending = revenue_dispatcher.get_pending_revenue(asset_id, artist1, erc20);
    let artist2_pending = revenue_dispatcher.get_pending_revenue(asset_id, artist2, erc20);
    let studio_pending = revenue_dispatcher.get_pending_revenue(asset_id, studio, erc20);

    assert!(artist1_pending == 60, "Artist1 should receive 40% of license fee");
    assert!(artist2_pending == 52, "Artist2 should receive 35% of license fee");
    assert!(studio_pending == 37, "Studio should receive 25% of license fee");

    // === PHASE 5: USAGE & ROYALTY REPORTING ===
    start_cheat_caller_address(contract_address, streaming_service);

    // Month 1: 100K streams generating $2000 revenue
    licensing_dispatcher.report_usage_revenue(license_id, 2000_u256, 100000_u256);

    // Month 2: 150K streams generating $3000 revenue
    licensing_dispatcher.report_usage_revenue(license_id, 3000_u256, 150000_u256);

    stop_cheat_caller_address(contract_address);

    // === PHASE 6: ROYALTY PAYMENTS ===
    let total_royalties_due = licensing_dispatcher.calculate_due_royalties(license_id);
    assert!(total_royalties_due == 150, "Should owe 3% of $5000 = $150");

    // Pay royalties
    start_cheat_caller_address(contract_address, streaming_service);
    licensing_dispatcher.pay_royalties(license_id, total_royalties_due);
    stop_cheat_caller_address(contract_address);

    // === PHASE 7: VERIFY FINAL REVENUE DISTRIBUTION ===
    let artist1_final = revenue_dispatcher.get_pending_revenue(asset_id, artist1, erc20);
    let artist2_final = revenue_dispatcher.get_pending_revenue(asset_id, artist2, erc20);
    let studio_final = revenue_dispatcher.get_pending_revenue(asset_id, studio, erc20);

    println!(
        "artist1 final: {}, artist2 final: {}, studio final: {}",
        artist1_final,
        artist2_final,
        studio_final,
    );

    // License fee + royalty share
    assert!(artist1_final == 120, "Artist1 total: $60 fee + $60 royalty");
    assert!(artist2_final == 104, "Artist2 total: $52.50 fee + $52.50 royalty");
    assert!(studio_final == 74, "Studio total: $37.50 fee + $37.50 royalty");
}

#[test]
fn test_license_expiration_timing() {
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

    // Create license with 1 hour duration
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
            3600, // 1 hour
            erc20_dispatcher.contract_address,
            create_basic_license_terms(),
            "ipfs://expiring-license",
        );
    stop_cheat_caller_address(contract_address);

    // Execute immediately - should work
    setup_licensee_payment(contract_address, erc20_dispatcher, licensee, 1000_u256);
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.execute_license(license_id);
    stop_cheat_caller_address(contract_address);

    assert!(licensing_dispatcher.is_license_valid(license_id), "License should be valid initially");

    // Fast forward to just before expiration
    start_cheat_block_timestamp(contract_address, 3599);
    assert!(
        licensing_dispatcher.is_license_valid(license_id),
        "License should still be valid 1 second before expiry",
    );

    // Fast forward past expiration
    start_cheat_block_timestamp(contract_address, 3601);
    assert!(
        !licensing_dispatcher.is_license_valid(license_id),
        "License should be invalid after expiry",
    );

    let status = licensing_dispatcher.get_license_status(license_id);
    assert!(status == 'EXPIRED', "Status should be EXPIRED");

    stop_cheat_block_timestamp(contract_address);
}

#[test]
#[should_panic(expected: "License has expired")]
fn test_execute_expired_license_offer() {
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

    // Create license with short duration
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
            10, // 10 seconds
            erc20_dispatcher.contract_address,
            create_basic_license_terms(),
            "ipfs://short-license",
        );
    stop_cheat_caller_address(contract_address);

    // Fast forward past expiration
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 20);

    setup_licensee_payment(contract_address, erc20_dispatcher, licensee, 1000_u256);
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.execute_license(license_id); // Should panic
}

#[test]
fn test_suspension_auto_reactivation() {
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

    // Create and execute license
    let license_id = create_and_execute_license(
        contract_address,
        licensing_dispatcher,
        erc20_dispatcher,
        asset_id,
        creator1,
        licensee,
        1000_u256,
    );

    // Suspend for 1 hour
    start_cheat_caller_address(contract_address, creator1);
    licensing_dispatcher.suspend_license(license_id, 3600);
    stop_cheat_caller_address(contract_address);

    let status = licensing_dispatcher.get_license_status(license_id);
    assert!(status == 'SUSPENDED', "License should be suspended");

    // Check just before suspension ends
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 3599);
    let status = licensing_dispatcher.get_license_status(license_id);
    assert!(status == 'SUSPENDED', "License should still be suspended");

    // Check after suspension ends
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 3601);
    let status = licensing_dispatcher.get_license_status(license_id);
    assert!(status == 'SUSPENSION_EXPIRED', "License suspension should have expired");

    // Auto-reactivate
    start_cheat_caller_address(contract_address, licensee);
    let reactivated = licensing_dispatcher.check_and_reactivate_license(license_id);
    stop_cheat_caller_address(contract_address);

    assert!(reactivated, "License should be reactivated");
    assert!(
        licensing_dispatcher.is_license_valid(license_id),
        "License should be valid after reactivation",
    );

    stop_cheat_block_timestamp(contract_address);
}

#[test]
fn test_high_value_license_governance_threshold() {
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

    // Create high-value license (> $500)
    start_cheat_caller_address(contract_address, creator1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            600_u256, // High value
            200_u256,
            0,
            erc20_dispatcher.contract_address,
            create_basic_license_terms(),
            "ipfs://high-value-license",
        );
    stop_cheat_caller_address(contract_address);

    let license_info = licensing_dispatcher.get_license_info(license_id);
    assert!(license_info.requires_approval, "High-value license should require approval");
    assert!(!license_info.is_approved, "High-value license should not be auto-approved");
}

#[test]
fn test_governance_voting_minority_fails() {
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
    let creator1 = *creators[0]; // 40 weight
    let creator2 = *creators[1]; // 35 weight
    let creator3 = *creators[2]; // 25 weight

    let proposed_license = create_proposed_license(
        asset_id, USER(), erc20_dispatcher.contract_address,
    );

    // Create proposal
    start_cheat_caller_address(contract_address, creator1);
    let proposal_id = licensing_dispatcher.propose_license_terms(asset_id, proposed_license, 86400);
    stop_cheat_caller_address(contract_address);

    // Vote: creator1(40) AGAINST, creator2(35) + creator3(25) = 60 FOR
    // This should pass since 60 FOR > 40 AGAINST
    start_cheat_caller_address(contract_address, creator1);
    licensing_dispatcher.vote_on_license_proposal(proposal_id, false); // 40 against
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator2);
    licensing_dispatcher.vote_on_license_proposal(proposal_id, true); // 35 for
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator3);
    licensing_dispatcher.vote_on_license_proposal(proposal_id, true); // 25 for
    stop_cheat_caller_address(contract_address);

    // Fast forward past voting deadline
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 86401);

    start_cheat_caller_address(contract_address, creator1);
    let execution_result = licensing_dispatcher.execute_license_proposal(proposal_id);
    stop_cheat_caller_address(contract_address);

    // Should pass because 60 FOR > 40 AGAINST
    assert!(execution_result, "Proposal should pass when for votes exceed against votes");

    stop_cheat_block_timestamp(contract_address);
}

#[test]
#[should_panic(expected: "Proposal did not pass")]
fn test_governance_voting_fails_when_minority_supports() {
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
    let creator1 = *creators[0]; // 40 weight
    let creator2 = *creators[1]; // 35 weight
    let creator3 = *creators[2]; // 25 weight

    let proposed_license = create_proposed_license(
        asset_id, USER(), erc20_dispatcher.contract_address,
    );

    // Create proposal
    start_cheat_caller_address(contract_address, creator1);
    let proposal_id = licensing_dispatcher.propose_license_terms(asset_id, proposed_license, 86400);
    stop_cheat_caller_address(contract_address);

    // Vote: creator2(35) FOR, creator1(40) + creator3(25) = 65 AGAINST
    // This should fail since 35 FOR < 65 AGAINST
    start_cheat_caller_address(contract_address, creator1);
    licensing_dispatcher.vote_on_license_proposal(proposal_id, false); // 40 against
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator2);
    licensing_dispatcher.vote_on_license_proposal(proposal_id, true); // 35 for
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator3);
    licensing_dispatcher.vote_on_license_proposal(proposal_id, false); // 25 against
    stop_cheat_caller_address(contract_address);

    // Fast forward past voting deadline
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 86401);

    start_cheat_caller_address(contract_address, creator1);

    licensing_dispatcher.execute_license_proposal(proposal_id);

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: "Already voted on this proposal")]
fn test_double_voting_prevention() {
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

    let proposed_license = create_proposed_license(
        asset_id, USER(), erc20_dispatcher.contract_address,
    );

    start_cheat_caller_address(contract_address, creator1);
    let proposal_id = licensing_dispatcher.propose_license_terms(asset_id, proposed_license, 86400);
    licensing_dispatcher.vote_on_license_proposal(proposal_id, true);
    licensing_dispatcher.vote_on_license_proposal(proposal_id, false); // Should panic
}

// ========== USAGE LIMITS EDGE CASES ==========

#[test]
fn test_zero_usage_limit_means_unlimited() {
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

    // Create license with 0 max usage (unlimited)
    let mut license_terms = create_basic_license_terms();
    license_terms.max_usage_count = 0; // Unlimited

    let license_id = create_and_execute_license_with_terms(
        contract_address,
        licensing_dispatcher,
        erc20_dispatcher,
        asset_id,
        creator1,
        licensee,
        1000_u256,
        license_terms,
    );

    // Report massive usage - should not fail
    start_cheat_caller_address(contract_address, licensee);
    let success = licensing_dispatcher.report_usage_revenue(license_id, 100000_u256, 1000000_u256);
    stop_cheat_caller_address(contract_address);

    assert!(success, "Unlimited usage should allow any amount");
    assert!(licensing_dispatcher.is_license_valid(license_id), "License should remain valid");
}

#[test]
fn test_usage_exactly_at_limit() {
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

    let mut license_terms = create_basic_license_terms();
    license_terms.max_usage_count = 10;

    let license_id = create_and_execute_license_with_terms(
        contract_address,
        licensing_dispatcher,
        erc20_dispatcher,
        asset_id,
        creator1,
        licensee,
        1000_u256,
        license_terms,
    );

    // Use exactly the limit
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.report_usage_revenue(license_id, 1000_u256, 10_u256);
    stop_cheat_caller_address(contract_address);

    // Should still be valid at exactly the limit
    assert!(
        licensing_dispatcher.is_license_valid(license_id), "License should be valid at exact limit",
    );

    let terms = licensing_dispatcher.get_license_terms(license_id);
    assert!(terms.current_usage_count == 10, "Usage count should be exactly at limit");
}

// ========== ROYALTY CALCULATION EDGE CASES ==========

#[test]
fn test_zero_royalty_rate() {
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

    // Create license with 0% royalty
    start_cheat_caller_address(contract_address, creator1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            100_u256,
            0_u256, // 0% royalty
            0,
            erc20_dispatcher.contract_address,
            create_basic_license_terms(),
            "ipfs://no-royalty-license",
        );
    stop_cheat_caller_address(contract_address);

    setup_licensee_payment(contract_address, erc20_dispatcher, licensee, 1000_u256);
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.execute_license(license_id);

    // Report revenue
    licensing_dispatcher.report_usage_revenue(license_id, 50000_u256, 100_u256);
    stop_cheat_caller_address(contract_address);

    // Should owe no royalties
    let due_royalties = licensing_dispatcher.calculate_due_royalties(license_id);
    assert!(due_royalties == 0, "Should owe no royalties with 0% rate");
}

#[test]
fn test_fractional_royalty_calculation() {
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

    let license_id = create_and_execute_license(
        contract_address,
        licensing_dispatcher,
        erc20_dispatcher,
        asset_id,
        creator1,
        licensee,
        1000_u256,
    );

    // Report revenue that results in fractional royalty
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher
        .report_usage_revenue(license_id, 333_u256, 10_u256); // Should result in 33.3 cents royalty
    stop_cheat_caller_address(contract_address);

    let due_royalties = licensing_dispatcher.calculate_due_royalties(license_id);
    // With 300 basis points (3%), 333 * 300 / 10000 = 9.99, should round down to 9
    assert!(due_royalties == 9, "Fractional royalty should be handled correctly");
}

// ========== PAYMENT AND TRANSFER EDGE CASES ==========

#[test]
#[should_panic(expected: "Only licensee can transfer")]
fn test_transfer_license_by_non_licensee() {
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
    let malicious_user = deploy_erc1155_receiver();
    let new_licensee = deploy_erc1155_receiver();

    let license_id = create_and_execute_license(
        contract_address,
        licensing_dispatcher,
        erc20_dispatcher,
        asset_id,
        creator1,
        licensee,
        1000_u256,
    );

    // Try to transfer as someone other than the licensee
    start_cheat_caller_address(contract_address, malicious_user);
    licensing_dispatcher.transfer_license(license_id, new_licensee);
}

#[test]
fn test_partial_royalty_payments() {
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

    let license_id = create_and_execute_license(
        contract_address,
        licensing_dispatcher,
        erc20_dispatcher,
        asset_id,
        creator1,
        licensee,
        5000_u256,
    );

    // Report revenue owing 30 in royalties (1000 * 3%)
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.report_usage_revenue(license_id, 1000_u256, 10_u256);
    stop_cheat_caller_address(contract_address);

    let total_due = licensing_dispatcher.calculate_due_royalties(license_id);
    assert!(total_due == 30, "Should owe 30 in royalties");

    // Pay partial amount
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.pay_royalties(license_id, 10_u256);
    stop_cheat_caller_address(contract_address);

    let remaining_due = licensing_dispatcher.calculate_due_royalties(license_id);
    assert!(remaining_due == 20, "Should owe 20 remaining");

    // Pay the rest
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.pay_royalties(license_id, 20_u256);
    stop_cheat_caller_address(contract_address);

    let final_due = licensing_dispatcher.calculate_due_royalties(license_id);
    assert!(final_due == 0, "Should owe nothing after full payment");
}

