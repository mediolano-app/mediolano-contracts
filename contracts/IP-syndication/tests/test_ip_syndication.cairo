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
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";

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
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";

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

    let ip_metadata = ip_syndication.get_ip_metadata(ip_id);

    assert(ip_metadata.ip_id == ip_id, 'wrong ip ID');
    assert(ip_metadata.owner == BOB(), 'wrong ip owner');
    assert(ip_metadata.price == price, 'wrong ip price');
    assert(ip_metadata.description == description, 'wrong ip description');
    assert(ip_metadata.uri == uri, 'wrong ip uri');
    assert(ip_metadata.licensing_terms == licensing_terms, 'wrong ip licensing terms');
    assert(ip_metadata.token_id == ip_id, 'wrong ip token id');

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

    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.status == Status::Pending, 'wrong status');

    ip_syndication.activate_syndication(ip_id);

    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.status == Status::Pending, 'wrong status');
}

#[test]
fn test_activate_syndication_ok() {
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

    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.status == Status::Pending, 'wrong status');

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.status == Status::Active, 'wrong status');
}

#[test]
#[should_panic(expected: ('Syndication is active',))]
fn test_activate_syndication_when_active() {
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

    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.status == Status::Pending, 'wrong status');

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    ip_syndication.activate_syndication(ip_id);

    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.status == Status::Active, 'wrong status');

    ip_syndication.activate_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);
}

#[test]
#[should_panic(expected: ('Syndication not active',))]
fn test_deposit_non_active() {
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

    ip_syndication.deposit(ip_id, 100);
}

#[test]
#[should_panic(expected: ('Amount can not be zero',))]
fn test_deposit_amount_is_zero() {
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

    ip_syndication.deposit(ip_id, 0);
}

#[test]
#[should_panic(expected: ('Insufficient balance',))]
fn test_deposit_insufficient_balance() {
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

    ip_syndication.deposit(ip_id, 100);
}

#[test]
#[should_panic(expected: ('Address not whitelisted',))]
fn test_deposit_for_whitelist_mode() {
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

    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, 100);
}

#[test]
#[should_panic(expected: ('Syndication not active',))]
fn test_deposit_when_completed() {
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

    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, 100);
    ip_syndication.deposit(ip_id, 100);
    stop_cheat_caller_address(ip_syndication.contract_address);
}

#[test]
fn test_deposit_ok_public_mode() {
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

    let owner_balance_before = erc20.balance_of(OWNER());

    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, deposit);
    stop_cheat_caller_address(ip_syndication.contract_address);

    let all_participants = ip_syndication.get_all_participants(ip_id);

    assert(*all_participants.at(0) == OWNER(), 'wrong participant');

    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.total_raised == deposit, 'wrong total raised');
    assert(syndication_details.participant_count == 1, 'wrong participant count');

    let participant_details = ip_syndication.get_participant_details(ip_id, OWNER());

    assert(participant_details.amount_deposited == deposit, 'wrong amount deposited');
    assert(participant_details.minted == false, 'wrong minted status');
    assert(participant_details.amount_refunded == 0, 'wrong amount refunded');

    let owner_balance_after = erc20.balance_of(OWNER());
    let ip_syn_balance = erc20.balance_of(ip_syndication.contract_address);
    assert(ip_syn_balance == deposit, 'wrong ip syn balance');
    assert(owner_balance_before - owner_balance_after == deposit, 'wrong owner balance');
}

