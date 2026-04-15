use starknet::{ClassHash, ContractAddress};

/// Public interface for the IPCollectionFactory contract.
///
/// The factory is the single deployment point for all IP ERC-1155 collections.
/// Anyone can deploy a new collection — the caller becomes its owner.
/// The factory owner can update the class hash used for future deployments
/// (e.g. after a protocol upgrade), without affecting existing collections.
#[starknet::interface]
pub trait IIPCollectionFactory<TContractState> {
    /// Returns the class hash used to deploy new collections.
    fn collection_class_hash(self: @TContractState) -> ClassHash;

    /// Updates the class hash for future collection deployments.
    /// Factory owner only. Does not affect already-deployed collections.
    fn update_collection_class_hash(ref self: TContractState, new_class_hash: ClassHash);

    /// Deploys a new IPCollection instance.
    ///
    /// Callable by anyone — the caller becomes the collection owner.
    /// Returns the address of the newly deployed collection.
    /// Emits `CollectionDeployed`.
    fn deploy_collection(
        ref self: TContractState, name: ByteArray, symbol: ByteArray,
    ) -> ContractAddress;
}
