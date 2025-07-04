use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use ip_collective_agreement::types::{
    GovernanceProposal, AssetManagementProposal, RevenuePolicyProposal, EmergencyProposal,
    GovernanceSettings, ProposalType, ComplianceStatus,
};
use ip_collective_agreement::interface::{
    IOwnershipRegistryDispatcher, IOwnershipRegistryDispatcherTrait, IIPAssetManagerDispatcher,
    IIPAssetManagerDispatcherTrait, IRevenueDistributionDispatcher,
    IRevenueDistributionDispatcherTrait, IGovernanceDispatcher, IGovernanceDispatcherTrait,
    ILicenseManagerDispatcher, ILicenseManagerDispatcherTrait,
};
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use core::num::traits::Bounded;

use super::test_utils::{
    OWNER, CREATOR1, CREATOR2, CREATOR3, USER, SPENDER, MARKETPLACE, setup,
    create_test_creators_data, register_test_asset, setup_with_governance,
    create_default_governance_settings, create_and_execute_license,
};

// ========== GOVERNANCE SETTINGS TESTS ==========

#[test]
fn test_set_and_get_governance_settings() {
    let (contract_address, _, asset_dispatcher, _, _, _, governance_dispatcher, _, owner_address) =
        setup_with_governance();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];

    let custom_settings = GovernanceSettings {
        default_quorum_percentage: 6000, // 60%
        emergency_quorum_percentage: 2000, // 20%
        license_quorum_percentage: 4500, // 45%
        asset_mgmt_quorum_percentage: 7000, // 70%
        revenue_policy_quorum_percentage: 6500, // 65%
        default_voting_duration: 432000, // 5 days
        emergency_voting_duration: 43200, // 12 hours
        execution_delay: 172800 // 2 days
    };

    // Set custom governance settings
    start_cheat_caller_address(contract_address, creator1);
    let success = governance_dispatcher.set_governance_settings(asset_id, custom_settings);
    stop_cheat_caller_address(contract_address);

    assert!(success, "Setting governance settings should succeed");

    // Verify settings were stored correctly
    let retrieved_settings = governance_dispatcher.get_governance_settings(asset_id);
    assert!(retrieved_settings.default_quorum_percentage == 6000, "Default quorum should be 60%");
    assert!(
        retrieved_settings.emergency_quorum_percentage == 2000, "Emergency quorum should be 20%",
    );
    assert!(retrieved_settings.execution_delay == 172800, "Execution delay should be 2 days");
}
#[test]
fn test_default_governance_settings() {
    let (contract_address, _, asset_dispatcher, _, _, _, governance_dispatcher, _, owner_address) =
        setup_with_governance();
    let (asset_id, _, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );

    // Get settings without setting any (should return defaults)
    let default_settings = governance_dispatcher.get_governance_settings(asset_id);

    assert!(default_settings.default_quorum_percentage == 5000, "Default should be 50%");
    assert!(
        default_settings.emergency_quorum_percentage == 3000, "Emergency default should be
    30%",
    );
    assert!(
        default_settings.default_voting_duration == 259200, "Default voting should be 3
    days",
    );
    assert!(
        default_settings.execution_delay == 86400, "Default execution delay should be 1
    day",
    );
}

#[test]
#[should_panic(expected: "Only asset owners can set governance settings")]
fn test_set_governance_settings_unauthorized() {
    let (contract_address, _, asset_dispatcher, _, _, _, governance_dispatcher, _, owner_address) =
        setup_with_governance();
    let (asset_id, _, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let non_owner = USER();

    let settings = create_default_governance_settings();

    start_cheat_caller_address(contract_address, non_owner);
    governance_dispatcher.set_governance_settings(asset_id, settings);
}

#[test]
#[should_panic(expected: "Quorum cannot exceed 100%")]
fn test_invalid_governance_settings() {
    let (contract_address, _, asset_dispatcher, _, _, _, governance_dispatcher, _, owner_address) =
        setup_with_governance();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];

    let invalid_settings = GovernanceSettings {
        default_quorum_percentage: 15000, // 150% - invalid!
        emergency_quorum_percentage: 3000,
        license_quorum_percentage: 4000,
        asset_mgmt_quorum_percentage: 6000,
        revenue_policy_quorum_percentage: 5500,
        default_voting_duration: 259200,
        emergency_voting_duration: 86400,
        execution_delay: 86400,
    };

    start_cheat_caller_address(contract_address, creator1);
    governance_dispatcher.set_governance_settings(asset_id, invalid_settings);
}

