use core::starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct IPAssetData {
    pub metadata_uri: ByteArray,
    pub metadata_hash: ByteArray,
    pub owner: ContractAddress,
    pub asset_type: AssetType,
    pub license_terms: LicenseTerms,
    pub expiry_date: u64
}

#[derive(Default, Debug, Drop, Serde, starknet::Store, Clone, PartialEq)]
pub enum AssetType {
    #[default]
    Patent,
    Trademark,
    Copyright,
    TradeSecret,
}

#[derive(Default, Debug, Drop, Serde, starknet::Store, Clone, PartialEq)]
pub enum LicenseTerms {
    #[default]
    Standard,
    Premium,
    Exclusive,
    Custom,
}


// Error messages as constants
pub const INVALID_METADATA: felt252 = 'Invalid metadata';
pub const INVALID_ASSET_TYPE: felt252 = 'Invalid asset type';
pub const INVALID_LICENSE_TERMS: felt252 = 'Invalid license terms';
pub const UNAUTHORIZED: felt252 = 'Unauthorized';

pub const DEFAULT_BATCH_LIMIT: u32 = 50;
pub const ERROR_BATCH_TOO_LARGE: felt252 = 'Batch size exceeds limit';
pub const ERROR_EMPTY_BATCH: felt252 = 'Empty batch';
pub const ERROR_INVALID_HASH: felt252 = 'Invalid metadata hash';