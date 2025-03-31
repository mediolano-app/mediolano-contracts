use ip_syndication::errors::Errors;
use ip_syndication::interface::{IIPSyndicationDispatcher, IIPSyndicationDispatcherTrait};
use ip_syndication::types::{IPMetadata, SyndicationDetails, Status, Mode, ParticipantDetails};
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use snforge_std::{
    EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    cheat_caller_address, stop_cheat_caller_address_global
};
use starknet::{ContractAddress, contract_address_const};
use super::test_utils::{setup, BOB, OWNER, ALICE};

#[test]
#[should_panic(expected: ('Price can not be zero',))]
fn test_register_ip_price_is_zero() {
    // Setup test environment
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";

    // Try to register with zero price (should fail)
    ip_syndication
        .register_ip(
            0,
            'flawless'.into(),
            description,
            uri,
            'Exclusive license',
            Mode::Public,
            erc20.contract_address
        );
}

#[test]
#[should_panic(expected: ('Invalid currency address',))]
fn test_register_ip_price_invalid_currency_address() {
    // Setup test environment
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";

    // Try to register with zero currency address (should fail)
    ip_syndication
        .register_ip(
            100,
            'flawless'.into(),
            description,
            uri,
            'Exclusive license',
            Mode::Public,
            contract_address_const::<0>()
        );
}

#[test]
fn test_register_ip_price_ok() {
    // Setup test environment
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    // Register IP as BOB
    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Verify IP metadata
    let ip_metadata = ip_syndication.get_ip_metadata(ip_id);

    assert(ip_metadata.ip_id == ip_id, 'wrong ip ID');
    assert(ip_metadata.owner == BOB(), 'wrong ip owner');
    assert(ip_metadata.price == price, 'wrong ip price');
    assert(ip_metadata.description == description, 'wrong ip description');
    assert(ip_metadata.uri == uri, 'wrong ip uri');
    assert(ip_metadata.licensing_terms == licensing_terms, 'wrong ip licensing terms');
    assert(ip_metadata.token_id == ip_id, 'wrong ip token id');

    // Verify syndication details
    let syndication_details = ip_syndication.get_syndication_details(ip_id);

    assert(syndication_details.ip_id == ip_id, 'wrong ip_id');
    assert(syndication_details.mode == Mode::Public, 'wrong mode');
    assert(syndication_details.status == Status::Pending, 'wrong status');
    assert(syndication_details.total_raised == 0, 'wrong total amount raised');
    assert(syndication_details.participant_count == 0, 'wrong participant count');
    assert(
        syndication_details.currency_address == erc20.contract_address, 'wrong participant count'
    );
}

#[test]
#[should_panic(expected: ('Not IP owner',))]
fn test_activate_syndication_not_ip_owner() {
    // Setup test environment and register IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Verify initial status is Pending
    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.status == Status::Pending, 'wrong status');

    // Try to activate as non-owner (default caller, not BOB) - should fail
    ip_syndication.activate_syndication(ip_id);
}

#[test]
fn test_activate_syndication_ok() {
    // Setup test environment and register IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Verify initial status is Pending
    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.status == Status::Pending, 'wrong status');

    // Activate as BOB (owner)
    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Verify status is now Active
    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.status == Status::Active, 'wrong status');
}

#[test]
#[should_panic(expected: ('Syndication is active',))]
fn test_activate_syndication_when_active() {
    // Setup test environment and register IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Verify initial status is Pending
    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.status == Status::Pending, 'wrong status');

    // Activate as BOB (owner)
    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    ip_syndication.activate_syndication(ip_id);

    // Verify status is now Active
    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.status == Status::Active, 'wrong status');

    // Try to activate again (should fail)
    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);
}

#[test]
#[should_panic(expected: ('Syndication not active',))]
fn test_deposit_non_active() {
    // Setup test environment and register IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Try to deposit while syndication is still Pending (should fail)
    ip_syndication.deposit(ip_id, 100);
}

#[test]
#[should_panic(expected: ('Amount can not be zero',))]
fn test_deposit_amount_is_zero() {
    // Setup test environment, register and activate IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Try to deposit zero amount (should fail)
    ip_syndication.deposit(ip_id, 0);
}

