#[starknet::contract]
pub mod IPCollection {
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
        TokenBurned: TokenBurned,
        TokenBurnedBatch: TokenBurnedBatch,
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
    pub struct TokenBurned {
        pub collection_id: u256,
        pub token_id: u256,
        pub operator: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenBurnedBatch {
        pub tokens: Array<ByteArray>,
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

    #[derive(Drop, starknet::Event)]
    pub struct TokenTransferred {
        pub collection_id: u256,
        pub token_id: u256,
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
        /// Creates a new NFT collection with the given name, symbol, and base URI.
        /// Deploys a new NFT contract for the collection and assigns the caller as the owner.
        /// Emits a `CollectionCreated` event.
        ///
        /// Params:
        /// - `name`: Name of the collection.
        /// - `symbol`: Symbol of the collection.
        /// - `base_uri`: Base URI for token metadata.
        ///
        /// Returns: The unique collection ID.
        fn create_collection(
            ref self: ContractState, name: ByteArray, symbol: ByteArray, base_uri: ByteArray,
        ) -> u256 {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Caller is zero address');

            let collection_id = self.collection_count.read() + 1;

            let collection_manager = get_contract_address();

            let mut constructor_calldata: Array<felt252> = array![];

            // Serialize constructor arguments for NFT contract
            (
                name.clone(),
                symbol.clone(),
                base_uri.clone(),
                caller,
                collection_id,
                collection_manager,
            )
                .serialize(ref constructor_calldata);

            let (ip_nft_adddress, _) = deploy_syscall(
                self.ip_nft_class_hash.read(), 0, constructor_calldata.span(), false,
            )
                .unwrap();

            let collection = Collection {
                name: name.clone(),
                symbol: symbol.clone(),
                base_uri: base_uri.clone(),
                owner: caller,
                ip_nft: ip_nft_adddress,
                is_active: true,
            };

            self.collections.entry(collection_id).write(collection);
            self.collection_count.write(collection_id);

            let mut user_collection_index = self.user_collection_index.read(caller);

            self.user_collections.entry((caller, user_collection_index)).write(collection_id);
            self.user_collection_index.entry(caller).write(user_collection_index + 1);

            self.emit(CollectionCreated { collection_id, owner: caller, name, symbol, base_uri });

            collection_id
        }


        /// Mints a new token in the specified collection to the recipient address.
        /// Only the collection owner can mint.
        /// Emits a `TokenMinted` event.
        ///
        /// Params:
        /// - `collection_id`: ID of the collection to mint from.
        /// - `recipient`: Address to receive the minted token.
        ///
        /// Returns: The token ID of the newly minted token.
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

            // read collection stats
            let mut collection_stats = self.collection_stats.read(collection_id);
            let next_token_id = collection_stats.total_minted;

            let ip_nft = IIPNftDispatcher { contract_address: collection.ip_nft };

            ip_nft.mint(recipient, next_token_id, token_uri);

            // update collection stats
            collection_stats.total_minted = next_token_id + 1;
            collection_stats.last_mint_time = get_block_timestamp();

            let metadata_uri = IERC721Dispatcher { contract_address: collection.ip_nft }
                .token_uri(next_token_id);

            self.collection_stats.entry(collection_id).write(collection_stats);

            self
                .emit(
                    TokenMinted {
                        collection_id,
                        token_id: next_token_id,
                        owner: recipient,
                        metadata_uri: metadata_uri,
                    },
                );

            next_token_id
        }

        /// Batch mints tokens in the specified collection to multiple recipients.
        /// Only the collection owner can batch mint.
        /// Emits a `TokenMintedBatch` event.
        ///
        /// Params:
        /// - `collection_id`: ID of the collection to mint from.
        /// - `recipients`: Array of recipient addresses.
        ///
        /// Returns: Span of minted token IDs.
        fn batch_mint(
            ref self: ContractState,
            collection_id: u256,
            recipients: Array<ContractAddress>,
            token_uris: Array<ByteArray>,
        ) -> Span<u256> {
            let n = recipients.len();

            assert(n > 0, 'Recipients array is empty');

            let collection = self.collections.read(collection_id);

            assert(collection.is_active, 'Collection is not active');

            let operator = get_caller_address();

            assert(operator == collection.owner, 'Only collection owner can mint');

            // read collection stats
            let mut collection_stats = self.collection_stats.read(collection_id);

            let ip_nft = IIPNftDispatcher { contract_address: collection.ip_nft };

            let mut i: u32 = 0;

            let mut token_ids: Array<u256> = array![];

            while i < n {
                let recipient: ContractAddress = *recipients.at(i);
                let token_uri: ByteArray = token_uris.at(i).clone();
                assert(!recipient.is_zero(), 'Recipient is zero address');
                let next_token_id = collection_stats.total_minted + i.into();

                ip_nft.mint(recipient, next_token_id, token_uri);

                token_ids.append(next_token_id);

                i += 1;
            }

            let timestamp = get_block_timestamp();

            // update collection stats
            collection_stats.total_minted += n.into();
            collection_stats.last_mint_time = timestamp;

            self.collection_stats.entry(collection_id).write(collection_stats);

            // Emit batch event
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

        /// Burns a specific token, removing it from circulation.
        /// Updates collection stats and emits a `TokenBurned` event.
        ///
        /// Params:
        /// - `token`: ByteArray of token <collection_id:token_id>.
        fn burn(ref self: ContractState, token: ByteArray) {
            let token = TokenTrait::from_bytes(token);

            let collection = self.collections.read(token.collection_id);

            assert(collection.is_active, 'Collection is not active');

            let ip_nft = IIPNftDispatcher { contract_address: collection.ip_nft };

            let token_owner = IERC721Dispatcher { contract_address: collection.ip_nft }
                .owner_of(token.token_id);

            assert(token_owner == get_caller_address(), 'Caller not token owner');

            ip_nft.burn(token.token_id);

            let timestamp = get_block_timestamp();

            // update collection stats
            let mut collection_stats = self.collection_stats.read(token.collection_id);
            collection_stats.total_burned += 1;
            collection_stats.last_burn_time = timestamp;

            self.collection_stats.entry(token.collection_id).write(collection_stats);

            // Emit burn event
            self
                .emit(
                    TokenBurned {
                        collection_id: token.collection_id,
                        token_id: token.token_id,
                        operator: get_caller_address(),
                        timestamp,
                    },
                );
        }

        /// Batch burns multiple tokens.
        /// Updates collection stats and emits a `TokenBurnedBatch` event.
        ///
        /// Params:
        /// - `tokens`: Array of ByteArrays of tokens to burn.
        fn batch_burn(ref self: ContractState, tokens: Array<ByteArray>) {
            let n = tokens.len();

            assert(n > 0, 'Tokens array is empty');

            let mut i: u32 = 0;

            let timestamp = get_block_timestamp();
            while i < n {
                let token = TokenTrait::from_bytes(tokens.at(i).clone());
                let collection = self.collections.read(token.collection_id);
                assert(collection.is_active, 'Collection is not active');

                let ip_nft = IIPNftDispatcher { contract_address: collection.ip_nft };

                ip_nft.burn(token.token_id);

                let mut collection_stats = self.collection_stats.read(token.collection_id);
                collection_stats.total_burned += 1;
                collection_stats.last_burn_time = timestamp;

                self.collection_stats.entry(token.collection_id).write(collection_stats);

                i += 1;
            }

            // Emit batch event
            self
                .emit(
                    TokenBurnedBatch {
                        tokens: tokens.clone(), operator: get_caller_address(), timestamp,
                    },
                );
        }

        // Transfers a token from one address to another.
        /// Emits a `TokenTransferred` event.
        ///
        /// Params:
        /// - `from`: Current owner address.
        /// - `to`: Recipient address.
        /// - `token`: ByteArray of the token.
        fn transfer_token(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token: ByteArray,
        ) {
            let token = TokenTrait::from_bytes(token);

            let collection = self.collections.read(token.collection_id);

            assert(collection.is_active, 'Collection is not active');

            let ip_nft = IERC721Dispatcher { contract_address: collection.ip_nft };

            let approved = ip_nft.get_approved(token.token_id);

            assert(approved == get_contract_address(), 'Contract not approved');

            ip_nft.transfer_from(from, to, token.token_id);

            self
                .emit(
                    TokenTransferred {
                        collection_id: token.collection_id,
                        token_id: token.token_id,
                        operator: get_caller_address(),
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Batch transfers multiple tokens from one address to another.
        /// Emits a `TokenTransferredBatch` event.
        ///
        /// Params:
        /// - `from`: Current owner address.
        /// - `to`: Recipient address.
        /// - `tokens`: Array of ByteArrays of the tokens.
        fn batch_transfer(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            tokens: Array<ByteArray>,
        ) {
            let n = tokens.len();

            assert(n > 0, 'Tokens array is empty');
            let mut i: u32 = 0;
            while i < n {
                let token = TokenTrait::from_bytes(tokens.at(i).clone());
                let collection = self.collections.read(token.collection_id);
                assert(collection.is_active, 'Collection is not active');
                let ip_nft = IERC721Dispatcher { contract_address: collection.ip_nft };
                ip_nft.transfer_from(from, to, token.token_id);
                i += 1;
            }
            // Emit batch event
            self
                .emit(
                    TokenTransferredBatch {
                        from,
                        to,
                        tokens: tokens.clone(),
                        operator: get_caller_address(),
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Lists all token IDs owned by a user in a specific collection.
        ///
        /// Params:
        /// - `collection_id`: ID of the collection.
        /// - `user`: Address of the user.
        ///
        /// Returns: Span of token IDs owned by the user in the collection.
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

        /// Returns a span containing all collection IDs owned by the specified user.
        ///
        /// # Arguments
        /// - `user`: The address of the user whose collection IDs are to be listed.
        ///
        /// # Returns
        /// - `Span<felt252>`: A span containing the collection IDs owned by the user.
        fn list_user_collections(self: @ContractState, user: ContractAddress) -> Span<u256> {
            let mut user_collection_index = self.user_collection_index.read(user);

            let mut collections = array![];

            let mut i: u256 = 0;

            while i < user_collection_index {
                let collection_id = self.user_collections.entry((user, i)).read();
                collections.append(collection_id);
                i += 1;
            }

            return collections.span();
        }

        /// Retrieves the metadata and configuration of a specific collection.
        ///
        /// Params:
        /// - `collection_id`: ID of the collection.
        ///
        /// Returns: The `Collection` struct.
        fn get_collection(self: @ContractState, collection_id: u256) -> Collection {
            return self.collections.read(collection_id);
        }

        /// Retrieves statistics for a specific collection (e.g., total minted, burned).
        ///
        /// Params:
        /// - `collection_id`: ID of the collection.
        ///
        /// Returns: The `CollectionStats` struct.
        fn get_collection_stats(self: @ContractState, collection_id: u256) -> CollectionStats {
            self.collection_stats.read(collection_id)
        }

        /// Checks if a collection is valid (exists and is active).
        ///
        /// Params:
        /// - `collection_id`: ID of the collection.
        ///
        /// Returns: `true` if the collection is active, `false` otherwise.
        fn is_valid_collection(self: @ContractState, collection_id: u256) -> bool {
            let collection = self.collections.read(collection_id);
            collection.is_active
        }

        /// Checks if a token is valid (exists and belongs to an active collection).
        ///
        /// Params:
        /// - `token`: ByteArray encoding the token.
        ///
        /// Returns: `true` if the token is valid, `false` otherwise.
        fn is_valid_token(self: @ContractState, token: ByteArray) -> bool {
            let token = TokenTrait::from_bytes(token);

            let collection = self.collections.read(token.collection_id);
            if !collection.is_active {
                return false;
            }

            let ip_nft = IERC721Dispatcher { contract_address: collection.ip_nft };

            !ip_nft.owner_of(token.token_id).is_zero()
        }

        /// Retrieves metadata and ownership information for a specific token.
        ///
        /// Params:
        /// - `token`: ByteArray encoding the token.
        ///
        /// Returns: The `TokenData` struct.
        fn get_token(self: @ContractState, token: ByteArray) -> TokenData {
            let token = TokenTrait::from_bytes(token);
            let collection = self.collections.read(token.collection_id);

            if !collection.is_active {
                return TokenData {
                    collection_id: 0, token_id: 0, owner: Zero::zero(), metadata_uri: "",
                };
            }

            let ip_nft = IERC721Dispatcher { contract_address: collection.ip_nft };

            let token_uri = ip_nft.token_uri(token.token_id);

            let owner = ip_nft.owner_of(token.token_id);

            TokenData {
                collection_id: token.collection_id,
                token_id: token.token_id,
                owner,
                metadata_uri: token_uri,
            }
        }

        /// Checks if a given address is the owner of a specific collection.
        ///
        /// Params:
        /// - `collection_id`: ID of the collection.
        /// - `owner`: Address to check.
        ///
        /// Returns: `true` if the address is the owner, `false` otherwise.
        fn is_collection_owner(
            self: @ContractState, collection_id: u256, owner: ContractAddress,
        ) -> bool {
            let collection = self.collections.read(collection_id);
            collection.owner == owner
        }

        /// Upgrades the collection nft class hash
        ///
        /// Params:
        /// - `new_nft_class_hash`: Class hash of new IP NFT contract
        ///
        fn upgrade_ip_nft_class_hash(ref self: ContractState, new_nft_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.ip_nft_class_hash.write(new_nft_class_hash)
        }
    }
}
