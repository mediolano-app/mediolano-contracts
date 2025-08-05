use starknet::ContractAddress;
#[starknet::interface]
pub trait IIPIdentity<TContractState> {
    fn register_ip_id(
        ref self: TContractState,
        ip_id: felt252,
        metadata_uri: ByteArray,
        ip_type: ByteArray,
        license_terms: ByteArray,
    ) -> u256;

    fn update_ip_id_metadata(ref self: TContractState, ip_id: felt252, new_metadata_uri: ByteArray);

    fn get_ip_id_data(self: @TContractState, ip_id: felt252) -> IPIDData;

    fn get_token_id_by_ip(self: @TContractState, ip_id: felt252) -> u256;

    fn get_ip_metadata_uri(self: @TContractState, ip_id: felt252) -> ByteArray;

    fn get_ip_owner(self: @TContractState, ip_id: felt252) -> ContractAddress;

    fn get_total_supply(self: @TContractState) -> u256;

    fn get_user_ip_ids(self: @TContractState, owner: ContractAddress) -> Array<felt252>;

    fn verify_ip_id(ref self: TContractState, ip_id: felt252);
}

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct IPIDData {
    pub metadata_uri: ByteArray,
    pub ip_type: ByteArray,
    pub license_terms: ByteArray,
    pub is_verified: bool,
    pub created_at: u64,
    pub updated_at: u64,
}

#[starknet::contract]
pub mod IPIdentity {
    use core::{
        array::ArrayTrait, traits::{Into}, num::traits::Zero,
        starknet::{
            ContractAddress,
            storage::{
                StoragePointerWriteAccess, StoragePointerReadAccess, StorageMapReadAccess,
                StorageMapWriteAccess, Map, Vec, StoragePathEntry, VecTrait, MutableVecTrait
            },
            get_caller_address, get_block_timestamp,
        },
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::introspection::src5::SRC5Component;
    use super::{IIPIdentity, IPIDData};

    // Components
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Impls
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    // Implement ERC721HooksTrait
    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {}

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {}
    }

    // Constants
    const ERROR_ALREADY_REGISTERED: felt252 = 'IP ID already registered';
    const ERROR_NOT_OWNER: felt252 = 'Caller is not the owner';
    const ERROR_INVALID_IP_ID: felt252 = 'Invalid IP ID';

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        ip_id_to_token_id: Map<felt252, u256>,
        ip_id_data: Map<felt252, IPIDData>,
        owner_to_ip_ids: Map<ContractAddress, Vec<felt252>>,
        token_counter: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        IPIDRegistered: IPIDRegistered,
        IPIDUpdated: IPIDUpdated,
        IPIDVerified: IPIDVerified,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IPIDRegistered {
        #[key]
        pub ip_id: felt252,
        pub owner: ContractAddress,
        pub token_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IPIDUpdated {
        #[key]
        pub ip_id: felt252,
        pub owner: ContractAddress,
        pub timestamp: u64,
    }


    #[derive(Drop, starknet::Event)]
    pub struct IPIDVerified {
        #[key]
        pub ip_id: felt252,
        pub owner: ContractAddress,
        pub verifier: ContractAddress,
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
    ) {
        self.ownable.initializer(owner);
        self.erc721.initializer(name, symbol, base_uri);
    }

    #[abi(embed_v0)]
    impl IPIdentityImpl of IIPIdentity<ContractState> {
        fn register_ip_id(
            ref self: ContractState,
            ip_id: felt252,
            metadata_uri: ByteArray,
            ip_type: ByteArray,
            license_terms: ByteArray,
        ) -> u256 {
            // Check if IP ID is already registered
            assert(self.ip_id_to_token_id.read(ip_id).is_zero(), ERROR_ALREADY_REGISTERED);

            let caller = get_caller_address();

            // Mint NFT
            let token_id = self.token_counter.read() + 1;
            self.token_counter.write(token_id);
            self.erc721.mint(caller, token_id);

            // Store IP ID data
            let ip_data = IPIDData {
                metadata_uri,
                ip_type,
                license_terms,
                is_verified: false,
                created_at: get_block_timestamp(),
                updated_at: get_block_timestamp(),
            };

            self.ip_id_data.write(ip_id, ip_data);
            self.ip_id_to_token_id.write(ip_id, token_id);
            self.owner_to_ip_ids.entry(caller).append().write(ip_id);

            self.emit(IPIDRegistered { ip_id, owner: caller, token_id });

            token_id
        }

        fn update_ip_id_metadata(
            ref self: ContractState, ip_id: felt252, new_metadata_uri: ByteArray,
        ) {
            let token_id = self.get_token_id_by_ip(ip_id);
            let caller = get_caller_address();
            let owner = self.erc721.owner_of(token_id);
            assert(caller == owner, ERROR_NOT_OWNER);

            // Update data
            let mut ip_data = self.get_ip_id_data(ip_id);
            ip_data.metadata_uri = new_metadata_uri;
            ip_data.updated_at = get_block_timestamp();
            self.ip_id_data.write(ip_id, ip_data);

            self.emit(IPIDUpdated { ip_id, owner: caller, timestamp: get_block_timestamp() });
        }

        fn get_ip_id_data(self: @ContractState, ip_id: felt252) -> IPIDData {
            assert(self.ip_id_to_token_id.read(ip_id).is_non_zero(), ERROR_INVALID_IP_ID);
            self.ip_id_data.read(ip_id)
        }

        fn get_token_id_by_ip(self: @ContractState, ip_id: felt252) -> u256 {
            let token_id = self.ip_id_to_token_id.read(ip_id);
            assert(token_id.is_non_zero(), ERROR_INVALID_IP_ID);
            token_id
        }


        fn get_ip_owner(self: @ContractState, ip_id: felt252) -> ContractAddress {
            let token_id = self.ip_id_to_token_id.read(ip_id);
            assert(token_id.is_non_zero(), ERROR_INVALID_IP_ID);
            self.erc721.owner_of(token_id)
        }

        fn get_ip_metadata_uri(self: @ContractState, ip_id: felt252) -> ByteArray {
            let ip_data = self.get_ip_id_data(ip_id);
            ip_data.metadata_uri
        }

        fn get_user_ip_ids(self: @ContractState, owner: ContractAddress) -> Array<felt252> {
            let ids = self.owner_to_ip_ids.entry(owner);
            let mut arr: Array<felt252> = array![];
            let len = ids.len();
            let mut i = 0;
            while i != len {
                arr.append(ids.at(i).read());
                i = i + 1;
            };
            arr
        }

        fn get_total_supply(self: @ContractState) -> u256 {
            self.token_counter.read()
        }


        fn verify_ip_id(ref self: ContractState, ip_id: felt252) {
            self.ownable.assert_only_owner();

            let token_id = self.get_token_id_by_ip(ip_id);

            let owner = self.erc721.owner_of(token_id);
            let mut ip_data = self.get_ip_id_data(ip_id);
            ip_data.is_verified = true;
            ip_data.updated_at = get_block_timestamp();
            self.ip_id_data.write(ip_id, ip_data);

            self
                .emit(
                    IPIDVerified {
                        ip_id,
                        owner,
                        verifier: get_caller_address(),
                        timestamp: get_block_timestamp(),
                    },
                );
        }
    }
}
