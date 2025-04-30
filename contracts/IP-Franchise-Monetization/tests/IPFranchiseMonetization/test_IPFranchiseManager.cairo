use crate::utils::*;

use ip_franchise_monetization::interfaces::{
    IIPFranchiseAgreementDispatcherTrait, IIPFranchiseAgreementDispatcher,
    IIPFranchiseManagerDispatcherTrait,
};

use ip_franchise_monetization::types::{PaymentModel, ExclusivityType, ApplicationStatus};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};

use snforge_std::{cheat_caller_address, CheatSpan, mock_call};

use openzeppelin_token::erc721::interface::IERC721DispatcherTrait;

#[test]
fn test_initialization_succesful() {
    let TestContracts { manager_contract, erc20_token: _, erc721_token } = initialize_contracts();
    let token_id = manager_contract.get_ip_nft_id();
    let token_address = manager_contract.get_ip_nft_address();
    let owner = IOwnableDispatcher { contract_address: manager_contract.contract_address }.owner();
    let preferred_payment = manager_contract.get_preferred_payment_model();
    let default_fee = manager_contract.get_default_franchise_fee();
    assert!(token_id == 1, "token id should match");
    assert!(token_address == erc721_token.contract_address, "token address should match");
    assert!(owner == OWNER(), "owner should match");
    assert!(preferred_payment == PaymentModel::OneTime(20000), "payment model should match");
    assert!(default_fee == 500, "franchise fee should match");
}

#[test]
fn test_link_ip() {
    let TestContracts { manager_contract, erc20_token: _, erc721_token } = initialize_contracts();
    let token_id = manager_contract.get_ip_nft_id();

    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    manager_contract.link_ip_asset();

    let owner = erc721_token.owner_of(token_id);

    assert!(manager_contract.is_ip_asset_linked(), "ip asset linking failed");
    assert!(manager_contract.contract_address == owner, "manager contract should own ip asset");
}

#[test]
fn test_unlink_ip() {
    let TestContracts { manager_contract, erc20_token: _, erc721_token } = initialize_contracts();
    let token_id = manager_contract.get_ip_nft_id();

    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(2));
    manager_contract.link_ip_asset();
    manager_contract.unlink_ip_asset();

    let owner = erc721_token.owner_of(token_id);
    assert!(!manager_contract.is_ip_asset_linked(), "ip asset still linked");
    assert!(OWNER() == owner, "owner should get ip asset");
}

#[test]
fn test_add_teritories() {
    let TestContracts { manager_contract, erc20_token: _, erc721_token } = initialize_contracts();
    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(2));
    manager_contract.link_ip_asset();

    manager_contract.add_franchise_territory("Lagos");

    let territory_id = 0;

    let territory = manager_contract.get_territory_info(territory_id);
    assert!(territory.name == "Lagos", "territory name should match");
    assert!(territory.active, "territory should be active");
    assert!(territory.exclusive_to_agreement == Option::None, "exclusivity should match");
}

#[test]
fn test_deactivate_teritories() {
    let TestContracts { manager_contract, erc20_token: _, erc721_token } = initialize_contracts();
    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(3));
    manager_contract.link_ip_asset();
    manager_contract.add_franchise_territory("Lagos");

    let territory_id = 0;
    manager_contract.deactivate_franchise_territory(territory_id);

    let territory = manager_contract.get_territory_info(territory_id);
    assert!(territory.name == "Lagos", "territory name should match");
    assert!(!territory.active, "territory should be active");
    assert!(territory.exclusive_to_agreement == Option::None, "exclusivity should match");
}

#[test]
fn test_create_agreement_direct() {
    let TestContracts { manager_contract, erc20_token, erc721_token } = initialize_contracts();
    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(3));
    manager_contract.link_ip_asset();
    manager_contract.add_franchise_territory("Lagos");

    let franchise_terms = dummy_franchise_terms(erc20_token.contract_address);

    manager_contract.create_direct_franchise_agreement(FRANCHISEE(), franchise_terms.clone());

    let total_agreeements = manager_contract.get_total_franchise_agreements();

    assert!(total_agreeements == 1, "franchise agreements should match");

    let agreement_id = total_agreeements - 1;
    let franchise_address = manager_contract.get_franchise_agreement_address(agreement_id);

    let franchise_agreement = IIPFranchiseAgreementDispatcher {
        contract_address: franchise_address,
    };

    assert!(
        franchise_agreement.get_agreement_id() == agreement_id,
        "franchise agreement id should match",
    );
    assert!(
        franchise_agreement.get_franchise_manager() == manager_contract.contract_address,
        "franchise agreement manager should match",
    );

    let actual_franchise_terms = franchise_agreement.get_franchise_terms();
    assert!(
        actual_franchise_terms.payment_model == franchise_terms.payment_model,
        "franchise payment model should match",
    );
    assert!(!franchise_agreement.is_active(), "franchise agreement not active");
}

