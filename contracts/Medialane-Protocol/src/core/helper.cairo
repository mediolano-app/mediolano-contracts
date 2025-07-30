use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin_utils::snip12::{OffchainMessageHash, SNIP12Metadata, StructHash};
use starknet::ContractAddress;

const MESSAGE_TYPE_HASH: felt252 =
    0x28bf13f11bba405c77ce010d2781c5903cbed100f01f72fcff1664f98343eb6;

#[derive(Copy, Drop, Hash)]
struct Message {
    recipient: ContractAddress,
    amount: u256,
    nonce: felt252,
    expiry: u64,
}

impl StructHashImpl of StructHash<Message> {
    fn hash_struct(self: @Message) -> felt252 {
        let hash_state = PoseidonTrait::new();
        hash_state.update_with(MESSAGE_TYPE_HASH).update_with(*self).finalize()
    }
}

#[starknet::contract]
mod CustomERC20 {
    use openzeppelin_account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin_utils::cryptography::nonces::NoncesComponent;
    use starknet::ContractAddress;
    use super::{Message, OffchainMessageHash, SNIP12Metadata};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20Impl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;
    impl NoncesInternalImpl = NoncesComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        nonces: NoncesComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        NoncesEvent: NoncesComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_supply: u256, recipient: ContractAddress) {
        self.erc20.initializer("MyToken", "MTK");
        self.erc20.mint(recipient, initial_supply);
    }

    /// Required for hash computation.
    impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'CustomERC20'
        }
        fn version() -> felt252 {
            'v1'
        }
    }

    #[external(v0)]
    fn transfer_with_signature(
        ref self: ContractState,
        recipient: ContractAddress,
        amount: u256,
        nonce: felt252,
        expiry: u64,
        signature: Array<felt252>,
    ) {
        assert(starknet::get_block_timestamp() <= expiry, 'Expired signature');
        let owner = starknet::get_caller_address();

        // Check and increase nonce
        self.nonces.use_checked_nonce(owner, nonce);

        // Build hash for calling `is_valid_signature`
        let message = Message { recipient, amount, nonce, expiry };
        let hash = message.get_message_hash(owner);

        let is_valid_signature_felt = ISRC6Dispatcher { contract_address: owner }
            .is_valid_signature(hash, signature);

        // Check either 'VALID' or true for backwards compatibility
        let is_valid_signature = is_valid_signature_felt == starknet::VALIDATED
            || is_valid_signature_felt == 1;
        assert(is_valid_signature, 'Invalid signature');

        // Transfer tokens
        self.erc20._transfer(owner, recipient, amount);
    }
}
