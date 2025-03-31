use ip_syndication::types::{IPMetadata, SyndicationDetails, Status, Mode, ParticipantDetails};
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
        currency_address: ContractAddress,
    ) -> u256;

    fn update_whitelist(
        ref self: TContractState, ip_id: u256, address: ContractAddress, status: bool
    );
    fn deposit(ref self: TContractState, ip_id: u256, amount: u256);
    fn mint_asset(ref self: TContractState, ip_id: u256);
    fn is_whitelisted(self: @TContractState, ip_id: u256, address: ContractAddress) -> bool;
    fn cancel_syndication(ref self: TContractState, ip_id: u256);
    fn activate_syndication(ref self: TContractState, ip_id: u256);

    fn get_ip_metadata(self: @TContractState, ip_id: u256) -> IPMetadata;
    fn get_all_participants(self: @TContractState, ip_id: u256) -> Span<ContractAddress>;
    fn get_syndication_details(self: @TContractState, ip_id: u256) -> SyndicationDetails;
    fn get_participant_details(
        self: @TContractState, ip_id: u256, participant: ContractAddress
    ) -> ParticipantDetails;
    fn get_syndication_status(self: @TContractState, ip_id: u256) -> Status;
    fn get_participant_count(self: @TContractState, ip_id: u256) -> u256;
}

