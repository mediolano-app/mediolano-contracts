use starknet::{ContractAddress, contract_address_const};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use core::byte_array::ByteArray;
use core::array::ArrayTrait;
use core::integer::u256;
use core::array::Array;

use super::interfaces::{Offer, OfferStatus};
use super::IPOfferLicensingDispatcher;
use super::IPOfferLicensingDispatcherTrait;

// Test addresses
fn OWNER() -> ContractAddress {
    contract_address_const::<0x123>()
}

fn CREATOR() -> ContractAddress {
    contract_address_const::<0x456>()
}

fn BUYER() -> ContractAddress {
    contract_address_const::<0x789>()
}

fn IP_TOKEN_CONTRACT() -> ContractAddress {
    contract_address_const::<0xabc>()
}

fn PAYMENT_TOKEN() -> ContractAddress {
    contract_address_const::<0xdef>()
}

// Test constants
const IP_TOKEN_ID: u256 = 1;
const PAYMENT_AMOUNT: u256 = 1000;

fn LICENSE_TERMS() -> ByteArray {
    "Test License Terms"
}

// Helper function to deploy the contract
fn deploy_contract() -> IPOfferLicensingDispatcher {
    let contract = declare("IPOfferLicensing").unwrap();
    let mut constructor_calldata = array![];
    OWNER().serialize(ref constructor_calldata);
    IP_TOKEN_CONTRACT().serialize(ref constructor_calldata);
    
    let (contract_address, _) = contract
        .contract_class()
        .deploy(@constructor_calldata)
        .unwrap();
    
    IPOfferLicensingDispatcher { contract_address }
}

// Helper function to setup IP token ownership
fn setup_ip_token(contract: IPOfferLicensingDispatcher, owner: ContractAddress) {
    start_cheat_caller_address(contract.contract_address, IP_TOKEN_CONTRACT());
    let ip_contract = IERC721Dispatcher { contract_address: IP_TOKEN_CONTRACT() };
    ip_contract.transfer_from(OWNER(), owner, IP_TOKEN_ID);
    stop_cheat_caller_address(contract.contract_address);
}

