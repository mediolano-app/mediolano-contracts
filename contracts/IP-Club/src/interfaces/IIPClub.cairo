use starknet::ContractAddress;
use crate::types::ClubRecord;

#[starknet::interface]
pub trait IIPClub<TContractState> {
    fn create_club(
        ref self: TContractState,
        name: ByteArray,
        symbols: ByteArray,
        metadata_uri: ByteArray,
        max_members: Option<u32>,
        entry_fee: Option<u256>,
        payment_token: Option<ContractAddress>,
    );
    fn close_club(ref self: TContractState, club_id: u256);
    fn join_club(ref self: TContractState, club_id: u256);
    fn get_club_record(self: @TContractState, club_id: u256) -> ClubRecord;
    fn is_member(self: @TContractState, club_id: u256, user: ContractAddress) -> bool;
}

