use starknet::ContractAddress;

// pub struct TokenID {
//     pub collection_id: u256,
//     pub token_id: u256
// }

#[starknet::interface]
pub trait IIPCollection<ContractState> {
    fn create_collection(
        ref self: ContractState, name: ByteArray, symbol: ByteArray, base_uri: ByteArray,
    ) -> u256;

    fn mint(ref self: ContractState, collection_id: u256, recipient: ContractAddress) -> u256;
    fn mint_batch(
        ref self: ContractState, collection_id: u256, recipients: Array<ContractAddress>,
    ) -> Array<u256>;

    fn burn(ref self: ContractState, collection_id: u256, token_id: u256);
    fn burn_batch(ref self: ContractState, collection_id: u256, token_ids: Array<u256>);

    fn transfer_token(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, collection_id: u256, token_id: u256,
    );
    fn transfer_batch(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, collection_id: u256, token_ids: Array<u256>,
    );

    fn list_user_tokens_per_collection(self: @ContractState, collection_id: u256, user: ContractAddress) -> Span<u256>;
    fn list_user_collections(self: @ContractState, user: ContractAddress) -> Span<u256>;

    fn get_collection(self: @ContractState, collection_id: u256) -> Collection;
    fn is_valid_collection(self: @ContractState, collection_id: u256) -> bool;
    fn get_collection_stats(self: @ContractState, collection_id: u256) -> CollectionStats;

    // fn get_token(self: @ContractState, token_id: u256) -> Token;
    // fn is_valid_token(self: @ContractState, token_id: u256, collection_id: u256) -> bool;
  
    fn is_collection_owner(
        self: @ContractState, collection_id: u256, user: ContractAddress,
    ) -> bool;
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Collection {
    pub name: ByteArray,
    pub symbol: ByteArray,
    pub base_uri: ByteArray,
    pub owner: ContractAddress,
    pub ip_nft: ContractAddress,
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
    pub total_minted: u256,
    pub total_burned: u256,
    pub total_transfers: u256,
    pub last_mint_time: u64,
    pub last_burn_time: u64,
    pub last_transfer_time: u64,
}

#[starknet::contract]
pub mod IPCollection {
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::{
        ClassHash, ContractAddress, get_caller_address, get_contract_address,
        contract_address_const, get_block_timestamp,
        storage::{
            Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
            StoragePointerReadAccess, StoragePointerWriteAccess,
        },
    };

    use starknet::syscalls::deploy_syscall;

    use super::{Collection, IIPCollection, Token, CollectionStats};

    use crate::IPNft::{IIPNftDispatcher, IIPNftDispatcherTrait};

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
        pub token_ids: Array<u256>,
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
        pub collection_id: u256,
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

