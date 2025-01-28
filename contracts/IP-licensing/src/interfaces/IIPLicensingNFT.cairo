use starknet::ContractAddress;
use starknet::class_hash::ClassHash;
use core::fmt::{Debug, Formatter};
use ip_licensing::IPLicensingNFT::IPLicensingNFT::{IPLicenseData };


// *************************************************************************
//                              INTERFACE of  Licensing
// *************************************************************************

#[starknet::interface]
pub trait IIPLicensingNFT<TContractState> {
    fn mint_license_nft(
         ref self: TContractState,
        original_nft_id: u256,
        license_type: u8,
        duration: u32,
        royalty_rate: u8,
        upfront_fee: u256,
        sublicensing: bool,
        exclusivity: u8,
        metadata_cid: felt252
    )->u256;

    fn mint_and_store_license(
        ref self: TContractState,
        license_data: IPLicenseData,
        original_nft_id: u256,
    ) -> u256 ;

    fn prepare_license_data(
        ref self: TContractState,   
        original_nft_id: u256,
        license_type: u8,
        duration: u32,
        royalty_rate: u8,
        upfront_fee: u256,
        sublicensing: bool,
        exclusivity: u8,
        metadata_cid: felt252,
    ) -> IPLicenseData ;
    fn get_licensing_data(ref self: TContractState, nft_id: u256) -> IPLicenseData ;

}