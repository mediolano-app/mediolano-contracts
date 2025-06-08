// Define the contract module
#[starknet::contract]
pub mod Crowdfunding {
    use crate::interfaces::IERC20::IERC20DispatcherTrait;
use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_block_timestamp;
    use core::array::ArrayTrait;
    use core::option::OptionTrait;
    use core::integer::u256;
    use core::integer::u64;
    use core::traits::Into;
    use ip_launchpad::interfaces::IERC20::IERC20Dispatcher;
    use ip_launchpad::interfaces::ICrowdfunding::{ICrowdfunding, Asset, Investment};

    // Storage imports
    use starknet::storage::*;

    // Constants
    const ETH_ADDRESS: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;

    // Storage variables defined in a struct
    #[storage]
    pub struct Storage {
        asset_count: u64, // Counter for assets
        asset_data: Map<u64, Asset>, // Map asset_id (u64) to Asset struct
        asset_ipfs_hash: Map<(u64, u64), felt252>, // Map (asset_id, index) to felt252 hash part
        investor_data: Map<(u64, ContractAddress), Investment>, // Map (asset_id, investor_address) to Investment struct
    }

    // Events - Must derive Drop and starknet::Event, and be part of an #[event] enum
    #[derive(Drop, starknet::Event)]
    pub struct AssetCreated {
        asset_id: u64,
        creator: ContractAddress,
        goal: u256,
        start_time: u64,
        duration: u64,
        base_price: u256,
        ipfs_hash_len: u64,
        ipfs_hash: Span<felt252>, // Events emit Span for arrays
    }

    #[derive(Drop, starknet::Event)]
    pub struct Funded {
        asset_id: u64,
        investor: ContractAddress,
        amount: u256,
        // discounted_price: u256, // Removed from event as it's a calculation
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FundingClosed {
        asset_id: u64,
        total_raised: u256,
        success: bool, // Use bool type
    }

    #[derive(Drop, starknet::Event)]
    pub struct CreatorWithdrawal {
        asset_id: u64,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct InvestorWithdrawal {
        asset_id: u64,
        investor: ContractAddress,
        amount: u256,
    }

    // Event Enum
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AssetCreated: AssetCreated,
        Funded: Funded,
        FundingClosed: FundingClosed,
        CreatorWithdrawal: CreatorWithdrawal,
        InvestorWithdrawal: InvestorWithdrawal,
    }

    // Implement the contract interface - Functions here are public
    #[abi(embed_v0)]
    pub impl CrowdfundingImpl of ICrowdfunding<ContractState> {
        fn create_asset(
            ref self: ContractState,
            goal: u256,
            duration: u64,
            base_price: u256,
            ipfs_hash: Array<felt252>
        ) {
            // Validate inputs using Cairo 1+ syntax
            assert(duration > 0, 'DURATION_MUST_BE_POSITIVE');
            assert(goal > 0, 'GOAL_MUST_BE_POSITIVE'); // u256 comparison
            assert(base_price > 0, 'BASE_PRICE_MUST_BE_POSITIVE'); // u256 comparison

            let caller = get_caller_address();
            let start_time = get_block_timestamp();
            let end_time = start_time + duration;
            let asset_id = self.asset_count.read();

            // Store asset data using storage struct access
            let asset = Asset {
                creator: caller,
                goal: goal,
                raised: 0.into(), // u256 literal
                start_time: start_time,
                end_time: end_time,
                base_price: base_price,
                is_closed: false, // bool literal
                ipfs_hash_len: ipfs_hash.len().into(), // Convert usize to u64
            };
            self.asset_data.write(asset_id, asset);

            // Store IPFS hash parts in the map
            let mut i: u64 = 0;
            let ipfs_len: u64 = ipfs_hash.len().into();
            while i != ipfs_len {
                // Write to the map with (asset_id, index) as key
                let j: u32 = i.try_into().unwrap(); // Convert u64
                self.asset_ipfs_hash.write((asset_id, i), *ipfs_hash.at(j));
                i += 1;
            };

            // Update asset count
            self.asset_count.write(asset_id + 1);

            // Emit event using self.emit
            let ipfs_span = ipfs_hash.span(); // Convert Array to Span for event
            self.emit(
                Event::AssetCreated(
                    AssetCreated {
                        asset_id: asset_id,
                        creator: caller,
                        goal: goal,
                        start_time: start_time,
                        duration: duration,
                        base_price: base_price,
                        ipfs_hash_len: ipfs_len,
                        ipfs_hash: ipfs_span,
                    }
                )
            );
        }

