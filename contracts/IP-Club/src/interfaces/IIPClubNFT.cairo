use starknet::ContractAddress;

#[starknet::interface]
pub trait IIPClubNFT<TContractState> {
    // Mintable functions
    fn mint(ref self: TContractState, recipient: ContractAddress);

    // Get functions
    fn has_nft(self: @TContractState, user: ContractAddress) -> bool;
    fn get_nft_creator(self: @TContractState) -> ContractAddress;
    fn get_ip_club_manager(self: @TContractState) -> ContractAddress;
    fn get_associated_club_id(self: @TContractState) -> u256;
    fn get_last_minted_id(self: @TContractState) -> u256;
}
