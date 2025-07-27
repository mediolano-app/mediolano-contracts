// mip/mip.cairo
// Core smart contract for MIP Protocol: IP ownership as ERC-721 public goods on StarkNet

#[starknet::contract]
pub mod MIP {
    use starknet::ContractAddress;
    use core::num::traits::Zero;
    use core::array::Span;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::extensions::erc721_enumerable::ERC721EnumerableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use super::super::interfaces::{IMIP, ICounter};
    use core::starknet::storage::{Map, StorageMapWriteAccess};

    // Custom Counter Component
    #[starknet::component]
    pub mod CounterComponent {
        use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

        #[storage]
        pub struct Storage {
            counter: u256,
        }

        #[event]
        #[derive(Drop, starknet::Event)]
        pub enum Event {
            CounterIncremented: CounterIncremented,
            CounterDecremented: CounterDecremented,
        }

        #[derive(Drop, starknet::Event)]
        struct CounterIncremented {
            value: u256,
        }

        #[derive(Drop, starknet::Event)]
        struct CounterDecremented {
            value: u256,
        }

        #[embeddable_as(CounterImpl)]
        impl Counter<
            TContractState, +HasComponent<TContractState>,
        > of super::ICounter<ComponentState<TContractState>> {
            fn current(self: @ComponentState<TContractState>) -> u256 {
                self.counter.read()
            }

            fn increment(ref self: ComponentState<TContractState>) {
                let current = self.counter.read();
                self.counter.write(current + 1);
                self.emit(CounterIncremented { value: current + 1 });
            }

            fn decrement(ref self: ComponentState<TContractState>) {
                let current = self.counter.read();
                assert(current > 0, 'Counter cannot be negative');
                self.counter.write(current - 1);
                self.emit(CounterDecremented { value: current - 1 });
            }
        }

        #[generate_trait]
        pub impl InternalImpl<
            TContractState, +HasComponent<TContractState>,
        > of InternalTrait<TContractState> {
            fn initializer(ref self: ComponentState<TContractState>) {
                self.counter.write(0);
            }
        }
    }

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(
        path: ERC721EnumerableComponent, storage: erc721_enumerable, event: ERC721EnumerableEvent,
    );
    component!(path: CounterComponent, storage: counter, event: CounterEvent);

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl CounterInternalImpl = CounterComponent::CounterImpl<ContractState>;
    impl CounterInternalImplStorage = CounterComponent::InternalImpl<ContractState>;
    impl ERC721EnumerableInternalImpl = ERC721EnumerableComponent::InternalImpl<ContractState>;

    // Implement ERC721 hooks for enumerable updates
    impl ERC721EnumerableHooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let mut contract_state = self.get_contract_mut();
            ERC721EnumerableInternalImpl::before_update(
                ref contract_state.erc721_enumerable, to, token_id,
            );
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {}
    }

    #[storage]
    struct Storage {
        token_uris: Map<u256, ByteArray>,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc721_enumerable: ERC721EnumerableComponent::Storage,
        #[substorage(v0)]
        counter: CounterComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721EnumerableEvent: ERC721EnumerableComponent::Event,
        #[flat]
        CounterEvent: CounterComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc721.initializer("MIP Protocol", "MIP", "ipfs://QmMIP/");
        self.ownable.initializer(owner);
        self.erc721_enumerable.initializer();
        CounterInternalImplStorage::initializer(ref self.counter);
    }

    #[abi(embed_v0)]
    impl MIPImpl of IMIP<ContractState> {
        /// Mints a new IP token to the recipient with the specified URI.
        /// Returns the token ID.
        /// @param recipient The address to receive the minted token.
        /// @param uri The URI for the token's metadata (e.g., IPFS link).
        /// @return The ID of the minted token.
        fn mint_item(ref self: ContractState, recipient: ContractAddress, uri: ByteArray) -> u256 {
            assert(recipient.is_non_zero(), 'Invalid recipient');
            let token_id = self.counter.current() + 1;
            self.counter.increment();
            // Use the internal mint function from ERC721Component
            ERC721InternalImpl::mint(ref self.erc721, recipient, token_id);
            // Store the URI using the Map's write method with StorageMapWriteAccess
            StorageMapWriteAccess::write(self.token_uris, token_id, uri.clone());
            token_id
        }
    }

    #[abi(embed_v0)]
    impl CounterImpl of ICounter<ContractState> {
        fn current(self: @ContractState) -> u256 {
            self.counter.current()
        }

        fn increment(ref self: ContractState) {
            self.counter.increment()
        }

        fn decrement(ref self: ContractState) {
            self.counter.decrement()
        }
    }

    // Embed the OpenZeppelin mixin implementations directly
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721EnumerableImpl =
        ERC721EnumerableComponent::ERC721EnumerableImpl<ContractState>;
}
