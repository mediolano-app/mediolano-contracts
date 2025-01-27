use starknet::ContractAddress;
use starknet::class_hash::ClassHash;
use core::fmt::{Debug, Formatter};

// *************************************************************************
//                              INTERFACE of  Licensing
// *************************************************************************

// *************************************************************************
//                             EVENTS
// *************************************************************************

#[starknet::interface]
pub trait IIPLicensingNFT<TContractState> {
    fn mint_license_nft(
        ref self: TContractState,
        original_nft_id: u256,
        license_type: u8,
        duration : u32,
        royalty_rate: u8,
        upfront_fee : u256 ,
        sublicensing: bool,
        exclusivity : u8 ,
        metadata_cid: ByteArray
    );
    // fn get_user_token_id(self: @TContractState, user: ContractAddress) -> u256;
// fn get_last_minted_id(self: @TContractState) -> u256;
// fn get_token_mint_timestamp(self: @TContractState, token_id: u256) -> u64;
// fn upgrade(ref self: TContractState, Imp_hash: ClassHash);
// fn owner(self: @TContractState) -> ContractAddress;
// fn erc_721(self: @TContractState) -> ContractAddress;
// fn mint(ref self: TContractState, task_id: u256);

}
