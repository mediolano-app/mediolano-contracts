use starknet::{ClassHash, ContractAddress};

#[starknet::interface]
pub trait IERC1155CollectionsFactory<TState> {
    fn erc1155_collections_class_hash(self: @TState) -> ClassHash;
    fn update_erc1155_collections_class_hash(
        ref self: TState, new_erc1155_collections_class_hash: ClassHash
    );
    fn deploy_erc1155_collection(
        ref self: TState,
        token_uri: ByteArray,
        recipient: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>
    ) -> ContractAddress;
}

#[starknet::interface]
pub trait IERC1155CollectionsFactoryMixin<TState> {
    // IOwnable
    fn owner(self: @TState) -> ContractAddress;
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TState);
    // IERC1155CollectionsFactory
    fn erc1155_collections_class_hash(self: @TState) -> ClassHash;
    fn update_erc1155_collections_class_hash(
        ref self: TState, new_erc1155_collections_class_hash: ClassHash
    );
    fn deploy_erc1155_collection(
        ref self: TState,
        token_uri: ByteArray,
        recipient: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>
    ) -> ContractAddress;
}

#[starknet::interface]
pub trait IERC1155Collection<TState> {
    fn class_hash(self: @TState) -> ClassHash;
    fn mint(ref self: TState, to: ContractAddress, token_id: u256, value: u256);
}

#[starknet::interface]
pub trait IERC1155CollectionMixin<TState> {
    // IOwnable
    fn owner(self: @TState) -> ContractAddress;
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TState);
    // IERC1155
    fn balance_of(self: @TState, account: ContractAddress, token_id: u256) -> u256;
    fn balance_of_batch(
        self: @TState, accounts: Span<ContractAddress>, token_ids: Span<u256>,
    ) -> Span<u256>;
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        value: u256,
        data: Span<felt252>,
    );
    fn safe_batch_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>,
    );
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    // IERC1155MetadataURI
    fn uri(self: @TState, token_id: u256) -> ByteArray;
    // IERC1155Collection
    fn class_hash(self: @TState) -> ClassHash;
    fn mint(ref self: TState, to: ContractAddress, token_id: u256, value: u256);
}
