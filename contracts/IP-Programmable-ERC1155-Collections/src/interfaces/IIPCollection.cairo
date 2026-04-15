use starknet::ContractAddress;
use crate::types::TokenData;

/// Public interface for an IPCollection ERC-1155 contract.
///
/// Each collection is a standalone ERC-1155 contract deployed by the factory.
/// The collection owner controls minting. Any holder can transfer their tokens.
/// IP provenance (original creator + registration timestamp) is recorded immutably
/// at first mint of each token type, satisfying the Berne Convention authorship standard.
#[starknet::interface]
pub trait IIPCollection<TContractState> {
    /// Mints `value` copies of a new or existing token type to `to`.
    ///
    /// Owner only. `to` must not be the zero address.
    /// For new token types (first mint of this `token_id`):
    ///   - `token_uri` is stored permanently and must start with `ipfs://` or `ar://`.
    ///   - `to` is recorded as the original creator.
    ///   - Block timestamp is recorded as the registration date.
    /// For existing token types (subsequent mints): `token_uri` is ignored.
    fn mint_item(
        ref self: TContractState,
        to: ContractAddress,
        token_id: u256,
        value: u256,
        token_uri: ByteArray,
    );

    /// Batch version of `mint_item`. All token IDs in the batch are minted to `to`.
    ///
    /// Owner only. `token_ids`, `values`, and `token_uris` must have equal length.
    /// For each token_id: URI is stored only on first mint of that type.
    fn batch_mint_item(
        ref self: TContractState,
        to: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        token_uris: Array<ByteArray>,
    );

    /// Returns the address that deployed this collection via the factory.
    /// Informational only — holds no special power beyond the Ownable owner.
    fn get_collection_creator(self: @TContractState) -> ContractAddress;

    /// Returns the address that first minted this token type.
    /// Immutable Berne Convention authorship record.
    /// Reverts if the token type has never been minted.
    fn get_token_creator(self: @TContractState, token_id: u256) -> ContractAddress;

    /// Returns the block timestamp recorded at first mint of this token type.
    /// Reverts if the token type has never been minted.
    fn get_token_registered_at(self: @TContractState, token_id: u256) -> u64;

    /// Returns all provenance fields for a token type in a single call.
    /// Reverts if the token type has never been minted.
    fn get_token_data(self: @TContractState, token_id: u256) -> TokenData;
}
