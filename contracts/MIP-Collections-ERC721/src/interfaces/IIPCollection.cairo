/// Interface for IP Collection contract, defining core collection and token management operations.
use starknet::{ClassHash, ContractAddress};
use crate::types::{Collection, CollectionStats, TokenData};

#[starknet::interface]
pub trait IIPCollection<ContractState> {
    /// Creates a new collection with the given `name`, `symbol`, and `base_uri`.
    /// Deploys a new IPNft ERC-721 contract for the collection.
    /// The caller becomes the collection owner.
    ///
    /// # Arguments
    /// * `name` - The name of the collection (must be non-empty).
    /// * `symbol` - The symbol of the collection (must be non-empty).
    /// * `base_uri` - The base URI for the collection's metadata.
    ///
    /// # Returns
    /// The unique identifier (`u256`) of the created collection.
    fn create_collection(
        ref self: ContractState, name: ByteArray, symbol: ByteArray, base_uri: ByteArray,
    ) -> u256;

    /// Mints a new token in the specified `collection_id` and assigns it to the `recipient`.
    /// Only the collection owner can mint.
    /// Token IDs start at 1. The `token_uri` must be a content-addressed URI (ipfs:// or ar://).
    ///
    /// # Arguments
    /// * `collection_id` - The identifier of the collection to mint in.
    /// * `recipient` - The address to receive the newly minted token.
    /// * `token_uri` - The content-addressed URI metadata for the token.
    ///
    /// # Returns
    /// The unique identifier (`u256`) of the minted token.
    fn mint(
        ref self: ContractState,
        collection_id: u256,
        recipient: ContractAddress,
        token_uri: ByteArray,
    ) -> u256;

    /// Mints tokens in batch for the specified `collection_id`.
    /// `recipients` and `token_uris` must be the same length.
    /// Only the collection owner can batch mint.
    ///
    /// # Arguments
    /// * `collection_id` - The identifier of the collection to mint in.
    /// * `recipients` - Array of addresses to receive the newly minted tokens.
    /// * `token_uris` - Array of content-addressed URIs for each token (must match recipients length).
    ///
    /// # Returns
    /// A Span of token IDs (`u256`) for the minted tokens.
    fn batch_mint(
        ref self: ContractState,
        collection_id: u256,
        recipients: Array<ContractAddress>,
        token_uris: Array<ByteArray>,
    ) -> Span<u256>;

    /// Archives a token, preserving the on-chain provenance record permanently.
    /// Archived tokens cannot be transferred or re-archived.
    /// Only the token owner can archive their token.
    /// This replaces destructive burning to comply with Berne Convention requirements —
    /// the legal record of IP creation is never deleted.
    ///
    /// # Arguments
    /// * `token` - The identifier of the token to archive (format: "collection_id:token_id").
    fn archive(ref self: ContractState, token: ByteArray);

    /// Archives multiple tokens in batch.
    /// Caller must own all tokens in the batch.
    ///
    /// # Arguments
    /// * `tokens` - Array of token identifiers to archive.
    fn batch_archive(ref self: ContractState, tokens: Array<ByteArray>);

    /// Transfers a `token` from `from` address to `to` address.
    /// The IPCollection contract must be approved for the token.
    /// The caller must be the token owner or an approved operator.
    ///
    /// # Arguments
    /// * `from` - Current owner of the token.
    /// * `to` - Recipient of the token.
    /// * `token` - Identifier of the token to transfer.
    fn transfer_token(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, token: ByteArray,
    );

    /// Transfers multiple `tokens` from `from` address to `to` address in batch.
    /// The IPCollection contract must be approved for each token.
    /// The caller must be the token owner or an approved operator.
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

    /// Updates the mutable metadata fields (name, symbol, base_uri) for a collection.
    /// Only the collection owner can update metadata.
    /// Emits a CollectionUpdated event.
    ///
    /// # Arguments
    /// * `collection_id` - The identifier of the collection to update.
    /// * `name` - New name (must be non-empty).
    /// * `symbol` - New symbol (must be non-empty).
    /// * `base_uri` - New base URI.
    fn update_collection_metadata(
        ref self: ContractState,
        collection_id: u256,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
    );

    /// Toggles the active state of a collection.
    /// Inactive collections reject all mint, archive, and transfer operations.
    /// Only the collection owner can toggle this.
    ///
    /// # Arguments
    /// * `collection_id` - The identifier of the collection.
    /// * `is_active` - The desired active state.
    fn set_collection_active(ref self: ContractState, collection_id: u256, is_active: bool);

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

    /// Returns the total number of collections ever created.
    ///
    /// # Returns
    /// * `u256` - Total collection count.
    fn get_collection_count(self: @ContractState) -> u256;

    /// Checks if a `collection_id` is valid and active.
    ///
    /// # Arguments
    /// * `collection_id` - The identifier of the collection.
    ///
    /// # Returns
    /// `true` if valid and active, `false` otherwise.
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

    /// Retrieves the full token data including immutable legal record fields.
    /// Reverts if the collection is inactive or the token does not exist.
    ///
    /// # Arguments
    /// * `token` - The identifier of the token (format: "collection_id:token_id").
    ///
    /// # Returns
    /// A `TokenData` struct including `original_creator` and `registered_at`.
    fn get_token(self: @ContractState, token: ByteArray) -> TokenData;

    /// Checks if a `token` identifier is valid (exists in an active collection).
    ///
    /// # Arguments
    /// * `token` - The identifier of the token.
    ///
    /// # Returns
    /// `true` if valid, `false` otherwise.
    fn is_valid_token(self: @ContractState, token: ByteArray) -> bool;

    /// Upgrades the IPNft class hash used for future collection deployments.
    /// Only affects new collections — already-deployed IPNft contracts are permanently immutable.
    /// Only callable by the IPCollection contract owner.
    ///
    /// # Arguments
    /// * `new_nft_class_hash` - Class hash of the new IP NFT contract.
    fn upgrade_ip_nft_class_hash(ref self: ContractState, new_nft_class_hash: ClassHash);
}
