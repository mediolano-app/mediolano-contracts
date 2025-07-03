use starknet::ContractAddress;

#[starknet::interface]
pub trait IIPCollection<ContractState> {
    fn create_collection(
        ref self: ContractState, name: ByteArray, symbol: ByteArray, base_uri: ByteArray,
    ) -> u256;
    fn mint(ref self: ContractState, collection_id: u256, recipient: ContractAddress) -> u256;
    fn burn(ref self: ContractState, token_id: u256);
    fn list_user_tokens(self: @ContractState, owner: ContractAddress) -> Array<u256>;
    fn transfer_token(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
    );
    fn list_user_collections(self: @ContractState, owner: ContractAddress) -> Array<u256>;
    fn get_collection(self: @ContractState, collection_id: u256) -> Collection;
    fn get_token(self: @ContractState, token_id: u256) -> Token;
    fn list_all_tokens(self: @ContractState) -> Array<u256>;
    fn list_collection_tokens(self: @ContractState, collection_id: u256) -> Array<u256>;
    fn mint_batch(ref self: ContractState, collection_id: u256, recipients: Array<ContractAddress>) -> Array<u256>;
    fn burn_batch(ref self: ContractState, token_ids: Array<u256>);
    fn transfer_batch(ref self: ContractState, from: ContractAddress, to: ContractAddress, token_ids: Array<u256>);
    fn update_collection_metadata(ref self: ContractState, collection_id: u256, name: ByteArray, symbol: ByteArray, base_uri: ByteArray);
    fn get_collection_stats(self: @ContractState, collection_id: u256) -> CollectionStats;
    fn is_valid_collection(self: @ContractState, collection_id: u256) -> bool;
    fn is_valid_token(self: @ContractState, token_id: u256) -> bool;
    fn is_collection_owner(self: @ContractState, collection_id: u256, owner: ContractAddress) -> bool;
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Collection {
    pub name: ByteArray,
    pub symbol: ByteArray,
    pub base_uri: ByteArray,
    pub owner: ContractAddress,
    pub is_active: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Token {
    pub collection_id: u256,
    pub token_id: u256,
    pub owner: ContractAddress,
    pub metadata_uri: ByteArray,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct CollectionStats {
    pub total_supply: u256,
    pub minted: u256,
    pub burned: u256,
    pub last_mint_batch_id: u256,
    pub last_mint_time: u64,
}

#[starknet::contract]
pub mod IPCollection {
    // use alexandria_storage::List;
    // use alexandria_storage::ListTrait;
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::ERC721Component::InternalTrait;
    use openzeppelin::token::erc721::extensions::ERC721EnumerableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::{
        ClassHash, ContractAddress, get_caller_address, get_contract_address,
        storage::{
            Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
            StoragePointerReadAccess, StoragePointerWriteAccess,
        },
    };

    use super::{Collection, IIPCollection, Token, CollectionStats};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(
        path: ERC721EnumerableComponent, storage: erc721_enumerable, event: ERC721EnumerableEvent,
    );
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721EnumerableImpl =
        ERC721EnumerableComponent::ERC721EnumerableImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl ERC721EnumerableInternalImpl = ERC721EnumerableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        collections: Map<u256, Collection>,
        collection_count: u256,
        tokens: Map<u256, Token>,
        // Removed: owned_collections, owned_collection_count, owned_tokens, owned_token_count, user_tokens, user_token_count
        // Operator approvals: (owner, operator) -> bool
        operator_approvals: Map<(ContractAddress, ContractAddress), bool>,
        // Token approvals: token_id -> approved address
        token_approvals: Map<u256, ContractAddress>,
        // Batch operation tracking: batch_id -> timestamp
        mint_batch_timestamps: Map<u256, u64>,
        burn_batch_timestamps: Map<u256, u64>,
        transfer_batch_timestamps: Map<u256, u64>,
        // Collection stats: collection_id -> CollectionStats
        collection_stats: Map<u256, CollectionStats>,
        // Global token tracking
        all_tokens: Map<u256, u256>, // index -> token_id
        all_token_count: u256, // total number of tokens
        collection_tokens: Map<(u256, u256), u256>, // (collection_id, index) -> token_id
        collection_token_count: Map<u256, u256>, // collection_id -> number of tokens
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc721_enumerable: ERC721EnumerableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC721EnumerableEvent: ERC721EnumerableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        CollectionCreated: CollectionCreated,
        CollectionUpdated: CollectionUpdated,
        TokenMinted: TokenMinted,
        TokenMintedBatch: TokenMintedBatch,
        TokenBurnedBatch: TokenBurnedBatch,
        TokenTransferredBatch: TokenTransferredBatch,
    }


    #[derive(Drop, starknet::Event)]
    pub struct CollectionCreated {
        pub collection_id: u256,
        pub owner: ContractAddress,
        pub name: ByteArray,
        pub symbol: ByteArray,
        pub base_uri: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenMinted {
        pub collection_id: u256,
        pub token_id: u256,
        pub owner: ContractAddress,
        pub metadata_uri: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CollectionUpdated {
        pub collection_id: u256,
        pub owner: ContractAddress,
        pub name: ByteArray,
        pub symbol: ByteArray,
        pub base_uri: ByteArray,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenMintedBatch {
        pub collection_id: u256,
        pub token_ids: Array<u256>,
        pub owners: Array<ContractAddress>,
        pub operator: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenBurnedBatch {
        pub token_ids: Array<u256>,
        pub operator: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenTransferredBatch {
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub token_ids: Array<u256>,
        pub operator: ContractAddress,
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        owner: ContractAddress,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.ownable.initializer(owner);
        self.erc721_enumerable.initializer();
        self.collection_count.write(0);
    }

    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.erc721_enumerable.before_update(to, token_id);
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    // This avoids using string operations and just returns the base URI as-is
    fn get_token_uri(base_uri: ByteArray, _token_id: u256) -> ByteArray {
        // You would need to implement proper string conversion in a production contract
        base_uri.clone()
    }

    #[abi(embed_v0)]
    impl IPCollection of IIPCollection<ContractState> {
        fn create_collection(
            ref self: ContractState, name: ByteArray, symbol: ByteArray, base_uri: ByteArray,
        ) -> u256 {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Caller is zero address');

            let collection_id = self.collection_count.read() + 1;
            let collection = Collection {
                name: name.clone(),
                symbol: symbol.clone(),
                base_uri: base_uri.clone(),
                owner: caller,
                is_active: true,
            };

            self.collections.entry(collection_id).write(collection);
            self.collection_count.write(collection_id);

            self.emit(CollectionCreated { collection_id, owner: caller, name, symbol, base_uri });

            collection_id
        }

        fn mint(ref self: ContractState, collection_id: u256, recipient: ContractAddress) -> u256 {
            self.ownable.assert_only_owner();
            assert(!recipient.is_zero(), 'Recipient is zero address');

            let collection = self.collections.read(collection_id);

            let caller = get_caller_address();
            assert(caller != Zero::zero(), 'Caller is zero address');

            let token_id = self.all_token_count.read() + 1;
            let metadata_uri = get_token_uri(collection.base_uri, token_id);

            self.erc721.mint(recipient, token_id);

            let token = Token {
                collection_id, token_id, owner: recipient, metadata_uri: metadata_uri.clone(),
            };

            self.tokens.write(token_id, token);

            let all_token_count = self.all_token_count.read();
            self.all_tokens.entry(all_token_count).write(token_id);
            self.all_token_count.write(all_token_count + 1);

            let collection_token_count = self.collection_token_count.read(collection_id);
            self.collection_tokens.entry((collection_id, collection_token_count)).write(token_id);
            self.collection_token_count.entry(collection_id).write(collection_token_count + 1);

            self
                .emit(
                    TokenMinted {
                        collection_id, token_id, owner: recipient, metadata_uri: metadata_uri,
                    },
                );

            token_id
        }

        fn burn(ref self: ContractState, token_id: u256) {
            self.erc721.update(Zero::zero(), token_id, get_caller_address());
        }

        fn list_user_tokens(self: @ContractState, owner: ContractAddress) -> Array<u256> {
            return array![];
        }

        fn transfer_token(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
        ) {
            let caller = get_caller_address();
            assert(caller != Zero::zero(), 'Caller is zero address');

            let approved = self.erc721.get_approved(token_id);

            assert(approved == get_contract_address(), 'Contract not approved');

            self.erc721.transfer(from, to, token_id);
        }

        fn list_user_collections(self: @ContractState, owner: ContractAddress) -> Array<u256> {
            return array![];
        }

        fn get_collection(self: @ContractState, collection_id: u256) -> Collection {
            return self.collections.read(collection_id);
        }

        fn get_token(self: @ContractState, token_id: u256) -> Token {
            return self.tokens.read(token_id);
        }

        // NEW: Function to list all tokens in the contract
        fn list_all_tokens(self: @ContractState) -> Array<u256> {
            let mut token_ids: Array<u256> = array![];
            let count = self.all_token_count.read();
            let mut i: u256 = 0;
            while i < count {
                let token_id = self.all_tokens.read(i);
                token_ids.append(token_id);
                i += 1;
            };
            token_ids
        }

        // NEW: Function to list all tokens in a specific collection
        fn list_collection_tokens(self: @ContractState, collection_id: u256) -> Array<u256> {
            let mut token_ids: Array<u256> = array![];
            let count = self.collection_token_count.read(collection_id);
            let mut i: u256 = 0;
            while i < count {
                let token_id = self.collection_tokens.read((collection_id, i));
                token_ids.append(token_id);
                i += 1;
            };
            token_ids
        }

        fn mint_batch(ref self: ContractState, collection_id: u256, recipients: Array<ContractAddress>) -> Array<u256> {
            self.ownable.assert_only_owner();
            let n = recipients.len();
            assert(n > 0, 'Recipients array is empty');

            let collection = self.collections.read(collection_id);
            assert(collection.is_active, 'Collection is not active');

            let mut token_ids: Array<u256> = array![];
            let mut i: u32 = 0;
            let mut all_token_count = self.all_token_count.read();
            let mut collection_token_count = self.collection_token_count.read(collection_id);
            let operator = get_caller_address();
            let timestamp = 0; // TODO: Replace with block timestamp if available

            while i < n {
                let recipient: ContractAddress = *recipients.at(i);
                assert(!recipient.is_zero(), 'Recipient is zero address');

                let token_id = all_token_count + 1;
                let metadata_uri = get_token_uri(collection.base_uri.clone(), token_id);

                self.erc721.mint(recipient, token_id);

                let token = Token {
                    collection_id, token_id, owner: recipient, metadata_uri: metadata_uri.clone(),
                };
                self.tokens.write(token_id, token);

                self.all_tokens.entry(all_token_count).write(token_id);
                all_token_count += 1;

                self.collection_tokens.entry((collection_id, collection_token_count)).write(token_id);
                collection_token_count += 1;

                token_ids.append(token_id);
                i += 1;
            };
            self.all_token_count.write(all_token_count);
            self.collection_token_count.entry(collection_id).write(collection_token_count);

            // Emit batch event
            self.emit(TokenMintedBatch {
                collection_id,
                token_ids: token_ids.clone(),
                owners: recipients.clone(),
                operator,
                timestamp,
            });

            return token_ids;
        }

        fn burn_batch(ref self: ContractState, token_ids: Array<u256>) {
            // Implementation needed
            return ();
        }

        fn transfer_batch(ref self: ContractState, from: ContractAddress, to: ContractAddress, token_ids: Array<u256>) {
            // Implementation needed
            return ();
        }

        fn update_collection_metadata(ref self: ContractState, collection_id: u256, name: ByteArray, symbol: ByteArray, base_uri: ByteArray) {
            // Implementation needed
            return ();
        }

        fn get_collection_stats(self: @ContractState, collection_id: u256) -> CollectionStats {
            // Implementation needed
            return CollectionStats {
                total_supply: 0,
                minted: 0,
                burned: 0,
                last_mint_batch_id: 0,
                last_mint_time: 0,
            };
        }

        fn is_valid_collection(self: @ContractState, collection_id: u256) -> bool {
            // Implementation needed
            return false;
        }

        fn is_valid_token(self: @ContractState, token_id: u256) -> bool {
            // Implementation needed
            return false;
        }

        fn is_collection_owner(self: @ContractState, collection_id: u256, owner: ContractAddress) -> bool {
            // Implementation needed
            return false;
        }
    }
}

