#[starknet::interface]
pub trait IIPIdentity<TContractState> {
    // Core registration and management functions
    fn register_ip_id(
        ref self: TContractState,
        ip_id: felt252,
        metadata_uri: ByteArray,
        ip_type: ByteArray,
        license_terms: ByteArray,
        collection_id: u256,
        royalty_rate: u256,
        licensing_fee: u256,
        commercial_use: bool,
        derivative_works: bool,
        attribution_required: bool,
        metadata_standard: ByteArray,
        external_url: ByteArray,
        tags: ByteArray,
        jurisdiction: ByteArray,
    ) -> u256;

    fn update_ip_id_metadata(
        ref self: TContractState, ip_id: felt252, new_metadata_uri: ByteArray,
    );

    fn update_ip_id_licensing(
        ref self: TContractState,
        ip_id: felt252,
        license_terms: ByteArray,
        royalty_rate: u256,
        licensing_fee: u256,
        commercial_use: bool,
        derivative_works: bool,
        attribution_required: bool,
    );

    fn transfer_ip_ownership(
        ref self: TContractState, ip_id: felt252, new_owner: ContractAddress,
    );

    fn verify_ip_id(ref self: TContractState, ip_id: felt252);

    // Enhanced public getters for cross-contract queries
    fn get_ip_id_data(self: @TContractState, ip_id: felt252) -> IPIDData;

    fn get_ip_owner(self: @TContractState, ip_id: felt252) -> ContractAddress;

    fn get_ip_token_id(self: @TContractState, ip_id: felt252) -> u256;

    fn is_ip_verified(self: @TContractState, ip_id: felt252) -> bool;

    fn get_ip_licensing_terms(self: @TContractState, ip_id: felt252) -> (ByteArray, u256, u256, bool, bool, bool);

    fn get_ip_metadata_info(self: @TContractState, ip_id: felt252) -> (ByteArray, ByteArray, ByteArray, ByteArray);

    // Batch query functions for efficiency
    fn get_multiple_ip_data(self: @TContractState, ip_ids: Array<felt252>) -> Array<IPIDData>;

    fn get_owner_ip_ids(self: @TContractState, owner: ContractAddress) -> Array<felt252>;

    fn get_verified_ip_ids(self: @TContractState, limit: u256, offset: u256) -> Array<felt252>;

    fn get_ip_ids_by_collection(self: @TContractState, collection_id: u256) -> Array<felt252>;

    fn get_ip_ids_by_type(self: @TContractState, ip_type: ByteArray) -> Array<felt252>;

    // Utility functions for ecosystem integration
    fn is_ip_id_registered(self: @TContractState, ip_id: felt252) -> bool;

    fn get_total_registered_ips(self: @TContractState) -> u256;

    fn can_use_commercially(self: @TContractState, ip_id: felt252) -> bool;

    fn can_create_derivatives(self: @TContractState, ip_id: felt252) -> bool;

    fn requires_attribution(self: @TContractState, ip_id: felt252) -> bool;
}

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct IPIDData {
    pub metadata_uri: ByteArray,
    pub ip_type: ByteArray,
    pub license_terms: ByteArray,
    pub is_verified: bool,
    pub created_at: u64,
    pub updated_at: u64,
    // MIP-compatible fields for enhanced interoperability
    pub collection_id: u256,
    pub royalty_rate: u256, // Basis points (e.g., 250 = 2.5%)
    pub licensing_fee: u256,
    pub commercial_use: bool,
    pub derivative_works: bool,
    pub attribution_required: bool,
    pub metadata_standard: ByteArray, // e.g., "ERC721", "ERC1155", "IPFS", etc.
    pub external_url: ByteArray,
    pub tags: ByteArray, // Comma-separated tags for categorization
    pub jurisdiction: ByteArray, // Legal jurisdiction
}

