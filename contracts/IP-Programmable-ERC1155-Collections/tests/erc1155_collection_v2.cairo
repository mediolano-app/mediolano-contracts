use starknet::{ClassHash, ContractAddress};

#[starknet::interface]
pub trait IERC1155CollectionV2<TState> {
    fn class_hash(self: @TState) -> ClassHash;
    fn mint(ref self: TState, to: ContractAddress, token_id: u256, value: u256);
    fn batch_mint(ref self: TState, to: ContractAddress, token_ids: Span<u256>, values: Span<u256>);
}

#[starknet::interface]
pub trait IERC1155CollectionV2Mixin<TState> {
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
    // IERC1155CollectionV2
    fn class_hash(self: @TState) -> ClassHash;
    fn mint(ref self: TState, to: ContractAddress, token_id: u256, value: u256);
    fn batch_mint(ref self: TState, to: ContractAddress, token_ids: Span<u256>, values: Span<u256>);
}

#[starknet::contract]
mod ERC1155CollectionContractV2 {
    use starknet::{ClassHash, ContractAddress, get_contract_address, SyscallResultTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::syscalls::get_class_hash_at_syscall;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;
    use openzeppelin_token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use super::IERC1155CollectionV2;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // ERC1155 Mixin
    #[abi(embed_v0)]
    impl ERC1155MixinImpl = ERC1155Component::ERC1155MixinImpl<ContractState>;
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        ERC1155Collection_class_hash: ClassHash,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        ERC1155Event: ERC1155Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        token_uri: ByteArray,
        recipient: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>
    ) {
        self.ownable.initializer(owner);
        self.erc1155.initializer(token_uri);
        self
            .erc1155
            .batch_mint_with_acceptance_check(recipient, token_ids, values, array![].span());
        let class_hash = get_class_hash_at_syscall(get_contract_address()).unwrap_syscall();
        self.ERC1155Collection_class_hash.write(class_hash);
    }

    #[abi(embed_v0)]
    impl ERC1155CollectionUpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            // Replace the class hash upgrading the contract
            self.upgradeable.upgrade(new_class_hash);

            self.ERC1155Collection_class_hash.write(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl ERC1155CollectionImpl of IERC1155CollectionV2<ContractState> {
        fn class_hash(self: @ContractState) -> ClassHash {
            self.ERC1155Collection_class_hash.read()
        }

        fn mint(ref self: ContractState, to: ContractAddress, token_id: u256, value: u256) {
            self.ownable.assert_only_owner();
            self.erc1155.mint_with_acceptance_check(to, token_id, value, array![].span());
        }

        fn batch_mint(
            ref self: ContractState, to: ContractAddress, token_ids: Span<u256>, values: Span<u256>
        ) {
            self.ownable.assert_only_owner();
            self.erc1155.batch_mint_with_acceptance_check(to, token_ids, values, array![].span());
        }
    }
}
