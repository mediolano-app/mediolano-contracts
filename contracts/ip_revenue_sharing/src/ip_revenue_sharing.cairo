use starknet::{ContractAddress, get_caller_address, get_contract_address};
use core::array::ArrayTrait;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};

#[starknet::interface]
trait IPRevenueSharing<TContractState> {
    fn create_and_list_item(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        price: u256,
        currency_address: ContractAddress,
        metadata_hash: felt252,
        license_terms_hash: felt252,
        total_shares: u256
    );

    fn transfer_fractional_shares(
        ref self: TContractState,
        token_id: u256,
        to: ContractAddress,
        amount: u256
    );

    fn claim_royalty( ref self: TContractState, token_id: u256);

    fn distribute_sale_revenue(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256
    );

    fn remove_listing(
        ref self: TContractState,

        nft_contract: ContractAddress,
        token_id: u256
    );
}

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
    pub total_shares: u256,
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
    pub fractional: FractionalOwnership,
}

#[derive(Drop, starknet::Event)]
pub struct RoyaltyClaimed {
    #[key]
    pub token_id: u256,
    pub owner: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct FractionalSharesTransferred {
    #[key]
    pub token_id: u256,
    pub from: ContractAddress,
    pub to: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct RevenueDistributed {
    #[key]
    pub token_id: u256,
    pub total_revenue: u256,
}

#[starknet::contract]
mod IPRevenueSharingMarketplace {
    use super::*;
    
    #[storage]
    struct Storage {
        listings: starknet::storage::Map<(ContractAddress, u256), Listing>,
        fractional_shares: starknet::storage::Map<(u256, ContractAddress), u256>,
        pending_revenue: starknet::storage::Map<(u256, ContractAddress), u256>,
        contract_balance: starknet::storage::Map<ContractAddress, u256>,
        owner: ContractAddress,
        marketplace_fee: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, marketplace_fee: u256) {
        self.owner.write(get_caller_address());
        self.marketplace_fee.write(marketplace_fee);
    }

    #[abi(embed_v0)]
    impl IPRevenueSharingImpl of IPRevenueSharing<ContractState> for ContractState {
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
            assert(total_shares > 0, 'Total shares must be greater than zero');
            assert(price > 0, 'Price must be greater than zero');
            
            let caller = get_caller_address();
            let nft_dispatcher = IERC721Dispatcher { contract_address: nft_contract };
            assert(nft_dispatcher.owner_of(token_id) == caller, 'Not token owner');
            assert(nft_dispatcher.get_approved(token_id) == get_contract_address()
                || nft_dispatcher.is_approved_for_all(caller, get_contract_address()), 'Not approved for marketplace');
            
            let metadata = IPMetadata {
                ipfs_hash: metadata_hash,
                license_terms: license_terms_hash,
                creator: caller,
                creation_date: starknet::get_block_timestamp(),
                last_updated: starknet::get_block_timestamp(),
                version: 1,
            };
            let fractional = FractionalOwnership { total_shares, accrued_revenue: 0 };
            
            self.listings.write((nft_contract, token_id), Listing {
                seller: caller, nft_contract, price, currency: currency_address, active: true, metadata, fractional
            });
            
            self.fractional_shares.write((token_id, caller), total_shares);
        }

        fn transfer_fractional_shares(
            ref self: ContractState,
            token_id: u256,
            to: ContractAddress,
            amount: u256
        ) {
            assert(amount > 0, 'Amount must be greater than zero');
            let caller = get_caller_address();
            let balance = self.fractional_shares.read((token_id, caller));
            assert(balance >= amount, 'Insufficient shares');
            
            self.fractional_shares.write((token_id, caller), balance - amount);
            let receiver_balance = self.fractional_shares.read((token_id, to));
            self.fractional_shares.write((token_id, to), receiver_balance + amount);
            
            self.emit(FractionalSharesTransferred { token_id, from: caller, to, amount });
        }

        fn claim_royalty(ref self: ContractState, token_id: u256) {
            let caller = get_caller_address();
            let shares = self.fractional_shares.read((token_id, caller));
            assert(shares > 0, 'No shares held');
            
            let listing = self.listings.read((get_contract_address(), token_id));
            let total_shares = listing.fractional.total_shares;
            let claimable = (listing.fractional.accrued_revenue * shares) / total_shares;
            
            let currency = IERC20Dispatcher { contract_address: listing.currency };
            let contract_balance = self.contract_balance.read(listing.currency);
            assert(contract_balance >= claimable, 'Insufficient contract balance');
            
            self.contract_balance.write(listing.currency, contract_balance - claimable);
            currency.transfer_from(get_contract_address(), caller, claimable);
            
            self.emit(RoyaltyClaimed { token_id, owner: caller, amount: claimable });
        }

        fn distribute_sale_revenue(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256
        ) {
            let listing = self.listings.read((nft_contract, token_id));
            let total_revenue = listing.price - ((listing.price * self.marketplace_fee.read()) / 10000);
            let currency = IERC20Dispatcher { contract_address: listing.currency };
            
            let contract_balance = self.contract_balance.read(listing.currency);
            self.contract_balance.write(listing.currency, contract_balance + total_revenue);
            
            let total_shares = listing.fractional.total_shares;
            let owners = self.fractional_shares.keys(); // Fetch all owners (not supported directly, may need indexing)
            
            for owner in owners {
                let shares = self.fractional_shares.read((token_id, owner));
                let owner_revenue = (total_revenue * shares) / total_shares;
                let pending = self.pending_revenue.read((token_id, owner));
                self.pending_revenue.write((token_id, owner), pending + owner_revenue);
            }
            
            self.emit(RevenueDistributed { token_id, total_revenue });
        }

      

        fn remove_listing(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256
        ) {
            let caller = get_caller_address();
            let listing = self.listings.read((nft_contract, token_id));
            assert(listing.seller == caller, 'Only seller can deactivate listing');
            
            listing.active = false;
            self.listings.write((nft_contract, token_id), listing);
        }
    }
}