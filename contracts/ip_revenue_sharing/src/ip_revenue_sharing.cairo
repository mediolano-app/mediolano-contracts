use starknet::ContractAddress;

#[starknet::interface]
pub trait IIPRevenueSharing<TContractState> {
    fn create_ip_asset(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        metadata_hash: felt252,
        license_terms_hash: felt252,
        total_shares: u256,
    );


    fn list_ip_asset(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        price: u256,
        currency_address: ContractAddress,
    );

    fn remove_listing(ref self: TContractState, nft_contract: ContractAddress, token_id: u256);

    fn claim_royalty(ref self: TContractState, token_id: u256);

    fn distribute_sale_revenue(
        ref self: TContractState, nft_contract: ContractAddress, token_id: u256,
    );
    fn add_fractional_owner(ref self: TContractState, token_id: u256, owner: ContractAddress);

    fn get_fractional_owners(self: @TContractState, token_id: u256) -> Array<ContractAddress>;

    fn update_fractional_shares(
        ref self: TContractState, token_id: u256, owner: ContractAddress, new_shares: u256,
    );
    fn get_fractional_shares(self: @TContractState, token_id: u256, owner: ContractAddress) -> u256;
}


#[starknet::contract]
pub mod IPRevenueSharing {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use core::array::ArrayTrait;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use super::*;

    #[storage]
    struct Storage {
        listings: Map<(ContractAddress, u256), Listing>,
        fractional_shares: Map<(u256, ContractAddress), u256>,
        pending_revenue: Map<(u256, ContractAddress), u256>,
        contract_balance: Map<ContractAddress, u256>,
        owner: ContractAddress,
        fractional_owners: Map<u256, Array<ContractAddress>>,
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
        pub token_id: u256,
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
    pub struct RevenueDistributed {
        #[key]
        pub token_id: u256,
        pub total_revenue: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        RoyaltyClaimed: RoyaltyClaimed,
        RevenueDistributed: RevenueDistributed,
    }


    #[constructor]
    fn constructor(ref self: ContractState, marketplace_fee: u256) {
        self.owner.write(get_caller_address());
    }

    #[abi(embed_v0)]
    impl IIPRevenueSharing of super::IIPRevenueSharing<ContractState> {
        fn create_ip_asset(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            metadata_hash: felt252,
            license_terms_hash: felt252,
            total_shares: u256,
        ) {
            assert(total_shares > 0, 'SharesMustbeGreaterThanZero');

            let caller = get_caller_address();
            let nft_dispatcher = IERC721Dispatcher { contract_address: nft_contract };
            assert(nft_dispatcher.owner_of(token_id) == caller, 'Not Token Owner');

            let metadata = IPMetadata {
                ipfs_hash: metadata_hash,
                license_terms: license_terms_hash,
                creator: caller,
                creation_date: starknet::get_block_timestamp(),
                last_updated: starknet::get_block_timestamp(),
                version: 1,
            };
            let fractional = FractionalOwnership { total_shares, accrued_revenue: 0 };

            self
                .listings
                .write(
                    (nft_contract, token_id),
                    Listing {
                        seller: caller,
                        nft_contract,
                        token_id,
                        price: 0,
                        currency: get_contract_address(),
                        active: false,
                        metadata,
                        fractional,
                    },
                );

            self.fractional_shares.write((token_id, caller), total_shares);
        }

        fn list_ip_asset(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            price: u256,
            currency_address: ContractAddress,
        ) {
            assert(price > 0, 'Price must be greater than zero');

            let caller = get_caller_address();
            let nft_dispatcher = IERC721Dispatcher { contract_address: nft_contract };
            assert(nft_dispatcher.owner_of(token_id) == caller, 'Not token owner');
            assert(
                nft_dispatcher.get_approved(token_id) == get_contract_address()
                    || nft_dispatcher.is_approved_for_all(caller, get_contract_address()),
                'Not approved for marketplace',
            );

            let mut listing = self.listings.read((nft_contract, token_id));
            listing.price = price;
            listing.currency = currency_address;
            listing.active = true;
            self.listings.write((nft_contract, token_id), listing);
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
            ref self: ContractState, nft_contract: ContractAddress, token_id: u256,
        ) {
            // Validate that the listing exists
            let listing = self.listings.read((nft_contract, token_id));
            assert(listing.active, 'Listing is not active');

            // Validate that the total shares are greater than zero
            let total_shares = listing.fractional.total_shares;
            assert(total_shares > 0, 'Shares must be > than zero');

            // Calculate total revenue (after deducting marketplace fee)
            let total_revenue = listing.price;
            let currency = IERC20Dispatcher { contract_address: listing.currency };

            // Distribute revenue to fractional owners
            // Instead of using `keys()`, track owners explicitly (e.g., using an array or mapping)
            let owners = self.get_fractional_owners(token_id); // Assume this function exists
            for owner in owners {
                let shares = self.fractional_shares.read((token_id, owner));
                let owner_revenue = (total_revenue * shares) / total_shares;

                // Transfer funds to the owner (automatic distribution)
                currency.transfer_from(get_contract_address(), owner, owner_revenue);

                // Emit an event for transparency
                self.emit(RoyaltyClaimed { token_id, owner, amount: owner_revenue });
            };

            // Emit an event for revenue distribution
            self.emit(RevenueDistributed { token_id, total_revenue });
        }

        fn remove_listing(ref self: ContractState, nft_contract: ContractAddress, token_id: u256) {
            let caller = get_caller_address();
            let mut listing = self.listings.read((nft_contract, token_id));
            assert(listing.seller == caller, 'Only seller');

            listing.active = false;
            self.listings.write((nft_contract, token_id), listing);
        }

        fn add_fractional_owner(ref self: ContractState, token_id: u256, owner: ContractAddress) {
            let mut owners = self.fractional_owners.entry(token_id).read();
            owners.append(owner);
            self.fractional_owners.entry(token_id).write(owners);
        }

        fn get_fractional_owners(self: @ContractState, token_id: u256) -> Array<ContractAddress> {
            self.fractional_owners.entry(token_id).read()
        }

        fn update_fractional_shares(
            ref self: ContractState, token_id: u256, owner: ContractAddress, new_shares: u256,
        ) {
            self.fractional_shares.entry((token_id, owner)).write(new_shares);
        }

        fn get_fractional_shares(
            self: @ContractState, token_id: u256, owner: ContractAddress,
        ) -> u256 {
            self.fractional_shares.entry((token_id, owner)).read()
        }
    }
}
