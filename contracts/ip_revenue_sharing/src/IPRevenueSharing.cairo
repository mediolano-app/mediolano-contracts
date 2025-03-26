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
    fn claim_royalty(ref self: TContractState, nft_contract: ContractAddress, token_id: u256);
    fn record_sale_revenue(
        ref self: TContractState, nft_contract: ContractAddress, token_id: u256, amount: u256,
    );


    fn get_contract_balance(self: @TContractState, currency: ContractAddress) -> u256;


    fn add_fractional_owner(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        owner: ContractAddress
    );
    fn update_fractional_shares(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        owner: ContractAddress,
        new_shares: u256
    );
    fn get_fractional_owner(
        self: @TContractState, nft_contract: ContractAddress, token_id: u256, index: u32
    ) -> ContractAddress;
    fn get_fractional_owner_count(
        self: @TContractState, nft_contract: ContractAddress, token_id: u256
    ) -> u32;
    fn get_fractional_shares(
        self: @TContractState, nft_contract: ContractAddress, token_id: u256, owner: ContractAddress
    ) -> u256;
    fn get_claimed_revenue(
        self: @TContractState, nft_contract: ContractAddress, token_id: u256, owner: ContractAddress
    ) -> u256;
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

    #[storage]
    struct Storage {
        listings: Map<(ContractAddress, u256), Listing>,
        fractional_shares: Map<((ContractAddress, u256), ContractAddress), u256>,
        contract_balance: Map<ContractAddress, u256>,
        owner: ContractAddress,
        fractional_owner_index: Map<((ContractAddress, u256), u32), ContractAddress>,
        fractional_owner_count: Map<(ContractAddress, u256), u32>,
        claimed_revenue: Map<((ContractAddress, u256), ContractAddress), u256>,
        is_fractional_owner: Map<((ContractAddress, u256), ContractAddress), bool>,
    }

    #[derive(Drop, Serde, starknet::Store)]
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
    pub struct RevenueRecorded {
        #[key]
        pub token_id: u256,
        pub amount: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        RoyaltyClaimed: RoyaltyClaimed,
        RevenueRecorded: RevenueRecorded,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
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
                        currency: 0.try_into().unwrap(),
                        active: false,
                        metadata,
                        fractional,
                    },
                );

            self.fractional_shares.write(((nft_contract, token_id), caller), total_shares);
        }

        fn list_ip_asset(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            price: u256,
            currency_address: ContractAddress,
        ) {
            assert(price > 0, 'Price must be greater than zero');

            let mut listing = self.listings.read((nft_contract, token_id));
            assert(!listing.active, 'Listing already active');

            let caller = get_caller_address();
            let nft_dispatcher = IERC721Dispatcher { contract_address: nft_contract };
            assert(nft_dispatcher.owner_of(token_id) == caller, 'Not token owner');
            assert(
                nft_dispatcher.get_approved(token_id) == get_contract_address()
                    || nft_dispatcher.is_approved_for_all(caller, get_contract_address()),
                'Not approved for marketplace'
            );

            let mut listing = self.listings.read((nft_contract, token_id));
            listing.price = price;
            listing.currency = currency_address;
            listing.active = true;
            self.listings.write((nft_contract, token_id), listing);
        }

        fn remove_listing(ref self: ContractState, nft_contract: ContractAddress, token_id: u256) {
            let caller = get_caller_address();
            let mut listing = self.listings.read((nft_contract, token_id));
            assert(listing.seller == caller, 'Only seller');

            listing.active = false;
            self.listings.write((nft_contract, token_id), listing);
        }

        fn claim_royalty(ref self: ContractState, nft_contract: ContractAddress, token_id: u256) {
            let caller = get_caller_address();
            let shares = self.fractional_shares.read(((nft_contract, token_id), caller));
            assert(shares > 0, 'No shares held');

            let listing_key = (nft_contract, token_id);
            let listing = self.listings.read(listing_key);
            assert(listing.token_id == token_id, 'Invalid token_id');

            let total_shares = listing.fractional.total_shares;
            let total_revenue = listing.fractional.accrued_revenue;
            let currency_address = listing.currency;

            let claimed_so_far = self.claimed_revenue.read(((nft_contract, token_id), caller));
            // Note: Integer division may lose precision; consider fixed-point arithmetic later
            let claimable = (total_revenue * shares) / total_shares - claimed_so_far;
            assert(claimable > 0, 'No revenue to claim');

            let currency = IERC20Dispatcher { contract_address: currency_address };
            let actual_balance = currency.balance_of(get_contract_address());
            assert(actual_balance >= claimable, 'Insufficient balance');

            self.contract_balance.write(currency_address, actual_balance - claimable);
            self
                .claimed_revenue
                .write(((nft_contract, token_id), caller), claimed_so_far + claimable);
            currency.transfer(caller, claimable);

            self.emit(RoyaltyClaimed { token_id, owner: caller, amount: claimable });
        }


        fn record_sale_revenue(
            ref self: ContractState, nft_contract: ContractAddress, token_id: u256, amount: u256,
        ) {
            let caller = get_caller_address();
            assert(self.owner.read() == caller, 'Only owner');
            let listing_key = (nft_contract, token_id);
            let mut listing = self.listings.read(listing_key);
            assert(listing.token_id == token_id, 'Invalid token_id');

            listing.fractional.accrued_revenue = listing.fractional.accrued_revenue + amount;
            let currency_address = listing.currency;
            self.listings.write(listing_key, listing);

            let currency = IERC20Dispatcher { contract_address: currency_address };
            currency.transfer_from(caller, nft_contract, amount);
            let balance = self.contract_balance.read(currency_address);
            self.contract_balance.write(currency_address, balance + amount);

            self.emit(RevenueRecorded { token_id, amount });
        }

        fn add_fractional_owner(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            owner: ContractAddress
        ) {
            let caller = get_caller_address();
            let listing_key = (nft_contract, token_id);
            let listing = self.listings.read(listing_key);
            assert(listing.seller == caller || self.owner.read() == caller, 'Not authorized');
            assert(listing.token_id == token_id, 'Invalid token ID');

            let owner_key = ((nft_contract, token_id), owner);
            let already_exists = self.is_fractional_owner.read(owner_key);
            assert(!already_exists, 'Owner already exists');

            let count = self.fractional_owner_count.read((nft_contract, token_id));
            self.fractional_owner_index.write(((nft_contract, token_id), count), owner);
            self.fractional_owner_count.write((nft_contract, token_id), count + 1);
            self.is_fractional_owner.write(owner_key, true);
        }

        fn get_fractional_owner(
            self: @ContractState, nft_contract: ContractAddress, token_id: u256, index: u32,
        ) -> ContractAddress {
            let listing_key = (nft_contract, token_id);
            let listing = self.listings.read(listing_key);
            assert(listing.token_id == token_id, 'Invalid token_id');

            let count = self.fractional_owner_count.read((nft_contract, token_id));
            assert(index < count, 'Index out of bounds');
            self.fractional_owner_index.read(((nft_contract, token_id), index))
        }

        fn get_fractional_owner_count(
            self: @ContractState, nft_contract: ContractAddress, token_id: u256
        ) -> u32 {
            let listing_key = (nft_contract, token_id);
            let listing = self.listings.read(listing_key);
            assert(listing.token_id == token_id, 'Invalid token_id');
            self.fractional_owner_count.read((nft_contract, token_id))
        }

        fn update_fractional_shares(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            owner: ContractAddress,
            new_shares: u256,
        ) {
            let caller = get_caller_address();
            let listing_key = (nft_contract, token_id);
            let listing = self.listings.read(listing_key);
            assert(listing.seller == caller || self.owner.read() == caller, 'Not authorized');
            assert(listing.token_id == token_id, 'Invalid token_id');
            self.fractional_shares.write(((nft_contract, token_id), owner), new_shares);
        }

        fn get_fractional_shares(
            self: @ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            owner: ContractAddress,
        ) -> u256 {
            let listing_key = (nft_contract, token_id);
            let listing = self.listings.read(listing_key);
            assert(listing.token_id == token_id, 'Invalid token_id');
            self.fractional_shares.read(((nft_contract, token_id), owner))
        }

        fn get_contract_balance(self: @ContractState, currency: ContractAddress) -> u256 {
            self.contract_balance.read(currency)
        }

        fn get_claimed_revenue(
            self: @ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            owner: ContractAddress,
        ) -> u256 {
            self.claimed_revenue.read(((nft_contract, token_id), owner))
        }
    }
}

