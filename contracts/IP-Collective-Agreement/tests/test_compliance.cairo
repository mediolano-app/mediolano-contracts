use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use ip_collective_agreement::types::{
    ComplianceRecord, ComplianceVerificationRequest, CountryComplianceRequirements,
    ComplianceAuthority, WorkType, ComplianceStatus,
};
use ip_collective_agreement::interface::{
    IOwnershipRegistryDispatcher, IOwnershipRegistryDispatcherTrait, IIPAssetManagerDispatcher,
    IIPAssetManagerDispatcherTrait, IBerneComplianceDispatcher, IBerneComplianceDispatcherTrait,
    IRevenueDistributionDispatcher, IRevenueDistributionDispatcherTrait, ILicenseManagerDispatcher,
    ILicenseManagerDispatcherTrait, IGovernanceDispatcher, IGovernanceDispatcherTrait,
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};

use super::test_utils::{
    OWNER, CREATOR1, CREATOR2, CREATOR3, USER, SPENDER, MARKETPLACE, setup,
    create_test_creators_data, register_test_asset, deploy_erc1155_receiver, setup_with_compliance,
    register_test_authority, create_and_approve_verification, array_contains,
};

#[test]
fn test_register_compliance_authority() {
    let (
        contract_address, _, asset_dispatcher, _, _, _, _, compliance_dispatcher, _, owner_address,
    ) =
        setup_with_compliance();
    let authority_address = deploy_erc1155_receiver();
    let authorized_countries = array!['US', 'CA', 'MX'].span();

    start_cheat_caller_address(contract_address, owner_address);
    let success = compliance_dispatcher
        .register_compliance_authority(
            authority_address,
            "North America Copyright Office",
            authorized_countries,
            'GOVERNMENT',
            "ipfs://credentials-hash",
        );
    stop_cheat_caller_address(contract_address);

    assert!(success, "Authority registration should succeed");

    // Verify authority was stored correctly
    let authority = compliance_dispatcher.get_compliance_authority(authority_address);
    assert!(authority.authority_address == authority_address, "Wrong authority address");
    assert!(authority.authority_name == "North America Copyright Office", "Wrong authority name");
    assert!(authority.authority_type == 'GOVERNMENT', "Wrong authority type");
    assert!(authority.is_active, "Authority should be active");
    assert!(authority.authorized_countries_count == 3, "Should have 3 authorized countries");
    assert!(authority.verification_count == 0, "Should start with 0 verifications");

    // Verify countries were stored
    let stored_countries = compliance_dispatcher.get_authority_countries(authority_address);
    assert!(stored_countries.len() == 3, "Should return 3 countries");
    assert!(array_contains(stored_countries, 'US'), "Should contain US");
    assert!(array_contains(stored_countries, 'CA'), "Should contain CA");
    assert!(array_contains(stored_countries, 'MX'), "Should contain MX");

    // Test authorization for specific countries
    assert!(
        compliance_dispatcher.is_authorized_for_country(authority_address, 'US'),
        "Should be authorized for US",
    );
    assert!(
        compliance_dispatcher.is_authorized_for_country(authority_address, 'CA'),
        "Should be authorized for CA",
    );
    assert!(
        !compliance_dispatcher.is_authorized_for_country(authority_address, 'UK'),
        "Should not be authorized for UK",
    );
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_register_authority_unauthorized() {
    let (contract_address, _, _, _, _, _, _, compliance_dispatcher, _, _) = setup_with_compliance();
    let non_owner = USER();
    let authority_address = deploy_erc1155_receiver();

    start_cheat_caller_address(contract_address, non_owner);
    compliance_dispatcher
        .register_compliance_authority(
            authority_address,
            "Unauthorized Authority",
            array!['US'].span(),
            'GOVERNMENT',
            "ipfs://fake",
        );
}

#[test]
#[should_panic(expected: "Invalid authority type")]
fn test_register_authority_invalid_type() {
    let (contract_address, _, _, _, _, _, _, compliance_dispatcher, _, owner_address) =
        setup_with_compliance();
    let authority_address = deploy_erc1155_receiver();

    start_cheat_caller_address(contract_address, owner_address);
    compliance_dispatcher
        .register_compliance_authority(
            authority_address,
            "Invalid Authority",
            array!['US'].span(),
            'INVALID_TYPE',
            "ipfs://creds",
        );
}

#[test]
fn test_deactivate_compliance_authority() {
    let (contract_address, _, _, _, _, _, _, compliance_dispatcher, _, owner_address) =
        setup_with_compliance();
    let authority_address = register_test_authority(
        contract_address, compliance_dispatcher, owner_address,
    );

    // Verify authority is initially active
    assert!(
        compliance_dispatcher.is_authorized_for_country(authority_address, 'US'),
        "Should be authorized initially",
    );

    // Deactivate authority
    start_cheat_caller_address(contract_address, owner_address);
    let success = compliance_dispatcher.deactivate_compliance_authority(authority_address);
    stop_cheat_caller_address(contract_address);

    assert!(success, "Deactivation should succeed");

    // Verify authority is no longer authorized
    assert!(
        !compliance_dispatcher.is_authorized_for_country(authority_address, 'US'),
        "Should not be authorized after deactivation",
    );

    let authority = compliance_dispatcher.get_compliance_authority(authority_address);
    assert!(!authority.is_active, "Authority should be inactive");
}

#[test]
fn test_set_and_get_country_requirements() {
    let (contract_address, _, _, _, _, _, _, compliance_dispatcher, _, owner_address) =
        setup_with_compliance();

    let us_requirements = CountryComplianceRequirements {
        country_code: 'US',
        is_berne_signatory: true,
        automatic_protection: true,
        registration_required: false,
        protection_duration_years: 95, // Different from default
        notice_required: true,
        deposit_required: true,
        translation_rights_duration: 7,
        moral_rights_protected: false,
    };

    start_cheat_caller_address(contract_address, owner_address);
    let success = compliance_dispatcher.set_country_requirements('US', us_requirements);
    stop_cheat_caller_address(contract_address);

    assert!(success, "Setting country requirements should succeed");

    let retrieved = compliance_dispatcher.get_country_requirements('US');
    assert!(retrieved.country_code == 'US', "Wrong country code");
    assert!(retrieved.protection_duration_years == 95, "Wrong protection duration");
    assert!(retrieved.notice_required, "Notice should be required");
    assert!(!retrieved.moral_rights_protected, "Moral rights should not be protected");
}

#[test]
fn test_get_default_country_requirements() {
    let (_, _, _, _, _, _, _, compliance_dispatcher, _, _) = setup_with_compliance();

    // Get requirements for country not explicitly set (should return defaults)
    let default_reqs = compliance_dispatcher.get_country_requirements('FR');

    assert!(default_reqs.country_code == 'FR', "Should set country code");
    assert!(default_reqs.is_berne_signatory, "Default should be Berne signatory");
    assert!(default_reqs.automatic_protection, "Default should have automatic protection");
    assert!(!default_reqs.registration_required, "Default should not require registration");
    assert!(default_reqs.protection_duration_years == 70, "Default should be life + 70");
    assert!(default_reqs.moral_rights_protected, "Default should protect moral rights");
}

#[test]
fn test_get_berne_signatory_countries() {
    let (_, _, _, _, _, _, _, compliance_dispatcher, _, _) = setup_with_compliance();

    let signatories = compliance_dispatcher.get_berne_signatory_countries();

    assert!(signatories.len() > 0, "Should have signatory countries");
    assert!(array_contains(signatories, 'US'), "Should include US");
    assert!(array_contains(signatories, 'UK'), "Should include UK");
    assert!(array_contains(signatories, 'FR'), "Should include France");
    assert!(array_contains(signatories, 'DE'), "Should include Germany");
}

#[test]
fn test_request_compliance_verification() {
    let (
        contract_address, _, asset_dispatcher, _, _, _, _, compliance_dispatcher, _, owner_address,
    ) =
        setup_with_compliance();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];
    let authors = array![creator1, *creators[1]].span();

    start_cheat_caller_address(contract_address, creator1);
    let request_id = compliance_dispatcher
        .request_compliance_verification(
            asset_id,
            ComplianceStatus::BerneCompliant.into(),
            "ipfs://evidence-documentation",
            'US',
            1640995200, // Jan 1, 2022
            WorkType::Musical.into(),
            true,
            authors,
        );
    stop_cheat_caller_address(contract_address);

    assert!(request_id == 1, "First request should have ID 1");

    let request = compliance_dispatcher.get_compliance_verification_request(request_id);
    assert!(request.asset_id == asset_id, "Wrong asset ID");
    assert!(request.requester == creator1, "Wrong requester");
    assert!(
        request.requested_status == ComplianceStatus::BerneCompliant.into(),
        "Wrong requested status",
    );
    assert!(request.country_of_origin == 'US', "Wrong country of origin");
    assert!(request.work_type == WorkType::Musical.into(), "Wrong work type");
    assert!(request.is_original_work, "Should be marked as original");
    assert!(request.authors_count == 2, "Should have 2 authors");
    assert!(!request.is_processed, "Should not be processed initially");

    // Verify authors were stored
    let stored_authors = compliance_dispatcher.get_verification_authors(request_id);
    assert!(stored_authors.len() == 2, "Should have 2 stored authors");
    assert!(array_contains(stored_authors, creator1), "Should contain creator1");
    assert!(array_contains(stored_authors, *creators.at(1)), "Should contain creator2");
}

