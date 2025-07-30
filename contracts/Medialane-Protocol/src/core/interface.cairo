use starknet::ContractAddress;
use crate::core::types::*;

#[starknet::interface]
pub trait IMedialane<TState> {
    fn register_order(ref self: TState, order: Order);
    fn fulfill_order(ref self: TState, fulfillment_request: FulfillmentRequest);
    fn cancel_order(ref self: TState, cancel_request: CancelRequest);
    fn get_order_details(self: @TState, order_hash: felt252) -> OrderDetails;
    fn get_order_hash(
        self: @TState, parameters: OrderParameters, signer: ContractAddress,
    ) -> felt252;
}
