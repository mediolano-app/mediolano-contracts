use alexandria_storage::{List, ListTrait};
use core::num::traits::Zero;
// use alexandria_storage::List;
// use openzeppelin::access::accesscontrol::{AccessControlComponent};
// use openzeppelin::access::ownable::interface::IOwnable;
// use openzeppelin::token::erc721::ERC721ReceiverComponent;
// use openzeppelin::token::erc721::interface::ERC721ABIDispatcher;
// use openzeppelin::token::erc721::interface::ERC721ABIDispatcherTrait;
use core::traits::*;
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::introspection::src5::SRC5Component;
use openzeppelin::token::erc721::ERC721Component;
use openzeppelin::token::erc721::extensions::ERC721EnumerableComponent;
use openzeppelin::upgrades::UpgradeableComponent;
use openzeppelin::upgrades::interface::IUpgradeable;
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
use super::interfaces::ITimeCapsule;
use super::types::TimeCapsule;
// use core::traits::Drop;

#[starknet::contract]
pub mod IPTimeCapsule {
    // use openzeppelin::token::erc721::ERC721Component::InternalTrait;
    use starknet::ClassHash;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::ERC721Component::InternalTrait;
    use super::{*, Zero};

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
    // impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl ERC721EnumerableInternalImpl = ERC721EnumerableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        time_capsule: Map<u256, TimeCapsule>,
        token_id_count: u256,
        metadata_hash: felt252,
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
        TimeCapsuleMinted: TimeCapsuleMinted,
    }

    #[derive(Drop, starknet::Event)]
    struct TimeCapsuleMinted {
        token_id: u256,
        to: ContractAddress,
        metadata_hash: felt252,
        unvesting_timestamp: u64,
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
            if to.is_non_zero() {
                let mut to_tokens = contract_state.user_tokens.read(to);
                ListTrait::append(ref to_tokens, token_id).expect('Append to to_tokens failed');
                contract_state.user_tokens.write(to, to_tokens);
            }
            if auth.is_non_zero() {
                let mut from_tokens = contract_state.user_tokens.read(auth);
                let mut new_tokens: Array<u256> = array![];
                let len = from_tokens.len();
                let mut i = 0;
                while i < len {
                    let token = from_tokens.get(i).expect('List get failed');
                    if token.expect('List get failed') != token_id {
                        new_tokens.append(token.expect('List get failed'));
                    }
                    i += 1;
                }
                let mut new_from_tokens: List<u256> = ListTrait::new(
                    0, starknet::storage_access::storage_base_address_from_felt252(0),
                );
                for token in new_tokens {
                    ListTrait::append(ref new_from_tokens, token)
                        .expect('should to new_from_tokens');
                }
                contract_state.user_tokens.write(auth, new_from_tokens);
            }
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash)
        }
    }

    #[abi(embed_v0)]
    impl IPTimeCapsuleImpl of ITimeCapsule<ContractState> {
        fn mint(
            ref self: ContractState,
            recipient: ContractAddress,
            metadata_hash: felt252,
            unvesting_timestamp: u64,
        ) -> u256 {
            let caller = get_caller_address();
            assert(caller.is_non_zero(), 'Caller is zero address');
            assert(recipient.is_non_zero(), 'Recipient is zero address');
            let current_timestamp = get_block_timestamp();
            assert(unvesting_timestamp > current_timestamp, 'Unvesting date in past');

            let token_id = self.token_id_count.read() + 1;
            self.token_id_count.write(token_id);

            self.erc721.mint(recipient, token_id);
            self
                .time_capsule
                .write(
                    token_id, TimeCapsule { owner: recipient, metadata_hash, unvesting_timestamp },
                );

            let mut user_tokens = self.user_tokens.read(recipient);
            ListTrait::append(ref user_tokens, token_id).expect('Append to user_tokens failed');
            self.user_tokens.write(recipient, user_tokens);

            self
                .emit(
                    TimeCapsuleMinted {
                        token_id, to: recipient, metadata_hash, unvesting_timestamp,
                    },
                );

            token_id
        }

        fn get_metadata(self: @ContractState, token_id: u256) -> felt252 {
            assert(self.erc721.exists(token_id), 'Token does not exists');
            let capsule = self.time_capsule.read(token_id);
            let current_timestamp = get_block_timestamp();

            if current_timestamp >= capsule.unvesting_timestamp {
                capsule.metadata_hash
            } else {
                0
            }
        }

        fn set_metadata(ref self: ContractState, token_id: u256, metadata_hash: felt252) {
            assert(self.erc721.exists(token_id), 'Token does not exists');
            let capsule = self.time_capsule.read(token_id);
            let caller = get_caller_address();
            assert(caller == capsule.owner || caller == self.ownable.owner(), 'Not authorized');

            let current_timpstamp = get_block_timestamp();
            assert(current_timpstamp >= capsule.unvesting_timestamp, 'Not yet Unvested');

            self
                .time_capsule
                .write(
                    token_id,
                    TimeCapsule {
                        owner: capsule.owner,
                        metadata_hash,
                        unvesting_timestamp: capsule.unvesting_timestamp,
                    },
                )
        }

        fn list_user_tokens(self: @ContractState, owner: ContractAddress) -> Array<u256> {
            let user_tokens = self.user_tokens.read(owner);
            let mut token_ids: Array<u256> = array![];
            let len = user_tokens.len();
            let mut i: u32 = 0;
        
            while i < len {
                match user_tokens.get(i) {
                    Result::Ok(token_option) => {
                        match token_option {
                            Option::Some(token_id) => {
                                token_ids.append(token_id);
                            },
                            Option::None => {
                               
                            }
                        }
                    },
                    Result::Err(_) => {
                        break;
                    }
                }
                i += 1;
            }
        
            token_ids
        }
    }
}