#[test]
#[should_panic(expected: "Only asset owners can request verification")]
fn test_request_verification_unauthorized() {
    let (
        contract_address, _, asset_dispatcher, _, _, _, _, compliance_dispatcher, _, owner_address,
    ) =
        setup_with_compliance();
    let (asset_id, _, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let non_owner = USER();

    start_cheat_caller_address(contract_address, non_owner);
    compliance_dispatcher
        .request_compliance_verification(
            asset_id,
            ComplianceStatus::BerneCompliant.into(),
            "ipfs://fake",
            'US',
            1640995200,
            WorkType::Musical.into(),
            true,
            array![non_owner].span(),
        );
}

#[test]
fn test_process_compliance_verification_success() {
    let (
        contract_address, _, asset_dispatcher, _, _, _, _, compliance_dispatcher, _, owner_address,
    ) =
        setup_with_compliance();
    let authority_address = register_test_authority(
        contract_address, compliance_dispatcher, owner_address,
    );
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];
    let creator2 = *creators[1];

    // Create verification request
    start_cheat_caller_address(contract_address, creator1);
    let request_id = compliance_dispatcher
        .request_compliance_verification(
            asset_id,
            ComplianceStatus::BerneCompliant.into(),
            "ipfs://evidence",
            'US',
            1640995200,
            WorkType::Musical.into(),
            true,
            array![creator1, creator2].span(),
        );
    stop_cheat_caller_address(contract_address);

    // Process verification as authority
    let auto_countries = array!['US', 'CA', 'UK'].span();
    let manual_countries = array!['DE', 'FR'].span();
    let protection_duration = 70 * 31536000; // 70 years in seconds

    start_cheat_caller_address(contract_address, authority_address);
    let success = compliance_dispatcher
        .process_compliance_verification(
            request_id,
            true,
            "Meets all Berne Convention requirements",
            protection_duration,
            auto_countries,
            manual_countries,
        );
    stop_cheat_caller_address(contract_address);

    assert!(success, "Verification processing should succeed");

    // Verify request was updated
    let updated_request = compliance_dispatcher.get_compliance_verification_request(request_id);
    assert!(updated_request.is_processed, "Request should be processed");
    assert!(updated_request.is_approved, "Request should be approved");
    assert!(
        updated_request.verifier_notes == "Meets all Berne Convention requirements",
        "Wrong verifier notes",
    );

    // Verify compliance record was created
    let compliance_record = compliance_dispatcher.get_compliance_record(asset_id);
    assert!(compliance_record.asset_id == asset_id, "Wrong asset ID in record");
    assert!(
        compliance_record.compliance_status == ComplianceStatus::BerneCompliant.into(),
        "Wrong compliance status",
    );
    assert!(compliance_record.country_of_origin == 'US', "Wrong country of origin");
    assert!(
        compliance_record.registration_authority == authority_address,
        "Wrong registration authority",
    );
    assert!(
        compliance_record.protection_duration == protection_duration, "Wrong protection duration",
    );
    assert!(compliance_record.is_collective_work, "Should be marked as collective work");
    assert!(compliance_record.renewal_required, "Should require renewal");
    assert!(
        compliance_record.automatic_protection_count == 3, "Should have 3 auto-protected countries",
    );
    assert!(
        compliance_record.manual_registration_count == 2,
        "Should have 2 manual registration countries",
    );

    // Verify asset compliance status was updated
    let asset_info = asset_dispatcher.get_asset_info(asset_id);
    assert!(
        asset_info.compliance_status == ComplianceStatus::BerneCompliant.into(),
        "Asset status should be updated",
    );

    // Verify countries were stored correctly
    let stored_auto = compliance_dispatcher.get_automatic_protection_countries(asset_id);
    let stored_manual = compliance_dispatcher.get_manual_registration_countries(asset_id);

    assert!(stored_auto.len() == 3, "Should have 3 automatic protection countries");
    assert!(array_contains(stored_auto, 'US'), "Should include US in automatic");
    assert!(stored_manual.len() == 2, "Should have 2 manual registration countries");
    assert!(array_contains(stored_manual, 'DE'), "Should include DE in manual");

    // Verify authority stats updated
    let updated_authority = compliance_dispatcher.get_compliance_authority(authority_address);
    assert!(updated_authority.verification_count == 1, "Authority should have 1 verification");
}

