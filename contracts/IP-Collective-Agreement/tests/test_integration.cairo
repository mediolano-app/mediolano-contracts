use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use ip_collective_agreement::types::{
    ComplianceRecord, ComplianceVerificationRequest, CountryComplianceRequirements,
    ComplianceAuthority, WorkType, ComplianceStatus, GovernanceSettings, AssetManagementProposal,
    LicenseTerms, LicenseType, UsageRights,
};
use ip_collective_agreement::interface::{
    IOwnershipRegistryDispatcher, IOwnershipRegistryDispatcherTrait, IIPAssetManagerDispatcher,
    IIPAssetManagerDispatcherTrait, IRevenueDistributionDispatcher,
    IRevenueDistributionDispatcherTrait, ILicenseManagerDispatcher, ILicenseManagerDispatcherTrait,
    IGovernanceDispatcher, IGovernanceDispatcherTrait, IBerneComplianceDispatcher,
    IBerneComplianceDispatcherTrait,
};
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use core::num::traits::Bounded;

use super::test_utils::{
    OWNER, CREATOR1, CREATOR2, CREATOR3, USER, SPENDER, MARKETPLACE, setup,
    create_test_creators_data, deploy_erc1155_receiver, array_contains,
};

#[test]
fn test_complete_ip_lifecycle_integration() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        licensing_dispatcher,
        governance_dispatcher,
        compliance_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup_complete_system();

    // Create stakeholders
    let artist1 = deploy_erc1155_receiver(); // Lead artist - 40% ownership, 45% governance
    let artist2 =
        deploy_erc1155_receiver(); // Collaborating artist - 35% ownership, 35% governance  
    let studio = deploy_erc1155_receiver(); // Recording studio - 25% ownership, 20% governance
    let streaming_service = deploy_erc1155_receiver(); // Licensee
    let compliance_authority = deploy_erc1155_receiver(); // US Copyright Office
    let marketplace = MARKETPLACE(); // Secondary revenue source

    let creators = array![artist1, artist2, studio].span();
    let ownership_percentages = array![40_u256, 35_u256, 25_u256].span();
    let governance_weights = array![45_u256, 35_u256, 20_u256].span();

    // ========== ASSET CREATION PHASE ==========
    start_cheat_caller_address(contract_address, owner_address);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            WorkType::Musical.into(),
            "ipfs://QmMusicAlbum/metadata.json",
            creators,
            ownership_percentages,
            governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // Verify asset creation
    let asset_info = asset_dispatcher.get_asset_info(asset_id);
    assert!(asset_info.asset_id == asset_id, "Asset should be created");
    assert!(asset_info.asset_type == WorkType::Musical.into(), "Should be musical work");

    // Verify ownership distribution
    assert!(
        ownership_dispatcher.get_owner_percentage(asset_id, artist1) == 40,
        "Artist1 should own 40%",
    );
    assert!(
        ownership_dispatcher.get_owner_percentage(asset_id, artist2) == 35,
        "Artist2 should own 35%",
    );
    assert!(
        ownership_dispatcher.get_owner_percentage(asset_id, studio) == 25, "Studio should own 25%",
    );

    // Verify ERC1155 token distribution
    assert!(
        erc1155_dispatcher.balance_of(artist1, asset_id) == 400, "Artist1 should have 400 tokens",
    );
    assert!(
        erc1155_dispatcher.balance_of(artist2, asset_id) == 350, "Artist2 should have 350 tokens",
    );
    assert!(
        erc1155_dispatcher.balance_of(studio, asset_id) == 250, "Studio should have 250 tokens",
    );

    // ========== GOVERNANCE SETUP PHASE ==========

    let governance_settings = GovernanceSettings {
        default_quorum_percentage: 5000, // 50%
        emergency_quorum_percentage: 3000, // 30%
        license_quorum_percentage: 4000, // 40%
        asset_mgmt_quorum_percentage: 6000, // 60%
        revenue_policy_quorum_percentage: 5500, // 55%
        default_voting_duration: 259200, // 3 days
        emergency_voting_duration: 86400, // 1 day
        execution_delay: 86400 // 1 day
    };

    start_cheat_caller_address(contract_address, artist1);
    governance_dispatcher.set_governance_settings(asset_id, governance_settings);
    stop_cheat_caller_address(contract_address);

    // ========== COMPLIANCE AUTHORITY SETUP ==========

    start_cheat_caller_address(contract_address, owner_address);
    compliance_dispatcher
        .register_compliance_authority(
            compliance_authority,
            "US Copyright Office",
            array!['US', 'CA', 'MX'].span(),
            'GOVERNMENT',
            "ipfs://us-copyright-office-credentials",
        );
    stop_cheat_caller_address(contract_address);

    // ========== COMPLIANCE VERIFICATION PHASE ==========

    // Request compliance verification
    start_cheat_caller_address(contract_address, artist1);
    let verification_request_id = compliance_dispatcher
        .request_compliance_verification(
            asset_id,
            ComplianceStatus::BerneCompliant.into(),
            "ipfs://compliance-evidence-music-album",
            'US',
            1672531200, // Jan 1, 2023
            WorkType::Musical.into(),
            true,
            creators,
        );
    stop_cheat_caller_address(contract_address);

    // Authority processes verification
    start_cheat_caller_address(contract_address, compliance_authority);
    compliance_dispatcher
        .process_compliance_verification(
            verification_request_id,
            true,
            "Meets all Berne Convention requirements for musical works",
            70 * 31536000, // 70 years protection
            array!['US', 'CA', 'UK', 'AU', 'DE', 'FR'].span(), // Automatic protection
            array!['JP', 'CN', 'IN'].span() // Manual registration required
        );
    stop_cheat_caller_address(contract_address);

    // Verify compliance record
    let compliance_record = compliance_dispatcher.get_compliance_record(asset_id);
    assert!(
        compliance_record.compliance_status == ComplianceStatus::BerneCompliant.into(),
        "Should be Berne compliant",
    );
    assert!(
        compliance_record.registration_authority == compliance_authority,
        "Authority should be recorded",
    );
    assert!(
        compliance_record.automatic_protection_count == 6, "Should have 6 auto-protected countries",
    );

    // ========== LICENSING SETUP PHASE ==========

    // Setup payment for streaming service
    start_cheat_caller_address(erc20_dispatcher.contract_address, SPENDER());
    erc20_dispatcher.transfer(streaming_service, 100000_u256); // $1000 for licensing
    stop_cheat_caller_address(erc20_dispatcher.contract_address);

    start_cheat_caller_address(erc20_dispatcher.contract_address, streaming_service);
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20_dispatcher.contract_address);

    // Create default licensing terms
    let license_terms = LicenseTerms {
        max_usage_count: 10000000, // 10M streams
        current_usage_count: 0,
        attribution_required: true,
        modification_allowed: false,
        commercial_revenue_share: 0,
        termination_notice_period: 2592000 // 30 days
    };

    start_cheat_caller_address(contract_address, artist1);
    licensing_dispatcher.set_default_license_terms(asset_id, license_terms);
    stop_cheat_caller_address(contract_address);

    // ========== LICENSE CREATION AND EXECUTION ==========

    // Artist1 creates streaming license offer
    start_cheat_caller_address(contract_address, artist1);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            streaming_service,
            LicenseType::NonExclusive.into(),
            UsageRights::Performance.into(),
            'GLOBAL',
            50000_u256, // $500 upfront license fee
            300_u256, // 3% royalty rate
            31536000, // 1 year duration
            erc20_dispatcher.contract_address,
            license_terms,
            "ipfs://streaming-license-terms.json",
        );
    stop_cheat_caller_address(contract_address);

    // Verify license is available for execution
    let available_licenses = licensing_dispatcher.get_available_licenses(asset_id);
    assert!(array_contains(available_licenses.span(), license_id), "License should be available");

    // Streaming service accepts and executes license
    start_cheat_caller_address(contract_address, streaming_service);
    licensing_dispatcher.execute_license(license_id);
    stop_cheat_caller_address(contract_address);

    // Verify license is active and fee was distributed
    let license_info = licensing_dispatcher.get_license_info(license_id);
    assert!(license_info.is_active, "License should be active");
    assert!(licensing_dispatcher.is_license_valid(license_id), "License should be valid");

    // Check license fee distribution
    let artist1_pending = revenue_dispatcher
        .get_pending_revenue(asset_id, artist1, erc20_dispatcher.contract_address);
    let artist2_pending = revenue_dispatcher
        .get_pending_revenue(asset_id, artist2, erc20_dispatcher.contract_address);
    let studio_pending = revenue_dispatcher
        .get_pending_revenue(asset_id, studio, erc20_dispatcher.contract_address);

    assert!(artist1_pending == 20000, "Artist1 should get 40% of license fee"); // 40% of 50000
    assert!(artist2_pending == 17500, "Artist2 should get 35% of license fee"); // 35% of 50000
    assert!(studio_pending == 12500, "Studio should get 25% of license fee"); // 25% of 50000

    // ========== REVENUE GENERATION PHASE ==========

    // Streaming service reports usage and revenue over time
    start_cheat_caller_address(contract_address, streaming_service);

    // Month 1: 2M streams, $6000 revenue
    licensing_dispatcher.report_usage_revenue(license_id, 600000_u256, 2000000_u256);

    // Month 2: 3M streams, $9000 revenue
    licensing_dispatcher.report_usage_revenue(license_id, 900000_u256, 3000000_u256);

    // Month 3: 2.5M streams, $7500 revenue
    licensing_dispatcher.report_usage_revenue(license_id, 750000_u256, 2500000_u256);

    stop_cheat_caller_address(contract_address);

    // Verify usage tracking
    let updated_terms = licensing_dispatcher.get_license_terms(license_id);
    assert!(updated_terms.current_usage_count == 7500000, "Should track 7.5M total streams");
    assert!(
        updated_terms.current_usage_count < updated_terms.max_usage_count,
        "Should be under usage limit",
    );

    // Calculate and pay royalties
    let due_royalties = licensing_dispatcher.calculate_due_royalties(license_id);
    assert!(due_royalties == 67500, "Should owe 3% of $22,500 = $675");

    start_cheat_caller_address(contract_address, streaming_service);
    licensing_dispatcher.pay_royalties(license_id, due_royalties);
    stop_cheat_caller_address(contract_address);

    // ========== SECONDARY REVENUE SOURCES ==========

    // Marketplace generates revenue (sync licensing, merchandise, etc.)
    start_cheat_caller_address(contract_address, marketplace);
    revenue_dispatcher
        .receive_revenue(asset_id, erc20_dispatcher.contract_address, 150000_u256); // $1500
    stop_cheat_caller_address(contract_address);

    // Artist2 triggers revenue distribution
    start_cheat_caller_address(contract_address, artist2);
    revenue_dispatcher.distribute_all_revenue(asset_id, erc20_dispatcher.contract_address);
    stop_cheat_caller_address(contract_address);

    // ========== GOVERNANCE IN ACTION ==========

    // Studio proposes to update metadata (add deluxe edition info)
    let metadata_proposal = AssetManagementProposal {
        new_metadata_uri: "ipfs://QmMusicAlbum-DeluxeEdition/metadata.json",
        new_compliance_status: ComplianceStatus::BerneCompliant.into(),
        update_metadata: true,
        update_compliance: false,
    };

    start_cheat_caller_address(contract_address, studio);
    let proposal_id = governance_dispatcher
        .propose_asset_management(
            asset_id,
            metadata_proposal,
            259200, // 3 days voting
            "Add deluxe edition information to album metadata",
        );
    stop_cheat_caller_address(contract_address);

    // Voting phase
    start_cheat_caller_address(contract_address, artist1);
    governance_dispatcher.vote_on_governance_proposal(proposal_id, true); // 45% vote FOR
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, artist2);
    governance_dispatcher
        .vote_on_governance_proposal(proposal_id, true); // 35% vote FOR (total 80%)
    stop_cheat_caller_address(contract_address);

    // Check quorum reached
    assert!(governance_dispatcher.check_quorum_reached(proposal_id), "Quorum should be reached");

    // Fast forward past voting period
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 259201);

    // Execute proposal
    start_cheat_caller_address(contract_address, studio);
    governance_dispatcher.execute_asset_management_proposal(proposal_id);
    stop_cheat_caller_address(contract_address);

    // Verify metadata was updated
    let updated_asset = asset_dispatcher.get_asset_info(asset_id);
    assert!(
        updated_asset.metadata_uri == "ipfs://QmMusicAlbum-DeluxeEdition/metadata.json",
        "Metadata should be updated",
    );

    stop_cheat_block_timestamp(contract_address);

    // ========== OWNERSHIP DYNAMICS ==========

    // Artist1 transfers 10% to new investor
    let investor = deploy_erc1155_receiver();

    start_cheat_caller_address(contract_address, artist1);
    ownership_dispatcher.transfer_ownership_share(asset_id, artist1, investor, 10_u256);
    stop_cheat_caller_address(contract_address);

    // Verify ownership rebalancing
    assert!(
        ownership_dispatcher.get_owner_percentage(asset_id, artist1) == 30,
        "Artist1 should now have 30%",
    );
    assert!(
        ownership_dispatcher.get_owner_percentage(asset_id, investor) == 10,
        "Investor should have 10%",
    );

    // Add more revenue to see new distribution
    start_cheat_caller_address(contract_address, marketplace);
    revenue_dispatcher
        .receive_revenue(asset_id, erc20_dispatcher.contract_address, 100000_u256); // $1000
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, artist2);
    revenue_dispatcher.distribute_all_revenue(asset_id, erc20_dispatcher.contract_address);
    stop_cheat_caller_address(contract_address);

    // Verify new revenue distribution reflects ownership change
    let investor_pending = revenue_dispatcher
        .get_pending_revenue(asset_id, investor, erc20_dispatcher.contract_address);
    assert!(investor_pending == 10000, "Investor should get 10% of new revenue"); // 10% of 100000

    // ========== WITHDRAWAL PHASE ==========

    // All stakeholders withdraw their accumulated revenue
    start_cheat_caller_address(contract_address, artist1);
    let artist1_withdrawn = revenue_dispatcher
        .withdraw_pending_revenue(asset_id, erc20_dispatcher.contract_address);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, artist2);
    let artist2_withdrawn = revenue_dispatcher
        .withdraw_pending_revenue(asset_id, erc20_dispatcher.contract_address);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, studio);
    let studio_withdrawn = revenue_dispatcher
        .withdraw_pending_revenue(asset_id, erc20_dispatcher.contract_address);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, investor);
    let investor_withdrawn = revenue_dispatcher
        .withdraw_pending_revenue(asset_id, erc20_dispatcher.contract_address);
    stop_cheat_caller_address(contract_address);

    // ========== SYSTEM CONSISTENCY VERIFICATION ==========

    // Verify no pending revenue remains
    let total_pending = revenue_dispatcher
        .get_pending_revenue(asset_id, artist1, erc20_dispatcher.contract_address)
        + revenue_dispatcher
            .get_pending_revenue(asset_id, artist2, erc20_dispatcher.contract_address)
        + revenue_dispatcher
            .get_pending_revenue(asset_id, studio, erc20_dispatcher.contract_address)
        + revenue_dispatcher
            .get_pending_revenue(asset_id, investor, erc20_dispatcher.contract_address);

    assert!(total_pending == 0, "No pending revenue should remain");

    // Verify ownership still totals 100%
    let total_ownership = ownership_dispatcher.get_owner_percentage(asset_id, artist1)
        + ownership_dispatcher.get_owner_percentage(asset_id, artist2)
        + ownership_dispatcher.get_owner_percentage(asset_id, studio)
        + ownership_dispatcher.get_owner_percentage(asset_id, investor);

    assert!(total_ownership == 100, "Total ownership should equal 100%");

    // Verify license is still valid and functional
    assert!(licensing_dispatcher.is_license_valid(license_id), "License should remain valid");
    assert!(
        compliance_dispatcher.check_protection_validity(asset_id, 'US'),
        "Should have US protection",
    );
}

// ========== HELPER FUNCTIONS ==========

fn setup_complete_system() -> (
    ContractAddress,
    IOwnershipRegistryDispatcher,
    IIPAssetManagerDispatcher,
    IERC1155Dispatcher,
    IRevenueDistributionDispatcher,
    ILicenseManagerDispatcher,
    IGovernanceDispatcher,
    IBerneComplianceDispatcher,
    IERC20Dispatcher,
    ContractAddress,
) {
    // Reuse existing setup but add all dispatchers
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        licensing_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();

    let governance_dispatcher = IGovernanceDispatcher { contract_address };
    let compliance_dispatcher = IBerneComplianceDispatcher { contract_address };

    (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        licensing_dispatcher,
        governance_dispatcher,
        compliance_dispatcher,
        erc20_dispatcher,
        owner_address,
    )
}