#[test]
fn test_apply_for_franchise() {
    let TestContracts { manager_contract, erc20_token, erc721_token } = initialize_contracts();
    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(2));
    manager_contract.link_ip_asset();
    manager_contract.add_franchise_territory("Lagos");

    let franchise_terms = dummy_franchise_terms(erc20_token.contract_address);

    cheat_caller_address(
        manager_contract.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(2),
    );
    manager_contract.apply_for_franchise(franchise_terms.clone());

    let total_agreements = manager_contract.get_total_franchise_applications();
    let application_id = total_agreements - 1;

    let latest_version = manager_contract.get_franchise_application_version(application_id);

    let application = manager_contract.get_franchise_application(application_id, latest_version);

    assert!(application.franchisee == FRANCHISEE(), "application franchisee should match");

    let actual_franchise_terms = application.current_terms;
    assert!(
        actual_franchise_terms.payment_model == franchise_terms.payment_model,
        "application payment model should match",
    );
    assert!(application.status == ApplicationStatus::Pending, "application status should match");
}

#[test]
fn test_reject_franchise_application() {
    let TestContracts { manager_contract, erc20_token, erc721_token } = initialize_contracts();
    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(2));
    manager_contract.link_ip_asset();
    manager_contract.add_franchise_territory("Lagos");

    let franchise_terms = dummy_franchise_terms(erc20_token.contract_address);

    cheat_caller_address(
        manager_contract.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(2),
    );
    manager_contract.apply_for_franchise(franchise_terms.clone());

    let total_agreements = manager_contract.get_total_franchise_applications();
    let application_id = total_agreements - 1;

    let latest_version = manager_contract.get_franchise_application_version(application_id);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    manager_contract.reject_franchise_application(application_id);

    let application = manager_contract.get_franchise_application(application_id, latest_version);

    assert!(
        application.status == ApplicationStatus::Rejected, "application status should
    match",
    );
}

#[test]
fn test_approve_franchise_application() {
    let TestContracts { manager_contract, erc20_token, erc721_token } = initialize_contracts();
    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(2));
    manager_contract.link_ip_asset();
    manager_contract.add_franchise_territory("Lagos");

    let franchise_terms = dummy_franchise_terms(erc20_token.contract_address);

    cheat_caller_address(
        manager_contract.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(2),
    );
    manager_contract.apply_for_franchise(franchise_terms.clone());

    let total_agreements = manager_contract.get_total_franchise_applications();
    let application_id = total_agreements - 1;

    let latest_version = manager_contract.get_franchise_application_version(application_id);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    manager_contract.approve_franchise_application(application_id);

    let application = manager_contract.get_franchise_application(application_id, latest_version);

    assert!(
        application.status == ApplicationStatus::Approved, "application status should
    match",
    );
}

#[test]
fn test_revise_franchise_application_owner() {
    let TestContracts { manager_contract, erc20_token, erc721_token } = initialize_contracts();
    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(2));
    manager_contract.link_ip_asset();
    manager_contract.add_franchise_territory("Lagos");

    let mut franchise_terms = dummy_franchise_terms(erc20_token.contract_address);

    cheat_caller_address(
        manager_contract.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(2),
    );
    manager_contract.apply_for_franchise(franchise_terms.clone());

    let total_agreements = manager_contract.get_total_franchise_applications();
    let application_id = total_agreements - 1;

    let prev_version = manager_contract.get_franchise_application_version(application_id);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(1));

    franchise_terms.payment_model = PaymentModel::OneTime(1000000);
    franchise_terms.franchise_fee = 40000;

    manager_contract.revise_franchise_application(application_id, franchise_terms.clone());

    let latest_version = manager_contract.get_franchise_application_version(application_id);

    assert!(latest_version == prev_version + 1, "application version should increment");

    let application = manager_contract.get_franchise_application(application_id, latest_version);

    assert!(application.status == ApplicationStatus::Revised, "application status should match");

    assert!(application.last_proposed_by == OWNER(), "application last updater should be owner");

    let actual_franchise_terms = application.current_terms;

    assert!(
        actual_franchise_terms.payment_model == PaymentModel::OneTime(1000000),
        "application payment model should match",
    );

    assert!(
        actual_franchise_terms.franchise_fee == 40000, "application franchise fee should match",
    );
}

