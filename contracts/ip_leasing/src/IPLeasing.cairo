#[starknet::contract]
pub mod IPLeasing {
    use ERC1155Component::InternalTrait;
    use core::array::ArrayTrait;
    use core::starknet::{
        ContractAddress, get_caller_address, get_block_timestamp,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess},
    };
    use openzeppelin::token::erc1155::{ERC1155Component};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use super::super::types::{Lease, LeaseOffer};
    use super::super::interfaces::IIPLeasing;

    // Components
    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC1155 External
    #[abi(embed_v0)]
    impl ERC1155Impl = ERC1155Component::ERC1155Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1155MetadataURIImpl =
        ERC1155Component::ERC1155MetadataURIImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    // Internal
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Custom hooks to restrict transfers during active leases
    impl ERC1155HooksImpl of ERC1155Component::ERC1155HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC1155Component::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
        ) {
            let contract_state = self.get_contract();
            let mut i: u32 = 0;
            while i < token_ids.len() {
                let token_id = *token_ids.at(i);
                let lease = contract_state.leases.read(token_id);
                if lease.is_active {
                    // Allow transfers only by the contract itself (e.g., for expiration)
                    assert(
                        get_caller_address() == contract_state.get_contract_address(),
                        'Leased IP cannot be transferred',
                    );
                }
                i += 1;
            }
        }

        fn after_update(
            ref self: ERC1155Component::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
        ) {}
    }

    // Storage
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        leases: Map<u256, Lease>,
        lease_offers: Map<u256, LeaseOffer>,
        active_leases_by_owner: Map<(ContractAddress, u256), u256>,
        active_leases_by_lessee: Map<(ContractAddress, u256), u256>,
        lease_count_by_owner: Map<ContractAddress, u256>,
        lease_count_by_lessee: Map<ContractAddress, u256>,
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        LeaseOfferCreated: LeaseOfferCreated,
        LeaseOfferCancelled: LeaseOfferCancelled,
        LeaseStarted: LeaseStarted,
        LeaseRenewed: LeaseRenewed,
        LeaseExpired: LeaseExpired,
        LeaseTerminated: LeaseTerminated,
    }

    #[derive(Drop, starknet::Event)]
    struct LeaseOfferCreated {
        token_id: u256,
        owner: ContractAddress,
        amount: u256,
        lease_fee: u256,
        duration: u64,
        license_terms_uri: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    struct LeaseOfferCancelled {
        token_id: u256,
        owner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct LeaseStarted {
        token_id: u256,
        lessee: ContractAddress,
        amount: u256,
        start_time: u64,
        end_time: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct LeaseRenewed {
        token_id: u256,
        lessee: ContractAddress,
        new_end_time: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct LeaseExpired {
        token_id: u256,
        lessee: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct LeaseTerminated {
        token_id: u256,
        lessee: ContractAddress,
        reason: ByteArray,
    }

    // Errors
    const INVALID_TOKEN_ID: felt252 = 'Invalid token ID';
    const NOT_TOKEN_OWNER: felt252 = 'Not token owner';
    const INSUFFICIENT_AMOUNT: felt252 = 'Insufficient amount';
    const INVALID_LEASE_FEE: felt252 = 'Invalid lease fee';
    const INVALID_DURATION: felt252 = 'Invalid duration';
    const LEASE_ALREADY_ACTIVE: felt252 = 'Lease already active';
    const NO_ACTIVE_LEASE: felt252 = 'No active lease';
    const LEASE_EXPIRED: felt252 = 'Lease expired';
    const NOT_LESSEE: felt252 = 'Not lessee';
    const NO_ACTIVE_OFFER: felt252 = 'No active offer';
    const INSUFFICIENT_PAYMENT: felt252 = 'Insufficient payment';
    const LEASE_NOT_EXPIRED: felt252 = 'Lease not expired';

    // Constructor
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, uri: ByteArray) {
        self.ownable.initializer(owner);
        self.erc1155.initializer(uri);
    }

    // External Functions
    #[abi(embed_v0)]
    impl IPLeasingImpl of IIPLeasing<ContractState> {
        fn create_lease_offer(
            ref self: ContractState,
            token_id: u256,
            amount: u256,
            lease_fee: u256,
            duration: u64,
            license_terms_uri: ByteArray,
        ) {
            let caller = get_caller_address();
            assert(self.erc1155.balance_of(caller, token_id) >= amount, NOT_TOKEN_OWNER);
            assert(amount > 0, INSUFFICIENT_AMOUNT);
            assert(lease_fee > 0, INVALID_LEASE_FEE);
            assert(duration > 0, INVALID_DURATION);
            assert(!self.leases.read(token_id).is_active, LEASE_ALREADY_ACTIVE);
            assert(self.erc1155.balance_of(caller, token_id) >= amount, 'Not token owner');

            let terms_uri_clone = license_terms_uri.clone();
            let offer = LeaseOffer {
                owner: caller,
                amount,
                lease_fee,
                duration,
                license_terms_uri: terms_uri_clone,
                is_active: true,
            };
            self.lease_offers.write(token_id, offer);

            // Escrow the IP tokens
            self
                .erc1155
                .safe_transfer_from(
                    from: caller,
                    to: self.get_contract_address(),
                    token_id: token_id,
                    value: amount,
                    data: array![].span(),
                );

            // Index the lease offer
            let lease_count = self.lease_count_by_owner.read(caller);
            self.active_leases_by_owner.write((caller, lease_count), token_id);
            self.lease_count_by_owner.write(caller, lease_count + 1);

            self
                .emit(
                    LeaseOfferCreated {
                        token_id, owner: caller, amount, lease_fee, duration, license_terms_uri,
                    },
                );
        }

        fn cancel_lease_offer(ref self: ContractState, token_id: u256) {
            let caller = get_caller_address();
            let offer = self.lease_offers.read(token_id);
            assert(offer.is_active, NO_ACTIVE_OFFER);
            assert(offer.owner == caller, NOT_TOKEN_OWNER);

            // Mark offer as inactive
            self
                .lease_offers
                .write(
                    token_id,
                    LeaseOffer {
                        owner: offer.owner,
                        amount: offer.amount,
                        lease_fee: offer.lease_fee,
                        duration: offer.duration,
                        license_terms_uri: offer.license_terms_uri,
                        is_active: false,
                    },
                );

            // Return escrowed tokens
            self
                .erc1155
                .safe_transfer_from(
                    from: self.get_contract_address(),
                    to: caller,
                    token_id: token_id,
                    value: offer.amount,
                    data: array![].span(),
                );

            self.emit(LeaseOfferCancelled { token_id, owner: caller });
        }

        fn start_lease(ref self: ContractState, token_id: u256) {
            let caller = get_caller_address();
            let offer = self.lease_offers.read(token_id);
            assert(offer.is_active, NO_ACTIVE_OFFER);
            assert(!self.leases.read(token_id).is_active, LEASE_ALREADY_ACTIVE);

            let start_time = get_block_timestamp();
            let end_time = start_time + offer.duration;

            // Create lease
            let lease = Lease {
                lessee: caller, amount: offer.amount, start_time, end_time, is_active: true,
            };
            self.leases.write(token_id, lease);

            // Transfer tokens to lessee
            self
                .erc1155
                .safe_transfer_from(
                    from: self.get_contract_address(),
                    to: caller,
                    token_id: token_id,
                    value: offer.amount,
                    data: array![].span(),
                );

            // Mark offer as inactive
            self
                .lease_offers
                .write(
                    token_id,
                    LeaseOffer {
                        owner: offer.owner,
                        amount: offer.amount,
                        lease_fee: offer.lease_fee,
                        duration: offer.duration,
                        license_terms_uri: offer.license_terms_uri,
                        is_active: false,
                    },
                );

            // Index the lease
            let lease_count = self.lease_count_by_lessee.read(caller);
            self.active_leases_by_lessee.write((caller, lease_count), token_id);
            self.lease_count_by_lessee.write(caller, lease_count + 1);

            self
                .emit(
                    LeaseStarted {
                        token_id, lessee: caller, amount: offer.amount, start_time, end_time,
                    },
                );
        }

        fn renew_lease(ref self: ContractState, token_id: u256, additional_duration: u64) {
            let caller = get_caller_address();
            let mut lease = self.leases.read(token_id);
            assert(lease.is_active, NO_ACTIVE_LEASE);
            assert(lease.lessee == caller, NOT_LESSEE);
            assert(get_block_timestamp() <= lease.end_time, LEASE_EXPIRED);
            assert(additional_duration > 0, INVALID_DURATION);

            lease.end_time += additional_duration;
            self.leases.write(token_id, lease);

            self.emit(LeaseRenewed { token_id, lessee: caller, new_end_time: lease.end_time });
        }

        fn expire_lease(ref self: ContractState, token_id: u256) {
            let lease = self.leases.read(token_id);
            assert(lease.is_active, NO_ACTIVE_LEASE);
            assert(get_block_timestamp() > lease.end_time, LEASE_NOT_EXPIRED);

            let offer = self.lease_offers.read(token_id);
            let _owner = offer.owner;

            // Revert tokens to owner
            self
                .erc1155
                .safe_transfer_from(
                    from: lease.lessee,
                    to: offer.owner,
                    token_id: token_id,
                    value: lease.amount,
                    data: array![].span(),
                );
            // Mark lease as inactive
            self
                .leases
                .write(
                    token_id,
                    Lease {
                        lessee: lease.lessee,
                        amount: lease.amount,
                        start_time: lease.start_time,
                        end_time: lease.end_time,
                        is_active: false,
                    },
                );

            self.emit(LeaseExpired { token_id, lessee: lease.lessee });
        }

        fn terminate_lease(ref self: ContractState, token_id: u256, reason: ByteArray) {
            let caller = get_caller_address();
            let lease = self.leases.read(token_id);
            assert(lease.is_active, NO_ACTIVE_LEASE);
            let offer = self.lease_offers.read(token_id);
            assert(offer.owner == caller, NOT_TOKEN_OWNER);

            // Revert tokens to owner
            self
                .erc1155
                .safe_transfer_from(
                    from: lease.lessee,
                    to: caller,
                    token_id: token_id,
                    value: lease.amount,
                    data: array![].span(),
                );

            // Mark lease as inactive
            self
                .leases
                .write(
                    token_id,
                    Lease {
                        lessee: lease.lessee,
                        amount: lease.amount,
                        start_time: lease.start_time,
                        end_time: lease.end_time,
                        is_active: false,
                    },
                );

            self.emit(LeaseTerminated { token_id, lessee: lease.lessee, reason });
        }

        fn mint_ip(ref self: ContractState, to: ContractAddress, token_id: u256, amount: u256) {
            self.ownable.assert_only_owner();
            assert(amount > 0, INSUFFICIENT_AMOUNT);
            self
                .erc1155
                .batch_mint_with_acceptance_check(
                    to, array![token_id].span(), array![amount].span(), array![].span(),
                );
        }

        fn get_lease(self: @ContractState, token_id: u256) -> Lease {
            self.leases.read(token_id)
        }

        fn get_lease_offer(self: @ContractState, token_id: u256) -> LeaseOffer {
            self.lease_offers.read(token_id)
        }

        fn get_active_leases_by_owner(self: @ContractState, owner: ContractAddress) -> Array<u256> {
            let mut leases = array![];
            let count = self.lease_count_by_owner.read(owner);
            let mut i: u256 = 0;
            while i < count {
                let token_id = self.active_leases_by_owner.read((owner, i));
                if self.leases.read(token_id).is_active {
                    leases.append(token_id);
                }
                i += 1;
            };
            leases
        }

        fn get_active_leases_by_lessee(
            self: @ContractState, lessee: ContractAddress,
        ) -> Array<u256> {
            let mut leases = array![];
            let count = self.lease_count_by_lessee.read(lessee);
            let mut i: u256 = 0;
            while i < count {
                let token_id = self.active_leases_by_lessee.read((lessee, i));
                if self.leases.read(token_id).is_active {
                    leases.append(token_id);
                }
                i += 1;
            };
            leases
        }
    }

    // Internal Functions
    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_contract_address(self: @ContractState) -> ContractAddress {
            starknet::get_contract_address()
        }
    }
}