// Helper function to setup payment token approval
fn setup_payment_token(contract: IPOfferLicensingDispatcher, spender: ContractAddress, amount: u256) {
    start_cheat_caller_address(contract.contract_address, PAYMENT_TOKEN());
    let payment_token = IERC20Dispatcher { contract_address: PAYMENT_TOKEN() };
    payment_token.approve(spender, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_create_offer() {
    let mut contract: IPOfferLicensingDispatcher = deploy_contract();
    setup_ip_token(contract, CREATOR());
    
    // Create offer as creator
    start_cheat_caller_address(contract.contract_address, CREATOR());
    let offer_id: u256 = IPOfferLicensingDispatcherTrait::create_offer(
        ref contract,
        IP_TOKEN_ID,
        PAYMENT_AMOUNT,
        PAYMENT_TOKEN(),
        LICENSE_TERMS()
    );

    // Verify offer creation
    let offer: Offer = IPOfferLicensingDispatcherTrait::get_offer(@contract, offer_id);
    assert(offer.id == offer_id, 'Invalid offer ID');
    assert(offer.ip_token_id == IP_TOKEN_ID, 'Invalid IP token ID');
    assert(offer.creator == CREATOR(), 'Invalid creator');
    assert(offer.owner == CREATOR(), 'Invalid owner');
    assert(offer.payment_amount == PAYMENT_AMOUNT, 'Invalid payment amount');
    assert(offer.payment_token == PAYMENT_TOKEN(), 'Invalid payment token');
    assert(offer.license_terms == LICENSE_TERMS(), 'Invalid license terms');
    assert(offer.status == OfferStatus::Active, 'Invalid status');
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_accept_offer() {
    let mut contract: IPOfferLicensingDispatcher = deploy_contract();
    setup_ip_token(contract, CREATOR());
    
    // Create offer
    start_cheat_caller_address(contract.contract_address, CREATOR());
    let offer_id: u256 = IPOfferLicensingDispatcherTrait::create_offer(
        ref contract,
        IP_TOKEN_ID,
        PAYMENT_AMOUNT,
        PAYMENT_TOKEN(),
        LICENSE_TERMS()
    );
    stop_cheat_caller_address(contract.contract_address);

    // Setup payment token approval
    setup_payment_token(contract, contract.contract_address, PAYMENT_AMOUNT);

    // Accept offer as buyer
    start_cheat_caller_address(contract.contract_address, BUYER());
    IPOfferLicensingDispatcherTrait::accept_offer(ref contract, offer_id);

    // Verify offer acceptance
    let offer: Offer = IPOfferLicensingDispatcherTrait::get_offer(@contract, offer_id);
    assert(offer.status == OfferStatus::Accepted, 'Offer not accepted');
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_reject_offer() {
    let mut contract: IPOfferLicensingDispatcher = deploy_contract();
    setup_ip_token(contract, CREATOR());
    
    // Create offer
    start_cheat_caller_address(contract.contract_address, CREATOR());
    let offer_id: u256 = IPOfferLicensingDispatcherTrait::create_offer(
        ref contract,
        IP_TOKEN_ID,
        PAYMENT_AMOUNT,
        PAYMENT_TOKEN(),
        LICENSE_TERMS()
    );
    stop_cheat_caller_address(contract.contract_address);

    // Reject offer as creator
    start_cheat_caller_address(contract.contract_address, CREATOR());
    IPOfferLicensingDispatcherTrait::reject_offer(ref contract, offer_id);

    // Verify offer rejection
    let offer: Offer = IPOfferLicensingDispatcherTrait::get_offer(@contract, offer_id);
    assert(offer.status == OfferStatus::Rejected, 'Offer not rejected');
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_cancel_offer() {
    let mut contract: IPOfferLicensingDispatcher = deploy_contract();
    setup_ip_token(contract, CREATOR());
    
    // Create offer
    start_cheat_caller_address(contract.contract_address, CREATOR());
    let offer_id: u256 = IPOfferLicensingDispatcherTrait::create_offer(
        ref contract,
        IP_TOKEN_ID,
        PAYMENT_AMOUNT,
        PAYMENT_TOKEN(),
        LICENSE_TERMS()
    );
    stop_cheat_caller_address(contract.contract_address);

    // Cancel offer as creator
    start_cheat_caller_address(contract.contract_address, CREATOR());
    IPOfferLicensingDispatcherTrait::cancel_offer(ref contract, offer_id);

    // Verify offer cancellation
    let offer: Offer = IPOfferLicensingDispatcherTrait::get_offer(@contract, offer_id);
    assert(offer.status == OfferStatus::Cancelled, 'Offer not cancelled');
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_claim_refund() {
    let mut contract: IPOfferLicensingDispatcher = deploy_contract();
    setup_ip_token(contract, CREATOR());
    
    // Create offer
    start_cheat_caller_address(contract.contract_address, CREATOR());
    let offer_id: u256 = IPOfferLicensingDispatcherTrait::create_offer(
        ref contract,
        IP_TOKEN_ID,
        PAYMENT_AMOUNT,
        PAYMENT_TOKEN(),
        LICENSE_TERMS()
    );
    stop_cheat_caller_address(contract.contract_address);

    // Reject offer
    start_cheat_caller_address(contract.contract_address, CREATOR());
    IPOfferLicensingDispatcherTrait::reject_offer(ref contract, offer_id);
    stop_cheat_caller_address(contract.contract_address);

    // Claim refund
    start_cheat_caller_address(contract.contract_address, CREATOR());
    IPOfferLicensingDispatcherTrait::claim_refund(ref contract, offer_id);

    // Verify refund claimed
    let offer: Offer = IPOfferLicensingDispatcherTrait::get_offer(@contract, offer_id);
    assert(offer.status == OfferStatus::Rejected, 'Offer status changed');
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_get_offers_by_ip() {
    let mut contract: IPOfferLicensingDispatcher = deploy_contract();
    setup_ip_token(contract, CREATOR());
    
    // Create multiple offers
    start_cheat_caller_address(contract.contract_address, CREATOR());
    let offer_id1: u256 = IPOfferLicensingDispatcherTrait::create_offer(
        ref contract,
        IP_TOKEN_ID,
        PAYMENT_AMOUNT,
        PAYMENT_TOKEN(),
        LICENSE_TERMS()
    );
    let offer_id2: u256 = IPOfferLicensingDispatcherTrait::create_offer(
        ref contract,
        IP_TOKEN_ID,
        PAYMENT_AMOUNT * 2,
        PAYMENT_TOKEN(),
        LICENSE_TERMS()
    );
    stop_cheat_caller_address(contract.contract_address);

    // Get offers by IP token
    let offers: Array<u256> = IPOfferLicensingDispatcherTrait::get_offers_by_ip(@contract, IP_TOKEN_ID);
    assert(offers.len() == 2, 'Wrong number of offers');
    assert(*offers.at(0) == offer_id1, 'Wrong offer ID 1');
    assert(*offers.at(1) == offer_id2, 'Wrong offer ID 2');
}

#[test]
fn test_get_offers_by_creator() {
    let mut contract: IPOfferLicensingDispatcher = deploy_contract();
    setup_ip_token(contract, CREATOR());
    
    // Create multiple offers
    start_cheat_caller_address(contract.contract_address, CREATOR());
    let offer_id1: u256 = IPOfferLicensingDispatcherTrait::create_offer(
        ref contract,
        IP_TOKEN_ID,
        PAYMENT_AMOUNT,
        PAYMENT_TOKEN(),
        LICENSE_TERMS()
    );
    let offer_id2: u256 = IPOfferLicensingDispatcherTrait::create_offer(
        ref contract,
        IP_TOKEN_ID,
        PAYMENT_AMOUNT * 2,
        PAYMENT_TOKEN(),
        LICENSE_TERMS()
    );
    stop_cheat_caller_address(contract.contract_address);

    // Get offers by creator
    let offers: Array<u256> = IPOfferLicensingDispatcherTrait::get_offers_by_creator(@contract, CREATOR());
    assert(offers.len() == 2, 'Wrong number of offers');
    assert(*offers.at(0) == offer_id1, 'Wrong offer ID 1');
    assert(*offers.at(1) == offer_id2, 'Wrong offer ID 2');
}

#[test]
fn test_get_offers_by_owner() {
    let mut contract: IPOfferLicensingDispatcher = deploy_contract();
    setup_ip_token(contract, CREATOR());
    
    // Create multiple offers
    start_cheat_caller_address(contract.contract_address, CREATOR());
    let offer_id1: u256 = IPOfferLicensingDispatcherTrait::create_offer(
        ref contract,
        IP_TOKEN_ID,
        PAYMENT_AMOUNT,
        PAYMENT_TOKEN(),
        LICENSE_TERMS()
    );
    let offer_id2: u256 = IPOfferLicensingDispatcherTrait::create_offer(
        ref contract,
        IP_TOKEN_ID,
        PAYMENT_AMOUNT * 2,
        PAYMENT_TOKEN(),
        LICENSE_TERMS()
    );
    stop_cheat_caller_address(contract.contract_address);

    // Get offers by owner
    let offers: Array<u256> = IPOfferLicensingDispatcherTrait::get_offers_by_owner(@contract, CREATOR());
    assert(offers.len() == 2, 'Wrong number of offers');
    assert(*offers.at(0) == offer_id1, 'Wrong offer ID 1');
    assert(*offers.at(1) == offer_id2, 'Wrong offer ID 2');
}

#[test]
#[should_panic(expected: ('Not IP owner',))]
fn test_create_offer_not_owner() {
    let mut contract: IPOfferLicensingDispatcher = deploy_contract();
    
    // Try to create offer as non-owner
    start_cheat_caller_address(contract.contract_address, BUYER());
    let offer_id: u256 = IPOfferLicensingDispatcherTrait::create_offer(
        ref contract,
        IP_TOKEN_ID,
        PAYMENT_AMOUNT,
        PAYMENT_TOKEN(),
        LICENSE_TERMS()
    );
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: ('Offer not active',))]
fn test_accept_inactive_offer() {
    let mut contract: IPOfferLicensingDispatcher = deploy_contract();
    setup_ip_token(contract, CREATOR());
    
    // Create offer
    start_cheat_caller_address(contract.contract_address, CREATOR());
    let offer_id: u256 = IPOfferLicensingDispatcherTrait::create_offer(
        ref contract,
        IP_TOKEN_ID,
        PAYMENT_AMOUNT,
        PAYMENT_TOKEN(),
        LICENSE_TERMS()
    );
    IPOfferLicensingDispatcherTrait::reject_offer(ref contract, offer_id);
    stop_cheat_caller_address(contract.contract_address);

    // Try to accept rejected offer
    start_cheat_caller_address(contract.contract_address, BUYER());
    IPOfferLicensingDispatcherTrait::accept_offer(ref contract, offer_id);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: ('Not offer creator',))]
fn test_cancel_offer_not_creator() {
    let mut contract: IPOfferLicensingDispatcher = deploy_contract();
    setup_ip_token(contract, CREATOR());
    
    // Create offer
    start_cheat_caller_address(contract.contract_address, CREATOR());
    let offer_id: u256 = IPOfferLicensingDispatcherTrait::create_offer(
        ref contract,
        IP_TOKEN_ID,
        PAYMENT_AMOUNT,
        PAYMENT_TOKEN(),
        LICENSE_TERMS()
    );
    stop_cheat_caller_address(contract.contract_address);

    // Try to cancel offer as non-creator
    start_cheat_caller_address(contract.contract_address, BUYER());
    IPOfferLicensingDispatcherTrait::cancel_offer(ref contract, offer_id);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: ('Offer not refundable',))]
fn test_claim_refund_active_offer() {
    let mut contract: IPOfferLicensingDispatcher = deploy_contract();
    setup_ip_token(contract, CREATOR());
    
    // Create offer
    start_cheat_caller_address(contract.contract_address, CREATOR());
    let offer_id: u256 = IPOfferLicensingDispatcherTrait::create_offer(
        ref contract,
        IP_TOKEN_ID,
        PAYMENT_AMOUNT,
        PAYMENT_TOKEN(),
        LICENSE_TERMS()
    );
    stop_cheat_caller_address(contract.contract_address);

    // Try to claim refund for active offer
    start_cheat_caller_address(contract.contract_address, CREATOR());
    IPOfferLicensingDispatcherTrait::claim_refund(ref contract, offer_id);
    stop_cheat_caller_address(contract.contract_address);
} 