#[test]
fn test_revise_franchise_application_franchisee() {
    let TestContracts { manager_contract, erc20_token, erc721_token } = initialize_contracts();
    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(2));
    manager_contract.link_ip_asset();
    manager_contract.add_franchise_territory("Lagos");

    let mut franchise_terms = dummy_franchise_terms(erc20_token.contract_address);

    cheat_caller_address(
        manager_contract.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(2),
    );
    manager_contract.apply_for_franchise(franchise_terms.clone());

    let total_agreements = manager_contract.get_total_franchise_applications();
    let application_id = total_agreements - 1;

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(1));

    franchise_terms.payment_model = PaymentModel::OneTime(1000000);

    manager_contract.revise_franchise_application(application_id, franchise_terms.clone());

    let prev_version = manager_contract.get_franchise_application_version(application_id);

    cheat_caller_address(
        manager_contract.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );

    franchise_terms.payment_model = PaymentModel::OneTime(50000);
    franchise_terms.franchise_fee = 40;

    manager_contract.revise_franchise_application(application_id, franchise_terms);

    let latest_version = manager_contract.get_franchise_application_version(application_id);

    assert!(latest_version == prev_version + 1, "application version should increment");

    let application = manager_contract.get_franchise_application(application_id, latest_version);

    assert!(application.status == ApplicationStatus::Revised, "application status should match");

    assert!(
        application.last_proposed_by == FRANCHISEE(),
        "application last updater should be franchisee",
    );

    let actual_franchise_terms = application.current_terms;

    assert!(
        actual_franchise_terms.payment_model == PaymentModel::OneTime(50000),
        "application payment model should match",
    );

    assert!(actual_franchise_terms.franchise_fee == 40, "application franchise fee should match");
}

#[test]
fn test_accept_franchise_application_revision_franchisee() {
    let TestContracts { manager_contract, erc20_token, erc721_token } = initialize_contracts();
    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(2));
    manager_contract.link_ip_asset();
    manager_contract.add_franchise_territory("Lagos");

    let mut franchise_terms = dummy_franchise_terms(erc20_token.contract_address);

    cheat_caller_address(
        manager_contract.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(2),
    );
    manager_contract.apply_for_franchise(franchise_terms.clone());

    let total_agreements = manager_contract.get_total_franchise_applications();
    let application_id = total_agreements - 1;

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(1));

    franchise_terms.payment_model = PaymentModel::OneTime(1000000);
    franchise_terms.exclusivity == ExclusivityType::Exclusive;

    manager_contract.revise_franchise_application(application_id, franchise_terms.clone());

    cheat_caller_address(
        manager_contract.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );
    manager_contract.accept_franchise_application_revision(application_id);

    let latest_version = manager_contract.get_franchise_application_version(application_id);

    let application = manager_contract.get_franchise_application(application_id, latest_version);

    assert!(
        application.status == ApplicationStatus::RevisionAccepted,
        "application status should match",
    );
}


#[test]
fn test_create_franchise_agreement_from_application() {
    let TestContracts { manager_contract, erc20_token, erc721_token } = initialize_contracts();
    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(2));
    manager_contract.link_ip_asset();
    manager_contract.add_franchise_territory("Lagos");

    let mut franchise_terms = dummy_franchise_terms(erc20_token.contract_address);

    cheat_caller_address(
        manager_contract.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(2),
    );
    manager_contract.apply_for_franchise(franchise_terms.clone());

    let total_agreements = manager_contract.get_total_franchise_applications();
    let application_id = total_agreements - 1;

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(2));

    manager_contract.approve_franchise_application(application_id);

    manager_contract.create_franchise_agreement_from_application(application_id);

    let total_agreeements = manager_contract.get_total_franchise_agreements();

    assert!(total_agreeements == 1, "franchise agreements should match");

    let agreement_id = total_agreeements - 1;
    let franchise_address = manager_contract.get_franchise_agreement_address(agreement_id);

    let franchise_agreement = IIPFranchiseAgreementDispatcher {
        contract_address: franchise_address,
    };

    assert!(
        franchise_agreement.get_agreement_id() == agreement_id,
        "franchise agreement id should match",
    );
    assert!(
        franchise_agreement.get_franchise_manager() == manager_contract.contract_address,
        "franchise agreement manager should match",
    );

    let actual_franchise_terms = franchise_agreement.get_franchise_terms();
    assert!(
        actual_franchise_terms.payment_model == franchise_terms.payment_model,
        "franchise payment model should match",
    );
    assert!(!franchise_agreement.is_active(), "franchise agreement not active");
}