#[test]
#[should_panic(expected: ('Insufficient balance',))]
fn test_deposit_insufficient_balance() {
    // Setup test environment, register and activate IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Try to deposit without having sufficient balance (should fail)
    ip_syndication.deposit(ip_id, 100);
}

#[test]
#[should_panic(expected: ('Address not whitelisted',))]
fn test_deposit_for_whitelist_mode() {
    // Setup test environment, register and activate IP in whitelist mode
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Whitelist,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Try to deposit as non-whitelisted address (should fail)
    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, 100);
}

#[test]
#[should_panic(expected: ('Syndication not active',))]
fn test_deposit_when_completed() {
    // Setup test environment, register and activate IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Complete the syndication by depositing the full amount
    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, 100);

    // Try to deposit again to completed syndication (should fail)
    ip_syndication.deposit(ip_id, 100);
    stop_cheat_caller_address(ip_syndication.contract_address);
}

#[test]
fn test_deposit_ok_public_mode() {
    // Setup test environment, register and activate IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';
    let deposit = 100;

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Record OWNER's balance before deposit
    let owner_balance_before = erc20.balance_of(OWNER());

    // Make deposit as OWNER
    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, deposit);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Verify participant is added correctly
    let all_participants = ip_syndication.get_all_participants(ip_id);
    assert(*all_participants.at(0) == OWNER(), 'wrong participant');

    // Verify syndication details updated correctly
    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.total_raised == deposit, 'wrong total raised');
    assert(syndication_details.participant_count == 1, 'wrong participant count');

    // Verify participant details
    let participant_details = ip_syndication.get_participant_details(ip_id, OWNER());
    assert(participant_details.amount_deposited == deposit, 'wrong amount deposited');
    assert(participant_details.minted == false, 'wrong minted status');
    assert(participant_details.amount_refunded == 0, 'wrong amount refunded');

    // Verify balances updated correctly
    let owner_balance_after = erc20.balance_of(OWNER());
    let ip_syn_balance = erc20.balance_of(ip_syndication.contract_address);
    assert(ip_syn_balance == deposit, 'wrong ip syn balance');
    assert(owner_balance_before - owner_balance_after == deposit, 'wrong owner balance');
}

#[test]
fn test_deposit_ok_whitelist_mode() {
    // Setup test environment, register and activate IP in whitelist mode
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';
    let deposit = 100;

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Whitelist,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);

    // Add ALICE to whitelist
    ip_syndication.update_whitelist(ip_id, ALICE(), true);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Record ALICE's balance before deposit
    let alice_balance_after_balance_before = erc20.balance_of(ALICE());

    // Make deposit as ALICE (whitelisted)
    start_cheat_caller_address(ip_syndication.contract_address, ALICE());
    ip_syndication.deposit(ip_id, deposit);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Verify participant is added correctly
    let all_participants = ip_syndication.get_all_participants(ip_id);
    assert(*all_participants.at(0) == ALICE(), 'wrong participant');

    // Verify syndication details updated correctly
    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.total_raised == deposit, 'wrong total raised');
    assert(syndication_details.participant_count == 1, 'wrong participant count');

    // Verify participant details
    let participant_details = ip_syndication.get_participant_details(ip_id, ALICE());
    assert(participant_details.amount_deposited == deposit, 'wrong amount deposited');
    assert(participant_details.minted == false, 'wrong minted status');
    assert(participant_details.amount_refunded == 0, 'wrong amount refunded');

    // Verify balances updated correctly
    let alice_balance_after = erc20.balance_of(ALICE());
    let ip_syn_balance = erc20.balance_of(ip_syndication.contract_address);
    assert(ip_syn_balance == deposit, 'wrong ip syn balance');
    assert(
        alice_balance_after_balance_before - alice_balance_after == deposit, 'wrong owner balance'
    );
}

