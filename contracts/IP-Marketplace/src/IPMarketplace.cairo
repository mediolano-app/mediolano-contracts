use core::array::ArrayTrait;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use starknet::{ContractAddress, get_caller_address, get_contract_address};

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct IPUsageRights {
    pub commercial_use: bool,
    pub modifications_allowed: bool,
    pub attribution_required: bool,
    pub geographic_restrictions: felt252,
    pub usage_duration: u64,
    pub sublicensing_allowed: bool,
    pub industry_restrictions: felt252,
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct DerivativeRights {
    pub allowed: bool,
    pub royalty_share: u16,
    pub requires_approval: bool,
    pub max_derivatives: u32
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct IPMetadata {
    pub ipfs_hash: felt252,
    pub license_terms: felt252,
    pub creator: ContractAddress,
    pub creation_date: u64,
    pub last_updated: u64,
    pub version: u32,
    pub content_type: felt252,
    pub derivative_of: u256,
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct Listing {
    pub seller: ContractAddress,
    pub nft_contract: ContractAddress,
    pub price: u256,
    pub currency: ContractAddress,
    pub active: bool,
    pub metadata: IPMetadata,
    pub royalty_percentage: u16,
    pub usage_rights: IPUsageRights,
    pub derivative_rights: DerivativeRights,
    pub minimum_purchase_duration: u64,
    pub bulk_discount_rate: u16,
}

#[derive(Drop, starknet::Event)]
pub struct ItemListed {
    #[key]
    pub token_id: u256,
    pub nft_contract: ContractAddress,
    pub seller: ContractAddress,
    pub price: u256,
    pub currency: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ItemUnlisted {
    #[key]
    pub token_id: u256,
    pub nft_contract: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ItemSold {
    #[key]
    pub token_id: u256,
    pub nft_contract: ContractAddress,
    pub seller: ContractAddress,
    pub buyer: ContractAddress,
    pub price: u256,
}

#[derive(Drop, starknet::Event)]
pub struct ListingUpdated {
    #[key]
    pub token_id: u256,
    pub nft_contract: ContractAddress,
    pub new_price: u256,
}

#[derive(Drop, starknet::Event)]
pub struct MetadataUpdated {
    #[key]
    pub token_id: u256,
    pub nft_contract: ContractAddress,
    pub new_metadata_hash: felt252,
    pub new_license_terms_hash: felt252,
    pub updater: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct DerivativeRegistered {
    #[key]
    pub token_id: u256,
    pub nft_contract: ContractAddress,
    pub parent_token_id: u256,
    pub creator: ContractAddress,
}


#[starknet::interface]
pub trait IIPMarketplace<TContractState> {
    fn list_item(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        price: u256,
        currency_address: ContractAddress,
        metadata_hash: felt252,
        license_terms_hash: felt252,
        usage_rights: IPUsageRights,
        derivative_rights: DerivativeRights,
    );
    fn unlist_item(ref self: TContractState, nft_contract: ContractAddress, token_id: u256);
    fn buy_item(ref self: TContractState, nft_contract: ContractAddress, token_id: u256);
    fn update_listing(ref self: TContractState, nft_contract: ContractAddress, token_id: u256, new_price: u256);
    fn get_listing(self: @TContractState, nft_contract: ContractAddress, token_id: u256) -> Listing;
    fn update_metadata(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        new_metadata_hash: felt252,
        new_license_terms_hash: felt252,
    );
    fn register_derivative(
        ref self: TContractState,
        nft_contract: ContractAddress,
        parent_token_id: u256,
        metadata_hash: felt252,
        license_terms_hash: felt252,
    ) -> u256;
}


#[starknet::contract]
mod IPMarketplace {
    use super::{
        IPUsageRights, DerivativeRights, IPMetadata, Listing, ItemListed, ItemUnlisted, ItemSold,
        ListingUpdated, MetadataUpdated, DerivativeRegistered, IERC20Dispatcher,
        IERC20DispatcherTrait, IERC721Dispatcher, IERC721DispatcherTrait, ArrayTrait,
        ContractAddress, get_caller_address, get_contract_address
    };

    #[storage]
    struct Storage {
        // Composite key mapping combining NFT contract address and token ID
        listings: starknet::storage::Map::<(ContractAddress, u256), Listing>,
        // Tracking derivative relationships with composite keys
        derivative_registry: starknet::storage::Map::<(ContractAddress, u256), (ContractAddress, u256)>,
        owner: ContractAddress,
        marketplace_fee: u256,
        next_token_id: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ItemListed: ItemListed,
        ItemUnlisted: ItemUnlisted,
        ItemSold: ItemSold,
        ListingUpdated: ListingUpdated,
        MetadataUpdated: MetadataUpdated,
        DerivativeRegistered: DerivativeRegistered,
    }

    #[constructor]
    fn constructor(ref self: ContractState, marketplace_fee: u256) {
        self.owner.write(get_caller_address());
        self.marketplace_fee.write(marketplace_fee);
        self.next_token_id.write(0);
    }

    #[abi(embed_v0)]
    impl IPMarketplaceImpl of super::IIPMarketplace<ContractState> {
        fn list_item(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            price: u256,
            currency_address: ContractAddress,
            metadata_hash: felt252,
            license_terms_hash: felt252,
            usage_rights: IPUsageRights,
            derivative_rights: DerivativeRights,
        ) {
            let caller = get_caller_address();
            let nft_dispatcher = IERC721Dispatcher { contract_address: nft_contract };

            // Verify NFT ownership
            assert(nft_dispatcher.owner_of(token_id) == caller, 'Not token owner');

            // Verify marketplace approval
            assert(
                nft_dispatcher.get_approved(token_id) == get_contract_address()
                    || nft_dispatcher.is_approved_for_all(caller, get_contract_address()),
                'Not approved for marketplace'
            );

            // Create metadata record with timestamp and versioning
            let metadata = IPMetadata {
                ipfs_hash: metadata_hash,
                license_terms: license_terms_hash,
                creator: caller,
                creation_date: starknet::get_block_timestamp(),
                last_updated: starknet::get_block_timestamp(),
                version: 1,
                content_type: 0,
                derivative_of: 0,
            };

            // Create complete listing with all parameters
            let listing = Listing {
                seller: caller,
                nft_contract,
                price,
                currency: currency_address,
                active: true,
                metadata,
                royalty_percentage: 250, // 2.5%
                usage_rights,
                derivative_rights,
                minimum_purchase_duration: 0,
                bulk_discount_rate: 0,
            };

            // Store listing with composite key
            self.listings.write((nft_contract, token_id), listing);

            // Emit listing event
            self.emit(Event::ItemListed(ItemListed { 
                token_id,
                nft_contract,
                seller: caller,
                price,
                currency: currency_address,
            }));
        }

        fn unlist_item(ref self: ContractState, nft_contract: ContractAddress, token_id: u256) {
            let caller = get_caller_address();
            let mut listing = self.listings.read((nft_contract, token_id));

            assert(listing.active, 'Listing not active');
            assert(listing.seller == caller, 'Not the seller');

            listing.active = false;
            self.listings.write((nft_contract, token_id), listing);

            self.emit(Event::ItemUnlisted(ItemUnlisted { 
                token_id,
                nft_contract 
            }));
        }

        fn buy_item(ref self: ContractState, nft_contract: ContractAddress, token_id: u256) {
            let caller = get_caller_address();
            let listing = self.listings.read((nft_contract, token_id));

            assert(listing.active, 'Listing not active');
            assert(caller != listing.seller, 'Seller cannot buy');

            // Handle payment including marketplace fee
            let currency = IERC20Dispatcher { contract_address: listing.currency };
            let fee = (listing.price * self.marketplace_fee.read()) / 10000;
            let seller_amount = listing.price - fee;

            // Execute payments
            currency.transfer_from(caller, listing.seller, seller_amount);
            currency.transfer_from(caller, self.owner.read(), fee);

            // Transfer NFT ownership
            let nft_dispatcher = IERC721Dispatcher { contract_address: nft_contract };
            nft_dispatcher.transfer_from(listing.seller, caller, token_id);

            // Update listing status
            let mut updated_listing = listing;
            updated_listing.active = false;
            self.listings.write((nft_contract, token_id), updated_listing);

            // Emit sale event
            self.emit(Event::ItemSold(ItemSold {
                token_id,
                nft_contract,
                seller: listing.seller,
                buyer: caller,
                price: listing.price,
            }));
        }

        fn update_listing(
            ref self: ContractState, 
            nft_contract: ContractAddress,
            token_id: u256, 
            new_price: u256
        ) {
            let caller = get_caller_address();
            let mut listing = self.listings.read((nft_contract, token_id));

            assert(listing.active, 'Listing not active');
            assert(listing.seller == caller, 'Not the seller');

            listing.price = new_price;
            self.listings.write((nft_contract, token_id), listing);

            self.emit(Event::ListingUpdated(ListingUpdated { 
                token_id,
                nft_contract,
                new_price,
            }));
        }

        fn get_listing(
            self: @ContractState,
            nft_contract: ContractAddress,
            token_id: u256
        ) -> Listing {
            self.listings.read((nft_contract, token_id))
        }

        fn update_metadata(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            new_metadata_hash: felt252,
            new_license_terms_hash: felt252,
        ) {
            let caller = get_caller_address();
            let mut listing = self.listings.read((nft_contract, token_id));
            assert(listing.metadata.creator == caller, 'Not the creator');

            listing.metadata.ipfs_hash = new_metadata_hash;
            listing.metadata.license_terms = new_license_terms_hash;
            listing.metadata.last_updated = starknet::get_block_timestamp();
            listing.metadata.version += 1;

            self.listings.write((nft_contract, token_id), listing);

            self.emit(Event::MetadataUpdated(MetadataUpdated {
                token_id,
                nft_contract,
                new_metadata_hash,
                new_license_terms_hash,
                updater: caller,
            }));
        }

        fn register_derivative(
            ref self: ContractState,
            nft_contract: ContractAddress,
            parent_token_id: u256,
            metadata_hash: felt252,
            license_terms_hash: felt252,
        ) -> u256 {
            let caller = get_caller_address();
            let parent_listing = self.listings.read((nft_contract, parent_token_id));

            assert(parent_listing.derivative_rights.allowed, 'Derivatives not allowed');
            assert(parent_listing.active, 'Parent listing not active');

            let new_token_id = self.next_token_id.read() + 1;
            self.next_token_id.write(new_token_id);

            self.derivative_registry.write(
                (nft_contract, new_token_id),
                (nft_contract, parent_token_id)
            );

            self.emit(Event::DerivativeRegistered(DerivativeRegistered {
                token_id: new_token_id,
                nft_contract,
                parent_token_id,
                creator: caller,
            }));

            new_token_id
        }
    }
}