#[test]
#[should_panic(expected: "Not an active compliance authority")]
fn test_process_verification_unauthorized() {
    let (
        contract_address, _, asset_dispatcher, _, _, _, _, compliance_dispatcher, _, owner_address,
    ) =
        setup_with_compliance();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];
    let non_authority = USER();

    // Create verification request
    start_cheat_caller_address(contract_address, creator1);
    let request_id = compliance_dispatcher
        .request_compliance_verification(
            asset_id,
            ComplianceStatus::BerneCompliant.into(),
            "ipfs://evidence",
            'US',
            1640995200,
            WorkType::Musical.into(),
            true,
            array![creator1].span(),
        );
    stop_cheat_caller_address(contract_address);

    // Try to process as non-authority
    start_cheat_caller_address(contract_address, non_authority);
    compliance_dispatcher
        .process_compliance_verification(
            request_id, true, "Unauthorized approval", 0, array![].span(), array![].span(),
        );
}

#[test]
fn test_check_protection_validity() {
    let (
        contract_address, _, asset_dispatcher, _, _, _, _, compliance_dispatcher, _, owner_address,
    ) =
        setup_with_compliance();
    let authority_address = register_test_authority(
        contract_address, compliance_dispatcher, owner_address,
    );
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );

    // Create and approve compliance verification
    let request_id = create_and_approve_verification(
        contract_address, compliance_dispatcher, asset_id, *creators[0], authority_address,
    );

    // Should have protection in US (automatic)
    assert!(
        compliance_dispatcher.check_protection_validity(asset_id, 'US'),
        "Should have protection in US",
    );

    // Should not have protection in non-registered country
    assert!(
        !compliance_dispatcher.check_protection_validity(asset_id, 'JP'),
        "Should not have protection in JP",
    );

    // Register international protection for JP
    start_cheat_caller_address(contract_address, *creators[0]);
    compliance_dispatcher
        .register_international_protection(
            asset_id, array!['JP'].span(), array!["ipfs://jp-registration"].span(),
        );
    stop_cheat_caller_address(contract_address);

    // Now should have protection in JP
    assert!(
        compliance_dispatcher.check_protection_validity(asset_id, 'JP'),
        "Should have protection in JP after registration",
    );
}

