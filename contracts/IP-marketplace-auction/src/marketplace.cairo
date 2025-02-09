#[starknet::contract]
pub mod MarketPlace {
    use core::num::traits::Zero;
    use marketplace_auction::interface::{IMarketPlace, Auction};
    use marketplace_auction::utils::{hash, constants};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
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
        balances: Map<ContractAddress, u256>, // bidder -> total deposited funds  
        auction_duration: u64, // auction duration in days
        reveal_duration: u64,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    //TODO: action created event
    //TODO: bid successful event

    #[constructor]
    fn constructor(ref self: ContractState, auction_duration: u64, reveal_duration: u64) {
        self.auction_duration.write(auction_duration);
        self.reveal_duration.write(reveal_duration);
    }

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
            let auction_duration = self.auction_duration.read();
            let end_time = get_block_timestamp() + (auction_duration * constants::DAY_IN_SECONDS);
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
                is_open: true,
                is_finalized: false,
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
            self._check_auction_status(auction_id);

            let auction = self.get_auction(auction_id);
            let bidder = get_caller_address();
            let erc20_dispatcher = IERC20Dispatcher { contract_address: auction.currency_address };

            assert(!auction.owner.is_zero(), 'Invalid auction');
            assert(auction.owner != bidder, 'Bidder is owner');
            assert(auction.is_open, 'Auction closed');
            assert(amount >= auction.start_price, 'Amount less than start price');
            assert(!salt.is_zero(), 'salt is zero');
            assert(
                self._has_sufficient_funds(erc20_dispatcher, amount, get_caller_address()),
                'Insufficient funds'
            );

            let token_address = auction.token_address;
            let token_id = auction.token_id;

            let bid_hash = hash::compute_bid_hash(amount, salt);
            let bid_count = self.get_auction_bid_count(auction_id);

            // store bid hash
            self.committed_bids.entry((auction_id, bidder)).write(bid_hash);
            self.bids_count.entry(auction_id).write(bid_count + 1);

            // transfer funds & update state
            erc20_dispatcher.transfer_from(bidder, get_contract_address(), amount);
            let prev_balance = self.balances.entry(bidder).read();
            self.balances.entry(bidder).write(prev_balance + amount);
        }

        fn get_auction_bid_count(self: @ContractState, auction_id: u64) -> u64 {
            self.bids_count.entry(auction_id).read()
        }


        fn reveal_bid(ref self: ContractState, auction_id: u64, amount: u256, salt: felt252) {
            self._check_auction_status(auction_id);
            let bidder = get_caller_address();

            // check if auction is open
            let auction = self.get_auction(auction_id);
            assert(!auction.is_open, 'Auction is still open');

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

        fn finalize_auction(ref self: ContractState, auction_id: u64) {
            self._check_auction_status(auction_id);

            let mut auction = self.get_auction(auction_id);
            let reveal_duration = self.reveal_duration.read();
            let reveal_duration_end = auction.end_time
                + (reveal_duration * constants::DAY_IN_SECONDS);

            assert(!auction.is_open, 'Auction is still open');
            assert(get_block_timestamp() >= reveal_duration_end, 'Reveal time not over');
            assert(!auction.is_finalized, 'Auction already finalized');

            let (highest_bid, highest_bidder) = self._get_highest_bidder(auction_id);

            // refund bidders
            self._refund_committed_funds(auction_id, highest_bidder, auction.currency_address);

            // transfer asset to highest bidder
            IERC721Dispatcher { contract_address: auction.token_address }
                .transfer_from(get_contract_address(), highest_bidder, auction.token_id);

            // transfer bid amount to asset owner
            let prev_balance = self.balances.entry(highest_bidder).read();
            self.balances.entry(highest_bidder).write(prev_balance - highest_bid);
            IERC20Dispatcher { contract_address: auction.currency_address }
                .transfer(auction.owner, highest_bid);

            // update auction state
            auction.highest_bid = highest_bid;
            auction.highest_bidder = highest_bidder;
            auction.is_finalized = true;

            self.auctions.entry(auction_id).write(auction);
            // emit event
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

        fn _has_sufficient_funds(
            ref self: ContractState,
            erc20_dispatcher: IERC20Dispatcher,
            amount: u256,
            caller: ContractAddress
        ) -> bool {
            erc20_dispatcher.balance_of(caller) >= amount
        }

        fn _get_highest_bidder(self: @ContractState, auction_id: u64) -> (u256, ContractAddress) {
            let bids = self.get_revealed_bids(auction_id);
            let mut highest_bid = 0;
            let mut highest_bidder = contract_address_const::<0>();

            for (
                amount, bidder
            ) in bids {
                if *amount > highest_bid {
                    highest_bid = *amount;
                    highest_bidder = *bidder;
                }
            };

            (highest_bid, highest_bidder)
        }

        fn _refund_committed_funds(
            ref self: ContractState,
            auction_id: u64,
            highest_bidder: ContractAddress,
            currency_address: ContractAddress
        ) {
            let bids = self.get_revealed_bids(auction_id);

            for (
                amount, bidder
            ) in bids {
                if *bidder != highest_bidder {
                    let prev_balance = self.balances.entry(*bidder).read();
                    self.balances.entry(*bidder).write(prev_balance - *amount);

                    // transfer
                    IERC20Dispatcher { contract_address: currency_address }
                        .transfer(*bidder, *amount);
                }
            };
        }

        fn _check_auction_status(ref self: ContractState, auction_id: u64) {
            let mut auction = self.get_auction(auction_id);
            let current_time = get_block_timestamp();

            if current_time >= auction.end_time {
                auction.is_open = false;
                self.auctions.entry(auction_id).write(auction);
            }
        }
    }
}
