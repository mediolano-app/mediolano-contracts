use starknet::ContractAddress;

#[starknet::interface]
pub trait IIPCollection<ContractState> {
    fn mint(ref self: ContractState, recipient: ContractAddress) -> u256;
    fn burn(ref self: ContractState, token_id: u256);
    fn list_user_tokens(self: @ContractState, owner: ContractAddress) -> Array<u256>;
    fn transfer_token(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
    );
}

#[starknet::contract]
pub mod IPCollection {
    use core::num::traits::Zero;
    use openzeppelin::token::erc721::ERC721Component::InternalTrait;
    use alexandria_storage::ListTrait;
    use starknet::{
        ClassHash, get_caller_address, ContractAddress, get_contract_address,
        storage::{
            StoragePointerReadAccess, StoragePointerWriteAccess, StorageMapReadAccess,
            StorageMapWriteAccess, Map,
        },
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::extensions::ERC721EnumerableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::UpgradeableComponent;
    use alexandria_storage::List;   

    use super::IIPCollection;

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
        owners: Map<u256, ContractAddress>,
        balances: Map<ContractAddress, u256>,
        token_uri: Map<u256, felt252>,
        token_id_count: u256,
        user_tokens: Map<ContractAddress, List<u256>>,
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
    enum Event {
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
        self.token_id_count.write(0);
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

    #[abi(embed_v0)]
    impl IPCollection of IIPCollection<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress) -> u256 {
            self.ownable.assert_only_owner();

            let caller = get_caller_address();
            assert(caller != Zero::zero(), 'Caller is zero address');

            let token_id = self.token_id_count.read() + 1;

            self.erc721.mint(recipient, token_id);

            let mut user_tokens = self.user_tokens.read(recipient);
            user_tokens.append(token_id);

            self.user_tokens.write(recipient, user_tokens);

            token_id
        }

        fn burn(ref self: ContractState, token_id: u256) {
            self.erc721.update(Zero::zero(), token_id, get_caller_address());
        }

        fn list_user_tokens(self: @ContractState, owner: ContractAddress) -> Array<u256> {
            let mut user_tokens = self.user_tokens.read(owner);

            let mut token_ids: Array<u256> = array![];
            let mut i: u32 = 0;

            loop {
                if (i > user_tokens.len()) {
                    break;
                }

                let token = user_tokens[i];
                token_ids.append(token);

                i += 1;
            };

            token_ids
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
    }
}

