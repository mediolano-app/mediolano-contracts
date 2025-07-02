use starknet::ContractAddress;

#[starknet::interface]
pub trait IIPCollection<ContractState> {
    fn create_collection(
        ref self: ContractState, name: ByteArray, symbol: ByteArray, base_uri: ByteArray,
        max_supply: u128, metadata_uri: ByteArray, royalty_recipient: ContractAddress,
        royalty_basis_points: u16, mint_price: u128, mint_start_time: u256
    ) -> u256;
    fn update_collection(
        ref self: ContractState, collection_id: u256, max_supply: u128,
        royalty_recipient: ContractAddress, royalty_basis_points: u16,
        mint_price: u128, mint_start_time: u256, is_paused: bool, is_public_mint: bool
    );
    fn set_collection_uri(
        ref self: ContractState, collection_id: u256, uri: ByteArray
    );
    fn set_token_uri(
        ref self: ContractState, collection_id: u256, token_id: u256, uri: ByteArray
    );
    fn set_royalties(
        ref self: ContractState, collection_id: u256, recipient: ContractAddress,
        basis_points: u16
    );
    fn get_royalties(self: @ContractState, collection_id: u256) -> (ContractAddress, u16);

    fn mint_batch(
        ref self: ContractState, collection_id: u256, recipients: Array<ContractAddress>,
        metadata_uris: Array<ByteArray>, amounts: Array<u256>
    ) -> Array<u256>;
    fn public_mint(
        ref self: ContractState, collection_id: u256, quantity: u256
    ) -> Array<u256>;
    fn set_token_approval(
        ref self: ContractState, to: ContractAddress, token_id: u256
    );
    fn set_operator_approval(
        ref self: ContractState, operator: ContractAddress, approved: bool
    );
    fn verify_collection_owner(
        self: @ContractState, collection_id: u256, owner: ContractAddress
    ) -> bool;
    fn verify_token_owner(
        self: @ContractState, token_id: u256, owner: ContractAddress
    ) -> bool;

    fn get_collection_info(
        self: @ContractState, collection_id: u256
    ) -> (u256, u128, bool, bool, u128, u256);
    fn get_token_info(
        self: @ContractState, token_id: u256
    ) -> (u256, u256, u256);
    fn get_user_balance(
        self: @ContractState, owner: ContractAddress
    ) -> u256;
    fn get_user_balance_of_collection(
        self: @ContractState, owner: ContractAddress, collection_id: u256
    ) -> u256;
    fn get_collection_stats(
        self: @ContractState, collection_id: u256
    ) -> (u256, u256, u256);
    fn get_protocol_stats(self: @ContractState) -> (u256, u256, u256, u256, u256);

