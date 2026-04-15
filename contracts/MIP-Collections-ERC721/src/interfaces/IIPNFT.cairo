/// Interface for IPNFT (Intellectual Property NFT) contract operations.
use starknet::ContractAddress;

#[starknet::interface]
pub trait IIPNft<ContractState> {
    /// Mints a new token with the given `token_id` to the `recipient` address.
    /// The `token_uri` must be a content-addressed URI (ipfs:// or ar://) to ensure
    /// permanent, immutable metadata storage as required by Berne Convention compliance.
    ///
    /// # Arguments
    /// * `recipient` - The address to receive the newly minted token (recorded as original_creator).
    /// * `token_id` - The unique identifier for the token to be minted (must be > 0).
    /// * `token_uri` - The content-addressed URI for the token's metadata.
    fn mint(
        ref self: ContractState, recipient: ContractAddress, token_id: u256, token_uri: ByteArray,
    );

    /// Archives a token, marking it as inactive while preserving the on-chain record permanently.
    /// Archived tokens cannot be transferred or re-archived.
    /// The provenance record (creator, timestamp, URI) remains queryable forever for
    /// Berne Convention compliance — the legal evidence of creation is never destroyed.
    /// Only callable by DEFAULT_ADMIN_ROLE (the IPCollection factory).
    ///
    /// # Arguments
    /// * `token_id` - The unique identifier for the token to be archived.
    fn archive(ref self: ContractState, token_id: u256);

    /// Returns true if the token has been archived.
    /// Archived tokens retain their full on-chain legal record.
    ///
    /// # Arguments
    /// * `token_id` - The unique identifier of the token.
    fn is_archived(self: @ContractState, token_id: u256) -> bool;

    /// Returns the unique identifier of the collection this contract manages.
    ///
    /// # Returns
    /// * `u256` - The collection ID.
    fn get_collection_id(self: @ContractState) -> u256;

    /// Returns the address of the collection manager (IPCollection factory).
    ///
    /// # Returns
    /// * `ContractAddress` - The address managing the collection.
    fn get_collection_manager(self: @ContractState) -> ContractAddress;

    /// Returns the base URI of the collection.
    ///
    /// # Returns
    /// * `ByteArray` - The base URI of the collection.
    fn base_uri(self: @ContractState) -> ByteArray;

    /// Returns all token IDs owned by a specific address.
    ///
    /// # Arguments
    /// * `owner` - The address whose tokens are to be retrieved.
    ///
    /// # Returns
    /// * `Span<u256>` - A span containing all token IDs owned by the specified address.
    fn all_tokens_of_owner(self: @ContractState, owner: ContractAddress) -> Span<u256>;

    /// Returns true if the token exists (has ever been minted and not destroyed).
    /// Unlike owner_of, this never panics — it is safe to call for any token_id.
    ///
    /// # Arguments
    /// * `token_id` - The unique identifier of the token.
    fn token_exists(self: @ContractState, token_id: u256) -> bool;

    /// Returns all legal record fields for a token in a single cross-contract call.
    /// Reverts if the token does not exist.
    /// Use this instead of calling owner_of + token_uri + get_token_creator +
    /// get_token_registered_at separately — reduces 4 cross-contract calls to 1.
    ///
    /// # Arguments
    /// * `token_id` - The unique identifier of the token.
    ///
    /// # Returns
    /// * `owner` - Current token owner.
    /// * `metadata_uri` - Content-addressed URI (ipfs:// or ar://).
    /// * `original_creator` - Immutable creator address set at mint time.
    /// * `registered_at` - Immutable block timestamp set at mint time.
    fn get_full_token_data(
        self: @ContractState, token_id: u256,
    ) -> (ContractAddress, ByteArray, ContractAddress, u64);

    /// Returns the original creator address stored immutably at mint time.
    /// This is the permanent Berne Convention authorship record — it never changes
    /// regardless of subsequent ownership transfers.
    ///
    /// # Arguments
    /// * `token_id` - The unique identifier of the token.
    ///
    /// # Returns
    /// * `ContractAddress` - The original creator (first recipient) of the token.
    fn get_token_creator(self: @ContractState, token_id: u256) -> ContractAddress;

    /// Returns the block timestamp stored immutably at mint time.
    /// This is the permanent timestamped proof of IP creation for legal purposes.
    ///
    /// # Arguments
    /// * `token_id` - The unique identifier of the token.
    ///
    /// # Returns
    /// * `u64` - Unix timestamp (seconds) of the block in which the token was minted.
    fn get_token_registered_at(self: @ContractState, token_id: u256) -> u64;
}