#[test]
fn test_protection_duration_calculation() {
    let (_, _, _, _, _, _, _, compliance_dispatcher, _, _) = setup_with_compliance();

    // Test standard duration calculation
    let duration = compliance_dispatcher
        .calculate_protection_duration('US', WorkType::Musical.into(), 1640995200, false);

    let expected_duration = 70 * 31536000; // 70 years in seconds
    assert!(duration == expected_duration, "Wrong protection duration calculated");

    // Test anonymous work duration
    let anonymous_duration = compliance_dispatcher
        .calculate_protection_duration('US', WorkType::Musical.into(), 1640995200, true);

    let expected_anonymous = 70 * 31536000; // 70 years for anonymous
    assert!(anonymous_duration == expected_anonymous, "Wrong anonymous work duration");
}

#[test]
fn test_renewal_requirements() {
    let (
        contract_address, _, asset_dispatcher, _, _, _, _, compliance_dispatcher, _, owner_address,
    ) =
        setup_with_compliance();
    let authority_address = register_test_authority(
        contract_address, compliance_dispatcher, owner_address,
    );
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];

    start_cheat_block_timestamp(contract_address, 100);

    // Create and approve verification with finite protection
    create_and_approve_verification(
        contract_address, compliance_dispatcher, asset_id, creator1, authority_address,
    );

    let (renewal_required, deadline) = compliance_dispatcher.check_renewal_requirements(asset_id);
    assert!(renewal_required, "Renewal should be required");
    assert!(deadline > get_block_timestamp(), "Deadline should be in the future");

    start_cheat_block_timestamp(contract_address, deadline);

    // Test renewal
    start_cheat_caller_address(contract_address, creator1);
    let success = compliance_dispatcher.renew_protection(asset_id, "ipfs://renewal-evidence");
    stop_cheat_caller_address(contract_address);

    assert!(success, "Renewal should succeed");

    let (_, new_deadline) = compliance_dispatcher.check_renewal_requirements(asset_id);
    assert!(new_deadline > deadline, "New deadline should be extended");
}

