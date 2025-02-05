#[starknet::contract]
pub mod MarketPlace {
    use marketplace_auction::interface::{IMarketPlace, Auction};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{
        ContractAddress, get_block_timestamp, get_caller_address, contract_address_const
    };

    #[storage]
    struct Storage {
        auctions: Map<u64, Auction>,
        auction_count: u64,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    //TODO: action created event

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    pub impl MarketPlaceImpl of IMarketPlace<ContractState> {
        fn create_auction(
            ref self: ContractState,
            token_address: ContractAddress,
            token_id: u256,
            start_price: u256
        ) -> u64 {
            let owner = get_caller_address();
            let end_time = get_block_timestamp() + 0; //TODO: add auction duration
            let auction_id = self.auction_count.read() + 1;

            let auction = Auction {
                owner,
                token_address,
                token_id,
                start_price,
                highest_bid: 0,
                highest_bidder: contract_address_const::<0>(),
                end_time,
                active: true,
            };

            // Store auction details
            self.auctions.entry(auction_id).write(auction);
            self.auction_count.write(auction_id);

            auction_id
        }

        fn get_auction(self: @ContractState, auction_id: u64) -> Auction {
            self.auctions.entry(auction_id).read()
        }


        fn commit_bid(ref self: ContractState) {}
        fn reveal_bid(ref self: ContractState) {}
    }
}