// ========== ASSET MANAGEMENT PROPOSAL TESTS ==========

#[test]
fn test_asset_management_proposal_creation_and_execution() {
    let (contract_address, _, asset_dispatcher, _, _, _, governance_dispatcher, _, owner_address) =
        setup_with_governance();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];
    let creator2 = *creators[1];
    let creator3 = *creators[2];

    let proposal_data = AssetManagementProposal {
        new_metadata_uri: "ipfs://updated-asset-metadata",
        new_compliance_status: ComplianceStatus::BerneCompliant.into(),
        update_metadata: true,
        update_compliance: true,
    };

    // Create asset management proposal
    start_cheat_caller_address(contract_address, creator1);
    let proposal_id = governance_dispatcher
        .propose_asset_management(
            asset_id, proposal_data, 259200, // 3 days
            "Update metadata and compliance status",
        );
    stop_cheat_caller_address(contract_address);

    assert!(proposal_id == 1, "First proposal should have ID 1");

    // Check proposal details
    let proposal = governance_dispatcher.get_governance_proposal(proposal_id);
    assert!(proposal.asset_id == asset_id, "Proposal should be for correct asset");
    assert!(
        proposal.proposal_type == ProposalType::AssetManagement.into(),
        "Should be asset
    management type",
    );
    assert!(proposal.quorum_required > 0, "Should have quorum requirement");

    // Vote on proposal (need majority + quorum)
    start_cheat_caller_address(contract_address, creator1);
    governance_dispatcher.vote_on_governance_proposal(proposal_id, true); // 40 weight
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator2);
    governance_dispatcher.vote_on_governance_proposal(proposal_id, true); // 35 weight
    stop_cheat_caller_address(contract_address);

    // Check quorum reached
    assert!(governance_dispatcher.check_quorum_reached(proposal_id), "Quorum should be reached");

    // Fast forward past voting deadline
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 259201);

    // Execute proposal
    start_cheat_caller_address(contract_address, creator1);
    let success = governance_dispatcher.execute_asset_management_proposal(proposal_id);
    stop_cheat_caller_address(contract_address);

    assert!(success, "Proposal execution should succeed");

    // Verify asset was updated
    let updated_asset = asset_dispatcher.get_asset_info(asset_id);
    assert!(
        updated_asset.metadata_uri == "ipfs://updated-asset-metadata",
        "Metadata should be
    updated",
    );
    assert!(
        updated_asset.compliance_status == ComplianceStatus::BerneCompliant.into(),
        "Compliance should be updated",
    );

    stop_cheat_block_timestamp(contract_address);
}

#[test]
fn test_asset_management_proposal_fails_without_quorum() {
    let (contract_address, _, asset_dispatcher, _, _, _, governance_dispatcher, _, owner_address) =
        setup_with_governance();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator3 = *creators[2]; // Only 25% governance weight

    let proposal_data = AssetManagementProposal {
        new_metadata_uri: "ipfs://should-not-update",
        new_compliance_status: ComplianceStatus::BerneCompliant.into(),
        update_metadata: true,
        update_compliance: false,
    };

    start_cheat_caller_address(contract_address, creator3);
    let proposal_id = governance_dispatcher
        .propose_asset_management(asset_id, proposal_data, 259200, "Minority proposal");

    // Vote only with creator3 (25% weight, below 60% quorum for asset management)
    governance_dispatcher.vote_on_governance_proposal(proposal_id, true);
    stop_cheat_caller_address(contract_address);

    // Check quorum not reached
    assert!(
        !governance_dispatcher.check_quorum_reached(proposal_id),
        "Quorum should not be
    reached",
    );

    // Fast forward and try to execute
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 259201);

    start_cheat_caller_address(contract_address, creator3);
    let can_execute = governance_dispatcher.can_execute_proposal(proposal_id);
    stop_cheat_caller_address(contract_address);

    assert!(!can_execute, "Should not be able to execute without quorum");

    stop_cheat_block_timestamp(contract_address);
}

// ========== REVENUE POLICY PROPOSAL TESTS ==========

