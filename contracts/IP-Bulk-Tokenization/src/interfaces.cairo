use starknet::ContractAddress;
use super::types::{
    IPAssetData, 
    LicenseTerms, 
};

#[starknet::interface]
pub trait IIPNFT<TState> {
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn ownerOf(self: @TState, token_id: u256) -> ContractAddress;
    fn safeTransferFrom(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
    fn transferFrom(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn setApprovalForAll(ref self: TState, operator: ContractAddress, approved: bool);
    fn getApproved(self: @TState, token_id: u256) -> ContractAddress;
    fn isApprovedForAll(self: @TState, owner: ContractAddress, operator: ContractAddress) -> bool;
    fn mint(ref self: TState, to: ContractAddress) -> u256;
    fn burn(ref self: TState, token_id: u256) -> bool;
    fn has_any_IPNFT(self: @TState, address: ContractAddress) -> bool;
}

#[starknet::interface]
pub trait IAccessControl<TContractState> {
    fn has_role(self: @TContractState, role: felt252, account: ContractAddress) -> bool;
    fn get_role_admin(self: @TContractState, role: felt252) -> felt252;
    fn grant_role(ref self: TContractState, role: felt252, account: ContractAddress);
    fn revoke_role(ref self: TContractState, role: felt252, account: ContractAddress);
    fn renounce_role(ref self: TContractState, role: felt252, account: ContractAddress);
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
