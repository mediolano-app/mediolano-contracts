/// Interface for IPNFT (Intellectual Property NFT) contract operations.
///
/// Provides standard ERC721-like functionality with additional collection management features.
use starknet::ContractAddress;

#[starknet::interface]
pub trait IIPNft<ContractState> {
    /// Mints a new token with the given `token_id` to the `recipient` address.
    ///
    /// # Arguments
    /// * `recipient` - The address to receive the newly minted token.
    /// * `token_id` - The unique identifier for the token to be minted.
    fn mint(ref self: ContractState, recipient: ContractAddress, token_id: u256);

    /// Burns (destroys) the token with the specified `token_id`.
    ///
    /// # Arguments
    /// * `token_id` - The unique identifier for the token to be burned.
    fn burn(ref self: ContractState, token_id: u256);

    /// Transfers the token with `token_id` from one address to another.
    ///
    /// # Arguments
    /// * `from` - The address sending the token.
    /// * `to` - The address receiving the token.
    /// * `token_id` - The unique identifier for the token to be transferred.
    fn transfer(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
    );

    /// Returns the unique identifier of the collection this contract manages.
    ///
    /// # Returns
    /// * `u256` - The collection ID.
    fn get_collection_id(self: @ContractState) -> u256;

    /// Returns the address of the collection manager.
    ///
    /// # Returns
    /// * `ContractAddress` - The address managing the collection.
    fn get_collection_manager(self: @ContractState) -> ContractAddress;

    /// Returns a list of all token IDs owned by the specified `user`.
    ///
    /// # Arguments
    /// * `user` - The address whose tokens are being queried.
    /// # Returns
    /// * `Span<u256>` - A span containing all token IDs owned by the user.
    fn get_all_user_tokens(self: @ContractState, user: ContractAddress) -> Span<u256>;

    /// Returns the total number of tokens minted in this collection.
    ///
    /// # Returns
    /// * `u256` - The total supply of tokens.
    fn get_total_supply(self: @ContractState) -> u256;

    /// Returns the URI metadata associated with the specified `token_id`.
    ///
    /// # Arguments
    /// * `token_id` - The unique identifier for the token.
    /// # Returns
    /// * `ByteArray` - The URI of the token's metadata.
    fn get_token_uri(self: @ContractState, token_id: u256) -> ByteArray;

    /// Returns the owner address of the specified `token_id`.
    ///
    /// # Arguments
    /// * `token_id` - The unique identifier for the token.
    /// # Returns
    /// * `ContractAddress` - The address of the token owner.
    fn get_token_owner(self: @ContractState, token_id: u256) -> ContractAddress;

    /// Checks if a given spender is approved to manage a specific token.
    ///
    /// # Arguments
    /// - `self`: The contract state.
    /// - `token_id`: The unique identifier of the token (u256).
    /// - `spender`: The address of the spender to check approval for.
    ///
    /// # Returns
    /// - `bool`: Returns `true` if the spender is approved for the specified token, otherwise
    /// `false`.
    fn is_approved_for_token(
        self: @ContractState, token_id: u256, spender: ContractAddress,
    ) -> bool;
}
