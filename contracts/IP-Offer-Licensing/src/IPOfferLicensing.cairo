#[starknet::contract]
pub mod IPOfferLicensing {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin::token::erc721::ERC721Component;
    use core::array::ArrayTrait;
    use core::byte_array::ByteArray;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };

    use crate::interfaces::{IIPOfferLicensing, Offer, OfferStatus};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Add ERC721HooksTrait implementation
    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {}

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {}
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,

        // Offer Management
        offers: Map<u256, Offer>,
        offer_count: u256,
        
        // IP Token Management
        ip_token_contract: ContractAddress,
        
        // Offer Indexing
        ip_offers: Map<(u256, u256), u256>, // (ip_token_id, index) -> offer_id
        ip_offers_count: Map<u256, u256>,   // ip_token_id -> count
        
        creator_offers: Map<(ContractAddress, u256), u256>, // (creator, index) -> offer_id
        creator_offers_count: Map<ContractAddress, u256>,   // creator -> count
        
        owner_offers: Map<(ContractAddress, u256), u256>,   // (owner, index) -> offer_id
        owner_offers_count: Map<ContractAddress, u256>,     // owner -> count
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        OfferCreated: OfferCreated,
        OfferAccepted: OfferAccepted,
        OfferRejected: OfferRejected,
        OfferCancelled: OfferCancelled,
        RefundClaimed: RefundClaimed
    }

    #[derive(Drop, starknet::Event)]
    struct OfferCreated {
        #[key]
        offer_id: u256,
        ip_token_id: u256,
        creator: ContractAddress,
        owner: ContractAddress,
        payment_amount: u256,
        payment_token: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct OfferAccepted {
        #[key]
        offer_id: u256,
        ip_token_id: u256,
        creator: ContractAddress,
        owner: ContractAddress,
        payment_amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct OfferRejected {
        #[key]
        offer_id: u256,
        ip_token_id: u256,
        creator: ContractAddress,
        owner: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct OfferCancelled {
        #[key]
        offer_id: u256,
        ip_token_id: u256,
        creator: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct RefundClaimed {
        #[key]
        offer_id: u256,
        ip_token_id: u256,
        creator: ContractAddress,
        amount: u256
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        ip_token_contract: ContractAddress
    ) {
        self.ownable.initializer(owner);
        self.ip_token_contract.write(ip_token_contract);
        self.offer_count.write(0);
    }

    #[abi(embed_v0)]
    impl IPOfferLicensingImpl of IIPOfferLicensing<ContractState> {
        fn create_offer(
            ref self: ContractState,
            ip_token_id: u256,
            payment_amount: u256,
            payment_token: ContractAddress,
            license_terms: ByteArray
        ) -> u256 {
            // Validate IP token ownership
            let ip_contract = IERC721Dispatcher { contract_address: self.ip_token_contract.read() };
            let owner = ip_contract.owner_of(ip_token_id);
            assert(owner == get_caller_address(), 'Not IP owner');

            // Create new offer
            let offer_id = self.offer_count.read();
            self.offer_count.write(offer_id + 1);

            let offer = Offer {
                id: offer_id,
                ip_token_id,
                creator: get_caller_address(),
                owner,
                payment_amount,
                payment_token,
                license_terms,
                status: OfferStatus::Active,
                created_at: get_block_timestamp(),
                updated_at: get_block_timestamp()
            };

            // Store offer
            self.offers.write(offer_id, offer);

            // Index offer
            let ip_count = self.ip_offers_count.read(ip_token_id);
            self.ip_offers.write((ip_token_id, ip_count), offer_id);
            self.ip_offers_count.write(ip_token_id, ip_count + 1);

            let creator_count = self.creator_offers_count.read(get_caller_address());
            self.creator_offers.write((get_caller_address(), creator_count), offer_id);
            self.creator_offers_count.write(get_caller_address(), creator_count + 1);

            let owner_count = self.owner_offers_count.read(owner);
            self.owner_offers.write((owner, owner_count), offer_id);
            self.owner_offers_count.write(owner, owner_count + 1);

            // Emit event
            self.emit(OfferCreated {
                offer_id,
                ip_token_id,
                creator: get_caller_address(),
                owner,
                payment_amount,
                payment_token
            });

            offer_id
        }

        fn accept_offer(ref self: ContractState, offer_id: u256) {
            let mut offer = self.offers.read(offer_id);
            assert(offer.status == OfferStatus::Active, 'Offer not active');
            assert(offer.owner == get_caller_address(), 'Not IP owner');

            // Transfer payment
            let erc20: IERC20Dispatcher = IERC20Dispatcher { contract_address: offer.payment_token };
            erc20.transfer_from(offer.creator, offer.owner, offer.payment_amount);

            // Clone before writing
            let offer_for_event = offer.clone();

            // Update offer status
            offer.status = OfferStatus::Accepted;
            offer.updated_at = get_block_timestamp();
            self.offers.write(offer_id, offer);

            // Emit event
            self.emit(OfferAccepted {
                offer_id,
                ip_token_id: offer_for_event.ip_token_id,
                creator: offer_for_event.creator,
                owner: offer_for_event.owner,
                payment_amount: offer_for_event.payment_amount
            });
        }

        fn reject_offer(ref self: ContractState, offer_id: u256) {
            let mut offer = self.offers.read(offer_id);
            assert(offer.status == OfferStatus::Active, 'Offer not active');
            assert(offer.owner == get_caller_address(), 'Not IP owner');

            // Transfer payment
            let erc20: IERC20Dispatcher = IERC20Dispatcher { contract_address: offer.payment_token };
            erc20.transfer_from(offer.creator, offer.owner, offer.payment_amount);

            // Clone before writing
            let offer_for_event = offer.clone();

            // Update offer status
            offer.status = OfferStatus::Rejected;
            offer.updated_at = get_block_timestamp();
            self.offers.write(offer_id, offer);

            // Emit event
            self.emit(OfferRejected {
                offer_id,
                ip_token_id: offer_for_event.ip_token_id,
                creator: offer_for_event.creator,
                owner: offer_for_event.owner
            });
        }

        fn cancel_offer(ref self: ContractState, offer_id: u256) {
            let mut offer = self.offers.read(offer_id);
            assert(offer.status == OfferStatus::Active, 'Offer not active');
            assert(offer.creator == get_caller_address(), 'Not offer creator');

            // Transfer payment
            let erc20: IERC20Dispatcher = IERC20Dispatcher { contract_address: offer.payment_token };
            erc20.transfer_from(offer.creator, offer.owner, offer.payment_amount);

            // Clone before writing
            let offer_for_event = offer.clone();

            // Update offer status
            offer.status = OfferStatus::Cancelled;
            offer.updated_at = get_block_timestamp();
            self.offers.write(offer_id, offer);

            // Emit event
            self.emit(OfferCancelled {
                offer_id,
                ip_token_id: offer_for_event.ip_token_id,
                creator: offer_for_event.creator
            });
        }

        fn claim_refund(ref self: ContractState, offer_id: u256) {
            let offer = self.offers.read(offer_id);
            assert(offer.status == OfferStatus::Rejected || offer.status == OfferStatus::Cancelled, 'Offer not refundable');
            assert(offer.creator == get_caller_address(), 'Not offer creator');

            // Transfer payment back to creator
            let erc20: IERC20Dispatcher = IERC20Dispatcher { contract_address: offer.payment_token };
            erc20.transfer(offer.creator, offer.payment_amount);

            // Emit event
            self.emit(RefundClaimed {
                offer_id,
                ip_token_id: offer.ip_token_id,
                creator: offer.creator,
                amount: offer.payment_amount
            });
        }

        fn get_offer(self: @ContractState, offer_id: u256) -> Offer {
            self.offers.read(offer_id)
        }

        fn get_offers_by_ip(self: @ContractState, ip_token_id: u256) -> Array<u256> {
            let count = self.ip_offers_count.read(ip_token_id);
            let mut offers = ArrayTrait::new();
            
            let mut i: u256 = 0;
            loop {
                if i >= count {
                    break;
                }
                offers.append(self.ip_offers.read((ip_token_id, i)));
                i += 1;
            };
            
            offers
        }

        fn get_offers_by_creator(self: @ContractState, creator: ContractAddress) -> Array<u256> {
            let count = self.creator_offers_count.read(creator);
            let mut offers = ArrayTrait::new();
            
            let mut i: u256 = 0;
            loop {
                if i >= count {
                    break;
                }
                offers.append(self.creator_offers.read((creator, i)));
                i += 1;
            };
            
            offers
        }

        fn get_offers_by_owner(self: @ContractState, owner: ContractAddress) -> Array<u256> {
            let count = self.owner_offers_count.read(owner);
            let mut offers = ArrayTrait::new();
            
            let mut i: u256 = 0;
            loop {
                if i >= count {
                    break;
                }
                offers.append(self.owner_offers.read((owner, i)));
                i += 1;
            };
            
            offers
        }
    }
} 