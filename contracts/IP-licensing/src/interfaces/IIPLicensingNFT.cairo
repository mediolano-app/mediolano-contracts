use starknet::ContractAddress;
use starknet::class_hash::ClassHash;
use core::fmt::{Debug, Formatter};

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
        metadata_cid: ByteArray
    );


}
