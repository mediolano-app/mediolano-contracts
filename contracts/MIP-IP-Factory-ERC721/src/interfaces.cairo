// mip/imip.cairo
// Interface definitions for MIP Protocol

use starknet::ContractAddress;
use core::array::Span;

#[starknet::interface]
pub trait IMIP<ContractState> {
    fn mint_item(ref self: ContractState, recipient: ContractAddress, uri: ByteArray) -> u256;
}

#[starknet::interface]
pub trait IERC721<ContractState> {
    fn balance_of(self: @ContractState, account: ContractAddress) -> u256;
    fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    );
    fn transfer_from(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
    );
    fn approve(ref self: ContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: ContractState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @ContractState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;
}

#[starknet::interface]
pub trait IERC721CamelOnly<ContractState> {
    fn balanceOf(self: @ContractState, account: ContractAddress) -> u256;
    fn ownerOf(self: @ContractState, tokenId: u256) -> ContractAddress;
    fn safeTransferFrom(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        tokenId: u256,
        data: Span<felt252>,
    );
    fn transferFrom(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, tokenId: u256,
    );
    fn setApprovalForAll(ref self: ContractState, operator: ContractAddress, approved: bool);
    fn getApproved(self: @ContractState, tokenId: u256) -> ContractAddress;
    fn isApprovedForAll(
        self: @ContractState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;
}

#[starknet::interface]
pub trait IERC721Metadata<ContractState> {
    fn name(self: @ContractState) -> ByteArray;
    fn symbol(self: @ContractState) -> ByteArray;
    fn token_uri(self: @ContractState, token_id: u256) -> ByteArray;
}

#[starknet::interface]
pub trait IERC721MetadataCamelOnly<ContractState> {
    fn tokenURI(self: @ContractState, tokenId: u256) -> ByteArray;
}

#[starknet::interface]
pub trait IERC721Enumerable<ContractState> {
    fn total_supply(self: @ContractState) -> u256;
    fn token_by_index(self: @ContractState, index: u256) -> u256;
    fn token_of_owner_by_index(self: @ContractState, owner: ContractAddress, index: u256) -> u256;
}

#[starknet::interface]
pub trait IOwnable<ContractState> {
    fn owner(self: @ContractState) -> ContractAddress;
    fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: ContractState);
}

#[starknet::interface]
pub trait ICounter<ContractState> {
    fn current(self: @ContractState) -> u256;
    fn increment(ref self: ContractState);
    fn decrement(ref self: ContractState);
}

#[starknet::interface]
pub trait ISRC5<ContractState> {
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool;
}