        fn fund(ref self: ContractState, asset_id: u64, amount: u256) { // amount parameter receives the value
            let mut asset = self.asset_data.read(asset_id);

            assert(asset.creator != get_caller_address(), 'ASSET_NOT_FOUND');
            assert(!asset.is_closed, 'FUNDING_CLOSED');

            let current_time = get_block_timestamp();
            assert(current_time >= asset.start_time, 'FUNDING_NOT_STARTED');
            assert(current_time < asset.end_time, 'FUNDING_ENDED');

            let caller = get_caller_address();
            assert(amount > 0, 'AMOUNT_ZERO');

            // Calculate discount
            let time_elapsed = current_time - asset.start_time;
            let total_duration = asset.end_time - asset.start_time;

            let discount_percentage: u64 = if total_duration > 0 {
                 (total_duration - time_elapsed) * 100 / total_duration
            } else {
                0
            };

            let effective_discount_percentage = max_u64(discount_percentage, 10);

            // Calculate discounted price: base_price * (100 - effective_discount_percentage) / 100
            // NOTE: This simplified u256 multiplication/division can overflow for large numbers.
            // A robust solution might require 512-bit intermediates or checked arithmetic.
            let discounted_price = unsafe_u256_mul_div(asset.base_price, (100 - effective_discount_percentage).into(), 100.into());

            assert(amount >= discounted_price, 'INSUFFICIENT_FUNDS');

            // Record investment
            // Map::read() returns default value if key not found, so existing.amount is 0 for first investment
            let mut investment = self.investor_data.read((asset_id, caller));
            let new_amount = investment.amount + amount; // Use u256 addition operator
            investment.amount = new_amount;
            investment.timestamp = current_time;
            self.investor_data.write((asset_id, caller), investment);

            // Update total raised
            let new_raised = asset.raised + amount; // Use u256 addition operator
            asset.raised = new_raised;
            self.asset_data.write(asset_id, asset);

            // Emit event
            self.emit(Event::Funded(Funded { asset_id: asset_id, investor: caller, amount: amount, timestamp: current_time }));
        }

        fn close_funding(ref self: ContractState, asset_id: u64) {
            let mut asset = self.asset_data.read(asset_id);
            assert(asset.creator == get_caller_address(), 'NOT_CREATOR');
            assert(!asset.is_closed, 'FUNDING_ALREADY_CLOSED');

            let current_time = get_block_timestamp();
            assert(current_time > asset.end_time, 'FUNDING_NOT_ENDED');

            // Determine success using u256 comparison operator
            let success = asset.raised >= asset.goal;

            // Update state
            asset.is_closed = true;
            self.asset_data.write(asset_id, asset);

            // Emit event
            self.emit(Event::FundingClosed(FundingClosed { asset_id: asset_id, total_raised: asset.raised, success: success }));
        }

