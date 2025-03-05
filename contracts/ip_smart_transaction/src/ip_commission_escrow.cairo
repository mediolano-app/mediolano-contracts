use core::starknet::ContractAddress;

#[starknet::interface]
pub trait IIPCommissionEscrow<TContractState> {
    fn create_order(
        ref self: TContractState,
        amount: u256,
        supplier: ContractAddress,
        artwork_conditions: felt252,
        ip_license: felt252,
    ) -> u256;
    fn pay_order(ref self: TContractState, order_id: u256);
    fn complete_order(ref self: TContractState, order_id: u256);
    fn cancel_order(ref self: TContractState, order_id: u256);
    fn get_order_details(
        self: @TContractState, order_id: u256,
    ) -> (ContractAddress, ContractAddress, u256, felt252, felt252, felt252);
    fn _validate(ref self: TContractState, buyer: ContractAddress, amount: u256);
}

#[starknet::contract]
pub mod IPCommissionEscrow {
    use starknet::storage::{
        StorageMapReadAccess, StoragePointerReadAccess, StoragePointerWriteAccess,
        StorageMapWriteAccess, Map,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use ip_smart_transaction::mock_erc20::{IERC20Dispatcher, IERC20DispatcherTrait};

    // The Storage struct holds our order state and ERC20 dispatcher
    #[storage]
    struct Storage {
        // Incrementing order counter.
        order_count: u256,
        // Mapping from order_id to the amount deposited (in ERC20 tokens).
        orders_amount: Map<u256, u256>,
        // Mapping from order_id to order creator address (the one depositing funds).
        orders_creator: Map<u256, ContractAddress>,
        // Mapping from order_id to supplier address.
        orders_supplier: Map<u256, ContractAddress>,
        // Mapping from order_id to order state.
        // We use felt252 constants: e.g. 'NotPaid', 'Paid', 'Completed', 'Cancelled'
        order_states: Map<u256, felt252>,
        // Mapping from order_id to artwork conditions (represented as a felt252; e.g. could be an
        // IPFS hash).
        orders_artwork_conditions: Map<u256, felt252>,
        // Mapping from order_id to IP licensing details (also a felt252 representation).
        orders_ip_license: Map<u256, felt252>,
        // The ERC20 token dispatcher (set during deployment).
        erc20: IERC20Dispatcher,
        // The ERC20 token address.
        token_address: ContractAddress,
    }

    // In the constructor we initialize the token address and set order_count to 0.
    #[constructor]
    fn constructor(ref self: ContractState, token_address: ContractAddress) {
        self.erc20.write(IERC20Dispatcher { contract_address: token_address });
        self.token_address.write(token_address);
        self.order_count.write(0);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        OrderCreated: OrderCreated,
        OrderPaid: OrderPaid,
        OrderCompleted: OrderCompleted,
        OrderCancelled: OrderCancelled,
    }

    // Event emitted when a new order is created.
    #[derive(Drop, starknet::Event)]
    pub struct OrderCreated {
        order_id: u256,
        creator: ContractAddress,
        supplier: ContractAddress,
        amount: u256,
        artwork_conditions: felt252,
        ip_license: felt252,
    }

    // Event emitted when an order is paid.
    #[derive(Drop, starknet::Event)]
    pub struct OrderPaid {
        order_id: u256,
        payer: ContractAddress,
        amount: u256,
    }

    // Event emitted when an order is completed.
    #[derive(Drop, starknet::Event)]
    pub struct OrderCompleted {
        order_id: u256,
        supplier: ContractAddress,
        amount: u256,
    }

    // Event emitted when an order is cancelled.
    #[derive(Drop, starknet::Event)]
    pub struct OrderCancelled {
        order_id: u256,
    }

    // The main interface of the contract.
    #[abi(embed_v0)]
    impl IPCommissionEscrow of super::IIPCommissionEscrow<ContractState> {
        /// Create an order for commissioning IP.
        /// @param amount: The escrow deposit required (ERC20 token amount).
        /// @param supplier: The address of the supplier who will deliver the IP.
        /// @param artwork_conditions: Conditions or requirements for the commissioned work (e.g. an
        /// IPFS hash).
        /// @param ip_license: Licensing details for the commissioned IP.
        /// @return order_id: A unique identifier for the order.
        fn create_order(
            ref self: ContractState,
            amount: u256,
            supplier: ContractAddress,
            artwork_conditions: felt252,
            ip_license: felt252,
        ) -> u256 {
            // Increment the order counter.
            let current_order = self.order_count.read();
            let new_order = current_order + 1;
            self.order_count.write(new_order);

            // Store order details.
            let caller = get_caller_address();
            self.orders_creator.write(new_order, caller);
            self.orders_supplier.write(new_order, supplier);
            self.orders_amount.write(new_order, amount);
            self.orders_artwork_conditions.write(new_order, artwork_conditions);
            self.orders_ip_license.write(new_order, ip_license);
            // Set the initial state to 'NotPaid'.
            self.order_states.write(new_order, 'NotPaid');

            // Emit an event for order creation.
            self
                .emit(
                    OrderCreated {
                        order_id: new_order,
                        creator: caller,
                        supplier: supplier,
                        amount: amount,
                        artwork_conditions: artwork_conditions,
                        ip_license: ip_license,
                    },
                );
            new_order
        }

        /// Deposit funds for an order.
        /// The creator (order poster) calls this to deposit the required amount into the contract.
        fn pay_order(ref self: ContractState, order_id: u256) {
            let state = self.order_states.read(order_id);
            // Ensure the order is in the 'NotPaid' state.
            assert(state == 'NotPaid', 'Order is not payable');
            let amount = self.orders_amount.read(order_id);

            // Validate that the caller has sufficient token balance.
            let caller = get_caller_address();
            self._validate(caller, amount);

            // Transfer tokens from the caller to this contract.
            let dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            let result = dispatcher.transfer_from(caller, get_contract_address(), amount);
            assert(result, 'ERC20_TRANSFER_FAILED');

            // Update order state to 'Paid'.
            self.order_states.write(order_id, 'Paid');

            // Emit an event indicating successful payment.
            self.emit(OrderPaid { order_id: order_id, payer: caller, amount: amount });
        }

        /// Complete an order.
        /// Only the order creator may call this function once the supplier has met the conditions.
        /// On approval, funds are transferred to the supplier.
        fn complete_order(ref self: ContractState, order_id: u256) {
            let state = self.order_states.read(order_id);
            // Only a paid order can be completed.
            assert(state == 'Paid', 'Order is not paid');

            // Ensure that only the order creator can approve the order.
            let caller = get_caller_address();
            let creator = self.orders_creator.read(order_id);
            assert(caller == creator, 'Only order creator can complete');

            let amount = self.orders_amount.read(order_id);
            let supplier = self.orders_supplier.read(order_id);
            let dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };

            // Transfer funds to the supplier.
            let result = dispatcher.transfer(supplier, amount);
            assert(result, 'ERC20_TRANSFER_FAILED');

            // Mark the order as 'Completed'.
            self.order_states.write(order_id, 'Completed');

            // Emit an event for order completion.
            self.emit(OrderCompleted { order_id: order_id, supplier: supplier, amount: amount });
            // Note: The commissioned IP and licensing details are recorded in storage (or via
        // events)
        // so that offchain systems or further onchain processes can recognize that the supplier
        // now holds the commissioned IP along with the associated license.
        }

        /// Cancel an order.
        /// Only allowed when the order is still in the 'NotPaid' state.
        fn cancel_order(ref self: ContractState, order_id: u256) {
            let state = self.order_states.read(order_id);
            // An order cannot be cancelled if already paid or completed.
            assert(state == 'NotPaid', 'Cant cancel paid/completed one');

            // Only the order creator can cancel.
            let caller = get_caller_address();
            let creator = self.orders_creator.read(order_id);
            assert(caller == creator, 'Only order creator can cancel');

            self.order_states.write(order_id, 'Cancelled');
            self.emit(OrderCancelled { order_id: order_id });
        }

        /// Internal helper to validate that the buyer has sufficient token balance.
        fn _validate(ref self: ContractState, buyer: ContractAddress, amount: u256) {
            let buyer_balance = self.erc20.read().balance_of(buyer);
            assert(buyer_balance >= amount, 'ERC20_NOT_SUFFICIENT_AMOUNT');
        }

        /// Get details of an order.
        /// Returns the creator, supplier, amount, state, artwork conditions, and IP license.
        fn get_order_details(
            self: @ContractState, order_id: u256,
        ) -> (ContractAddress, ContractAddress, u256, felt252, felt252, felt252) {
            let creator = self.orders_creator.read(order_id);
            let supplier = self.orders_supplier.read(order_id);
            let amount = self.orders_amount.read(order_id);
            let state = self.order_states.read(order_id);
            let artwork_conditions = self.orders_artwork_conditions.read(order_id);
            let ip_license = self.orders_ip_license.read(order_id);
            (creator, supplier, amount, state, artwork_conditions, ip_license)
        }
    }
}
