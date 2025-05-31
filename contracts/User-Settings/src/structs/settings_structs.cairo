use starknet::ContractAddress;

// #[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
// pub struct EncryptedSetting {
//     ciphertext: felt252, // encrypted data
//     nonce: felt252, // encryption nonce
//     key_version: u64 // wallet key version used
// }

#[derive(Copy, Drop, Serde, starknet::Store, PartialEq, Default)]
pub struct AccountSetting {
    pub name: felt252,
    pub email: felt252,
    pub username: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store, PartialEq, Default)]
pub enum IPProtectionLevel {
    #[default]
    STANDARD, // use 0 to access it
    ADVANCED // use 1 to access it
}

#[derive(Copy, Drop, Serde, starknet::Store, PartialEq, Default)]
pub struct IPSettings {
    pub ip_protection_level: IPProtectionLevel,
    pub automatic_ip_registration: bool,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store, Default)]
pub struct NotificationSettings {
    pub enabled: bool,
    pub ip_updates: bool,
    pub blockchain_events: bool,
    pub account_activity: bool,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store, Default)]
pub struct Security {
    pub two_factor_authentication: bool,
    pub password: felt252 //the password here should be hashed before it is stored, maybe like Poseidon or Perdesen hash
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store, Default)]
pub enum NetworkType {
    #[default]
    TESTNET, // use 0 where it needs to be stored/read
    MAINNET // use 1 where it needs to be stored/read
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store, Default)]
pub enum GasPricePreference {
    LOW, // use 0 to refer to it
    #[default]
    MEDIUM, // use 1 to refer to it
    HIGH // use 2 to refer to it
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store, Default)]
pub struct NetworkSettings {
    pub network_type: NetworkType,
    pub gas_price_preference: GasPricePreference,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store, Default)]
pub struct AdvancedSettings {
    pub api_key: felt252, //should also be a hashed value that is stored, not the actual value
    pub data_retention: u64 //number of days data should be retained in case of account deletion
}

// Structure for storing wallet-specific encryption data
// Tracks the current public key, version, and last update time
// #[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
// pub struct WalletData {
//     pub_key: felt252,
//     version: felt252,
//     last_updated: u64
// }

// #[derive(Drop, Serde, starknet::Store)]
// pub struct EncryptedSetting {
//     data: felt252,
//     nonce: felt252,
//     pub_key: felt252,
//     timestamp: u64,
//     version: felt252
// }

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct FullUserSettings {
    account_settings: AccountSetting,
    ip_settings: IPSettings,
    notification_settings: NotificationSettings,
    security_settings: Security,
    network_settings: NetworkSettings,
    advanced_settings: AdvancedSettings,
    // x_verification: XVerification,
    // facebook_verification: FacebookVerification,
    social_verification: SocialVerification,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct XVerification {
    pub is_verified: bool,
    pub handler: felt252,
    pub user_address: ContractAddress,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct FacebookVerification {
    pub is_verified: bool,
    pub handler: felt252,
    pub user_address: ContractAddress,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct SocialVerification {
    pub x_verification_status: XVerification,
    pub facebook_verification_status: FacebookVerification,
}
