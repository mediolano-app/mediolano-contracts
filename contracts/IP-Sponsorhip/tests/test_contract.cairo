use core::result::ResultTrait;
use ip_sponsorship::interface::IIPSponsorshipDispatcherTrait;
use ip_sponsorship::interface::IIPSponsorshipDispatcher;
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp
};
use starknet::ContractAddress;

fn ADMIN() -> ContractAddress {
    123.try_into().unwrap()
}

fn IP_AUTHOR() -> ContractAddress {
    456.try_into().unwrap()
}

fn SPONSOR1() -> ContractAddress {
    789.try_into().unwrap()
}

fn SPONSOR2() -> ContractAddress {
    101112.try_into().unwrap()
}

fn deploy_contract() -> IIPSponsorshipDispatcher {
    let contract = declare("IPSponsorship").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![ADMIN().into()]).unwrap();
    IIPSponsorshipDispatcher { contract_address }
}

#[test]
fn test_deploy() {
    let _contract = deploy_contract();
}

#[test]
fn test_register_ip() {
    let contract = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    
    let metadata = 'ipfs://metadata_hash';
    let license_terms = 'standard_license_v1';
    
    let ip_id = contract.register_ip(metadata, license_terms);
    
    assert(ip_id == 1, 'IP ID should be 1');
    
    let (owner, returned_metadata, returned_license_terms, active) = contract.get_ip_details(ip_id);
    
    assert(owner == IP_AUTHOR(), 'Owner should be IP_AUTHOR');
    assert(returned_metadata == metadata, 'Metadata should match');
    assert(returned_license_terms == license_terms, 'License terms should match');
    assert(active == true, 'IP should be active');
    
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_update_ip_metadata() {
    let contract = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    
    let ip_id = contract.register_ip('original_metadata', 'license_v1');
    let new_metadata = 'updated_metadata';
    
    contract.update_ip_metadata(ip_id, new_metadata);
    
    let (_, returned_metadata, _, _) = contract.get_ip_details(ip_id);
    assert(returned_metadata == new_metadata, 'Metadata should be updated');
    
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Only IP owner can update')]
fn test_update_ip_metadata_unauthorized() {
    let contract = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    let ip_id = contract.register_ip('metadata', 'license');
    stop_cheat_caller_address(contract.contract_address);
    
    start_cheat_caller_address(contract.contract_address, SPONSOR1());
    contract.update_ip_metadata(ip_id, 'new_metadata');
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_create_sponsorship_offer() {
    let contract = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    
    let ip_id = contract.register_ip('metadata', 'license');
    let min_price = 100_u256;
    let max_price = 1000_u256;
    let duration = 3600_u64; // 1 hour
    
    let offer_id = contract.create_sponsorship_offer(ip_id, min_price, max_price, duration, Option::None);
    
    assert(offer_id == 1, 'Offer ID should be 1');
    
    let (returned_ip_id, returned_min_price, returned_max_price, returned_duration, author, active, specific_sponsor) = 
        contract.get_sponsorship_offer(offer_id);
    
    assert(returned_ip_id == ip_id, 'IP ID should match');
    assert(returned_min_price == min_price, 'Min price should match');
    assert(returned_max_price == max_price, 'Max price should match');
    assert(returned_duration == duration, 'Duration should match');
    assert(author == IP_AUTHOR(), 'Author should match');
    assert(active == true, 'Offer should be active');
    assert(specific_sponsor == Option::None, 'Should be open offer');
    
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_create_specific_sponsor_offer() {
    let contract = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    
    let ip_id = contract.register_ip('metadata', 'license');
    let offer_id = contract.create_sponsorship_offer(
        ip_id, 
        100_u256, 
        1000_u256, 
        3600_u64, 
        Option::Some(SPONSOR1())
    );
    
    let (_, _, _, _, _, _, specific_sponsor) = contract.get_sponsorship_offer(offer_id);
    assert(specific_sponsor == Option::Some(SPONSOR1()), 'Should be specific sponsor');
    
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Only IP owner can create offers')]
fn test_create_offer_unauthorized() {
    let contract = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    let ip_id = contract.register_ip('metadata', 'license');
    stop_cheat_caller_address(contract.contract_address);
    
    start_cheat_caller_address(contract.contract_address, SPONSOR1());
    contract.create_sponsorship_offer(ip_id, 100_u256, 1000_u256, 3600_u64, Option::None);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid price range')]
fn test_create_offer_invalid_price_range() {
    let contract = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    let ip_id = contract.register_ip('metadata', 'license');
    
    // Min price higher than max price
    contract.create_sponsorship_offer(ip_id, 1000_u256, 100_u256, 3600_u64, Option::None);
    
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_sponsor_ip() {
    let contract = deploy_contract();
    
    // Create IP and offer
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    let ip_id = contract.register_ip('metadata', 'license');
    let offer_id = contract.create_sponsorship_offer(ip_id, 100_u256, 1000_u256, 3600_u64, Option::None);
    stop_cheat_caller_address(contract.contract_address);
    
    // Place bid
    start_cheat_caller_address(contract.contract_address, SPONSOR1());
    let bid_amount = 500_u256;
    contract.sponsor_ip(offer_id, bid_amount);
    
    let bids = contract.get_sponsorship_bids(offer_id);
    assert(bids.len() == 1, 'Should have one bid');
    let (sponsor, amount) = *bids.at(0);
    assert(sponsor == SPONSOR1(), 'Sponsor should match');
    assert(amount == bid_amount, 'Amount should match');
    
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Bid below minimum price')]
fn test_sponsor_ip_bid_too_low() {
    let contract = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    let ip_id = contract.register_ip('metadata', 'license');
    let offer_id = contract.create_sponsorship_offer(ip_id, 100_u256, 1000_u256, 3600_u64, Option::None);
    stop_cheat_caller_address(contract.contract_address);
    
    start_cheat_caller_address(contract.contract_address, SPONSOR1());
    contract.sponsor_ip(offer_id, 50_u256); // Below minimum price of 100
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Bid above maximum price')]
fn test_sponsor_ip_bid_too_high() {
    let contract = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    let ip_id = contract.register_ip('metadata', 'license');
    let offer_id = contract.create_sponsorship_offer(ip_id, 100_u256, 1000_u256, 3600_u64, Option::None);
    stop_cheat_caller_address(contract.contract_address);
    
    start_cheat_caller_address(contract.contract_address, SPONSOR1());
    contract.sponsor_ip(offer_id, 1500_u256); // Above maximum price of 1000
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Not authorized to sponsor')]
fn test_sponsor_ip_specific_sponsor_unauthorized() {
    let contract = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    let ip_id = contract.register_ip('metadata', 'license');
    let offer_id = contract.create_sponsorship_offer(
        ip_id, 
        100_u256, 
        1000_u256, 
        3600_u64, 
        Option::Some(SPONSOR1())
    );
    stop_cheat_caller_address(contract.contract_address);
    
    // SPONSOR2 tries to bid on SPONSOR1-specific offer
    start_cheat_caller_address(contract.contract_address, SPONSOR2());
    contract.sponsor_ip(offer_id, 500_u256);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_accept_sponsorship() {
    let contract = deploy_contract();
    
    // Setup: Create IP, offer, and bid
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    let ip_id = contract.register_ip('metadata', 'license');
    let offer_id = contract.create_sponsorship_offer(ip_id, 100_u256, 1000_u256, 3600_u64, Option::None);
    stop_cheat_caller_address(contract.contract_address);
    
    start_cheat_caller_address(contract.contract_address, SPONSOR1());
    contract.sponsor_ip(offer_id, 500_u256);
    stop_cheat_caller_address(contract.contract_address);
    
    // Accept sponsorship
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    start_cheat_block_timestamp(contract.contract_address, 1000_u64);
    
    contract.accept_sponsorship(offer_id, SPONSOR1());
    
    // Check that offer is deactivated
    let (_, _, _, _, _, active, _) = contract.get_sponsorship_offer(offer_id);
    assert(active == false, 'Offer should be deactivated');
    
    // Check that license is created
    let user_licenses = contract.get_user_licenses(SPONSOR1());
    assert(user_licenses.len() == 1, 'Should have one license');
    
    let license_id = *user_licenses.at(0);
    assert(contract.is_license_valid(license_id), 'License should be valid');
    
    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Only offer author can accept')]
fn test_accept_sponsorship_unauthorized() {
    let contract = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    let ip_id = contract.register_ip('metadata', 'license');
    let offer_id = contract.create_sponsorship_offer(ip_id, 100_u256, 1000_u256, 3600_u64, Option::None);
    stop_cheat_caller_address(contract.contract_address);
    
    start_cheat_caller_address(contract.contract_address, SPONSOR1());
    contract.sponsor_ip(offer_id, 500_u256);
    // Try to accept own bid (should fail)
    contract.accept_sponsorship(offer_id, SPONSOR1());
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_cancel_sponsorship_offer() {
    let contract = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    let ip_id = contract.register_ip('metadata', 'license');
    let offer_id = contract.create_sponsorship_offer(ip_id, 100_u256, 1000_u256, 3600_u64, Option::None);
    
    contract.cancel_sponsorship_offer(offer_id);
    
    let (_, _, _, _, _, active, _) = contract.get_sponsorship_offer(offer_id);
    assert(active == false, 'Offer should be cancelled');
    
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_update_sponsorship_offer() {
    let contract = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    let ip_id = contract.register_ip('metadata', 'license');
    let offer_id = contract.create_sponsorship_offer(ip_id, 100_u256, 1000_u256, 3600_u64, Option::None);
    
    let new_min_price = 200_u256;
    let new_max_price = 2000_u256;
    
    contract.update_sponsorship_offer(offer_id, new_min_price, new_max_price);
    
    let (_, returned_min_price, returned_max_price, _, _, _, _) = contract.get_sponsorship_offer(offer_id);
    assert(returned_min_price == new_min_price, 'Min price should be updated');
    assert(returned_max_price == new_max_price, 'Max price should be updated');
    
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_transfer_license() {
    let contract = deploy_contract();
    
    // Setup complete sponsorship flow
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    let ip_id = contract.register_ip('metadata', 'license');
    let offer_id = contract.create_sponsorship_offer(ip_id, 100_u256, 1000_u256, 3600_u64, Option::None);
    stop_cheat_caller_address(contract.contract_address);
    
    start_cheat_caller_address(contract.contract_address, SPONSOR1());
    contract.sponsor_ip(offer_id, 500_u256);
    stop_cheat_caller_address(contract.contract_address);
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    start_cheat_block_timestamp(contract.contract_address, 1000_u64);
    contract.accept_sponsorship(offer_id, SPONSOR1());
    stop_cheat_caller_address(contract.contract_address);
    
    // Transfer license
    let user_licenses = contract.get_user_licenses(SPONSOR1());
    let license_id = *user_licenses.at(0);
    
    start_cheat_caller_address(contract.contract_address, SPONSOR1());
    contract.transfer_license(license_id, SPONSOR2());
    
    let new_user_licenses = contract.get_user_licenses(SPONSOR2());
    assert(new_user_licenses.len() == 1, 'SPONSOR2 should have license');
    
    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_revoke_license() {
    let contract = deploy_contract();
    
    // Setup complete sponsorship flow
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    let ip_id = contract.register_ip('metadata', 'license');
    let offer_id = contract.create_sponsorship_offer(ip_id, 100_u256, 1000_u256, 3600_u64, Option::None);
    stop_cheat_caller_address(contract.contract_address);
    
    start_cheat_caller_address(contract.contract_address, SPONSOR1());
    contract.sponsor_ip(offer_id, 500_u256);
    stop_cheat_caller_address(contract.contract_address);
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    start_cheat_block_timestamp(contract.contract_address, 1000_u64);
    contract.accept_sponsorship(offer_id, SPONSOR1());
    
    let user_licenses = contract.get_user_licenses(SPONSOR1());
    let license_id = *user_licenses.at(0);
    
    // Revoke license
    contract.revoke_license(license_id);
    
    assert(!contract.is_license_valid(license_id), 'License should be invalid');
    
    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_get_active_offers() {
    let contract = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    
    let ip_id1 = contract.register_ip('metadata1', 'license1');
    let ip_id2 = contract.register_ip('metadata2', 'license2');
    
    let offer_id1 = contract.create_sponsorship_offer(ip_id1, 100_u256, 1000_u256, 3600_u64, Option::None);
    let _offer_id2 = contract.create_sponsorship_offer(ip_id2, 200_u256, 2000_u256, 7200_u64, Option::None);
    
    let active_offers = contract.get_active_offers();
    assert(active_offers.len() == 2, 'Should have two active offers');
    
    // Cancel one offer
    contract.cancel_sponsorship_offer(offer_id1);
    
    let active_offers_after_cancel = contract.get_active_offers();
    assert(active_offers_after_cancel.len() == 1, 'Should have one active offer');
    
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_multiple_bids_on_offer() {
    let contract = deploy_contract();
    
    // Create IP and offer
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    let ip_id = contract.register_ip('metadata', 'license');
    let offer_id = contract.create_sponsorship_offer(ip_id, 100_u256, 1000_u256, 3600_u64, Option::None);
    stop_cheat_caller_address(contract.contract_address);
    
    // Multiple sponsors place bids
    start_cheat_caller_address(contract.contract_address, SPONSOR1());
    contract.sponsor_ip(offer_id, 300_u256);
    stop_cheat_caller_address(contract.contract_address);
    
    start_cheat_caller_address(contract.contract_address, SPONSOR2());
    contract.sponsor_ip(offer_id, 600_u256);
    stop_cheat_caller_address(contract.contract_address);
    
    let bids = contract.get_sponsorship_bids(offer_id);
    assert(bids.len() == 2, 'Should have two bids');
    
    let (sponsor1, amount1) = *bids.at(0);
    let (sponsor2, amount2) = *bids.at(1);
    
    assert(sponsor1 == SPONSOR1(), 'First bid from SPONSOR1');
    assert(amount1 == 300_u256, 'First bid amount 300');
    assert(sponsor2 == SPONSOR2(), 'Second bid from SPONSOR2');
    assert(amount2 == 600_u256, 'Second bid amount 600');
}

#[test]
fn test_license_expiry() {
    let contract = deploy_contract();
    
    // Setup complete sponsorship flow
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    let ip_id = contract.register_ip('metadata', 'license');
    let duration = 3600_u64; // 1 hour
    let offer_id = contract.create_sponsorship_offer(ip_id, 100_u256, 1000_u256, duration, Option::None);
    stop_cheat_caller_address(contract.contract_address);
    
    start_cheat_caller_address(contract.contract_address, SPONSOR1());
    contract.sponsor_ip(offer_id, 500_u256);
    stop_cheat_caller_address(contract.contract_address);
    
    start_cheat_caller_address(contract.contract_address, IP_AUTHOR());
    start_cheat_block_timestamp(contract.contract_address, 1000_u64);
    contract.accept_sponsorship(offer_id, SPONSOR1());
    
    let user_licenses = contract.get_user_licenses(SPONSOR1());
    let license_id = *user_licenses.at(0);
    
    // License should be valid initially
    assert(contract.is_license_valid(license_id), 'License should be valid');
    
    // Move time forward past expiry
    start_cheat_block_timestamp(contract.contract_address, 1000_u64 + duration + 1);
    
    // License should now be expired
    assert(!contract.is_license_valid(license_id), 'License should be expired');
    
    stop_cheat_block_timestamp(contract.contract_address);
    stop_cheat_caller_address(contract.contract_address);
} 