#[test]
fn test_validate_license_compliance() {
    let (
        contract_address, _, asset_dispatcher, _, _, _, _, compliance_dispatcher, _, owner_address,
    ) =
        setup_with_compliance();
    let authority_address = register_test_authority(
        contract_address, compliance_dispatcher, owner_address,
    );
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );

    // Create compliant asset
    create_and_approve_verification(
        contract_address, compliance_dispatcher, asset_id, *creators[0], authority_address,
    );

    // Should be valid for US territory
    let is_valid = compliance_dispatcher
        .validate_license_compliance(asset_id, 'US', 'US', 'COMMERCIAL');
    assert!(is_valid, "License should be valid for protected territory");

    // Should not be valid for unprotected territory
    let is_invalid = compliance_dispatcher
        .validate_license_compliance(asset_id, 'JP', 'JP', 'COMMERCIAL');
    assert!(!is_invalid, "License should not be valid for unprotected territory");
}

#[test]
fn test_get_licensing_restrictions() {
    let (
        contract_address, _, asset_dispatcher, _, _, _, _, compliance_dispatcher, _, owner_address,
    ) =
        setup_with_compliance();
    let authority_address = register_test_authority(
        contract_address, compliance_dispatcher, owner_address,
    );
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );

    // Set US requirements with notice requirement
    let us_reqs = CountryComplianceRequirements {
        country_code: 'US',
        is_berne_signatory: true,
        automatic_protection: true,
        registration_required: false,
        protection_duration_years: 95,
        notice_required: true,
        deposit_required: false,
        translation_rights_duration: 7,
        moral_rights_protected: false,
    };

    start_cheat_caller_address(contract_address, owner_address);
    compliance_dispatcher.set_country_requirements('US', us_reqs);
    stop_cheat_caller_address(contract_address);

    // Create compliant asset
    create_and_approve_verification(
        contract_address, compliance_dispatcher, asset_id, *creators[0], authority_address,
    );

    let restrictions = compliance_dispatcher.get_licensing_restrictions(asset_id, 'US');
    assert!(restrictions.len() > 0, "Should have restrictions");
    assert!(array_contains(restrictions, 'NOTICE_REQUIRED'), "Should require notice");
    assert!(array_contains(restrictions, 'NO_MORAL_RIGHTS'), "Should indicate no moral rights");
}

