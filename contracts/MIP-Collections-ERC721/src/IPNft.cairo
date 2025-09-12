#[starknet::contract]
pub mod IPNft {
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::extensions::ERC721EnumerableComponent;
    use openzeppelin::token::erc721::interface::{IERC721Metadata, IERC721MetadataCamelOnly};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress};
    use crate::interfaces::IIPNFT::IIPNft;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(
        path: ERC721EnumerableComponent, storage: erc721_enumerable, event: ERC721EnumerableEvent,
    );
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnly = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721EnumerableImpl =
        ERC721EnumerableComponent::ERC721EnumerableImpl<ContractState>;
    #[abi(embed_v0)]
    impl AccessControlCamelImpl =
        AccessControlComponent::AccessControlCamelImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl ERC721EnumerableInternalImpl = ERC721EnumerableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl SRC5ComponentInternalImpl = SRC5Component::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        collection_manager: ContractAddress,
        collection_id: u256,
        uris: Map<u256, ByteArray>,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
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
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        ERC721EnumerableEvent: ERC721EnumerableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        owner: ContractAddress,
        collection_id: u256,
        collection_manager: ContractAddress,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.ownable.initializer(owner);
        self.accesscontrol.initializer();

        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, collection_manager);

        self.erc721_enumerable.initializer();
        self.collection_id.write(collection_id);
        self.collection_manager.write(collection_manager);
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
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl ERC721Metadata of IERC721Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.erc721.ERC721_name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc721.ERC721_symbol.read()
        }

        fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.erc721._require_owned(token_id);
            self.uris.read(token_id)
        }
    }

    #[abi(embed_v0)]
    impl ERC721MetadataCamelOnly of IERC721MetadataCamelOnly<ContractState> {
        fn tokenURI(self: @ContractState, tokenId: u256) -> ByteArray {
            self.erc721._require_owned(tokenId);
            self.uris.read(tokenId)
        }
    }

    #[abi(embed_v0)]
    impl IPNftImpl of IIPNft<ContractState> {
        /// Mints a new ERC721 token to the specified recipient.
        /// Only callable by accounts with the DEFAULT_ADMIN_ROLE.
        ///
        /// # Arguments
        /// * `recipient` - The address to receive the minted token.
        /// * `token_id` - The unique identifier for the token to be minted.
        /// * `token_uri` - The URI metadata associated with the token.
        fn mint(
            ref self: ContractState,
            recipient: ContractAddress,
            token_id: u256,
            token_uri: ByteArray,
        ) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.erc721.mint(recipient, token_id);
            self.uris.write(token_id, token_uri);
        }

        /// Burns (removes) an ERC721 token.
        ///
        /// # Arguments
        /// * `token_id` - The unique identifier for the token to be burned.
        fn burn(ref self: ContractState, token_id: u256) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.erc721.burn(token_id);
        }

        /// Returns the collection ID associated with this contract.
        ///
        /// # Returns
        /// * `u256` - The collection ID.
        fn get_collection_id(self: @ContractState) -> u256 {
            self.collection_id.read()
        }

        /// Returns the address of the collection manager.
        ///
        /// # Returns
        /// * `ContractAddress` - The address of the collection manager.
        fn get_collection_manager(self: @ContractState) -> ContractAddress {
            self.collection_manager.read()
        }

        /// Returns the base uri of the collection.
        ///
        /// # Returns
        /// * `ByteArray` - The base uri of the collection.
        fn base_uri(self: @ContractState) -> ByteArray {
            self.erc721._base_uri()
        }

        // Returns all tokens owned by a specific address.
        // # Arguments
        // * `owner` - The address whose tokens are to be retrieved.
        // # Returns
        // * `Span<u256>` - A span containing all token IDs owned by the specified
        // address.
        fn all_tokens_of_owner(self: @ContractState, owner: ContractAddress) -> Span<u256> {
            self.erc721_enumerable.all_tokens_of_owner(owner)
        }
    }
}

