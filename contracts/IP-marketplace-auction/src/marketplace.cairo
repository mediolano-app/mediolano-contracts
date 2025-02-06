#[starknet::contract]
pub mod MarketPlace {
    use core::num::traits::Zero;
    use marketplace_auction::interface::{IMarketPlace, Auction};
    use marketplace_auction::utils::hash;

    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, MutableVecTrait,
        Vec, VecTrait,
    };
    use starknet::{
        ContractAddress, get_block_timestamp, get_caller_address, contract_address_const,
        get_contract_address
    };

    #[storage]
    struct Storage {
        auctions: Map<u64, Auction>, // auction_id -> Auction
        auction_count: u64,
        committed_bids: Map<(u64, ContractAddress), felt252>, // (auction_id, bidder) -> bid_hash
        bids_count: Map<u64, u64>, // auction_id -> number of bids
        revealed_bids: Map<u64, Vec<(u256, ContractAddress)>>, // auction_id -> Vec(amount, bidder)
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    //TODO: action created event
    //TODO: bid successful event

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    pub impl MarketPlaceImpl of IMarketPlace<ContractState> {
        fn create_auction(
            ref self: ContractState,
            token_address: ContractAddress,
            token_id: u256,
            start_price: u256,
            currency_address: ContractAddress,
        ) -> u64 {
            let owner = get_caller_address();
            let end_time = get_block_timestamp() + 0; //TODO: add auction duration
            let auction_id = self.auction_count.read() + 1;

            assert(!start_price.is_zero(), 'Start price is zero');
            assert(self._is_owner(token_address, token_id, owner), 'Caller is not owner');
            assert(!currency_address.is_zero(), 'Currency address is zero');

            let auction = Auction {
                owner,
                token_address,
                token_id,
                start_price,
                highest_bid: 0,
                highest_bidder: contract_address_const::<0>(),
                end_time,
                active: true,
                is_completed: false,
                currency_address,
            };

            // Store auction details
            self.auctions.entry(auction_id).write(auction);
            self.auction_count.write(auction_id);

            // transfer asset
            IERC721Dispatcher { contract_address: token_address }
                .transfer_from(owner, get_contract_address(), token_id);

            //TODO emit event
            auction_id
        }

        fn get_auction(self: @ContractState, auction_id: u64) -> Auction {
            self.auctions.entry(auction_id).read()
        }


        fn commit_bid(ref self: ContractState, auction_id: u64, amount: u256, salt: felt252) {
            let auction = self.get_auction(auction_id);
            let bidder = get_caller_address();

            assert(!auction.owner.is_zero(), 'Invalid auction');
            assert(auction.owner != bidder, 'Bidder is owner');
            assert(auction.active, 'Auction is not active');
            assert(amount >= auction.start_price, 'Amount less than start price');
            assert(!salt.is_zero(), 'salt is zero');

            let token_address = auction.token_address;
            let token_id = auction.token_id;

            let bid_hash = hash::compute_bid_hash(amount, salt);
            let bid_count = self.get_auction_bid_count(auction_id);

            // store bid hash
            self.committed_bids.entry((auction_id, bidder)).write(bid_hash);
            self.bids_count.entry(auction_id).write(bid_count + 1);
            // TODO: transfer funds
        }

        fn get_auction_bid_count(self: @ContractState, auction_id: u64) -> u64 {
            self.bids_count.entry(auction_id).read()
        }


        fn reveal_bid(ref self: ContractState, auction_id: u64, amount: u256, salt: felt252) {
            let bidder = get_caller_address();

            //TODO: use auction duration
            // check if auction is still active
            // assert(!self.get_auction(auction_id).active, 'Auction is still active');

            // get initial bid hash
            let bid_hash = self.committed_bids.entry((auction_id, bidder)).read();

            assert(!bid_hash.is_zero(), 'No bid found');

            // compare bid hash
            let revealed_bid_hash = hash::compute_bid_hash(amount, salt);

            assert(bid_hash == revealed_bid_hash, 'Wrong amount or salt');

            self.revealed_bids.entry(auction_id).append().write((amount, bidder));
        }

        fn get_revealed_bids(
            self: @ContractState, auction_id: u64
        ) -> Span<(u256, ContractAddress)> {
            let bid_len = self.revealed_bids.entry(auction_id).len();
            let mut bids: Array<(u256, ContractAddress)> = array![];

            for i in 0
                ..bid_len {
                    let bid = self.revealed_bids.entry(auction_id).at(i).read();
                    bids.append(bid);
                };
            bids.span()
        }
    }

    #[generate_trait]
    pub impl InternalFunctions of InternalFunctionsTrait {
        fn _is_owner(
            ref self: ContractState,
            token_address: ContractAddress,
            token_id: u256,
            caller: ContractAddress
        ) -> bool {
            let owner = IERC721Dispatcher { contract_address: token_address }.owner_of(token_id);
            owner == caller
        }
    }
}
