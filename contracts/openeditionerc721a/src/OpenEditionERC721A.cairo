use starknet::{ContractAddress};

#[starknet::interface]
pub trait IOpenEditionERC721A<ContractState> {
    fn create_claim_phase(
        ref self: ContractState,
        phase_id: u256,
        price: u256,
        start_time: u64,
        end_time: u64,
        is_public: bool,
        whitelist: Array<ContractAddress>,
    );
    fn update_metadata(ref self: ContractState, base_uri: ByteArray);
    fn mint(ref self: ContractState, phase_id: u256, quantity: u256) -> u256;
    fn get_current_token_id(self: @ContractState) -> u256;
    fn get_metadata(self: @ContractState, token_id: u256) -> ByteArray;
    fn get_claim_phase(self: @ContractState, phase_id: u256) -> ClaimPhase;
    fn is_whitelisted(self: @ContractState, phase_id: u256, account: ContractAddress) -> bool;
}

#[derive(Drop, Serde, starknet::Store)]
pub struct ClaimPhase {
    pub price: u256,
    pub start_time: u64,
    pub end_time: u64,
    pub is_public: bool,
}

#[starknet::contract]
pub mod OpenEditionERC721A {
    use super::{ClaimPhase, IOpenEditionERC721A};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, ClassHash};
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StoragePathEntry, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        base_uri: ByteArray,
        current_token_id: u256,
        claim_phases: Map<u256, ClaimPhase>,
        whitelist: Map<(u256, ContractAddress), bool>, // (phase_id, address) -> is_whitelisted
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ERC721Event: ERC721Component::Event,
        OwnableEvent: OwnableComponent::Event,
        SRC5Event: SRC5Component::Event,
        UpgradeableEvent: UpgradeableComponent::Event,
        ClaimPhaseCreated: ClaimPhaseCreated,
        MetadataUpdated: MetadataUpdated,
        TokensMinted: TokensMinted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ClaimPhaseCreated {
        #[key]
        pub phase_id: u256,
        pub price: u256,
        pub start_time: u64,
        pub end_time: u64,
        pub is_public: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MetadataUpdated {
        pub base_uri: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokensMinted {
        #[key]
        pub phase_id: u256,
        pub first_token_id: u256,
        pub quantity: u256,
        pub recipient: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        owner: ContractAddress,
    ) {
        self.erc721.initializer(name, symbol, base_uri.clone());
        self.ownable.initializer(owner);
        self.base_uri.write(base_uri);
        self.current_token_id.write(0);
    }

    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) { // No additional logic needed for now
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) { // No additional logic needed for now
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    fn get_token_uri(base_uri: ByteArray, token_id: u256) -> ByteArray {
        base_uri.clone()
    }

    #[abi(embed_v0)]
    impl OpenEditionERC721AImpl of IOpenEditionERC721A<ContractState> {
        fn create_claim_phase(
            ref self: ContractState,
            phase_id: u256,
            price: u256,
            start_time: u64,
            end_time: u64,
            is_public: bool,
            whitelist: Array<ContractAddress>,
        ) {
            self.ownable.assert_only_owner();
            assert(start_time <= end_time, 'Invalid time range');
            assert(end_time >= get_block_timestamp(), 'Phase ended');

            let phase = ClaimPhase { price, start_time, end_time, is_public };
            self.claim_phases.entry(phase_id).write(phase);

            // Populate whitelist in storage
            let mut i = 0;
            while i < whitelist.len() {
                self.whitelist.entry((phase_id, *whitelist.at(i))).write(true);
                i += 1;
            };

            self.emit(ClaimPhaseCreated { phase_id, price, start_time, end_time, is_public });
        }

        fn update_metadata(ref self: ContractState, base_uri: ByteArray) {
            self.ownable.assert_only_owner();
            self.base_uri.write(base_uri.clone());
            self.emit(MetadataUpdated { base_uri });
        }

        fn mint(ref self: ContractState, phase_id: u256, quantity: u256) -> u256 {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Caller is zero address');
            assert(quantity > 0, 'Invalid quantity');

            let phase = self.claim_phases.read(phase_id);
            let current_time = get_block_timestamp();
            assert(current_time >= phase.start_time, 'Phase not started');
            assert(current_time <= phase.end_time, 'Phase ended');

            // Check access control
            if !phase.is_public {
                assert(self.whitelist.read((phase_id, caller)), 'Not whitelisted');
            }

            // Simplified payment check (assumes external payment system)
            // In production, integrate with a payment system
            // assert(self.erc721.balance_of(caller) >= phase.price * quantity, 'Insufficient
            // funds');

            let first_token_id = self.current_token_id.read() + 1;
            let mut i = 0;
            while i < quantity {
                let token_id = first_token_id + i;
                self.erc721.mint(caller, token_id);
                i += 1;
            };

            self.current_token_id.write(first_token_id + quantity - 1);
            self.emit(TokensMinted { phase_id, first_token_id, quantity, recipient: caller });

            first_token_id
        }

        fn get_current_token_id(self: @ContractState) -> u256 {
            self.current_token_id.read()
        }

        fn get_metadata(self: @ContractState, token_id: u256) -> ByteArray {
            get_token_uri(self.base_uri.read(), token_id)
        }

        fn get_claim_phase(self: @ContractState, phase_id: u256) -> ClaimPhase {
            self.claim_phases.read(phase_id)
        }

        fn is_whitelisted(self: @ContractState, phase_id: u256, account: ContractAddress) -> bool {
            self.whitelist.read((phase_id, account))
        }
    }
}
