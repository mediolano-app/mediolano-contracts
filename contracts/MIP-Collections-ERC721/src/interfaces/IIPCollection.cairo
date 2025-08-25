/// Interface for IP Collection contract, defining core collection and token management operations.
use starknet::{ClassHash, ContractAddress};
use crate::types::{Collection, CollectionStats, TokenData};

#[starknet::interface]
pub trait IIPCollection<ContractState> {
    /// Creates a new collection with the given `name`, `symbol`, and `base_uri`.
    ///
    /// # Arguments
    /// * `name` - The name of the collection.
    /// * `symbol` - The symbol of the collection.
    /// * `base_uri` - The base URI for the collection's metadata.
    ///
    /// # Returns
    /// The unique identifier (`u256`) of the created collection.
    fn create_collection(
        ref self: ContractState, name: ByteArray, symbol: ByteArray, base_uri: ByteArray,
    ) -> u256;

    /// Mints a new token in the specified `collection_id` and assigns it to the `recipient`.
    ///
    /// # Arguments
    /// * `collection_id` - The identifier of the collection to mint in.
    /// * `recipient` - The address to receive the newly minted token.
    /// * `token_uri` - The URI metadata associated with the token.
    ///
    /// # Returns
    /// The unique identifier (`u256`) of the minted token.
    fn mint(
        ref self: ContractState,
        collection_id: u256,
        recipient: ContractAddress,
        token_uri: ByteArray,
    ) -> u256;

    /// Mints tokens in batch for the specified `collection_id` and `recipients`.
    ///
    /// # Arguments
    /// * `collection_id` - The identifier of the collection to mint in.
    /// * `recipients` - Array of addresses to receive the newly minted tokens.
    /// * `token_uris` - Array of URIs metadata associated with each token.
    ///
    /// # Returns
    /// A Span of token IDs (`u256`) for the minted tokens.
    fn batch_mint(
        ref self: ContractState,
        collection_id: u256,
        recipients: Array<ContractAddress>,
        token_uris: Array<ByteArray>,
    ) -> Span<u256>;

    /// Burns (destroys) the specified `token`.
    ///
    /// # Arguments
    /// * `token` - The identifier of the token to burn.
    fn burn(ref self: ContractState, token: ByteArray);

    /// Burns (destroys) multiple `tokens` in batch.
    ///
    /// # Arguments
    /// * `tokens` - Array of token identifiers to burn.
    fn batch_burn(ref self: ContractState, tokens: Array<ByteArray>);

    /// Transfers a `token` from `from` address to `to` address.
    ///
    /// # Arguments
    /// * `from` - Current owner of the token.
    /// * `to` - Recipient of the token.
    /// * `token` - Identifier of the token to transfer.
    fn transfer_token(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, token: ByteArray,
    );

    /// Transfers multiple `tokens` from `from` address to `to` address in batch.
    ///
    /// # Arguments
    /// * `from` - Current owner of the tokens.
    /// * `to` - Recipient of the tokens.
    /// * `tokens` - Array of token identifiers to transfer.
    fn batch_transfer(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        tokens: Array<ByteArray>,
    );

    /// Lists all token IDs owned by `user` in a specific `collection_id`.
    ///
    /// # Arguments
    /// * `collection_id` - The identifier of the collection.
    /// * `user` - The address whose tokens are to be listed.
    ///
    /// # Returns
    /// A Span of token IDs (`u256`).
    fn list_user_tokens_per_collection(
        self: @ContractState, collection_id: u256, user: ContractAddress,
    ) -> Span<u256>;

    /// Lists all collection IDs owned by `user`.
    ///
    /// # Arguments
    /// * `user` - The address whose collections are to be listed.
    ///
    /// # Returns
    /// A Span of collection IDs (`u256`).
    fn list_user_collections(self: @ContractState, user: ContractAddress) -> Span<u256>;

    /// Retrieves the metadata of a collection by its `collection_id`.
    ///
    /// # Arguments
    /// * `collection_id` - The identifier of the collection.
    ///
    /// # Returns
    /// A `Collection` struct.
    fn get_collection(self: @ContractState, collection_id: u256) -> Collection;


    /// Checks if a `collection_id` is valid (exists).
    ///
    /// # Arguments
    /// * `collection_id` - The identifier of the collection.
    ///
    /// # Returns
    /// `true` if valid, `false` otherwise.
    fn is_valid_collection(self: @ContractState, collection_id: u256) -> bool;

    /// Retrieves statistics for a collection by its `collection_id`.
    ///
    /// # Arguments
    /// * `collection_id` - The identifier of the collection.
    ///
    /// # Returns
    /// A `CollectionStats` struct.
    fn get_collection_stats(self: @ContractState, collection_id: u256) -> CollectionStats;

    /// Checks if the given `owner` address is the owner of the specified `collection_id`.
    ///
    /// # Arguments
    /// * `collection_id` - The identifier of the collection.
    /// * `owner` - The address to check for ownership.
    ///
    /// # Returns
    /// `true` if the address is the owner, `false` otherwise.
    fn is_collection_owner(
        self: @ContractState, collection_id: u256, owner: ContractAddress,
    ) -> bool;

    /// Retrieves the metadata of a token by its `token` identifier.
    ///
    /// # Arguments
    /// * `token` - The identifier of the token.
    ///
    /// # Returns
    /// A `TokenData` struct.
    fn get_token(self: @ContractState, token: ByteArray) -> TokenData;

    /// Checks if a `token` identifier is valid (exists).
    ///
    /// # Arguments
    /// * `token` - The identifier of the token.
    ///
    /// # Returns
    /// `true` if valid, `false` otherwise.
    fn is_valid_token(self: @ContractState, token: ByteArray) -> bool;

    /// Upgrades the collection nft class hash
    ///
    /// Params:
    /// - `new_nft_class_hash`: Class hash of new IP NFT contract
    ///
    fn upgrade_ip_nft_class_hash(ref self: ContractState, new_nft_class_hash: ClassHash);
}
