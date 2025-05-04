use crate::utils::*;

use ip_franchise_monetization::interfaces::{IIPFranchiseAgreementDispatcherTrait};
use snforge_std::{cheat_caller_address, CheatSpan, mock_call, start_cheat_block_timestamp_global};

use ip_franchise_monetization::types::{FranchiseSaleStatus};
use ip_franchise_monetization::interfaces::{FranchiseTermsTrait};
use openzeppelin_token::erc20::interface::{IERC20DispatcherTrait};

#[test]
fn test_activate_agreement_one_time_fee() {
    let test_contracts = initialize_contracts();
    let franchise_agreement = deploy_agreement_contract_fixed_fee(test_contracts.clone());

    let TestContracts {
        manager_contract, erc20_token: erc20_token, erc721_token: _,
    } = test_contracts;

    let activation_fee = franchise_agreement.get_activation_fee();

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, FRANCHISEE(), activation_fee);

    cheat_caller_address(erc20_token.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1));
    // approve tokens
    erc20_token.approve(franchise_agreement.contract_address, activation_fee);

    // call the franchise_agreement contract
    cheat_caller_address(
        franchise_agreement.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );
    franchise_agreement.activate_franchise();

    assert!(franchise_agreement.is_active(), "agreement should be active now");

    let manager_balance = erc20_token.balance_of(manager_contract.contract_address);
    assert!(manager_balance == activation_fee, "manager balance should be incremented");
}

#[test]
fn test_activate_agreement_royalty_fee() {
    let test_contracts = initialize_contracts();

    let franchise_agreement = deploy_agreement_contract_royalty_based(test_contracts.clone());
    let TestContracts {
        manager_contract, erc20_token: erc20_token, erc721_token: _,
    } = test_contracts;

    let activation_fee = franchise_agreement.get_activation_fee();

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, FRANCHISEE(), activation_fee);

    cheat_caller_address(erc20_token.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1));
    // approve tokens
    erc20_token.approve(franchise_agreement.contract_address, activation_fee);

    // call the franchise_agreement contract
    cheat_caller_address(
        franchise_agreement.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );
    franchise_agreement.activate_franchise();

    assert!(franchise_agreement.is_active(), "agreement should be active now");

    let manager_balance = erc20_token.balance_of(manager_contract.contract_address);
    assert!(manager_balance == activation_fee, "manager balance should be incremented");
}

#[test]
fn test_create_sale_request() {
    let test_contracts = initialize_contracts();

    let franchise_agreement = deploy_agreement_contract_royalty_based(test_contracts.clone());
    let TestContracts {
        manager_contract, erc20_token: erc20_token, erc721_token: _,
    } = test_contracts;

    // mint tokens to franchisee
    let activation_fee = franchise_agreement.get_activation_fee();

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, FRANCHISEE(), activation_fee);

    cheat_caller_address(erc20_token.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1));
    // approve tokens
    erc20_token.approve(franchise_agreement.contract_address, activation_fee);

    // call the franchise_agreement contract
    cheat_caller_address(
        franchise_agreement.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );
    franchise_agreement.activate_franchise();

    assert!(franchise_agreement.is_active(), "agreement should be active now");

    mock_call(manager_contract.contract_address, selector!("initiate_franchise_sale"), (), 1);

    cheat_caller_address(
        franchise_agreement.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );
    franchise_agreement.create_sale_request(BUYER(), 5000);

    let sale_request = franchise_agreement.get_sale_request();

    assert!(sale_request.is_some(), "agreement sale request is set");
}

#[test]
fn test_approve_sale_request_manager() {
    let test_contracts = initialize_contracts();

    let franchise_agreement = deploy_agreement_contract_royalty_based(test_contracts.clone());
    let TestContracts {
        manager_contract, erc20_token: erc20_token, erc721_token: _,
    } = test_contracts;

    let activation_fee = franchise_agreement.get_activation_fee();

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, FRANCHISEE(), activation_fee);

    cheat_caller_address(erc20_token.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1));
    // approve tokens
    erc20_token.approve(franchise_agreement.contract_address, activation_fee);

    // call the franchise_agreement contract
    cheat_caller_address(
        franchise_agreement.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );
    franchise_agreement.activate_franchise();

    assert!(franchise_agreement.is_active(), "agreement should be active now");

    mock_call(manager_contract.contract_address, selector!("initiate_franchise_sale"), (), 1);

    cheat_caller_address(
        franchise_agreement.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );
    franchise_agreement.create_sale_request(BUYER(), 5000);

    let sale_request = franchise_agreement.get_sale_request();

    assert!(sale_request.is_some(), "agreement sale request is set");

    cheat_caller_address(
        franchise_agreement.contract_address,
        manager_contract.contract_address,
        CheatSpan::TargetCalls(1),
    );
    franchise_agreement.approve_franchise_sale();

    assert!(sale_request.is_some(), "agreement sale request is set");
}

