use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
trait IMIPCollections<TContractState> {
    fn deploy_collection(
        self: @TContractState,
        salt: felt252,
        from_zero: bool,
        owner: ContractAddress,
    ) -> ContractAddress;

    fn create_collection(
        ref self: TContractState,
        name: felt252, 
        symbol: felt252
    ) -> ContractAddress;

    fn get_collection_count(
        self: @TContractState, 
        user: ContractAddress
    ) -> u64;

    fn get_collection_by_index(
        self: @TContractState, 
        user: ContractAddress, 
        index: u64
    ) -> CollectionInfo;

    fn get_all_collections_for_user(
        self: @TContractState, 
        user: ContractAddress
    ) -> Array<CollectionInfo>;
}

#[starknet::contract]
mod MIPCollections {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::utils::interfaces::{IUniversalDeployerDispatcher, IUniversalDeployerDispatcherTrait};
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StorableStoragePointerReadAccess, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait};

    use super::IMIPCollections;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // External
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    // Internal
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    const UDC_ADDRESS: felt252 = 0x041a78e741e5af4fec34b695679bc6891742439f7afb8484ecd7766661ad02bf;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,

        mip_classhash: ClassHash,
        user_collection_count: Map<ContractAddress, u64>,
        collections: Map<(ContractAddress, u64), CollectionInfo>,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct CollectionInfo {
        owner: ContractAddress,
        contract_address: ContractAddress, //to query a certain NFT, just go to this address and query the ID of the NFT
        name: felt252,
        symbol: felt252,
        deployment_timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct CollectionCreated {
        #[key]
        owner: ContractAddress,
        collection_address: ContractAddress,
        name: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        CollectionCreated: CollectionCreated,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, mip_classhash: ClassHash) {
        self.mip_classhash.write(mip_classhash);
        self.ownable.initializer(owner);
    }

    //
    // Upgradeable
    //
    
    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    impl MIPCollections of IMIPCollections<ContractState> {
        fn deploy_collection(
            self: @ContractState,
            salt: felt252,
            from_zero: bool,
            owner: ContractAddress,
            collection_name: felt252,
            collection_symbol: felt252,
        ) -> ContractAddress {

            let constructor_calldata = array![owner.try_into().unwrap()];
            let udc_dispatcher = IUniversalDeployerDispatcher {
                contract_address: UDC_ADDRESS.try_into().unwrap(),
            };
            let deployed_address = udc_dispatcher.deploy_contract(
                self.mip_classhash.read(), salt, false, constructor_calldata.span()
            );

            let collection_info = CollectionInfo {
                owner,
                contract_address: deployed_address,
                name: collection_name,
                symbol: collection_symbol, 
                deployment_timestamp: get_block_timestamp(),
            };
            self.user_collection_count.write(owner, self.user_collection_count.read(owner) + 1);
            self.collections.write((owner, self.user_collection_count.read(owner)), collection_info);
            
            deployed_address
        }

        //view functions
        fn get_collection_count(self: @ContractState, user: ContractAddress) -> u64 {
            self.user_collection_count.read(user)
        }

        fn get_collection_by_index(
            self: @ContractState, user: ContractAddress, index: u64
        ) -> CollectionInfo {
            self.collections.read((user, index))
        }
        
        fn get_all_collections_for_user(
            self: @ContractState, user: ContractAddress
        ) -> Array<CollectionInfo> {
            let count = self.user_collection_count.read(user);
            let mut all_collections = ArrayTrait::new();
            let mut i: u64 = 0;
            loop {
                if i >= count {
                    break;
                }
                let info = self.collections.read((user, i));
                all_collections.append(info);
                i += 1;
            };
            all_collections
        }
    }
}