#[starknet::contract]
pub mod IPIdentity {
    use core::{
        array::ArrayTrait, traits::{Into,}, num::traits::Zero,
        starknet::{
            ContractAddress,
            storage::{
                StoragePointerWriteAccess, StoragePointerReadAccess, StorageMapReadAccess,
                StorageMapWriteAccess, StoragePathEntry, Map, Vec, VecTrait, MutableVecTrait
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
        // Enhanced mappings for efficient cross-contract queries
        owner_to_ip_ids: Map<(ContractAddress, u256), felt252>,
        owner_ip_count: Map<ContractAddress, u256>,
        collection_to_ip_ids: Map<(u256, u256), felt252>,
        collection_ip_count: Map<u256, u256>,
        type_to_ip_ids: Map<(ByteArray, u256), felt252>,
        type_ip_count: Map<ByteArray, u256>,
        verified_ip_ids: Map<u256, felt252>,
        verified_count: u256,
        total_registered: u256,
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
        IPIDMetadataUpdated: IPIDMetadataUpdated,
        IPIDLicensingUpdated: IPIDLicensingUpdated,
        IPIDOwnershipTransferred: IPIDOwnershipTransferred,
        IPIDVerified: IPIDVerified,
        IPIDCollectionLinked: IPIDCollectionLinked,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IPIDRegistered {
        pub ip_id: felt252,
        pub owner: ContractAddress,
        pub token_id: u256,
        pub ip_type: ByteArray,
        pub collection_id: u256,
        pub metadata_uri: ByteArray,
        pub metadata_standard: ByteArray,
        pub commercial_use: bool,
        pub derivative_works: bool,
        pub attribution_required: bool,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IPIDMetadataUpdated {
        pub ip_id: felt252,
        pub owner: ContractAddress,
        pub old_metadata_uri: ByteArray,
        pub new_metadata_uri: ByteArray,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IPIDLicensingUpdated {
        pub ip_id: felt252,
        pub owner: ContractAddress,
        pub license_terms: ByteArray,
        pub royalty_rate: u256,
        pub licensing_fee: u256,
        pub commercial_use: bool,
        pub derivative_works: bool,
        pub attribution_required: bool,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IPIDOwnershipTransferred {
        pub ip_id: felt252,
        pub previous_owner: ContractAddress,
        pub new_owner: ContractAddress,
        pub token_id: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IPIDVerified {
        pub ip_id: felt252,
        pub owner: ContractAddress,
        pub verifier: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IPIDCollectionLinked {
        pub ip_id: felt252,
        pub collection_id: u256,
        pub owner: ContractAddress,
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
            collection_id: u256,
            royalty_rate: u256,
            licensing_fee: u256,
            commercial_use: bool,
            derivative_works: bool,
            attribution_required: bool,
            metadata_standard: ByteArray,
            external_url: ByteArray,
            tags: ByteArray,
            jurisdiction: ByteArray,
        ) -> u256 {
            // Check if IP ID is already registered
            assert(self.ip_id_to_token_id.read(ip_id).is_zero(), ERROR_ALREADY_REGISTERED);

            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            // Mint NFT
            let token_id = self.token_counter.read() + 1;
            self.token_counter.write(token_id);
            self.erc721.mint(caller, token_id);

            // Store enhanced IP ID data
            let ip_data = IPIDData {
                metadata_uri: metadata_uri.clone(),
                ip_type: ip_type.clone(),
                license_terms: license_terms.clone(),
                is_verified: false,
                created_at: timestamp,
                updated_at: timestamp,
                collection_id,
                royalty_rate,
                licensing_fee,
                commercial_use,
                derivative_works,
                attribution_required,
                metadata_standard: metadata_standard.clone(),
                external_url,
                tags,
                jurisdiction,
            };

            self.ip_id_data.write(ip_id, ip_data);
            self.ip_id_to_token_id.write(ip_id, token_id);

            // Update indexing structures
            self.owner_to_ip_ids.entry(caller).append().write(ip_id);

            let owner_count = self.owner_ip_count.read(caller);
            self.owner_ip_count.write(caller, owner_count + 1);

            if collection_id != 0 {
                self.collection_to_ip_ids.entry(collection_id).append().write(ip_id);
            }

            self.type_to_ip_ids.entry(ip_type.clone()).append().write(ip_id);
            self.all_ip_ids.append().write(ip_id);

            let total = self.total_registered.read();
            self.total_registered.write(total + 1);

            // Emit enhanced registration event
            self.emit(IPIDRegistered {
                ip_id,
                owner: caller,
                token_id,
                ip_type,
                collection_id,
                metadata_uri,
                metadata_standard,
                commercial_use,
                derivative_works,
                attribution_required,
                timestamp,
            });

            // Emit collection linking event if applicable
            if collection_id != 0 {
                self.emit(IPIDCollectionLinked {
                    ip_id,
                    collection_id,
                    owner: caller,
                    timestamp,
                });
            }

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
            let old_metadata_uri = ip_data.metadata_uri.clone();
            ip_data.metadata_uri = new_metadata_uri.clone();
            ip_data.updated_at = get_block_timestamp();
            self.ip_id_data.write(ip_id, ip_data);

            self.emit(IPIDMetadataUpdated {
                ip_id,
                owner: caller,
                old_metadata_uri,
                new_metadata_uri,
                timestamp: get_block_timestamp(),
            });
        }

        fn update_ip_id_licensing(
            ref self: ContractState,
            ip_id: felt252,
            license_terms: ByteArray,
            royalty_rate: u256,
            licensing_fee: u256,
            commercial_use: bool,
            derivative_works: bool,
            attribution_required: bool,
        ) {
            let token_id = self.ip_id_to_token_id.read(ip_id);
            assert(token_id.is_non_zero(), ERROR_INVALID_IP_ID);

            let caller = get_caller_address();
            let owner = self.erc721.owner_of(token_id);
            assert(caller == owner, ERROR_NOT_OWNER);

            // Update licensing data
            let mut ip_data = self.ip_id_data.read(ip_id);
            ip_data.license_terms = license_terms.clone();
            ip_data.royalty_rate = royalty_rate;
            ip_data.licensing_fee = licensing_fee;
            ip_data.commercial_use = commercial_use;
            ip_data.derivative_works = derivative_works;
            ip_data.attribution_required = attribution_required;
            ip_data.updated_at = get_block_timestamp();
            self.ip_id_data.write(ip_id, ip_data);

            self.emit(IPIDLicensingUpdated {
                ip_id,
                owner: caller,
                license_terms,
                royalty_rate,
                licensing_fee,
                commercial_use,
                derivative_works,
                attribution_required,
                timestamp: get_block_timestamp(),
            });
        }

        fn transfer_ip_ownership(
            ref self: ContractState, ip_id: felt252, new_owner: ContractAddress,
        ) {
            let token_id = self.ip_id_to_token_id.read(ip_id);
            assert(token_id.is_non_zero(), ERROR_INVALID_IP_ID);

            let caller = get_caller_address();
            let current_owner = self.erc721.owner_of(token_id);
            assert(caller == current_owner, ERROR_NOT_OWNER);

            // Transfer the NFT
            self.erc721.transfer_from(current_owner, new_owner, token_id);

            // Update indexing structures
            // Note: For simplicity, we'll rebuild the old owner's list
            // In a production system, you might want a more efficient removal method
            let old_owner_vec = self.owner_to_ip_ids.entry(current_owner);
            let old_owner_len = old_owner_vec.len();
            let mut found_index = old_owner_len; // Initialize to invalid index

            // Find the index of the IP ID to remove
            let mut i = 0;
            while i < old_owner_len {
                if old_owner_vec.at(i).read() == ip_id {
                    found_index = i;
                    break;
                }
                i += 1;
            };

            // Remove the IP ID if found (swap with last and pop)
            if found_index < old_owner_len {
                let last_index = old_owner_len - 1;
                if found_index != last_index {
                    let last_ip = old_owner_vec.at(last_index).read();
                    old_owner_vec.at(found_index).write(last_ip);
                }
                // Note: Vec doesn't have pop in current Cairo, so we'll leave it for now
            }

            let old_owner_count = self.owner_ip_count.read(current_owner);
            self.owner_ip_count.write(current_owner, old_owner_count - 1);

            // Add to new owner's list
            self.owner_to_ip_ids.entry(new_owner).append().write(ip_id);

            let new_owner_count = self.owner_ip_count.read(new_owner);
            self.owner_ip_count.write(new_owner, new_owner_count + 1);

            self.emit(IPIDOwnershipTransferred {
                ip_id,
                previous_owner: current_owner,
                new_owner,
                token_id,
                timestamp: get_block_timestamp(),
            });
        }

        fn verify_ip_id(ref self: ContractState, ip_id: felt252) {
            self.ownable.assert_only_owner();

            let token_id = self.ip_id_to_token_id.read(ip_id);
            assert(token_id.is_non_zero(), ERROR_INVALID_IP_ID);

            let owner = self.erc721.owner_of(token_id);
            let mut ip_data = self.ip_id_data.read(ip_id);

            if !ip_data.is_verified {
                ip_data.is_verified = true;
                ip_data.updated_at = get_block_timestamp();
                self.ip_id_data.write(ip_id, ip_data);

                // Add to verified list
                self.verified_ip_ids.append().write(ip_id);

                self.emit(IPIDVerified {
                    ip_id,
                    owner,
                    verifier: get_caller_address(),
                    timestamp: get_block_timestamp(),
                });
            }
        }

        // Enhanced public getters for cross-contract queries
        fn get_ip_id_data(self: @ContractState, ip_id: felt252) -> IPIDData {
            assert(self.ip_id_to_token_id.read(ip_id).is_non_zero(), ERROR_INVALID_IP_ID);
            self.ip_id_data.read(ip_id)
        }

        fn get_ip_owner(self: @ContractState, ip_id: felt252) -> ContractAddress {
            let token_id = self.ip_id_to_token_id.read(ip_id);
            assert(token_id.is_non_zero(), ERROR_INVALID_IP_ID);
            self.erc721.owner_of(token_id)
        }

        fn get_ip_token_id(self: @ContractState, ip_id: felt252) -> u256 {
            let token_id = self.ip_id_to_token_id.read(ip_id);
            assert(token_id.is_non_zero(), ERROR_INVALID_IP_ID);
            token_id
        }

        fn is_ip_verified(self: @ContractState, ip_id: felt252) -> bool {
            let token_id = self.ip_id_to_token_id.read(ip_id);
            if token_id.is_zero() {
                return false;
            }
            let ip_data = self.ip_id_data.read(ip_id);
            ip_data.is_verified
        }

        fn get_ip_licensing_terms(self: @ContractState, ip_id: felt252) -> (ByteArray, u256, u256, bool, bool, bool) {
            assert(self.ip_id_to_token_id.read(ip_id).is_non_zero(), ERROR_INVALID_IP_ID);
            let ip_data = self.ip_id_data.read(ip_id);
            (
                ip_data.license_terms,
                ip_data.royalty_rate,
                ip_data.licensing_fee,
                ip_data.commercial_use,
                ip_data.derivative_works,
                ip_data.attribution_required
            )
        }

        fn get_ip_metadata_info(self: @ContractState, ip_id: felt252) -> (ByteArray, ByteArray, ByteArray, ByteArray) {
            assert(self.ip_id_to_token_id.read(ip_id).is_non_zero(), ERROR_INVALID_IP_ID);
            let ip_data = self.ip_id_data.read(ip_id);
            (
                ip_data.metadata_uri,
                ip_data.ip_type,
                ip_data.metadata_standard,
                ip_data.external_url
            )
        }

        // Batch query functions for efficiency
        fn get_multiple_ip_data(self: @ContractState, ip_ids: Array<felt252>) -> Array<IPIDData> {
            let mut result = ArrayTrait::new();
            let mut i = 0;
            while i < ip_ids.len() {
                let ip_id = *ip_ids.at(i);
                if self.ip_id_to_token_id.read(ip_id).is_non_zero() {
                    result.append(self.ip_id_data.read(ip_id));
                }
                i += 1;
            };
            result
        }

        fn get_owner_ip_ids(self: @ContractState, owner: ContractAddress) -> Array<felt252> {
            let owner_vec = self.owner_to_ip_ids.entry(owner);
            let mut result = ArrayTrait::new();
            let mut i = 0;
            while i < owner_vec.len() {
                result.append(owner_vec.at(i).read());
                i += 1;
            };
            result
        }

        fn get_verified_ip_ids(self: @ContractState, limit: u256, offset: u256) -> Array<felt252> {
            let verified_vec = self.verified_ip_ids;
            let mut result = ArrayTrait::new();
            let mut i = offset;
            let mut count = 0;

            while i < verified_vec.len() && count < limit {
                result.append(verified_vec.at(i).read());
                i += 1;
                count += 1;
            };
            result
        }

        fn get_ip_ids_by_collection(self: @ContractState, collection_id: u256) -> Array<felt252> {
            let collection_vec = self.collection_to_ip_ids.entry(collection_id);
            let mut result = ArrayTrait::new();
            let mut i = 0;
            while i < collection_vec.len() {
                result.append(collection_vec.at(i).read());
                i += 1;
            };
            result
        }

        fn get_ip_ids_by_type(self: @ContractState, ip_type: ByteArray) -> Array<felt252> {
            let type_vec = self.type_to_ip_ids.entry(ip_type);
            let mut result = ArrayTrait::new();
            let mut i = 0;
            while i < type_vec.len() {
                result.append(type_vec.at(i).read());
                i += 1;
            };
            result
        }

        // Utility functions for ecosystem integration
        fn is_ip_id_registered(self: @ContractState, ip_id: felt252) -> bool {
            self.ip_id_to_token_id.read(ip_id).is_non_zero()
        }

        fn get_total_registered_ips(self: @ContractState) -> u256 {
            self.total_registered.read()
        }

        fn can_use_commercially(self: @ContractState, ip_id: felt252) -> bool {
            if !self.ip_id_to_token_id.read(ip_id).is_non_zero() {
                return false;
            }
            let ip_data = self.ip_id_data.read(ip_id);
            ip_data.commercial_use
        }

        fn can_create_derivatives(self: @ContractState, ip_id: felt252) -> bool {
            if !self.ip_id_to_token_id.read(ip_id).is_non_zero() {
                return false;
            }
            let ip_data = self.ip_id_data.read(ip_id);
            ip_data.derivative_works
        }

        fn requires_attribution(self: @ContractState, ip_id: felt252) -> bool {
            if !self.ip_id_to_token_id.read(ip_id).is_non_zero() {
                return false;
            }
            let ip_data = self.ip_id_data.read(ip_id);
            ip_data.attribution_required
        }
    }
}
