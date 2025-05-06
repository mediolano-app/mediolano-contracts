#[starknet::contract]
mod ERC1155CollectionsFactoryContract {
    use starknet::{ClassHash, ContractAddress, get_caller_address};
    use starknet::syscalls::deploy_syscall;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_utils::serde::SerializedAppend;
    use ip_programmable_erc1155_collections::interfaces::IERC1155CollectionsFactory;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        erc1155_collections_class_hash: ClassHash,
        contract_address_salt: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    pub mod Errors {
        pub const DEPLOYMENT_FAILED: felt252 = 'DEPLOYMENT_FAILED';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, erc1155_collections_class_hash: ClassHash
    ) {
        self.ownable.initializer(owner);
        self.erc1155_collections_class_hash.write(erc1155_collections_class_hash);
        self.contract_address_salt.write(0);
    }

    #[abi(embed_v0)]
    impl ERC1155CollectionsFactoryImpl of IERC1155CollectionsFactory<ContractState> {
        fn erc1155_collections_class_hash(self: @ContractState) -> ClassHash {
            self.erc1155_collections_class_hash.read()
        }

        fn update_erc1155_collections_class_hash(
            ref self: ContractState, new_erc1155_collections_class_hash: ClassHash
        ) {
            self.ownable.assert_only_owner();
            self.erc1155_collections_class_hash.write(new_erc1155_collections_class_hash);
        }

        fn deploy_erc1155_collection(
            ref self: ContractState,
            token_uri: ByteArray,
            recipient: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>
        ) -> ContractAddress {
            let contract_address_salt = self.contract_address_salt.read();
            let mut calldata = array![];
            calldata.append_serde(get_caller_address());
            calldata.append_serde(token_uri);
            calldata.append_serde(recipient);
            calldata.append_serde(token_ids);
            calldata.append_serde(values);
            let deploy_result = deploy_syscall(
                self.erc1155_collections_class_hash.read(),
                contract_address_salt,
                calldata.span(),
                false,
            );
            assert(deploy_result.is_ok(), Errors::DEPLOYMENT_FAILED);
            self.contract_address_salt.write(contract_address_salt + 1);
            let (contract_address, _) = deploy_result.unwrap();
            contract_address
        }
    }
}
