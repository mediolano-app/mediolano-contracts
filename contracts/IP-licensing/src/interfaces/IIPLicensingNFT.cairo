use starknet::ContractAddress;
use starknet::class_hash::ClassHash;
use core::fmt::{Debug, Formatter};
use ip_licensing::IPLicensingNFT::IPLicensingNFT;


// *************************************************************************
//                              INTERFACE of  Licensing
// *************************************************************************

#[starknet::interface]
pub trait IIPLicensingNFT<TContractState> {
    fn mint_license(
        ref self: TContractState, recipient: ContractAddress, metadata_uri: ByteArray,
    ) -> u256;
}
