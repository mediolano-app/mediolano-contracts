use core::starknet::ContractAddress;
use core::byte_array::ByteArray;

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct IPAssetData {
    pub metadata_uri: ByteArray,
    pub owner: ContractAddress,
    pub asset_type: ByteArray,
    pub license_terms: ByteArray,
    pub expiry_date: u64
}

#[derive(Debug, Drop, Serde, starknet::Store, Clone, PartialEq)]
pub enum LicenseTerms {
    Standard,
    Premium,
    Exclusive,
    Custom,
}

#[derive(Drop, Serde, starknet::Store, Clone)]
struct MarketAsset {
    seller: ContractAddress,
    price: u256,
    metadata_uri: ByteArray,
    metadata_hash: ByteArray,
    is_active: bool
}

const DEFAULT_COMMISSION_RATE: u256 = 500; // 5%
const ERROR_INVALID_COMMISSION: felt252 = 'Invalid commission rate';
const ERROR_INVALID_PAYMENT: felt252 = 'Invalid payment token';
const ERROR_INVALID_PRICE: felt252 = 'Invalid price';
const ERROR_ASSET_NOT_FOUND: felt252 = 'Asset not found';
const ERROR_UNAUTHORIZED: felt252 = 'Unauthorized';
const ERROR_ALREADY_REGISTERED: felt252 = 'Asset already registered';
