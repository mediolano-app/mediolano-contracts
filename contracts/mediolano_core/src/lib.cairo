use core::array::ArrayTrait;
use core::ecdsa::check_ecdsa_signature;
use core::option::OptionTrait;
use core::poseidon::poseidon_hash_span;
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use starknet::secp_trait::*;
use starknet::storage::{
    Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};
use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};

#[starknet::contract]
mod medialane {
    use super::*;
    mod errors {
        pub const INVALID_SIGNATURE: felt252 = 'Invalid signature';
        pub const ORDER_EXPIRED: felt252 = 'Order expired';
        pub const ORDER_NOT_YET_VALID: felt252 = 'Order not yet valid';
        pub const INVALID_NONCE: felt252 = 'Invalid nonce';
        pub const ORDER_ALREADY_FILLED: felt252 = 'Order already filled';
        pub const ORDER_CANCELLED: felt252 = 'Order cancelled';
        pub const INSUFFICIENT_APPROVAL: felt252 = 'Insufficient approval';
        pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
        pub const TRANSFER_FAILED: felt252 = 'Transfer failed';
        pub const INVALID_ITEM_TYPE: felt252 = 'Invalid item type';
        pub const OFFER_CONSIDERATION_MISMATCH: felt252 = 'Mismatch items';
        pub const CALLER_NOT_OFFERER: felt252 = 'Caller not offerer';
        pub const UNSUPPORTED_TOKEN_STANDARD: felt252 = 'Unsupported token';
        pub const INVALID_AMOUNT: felt252 = 'Invalid amount';
        pub const NATIVE_TRANSFER_FAILED: felt252 = 'STRK transfer failed';
        pub const INVALID_ORDER_LENGTHS: felt252 = 'Invalid item lengths';
        pub const HASH_SERIALIZATION_FAILED: felt252 = 'Hash serialization failed';
    }

    const CHAIN_ID: felt252 = 0x534e5f4d41494e;
    const STRK_TOKEN_ADDRESS: felt252 = 0xCa14007Eff0dB1f8135f4C25B34De49AB0d42766;
    #[derive(Drop, Copy, Serde, starknet::Store, PartialEq)]
    pub enum ItemType {
        NATIVE, // STRK
        ERC20,
        ERC721,
        ERC1155,
    }

    #[derive(Drop, Copy, Serde)]
    pub struct OfferItem {
        item_type: ItemType,
        token: ContractAddress, // Contract address of the token (0 for NATIVE STRK)    
        identifier_or_criteria: u256, // Token ID for ERC721/ERC1155, 0 for NATIVE/ERC20
        start_amount: u256, // Amount for NATIVE/ERC20/ERC1155, 1 for ERC721
        end_amount: u256 // Usually same as start_amount for fixed price
    }

    #[derive(Drop, Copy, Serde)]
    pub struct ConsiderationItem {
        item_type: ItemType,
        token: ContractAddress, // Contract address of the token (0 for NATIVE STRK)
        identifier_or_criteria: u256, // Token ID for ERC721/ERC1155, 0 for NATIVE/ERC20
        start_amount: u256, // Amount for NATIVE/ERC20/ERC1155, 1 for ERC721
        end_amount: u256, // Usually same as start_amount for fixed price
        recipient: ContractAddress // Address that receives this consideration item
    }

    #[derive(Drop, Clone, Serde)]
    pub struct OrderParameters {
        offerer: ContractAddress,
        offer: Array<OfferItem>,
        consideration: Array<ConsiderationItem>,
        start_time: u64, // Unix timestamp
        end_time: u64, // Unix timestamp, 0 for no expiry
        zone: ContractAddress, // Optional zone for advanced features (e.g., validation), 0 if unused
        zone_hash: felt252, // Optional hash for zone data, 0 if unused
        salt: felt252, // Random salt for uniqueness
        nonce: u128 // Offerer's nonce for this order
    }

    // Order structure including signature
    #[derive(Drop, Clone, Serde)]
    pub struct Order {
        parameters: OrderParameters,
        signature: Array<felt252> // ECDSA sig [r, s, pub_key]
    }

    // Status of an order hash
    #[derive(Drop, Copy, Serde, starknet::Store, PartialEq)]
    pub enum OrderFillStatus {
        Unfilled,
        Filled,
        Cancelled,
        // PartiallyFilled, // Could add for partial fills
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        OrderFulfilled: OrderFulfilled,
        OrderCancelled: OrderCancelled,
        NonceIncremented: NonceIncremented,
    }

