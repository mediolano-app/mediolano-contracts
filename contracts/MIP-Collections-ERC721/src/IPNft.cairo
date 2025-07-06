use starknet::ContractAddress;

#[starknet::interface]
pub trait IIPNft<ContractState> {
    fn mint(ref self: ContractState, recipient: ContractAddress, token_id: u256);
    fn batch_mint(
        ref self: ContractState, recipients: Array<ContractAddress>, start_id: u256,
    ) -> Span<u256>;
    fn burn(ref self: ContractState, token_id: u256);
    fn batch_burn(ref self: ContractState, token_ids: Array<u256>);
    fn transfer(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
    );
    fn batch_transfer(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, token_ids: Array<u256>,
    );
    fn get_collection_id(self: @ContractState) -> u256;
    fn get_collection_manager(self: @ContractState) -> ContractAddress;
    fn get_all_user_tokens(self: @ContractState, user: ContractAddress) -> Span<u256>;
    fn get_total_supply(self: @ContractState) -> u256;
}

#[starknet::contract]
pub mod IPNft {
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::ERC721Component::InternalTrait;
    use openzeppelin::token::erc721::extensions::ERC721EnumerableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::{
        ClassHash, ContractAddress, get_caller_address, contract_address_const,
        storage::{StoragePointerReadAccess, StoragePointerWriteAccess},
    };

    use super::IIPNft;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
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
    impl AccessControlMixinImpl = AccessControlComponent::AccessControlMixinImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl ERC721EnumerableInternalImpl = ERC721EnumerableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        collection_manager: ContractAddress,
        collection_id: u256,
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
    impl IPNFTIMpl of IIPNft<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, token_id: u256) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.erc721.mint(recipient, token_id);
        }

        fn batch_mint(
            ref self: ContractState, recipients: Array<ContractAddress>, start_id: u256,
        ) -> Span<u256> {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            let n = recipients.len();
            let mut i: u32 = 0;

            let mut token_ids: Array<u256> = array![];

            while i < n {
                let recipient: ContractAddress = *recipients.at(i);
                assert(!recipient.is_zero(), 'Recipient is zero address');
                let next_token_id = start_id + i.into();
                self.erc721.mint(recipient, next_token_id);
                token_ids.append(next_token_id);
                i += 1;
            };

           token_ids.span()
        }

        fn burn(ref self: ContractState, token_id: u256) {
            self.erc721.update(contract_address_const::<0>(), token_id, get_caller_address());
        }

        fn batch_burn(ref self: ContractState, token_ids: Array<u256>) {
            let n = token_ids.len();
            let mut i: u32 = 0;
            let caller = get_caller_address();

            while i < n {
                let token_id: u256 = *token_ids.at(i);
                self.erc721.update(contract_address_const::<0>(), token_id, caller);
                i += 1;
            };
        }

        fn transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
        ) {
            self.erc721.transfer(from, to, token_id);
        }

        fn batch_transfer(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Array<u256>,
        ) {
            let n = token_ids.len();
            let mut i: u32 = 0;

            while i < n {
                let token_id: u256 = *token_ids.at(i);
                self.erc721.transfer(from, to, token_id);
                i += 1;
            };
        }

        fn get_collection_id(self: @ContractState) -> u256 {
            self.collection_id.read()
        }

        fn get_collection_manager(self: @ContractState) -> ContractAddress {
            self.collection_manager.read()
        }

        fn get_all_user_tokens(self: @ContractState, user: ContractAddress) -> Span<u256> {
            self.erc721_enumerable.all_tokens_of_owner(user)
        }

        fn get_total_supply(self: @ContractState) -> u256 {
            self.erc721_enumerable.total_supply()
        }
    }
}

