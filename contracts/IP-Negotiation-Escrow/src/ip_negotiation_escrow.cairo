use core::starknet::ContractAddress;

#[starknet::interface]
pub trait IIPNegotiationEscrow<TContractState> {
    fn create_order(
        ref self: TContractState,
        creator: ContractAddress,
        price: u256,
        token_id: u256,
    ) -> felt252;
    
    fn get_order(self: @TContractState, order_id: felt252) -> Order;
    fn get_order_by_token_id(self: @TContractState, token_id: u256) -> Order;
    fn deposit_funds(ref self: TContractState, order_id: felt252);
    fn fulfill_order(ref self: TContractState, order_id: felt252);
    fn cancel_order(ref self: TContractState, order_id: felt252);
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Order {
    creator: ContractAddress,
    price: u256,
    token_id: u256,
    fulfilled: bool,
    id: felt252,
}

#[starknet::contract]
pub mod IPNegotiationEscrow {
    use starknet::storage::{
        StorageMapReadAccess, StoragePointerReadAccess, StoragePointerWriteAccess,
        StorageMapWriteAccess, Map,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use ip_negotiation_escrow::mock_erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::{Order};
    use core::pedersen::pedersen;

    #[storage]
    struct Storage {
        // The ERC20 token dispatcher (set during deployment)
        erc20: IERC20Dispatcher,
        // The ERC20 token address
        token_address: ContractAddress,
        // Mapping from order_id to Order
        orders: Map<felt252, Order>,
        // Mapping from token_id to order_id
        token_to_order: Map<u256, felt252>,
        // Total number of orders created (for generating unique order IDs)
        order_count: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        OrderCreated: OrderCreated,
        FundsDeposited: FundsDeposited,
        OrderFulfilled: OrderFulfilled,
        OrderCancelled: OrderCancelled,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OrderCreated {
        order_id: felt252,
        creator: ContractAddress,
        price: u256,
        token_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FundsDeposited {
        order_id: felt252,
        buyer: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OrderFulfilled {
        order_id: felt252,
        seller: ContractAddress,
        buyer: ContractAddress,
        token_id: u256,
        price: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OrderCancelled {
        order_id: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_address: ContractAddress) {
        self.erc20.write(IERC20Dispatcher { contract_address: token_address });
        self.token_address.write(token_address);
        self.order_count.write(0);
    }

    #[abi(embed_v0)]
    impl IPNegotiationEscrowImpl of super::IIPNegotiationEscrow<ContractState> {
        /// Create a new order for IP negotiation
        /// @param creator: The address of the seller who owns the IP
        /// @param price: The price of the IP in the specified token
        /// @param token_id: Unique identifier for the IP asset
        /// @return order_id: A unique identifier for the order
        fn create_order(
            ref self: ContractState,
            creator: ContractAddress,
            price: u256,
            token_id: u256,
        ) -> felt252 {
            // Ensure the creator is the caller
            let caller = get_caller_address();
            assert(caller == creator, 'Only creator can create order');
            
            // Check if token already has an active order
            let existing_order_id = self.token_to_order.read(token_id);
            if existing_order_id != 0 {
                let existing_order = self.orders.read(existing_order_id);
                assert(existing_order.fulfilled, 'Token already has active order');
            }
            
            // Generate unique order ID using Pedersen hash
            let count = self.order_count.read();
            
            // Calculate a unique order ID by chaining Pedersen hashes
            let hash1 = pedersen(token_id.low.into(), token_id.high.into());
            let hash2 = pedersen(hash1, count.low.into());
            let hash3 = pedersen(hash2, count.high.into());
            let order_id = pedersen(hash3, creator.into());
            
            // Create new order
            let order = Order {
                creator,
                price,
                token_id,
                fulfilled: false,
                id: order_id,
            };
            
            // Store order in mappings
            self.orders.write(order_id, order);
            self.token_to_order.write(token_id, order_id);
            
            // Increment order count
            self.order_count.write(count + 1);
            
            // Emit event
            self.emit(
                OrderCreated {
                    order_id,
                    creator,
                    price,
                    token_id,
                }
            );
            
            order_id
        }
        
        /// Get order details by order ID
        /// @param order_id: The unique identifier of the order
        /// @return Order: The order details
        fn get_order(self: @ContractState, order_id: felt252) -> Order {
            let order = self.orders.read(order_id);
            assert(order.id == order_id, 'Order does not exist');
            order
        }
        
        /// Get order details by token ID
        /// @param token_id: The unique identifier of the token
        /// @return Order: The order details
        fn get_order_by_token_id(self: @ContractState, token_id: u256) -> Order {
            let order_id = self.token_to_order.read(token_id);
            assert(order_id != 0, 'No order for this token');
            self.orders.read(order_id)
        }
        
        /// Deposit funds for an order
        /// @param order_id: The unique identifier of the order
        fn deposit_funds(ref self: ContractState, order_id: felt252) {
            let order = self.orders.read(order_id);
            assert(order.id == order_id, 'Order does not exist');
            assert(!order.fulfilled, 'Order already fulfilled');
            
            let buyer = get_caller_address();
            assert(buyer != order.creator, 'Creator cannot buy own IP');
            
            // Check buyer has sufficient balance
            let buyer_balance = self.erc20.read().balance_of(buyer);
            assert(buyer_balance >= order.price, 'Insufficient balance');
            
            // Transfer tokens from buyer to contract
            let dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            let result = dispatcher.transfer_from(buyer, get_contract_address(), order.price);
            assert(result, 'ERC20 transfer failed');
            
            // Emit event
            self.emit(
                FundsDeposited {
                    order_id,
                    buyer,
                    amount: order.price,
                }
            );
        }
        
        /// Fulfill an order after funds have been deposited
        /// @param order_id: The unique identifier of the order
        fn fulfill_order(ref self: ContractState, order_id: felt252) {
            let mut order = self.orders.read(order_id);
            assert(order.id == order_id, 'Order does not exist');
            assert(!order.fulfilled, 'Order already fulfilled');
            
            // Only the creator (seller) can fulfill the order
            let caller = get_caller_address();
            assert(caller == order.creator, 'Only creator can fulfill order');
            
            // Transfer tokens to the seller
            let dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            let result = dispatcher.transfer(order.creator, order.price);
            assert(result, 'ERC20 transfer failed');
            
            // Mark order as fulfilled
            order.fulfilled = true;
            self.orders.write(order_id, order);
            
            // Emit event
            // Note: In practice, we would also need to handle the actual transfer of the token,
            // which might be done through a separate NFT contract
            self.emit(
                OrderFulfilled {
                    order_id,
                    seller: order.creator,
                    buyer: caller, // This would normally be the buyer's address
                    token_id: order.token_id,
                    price: order.price,
                }
            );
        }
        
        /// Cancel an order
        /// @param order_id: The unique identifier of the order
        fn cancel_order(ref self: ContractState, order_id: felt252) {
            let order = self.orders.read(order_id);
            assert(order.id == order_id, 'Order does not exist');
            assert(!order.fulfilled, 'Order already fulfilled');
            
            // Only the creator can cancel the order
            let caller = get_caller_address();
            assert(caller == order.creator, 'Only creator can cancel order');
            
            // Mark order as fulfilled (effectively cancelling it)
            let mut updated_order = order;
            updated_order.fulfilled = true;
            self.orders.write(order_id, updated_order);
            
            // Emit event
            self.emit(
                OrderCancelled {
                    order_id,
                }
            );
        }
    }
} 