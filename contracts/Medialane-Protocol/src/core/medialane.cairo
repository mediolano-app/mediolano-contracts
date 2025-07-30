#[starknet::contract]
pub mod MedialaneV2 {
    use openzeppelin_account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
    use openzeppelin_token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin_utils::cryptography::nonces::NoncesComponent;
    use openzeppelin_utils::snip12::{OffchainMessageHash, SNIP12Metadata};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp};
    use crate::core::errors::*;
    use crate::core::events::*;
    use crate::core::interface::*;
    use crate::core::types::*;

    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;
    impl NoncesInternalImpl = NoncesComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        nonces: NoncesComponent::Storage,
        order_status: Map<felt252, OrderStatus>,
        native_token_address: ContractAddress // STRK token address
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        NoncesEvent: NoncesComponent::Event,
        OrderCreated: OrderCreated,
        OrderFulfilled: OrderFulfilled,
        OrderCancelled: OrderCancelled,
    }

    /// Required for hash computation.
    impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'Medialane'
        }
        fn version() -> felt252 {
            'v1'
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, native_token_address: ContractAddress) {
        self.native_token_address.write(native_token_address);
    }

    #[abi(embed_v0)]
    impl MedialaneImpl of IMedialane<ContractState> {
        fn register_order(ref self: ContractState, order: Order) {
            let order_parameters = order.parameters;
            let signature = order.signature;

            let offerer = order_parameters.offerer;

            let order_hash = order_parameters.get_message_hash(offerer);

            self._validate_order_hash_signature(order_hash.clone(), offerer, signature);

            // Validate Order Status (Nonce, Not Filled/Cancelled)
            self._validate_order_status(order_hash, OrderStatus::None);

            // Validate Order Timing (Start/End Time)
            self._validate_order_timing(order_parameters.start_time, order_parameters.end_time);

            self.nonces.use_checked_nonce(offerer, order_parameters.nonce);

            self.order_status.write(order_hash, OrderStatus::Created);

            self
                .emit(
                    Event::OrderCreated(
                        OrderCreated { order_hash: order_hash, offerer: order_parameters.offerer },
                    ),
                );
        }

        fn fulfill_order(ref self: ContractState, order: Order, fulfiller: ContractAddress) {
            let order_parameters = order.parameters;
            let signature = order.signature;

            let order_hash = order_parameters.get_message_hash(fulfiller);

            self._validate_order_hash_signature(order_hash.clone(), fulfiller, signature);

            // Validate Order Status is Created
            self._validate_order_status(order_hash, OrderStatus::Created);

            // Validate Order Timing (Start/End Time)
            self._validate_order_timing(order_parameters.start_time, order_parameters.end_time);

            self.nonces.use_checked_nonce(fulfiller, order_parameters.nonce);

            // Execute Transfers (Interaction)
            self._execute_transfers(order_parameters, fulfiller);

            // Update Order Status
            self.order_status.write(order_hash, OrderStatus::Filled);

            self
                .emit(
                    Event::OrderFulfilled(
                        OrderFulfilled {
                            order_hash: order_hash,
                            offerer: order_parameters.offerer,
                            fulfiller: fulfiller,
                        },
                    ),
                );
        }

        fn cancel_order(ref self: ContractState, order: Order) {
            let order_parameters = order.parameters;
            let signature = order.signature;
            let offerer = order_parameters.offerer.clone();

            let order_hash = order_parameters.get_message_hash(offerer);

            self._validate_order_hash_signature(order_hash.clone(), offerer, signature);

            // Validate Order Status is Created
            self._validate_order_status(order_hash, OrderStatus::Created);

            self.nonces.use_checked_nonce(offerer, order_parameters.nonce);

            // Update Order Status
            self.order_status.write(order_hash, OrderStatus::Cancelled);

            self
                .emit(
                    Event::OrderCancelled(
                        OrderCancelled {
                            order_hash: order_hash, offerer: order_parameters.offerer,
                        },
                    ),
                );
        }

        fn get_order_status(self: @ContractState, order_hash: felt252) -> OrderStatus {
            self.order_status.read(order_hash)
        }

        fn get_order_hash(
            self: @ContractState, parameters: OrderParameters, signer: ContractAddress,
        ) -> felt252 {
            parameters.get_message_hash(signer)
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        /// Validates the order's timing constraints.
        fn _validate_order_timing(self: @ContractState, start_time: u64, end_time: u64) {
            let current_timestamp = get_block_timestamp();
            assert(current_timestamp >= start_time, errors::ORDER_NOT_YET_VALID);
            // Only check end_time if it's non-zero (0 means no expiry)
            if end_time != 0 {
                assert(current_timestamp < end_time, errors::ORDER_EXPIRED);
            }
        }

        /// Validates the order's status (nonce, filled, cancelled). Reverts if invalid.
        fn _validate_order_status(
            ref self: ContractState, order_hash: felt252, expected: OrderStatus,
        ) {
            let actual = self.order_status.read(order_hash);

            assert(
                actual == expected,
                match actual {
                    OrderStatus::None => errors::ORDER_NOT_FOUND,
                    OrderStatus::Created => errors::ORDER_ALREADY_CREATED,
                    OrderStatus::Filled => errors::ORDER_ALREADY_FILLED,
                    OrderStatus::Cancelled => errors::ORDER_CANCELLED,
                },
            );
        }

        /// Verifies the order signature against the order hash and signer address.
        fn _validate_order_hash_signature(
            self: @ContractState,
            order_hash: felt252,
            signer_address: ContractAddress,
            signature: Array<felt252>,
        ) {
            let is_valid_signature_felt = ISRC6Dispatcher { contract_address: signer_address }
                .is_valid_signature(order_hash, signature);

            let is_valid_signature = is_valid_signature_felt == starknet::VALIDATED
                || is_valid_signature_felt == 1;

            assert(is_valid_signature, errors::INVALID_SIGNATURE);
        }

        /// Executes the actual asset transfers based on the order parameters.
        fn _execute_transfers(
            ref self: ContractState, parameters: OrderParameters, fulfiller: ContractAddress,
        ) {
            let offerer = parameters.offerer;

            // Process Offers: Offerer -> Fulfiller
            let mut offer_item = parameters.offer.clone();

            // Note: Recipient for offered items is always the fulfiller
            self
                ._transfer_item(
                    offer_item.start_amount,
                    offer_item.end_amount,
                    Option::Some(offer_item.token),
                    offer_item.item_type,
                    Option::Some(offer_item.identifier_or_criteria),
                    offerer,
                    fulfiller,
                );

            // Process Considerations: Fulfiller -> Recipient specified in item
            let mut consideration_item = parameters.consideration.clone();

            assert(
                consideration_item.recipient != 0.try_into().unwrap(), 'Recipient cannot be zero',
            );
            // Sender for consideration items is always the fulfiller
            self
                ._transfer_item(
                    consideration_item.start_amount,
                    consideration_item.end_amount,
                    Option::Some(consideration_item.token),
                    consideration_item.item_type,
                    Option::Some(consideration_item.identifier_or_criteria),
                    fulfiller,
                    consideration_item.recipient,
                );
        }

        /// Transfers a single item of a specified type (NATIVE, ERC20, ERC721, or ERC1155) from one
        /// address to another.
        ///
        /// This is an internal helper function called by `_execute_transfers`. It handles the
        /// specific transfer logic based on the `item_type`.
        ///
        /// # Arguments
        /// * `start_amount:` - The amount of the item to transfer. For ERC721, this must be 1.
        /// * `end_amount` - The ending amount for the item.
        /// * `token` - The contract address of the token.
        /// * `item_type` - The type of the item to transfer.
        /// * `identifier_or_criteria` - The token ID for ERC721/ERC1155 items. Expected to be
        /// `Some(id)` for these types.
        /// * `from` - The address sending the item. This address must have approved the Medialane
        /// contract or have sufficient balance.
        /// * `to` - The address receiving the item.
        ///
        /// # Panics
        /// * `errors::INVALID_AMOUNT` if `start_amount` is zero, or if `start_amount` is not 1 for
        /// an `ERC721` item.
        /// * `errors::NATIVE_TRANSFER_FAILED` if the transfer of NATIVE (STRK) tokens fails.
        /// * `errors::TRANSFER_FAILED` if the transfer of ERC20 tokens fails.
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
            assert(start_amount > 0.into(), errors::INVALID_AMOUNT);

            match item_type {
                ItemType::NATIVE => {
                    let dispatcher = IERC20Dispatcher {
                        contract_address: self.native_token_address.read(),
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
                    // Need approval: `from` must setApprovalForAll for this contract address
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

