use starknet::ContractAddress;
use core::byte_array::ByteArray;
use core::integer::u256;

#[starknet::interface]
pub trait IIPOfferLicensing<T> {
    // Offer Management
    fn create_offer(
        ref self: T,
        ip_token_id: u256,
        payment_amount: u256,
        payment_token: ContractAddress,
        license_terms: ByteArray
    ) -> u256;

    fn accept_offer(ref self: T, offer_id: u256);
    fn reject_offer(ref self: T, offer_id: u256);
    fn cancel_offer(ref self: T, offer_id: u256);
    fn claim_refund(ref self: T, offer_id: u256);

    // View Functions
    fn get_offer(self: @T, offer_id: u256) -> Offer;
    fn get_offers_by_ip(self: @T, ip_token_id: u256) -> Array<u256>;
    fn get_offers_by_creator(self: @T, creator: ContractAddress) -> Array<u256>;
    fn get_offers_by_owner(self: @T, owner: ContractAddress) -> Array<u256>;
}

#[derive(Drop, starknet::Store, Serde, Clone)]
pub struct Offer {
    pub id: u256,
    pub ip_token_id: u256,
    pub creator: ContractAddress,
    pub owner: ContractAddress,
    pub payment_amount: u256,
    pub payment_token: ContractAddress,
    pub license_terms: ByteArray,
    pub status: OfferStatus,
    pub created_at: u64,
    pub updated_at: u64
}

#[derive(Drop, starknet::Store, Serde, Copy)]
#[allow(starknet::store_no_default_variant)]
#[derive(PartialEq)]
pub enum OfferStatus {
    Active,
    Accepted,
    Rejected,
    Cancelled
} 