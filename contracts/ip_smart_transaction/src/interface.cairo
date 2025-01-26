use starknet::ContractAddress;

#[starknet::interface]
pub trait ERC721Escrow<TState> {
    fn create_escrow(ref self: TState, amount: u256, recipient: ContractAddress) -> felt252;

    fn update_escrow(ref self: TState, id: felt252, fulfilled: bool);

    fn check_escrow_and_transfer(ref self: TState, id: felt252);

    fn cancel_escrow(ref self: TState, id: felt252);

    fn get_escrow_details(self: @TState, id: felt252) -> (u256, ContractAddress);
}