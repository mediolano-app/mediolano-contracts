use starknet::ContractAddress;
use user_settings::structs::settings_structs::{
    AccountSetting, IPProtectionLevel, IPSettings, NotificationSettings, Security, NetworkSettings,
    AdvancedSettings, NetworkType, GasPricePreference, SocialVerification //, WalletData
};

#[starknet::interface]
pub trait IEncryptedPreferencesRegistry<TContractState> {
    //
    fn store_account_details(
        ref self: TContractState, name: felt252, email: felt252, username: felt252, // nonce: felt252,
        timestamp: u64,
        // version: felt252,
    // pub_key: felt252,
    // wallet_signature: Array<felt252>
    );
    fn update_account_details(
        ref self: TContractState,
        name: Option<felt252>,
        email: Option<felt252>,
        username: Option<felt252>,
        // nonce: felt252,
        timestamp: u64,
        // version: felt252,
    // pub_key: felt252,
    // wallet_signature: Array<felt252>
    );
    fn store_ip_management_settings(
        ref self: TContractState,
        protection_level: u8,
        automatic_ip_registration: bool,
        // nonce: felt252,
        timestamp: u64,
        // version: felt252,
    // pub_key: felt252,
    // wallet_signature: Array<felt252>
    );
    fn update_ip_management_settings(
        ref self: TContractState,
        protection_level: Option<u8>,
        automatic_ip_registration: Option<bool>,
        // nonce: felt252,
        timestamp: u64,
        // version: felt252,
    // pub_key: felt252,
    // wallet_signature: Array<felt252>
    );
    fn store_notification_settings(
        ref self: TContractState,
        enable_notifications: bool,
        ip_updates: bool,
        blockchain_events: bool,
        account_activity: bool,
        // nonce: felt252,
        timestamp: u64,
        // version: felt252,
    // pub_key: felt252,
    // wallet_signature: Array<felt252>
    );
    fn update_notification_settings(
        ref self: TContractState,
        enable_notifications: Option<bool>,
        ip_updates: Option<bool>,
        blockchain_events: Option<bool>,
        account_activity: Option<bool>,
        // nonce: felt252,
        timestamp: u64,
        // version: felt252,
    // pub_key: felt252,
    // wallet_signature: Array<felt252>
    );
    fn store_security_settings(ref self: TContractState, password: felt252, // nonce: felt252,
    timestamp: u64// version: felt252,
    // pub_key: felt252,
    // wallet_signature: Array<felt252>
    );
    fn update_security_settings(ref self: TContractState, password: felt252, // nonce: felt252,
    timestamp: u64// version: felt252,
    // pub_key: felt252,
    // wallet_signature: Array<felt252>
    );
    fn store_network_settings(
        ref self: TContractState, network_type: u8, gas_price_preference: u8, // nonce: felt252,
        timestamp: u64,
        // version: felt252,
    // pub_key: felt252,
    // wallet_signature: Array<felt252>
    );
    fn update_network_settings(
        ref self: TContractState,
        network_type: Option<u8>,
        gas_price_preference: Option<u8>,
        // nonce: felt252,
        timestamp: u64,
        // version: felt252,
    // pub_key: felt252,
    // wallet_signature: Array<felt252>
    );
    fn store_advanced_settings(ref self: TContractState, api_key: felt252, // nonce: felt252,
    timestamp: u64// version: felt252,
    // pub_key: felt252,
    // wallet_signature: Array<felt252>
    );
    fn store_X_verification(
        ref self: TContractState, x_verified: bool, // nonce: felt252,
        timestamp: u64, // version: felt252,
        // pub_key: felt252,
        // wallet_signature: Array<felt252>,
        handler: felt252,
    );
    fn regenerate_api_key(ref self: TContractState, // nonce: felt252,
    timestamp: u64// version: felt252,
    // pub_key: felt252,
    // wallet_signature: Array<felt252>
    ) -> felt252;
    fn delete_account(ref self: TContractState, // nonce: felt252,
    timestamp: u64// version: felt252,
    // pub_key: felt252,
    // wallet_signature: Array<felt252>
    );
    // READ FUNCTIONS
    fn get_account_settings(self: @TContractState, user: ContractAddress) -> AccountSetting;
    fn get_network_settings(self: @TContractState, user: ContractAddress) -> NetworkSettings;
    fn get_ip_settings(self: @TContractState, user: ContractAddress) -> IPSettings;
    fn get_notification_settings(
        self: @TContractState, user: ContractAddress,
    ) -> NotificationSettings;
    fn get_security_settings(self: @TContractState, user: ContractAddress) -> Security;
    fn get_advanced_settings(self: @TContractState, user: ContractAddress) -> AdvancedSettings;
    // fn get_public_key(self: @TContractState) -> felt252;
    // fn get_nonce(self: @TContractState) -> felt252;
    fn get_social_verification(self: @TContractState, user: ContractAddress) -> SocialVerification;
}