#[test]
fn test_revenue_policy_proposal() {
    let (
        contract_address,
        _,
        asset_dispatcher,
        _,
        revenue_dispatcher,
        _,
        governance_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup_with_governance();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];
    let creator2 = *creators[1];
    let erc20 = erc20_dispatcher.contract_address;

    let proposal_data = RevenuePolicyProposal {
        token_address: erc20,
        new_minimum_distribution: 5000_u256, // $50.00
        new_distribution_frequency: 604800 // 1 week
    };

    // Create revenue policy proposal
    start_cheat_caller_address(contract_address, creator1);
    let proposal_id = governance_dispatcher
        .propose_revenue_policy(
            asset_id, proposal_data, 259200, "Increase minimum distribution threshold",
        );
    stop_cheat_caller_address(contract_address);

    // Vote to approve (need 55% quorum for revenue policy)
    start_cheat_caller_address(contract_address, creator1);
    governance_dispatcher.vote_on_governance_proposal(proposal_id, true); // 40%
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator2);
    governance_dispatcher.vote_on_governance_proposal(proposal_id, true); // 35% (total 75%)
    stop_cheat_caller_address(contract_address);

    // Fast forward and execute
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 259201);

    start_cheat_caller_address(contract_address, creator1);
    let success = governance_dispatcher.execute_revenue_policy_proposal(proposal_id);
    stop_cheat_caller_address(contract_address);

    assert!(success, "Revenue policy execution should succeed");

    // Verify policy was updated
    let new_minimum = revenue_dispatcher.get_minimum_distribution(asset_id, erc20);
    assert!(new_minimum == 5000, "Minimum distribution should be updated to $50.00");

    stop_cheat_block_timestamp(contract_address);
}

// ========== EMERGENCY PROPOSAL TESTS ==========

#[test]
fn test_emergency_proposal_license_suspension() {
    let (
        contract_address,
        _,
        asset_dispatcher,
        _,
        _,
        licensing_dispatcher,
        governance_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup_with_governance();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];
    let creator2 = *creators[1];
    let licensee = USER();

    // Create and execute a license first
    let license_id = create_and_execute_license(
        contract_address,
        licensing_dispatcher,
        erc20_dispatcher,
        asset_id,
        creator1,
        licensee,
        1000_u256,
    );

    // Verify license is active
    assert!(
        licensing_dispatcher.is_license_valid(license_id), "License should be active
    initially",
    );

    // Create emergency proposal to suspend the license
    let emergency_data = EmergencyProposal {
        action_type: 'SUSPEND_LICENSE',
        target_id: license_id,
        suspension_duration: 604800, // 1 week
        reason: "License terms violation reported",
    };

    start_cheat_caller_address(contract_address, creator1);
    let proposal_id = governance_dispatcher
        .propose_emergency_action(
            asset_id, emergency_data, "Emergency license suspension due to violation",
        );
    stop_cheat_caller_address(contract_address);

    // Emergency proposals have lower quorum (30%) and shorter voting period (1 day)
    let proposal = governance_dispatcher.get_governance_proposal(proposal_id);
    assert!(
        proposal.proposal_type == ProposalType::Emergency.into(), "Should be emergency
    type",
    );

    // Vote (30% quorum means just creator1's 40% vote is enough)
    start_cheat_caller_address(contract_address, creator1);
    governance_dispatcher.vote_on_governance_proposal(proposal_id, true);
    stop_cheat_caller_address(contract_address);

    assert!(
        governance_dispatcher.check_quorum_reached(proposal_id),
        "Emergency quorum should be
    reached",
    );

    // Fast forward past emergency voting period (1 day)
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 86401);

    // Execute emergency proposal
    start_cheat_caller_address(contract_address, creator2);
    let success = governance_dispatcher.execute_emergency_proposal(proposal_id);
    stop_cheat_caller_address(contract_address);

    assert!(success, "Emergency proposal execution should succeed");

    // Verify license was suspended
    assert!(
        !licensing_dispatcher.is_license_valid(license_id),
        "License should be invalid after
    suspension",
    );

    let license_info = licensing_dispatcher.get_license_info(license_id);
    assert!(license_info.is_suspended, "License should be marked as suspended");

    stop_cheat_block_timestamp(contract_address);
}

// ========== QUORUM AND VOTING TESTS ==========