#[test]
fn test_deposit_with_excess_deposit() {
    // Setup test environment, register and activate IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';
    let deposit = 200; // Double the price
    let expected_deposit = 100; // Should only deposit up to price

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Record OWNER's balance before deposit
    let owner_balance_before = erc20.balance_of(OWNER());

    // Make deposit with excess amount
    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, deposit);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Verify participant is added correctly
    let all_participants = ip_syndication.get_all_participants(ip_id);
    assert(*all_participants.at(0) == OWNER(), 'wrong participant');

    // Verify syndication details updated correctly
    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.total_raised == expected_deposit, 'wrong total raised');
    assert(syndication_details.participant_count == 1, 'wrong participant count');

    // Verify participant details
    let participant_details = ip_syndication.get_participant_details(ip_id, OWNER());
    assert(participant_details.amount_deposited == expected_deposit, 'wrong amount deposited');
    assert(participant_details.minted == false, 'wrong minted status');
    assert(participant_details.amount_refunded == 0, 'wrong amount refunded');

    // Verify balances updated correctly (only expected_deposit should be transferred)
    let owner_balance_after = erc20.balance_of(OWNER());
    let ip_syn_balance = erc20.balance_of(ip_syndication.contract_address);
    assert(ip_syn_balance == expected_deposit, 'wrong ip syn balance');
    assert(owner_balance_before - owner_balance_after == expected_deposit, 'wrong owner balance');
}

#[test]
fn test_get_participant_count() {
    // Setup test environment, register and activate IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 1000_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Add two participants
    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, 100);
    stop_cheat_caller_address(ip_syndication.contract_address);

    start_cheat_caller_address(ip_syndication.contract_address, ALICE());
    ip_syndication.deposit(ip_id, 100);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Verify participant count
    assert(ip_syndication.get_participant_count(ip_id) == 2, 'wrong participant count');
}

#[test]
fn test_get_all_participants() {
    // Setup test environment, register and activate IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 1000_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Add two participants
    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, 100);
    stop_cheat_caller_address(ip_syndication.contract_address);

    start_cheat_caller_address(ip_syndication.contract_address, ALICE());
    ip_syndication.deposit(ip_id, 100);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Verify participant list
    let participants = ip_syndication.get_all_participants(ip_id);
    assert(participants.len() == 2, 'wrong participant count');
    assert(*participants.at(0) == OWNER(), 'wrong participant');
    assert(*participants.at(1) == ALICE(), 'wrong participant');
}

#[test]
#[should_panic(expected: ('Not IP owner',))]
fn test_update_whitelist_non_owner() {
    // Setup test environment, register and activate IP in whitelist mode
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 1000_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Whitelist,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Try to update whitelist as non-owner (should fail)
    ip_syndication.update_whitelist(ip_id, ALICE(), true);
}

#[test]
#[should_panic(expected: ('Syndication not active',))]
fn test_update_whitelist_syndication_non_active() {
    // Setup test environment and register IP (but don't activate)
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 1000_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Whitelist,
            erc20.contract_address
        );

    // Try to update whitelist before activation (should fail)
    ip_syndication.update_whitelist(ip_id, ALICE(), true);
    stop_cheat_caller_address(ip_syndication.contract_address);
}

#[test]
#[should_panic(expected: ('Not in whitelist mode',))]
fn test_update_whitelist_not_in_whitelist_mode() {
    // Setup test environment, register and activate IP in public mode
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 1000_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );
    ip_syndication.activate_syndication(ip_id);

    // Try to update whitelist in public mode (should fail)
    ip_syndication.update_whitelist(ip_id, ALICE(), true);
    stop_cheat_caller_address(ip_syndication.contract_address);
}

#[test]
fn test_update_whitelist_ok() {
    // Setup test environment, register and activate IP in whitelist mode
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 1000_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Whitelist,
            erc20.contract_address
        );
    ip_syndication.activate_syndication(ip_id);

    // Update whitelist to add ALICE
    ip_syndication.update_whitelist(ip_id, ALICE(), true);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Verify whitelist status
    assert(ip_syndication.is_whitelisted(ip_id, ALICE()), 'alice should be whitelisted');
    assert(!ip_syndication.is_whitelisted(ip_id, OWNER()), 'owner shouldnt be whitelisted');
}

