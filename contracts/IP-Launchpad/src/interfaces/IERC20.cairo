use starknet::ContractAddress;


#[starknet::interface]
pub trait IERC20<TState> {
    /// Returns the total supply of tokens.
    fn total_supply(self: @TState) -> u256;

    /// Returns the amount of tokens owned by `account`.
    fn balance_of(self: @TState, account: ContractAddress) -> u256;

    /// Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of
    /// `owner` through `transfer_from`.
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;

    /// Moves `amount` tokens from the caller's account to `recipient`.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;

    /// Moves `amount` tokens from `sender` to `recipient` using the allowance mechanism.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;

    /// Sets `amount` as the allowance of `spender` over the caller's tokens.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
}