use ip_programmable_erc_1155::types::TokenData;
use starknet::ContractAddress;

/// Public interface for the IPCollection1155 contract.
///
/// IPCollection1155 is a standalone, immutable, permissionless ERC-1155 multi-token contract.
/// Any user can mint a new token type into the same contract. No address holds privileged
/// power after deployment — the contract is fully trust-minimized. Each token type carries an
/// immutable IP provenance record: original creator address and registration timestamp, written
/// once at first mint and never modifiable. Per-token programmable license terms can be updated
/// by the original creator at any time.
#[starknet::interface]
pub trait IIPCollection1155<TContractState> {
    /// Mints `amount` units of a **new** token type to `recipient`.
    ///
    /// Assigns the next sequential token ID automatically.
    /// Callable by anyone — no access control.
    /// Validates:
    ///   - `recipient` is not the zero address
    ///   - `amount` > 0
    ///   - `token_uri` starts with `ipfs://` or `ar://`
    ///
    /// Reverts if `recipient` is a contract that does not implement
    /// IERC1155Receiver or ISRC6, preventing permanent token lockup.
    ///
    /// Returns the newly assigned token ID (starts at 1, increments by 1).
    fn mint_item(
        ref self: TContractState,
        recipient: ContractAddress,
        amount: u256,
        token_uri: ByteArray,
        license: ByteArray,
    ) -> u256;

    /// Updates the license terms for an existing token type.
    ///
    /// Only the original creator of that token type can call this.
    /// Emits `LicenseUpdated`.
    fn set_license(ref self: TContractState, token_id: u256, license: ByteArray);

    /// Returns the address that deployed this contract.
    /// Informational only — this address holds no special power over the contract.
    fn get_collection_creator(self: @TContractState) -> ContractAddress;

    /// Returns the original creator (caller at first mint) for a token type.
    /// This is the immutable Berne Convention authorship record.
    /// Reverts if the token does not exist.
    fn get_token_creator(self: @TContractState, token_id: u256) -> ContractAddress;

    /// Returns the block timestamp stored immutably at first mint.
    /// Reverts if the token does not exist.
    fn get_token_registered_at(self: @TContractState, token_id: u256) -> u64;

    /// Returns the current license terms for a token type.
    /// Returns an empty ByteArray if no license has been set.
    fn get_license(self: @TContractState, token_id: u256) -> ByteArray;

    /// Returns all provenance fields for a token type in a single call.
    /// Avoids multiple separate cross-contract calls.
    /// Reverts if the token does not exist.
    fn get_token_data(self: @TContractState, token_id: u256) -> TokenData;
}
