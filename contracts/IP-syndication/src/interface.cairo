use ip_syndication::types::{IPMetadata, SyndicationDetails, Status, Mode, ParticipantsDetails};
use starknet::{ContractAddress};

#[starknet::interface]
pub trait IIPSyndication<TContractState> {
    fn register_ip(
        ref self: TContractState,
        price: u256,
        name: felt252,
        description: ByteArray,
        uri: ByteArray,
        licensing_terms: felt252,
        mode: Mode,
        // collection_id: felt252
    );

    fn update_whitelist(
        ref self: TContractState, ip_id: u256, address: ContractAddress, status: bool
    );

    //TODO: batch update whitelist

    fn deposit(ref self: TContractState, ip_id: u256, amount: u256);

    fn cancel_syndication(ref self: TContractState, ip_id: u256);

    fn get_ip_metadata(self: @TContractState, ip_id: u256) -> IPMetadata;
    fn get_all_participants(self: @TContractState, ip_id: u256) -> Span<ContractAddress>;
    fn get_syndication_details(self: @TContractState, ip_id: u256) -> SyndicationDetails;
    fn is_whitelisted(self: @TContractState, address: ContractAddress, ip_id: u256) -> bool;

    fn get_participant_details(
        self: @TContractState, ip_id: u256, participant: ContractAddress
    ) -> ParticipantDetails;

    fn get_syndication_status(self: @TContractState, ip_id: u256) -> Status;
}