#[test]
fn test_rejected_sale_request_manager() {
    let test_contracts = initialize_contracts();

    let franchise_agreement = deploy_agreement_contract_royalty_based(test_contracts.clone());
    let TestContracts {
        manager_contract, erc20_token: erc20_token, erc721_token: _,
    } = test_contracts;

    let activation_fee = franchise_agreement.get_activation_fee();

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, FRANCHISEE(), activation_fee);

    cheat_caller_address(erc20_token.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1));
    // approve tokens
    erc20_token.approve(franchise_agreement.contract_address, activation_fee);

    // call the franchise_agreement contract
    cheat_caller_address(
        franchise_agreement.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );
    franchise_agreement.activate_franchise();

    assert!(franchise_agreement.is_active(), "agreement should be active now");

    mock_call(manager_contract.contract_address, selector!("initiate_franchise_sale"), (), 1);

    cheat_caller_address(
        franchise_agreement.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );
    franchise_agreement.create_sale_request(BUYER(), 5000);

    let sale_request = franchise_agreement.get_sale_request();

    assert!(sale_request.is_some(), "agreement sale request is set");

    cheat_caller_address(
        franchise_agreement.contract_address,
        manager_contract.contract_address,
        CheatSpan::TargetCalls(1),
    );
    franchise_agreement.reject_franchise_sale();

    assert!(sale_request.is_some(), "agreement sale request is set");
}

#[test]
fn test_finalize_sale_request_buyer() {
    let test_contracts = initialize_contracts();

    let franchise_agreement = deploy_agreement_contract_royalty_based(test_contracts.clone());
    let TestContracts {
        manager_contract, erc20_token: erc20_token, erc721_token: _,
    } = test_contracts;

    let activation_fee = franchise_agreement.get_activation_fee();

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, FRANCHISEE(), activation_fee);

    cheat_caller_address(erc20_token.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1));
    // approve tokens
    erc20_token.approve(franchise_agreement.contract_address, activation_fee);
    // call the franchise_agreement contract
    cheat_caller_address(
        franchise_agreement.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );
    franchise_agreement.activate_franchise();

    assert!(franchise_agreement.is_active(), "agreement should be active now");

    mock_call(manager_contract.contract_address, selector!("initiate_franchise_sale"), (), 1);

    cheat_caller_address(
        franchise_agreement.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );
    franchise_agreement.create_sale_request(BUYER(), 5000);

    let sale_request = franchise_agreement.get_sale_request();

    assert!(sale_request.is_some(), "agreement sale request is set");

    cheat_caller_address(
        franchise_agreement.contract_address,
        manager_contract.contract_address,
        CheatSpan::TargetCalls(1),
    );
    franchise_agreement.approve_franchise_sale();

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, BUYER(), 10000);

    // approve tokens
    cheat_caller_address(erc20_token.contract_address, BUYER(), CheatSpan::TargetCalls(1));
    erc20_token.approve(franchise_agreement.contract_address, 5000);

    cheat_caller_address(franchise_agreement.contract_address, BUYER(), CheatSpan::TargetCalls(1));
    franchise_agreement.finalize_franchise_sale();

    let sale_request = franchise_agreement.get_sale_request().unwrap();
    assert!(sale_request.status == FranchiseSaleStatus::Completed, "not completed")
}

#[test]
fn test_pay_royalty() {
    let test_contracts = initialize_contracts();

    let franchise_agreement = deploy_agreement_contract_royalty_based(test_contracts.clone());
    let TestContracts {
        manager_contract, erc20_token: erc20_token, erc721_token: _,
    } = test_contracts;

    let activation_fee = franchise_agreement.get_activation_fee();

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, FRANCHISEE(), activation_fee);

    cheat_caller_address(erc20_token.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1));

    // approve tokens
    erc20_token.approve(franchise_agreement.contract_address, activation_fee);

    // call the franchise_agreement contract
    cheat_caller_address(
        franchise_agreement.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );
    franchise_agreement.activate_franchise();

    assert!(franchise_agreement.is_active(), "agreement should be active now");

    // MONTHLY ROYALTY
    let one_month = 30 * 24 * 60 * 60;

    let one_day = 24 * 60 * 60;

    // Increase block timestamps

    start_cheat_block_timestamp_global(one_month + one_day);

    // Should be time for first royalty payment

    let franchise_terms = franchise_agreement.get_franchise_terms();
    let no_of_missed_payments = franchise_agreement.get_total_missed_payments();

    assert!(no_of_missed_payments == 1, "missed payments not properly calculated");

    let last_month_revenue = 10_000_000;

    let expected_payment = last_month_revenue * 10 / 100; // 10% according to payment model

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, FRANCHISEE(), expected_payment);

    cheat_caller_address(erc20_token.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1));

    // approve tokens
    erc20_token.approve(franchise_agreement.contract_address, expected_payment);

    cheat_caller_address(
        franchise_agreement.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );

    // structure revenue
    let mut revenues = ArrayTrait::<u256>::new();

    revenues.append(last_month_revenue);

    let prev_last_payment_id = franchise_terms.get_last_payment_id();

    // trigger function call
    franchise_agreement.make_royalty_payments(revenues);

    let updated_franchise_terms = franchise_agreement.get_franchise_terms();

    let manager_balance = erc20_token.balance_of(manager_contract.contract_address);
    assert!(
        manager_balance == activation_fee + expected_payment,
        "manager balance should be incremented",
    );

    let curr_last_payment_id = updated_franchise_terms.get_last_payment_id();

    assert!(curr_last_payment_id == prev_last_payment_id + 1, "payment id should increase");
}