#[test]
fn test_initiate_franchise_sale_works() {
    let TestContracts { manager_contract, erc20_token, erc721_token } = initialize_contracts();
    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(3));
    manager_contract.link_ip_asset();
    manager_contract.add_franchise_territory("Lagos");

    let franchise_terms = dummy_franchise_terms(erc20_token.contract_address);

    manager_contract.create_direct_franchise_agreement(FRANCHISEE(), franchise_terms.clone());

    let total_agreeements = manager_contract.get_total_franchise_agreements();

    assert!(total_agreeements == 1, "franchise agreements should match");

    let agreement_id = total_agreeements - 1;
    let franchise_address = manager_contract.get_franchise_agreement_address(agreement_id);

    cheat_caller_address(
        manager_contract.contract_address, franchise_address, CheatSpan::TargetCalls(3),
    );

    manager_contract.initiate_franchise_sale(agreement_id);

    let is_listed = manager_contract.is_franchise_sale_requested(agreement_id);

    assert!(is_listed, "franchise should be listed for sale");
}

#[test]
fn test_approve_franchise_sale() {
    let TestContracts { manager_contract, erc20_token, erc721_token } = initialize_contracts();
    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(3));
    manager_contract.link_ip_asset();
    manager_contract.add_franchise_territory("Lagos");

    let franchise_terms = dummy_franchise_terms(erc20_token.contract_address);

    manager_contract.create_direct_franchise_agreement(FRANCHISEE(), franchise_terms.clone());

    let total_agreeements = manager_contract.get_total_franchise_agreements();

    assert!(total_agreeements == 1, "franchise agreements should match");

    let agreement_id = total_agreeements - 1;
    let franchise_address = manager_contract.get_franchise_agreement_address(agreement_id);

    cheat_caller_address(
        manager_contract.contract_address, franchise_address, CheatSpan::TargetCalls(3),
    );

    manager_contract.initiate_franchise_sale(agreement_id);

    let is_listed = manager_contract.is_franchise_sale_requested(agreement_id);

    assert!(is_listed, "franchise should be listed for sale");

    mock_call(franchise_address, selector!("approve_franchise_sale"), (), 1);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    manager_contract.approve_franchise_sale(agreement_id);
}


#[test]
fn test_reject_franchise_sale() {
    let TestContracts { manager_contract, erc20_token, erc721_token } = initialize_contracts();
    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(3));
    manager_contract.link_ip_asset();
    manager_contract.add_franchise_territory("Lagos");

    let franchise_terms = dummy_franchise_terms(erc20_token.contract_address);

    manager_contract.create_direct_franchise_agreement(FRANCHISEE(), franchise_terms.clone());

    let total_agreeements = manager_contract.get_total_franchise_agreements();

    assert!(total_agreeements == 1, "franchise agreements should match");

    let agreement_id = total_agreeements - 1;
    let franchise_address = manager_contract.get_franchise_agreement_address(agreement_id);

    cheat_caller_address(
        manager_contract.contract_address, franchise_address, CheatSpan::TargetCalls(3),
    );

    manager_contract.initiate_franchise_sale(agreement_id);

    let is_listed = manager_contract.is_franchise_sale_requested(agreement_id);

    assert!(is_listed, "franchise should be listed for sale");

    mock_call(franchise_address, selector!("reject_franchise_sale"), (), 1);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    manager_contract.reject_franchise_sale(agreement_id);
}

#[test]
fn test_revoke_franchise_license() {
    let TestContracts { manager_contract, erc20_token, erc721_token } = initialize_contracts();
    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(3));
    manager_contract.link_ip_asset();
    manager_contract.add_franchise_territory("Lagos");

    let franchise_terms = dummy_franchise_terms(erc20_token.contract_address);

    manager_contract.create_direct_franchise_agreement(FRANCHISEE(), franchise_terms.clone());

    let total_agreeements = manager_contract.get_total_franchise_agreements();

    assert!(total_agreeements == 1, "franchise agreements should match");

    let agreement_id = total_agreeements - 1;
    let franchise_address = manager_contract.get_franchise_agreement_address(agreement_id);

    mock_call(franchise_address, selector!("revoke_franchise_license"), (), 1);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    manager_contract.revoke_franchise_license(agreement_id);
}

#[test]
fn test_reinstate_franchise_license() {
    let TestContracts { manager_contract, erc20_token, erc721_token } = initialize_contracts();
    cheat_caller_address(erc721_token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721_token.set_approval_for_all(manager_contract.contract_address, true);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(3));
    manager_contract.link_ip_asset();
    manager_contract.add_franchise_territory("Lagos");

    let franchise_terms = dummy_franchise_terms(erc20_token.contract_address);

    manager_contract.create_direct_franchise_agreement(FRANCHISEE(), franchise_terms.clone());

    let total_agreeements = manager_contract.get_total_franchise_agreements();

    assert!(total_agreeements == 1, "franchise agreements should match");

    let agreement_id = total_agreeements - 1;
    let franchise_address = manager_contract.get_franchise_agreement_address(agreement_id);

    mock_call(franchise_address, selector!("reinstate_franchise_license"), (), 1);

    cheat_caller_address(manager_contract.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    manager_contract.reinstate_franchise_license(agreement_id);
}

