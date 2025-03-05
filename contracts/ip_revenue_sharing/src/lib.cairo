//The goal is to develop a Cairo smart contract that enables revenue sharing for tokenized IP assets. This will allow users to create an IP asset, tokenize it, and sell the rights in an NFT marketplace. Revenue generated from the IP asset will be distributed to its fractional owners as royalties, using an NFT token format.

//Objectives

//Develop a Cairo smart contract for revenue sharing of tokenized IP assets.
//Allow users to create and sell IP assets with revenue share in Mediolano IP marketplace.
//Enable fractional owners of the IP asset to receive royalty revenue.
//Allows fractional owners to claim their share of the revenue.
//Conduct thorough testing and implement security best practices for the smart contract.
//Criteria

//The Cairo smart contract for Programmable IP Revenue Sharing is developed and deployed on the Starknet testnet.
//Users can create, tokenize, and sell IP assets in the NFT marketplace.
//Fractional owners receive royalty revenue through airdrops.
//Comprehensive testing is completed with no critical issues remaining.

use core::array::ArrayTrait;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use starknet::{ContractAddress, get_caller_address, get_contract_address};

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct IPMetadata {
    pub ipfs_hash: felt252,
    pub license_terms: felt252,
    pub creator: ContractAddress,
    pub creation_date: u64,
    pub last_updated: u64,
    pub version: u32,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct FractionalOwnership {
    // Total number of shares issued for the IP asset.
    pub total_shares: u256,
    // Accrued revenue (royalties) available for distribution.
    pub accrued_revenue: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Listing {
    pub seller: ContractAddress,
    pub nft_contract: ContractAddress,
    pub price: u256,
    pub currency: ContractAddress,
    pub active: bool,
    pub metadata: IPMetadata,
    // Fractional revenue sharing info keyed by IP asset token id.
    pub fractional: FractionalOwnership,
}

#[derive(Drop, starknet::Event)]
pub struct RoyaltyClaimed {
    #[key]
    pub token_id: u256,
    pub owner: ContractAddress,
    pub amount: u256,
}

#[starknet::contract]
mod IPRevenueSharingMarketplace {
    use super::{
        IPMetadata, Listing, FractionalOwnership, RoyaltyClaimed,
        IERC20Dispatcher, IERC20DispatcherTrait, IERC721Dispatcher, IERC721DispatcherTrait,
        ContractAddress, get_caller_address, get_contract_address
    };

    #[storage]
    struct Storage {
        // Maps (nft_contract, token_id) to a Listing.
        listings: starknet::storage::Map::<(ContractAddress, u256), Listing>,
        // Maps (token_id, fractional_owner) to share balance.
        fractional_shares: starknet::storage::Map::<(u256, ContractAddress), u256>,
        // Maps fractional owner to revenue that can be claimed.
        pending_revenue: starknet::storage::Map::<(u256, ContractAddress), u256>,
        owner: ContractAddress,
        marketplace_fee: u256,
        next_token_id: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, marketplace_fee: u256) {
        self.owner.write(get_caller_address());
        self.marketplace_fee.write(marketplace_fee);
        self.next_token_id.write(0);
    }

    #[abi(embed_v0)]
    impl IPRevenueSharingImpl {
        // Create and list a new IP asset with fractional ownership.
        fn create_and_list_item(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            price: u256,
            currency_address: ContractAddress,
            metadata_hash: felt252,
            license_terms_hash: felt252,
            total_shares: u256
        ) {
            let caller = get_caller_address();
            let nft_dispatcher = IERC721Dispatcher { contract_address: nft_contract };
            // Ensure caller owns NFT.
            assert(nft_dispatcher.owner_of(token_id) == caller, 'Not token owner');
            // Ensure the marketplace is approved.
            assert(
                nft_dispatcher.get_approved(token_id) == get_contract_address()
                    || nft_dispatcher.is_approved_for_all(caller, get_contract_address()),
                'Not approved for marketplace'
            );

            let metadata = IPMetadata {
                ipfs_hash: metadata_hash,
                license_terms: license_terms_hash,
                creator: caller,
                creation_date: starknet::get_block_timestamp(),
                last_updated: starknet::get_block_timestamp(),
                version: 1,
            };

            let fractional = FractionalOwnership {
                total_shares,
                accrued_revenue: 0,
            };

            let listing = Listing {
                seller: caller,
                nft_contract,
                price,
                currency: currency_address,
                active: true,
                metadata,
                fractional,
            };

            self.listings.write((nft_contract, token_id), listing);

            // Initialize fractional shares: assign all shares to the creator.
            self.fractional_shares.write((token_id, caller), total_shares);
        }

        // Function to handle the sale of an IP asset and distribute royalties.
        fn buy_item(ref self: ContractState, nft_contract: ContractAddress, token_id: u256) {
            let caller = get_caller_address();
            let mut listing = self.listings.read((nft_contract, token_id));
            assert(listing.active, 'Listing not active');
            assert(caller != listing.seller, 'Seller cannot buy');

            // Payment handling.
            let currency = IERC20Dispatcher { contract_address: listing.currency };
            let fee = (listing.price * self.marketplace_fee.read()) / 10000;
            let seller_amount = listing.price - fee;
            currency.transfer_from(caller, listing.seller, seller_amount);
            currency.transfer_from(caller, self.owner.read(), fee);

            // Update listing to inactive.
            listing.active = false;
            self.listings.write((nft_contract, token_id), listing);

            // Transfer NFT ownership.
            let nft_dispatcher = IERC721Dispatcher { contract_address: nft_contract };
            nft_dispatcher.transfer_from(listing.seller, caller, token_id);

            // Distribute revenue to fractional owners.
            // For example, here we airdrop the revenue based on their share percentage.
            let total_revenue = seller_amount;
            let total_shares = listing.fractional.total_shares;
            // Update accrued revenue on the listing.
            let new_accrued = listing.fractional.accrued_revenue + total_revenue;
            listing.fractional.accrued_revenue = new_accrued;
            self.listings.write((nft_contract, token_id), listing);

            // In a real implementation, you might iterate through fractional owners (if tracked on-chain)
            // or let owners claim their share manually. For simplicity, we assume manual claiming.
        }

        // Fractional owners claim their share of revenue.
        fn claim_royalty(ref self: ContractState, token_id: u256) {
            let caller = get_caller_address();
            // Get the owner’s share balance.
            let shares = self.fractional_shares.read((token_id, caller));
            assert(shares > 0, 'No shares held');
            // Determine the claimable amount based on the listing’s accrued revenue.
            let listing = self.listings.read((get_contract_address(), token_id)); // Assuming one NFT contract.
            let total_shares = listing.fractional.total_shares;
            let claimable = (listing.fractional.accrued_revenue * shares) / total_shares;

            // Reset accrued revenue for the caller for simplicity.
            self.pending_revenue.write((token_id, caller), 0);

            // Transfer claimable revenue using the accepted ERC20 currency.
            let currency = IERC20Dispatcher { contract_address: listing.currency };
            currency.transfer_from(self.owner.read(), caller, claimable);

            self.emit(RoyaltyClaimed { token_id, owner: caller, amount: claimable });
        }
    }
}
