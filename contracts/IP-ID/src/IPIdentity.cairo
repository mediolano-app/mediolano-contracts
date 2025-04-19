#[starknet::interface]
pub trait IIPIdentity<TContractState> {
    fn register_ip_id(
        ref self: TContractState,
        ip_id: felt252,
        metadata_uri: ByteArray,
        ip_type: ByteArray,
        license_terms: ByteArray,
    ) -> u256;

    fn update_ip_id_metadata(
        ref self: TContractState, ip_id: felt252, new_metadata_uri: ByteArray,
    );

    fn get_ip_id_data(self: @TContractState, ip_id: felt252) -> IPIDData;

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
        array::ArrayTrait, traits::{Into,}, num::traits::Zero,
        starknet::{
            ContractAddress,
            storage::{
                StoragePointerWriteAccess, StoragePointerReadAccess, StorageMapReadAccess,
                StorageMapWriteAccess, Map
            },
            get_caller_address, get_block_timestamp
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
            auth: ContractAddress
        ) {}

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
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
    }

    #[derive(Drop, starknet::Event)]
    pub struct IPIDRegistered {
        pub ip_id: felt252,
        pub owner: ContractAddress,
        pub token_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct IPIDUpdated {
        ip_id: felt252,
        owner: ContractAddress,
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

            self.emit(IPIDRegistered { ip_id, owner: caller, token_id });

            token_id
        }

        fn update_ip_id_metadata(
            ref self: ContractState, ip_id: felt252, new_metadata_uri: ByteArray,
        ) {
            let token_id = self.ip_id_to_token_id.read(ip_id);
            assert(token_id.is_non_zero(), ERROR_INVALID_IP_ID);

            let caller = get_caller_address();
            let owner = self.erc721.owner_of(token_id);
            assert(caller == owner, ERROR_NOT_OWNER);

            // Update data
            let mut ip_data = self.ip_id_data.read(ip_id);
            ip_data.metadata_uri = new_metadata_uri;
            ip_data.updated_at = get_block_timestamp();
            self.ip_id_data.write(ip_id, ip_data);

            self.emit(IPIDUpdated { ip_id, owner: caller });
        }

        fn get_ip_id_data(self: @ContractState, ip_id: felt252) -> IPIDData {
            assert(self.ip_id_to_token_id.read(ip_id).is_non_zero(), ERROR_INVALID_IP_ID);
            self.ip_id_data.read(ip_id)
        }

        fn verify_ip_id(ref self: ContractState, ip_id: felt252) {
            self.ownable.assert_only_owner();

            let token_id = self.ip_id_to_token_id.read(ip_id);
            assert(token_id.is_non_zero(), ERROR_INVALID_IP_ID);

            let owner = self.erc721.owner_of(token_id);
            let mut ip_data = self.ip_id_data.read(ip_id);
            ip_data.is_verified = true;
            ip_data.updated_at = get_block_timestamp();
            self.ip_id_data.write(ip_id, ip_data);

            self.emit(IPIDUpdated { ip_id, owner });
        }
    }
}