        fn withdraw_creator(ref self: ContractState, asset_id: u64) {
            let asset = self.asset_data.read(asset_id);
            let caller = get_caller_address();

            // Validate
            assert(caller == asset.creator, 'NOT_CREATOR');
            assert(asset.is_closed, 'FUNDING_NOT_CLOSED');
            assert(asset.raised >= asset.goal, 'GOAL_NOT_REACHED'); // Goal reached

            // Transfer funds using the helper
            let amount_to_transfer = asset.raised;
            assert(amount_to_transfer > 0, 'AMOUNT_TO_TRANSFER_ZERO'); // Should not happen if raised > 0
            let success = transfer_erc20(caller, amount_to_transfer);
            assert(success, 'TRANSFER_FAILED');

            // Emit event
            self.emit(Event::CreatorWithdrawal(CreatorWithdrawal { asset_id: asset_id, amount: amount_to_transfer }));
        }

        fn withdraw_investor(ref self: ContractState, asset_id: u64) {
            let asset = self.asset_data.read(asset_id);
            let caller = get_caller_address();
            let mut investment = self.investor_data.read((asset_id, caller));

            // Validate
            assert(investment.amount > 0, 'NO_INVESTMENT'); // Has investment
            assert(asset.is_closed, 'FUNDING_NOT_CLOSED');
            assert!(asset.raised < asset.goal, "GOAL_REACHED_USE_CREATOR_WITHDRAW"); // Goal not reached

            // Transfer funds using the helper
            let amount_to_transfer = investment.amount;
            assert(amount_to_transfer > 0, 'AMOUNT_TO_TRANSFER_ZERO'); // Should be covered by NO_INVESTMENT
            let success = transfer_erc20(caller, amount_to_transfer);
            assert(success, 'TRANSFER_FAILED');

            // Reset investment in storage
            investment.amount = 0.into();
            investment.timestamp = 0;
            self.investor_data.write((asset_id, caller), investment);

            // Emit event
            self.emit(Event::InvestorWithdrawal(InvestorWithdrawal { asset_id: asset_id, investor: caller, amount: amount_to_transfer }));
        }

        // View functions - Use self: @ContractState for read-only access
        fn get_asset_count(self: @ContractState) -> u64 {
            self.asset_count.read()
        }

        fn get_asset_data(self: @ContractState, asset_id: u64) -> Asset {
            self.asset_data.read(asset_id)
        }

        fn get_asset_ipfs_hash(self: @ContractState, asset_id: u64) -> Array<felt252> {
            let asset = self.asset_data.read(asset_id);
            let mut ipfs_hash_array = array![]; 
            let ipfs_len = asset.ipfs_hash_len;

            let mut i: u64 = 0;
            while i != ipfs_len {
                // Read from the map with (asset_id, index) as key
                let hash_part = self.asset_ipfs_hash.read((asset_id, i));
                ipfs_hash_array.append(hash_part);
                i += 1;
            };

            ipfs_hash_array
        }

        fn get_investor_data(self: @ContractState, asset_id: u64, investor: ContractAddress) -> Investment {
            self.investor_data.read((asset_id, investor))
        }
    }

    // --- Helper functions ---

    // Helper function to transfer ERC20 tokens
    // This function is private (not in the abi(embed_v0) impl)
    fn transfer_erc20(recipient: ContractAddress, amount: u256) -> bool {

        let eth_contract_address: ContractAddress = ETH_ADDRESS.try_into().unwrap();
        let erc20_dispatcher = IERC20Dispatcher { contract_address: eth_contract_address };

        let result = erc20_dispatcher.transfer(
            recipient,
            amount
        );
        result
    }

    // Helper function for u256 multiplication and division
    // NOTE: This is a simplified version using direct u256 operators.
    // For full precision with large numbers, a 512-bit intermediate might be required,
    // which is not directly supported by core library types in this context.
    // This function can panic on overflow during multiplication or division by zero.
    fn unsafe_u256_mul_div(value: u256, numerator: u256, denominator: u256) -> u256 {
        assert(denominator > 0, 'DIVISION_BY_ZERO'); // Ensure denominator is not zero
        (value * numerator) / denominator // Perform multiplication and division
    }

    // Helper function for max of two u64 values
    fn max_u64(a: u64, b: u64) -> u64 {
        if a > b {
            a
        } else {
            b
        }
    }
}