#[test]
fn test_deposit_ok_whitelist_mode() {
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
    ip_syndication.update_whitelist(ip_id, ALICE(), true);

    stop_cheat_caller_address(ip_syndication.contract_address);

    let alice_balance_after_balance_before = erc20.balance_of(ALICE());

    start_cheat_caller_address(ip_syndication.contract_address, ALICE());
    ip_syndication.deposit(ip_id, deposit);
    stop_cheat_caller_address(ip_syndication.contract_address);

    let all_participants = ip_syndication.get_all_participants(ip_id);

    assert(*all_participants.at(0) == ALICE(), 'wrong participant');

    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.total_raised == deposit, 'wrong total raised');
    assert(syndication_details.participant_count == 1, 'wrong participant count');

    let participant_details = ip_syndication.get_participant_details(ip_id, ALICE());

    assert(participant_details.amount_deposited == deposit, 'wrong amount deposited');
    assert(participant_details.minted == false, 'wrong minted status');
    assert(participant_details.amount_refunded == 0, 'wrong amount refunded');

    let alice_balance_after = erc20.balance_of(ALICE());
    let ip_syn_balance = erc20.balance_of(ip_syndication.contract_address);
    assert(ip_syn_balance == deposit, 'wrong ip syn balance');
    assert(
        alice_balance_after_balance_before - alice_balance_after == deposit, 'wrong owner balance'
    );
}

#[test]
fn test_deposit_with_excess_deposit() {
    let (ip_syndication, asset_nft, erc20, _) = setup();
    let description: ByteArray = "description";
    let uri: ByteArray = "flawless/";
    let price = 100_u256;
    let name = 'flawless';
    let licensing_terms = 'Exclusive license';
    let deposit = 200;
    let expected_deposit = deposit - price;

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

    let owner_balance_before = erc20.balance_of(OWNER());

    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, deposit);
    stop_cheat_caller_address(ip_syndication.contract_address);

    let all_participants = ip_syndication.get_all_participants(ip_id);

    assert(*all_participants.at(0) == OWNER(), 'wrong participant');

    let syndication_details = ip_syndication.get_syndication_details(ip_id);
    assert(syndication_details.total_raised == expected_deposit, 'wrong total raised');
    assert(syndication_details.participant_count == 1, 'wrong participant count');

    let participant_details = ip_syndication.get_participant_details(ip_id, OWNER());

    assert(participant_details.amount_deposited == expected_deposit, 'wrong amount deposited');
    assert(participant_details.minted == false, 'wrong minted status');
    assert(participant_details.amount_refunded == 0, 'wrong amount refunded');

    let owner_balance_after = erc20.balance_of(OWNER());
    let ip_syn_balance = erc20.balance_of(ip_syndication.contract_address);
    assert(ip_syn_balance == expected_deposit, 'wrong ip syn balance');
    assert(owner_balance_before - owner_balance_after == expected_deposit, 'wrong owner balance');
}

#[test]
fn test_get_participant_count() {
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

    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, 100);
    stop_cheat_caller_address(ip_syndication.contract_address);

    start_cheat_caller_address(ip_syndication.contract_address, ALICE());
    ip_syndication.deposit(ip_id, 100);
    stop_cheat_caller_address(ip_syndication.contract_address);

    assert(ip_syndication.get_participant_count(ip_id) == 2, 'wrong participant count');
}

#[test]
fn test_get_all_participants() {
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

    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, 100);
    stop_cheat_caller_address(ip_syndication.contract_address);

    start_cheat_caller_address(ip_syndication.contract_address, ALICE());
    ip_syndication.deposit(ip_id, 100);
    stop_cheat_caller_address(ip_syndication.contract_address);

    let participants = ip_syndication.get_all_participants(ip_id);
    assert(participants.len() == 2, 'wrong participant count');
    assert(*participants.at(0) == OWNER(), 'wrong participant');
    assert(*participants.at(1) == ALICE(), 'wrong participant');
}

#[test]
#[should_panic(expected: ('Not IP owner',))]
fn test_update_whitelist_non_owner() {
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

    ip_syndication.update_whitelist(ip_id, ALICE(), true);
}

#[test]
#[should_panic(expected: ('Syndication not active',))]
fn test_update_whitelist_syndication_non_active() {
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
    ip_syndication.update_whitelist(ip_id, ALICE(), true);
    stop_cheat_caller_address(ip_syndication.contract_address);
}

