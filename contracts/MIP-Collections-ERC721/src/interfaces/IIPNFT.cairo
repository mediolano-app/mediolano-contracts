/// Interface for IPNFT (Intellectual Property NFT) contract operations.
use starknet::ContractAddress;

#[starknet::interface]
pub trait IIPNft<ContractState> {
    /// Mints a new token with the given `token_id` to the `recipient` address.
    ///
    /// # Arguments
    /// * `recipient` - The address to receive the newly minted token.
    /// * `token_id` - The unique identifier for the token to be minted.
    /// * `token_uri` - The URI metadata associated with the token.
    fn mint(
        ref self: ContractState, recipient: ContractAddress, token_id: u256, token_uri: ByteArray,
    );

    /// Burns (destroys) the token with the specified `token_id`.
    ///
    /// # Arguments
    /// * `token_id` - The unique identifier for the token to be burned.
    fn burn(ref self: ContractState, token_id: u256);

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

    /// Returns the base uri of the collection.
    ///
    /// # Returns
    /// * `ByteArray` - The base uri of the collection.
    fn base_uri(self: @ContractState) -> ByteArray;

    /// Returns all tokens owned by a specific address.
    /// # Arguments
    /// * `owner` - The address whose tokens are to be retrieved.
    /// # Returns
    /// * `Span<u256>` - A span containing all token IDs owned by the specified address.
    fn all_tokens_of_owner(self: @ContractState, owner: ContractAddress) -> Span<u256>;
}