    fn transfer_batch(
        ref self: ContractState, from: ContractAddress, to: ContractAddress,
        token_ids: Array<u256>
    );
    fn burn_batch(ref self: ContractState, token_ids: Array<u256>);
    fn approve_batch(
        ref self: ContractState, to: ContractAddress, token_ids: Array<u256>
    );
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Collection {
    pub name: ByteArray,
    pub symbol: ByteArray,
    pub base_uri: ByteArray,
    pub owner: ContractAddress,
    pub is_active: bool,
    pub total_supply: u256,
    pub max_supply: u128,
    pub metadata_uri: ByteArray,
    pub royalty_recipient: ContractAddress,
    pub royalty_basis_points: u16,
    pub is_paused: bool,
    pub is_public_mint: bool,
    pub mint_price: u128,
    pub mint_start_time: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Token {
    pub collection_id: u256,
    pub token_id: u256,
    pub owner: ContractAddress,
    pub metadata_uri: ByteArray,
    pub approved: Option<ContractAddress>,
    pub is_burned: bool,
    pub mint_time: u256,
}

#[starknet::contract]
pub mod IPCollection {
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

    use super::{Collection, IIPCollection, Token};

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
        owned_tokens: Map<ContractAddress, Array<u256>>,
        collection_tokens: Map<u256, Array<u256>>,
        token_approvals: Map<u256, ContractAddress>,
        operator_approvals: Map<(ContractAddress, ContractAddress), bool>,
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
        protocol_stats: Map<u8, u256>,
        batch_operations: Map<u256, BatchOperation>,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct BatchOperation {
        pub operation_type: u8,
        pub collection_id: u256,
        pub timestamp: u256,
        pub operator: ContractAddress,
        pub token_count: u128,
    }

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
        TokenMinted: TokenMinted,
        CollectionUpdated: CollectionUpdated,
        TokenTransferredBatch: TokenTransferredBatch,
        TokenBurnedBatch: TokenBurnedBatch,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CollectionCreated {
        pub collection_id: u256,
        pub owner: ContractAddress,
        pub name: ByteArray,
        pub symbol: ByteArray,
        pub max_supply: u128,
        pub mint_price: u128,
        pub mint_start_time: u256,
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
        pub updated_by: ContractAddress,
        pub timestamp: u256,
        pub total_supply: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenTransferredBatch {
        pub collection_id: u256,
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub token_ids: Array<u256>,
        pub timestamp: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenBurnedBatch {
        pub collection_id: u256,
        pub owner: ContractAddress,
        pub token_ids: Array<u256>,
        pub timestamp: u256,
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
        self.protocol_stats.entry(0).write(0);
        self.protocol_stats.entry(1).write(0);
        self.protocol_stats.entry(2).write(0);
    }

    #[abi(embed_v0)]
    impl IPCollection of IIPCollection<ContractState> {
        fn create_collection(
            ref self: ContractState, name: ByteArray, symbol: ByteArray, base_uri: ByteArray,
            max_supply: u128, metadata_uri: ByteArray, royalty_recipient: ContractAddress,
            royalty_basis_points: u16, mint_price: u128, mint_start_time: u256
        ) -> u256 {
            let caller = get_caller_address();
            assert(caller != Zero::zero(), 'Invalid caller address');
            assert(max_supply > 0, 'Max supply must be greater than 0');
            assert(royalty_basis_points <= 10000, 'Royalty basis points must be <= 10000');
            
            let collection_id = self.collection_count.read() + 1;
            self.collection_count.write(collection_id);
            
            let collection = Collection {
                name,
                symbol,
                base_uri,
                owner: caller,
                is_active: true,
                total_supply: 0,
                max_supply,
                metadata_uri,
                royalty_recipient,
                royalty_basis_points,
                is_paused: false,
                is_public_mint: false,
                mint_price,
                mint_start_time,
            };
            
            self.collections.entry(collection_id).write(collection);
            self.protocol_stats.entry(0).write(self.protocol_stats.entry(0).read() + 1);
            
            self.emit(Event::CollectionCreated(CollectionCreated {
                collection_id,
                owner: caller,
                name: name.clone(),
                symbol: symbol.clone(),
                max_supply,
                mint_price,
                mint_start_time,
            }));
            
            collection_id
        }

        fn burn_batch(ref self: ContractState, token_ids: Array<u256>) {
            let caller = get_caller_address();
            assert(caller != Zero::zero(), 'Invalid caller address');
            assert(token_ids.len() > 0, 'Token IDs array cannot be empty');
            
            let mut burned_tokens = array![];
            for token_id in token_ids.iter() {
                let token = self.tokens.entry(token_id).read();
                assert(!token.is_burned, 'Token already burned');
                assert(token.owner == caller, 'Not token owner');
                
                // Update token state
                self.tokens.entry(token_id).write(Token {
                    collection_id: token.collection_id,
                    token_id,
                    owner: caller,
                    metadata_uri: token.metadata_uri,
                    approved: None,
                    is_burned: true,
                    mint_time: token.mint_time,
                });
                
                burned_tokens.append(token_id);
            }
            
            // Update collection stats
            let collection = self.collections.entry(token.collection_id).read();
            self.collections.entry(token.collection_id).write(Collection {
                total_supply: collection.total_supply - burned_tokens.len().into(),
                ..collection
            });
            
            self.emit(Event::TokenBurnedBatch(TokenBurnedBatch {
                collection_id: token.collection_id,
                owner: caller,
                token_ids: burned_tokens,
                timestamp: get_block_timestamp(),
            }));
        }

        fn get_protocol_stats(self: @ContractState) -> (u256, u256, u256, u256, u256) {
            (
                self.protocol_stats.entry(0).read(),
                self.protocol_stats.entry(1).read(),
                self.protocol_stats.entry(2).read(),
                self.protocol_stats.entry(3).read(),
                self.protocol_stats.entry(4).read(),
            )
        }

        fn get_batch_operation(
            self: @ContractState, batch_id: u256
        ) -> BatchOperation {
            self.batch_operations.entry(batch_id).read()
        }
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
            
            // Additional security check
            let token = contract_state.tokens.read(token_id);
            assert(!token.is_burned, 'Cannot transfer burned token');
        }
    }

    fn get_token_uri(base_uri: ByteArray, _token_id: u256) -> ByteArray {
        assert(base_uri.len() > 0, 'Base URI cannot be empty');
        base_uri.clone()
    }
}