    #[derive(Drop, starknet::Event)]
    pub struct TokenTransferred { 
        pub collection_id: u256 , 
        pub token_id: u256, 
        pub operator: ContractAddress, 
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, ip_nft_class_hash: ClassHash) {
        self.ownable.initializer(owner);
        self.collection_count.write(0);
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
        fn create_collection(
            ref self: ContractState, name: ByteArray, symbol: ByteArray, base_uri: ByteArray,
        ) -> u256 {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Caller is zero address');

            let collection_id = self.collection_count.read() + 1;

            let collection_manager = get_contract_address();

            let mut constructor_calldata: Array::<felt252> = array![];

            // Serialize constructor arguments for NFT contract
            (
                name.clone(),
                symbol.clone(),
                base_uri.clone(),
                caller,
                collection_id.clone(),
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

            self.emit(CollectionCreated { collection_id, owner: caller, name, symbol, base_uri });

            collection_id
        }

        fn mint(ref self: ContractState, collection_id: u256, recipient: ContractAddress) -> u256 {
            assert(!recipient.is_zero(), 'Recipient is zero address');

            let collection = self.collections.read(collection_id);

            assert(get_caller_address() == collection.owner, 'Only collection owner can mint');

            assert(collection.is_active, 'Collection is not active');

            // read collection stats
            let mut collection_stats = self.collection_stats.read(collection_id);
            let next_token_id = collection_stats.total_minted;

            let ip_nft = IIPNftDispatcher{contract_address: collection.ip_nft};

            ip_nft.mint(recipient, next_token_id);

            // update collection stats
            collection_stats.total_minted = next_token_id + 1;
            collection_stats.last_mint_time = get_block_timestamp();

            let token_uri = ip_nft.get_token_uri(next_token_id);

            self.collection_stats.write(collection_id, collection_stats);

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

        fn batch_mint(
            ref self: ContractState, collection_id: u256, recipients: Array<ContractAddress>,
        ) -> Array<u256> {
            let n = recipients.len();

            assert(n > 0, 'Recipients array is empty');

            let collection = self.collections.read(collection_id);

            assert(collection.is_active, 'Collection is not active');

            let operator = get_caller_address();

            assert(operator == collection.owner, 'Only collection owner can mint');

            // read collection stats
            let mut collection_stats = self.collection_stats.read(collection_id);

            let ip_nft = IIPNftDispatcher{contract_address: collection.ip_nft};

            let minted_token_ids = ip_nft.batch_mint(recipients, collection_stats.total_minted);

            let timestamp = get_block_timestamp();

            // update collection stats
            collection_stats.total_minted += n.into();
            collection_stats.last_mint_time = timestamp;

            self.collection_stats.write(collection_id, collection_stats);

            // Emit batch event
            self
                .emit(
                    TokenMintedBatch {
                        collection_id,
                        token_ids: minted_token_ids.into().clone(),
                        owners: recipients.clone(),
                        operator,
                        timestamp,
                    },
                );

            minted_token_ids
        }

        fn burn(
            ref self: ContractState, collection_id: u256, token_id: u256,
        ) -> Array<u256> {
            let collection = self.collections.read(collection_id);

            assert(collection.is_active, 'Collection is not active');

            let ip_nft = IIPNftDispatcher{contract_address: collection.ip_nft};

            ip_nft.burn(token_id);

            let timestamp = get_block_timestamp();

            // update collection stats
            let mut collection_stats = self.collection_stats.read(collection_id);
            collection_stats.total_burned += 1;
            collection_stats.last_burn_time = timestamp;

            self.collection_stats.write(collection_id, collection_stats);

            // Emit burn event
            self
                .emit(
                    TokenBurned {
                        collection_id,
                        token_id,
                        operator: get_caller_address(),
                        timestamp,
                    },
                );
        }

        fn batch_burn(ref self: ContractState, collection_id: u256, token_ids: Array<u256>) {
           
            let collection = self.collections.read(collection_id);

            assert(collection.is_active, 'Collection is not active');

            let ip_nft = IIPNftDispatcher{contract_address: collection.ip_nft};

            ip_nft.batch_burn(token_ids);

            let timestamp = get_block_timestamp();

            let mut collection_stats = self.collection_stats.read(collection_id);
            collection_stats.total_burned += token_ids.len();
            collection_stats.last_burn_time = timestamp;
           
            // Emit batch event
            self.emit(
                TokenBurnedBatch { 
                    collection_id, 
                    token_ids: token_ids.clone(), 
                    operator: get_caller_address(), 
                    timestamp
                }
            );
        }

        fn transfer_token(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, collection_id: u256, token_id: u256,
        ) {
            let collection = self.collections.read(collection_id);

            assert(collection.is_active, 'Collection is not active');

            let ip_nft = IIPNftDispatcher{contract_address: collection.ip_nft};

            ip_nft.transfer(from, to, collection_id);

            self.emit(
                TokenTransferred { 
                    collection_id, 
                    token_id: token_id.clone(), 
                    operator: get_caller_address(), 
                    timestamp: get_block_timestamp(),
                }
            );

        }

        fn batch_transfer(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            collection_id: u256,
            token_ids: Array<u256>,
        ) {
            let collection = self.collections.read(collection_id);

            assert(collection.is_active, 'Collection is not active');

            let ip_nft = IIPNftDispatcher{contract_address: collection.ip_nft};

            ip_nft.batch_transfer(from, to, collection_id, token_ids);
        
            // Emit batch event
            self
                .emit(
                    TokenTransferredBatch {
                        collection_id,
                        from, 
                        to, 
                        token_ids: token_ids.clone(), 
                        operator: get_caller_address(), 
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn list_user_tokens_per_collection(self: @ContractState, collection_id: u256, user: ContractAddress) -> Span<u256> {
            let collection = self.collections.read(collection_id);

            if !collection.is_active {
                return array![].span();
            }

            let ip_nft = IIPNftDispatcher{contract_address: collection.ip_nft};
            ip_nft.get_all_user_tokens(user)
        }

        fn list_user_collections(self: @ContractState, user: ContractAddress) -> Span<u256> {
            return array![].span();
        }

        fn get_collection(self: @ContractState, collection_id: u256) -> Collection {
            return self.collections.read(collection_id);
        }

        fn get_collection_stats(self: @ContractState, collection_id: u256) -> CollectionStats {
            self.collection_stats.read(collection_id)
        }

        fn is_valid_collection(self: @ContractState, collection_id: u256) -> bool {
            // Try to read the collection; if it exists and is active, return true
            let collection = self.collections.read(collection_id);
            collection.is_active
        }

        // // could update check to show that token belongs to a particular collection
        // fn is_valid_token(self: @ContractState, token_id: u256) -> bool {
        //     // Try to read the token; if it exists and owner is not zero, return true
        //     let token = self.tokens.read(token_id);
        //     !token.owner.is_zero()
        // }

        // // (bug) check notes on the Token struct
        // fn get_token(self: @ContractState, token_id: u256) -> Token {
        //     let collection_id = self.erc721_enumerable.to
        //     return self.tokens.read(token_id);
        // }

        fn is_collection_owner(
            self: @ContractState, collection_id: u256, owner: ContractAddress,
        ) -> bool {
            let collection = self.collections.read(collection_id);
            collection.owner == owner
        }
    }
}