#[test]
#[should_panic(expected: ('Not IP owner',))]
fn test_cancel_syndication_non_owner() {
    // Setup test environment and register IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 1000_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Try to cancel as non-owner (should fail)
    ip_syndication.cancel_syndication(ip_id);
}

#[test]
#[should_panic(expected: ('Syn: completed or cancelled',))]
fn test_cancel_syndication_when_completed() {
    // Setup test environment, register and activate IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Complete the syndication by depositing the full amount
    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, 100);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Try to cancel a completed syndication (should fail)
    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    ip_syndication.cancel_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);
}

#[test]
fn test_cancel_syndication_ok() {
    // Setup test environment, register and activate IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 1000_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';
    let deposit = 500;

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Make deposit as OWNER
    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, deposit);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Record OWNER's balance before cancellation
    let owner_balance_before = erc20.balance_of(OWNER());

    // Cancel syndication as BOB (owner)
    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    ip_syndication.cancel_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Verify refund was processed
    let owner_balance_after = erc20.balance_of(OWNER());
    let syndication_details = ip_syndication.get_syndication_details(ip_id);

    assert(owner_balance_after == owner_balance_before + deposit, 'wrong owner balance');
    assert(erc20.balance_of(ip_syndication.contract_address) == 0, 'wrong balance after refund');
    assert(syndication_details.status == Status::Cancelled, 'wrong status');
}

#[test]
#[should_panic(expected: ('Syndication not completed',))]
fn test_mint_asset_non_competed_syn() {
    // Setup test environment, register and activate IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 1000_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';
    let deposit = 500;

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Make partial deposit (not enough to complete syndication)
    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, deposit);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Try to mint before syndication is completed (should fail)
    ip_syndication.mint_asset(ip_id);
}

#[test]
#[should_panic(expected: ('Not Syndication Participant',))]
fn test_mint_asset_non_participant() {
    // Setup test environment, register and activate IP
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';
    let deposit = 100;

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Complete the syndication as OWNER
    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, deposit);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Try to mint as ALICE who didn't participate (should fail)
    start_cheat_caller_address(ip_syndication.contract_address, ALICE());
    ip_syndication.mint_asset(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);
}

#[test]
#[should_panic(expected: ('Already minted',))]
fn test_mint_asset_already_minted() {
    // Setup test environment, register and activate IP
    let (ip_syndication, asset_nft, erc20, mike) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';
    let deposit = 100;

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Complete the syndication as Mike
    start_cheat_caller_address(ip_syndication.contract_address, mike);
    ip_syndication.deposit(ip_id, deposit);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Mint asset
    start_cheat_caller_address(ip_syndication.contract_address, mike);
    ip_syndication.mint_asset(ip_id);

    // Try to mint again (should fail)
    ip_syndication.mint_asset(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);
}

#[test]
fn test_mint_asset_ok() {
    // Setup test environment, register and activate IP
    let (ip_syndication, asset_nft, erc20, mike) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100_000_000;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';
    let deposit_1 = 568;
    let deposit_2 = 536;

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    let ip_id = ip_syndication
        .register_ip(
            price,
            name,
            description.clone(),
            uri.clone(),
            licensing_terms,
            Mode::Public,
            erc20.contract_address
        );

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Mike makes multiple deposits
    start_cheat_caller_address(ip_syndication.contract_address, mike);
    ip_syndication.deposit(ip_id, deposit_1);
    ip_syndication.deposit(ip_id, deposit_2);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // ALICE makes a deposit
    start_cheat_caller_address(ip_syndication.contract_address, ALICE());
    ip_syndication.deposit(ip_id, 10_000);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // OWNER completes the syndication with a large deposit
    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, 100_000_000);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Mike mints his asset
    start_cheat_caller_address(ip_syndication.contract_address, mike);
    ip_syndication.mint_asset(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    // Verify the ERC1155 token was minted with the correct amount
    let erc1155 = IERC1155Dispatcher { contract_address: asset_nft.contract_address };
    let balance_mike = erc1155.balance_of(mike, ip_id);

    // Verify Mike's minted share is equal to his total deposits
    assert(balance_mike == deposit_1 + deposit_2, 'wrong balance');
}
