use core::starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct IPAssetData {
    pub metadata_uri: ByteArray,
    pub owner: ContractAddress,
    pub asset_type: ByteArray,
    pub license_terms: ByteArray,
    pub expiry_date: u64
}

#[derive(Debug, Drop, Serde, starknet::Store, Clone, PartialEq)]
pub enum AssetType {
    Patent,
    Trademark,
    Copyright,
    TradeSecret,
}

#[derive(Debug, Drop, Serde, starknet::Store, Clone, PartialEq)]
pub enum LicenseTerms {
    Standard,
    Premium,
    Exclusive,
    Custom,
}

// Error messages as constants
const INVALID_METADATA: felt252 = 'Invalid metadata';
const INVALID_ASSET_TYPE: felt252 = 'Invalid asset type';
const INVALID_LICENSE_TERMS: felt252 = 'Invalid license terms';
const UNAUTHORIZED: felt252 = 'Unauthorized';
