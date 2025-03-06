use starknet::ContractAddress;

#[starknet::interface]
pub trait INFTAirdrop<TContractState> {
    fn whitelist(ref self: TContractState, to: ContractAddress, amount: u32);
    fn whitelist_balance_of(self: @TContractState, to: ContractAddress) -> u32;
    fn airdrop(ref self: TContractState);
    fn claim_with_proof(ref self: TContractState, proof: Span<felt252>, amount: u32);
}
