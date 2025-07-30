use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin_utils::snip12::StructHash;
use starknet::ContractAddress;
use crate::core::utils::order_parameters_type_hash;

#[derive(Drop, Copy, Serde, PartialEq, Hash, starknet::Store)]
pub enum ItemType {
    #[default]
    NATIVE, // STRK
    ERC20,
    ERC721,
    ERC1155,
}

#[derive(Drop, Copy, Serde, Hash, starknet::Store)]
pub struct OfferItem {
    pub item_type: ItemType,
    pub token: ContractAddress, // Contract address of the token (0 for NATIVE STRK)    
    pub identifier_or_criteria: u256, // Token ID for ERC721/ERC1155, 0 for NATIVE/ERC20
    pub start_amount: u256, // Amount for NATIVE/ERC20/ERC1155, 1 for ERC721
    pub end_amount: u256,
}

#[derive(Drop, Copy, Serde, Hash, starknet::Store)]
pub struct ConsiderationItem {
    pub item_type: ItemType,
    pub token: ContractAddress, // Contract address of the token (0 for NATIVE STRK)
    pub identifier_or_criteria: u256, // Token ID for ERC721/ERC1155, 0 for NATIVE/ERC20
    pub start_amount: u256, // Amount for NATIVE/ERC20/ERC1155, 1 for ERC721
    pub end_amount: u256, // Usually same as start_amount for fixed price
    pub recipient: ContractAddress // Address that receives this consideration item
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct OrderDetails {
    pub offerer: ContractAddress,
    pub offer: OfferItem,
    pub consideration: ConsiderationItem,
    pub start_time: u64,
    pub end_time: u64,
    pub order_status: OrderStatus,
}

#[derive(Drop, Clone, Copy, Serde, Hash)]
pub struct OrderParameters {
    pub offerer: ContractAddress,
    pub offer: OfferItem,
    pub consideration: ConsiderationItem,
    pub start_time: u64,
    pub end_time: u64,
    pub salt: felt252,
    pub nonce: felt252,
}

impl OrderParametersHashImpl of StructHash<OrderParameters> {
    fn hash_struct(self: @OrderParameters) -> felt252 {
        let hash_state = PoseidonTrait::new();
        let message_type_hash = order_parameters_type_hash();
        hash_state.update_with(message_type_hash).update_with(*self).finalize()
    }
}

#[derive(Drop, Clone, Copy, Serde, Hash)]
pub struct OrderFulfillment {
    pub order_hash: felt252,
    pub fulfiller: ContractAddress,
    pub nonce: felt252,
}

impl OrderFulfillmentHashImpl of StructHash<OrderFulfillment> {
    fn hash_struct(self: @OrderFulfillment) -> felt252 {
        let hash_state = PoseidonTrait::new();
        let message_type_hash = order_parameters_type_hash();
        hash_state.update_with(message_type_hash).update_with(*self).finalize()
    }
}

#[derive(Drop, Clone, Copy, Serde, Hash)]
pub struct OrderCancellation {
    pub order_hash: felt252,
    pub offerer: ContractAddress,
    pub nonce: felt252,
}

impl OrderCancellationHashImpl of StructHash<OrderCancellation> {
    fn hash_struct(self: @OrderCancellation) -> felt252 {
        let hash_state = PoseidonTrait::new();
        let message_type_hash = order_parameters_type_hash();
        hash_state.update_with(message_type_hash).update_with(*self).finalize()
    }
}

#[derive(Drop, Serde)]
pub struct FulfillmentRequest {
    pub fulfillment: OrderFulfillment,
    pub signature: Array<felt252>,
}

#[derive(Drop, Serde)]
pub struct CancelRequest {
    pub cancelation: OrderCancellation,
    pub signature: Array<felt252>,
}

#[derive(Drop, Serde)]
pub struct Order {
    pub parameters: OrderParameters,
    pub signature: Array<felt252>,
}

// Status of an order hash
#[derive(Drop, Debug, Copy, Serde, starknet::Store, PartialEq)]
pub enum OrderStatus {
    #[default]
    None, // Order hasn't been seen before
    Created, // Order is registered and live
    Filled, // Order was successfully matched and filled
    Cancelled // Order was cancelled by the user or system
}
