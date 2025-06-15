use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
trait IMIPCollections<TContractState> {
    fn deploy_collection(
        self: @TContractState,
        salt: felt252,
        from_zero: bool,
        owner: ContractAddress,
    ) -> ContractAddress;
}

#[starknet::contract]
mod MIPCollections {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::utils::interfaces::{IUniversalDeployerDispatcher, IUniversalDeployerDispatcherTrait};
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};

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
        user_collection_count: StorageMap<ContractAddress, u64>,
        collections: StorageMap<(ContractAddress, u64), CollectionInfo>,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct CollectionInfo {
        owner: ContractAddress,
        contract_address: ContractAddress,
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
        ) -> ContractAddress {

            let constructor_calldata = array![owner.try_into().unwrap()];

            let udc_dispatcher = IUniversalDeployerDispatcher {
                contract_address: UDC_ADDRESS.try_into().unwrap(),
            };

            udc_dispatcher.deploy_contract(
                self.mip_classhash.read(), salt, false, constructor_calldata.span()
            )
        }
    }
}

#[starknet::contract]
mod CollectionManager {
    use starknet::{ContractAddress, ClassHash, get_caller_address, get_block_timestamp};
    use array::{ArrayTrait, SpanTrait};
    use option::OptionTrait;
    use traits::{TryInto, Into};
    use zeroable::Zeroable;

    // =================================================
    // INTERFACES
    // =================================================

    // Interface for the Starknet Universal Deployer Contract (UDC)
    #[starknet::interface]
    trait IUniversalDeployer<TContractState> {
        fn deploy_contract(
            self: @TContractState,
            class_hash: ClassHash,
            salt: felt252,
            unique: bool, // Note: UDC now uses `unique` instead of `from_zero`
            calldata: Span<felt252>
        ) -> ContractAddress;
    }

    // Public interface for our CollectionManager
    #[starknet::interface]
    trait ICollectionManager<TContractState> {
        // Creates a new NFT collection for the caller
        fn create_collection(
            ref self: TContractState, name: felt252, symbol: felt252
        ) -> ContractAddress;
        
        // --- View Functions for Client-Side Querying ---

        // Gets the total number of collections for a user
        fn get_collection_count(self: @TContractState, user: ContractAddress) -> u64;

        // Gets a specific collection by user and index
        fn get_collection_by_index(
            self: @TContractState, user: ContractAddress, index: u64
        ) -> CollectionInfo;
        
        // Gets all collections for a specific user
        fn get_all_collections_for_user(
            self: @TContractState, user: ContractAddress
        ) -> Array<CollectionInfo>;
    }

    // =================================================
    // STRUCTS AND EVENTS
    // =================================================

    // The data we store for each created collection
    #[derive(Drop, Serde, starknet::Store)]
    struct CollectionInfo {
        owner: ContractAddress,
        contract_address: ContractAddress,
        name: felt252,
        symbol: felt252,
        deployment_timestamp: u64,
    }
    
    // Event emitted when a new collection is created
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CollectionCreated: CollectionCreated,
    }

    #[derive(Drop, starknet::Event)]
    struct CollectionCreated {
        #[key]
        owner: ContractAddress,
        collection_address: ContractAddress,
        name: felt252,
    }
    
    // =================================================
    // STORAGE
    // =================================================

    #[storage]
    struct Storage {
        erc721_class_hash: ClassHash,
        user_collection_count: StorageMap<ContractAddress, u64>,
        collections: StorageMap<(ContractAddress, u64), CollectionInfo>,
    }

    const UDC_ADDRESS: felt252 = 0x041a78e741e5af4fec34b695679bc6891742439f7afb8484ecd7766661ad02bf;

    // =================================================
    // IMPLEMENTATION
    // =================================================

    #[external(v0)]
    impl CollectionManagerImpl of ICollectionManager<ContractState> {
        fn create_collection(
            ref self: ContractState, name: felt252, symbol: felt252
        ) -> ContractAddress {
            let owner = get_caller_address();
            let collection_index = self.user_collection_count.read(owner);
            let erc721_class_hash = self.erc721_class_hash.read();
            
            // --- 1. Prepare Constructor Calldata for the ERC721 Contract ---
            // Let's assume the ERC721 constructor is `constructor(name, symbol, owner)`
            let mut constructor_calldata = ArrayTrait::new();
            constructor_calldata.append(name);
            constructor_calldata.append(symbol);
            constructor_calldata.append(owner.into()); // Convert ContractAddress to felt252

            // --- 2. Deploy using the UDC ---
            let udc_address: ContractAddress = UDC_ADDRESS.try_into().unwrap();
            let udc = IUniversalDeployerDispatcher { contract_address: udc_address };
            
            // Generate a unique salt to ensure a new address every time
            let salt: felt252 = starknet::storage_access::storage_address_from_base_and_offset(
                owner.into(),
                collection_index.into()
            ).into();

            let deployed_address = udc.deploy_contract(
                erc721_class_hash, salt, true, constructor_calldata.span()
            );

            // --- 3. Store the Collection Info ---
            let info = CollectionInfo {
                owner,
                contract_address: deployed_address,
                name,
                symbol,
                deployment_timestamp: get_block_timestamp(),
            };
            self.collections.write((owner, collection_index), info);
            
            // --- 4. Increment the User's Collection Counter ---
            self.user_collection_count.write(owner, collection_index + 1);

            // --- 5. Emit Event and Return Address ---
            self.emit(Event::CollectionCreated(CollectionCreated { owner, collection_address: deployed_address, name }));
            deployed_address
        }

        // --- View Functions ---

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

    #[constructor]
    fn constructor(ref self: ContractState, erc721_class: ClassHash) {
        self.erc721_class_hash.write(erc721_class);
    }
}