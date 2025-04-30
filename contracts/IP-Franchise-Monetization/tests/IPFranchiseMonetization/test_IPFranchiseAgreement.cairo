use crate::utils::*;

use ip_franchise_monetization::interfaces::{
    IIPFranchiseAgreementDispatcherTrait, IIPFranchiseAgreementDispatcher,
    IIPFranchiseManagerDispatcherTrait,
};

use ip_franchise_monetization::types::{PaymentModel, ExclusivityType, ApplicationStatus};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};

use snforge_std::{cheat_caller_address, CheatSpan, mock_call};

use openzeppelin_token::erc721::interface::IERC721DispatcherTrait;
use openzeppelin_token::erc20::interface::IERC20DispatcherTrait;

#[test]
fn test_activate_agreement_one_time_fee() {
    let test_contracts = initialize_contracts();

    let franchise_agreement = deploy_agreement_contract_fixed_fee(test_contracts.clone());
    let TestContracts {
        manager_contract, erc20_token: erc20_token, erc721_token: _,
    } = test_contracts();

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, FRANCHISEE(), 5000);

    // approve tokens
    erc20_token.approve(franchise_agreement.contract_address, 5000);

    // call the franchise_agreement contract
    cheat_caller_address(
        franchise_agreement.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );
    franchise_agreement.activate_franchise();

    assert!(franchise_agreement.is_active(), "agreement should be active now");

    let manager_balance = erc20_token.balanceOf(manager_contract.contract_address);
    // assert!(manager_balance == franchise_agreement, "manager balance should be incremented");
}

#[test]
fn test_activate_agreement_royalty_fee() {
    let test_contracts = initialize_contracts();

    let franchise_agreement = deploy_agreement_contract_royalty_based(test_contracts.clone());
    let TestContracts {
        manager_contract, erc20_token: erc20_token, erc721_token: _,
    } = test_contracts();

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, FRANCHISEE(), 5000);

    // approve tokens
    erc20_token.approve(franchise_agreement.contract_address, 5000);

    // call the franchise_agreement contract
    cheat_caller_address(
        franchise_agreement.contract_address, FRANCHISEE(), CheatSpan::TargetCalls(1),
    );
    franchise_agreement.activate_franchise();

    assert!(franchise_agreement.is_active(), "agreement should be active now");

    let manager_balance = erc20_token.balanceOf(manager_contract.contract_address);
    // assert!(manager_balance == franchise_agreement., "manager balance should be incremented");
}


#[test]
fn test_create_sale_request() {
    let test_contracts = initialize_contracts();

    let franchise_agreement = deploy_agreement_contract_royalty_based(test_contracts.clone());
    let TestContracts {
        manager_contract, erc20_token: erc20_token, erc721_token: _,
    } = test_contracts();

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, FRANCHISEE(), 5000);

    // approve tokens
    erc20_token.approve(franchise_agreement.contract_address, 5000);

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
    } = test_contracts();

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, FRANCHISEE(), 5000);

    // approve tokens
    erc20_token.approve(franchise_agreement.contract_address, 5000);

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
    } = test_contracts();

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, FRANCHISEE(), 5000);

    // approve tokens
    erc20_token.approve(franchise_agreement.contract_address, 5000);

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
    } = test_contracts();

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, FRANCHISEE(), 5000);

    // approve tokens
    erc20_token.approve(franchise_agreement.contract_address, 5000);

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

    // mint tokens to franchisee
    mint_erc20(erc20_token.contract_address, BUYER(), 10000);

    // approve tokens
    erc20_token.approve(franchise_agreement.contract_address, 5000);

    cheat_caller_address(franchise_agreement.contract_address, BUYER(), CheatSpan::TargetCalls(1));
    franchise_agreement.finalize_franchise_sale();

    assert!(sale_request.is_some(), "agreement sale request is set");
}

