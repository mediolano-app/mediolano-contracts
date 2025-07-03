use starknet::ContractAddress;

#[starknet::interface]
pub trait IRevenueDistribution<TContractState> {
    fn receive_revenue(
        ref self: TContractState, asset_id: u256, token_address: ContractAddress, amount: u256,
    ) -> bool;

    fn distribute_revenue(
        ref self: TContractState, asset_id: u256, token_address: ContractAddress, amount: u256,
    ) -> bool;

    fn distribute_all_revenue(
        ref self: TContractState, asset_id: u256, token_address: ContractAddress,
    ) -> bool;

    // Withdrawal functions
    fn withdraw_pending_revenue(
        ref self: TContractState, asset_id: u256, token_address: ContractAddress,
    ) -> u256;

    fn get_accumulated_revenue(
        self: @TContractState, asset_id: u256, token_address: ContractAddress,
    ) -> u256;

    // Revenue tracking
    fn get_pending_revenue(
        self: @TContractState,
        asset_id: u256,
        owner: ContractAddress,
        token_address: ContractAddress,
    ) -> u256;

    fn get_total_revenue_distributed(
        self: @TContractState, asset_id: u256, token_address: ContractAddress,
    ) -> u256;

    fn get_owner_total_earned(
        self: @TContractState,
        asset_id: u256,
        owner: ContractAddress,
        token_address: ContractAddress,
    ) -> u256;

    // Settings
    fn set_minimum_distribution(
        ref self: TContractState, asset_id: u256, min_amount: u256, token_address: ContractAddress,
    ) -> bool;
    fn get_minimum_distribution(
        self: @TContractState, asset_id: u256, token_address: ContractAddress,
    ) -> u256;
}
