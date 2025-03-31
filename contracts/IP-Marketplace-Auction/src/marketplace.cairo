#[starknet::contract]
pub mod MarketPlace {
    use core::num::traits::Zero;
    use marketplace_auction::interface::{IMarketPlace, Auction};
    use marketplace_auction::utils::errors::Errors;
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
    pub enum Event {
        AuctionCreated: AuctionCreated,
        BidCommitted: BidCommitted,
        BidRevealed: BidRevealed,
        AuctionFinalized: AuctionFinalized,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AuctionCreated {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub token_address: ContractAddress,
        #[key]
        pub token_id: u256,
        pub start_price: u256,
        pub currency_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BidCommitted {
        #[key]
        pub bidder: ContractAddress,
        #[key]
        pub auction_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BidRevealed {
        #[key]
        pub bidder: ContractAddress,
        #[key]
        pub auction_id: u64,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AuctionFinalized {
        #[key]
        pub auction_id: u64,
        #[key]
        pub highest_bidder: ContractAddress,
    }

    /// Initializes the marketplace contract with auction and reveal durations.
    ///
    /// # Arguments
    /// * `auction_duration` - The duration of auctions in days.
    /// * `reveal_duration` - The duration for revealing bids in days.
    #[constructor]
    fn constructor(ref self: ContractState, auction_duration: u64, reveal_duration: u64) {
        self.auction_duration.write(auction_duration);
        self.reveal_duration.write(reveal_duration);
    }

    #[abi(embed_v0)]
    pub impl MarketPlaceImpl of IMarketPlace<ContractState> {
        /// Creates a new auction for an ERC-721 token.
        ///
        /// # Arguments
        /// * `token_address` - The contract address of the ERC-721 token.
        /// * `token_id` - The ID of the token being auctioned.
        /// * `start_price` - The minimum bid amount.
        /// * `currency_address` - The ERC-20 token used for bidding.
        ///
        /// # Returns
        /// * The unique identifier of the newly created auction.
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

            assert(!start_price.is_zero(), Errors::START_PRIZE_IS_ZERO);
            assert(self._is_owner(token_address, token_id, owner), Errors::CALLER_NOT_OWNER);
            assert(!currency_address.is_zero(), Errors::CURRENCY_ADDRESS_ZERO);

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

            //emit auction created event
            self
                .emit(
                    Event::AuctionCreated(
                        AuctionCreated {
                            owner, token_address, token_id, start_price, currency_address
                        },
                    ),
                );

            auction_id
        }

        /// Retrieves the details of an auction by its ID.
        ///
        /// # Arguments
        /// * `auction_id` - The unique identifier of the auction.
        ///
        /// # Returns
        /// * The `Auction` struct containing auction details.
        fn get_auction(self: @ContractState, auction_id: u64) -> Auction {
            self.auctions.entry(auction_id).read()
        }

        /// Commits a bid for a specific auction by storing a hash of the bid amount and salt.
        ///
        /// # Arguments
        /// * `auction_id` - The ID of the auction being bid on.
        /// * `amount` - The bid amount.
        /// * `salt` - A secret value used to hash the bid for commitment.
        fn commit_bid(ref self: ContractState, auction_id: u64, amount: u256, salt: felt252) {
            self._check_auction_status(auction_id);

            let auction = self.get_auction(auction_id);
            let bidder = get_caller_address();
            let erc20_dispatcher = IERC20Dispatcher { contract_address: auction.currency_address };

            assert(!auction.owner.is_zero(), Errors::INVALID_AUCTION);
            assert(auction.owner != bidder, Errors::BIDDER_IS_OWNER);
            assert(auction.is_open, Errors::AUCTION_CLOSED);
            assert(amount >= auction.start_price, Errors::AMOUNT_LESS_THAN_START_PRICE);
            assert(!salt.is_zero(), Errors::SALT_IS_ZERO);
            assert(
                self._has_sufficient_funds(erc20_dispatcher, amount, get_caller_address()),
                Errors::INSUFFICIENT_FUNDS
            );

            let bid_hash = hash::compute_bid_hash(amount, salt);
            let bid_count = self.get_auction_bid_count(auction_id);

            // store bid hash
            self.committed_bids.entry((auction_id, bidder)).write(bid_hash);
            self.bids_count.entry(auction_id).write(bid_count + 1);

            // transfer funds & update state
            erc20_dispatcher.transfer_from(bidder, get_contract_address(), amount);
            let prev_balance = self.balances.entry(bidder).read();
            self.balances.entry(bidder).write(prev_balance + amount);

            self.emit(Event::BidCommitted(BidCommitted { bidder, auction_id }));
        }

        /// Gets the number of committed bids for an auction.
        ///
        /// # Arguments
        /// * `auction_id` - The unique identifier of the auction.
        ///
        /// # Returns
        /// * The total number of bids committed for the auction.
        fn get_auction_bid_count(self: @ContractState, auction_id: u64) -> u64 {
            self.bids_count.entry(auction_id).read()
        }

        /// Reveals a previously committed bid for an auction.
        ///
        /// # Arguments
        /// * `auction_id` - The ID of the auction.
        /// * `amount` - The bid amount previously committed.
        /// * `salt` - The same salt used during the bid commitment.
        fn reveal_bid(ref self: ContractState, auction_id: u64, amount: u256, salt: felt252) {
            self._check_auction_status(auction_id);
            let bidder = get_caller_address();

            // check if auction is open
            let auction = self.get_auction(auction_id);
            assert(!auction.is_open, Errors::AUCTION_STILL_OPEN);

            // get initial bid hash
            let bid_hash = self.committed_bids.entry((auction_id, bidder)).read();

            assert(!bid_hash.is_zero(), Errors::NO_BID_FOUND);

            // compare bid hash
            let revealed_bid_hash = hash::compute_bid_hash(amount, salt);

            assert(bid_hash == revealed_bid_hash, Errors::WRONG_AMOUNT_OR_SALT);

            if !self._is_reveal_duration_over(auction_id) {
                self.revealed_bids.entry(auction_id).append().write((amount, bidder));
            }

            // emit event
            self.emit(Event::BidRevealed(BidRevealed { bidder, auction_id, amount }));
        }

        /// Retrieves all revealed bids for a specific auction.
        ///
        /// # Arguments
        /// * `auction_id` - The ID of the auction.
        ///
        /// # Returns
        /// * A Span of tuples containing bid amounts and bidder addresses.
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

        /// Finalizes an auction, determines the winner, and transfers the asset and token.
        ///
        /// # Arguments
        /// * `auction_id` - The unique identifier of the auction.
        fn finalize_auction(ref self: ContractState, auction_id: u64) {
            self._check_auction_status(auction_id);

            let mut auction = self.get_auction(auction_id);
            assert(!auction.is_open, Errors::AUCTION_STILL_OPEN);
            assert(self._is_reveal_duration_over(auction_id), Errors::REVEAL_TIME_NOT_OVER);
            assert(!auction.is_finalized, Errors::AUCTION_IS_FINALIZED);

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
            self.emit(Event::AuctionFinalized(AuctionFinalized { auction_id, highest_bidder }));
        }

        /// Withdraws/refund committed bid from an auction that wasn't revealed within the reveal
        /// time.
        ///
        /// Ensures the caller is not the highest bidder(winner) and that the bid has not been
        /// refunded.
        /// Reveals the bid before allowing the withdrawal to confirm it's authenticity.
        ///
        /// # Arguments
        /// * `auction_id` - The ID of the auction.
        /// * `amount` - The amount to withdraw.
        /// * `salt` - The salt used for bid commitment.
        fn withdraw_unrevealed_bid(
            ref self: ContractState, auction_id: u64, amount: u256, salt: felt252
        ) {
            let bidder = get_caller_address();
            assert(
                bidder != self.get_auction(auction_id).highest_bidder,
                Errors::CALLER_ALREADY_WON_AUCTION
            );
            assert(!self._is_refunded(auction_id), Errors::BID_REFUNDED);

            self.reveal_bid(auction_id, amount, salt);

            let balance = self.balances.entry(bidder).read();
            assert(amount >= balance, Errors::AMOUNT_EXCEEDS_BALANCE);

            //refund
            self.balances.entry(bidder).write(balance - amount);
            IERC20Dispatcher { contract_address: self.get_auction(auction_id).currency_address }
                .transfer(bidder, amount);
        }
    }

    #[generate_trait]
    pub impl InternalFunctions of InternalFunctionsTrait {
        /// Checks whether a given address owns a specific ERC-721 token.
        ///
        /// # Arguments
        /// * `token_address` - The contract address of the ERC-721 token.
        /// * `token_id` - The ID of the token.
        /// * `caller` - The address to verify ownership for.
        ///
        /// # Returns
        /// * `true` if the caller is the owner of the token, otherwise `false`.
        fn _is_owner(
            ref self: ContractState,
            token_address: ContractAddress,
            token_id: u256,
            caller: ContractAddress
        ) -> bool {
            let owner = IERC721Dispatcher { contract_address: token_address }.owner_of(token_id);
            owner == caller
        }

        /// Checks if an address has sufficient ERC-20 balance to place a bid.
        ///
        /// # Arguments
        /// * `erc20_dispatcher` - The ERC-20 dispatcher for interacting with the token contract.
        /// * `amount` - The required balance amount.
        /// * `caller` - The address whose balance is being checked.
        ///
        /// # Returns
        /// * `true` if the balance is sufficient, otherwise `false`.
        fn _has_sufficient_funds(
            ref self: ContractState,
            erc20_dispatcher: IERC20Dispatcher,
            amount: u256,
            caller: ContractAddress
        ) -> bool {
            erc20_dispatcher.balance_of(caller) >= amount
        }

        /// Determines the highest bid and bidder for a given auction.
        ///
        /// # Arguments
        /// * `auction_id` - The unique identifier of the auction.
        ///
        /// # Returns
        /// * A tuple containing the highest bid amount and the highest bidder's address.
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

        /// Refunds all losing bidders for a finalized auction.
        ///
        /// # Arguments
        /// * `auction_id` - The unique identifier of the auction.
        /// * `highest_bidder` - The address of the winning bidder.
        /// * `currency_address` - The ERC-20 token used for bidding.
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

        /// Checks the status of an auction and closes it if the end time has passed.
        ///
        /// # Arguments
        /// * `auction_id` - The ID of the auction to check.
        fn _check_auction_status(ref self: ContractState, auction_id: u64) {
            let mut auction = self.get_auction(auction_id);
            let current_time = get_block_timestamp();

            if current_time >= auction.end_time {
                auction.is_open = false;
                self.auctions.entry(auction_id).write(auction);
            }
        }

        /// Determines whether the reveal duration for an auction has expired.
        ///
        /// # Arguments
        /// * `auction_id` - The ID of the auction.
        ///
        /// # Returns
        /// * `bool` - Returns `true` if the reveal duration has ended, otherwise `false`.
        fn _is_reveal_duration_over(self: @ContractState, auction_id: u64) -> bool {
            let auction = self.get_auction(auction_id);
            let reveal_duration = self.reveal_duration.read();
            let reveal_duration_end = auction.end_time
                + (reveal_duration * constants::DAY_IN_SECONDS);

            get_block_timestamp() >= reveal_duration_end
        }

        /// Checks if the caller's bid in a given auction has already been refunded.
        ///
        /// # Arguments
        /// * `auction_id` - The ID of the auction.
        ///
        /// # Returns
        /// * `bool` - Returns `true` if the caller's bid has been refunded, otherwise `false`.
        fn _is_refunded(self: @ContractState, auction_id: u64) -> bool {
            let bids = self.get_revealed_bids(auction_id);
            let mut is_refunded = false;

            for (_, bidder) in bids {
                if *bidder == get_caller_address() {
                    is_refunded = true;
                }
            };
            is_refunded
        }
    }
}