#[test]
fn test_quorum_calculation_and_participation_rate() {
    let (contract_address, _, asset_dispatcher, _, _, _, governance_dispatcher, _, owner_address) =
        setup_with_governance();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0]; // 40% governance weight
    let creator2 = *creators[1]; // 35% governance weight

    let proposal_data = AssetManagementProposal {
        new_metadata_uri: "ipfs://test",
        new_compliance_status: 'PENDING',
        update_metadata: true,
        update_compliance: false,
    };

    start_cheat_caller_address(contract_address, creator1);
    let proposal_id = governance_dispatcher
        .propose_asset_management(asset_id, proposal_data, 259200, "Test quorum calculation");
    stop_cheat_caller_address(contract_address);

    // Initially no votes
    let initial_participation = governance_dispatcher.get_proposal_participation_rate(proposal_id);
    assert!(initial_participation == 0, "Initial participation should be 0%");

    // Creator1 votes (40% of total governance weight)
    start_cheat_caller_address(contract_address, creator1);
    governance_dispatcher.vote_on_governance_proposal(proposal_id, true);
    stop_cheat_caller_address(contract_address);

    let participation_after_one = governance_dispatcher
        .get_proposal_participation_rate(proposal_id);
    assert!(participation_after_one == 4000, "Participation should be 40% (4000 basis points)");

    // Creator2 also votes (total now 75%)
    start_cheat_caller_address(contract_address, creator2);
    governance_dispatcher.vote_on_governance_proposal(proposal_id, false); // Votes against
    stop_cheat_caller_address(contract_address);

    let final_participation = governance_dispatcher.get_proposal_participation_rate(proposal_id);
    assert!(
        final_participation == 7500, "Final participation should be 75% (7500 basis
    points)",
    );

    // Should have reached quorum (60% required for asset management)
    assert!(
        governance_dispatcher.check_quorum_reached(proposal_id),
        "Quorum should be reached
    with 75% participation",
    );
}

#[test]
#[should_panic(expected: "Already voted on this proposal")]
fn test_double_voting_prevention() {
    let (contract_address, _, asset_dispatcher, _, _, _, governance_dispatcher, _, owner_address) =
        setup_with_governance();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];

    let proposal_data = AssetManagementProposal {
        new_metadata_uri: "ipfs://test",
        new_compliance_status: 'PENDING',
        update_metadata: true,
        update_compliance: false,
    };

    start_cheat_caller_address(contract_address, creator1);
    let proposal_id = governance_dispatcher
        .propose_asset_management(asset_id, proposal_data, 259200, "Double voting test");

    // Vote once
    governance_dispatcher.vote_on_governance_proposal(proposal_id, true);

    // Try to vote again (should panic)
    governance_dispatcher.vote_on_governance_proposal(proposal_id, false);
}

// ========== EXECUTION TIMING TESTS ==========

#[test]
fn test_execution_before_voting_ends_fails() {
    let (contract_address, _, asset_dispatcher, _, _, _, governance_dispatcher, _, owner_address) =
        setup_with_governance();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];
    let creator2 = *creators[1];

    let proposal_data = AssetManagementProposal {
        new_metadata_uri: "ipfs://early-execution",
        new_compliance_status: 'PENDING',
        update_metadata: true,
        update_compliance: false,
    };

    start_cheat_caller_address(contract_address, creator1);
    let proposal_id = governance_dispatcher
        .propose_asset_management(asset_id, proposal_data, 259200, "Early execution test");

    // Get enough votes
    governance_dispatcher.vote_on_governance_proposal(proposal_id, true);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator2);
    governance_dispatcher.vote_on_governance_proposal(proposal_id, true);
    stop_cheat_caller_address(contract_address);

    // Try to execute before voting period ends
    start_cheat_caller_address(contract_address, creator1);
    let can_execute = governance_dispatcher.can_execute_proposal(proposal_id);
    stop_cheat_caller_address(contract_address);

    assert!(!can_execute, "Should not be able to execute before voting ends");
}

#[test]
fn test_execution_after_deadline_fails() {
    let (contract_address, _, asset_dispatcher, _, _, _, governance_dispatcher, _, owner_address) =
        setup_with_governance();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];
    let creator2 = *creators[1];

    let proposal_data = AssetManagementProposal {
        new_metadata_uri: "ipfs://late-execution",
        new_compliance_status: 'PENDING',
        update_metadata: true,
        update_compliance: false,
    };

    start_cheat_caller_address(contract_address, creator1);
    let proposal_id = governance_dispatcher
        .propose_asset_management(asset_id, proposal_data, 259200, "Late execution test");

    governance_dispatcher.vote_on_governance_proposal(proposal_id, true);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator2);
    governance_dispatcher.vote_on_governance_proposal(proposal_id, true);
    stop_cheat_caller_address(contract_address);

    // Fast forward past execution deadline (voting period + execution delay)
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 259200 + 86401);

    start_cheat_caller_address(contract_address, creator1);
    let can_execute = governance_dispatcher.can_execute_proposal(proposal_id);
    stop_cheat_caller_address(contract_address);

    assert!(!can_execute, "Should not be able to execute after deadline");

    stop_cheat_block_timestamp(contract_address);
}

