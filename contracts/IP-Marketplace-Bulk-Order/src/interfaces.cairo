use starknet::ContractAddress;
use super::types::{IPAssetData, LicenseTerms,};

#[starknet::interface]
pub trait IIPMarketplace<TContractState> {
    fn bulk_purchase(ref self: TContractState, asset_ids: Array<u256>, total_amount: u256,);
    fn set_accepted_token(ref self: TContractState, token_address: ContractAddress);
    fn set_commission_wallet(ref self: TContractState, wallet_address: ContractAddress);
    fn set_paused(ref self: TContractState, paused: bool);
}

#[starknet::interface]
pub trait IIPTokenizer<TContractState> {
    fn bulk_tokenize(ref self: TContractState, assets: Array<IPAssetData>) -> Array<u256>;
    fn get_token_metadata(self: @TContractState, token_id: u256) -> IPAssetData;
    fn get_token_owner(self: @TContractState, token_id: u256) -> ContractAddress;
    fn get_token_expiry(self: @TContractState, token_id: u256) -> u64;
    fn update_metadata(ref self: TContractState, token_id: u256, new_metadata: ByteArray);
    fn update_license_terms(ref self: TContractState, token_id: u256, new_terms: LicenseTerms);
    fn transfer_token(ref self: TContractState, token_id: u256, to: ContractAddress);
    fn get_batch_status(self: @TContractState, batch_id: u256) -> u8;
    fn get_batch_limit(self: @TContractState) -> u32;
    fn set_batch_limit(ref self: TContractState, new_limit: u32);
    fn set_paused(ref self: TContractState, paused: bool);
    fn get_ipfs_gateway(self: @TContractState) -> ByteArray;
    fn set_ipfs_gateway(ref self: TContractState, gateway: ByteArray);
    fn get_hash(self: @TContractState, token_id: u256) -> ByteArray;
}