#[test]
fn test_mark_protection_expired() {
    let (
        contract_address, _, asset_dispatcher, _, _, _, _, compliance_dispatcher, _, owner_address,
    ) =
        setup_with_compliance();
    let authority_address = register_test_authority(
        contract_address, compliance_dispatcher, owner_address,
    );
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );

    // Create compliant asset
    create_and_approve_verification(
        contract_address, compliance_dispatcher, asset_id, *creators[0], authority_address,
    );

    // Initially should be compliant
    let initial_record = compliance_dispatcher.get_compliance_record(asset_id);
    assert!(
        initial_record.compliance_status == ComplianceStatus::BerneCompliant.into(),
        "Should be initially compliant",
    );

    // Mark as expired
    start_cheat_caller_address(contract_address, authority_address);
    let success = compliance_dispatcher.mark_protection_expired(asset_id);
    stop_cheat_caller_address(contract_address);

    assert!(success, "Marking expired should succeed");

    // Should now be non-compliant
    let expired_record = compliance_dispatcher.get_compliance_record(asset_id);
    assert!(
        expired_record.compliance_status == ComplianceStatus::NonCompliant.into(),
        "Should be non-compliant after expiry",
    );

    // Asset info should also be updated
    let asset_info = asset_dispatcher.get_asset_info(asset_id);
    assert!(
        asset_info.compliance_status == ComplianceStatus::NonCompliant.into(),
        "Asset status should be updated",
    );
}

#[test]
fn test_public_domain_detection() {
    let (
        contract_address, _, asset_dispatcher, _, _, _, _, compliance_dispatcher, _, owner_address,
    ) =
        setup_with_compliance();
    let authority_address = register_test_authority(
        contract_address, compliance_dispatcher, owner_address,
    );
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );

    // Create verification with very short protection
    start_cheat_caller_address(contract_address, *creators[0]);
    let request_id = compliance_dispatcher
        .request_compliance_verification(
            asset_id,
            ComplianceStatus::BerneCompliant.into(),
            "ipfs://evidence",
            'US',
            50,
            WorkType::Musical.into(),
            true,
            array![*creators[0]].span(),
        );
    stop_cheat_caller_address(contract_address);

    // Approve with very short protection
    start_cheat_caller_address(contract_address, authority_address);
    compliance_dispatcher
        .process_compliance_verification(
            request_id,
            true,
            "Short protection for testing",
            5, // 5 second protection
            array!['US'].span(),
            array![].span(),
        );
    stop_cheat_caller_address(contract_address);

    // Fast forward past protection period
    start_cheat_block_timestamp(contract_address, 100);

    // Should now be in public domain
    let is_public_domain = compliance_dispatcher.is_work_in_public_domain(asset_id, 'US');
    assert!(is_public_domain, "Work should be in public domain after protection expires");

    stop_cheat_block_timestamp(contract_address);
}
