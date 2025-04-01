// Define the contract interface
#[starknet::interface]
pub trait ISubscription<TContractState> {
    fn create_plan(
        ref self: TContractState,
        plan_id: felt252,
        price: u256,
        duration: u64,
        tier: felt252
    );
    fn subscribe(ref self: TContractState, plan_id: felt252);
    fn unsubscribe(ref self: TContractState);
    fn renew_subscription(ref self: TContractState);
    fn upgrade_subscription(ref self: TContractState, new_plan_id: felt252);
    fn get_subscription_status(self: @TContractState) -> bool;
    fn get_plan_details(self: @TContractState, plan_id: felt252) -> (u256, u64, felt252);
}