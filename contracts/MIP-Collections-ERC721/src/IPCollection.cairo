#[starknet::contract]
pub mod IPCollection {
    use core::dict::Felt252Dict;
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::extensions::erc721_enumerable::interface::{
        ERC721EnumerableABIDispatcher as IERC721EnumerableDispatcher,
        ERC721EnumerableABIDispatcherTrait,
    };
    use openzeppelin::token::erc721::{
        ERC721ABIDispatcher as IERC721Dispatcher, ERC721ABIDispatcherTrait,
    };
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StoragePathEntry, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::syscalls::deploy_syscall;
    use starknet::{
        ClassHash, ContractAddress, get_block_timestamp, get_caller_address, get_contract_address,
    };
    use crate::interfaces::IIPCollection::IIPCollection;
    use crate::interfaces::IIPNFT::{IIPNftDispatcher, IIPNftDispatcherTrait};
    use crate::types::{Collection, CollectionStats, TokenData, TokenTrait};

    // IPCollection (the factory/registry) remains upgradeable because it holds
    // only collection metadata and indexes — not the legal IP records themselves.
    // The legal records live in the individual IPNft contracts, which are immutable.
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        collections: Map<u256, Collection>,
        collection_count: u256,
        collection_stats: Map<u256, CollectionStats>,
        ip_nft_class_hash: ClassHash,
        user_collections: Map<(ContractAddress, u256), u256>,
        user_collection_index: Map<ContractAddress, u256>,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        CollectionCreated: CollectionCreated,
        CollectionUpdated: CollectionUpdated,
        TokenMinted: TokenMinted,
        TokenMintedBatch: TokenMintedBatch,
        TokenArchived: TokenArchived,
        TokenArchivedBatch: TokenArchivedBatch,
        TokenTransferred: TokenTransferred,
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
    pub struct CollectionUpdated {
        pub collection_id: u256,
        pub owner: ContractAddress,
        pub name: ByteArray,
        pub symbol: ByteArray,
        pub base_uri: ByteArray,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenMinted {
        pub collection_id: u256,
        pub token_id: u256,
        pub owner: ContractAddress,
        pub metadata_uri: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenMintedBatch {
        pub collection_id: u256,
        pub token_ids: Span<u256>,
        pub owners: Array<ContractAddress>,
        pub operator: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenArchived {
        pub collection_id: u256,
        pub token_id: u256,
        pub operator: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenArchivedBatch {
        pub tokens: Array<ByteArray>,
        pub operator: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenTransferred {
        pub collection_id: u256,
        pub token_id: u256,
        pub operator: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenTransferredBatch {
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub tokens: Array<ByteArray>,
        pub operator: ContractAddress,
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, ip_nft_class_hash: ClassHash) {
        self.ownable.initializer(owner);
        self.ip_nft_class_hash.write(ip_nft_class_hash);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl IPCollectionImpl of IIPCollection<ContractState> {
        /// Creates a new NFT collection and deploys a dedicated IPNft contract for it.
        /// The caller becomes the collection owner.
        fn create_collection(
            ref self: ContractState, name: ByteArray, symbol: ByteArray, base_uri: ByteArray,
        ) -> u256 {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Caller is zero address');

            // L-02: validate non-empty name and symbol
            assert(name.len() > 0, 'Name cannot be empty');
            assert(symbol.len() > 0, 'Symbol cannot be empty');

            let collection_id = self.collection_count.read() + 1;
            let collection_manager = get_contract_address();

            // 4-M CRITICAL: calldata must match IPNft constructor exactly.
            // IPNft constructor: (name, symbol, base_uri, collection_id, collection_manager)
            // OwnableComponent was removed from IPNft — `owner` arg is gone.
            let mut constructor_calldata: Array<felt252> = array![];
            (name.clone(), symbol.clone(), base_uri.clone(), collection_id, collection_manager)
                .serialize(ref constructor_calldata);

            let (ip_nft_address, _) = deploy_syscall(
                self.ip_nft_class_hash.read(), 0, constructor_calldata.span(), false,
            )
                .unwrap();

            let collection = Collection {
                name: name.clone(),
                symbol: symbol.clone(),
                base_uri: base_uri.clone(),
                owner: caller,
                ip_nft: ip_nft_address,
                is_active: true,
            };

            self.collections.entry(collection_id).write(collection);
            self.collection_count.write(collection_id);

            let user_collection_index = self.user_collection_index.read(caller);
            self.user_collections.entry((caller, user_collection_index)).write(collection_id);
            self.user_collection_index.entry(caller).write(user_collection_index + 1);

            self.emit(CollectionCreated { collection_id, owner: caller, name, symbol, base_uri });

            collection_id
        }

        /// Mints a new token in the specified collection to the recipient address.
        /// Only the collection owner can mint.
        /// Token IDs start at 1 (R-05).
        fn mint(
            ref self: ContractState,
            collection_id: u256,
            recipient: ContractAddress,
            token_uri: ByteArray,
        ) -> u256 {
            assert(!recipient.is_zero(), 'Recipient is zero address');

            let collection = self.collections.read(collection_id);
            assert(get_caller_address() == collection.owner, 'Only collection owner can mint');
            assert(collection.is_active, 'Collection is not active');

            let mut collection_stats = self.collection_stats.read(collection_id);

            // R-05: token IDs start at 1 — total_minted + 1 gives the next ID
            let next_token_id = collection_stats.total_minted + 1;

            let ip_nft = IIPNftDispatcher { contract_address: collection.ip_nft };
            ip_nft.mint(recipient, next_token_id, token_uri.clone());

            collection_stats.total_minted = next_token_id;
            collection_stats.last_mint_time = get_block_timestamp();
            self.collection_stats.entry(collection_id).write(collection_stats);

            // R-01: use local token_uri directly — no extra cross-contract call needed
            self
                .emit(
                    TokenMinted {
                        collection_id,
                        token_id: next_token_id,
                        owner: recipient,
                        metadata_uri: token_uri,
                    },
                );

            next_token_id
        }

        /// Batch mints tokens in the specified collection to multiple recipients.
        /// Only the collection owner can batch mint.
        fn batch_mint(
            ref self: ContractState,
            collection_id: u256,
            recipients: Array<ContractAddress>,
            token_uris: Array<ByteArray>,
        ) -> Span<u256> {
            let n = recipients.len();
            assert(n > 0, 'Recipients array is empty');

            // M-01: arrays must be the same length
            assert(token_uris.len() == n, 'Array lengths mismatch');

            let collection = self.collections.read(collection_id);
            assert(collection.is_active, 'Collection is not active');

            let operator = get_caller_address();
            assert(operator == collection.owner, 'Only collection owner can mint');

            let mut collection_stats = self.collection_stats.read(collection_id);
            let ip_nft = IIPNftDispatcher { contract_address: collection.ip_nft };

            let mut i: u32 = 0;
            let mut token_ids: Array<u256> = array![];

            while i < n {
                let recipient: ContractAddress = *recipients.at(i);
                let token_uri: ByteArray = token_uris.at(i).clone();
                assert(!recipient.is_zero(), 'Recipient is zero address');

                // R-05: token IDs start at 1
                let next_token_id = collection_stats.total_minted + i.into() + 1;
                ip_nft.mint(recipient, next_token_id, token_uri);
                token_ids.append(next_token_id);
                i += 1;
            };

            let timestamp = get_block_timestamp();
            collection_stats.total_minted += n.into();
            collection_stats.last_mint_time = timestamp;
            self.collection_stats.entry(collection_id).write(collection_stats);

            self
                .emit(
                    TokenMintedBatch {
                        collection_id,
                        token_ids: token_ids.span(),
                        owners: recipients.clone(),
                        operator,
                        timestamp,
                    },
                );

            token_ids.span()
        }

        /// Archives a token, permanently preserving the on-chain provenance record.
        /// Only the token owner can archive their token.
        /// Replaces destructive burn — the IP registration record is never destroyed.
        fn archive(ref self: ContractState, token: ByteArray) {
            let token = TokenTrait::from_bytes(token);
            let collection = self.collections.read(token.collection_id);
            assert(collection.is_active, 'Collection is not active');

            let caller = get_caller_address();
            let token_owner = IERC721Dispatcher { contract_address: collection.ip_nft }
                .owner_of(token.token_id);
            assert(token_owner == caller, 'Caller not token owner');

            IIPNftDispatcher { contract_address: collection.ip_nft }.archive(token.token_id);

            let timestamp = get_block_timestamp();
            let mut collection_stats = self.collection_stats.read(token.collection_id);
            collection_stats.total_archived += 1;
            collection_stats.last_archive_time = timestamp;
            self.collection_stats.entry(token.collection_id).write(collection_stats);

            self
                .emit(
                    TokenArchived {
                        collection_id: token.collection_id,
                        token_id: token.token_id,
                        operator: caller,
                        timestamp,
                    },
                );
        }

        /// Batch archives multiple tokens.
        /// C-01 FIX: ownership verified for every token inside the loop.
        /// Stats are written once per unique collection, not once per token.
        fn batch_archive(ref self: ContractState, tokens: Array<ByteArray>) {
            let n = tokens.len();
            assert(n > 0, 'Tokens array is empty');

            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            // Accumulate archive counts per collection_id to minimise storage writes.
            // Key: collection_id.low (felt252); Value: count of archived tokens.
            // collection_ids are sequential u256 with high=0, so .low is unique.
            let mut unique_cols: Array<u256> = array![];
            let mut col_counts: Felt252Dict<u128> = Default::default();

            let mut i: u32 = 0;
            while i < n {
                let token = TokenTrait::from_bytes(tokens.at(i).clone());
                let collection = self.collections.read(token.collection_id);
                assert(collection.is_active, 'Collection is not active');

                // C-01 FIX: verify ownership for every token
                let token_owner = IERC721Dispatcher { contract_address: collection.ip_nft }
                    .owner_of(token.token_id);
                assert(token_owner == caller, 'Caller not token owner');

                IIPNftDispatcher { contract_address: collection.ip_nft }.archive(token.token_id);

                let key: felt252 = token.collection_id.low.into();
                let prev = col_counts.get(key);
                if prev == 0 {
                    unique_cols.append(token.collection_id);
                }
                col_counts.insert(key, prev + 1);

                i += 1;
            };

            // One storage read+write per unique collection rather than per token
            let mut j: u32 = 0;
            while j < unique_cols.len() {
                let col_id = *unique_cols.at(j);
                let count: u256 = col_counts.get(col_id.low.into()).into();
                let mut stats = self.collection_stats.read(col_id);
                stats.total_archived += count;
                stats.last_archive_time = timestamp;
                self.collection_stats.entry(col_id).write(stats);
                j += 1;
            };

            self
                .emit(
                    TokenArchivedBatch { tokens: tokens.clone(), operator: caller, timestamp },
                );
        }

        /// Transfers a token from one address to another.
        /// The IPCollection contract must be approved for the token.
        /// M-02 FIX: caller must be the token owner or an approved operator.
        fn transfer_token(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token: ByteArray,
        ) {
            let token = TokenTrait::from_bytes(token);
            let collection = self.collections.read(token.collection_id);
            assert(collection.is_active, 'Collection is not active');

            let caller = get_caller_address();
            let ip_nft = IERC721Dispatcher { contract_address: collection.ip_nft };

            let approved = ip_nft.get_approved(token.token_id);
            assert(approved == get_contract_address(), 'Contract not approved');

            // M-02 FIX: caller must be owner or approved operator
            let token_owner = ip_nft.owner_of(token.token_id);
            assert(
                caller == token_owner || ip_nft.is_approved_for_all(token_owner, caller),
                'Not authorized',
            );

            ip_nft.transfer_from(from, to, token.token_id);

            // R-03 FIX: update transfer stats (was never updated before)
            let timestamp = get_block_timestamp();
            let mut collection_stats = self.collection_stats.read(token.collection_id);
            collection_stats.total_transfers += 1;
            collection_stats.last_transfer_time = timestamp;
            self.collection_stats.entry(token.collection_id).write(collection_stats);

            self
                .emit(
                    TokenTransferred {
                        collection_id: token.collection_id,
                        token_id: token.token_id,
                        operator: caller,
                        timestamp,
                    },
                );
        }

        /// Batch transfers multiple tokens from one address to another.
        /// H-01 FIX: approval check and caller authorization added inside the loop.
        /// Stats are written once per unique collection, not once per token.
        fn batch_transfer(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            tokens: Array<ByteArray>,
        ) {
            let n = tokens.len();
            assert(n > 0, 'Tokens array is empty');

            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            // Accumulate transfer counts per collection_id to minimise storage writes
            let mut unique_cols: Array<u256> = array![];
            let mut col_counts: Felt252Dict<u128> = Default::default();

            let mut i: u32 = 0;
            while i < n {
                let token = TokenTrait::from_bytes(tokens.at(i).clone());
                let collection = self.collections.read(token.collection_id);
                assert(collection.is_active, 'Collection is not active');

                let ip_nft = IERC721Dispatcher { contract_address: collection.ip_nft };

                // H-01 FIX: require contract approval (was missing in batch path)
                let approved = ip_nft.get_approved(token.token_id);
                assert(approved == get_contract_address(), 'Contract not approved');

                // H-01 FIX: require caller is authorized (was missing entirely)
                let token_owner = ip_nft.owner_of(token.token_id);
                assert(
                    caller == token_owner || ip_nft.is_approved_for_all(token_owner, caller),
                    'Not authorized',
                );

                ip_nft.transfer_from(from, to, token.token_id);

                let key: felt252 = token.collection_id.low.into();
                let prev = col_counts.get(key);
                if prev == 0 {
                    unique_cols.append(token.collection_id);
                }
                col_counts.insert(key, prev + 1);

                i += 1;
            };

            // One storage read+write per unique collection rather than per token
            let mut j: u32 = 0;
            while j < unique_cols.len() {
                let col_id = *unique_cols.at(j);
                let count: u256 = col_counts.get(col_id.low.into()).into();
                let mut stats = self.collection_stats.read(col_id);
                stats.total_transfers += count;
                stats.last_transfer_time = timestamp;
                self.collection_stats.entry(col_id).write(stats);
                j += 1;
            };

            self
                .emit(
                    TokenTransferredBatch {
                        from, to, tokens: tokens.clone(), operator: caller, timestamp,
                    },
                );
        }

        /// Updates mutable metadata (name, symbol, base_uri) for a collection.
        /// Only the collection owner can update. Emits CollectionUpdated.
        fn update_collection_metadata(
            ref self: ContractState,
            collection_id: u256,
            name: ByteArray,
            symbol: ByteArray,
            base_uri: ByteArray,
        ) {
            let caller = get_caller_address();
            let mut collection = self.collections.read(collection_id);
            assert(collection.owner == caller, 'Not collection owner');
            assert(name.len() > 0, 'Name cannot be empty');
            assert(symbol.len() > 0, 'Symbol cannot be empty');

            collection.name = name.clone();
            collection.symbol = symbol.clone();
            collection.base_uri = base_uri.clone();
            self.collections.entry(collection_id).write(collection);

            self
                .emit(
                    CollectionUpdated {
                        collection_id,
                        owner: caller,
                        name,
                        symbol,
                        base_uri,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Toggles the active state of a collection.
        /// Only the collection owner can toggle this.
        fn set_collection_active(
            ref self: ContractState, collection_id: u256, is_active: bool,
        ) {
            let caller = get_caller_address();
            let mut collection = self.collections.read(collection_id);
            assert(collection.owner == caller, 'Not collection owner');
            collection.is_active = is_active;
            self.collections.entry(collection_id).write(collection);
        }

        /// Lists all token IDs owned by a user in a specific collection.
        fn list_user_tokens_per_collection(
            self: @ContractState, collection_id: u256, user: ContractAddress,
        ) -> Span<u256> {
            let collection = self.collections.read(collection_id);
            if !collection.is_active {
                return array![].span();
            }
            let ip_nft = IERC721EnumerableDispatcher { contract_address: collection.ip_nft };
            ip_nft.all_tokens_of_owner(user)
        }

        /// Returns all collection IDs owned by the specified user.
        fn list_user_collections(self: @ContractState, user: ContractAddress) -> Span<u256> {
            let user_collection_index = self.user_collection_index.read(user);
            let mut collections = array![];
            let mut i: u256 = 0;
            while i < user_collection_index {
                let collection_id = self.user_collections.entry((user, i)).read();
                collections.append(collection_id);
                i += 1;
            };
            collections.span()
        }

        /// Retrieves the metadata and configuration of a specific collection.
        fn get_collection(self: @ContractState, collection_id: u256) -> Collection {
            self.collections.read(collection_id)
        }

        /// Returns the total number of collections ever created.
        fn get_collection_count(self: @ContractState) -> u256 {
            self.collection_count.read()
        }

        /// Retrieves statistics for a specific collection.
        fn get_collection_stats(self: @ContractState, collection_id: u256) -> CollectionStats {
            self.collection_stats.read(collection_id)
        }

        /// Checks if a collection is valid and active.
        fn is_valid_collection(self: @ContractState, collection_id: u256) -> bool {
            let collection = self.collections.read(collection_id);
            collection.is_active
        }

        /// Retrieves full token data including the immutable legal record fields.
        /// Reverts if the collection is inactive or the token does not exist.
        /// Uses a single cross-contract call (get_full_token_data) instead of four.
        fn get_token(self: @ContractState, token: ByteArray) -> TokenData {
            let token = TokenTrait::from_bytes(token);
            let collection = self.collections.read(token.collection_id);
            assert(collection.is_active, 'Collection is not active');

            // Single cross-contract call returns all four fields at once
            let nft = IIPNftDispatcher { contract_address: collection.ip_nft };
            let (owner, metadata_uri, original_creator, registered_at) = nft
                .get_full_token_data(token.token_id);

            TokenData {
                collection_id: token.collection_id,
                token_id: token.token_id,
                owner,
                metadata_uri,
                original_creator,
                registered_at,
            }
        }

        /// Checks if a token is valid (exists in an active collection).
        /// Safe: uses token_exists which never panics, unlike owner_of.
        fn is_valid_token(self: @ContractState, token: ByteArray) -> bool {
            let token = TokenTrait::from_bytes(token);
            let collection = self.collections.read(token.collection_id);
            if !collection.is_active {
                return false;
            }
            // token_exists reads the owner slot directly and returns false for non-existent
            // tokens — owner_of would panic, making is_valid_token unusable as a guard
            IIPNftDispatcher { contract_address: collection.ip_nft }.token_exists(token.token_id)
        }

        /// Checks if a given address is the owner of a specific collection.
        fn is_collection_owner(
            self: @ContractState, collection_id: u256, owner: ContractAddress,
        ) -> bool {
            let collection = self.collections.read(collection_id);
            collection.owner == owner
        }

        /// Updates the IPNft class hash used for future collection deployments.
        /// Only affects new collections — already-deployed IPNft contracts are immutable.
        fn upgrade_ip_nft_class_hash(ref self: ContractState, new_nft_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.ip_nft_class_hash.write(new_nft_class_hash)
        }
    }
}
