#[starknet::contract]
mod ERC1155CollectionContract {
    use starknet::{ClassHash, ContractAddress, get_contract_address, SyscallResultTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::syscalls::get_class_hash_at_syscall;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;
    use openzeppelin_token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use ip_programmable_erc1155_collections::interfaces::IERC1155Collection;

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
    impl ERC1155CollectionImpl of IERC1155Collection<ContractState> {
        fn class_hash(self: @ContractState) -> ClassHash {
            self.ERC1155Collection_class_hash.read()
        }

        fn mint(ref self: ContractState, to: ContractAddress, token_id: u256, value: u256) {
            self.ownable.assert_only_owner();
            self.erc1155.mint_with_acceptance_check(to, token_id, value, array![].span());
        }
    }
}
