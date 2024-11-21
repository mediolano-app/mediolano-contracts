use starknet::ContractAddress;

#[starknet::interface]
pub trait INameRegistry<TContractState> {
    fn store_name(
        ref self: TContractState, name: felt252, registration_type: NameRegistry::RegistrationType
    );
    fn get_name(self: @TContractState, address: ContractAddress) -> felt252;
    fn get_owner(self: @TContractState) -> NameRegistry::Person;
    fn store_metadata(
        ref self: TContractState,
        title: felt252,
        content: felt252,
        author: felt252,
        date: felt252
    ); // New function in the interface
}

#[starknet::contract]
mod NameRegistry {
    use starknet::{ContractAddress, get_caller_address, storage_access::StorageBaseAddress};

    #[storage]
    struct Storage {
        names: LegacyMap::<ContractAddress, felt252>,
        owner: Person,
        registration_type: LegacyMap::<ContractAddress, RegistrationType>,
        total_names: u128,
        metadata: LegacyMap::<ContractAddress, Metadata>, // New field for metadata
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        StoredName: StoredName,
    }
    #[derive(Drop, starknet::Event)]
    struct StoredName {
        #[key]
        user: ContractAddress,
        name: felt252,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Person {
        address: ContractAddress,
        name: felt252,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub enum RegistrationType {
        finite: u64,
        infinite
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Metadata {
        title: felt252,
        content: felt252,
        author: felt252,
        date: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: Person) {
        self.names.write(owner.address, owner.name);
        self.total_names.write(1);
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl NameRegistry of super::INameRegistry<ContractState> {
        fn store_name(ref self: ContractState, name: felt252, registration_type: RegistrationType) {
            let caller = get_caller_address();
            self._store_name(caller, name, registration_type);
        }

        fn get_name(self: @ContractState, address: ContractAddress) -> felt252 {
            self.names.read(address)
        }

        fn get_owner(self: @ContractState) -> Person {
            self.owner.read()
        }

        // New function to store metadata
        fn store_metadata(
            ref self: ContractState,
            title: felt252,
            content: felt252,
            author: felt252,
            date: felt252
        ) {
            let caller = get_caller_address();
            let metadata = Metadata {
                title,
                content,
                author,
                date,
            };
            self.metadata.write(caller, metadata);
        }
    }

    #[external(v0)]
    fn get_contract_name(self: @ContractState) -> felt252 {
        'Name Registry'
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _store_name(
            ref self: ContractState,
            user: ContractAddress,
            name: felt252,
            registration_type: RegistrationType
        ) {
            let total_names = self.total_names.read();
            self.names.write(user, name);
            self.registration_type.write(user, registration_type);
            self.total_names.write(total_names + 1);
            self.emit(StoredName { user: user, name: name });
        }
    }

    fn get_owner_storage_address(self: @ContractState) -> StorageBaseAddress {
        self.owner.address()
    }
}