    #[derive(Drop, starknet::Event)]
    struct OrderFulfilled {
        #[key]
        order_hash: felt252,
        #[key]
        offerer: ContractAddress,
        #[key]
        fulfiller: ContractAddress,
        zone: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct OrderCancelled {
        #[key]
        order_hash: felt252,
        #[key]
        offerer: ContractAddress,
        zone: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct NonceIncremented {
        #[key]
        offerer: ContractAddress,
        new_nonce: u128,
    }

    #[storage]
    struct Storage {
        // Mapping: offerer address -> current nonce
        _nonces: Map<ContractAddress, u128>,
        // Mapping: order hash -> OrderFillStatus
        _order_status: Map<felt252, OrderFillStatus>,
        // Store domain separator info
        _chain_id: felt252,
        _contract_address_felt: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self._chain_id.write(CHAIN_ID);
        self._contract_address_felt.write(get_contract_address().into());
    }


    #[abi(embed_v0)]
    impl MedialaneImpl of IMedialane<ContractState> {
        /// @notice Fulfills an order, transferring items between offerer and fulfiller.
        /// @param order The complete order struct including parameters and signature.
        /// @dev The caller of this function is the fulfiller.
        /// @dev Ensures validity, checks status, verifies signature, executes transfers, and marks
        /// order as filled.
        fn fulfill_order(ref self: ContractState, order: Order) {
            let caller = get_caller_address(); // Fulfiller
            let order_parameters = order.parameters.clone(); // Clone needed for multiple uses

            // Compute Order Hash
            let order_hash = self._compute_order_hash(order_parameters.clone());

            // Validate Order (Timing, Nonce, Status)
            self
                ._validate_order_status(
                    order_hash, order_parameters.offerer, order_parameters.nonce,
                );
            self._validate_order_timing(order_parameters.start_time, order_parameters.end_time);

            // Verify Signature (Check if offerer signed this order hash)
            assert(order.signature.len() == 3, errors::INVALID_SIGNATURE);
            let is_valid = self
                ._is_valid_offerer_signature(
                    order_parameters.offerer,
                    order_hash,
                    *order.signature[0],
                    *order.signature[1],
                    *order.signature[2],
                );
            assert(is_valid, errors::INVALID_SIGNATURE);

            // 4. Update Order Status
            self._order_status.write(order_hash, OrderFillStatus::Filled);

            // 5. Execute Transfers (Interaction)
            self._execute_transfers(order_parameters.clone(), caller);

            // 6. Emit Event
            self
                .emit(
                    Event::OrderFulfilled(
                        OrderFulfilled {
                            order_hash: order_hash,
                            offerer: order_parameters.offerer,
                            fulfiller: caller,
                            zone: order_parameters.zone,
                        },
                    ),
                );
        }

        /// @notice Cancels one or more orders created by the caller.
        /// @param orders_to_cancel An array of OrderParameters structs to cancel.
        /// @dev Only the offerer can cancel their own orders.
        fn cancel_orders(ref self: ContractState, orders_to_cancel: Array<OrderParameters>) {
            let caller = get_caller_address();
            let mut i = 0;
            let len = orders_to_cancel.len();
            while i < len {
                let order_params = orders_to_cancel.at(i).clone();
                // Ensure caller is the offerer
                assert(caller == order_params.offerer, errors::CALLER_NOT_OFFERER);

                let order_hash = self._compute_order_hash(order_params.clone());
                let current_status = self._order_status.read(order_hash);

                // Check if already filled or cancelled
                assert(current_status != OrderFillStatus::Filled, errors::ORDER_ALREADY_FILLED);
                if current_status != OrderFillStatus::Cancelled {
                    // Check nonce validity (optional, but good practice)
                    // let current_nonce = self._nonces.read(caller);
                    // assert(order_params.nonce == current_nonce, errors::INVALID_NONCE); //
                    // Strict: Only current nonce orders cancellable this way OR allow cancellation
                    // of any non-filled/non-cancelled order regardless of nonce progression:
                    assert(
                        order_params.nonce >= self._nonces.read(caller), errors::INVALID_NONCE,
                    ); // Check if nonce is current or future (though future makes less sense here)

                    // Mark as cancelled
                    self._order_status.write(order_hash, OrderFillStatus::Cancelled);

                    // Emit event
                    self
                        .emit(
                            Event::OrderCancelled(
                                OrderCancelled {
                                    order_hash: order_hash,
                                    offerer: caller, // which is order_params.offerer
                                    zone: order_params.zone,
                                },
                            ),
                        );
                }
                i += 1;
            }
        }

        /// @notice Increments the caller's nonce, effectively invalidating all orders signed with
        /// previous nonces.
        /// @dev Useful for bulk-invalidating outstanding orders.
        fn increment_nonce(ref self: ContractState) {
            let caller = get_caller_address();
            let current_nonce = self._nonces.read(caller);
            let new_nonce = current_nonce + 1;

            assert(new_nonce > current_nonce, 'Nonce overflow');
            self._nonces.write(caller, new_nonce);

            self.emit(Event::NonceIncremented(NonceIncremented { offerer: caller, new_nonce }));
        }

        /// @notice Gets the current nonce for a given offerer.
        /// @param offerer The address of the offerer.
        /// @return The current nonce.
        fn get_nonce(self: @ContractState, offerer: ContractAddress) -> u128 {
            self._nonces.read(offerer)
        }

        /// @notice Gets the status of an order given its hash.
        /// @param order_hash The hash of the order.
        /// @return The status (Unfilled, Filled, Cancelled).
        fn get_order_status(self: @ContractState, order_hash: felt252) -> OrderFillStatus {
            self._order_status.read(order_hash)
        }

        /// @notice Computes the EIP-712 style hash for a given order's parameters.
        /// @param parameters The OrderParameters struct.
        /// @return The computed order hash.
        fn get_order_hash(self: @ContractState, parameters: OrderParameters) -> felt252 {
            self._compute_order_hash(parameters)
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        /// @dev Computes the hash of the order parameters, including domain separation.
        fn _compute_order_hash(self: @ContractState, parameters: OrderParameters) -> felt252 {
            // 1. Hash the OrderParameters struct contents
            // Need to serialize the struct into a felt252 array first
            let mut parameters_felts: Array<felt252> = array![];
            // Manual serialization or use derived Serde trait if hashing supports it directly
            parameters.serialize(ref parameters_felts);
            let parameters_hash = poseidon_hash_span(parameters_felts.span());

            // 2. Define Domain Separator components
            // EIP-712 style domain separator hash
            // This requires hashing specific fields like name, version, chainId, verifyingContract
            // For simplicity here, we'll use chain_id and contract address directly
            // A more robust implementation would hash a struct representing the domain.
            let chain_id_val: felt252 = self._chain_id.read();
            let contract_addr_val: felt252 = self._contract_address_felt.read();

            let mut domain_info: Array<felt252> =
                array![ // Basic domain info - could be expanded per EIP-712 standard
                chain_id_val, contract_addr_val,
            ];

            let domain_hash = poseidon_hash_span(domain_info.span());

            // 3. Combine domain hash and parameters hash
            // Simplified: H(domain_hash, parameters_hash)
            let order_hash_params = array![domain_hash, parameters_hash];

            return poseidon_hash_span(order_hash_params.span());
        }


        /// @dev Validates the order's timing constraints.
        fn _validate_order_timing(self: @ContractState, start_time: u64, end_time: u64) {
            let current_timestamp = get_block_timestamp();
            assert(current_timestamp >= start_time, errors::ORDER_NOT_YET_VALID);
            // Only check end_time if it's non-zero (0 means no expiry)
            if end_time != 0 {
                assert(current_timestamp < end_time, errors::ORDER_EXPIRED);
            }
        }

        /// @dev Validates the order's status (nonce, filled, cancelled). Reverts if invalid.
        fn _validate_order_status(
            ref self: ContractState, order_hash: felt252, offerer: ContractAddress, nonce: u128,
        ) {
            // Check nonce
            let current_nonce = self._nonces.read(offerer);
            assert(nonce == current_nonce, errors::INVALID_NONCE);

            // Check filled/cancelled status
            let status = self._order_status.read(order_hash);
            assert(
                status == OrderFillStatus::Unfilled,
                {
                    if status == OrderFillStatus::Filled {
                        errors::ORDER_ALREADY_FILLED
                    } else { // Must be Cancelled
                        errors::ORDER_CANCELLED
                    }
                },
            );
        }

        /// @dev Verifies the ECDSA signature against the order hash and offerer address.
        fn _is_valid_offerer_signature(
            self: @ContractState,
            offerer: ContractAddress,
            order_hash: felt252,
            sig_r: felt252,
            sig_s: felt252,
            pub_key: felt252,
            //signature: Signature // r, s, y-parity
        ) -> bool {
            ///let pub_key = recover_public_key(
            ///    order_hash, signature.r, signature.s, signature.y_parity,
            ///);
            let is_valid = check_ecdsa_signature(order_hash, pub_key, sig_r, sig_s);

            return is_valid;
        }

        /// @dev Executes the actual asset transfers based on the order parameters.
        fn _execute_transfers(
            ref self: ContractState, parameters: OrderParameters, fulfiller: ContractAddress,
        ) {
            let offerer = parameters.offerer;

            // Process Offers: Offerer -> Fulfiller
            let mut offer_items = parameters.offer.clone();
            let mut offer_idx = 0;
            let offer_len = offer_items.len();
            assert(offer_len > 0, errors::INVALID_ORDER_LENGTHS); // Must offer something

            while offer_idx < offer_len {
                let item = offer_items.at(offer_idx);
                // Note: Recipient for offered items is always the fulfiller
                self
                    ._transfer_item(
                        *item.start_amount,
                        *item.end_amount,
                        Some(*item.token),
                        *item.item_type,
                        Some(*item.identifier_or_criteria),
                        offerer,
                        fulfiller,
                    );
                // self._transfer_item(*item, offerer, fulfiller);
                offer_idx += 1;
            }

            // Process Considerations: Fulfiller -> Recipient specified in item
            let mut consideration_items = parameters.consideration.clone();
            let mut cons_idx = 0;
            let cons_len = consideration_items.len();
            assert(cons_len > 0, errors::INVALID_ORDER_LENGTHS); // Must expect something

            while cons_idx < cons_len {
                let item = consideration_items.at(cons_idx);
                assert(*item.recipient != 0.try_into().unwrap(), 'Recipient cannot be zero');
                // Sender for consideration items is always the fulfiller
                self
                    ._transfer_item(
                        *item.start_amount,
                        *item.end_amount,
                        Some(*item.token),
                        *item.item_type,
                        Some(*item.identifier_or_criteria),
                        fulfiller,
                        *item.recipient,
                    );
                cons_idx += 1;
            }
        }


        /// @dev Helper function to transfer a single item based on its type.
        /// @param item The item to be transferred (STRK/ERC-20/ERC-721/ERC-1155).
        /// @param from The address sending the item.
        /// @param to The address receiving the item.
        fn _transfer_item(
            ref self: ContractState,
            start_amount: u256,
            end_amount: u256,
            token: Option<ContractAddress>,
            item_type: ItemType,
            identifier_or_criteria: Option<u256>,
            from: ContractAddress,
            to: ContractAddress,
        ) {
            // assert(start_amount == end_amount, 'Price ramping not implemented');
            assert(start_amount > 0.into(), errors::INVALID_AMOUNT);

            match item_type {
                ItemType::NATIVE => {
                    let dispatcher = IERC20Dispatcher {
                        contract_address: STRK_TOKEN_ADDRESS.try_into().unwrap(),
                    };
                    // Need allowance: `from` must approve this contract address
                    let success = dispatcher.transfer_from(from, to, start_amount);
                    assert(success, errors::NATIVE_TRANSFER_FAILED);
                },
                ItemType::ERC20 => {
                    let dispatcher = IERC20Dispatcher { contract_address: token.unwrap() };
                    // Need allowance: `from` must approve this contract address
                    let success = dispatcher.transfer_from(from, to, start_amount);
                    assert(success, errors::TRANSFER_FAILED);
                },
                ItemType::ERC721 => {
                    assert(start_amount == 1.into(), errors::INVALID_AMOUNT);
                    let dispatcher = IERC721Dispatcher { contract_address: token.unwrap() };

                    dispatcher.transfer_from(from, to, identifier_or_criteria.unwrap());
                },
                ItemType::ERC1155 => {
                    let dispatcher = IERC1155Dispatcher { contract_address: token.unwrap() };
                    // Need approval: `from` must setApprovalForAll for this contract address
                    dispatcher
                        .safe_transfer_from(
                            from,
                            to,
                            identifier_or_criteria.unwrap(),
                            start_amount,
                            array![].span(),
                        );
                },
            }
        }
    }
}

#[starknet::interface]
trait IMedialane<TState> {
    fn fulfill_order(ref self: TState, order: medialane::Order);
    fn cancel_orders(ref self: TState, orders_to_cancel: Array<medialane::OrderParameters>);
    fn increment_nonce(ref self: TState);
    fn get_nonce(self: @TState, offerer: starknet::ContractAddress) -> u128;
    fn get_order_status(self: @TState, order_hash: felt252) -> medialane::OrderFillStatus;
    fn get_order_hash(self: @TState, parameters: medialane::OrderParameters) -> felt252;
}
