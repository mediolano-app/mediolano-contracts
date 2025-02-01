use starknet::{ContractAddress, get_caller_address, get_contract_address};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};

// Define the Listing struct first before using it in the interface
#[derive(Drop, Serde, starknet::Store)]
pub struct Listing {
    seller: ContractAddress,
    price: u256,
    currency: ContractAddress,
    active: bool
}

#[starknet::interface]
pub trait IIPMarketplace<TContractState> {
    fn list_item(
        ref self: TContractState,
        token_id: u256,
        price: u256,
        currency_address: ContractAddress
    );
    fn unlist_item(ref self: TContractState, token_id: u256);
    fn buy_item(ref self: TContractState, token_id: u256);
    fn update_listing(ref self: TContractState, token_id: u256, new_price: u256);
    fn get_listing(self: @TContractState, token_id: u256) -> Listing;
}

#[starknet::contract]
mod IPMarketplace {
    use super::{ContractAddress, get_caller_address, get_contract_address, Listing};
    use super::{IERC20Dispatcher, IERC20DispatcherTrait, IERC721Dispatcher, IERC721DispatcherTrait};

    #[storage]
    struct Storage {
        listings: starknet::storage::Map<u256, Listing>,
        nft_contract: ContractAddress,
        owner: ContractAddress,
        marketplace_fee: u256, // in basis points (e.g., 250 = 2.5%)
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ItemListed: ItemListed,
        ItemUnlisted: ItemUnlisted,
        ItemSold: ItemSold,
        ListingUpdated: ListingUpdated
    }

    #[derive(Drop, starknet::Event)]
    struct ItemListed {
        #[key]
        token_id: u256,
        seller: ContractAddress,
        price: u256,
        currency: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct ItemUnlisted {
        #[key]
        token_id: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ItemSold {
        #[key]
        token_id: u256,
        seller: ContractAddress,
        buyer: ContractAddress,
        price: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ListingUpdated {
        #[key]
        token_id: u256,
        new_price: u256
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        nft_contract_address: ContractAddress,
        marketplace_fee: u256
    ) {
        self.nft_contract.write(nft_contract_address);
        self.owner.write(get_caller_address());
        self.marketplace_fee.write(marketplace_fee);
    }

    #[abi(embed_v0)]
    impl IPMarketplace of super::IIPMarketplace<ContractState> {
        fn list_item(
            ref self: ContractState,
            token_id: u256,
            price: u256,
            currency_address: ContractAddress
        ) {
            let caller = get_caller_address();
            let nft_contract = IERC721Dispatcher { contract_address: self.nft_contract.read() };
            
            // Verify ownership
            assert(nft_contract.owner_of(token_id) == caller, 'Not token owner');
            
            // Verify approval
            assert(
                nft_contract.get_approved(token_id) == get_contract_address() 
                || nft_contract.is_approved_for_all(caller, get_contract_address()),
                'Not approved for marketplace'
            );

            // Create listing
            let listing = Listing {
                seller: caller,
                price,
                currency: currency_address,
                active: true
            };
            self.listings.write(token_id, listing);

            // Emit event
            self.emit(Event::ItemListed(ItemListed { 
                token_id, 
                seller: caller, 
                price, 
                currency: currency_address 
            }));
        }

        fn unlist_item(ref self: ContractState, token_id: u256) {
            let caller = get_caller_address();
            let listing = self.listings.read(token_id);
            
            assert(listing.active, 'Listing not active');
            assert(listing.seller == caller, 'Not the seller');

            // Deactivate listing
            self.listings.write(
                token_id,
                Listing { active: false, ..listing }
            );

            self.emit(Event::ItemUnlisted(ItemUnlisted { token_id }));
        }

        fn buy_item(ref self: ContractState, token_id: u256) {
            let caller = get_caller_address();
            let listing = self.listings.read(token_id);
            
            assert(listing.active, 'Listing not active');
            assert(caller != listing.seller, 'Seller cannot buy');

            // Handle payment
            let currency = IERC20Dispatcher { contract_address: listing.currency };
            let fee = (listing.price * self.marketplace_fee.read()) / 10000;
            let seller_amount = listing.price - fee;

            // Transfer payment to seller
            currency.transfer_from(caller, listing.seller, seller_amount);
            // Transfer fee to marketplace owner
            currency.transfer_from(caller, self.owner.read(), fee);

            // Transfer NFT to buyer
            let nft_contract = IERC721Dispatcher { contract_address: self.nft_contract.read() };
            nft_contract.transfer_from(listing.seller, caller, token_id);

            // Deactivate listing
            self.listings.write(
                token_id,
                Listing { active: false, ..listing }
            );

            self.emit(Event::ItemSold(ItemSold {
                token_id,
                seller: listing.seller,
                buyer: caller,
                price: listing.price
            }));
        }

        fn update_listing(ref self: ContractState, token_id: u256, new_price: u256) {
            let caller = get_caller_address();
            let listing = self.listings.read(token_id);
            
            assert(listing.active, 'Listing not active');
            assert(listing.seller == caller, 'Not the seller');

            // Update listing price
            self.listings.write(
                token_id,
                Listing { price: new_price, ..listing }
            );

            self.emit(Event::ListingUpdated(ListingUpdated { token_id, new_price }));
        }

        fn get_listing(self: @ContractState, token_id: u256) -> Listing {
            self.listings.read(token_id)
        }
    }
}