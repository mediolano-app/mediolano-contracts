use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::PoseidonTrait;

use snforge_std::{
    ContractClassTrait, DeclareResult, DeclareResultTrait, declare, start_cheat_block_timestamp,
    start_cheat_caller_address, stop_cheat_block_timestamp, stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const};

use user_settings::interfaces::settings_interfaces::{
    IEncryptedPreferencesRegistryDispatcher, IEncryptedPreferencesRegistryDispatcherTrait,
};
use user_settings::structs::settings_structs::{IPProtectionLevel, NetworkType};
fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn mediolano_app() -> ContractAddress {
    contract_address_const::<'mediolano_app'>()
}

fn deploy_contract() -> (
    IEncryptedPreferencesRegistryDispatcher, ContractAddress, ContractAddress,
) {
    let contract = declare("EncryptedPreferencesRegistry").unwrap().contract_class();
    let owner = owner();
    let mediolano_app = mediolano_app();
    let constructor_calldata: Array<felt252> = array![owner.into(), mediolano_app.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    let dispatcher = IEncryptedPreferencesRegistryDispatcher { contract_address };

    (dispatcher, contract_address, owner)
}

#[test]
fn test_store_and_update_account_details() {
    let (dispatcher, this_contract, owner) = deploy_contract();
    let current_timestamp = 400_u64;
    let owner_name = 'owner';
    let owner_email = 'owner@gmail.com';
    let username = 'owner_user_name';

    start_cheat_block_timestamp(this_contract, current_timestamp);
    start_cheat_caller_address(this_contract, owner);
    dispatcher
        .store_account_details(
            owner_name,
            owner_email,
            username,
            current_timestamp //nonce, current_timestamp, version, pub_key, wallet_signature_arr
        );
    stop_cheat_caller_address(this_contract);
    stop_cheat_block_timestamp(this_contract);

    let mut account_details = dispatcher.get_account_settings(owner);
    assert(account_details.name == owner_name, 'Settings not updated properly');

    // let mut new_wallet_signature_arr: Array<felt252> = array!['r', 's'];

    start_cheat_block_timestamp(this_contract, current_timestamp);
    start_cheat_caller_address(this_contract, owner);
    dispatcher
        .update_account_details(
            Option::Some('new name'),
            Option::None,
            Option::None,
            current_timestamp //2, current_timestamp, version, pub_key, new_wallet_signature_arr
        );
    stop_cheat_caller_address(this_contract);
    stop_cheat_block_timestamp(this_contract);

    account_details = dispatcher.get_account_settings(owner);
    assert(account_details.name == 'new name', 'Settings not updated properly');
}

#[test]
fn test_store_and_update_ip_management_settings() {
    let (dispatcher, this_contract, owner) = deploy_contract();
    // let (current_timestamp, version, pub_key, mut wallet_signature) = (400_u64, 1, 'pub_key',
    // array!['s', 'r']);
    let current_timestamp = 400_u64;
    let mut protection_level = 0;
    let mut automatic_ip_registration = true;

    start_cheat_caller_address(this_contract, owner);
    start_cheat_block_timestamp(this_contract, current_timestamp);
    dispatcher
        .store_ip_management_settings(
            protection_level,
            automatic_ip_registration,
            current_timestamp //nonce, current_timestamp, version, pub_key, wallet_signature
        );
    let mut ip_management_settings = dispatcher.get_ip_settings(owner);
    stop_cheat_block_timestamp(this_contract);
    stop_cheat_caller_address(this_contract);

    assert(
        ip_management_settings.ip_protection_level == IPProtectionLevel::STANDARD,
        'Store setting 1 failed',
    );
    assert(ip_management_settings.automatic_ip_registration == true, 'Store setting 2 failed');

    // wallet_signature = array!['r', 's'];
    // nonce += 1;
    protection_level = 1;
    automatic_ip_registration = false;
    start_cheat_block_timestamp(this_contract, current_timestamp);
    start_cheat_caller_address(this_contract, owner);
    dispatcher
        .update_ip_management_settings(
            Option::Some(protection_level),
            Option::Some(automatic_ip_registration),
            current_timestamp //nonce, current_timestamp, version, pub_key, wallet_signature
        );
    stop_cheat_caller_address(this_contract);
    stop_cheat_block_timestamp(this_contract);
    ip_management_settings = dispatcher.get_ip_settings(owner);

    assert(
        ip_management_settings.ip_protection_level == IPProtectionLevel::ADVANCED,
        'Store setting failed',
    );
    assert(
        ip_management_settings.automatic_ip_registration == automatic_ip_registration,
        'Store setting failed',
    );
}

#[test]
fn test_store_and_update_notification_settings() {
    let (dispatcher, this_contract, owner) = deploy_contract();
    // let (current_timestamp, version, pub_key, mut wallet_signature) = (400_u64, 1, 'pub_key',
    // array!['s', 'r']);
    let current_timestamp = 400_u64;

    let enable_notifications = true;
    let ip_updates = true;
    let mut blockchain_events = true;
    let account_activity = true;
    // let mut nonce = 1;

    start_cheat_block_timestamp(this_contract, current_timestamp);
    start_cheat_caller_address(this_contract, owner);
    dispatcher
        .store_notification_settings(
            enable_notifications,
            ip_updates,
            blockchain_events,
            account_activity,
            current_timestamp //nonce, current_timestamp, version, pub_key, wallet_signature
        );
    stop_cheat_caller_address(this_contract);
    stop_cheat_block_timestamp(this_contract);

    let mut notification_settings = dispatcher.get_notification_settings(owner);
    assert(notification_settings.blockchain_events, 'Store setting failed');

    blockchain_events = false;
    // wallet_signature = array!['r', 's'];

    start_cheat_block_timestamp(this_contract, current_timestamp);
    start_cheat_caller_address(this_contract, owner);
    dispatcher
        .update_notification_settings(
            Option::Some(enable_notifications),
            Option::Some(ip_updates),
            Option::Some(blockchain_events),
            Option::Some(account_activity),
            current_timestamp // nonce + 1, current_timestamp, version, pub_key, wallet_signature
        );
    notification_settings = dispatcher.get_notification_settings(owner);
    stop_cheat_caller_address(this_contract);
    stop_cheat_block_timestamp(this_contract);

    assert(!notification_settings.blockchain_events, 'Update setting failed')
}

#[test]
fn test_store_and_update_security_settings() {
    let (dispatcher, this_contract, owner) = deploy_contract();
    // let (current_timestamp, version, pub_key, mut wallet_signature, mut nonce) = (400_u64, 1,
    // 'pub_key', array!['s', 'r'], 1);
    let current_timestamp = 400_u64;
    let mut password = 'password';

    let felt_caller: felt252 = owner.into();

    let hashed_password: felt252 = PoseidonTrait::new()
        .update_with(password)
        .update_with(current_timestamp)
        .update_with(felt_caller)
        .finalize()
        .into();

    start_cheat_block_timestamp(this_contract, current_timestamp);
    start_cheat_caller_address(this_contract, owner);
    dispatcher
        .store_security_settings(
            password,
            current_timestamp //nonce, current_timestamp, version, pub_key, wallet_signature
        );
    let mut security_settings = dispatcher.get_security_settings(owner);
    stop_cheat_caller_address(this_contract);
    stop_cheat_block_timestamp(this_contract);

    assert(security_settings.password == hashed_password, 'Store setting failed');

    password = 'new_password';

    start_cheat_block_timestamp(this_contract, current_timestamp);
    start_cheat_caller_address(this_contract, owner);
    dispatcher
        .update_security_settings(
            password,
            current_timestamp //nonce, current_timestamp, version, pub_key, wallet_signature
        );
    stop_cheat_caller_address(this_contract);
    stop_cheat_block_timestamp(this_contract);
    security_settings = dispatcher.get_security_settings(owner);
    // assert(security_settings.password == 'new_password', 'Update Setting failed')
// These two will fail, simply because the hash of the password is what is stored, not the
// password

}

#[test]
fn test_store_and_update_network_settings() {
    let (dispatcher, this_contract, owner) = deploy_contract();
    // let (current_timestamp, version, pub_key, mut wallet_signature, mut nonce) = (400_u64, 1,
    // 'pub_key', array!['s', 'r'], 1);
    let current_timestamp = 400_u64;
    let mut network_type = 0;
    let mut gas_price_preference = 0;

    start_cheat_block_timestamp(this_contract, current_timestamp);
    start_cheat_caller_address(this_contract, owner);
    dispatcher
        .store_network_settings(
            network_type,
            gas_price_preference,
            current_timestamp //nonce, current_timestamp, version, pub_key, wallet_signature
        );
    stop_cheat_caller_address(this_contract);
    stop_cheat_block_timestamp(this_contract);
    let mut network_settings = dispatcher.get_network_settings(owner);

    assert(network_settings.network_type == NetworkType::TESTNET, 'Store setting failed');

    network_type = 1;
    gas_price_preference = 1;

    start_cheat_block_timestamp(this_contract, current_timestamp);
    start_cheat_caller_address(this_contract, owner);
    dispatcher
        .update_network_settings(
            Option::Some(network_type), Option::Some(gas_price_preference), current_timestamp,
        );
    stop_cheat_caller_address(this_contract);
    stop_cheat_block_timestamp(this_contract);
    network_settings = dispatcher.get_network_settings(owner);

    assert(network_settings.network_type == NetworkType::MAINNET, 'Update setting failed');
}

#[test]
fn test_store_advanced_settings() {
    let (dispatcher, this_contract, owner) = deploy_contract();
    // let (current_timestamp, version, pub_key, mut wallet_signature, nonce) = (400_u64, 1,
    // 'pub_key', array!['s', 'r'], 1);
    let current_timestamp = 400_u64;
    let api_key = 'api_key';

    start_cheat_block_timestamp(this_contract, current_timestamp);
    start_cheat_caller_address(this_contract, owner);
    dispatcher
        .store_advanced_settings(
            api_key,
            current_timestamp //nonce, current_timestamp, version, pub_key, wallet_signature
        );
    stop_cheat_caller_address(this_contract);
    stop_cheat_block_timestamp(this_contract);

    let advanced_settings = dispatcher.get_advanced_settings(owner);
    assert(advanced_settings.api_key == api_key, 'Store setting failed')
}

#[test]
fn test_store_x_verification() {
    let (dispatcher, this_contract, owner) = deploy_contract();
    // let (current_timestamp, version, pub_key, mut wallet_signature, mut nonce) = (400_u64, 1,
    // 'pub_key', array!['s', 'r'], 1);
    let current_timestamp = 400_u64;

    let x_handler = 'my_x_handler';

    start_cheat_block_timestamp(this_contract, current_timestamp);
    start_cheat_caller_address(this_contract, owner);
    dispatcher
        .store_X_verification(
            true,
            current_timestamp,
            x_handler //nonce, current_timestamp, version, pub_key, wallet_signature, x_handler
        );
    stop_cheat_caller_address(this_contract);
    stop_cheat_block_timestamp(this_contract);
}

// #[test]
// fn test_regenerate_api_key() {
//     let (dispatcher, this_contract, owner) = deploy_contract();
//     // let (current_timestamp, version, pub_key, mut wallet_signature) = (400_u64, 1, 'pub_key',
//     array!['s', 'r']);
//     let current_timestamp = 400_u64;
// }

#[test]
fn test_delete_account() {
    let (dispatcher, this_contract, owner) = deploy_contract();
    // let (current_timestamp, version, pub_key, mut wallet_signature, mut nonce) = (400_u64, 1,
    // 'pub_key', array!['s', 'r'], 1);
    let current_timestamp = 400_u64;

    start_cheat_block_timestamp(this_contract, current_timestamp);
    start_cheat_caller_address(this_contract, owner);
    dispatcher.delete_account(current_timestamp);
    dispatcher.delete_account(current_timestamp);
    stop_cheat_caller_address(this_contract);
    stop_cheat_block_timestamp(this_contract);

    let account_settings = dispatcher.get_account_settings(owner);
    assert(account_settings == Default::default(), 'Delete Account Failed');
}