#[test]
#[should_panic(expected: ('Not in whitelist mode',))]
fn test_update_whitelist_not_in_whitelist_mode() {
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
    ip_syndication.update_whitelist(ip_id, ALICE(), true);
    stop_cheat_caller_address(ip_syndication.contract_address);
}

#[test]
fn test_update_whitelist_ok() {
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
    ip_syndication.update_whitelist(ip_id, ALICE(), true);
    stop_cheat_caller_address(ip_syndication.contract_address);

    assert(ip_syndication.is_whitelisted(ip_id, ALICE()), 'alice should be whitelisted');
    assert(!ip_syndication.is_whitelisted(ip_id, OWNER()), 'owner shouldnt be whitelisted');
}

#[test]
#[should_panic(expected: ('Not IP owner',))]
fn test_cancel_syndication_non_owner() {
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

    ip_syndication.cancel_syndication(ip_id);
}

#[test]
#[should_panic(expected: ('Syn: completed or cancelled',))]
fn test_cancel_syndication_when_completed() {
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

    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, 100);
    stop_cheat_caller_address(ip_syndication.contract_address);

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    ip_syndication.cancel_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);
}

#[test]
fn test_cancel_syndication_ok() {
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

    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, deposit);
    stop_cheat_caller_address(ip_syndication.contract_address);

    let owner_balance_before = erc20.balance_of(OWNER());

    start_cheat_caller_address(ip_syndication.contract_address, BOB());
    ip_syndication.cancel_syndication(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    let owner_balance_after = erc20.balance_of(OWNER());
    let syndication_details = ip_syndication.get_syndication_details(ip_id);

    assert(owner_balance_after == owner_balance_before + deposit, 'wrong owner balance');
    assert(erc20.balance_of(ip_syndication.contract_address) == 0, 'wrong balance after refund');
    assert(syndication_details.status == Status::Cancelled, 'wrong status');
}

#[test]
#[should_panic(expected: ('Syndication not completed',))]
fn test_mint_asset_non_competed_syn() {
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

    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, deposit);
    stop_cheat_caller_address(ip_syndication.contract_address);

    ip_syndication.mint_asset(ip_id);
}

#[test]
#[should_panic(expected: ('Not Syndication Participant',))]
fn test_mint_asset_non_participant() {
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

    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, deposit);
    stop_cheat_caller_address(ip_syndication.contract_address);

    start_cheat_caller_address(ip_syndication.contract_address, ALICE());
    ip_syndication.mint_asset(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);
}

#[test]
#[should_panic(expected: ('Already minted',))]
fn test_mint_asset_already_minted() {
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

    start_cheat_caller_address(ip_syndication.contract_address, mike);
    ip_syndication.deposit(ip_id, deposit);
    stop_cheat_caller_address(ip_syndication.contract_address);

    start_cheat_caller_address(ip_syndication.contract_address, mike);
    ip_syndication.mint_asset(ip_id);
    ip_syndication.mint_asset(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);
}

#[test]
fn test_mint_asset_ok() {
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

    start_cheat_caller_address(ip_syndication.contract_address, mike);
    ip_syndication.deposit(ip_id, deposit_1);
    ip_syndication.deposit(ip_id, deposit_2);
    stop_cheat_caller_address(ip_syndication.contract_address);

    start_cheat_caller_address(ip_syndication.contract_address, ALICE());
    ip_syndication.deposit(ip_id, 10_000);
    stop_cheat_caller_address(ip_syndication.contract_address);

    start_cheat_caller_address(ip_syndication.contract_address, OWNER());
    ip_syndication.deposit(ip_id, 100_000_000);
    stop_cheat_caller_address(ip_syndication.contract_address);

    start_cheat_caller_address(ip_syndication.contract_address, mike);
    ip_syndication.mint_asset(ip_id);
    stop_cheat_caller_address(ip_syndication.contract_address);

    let erc1155 = IERC1155Dispatcher { contract_address: asset_nft.contract_address };

    let balance_mike = erc1155.balance_of(mike, ip_id);

    assert(balance_mike == deposit_1 + deposit_2, 'wrong balance');
}
