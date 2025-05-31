#[starknet::interface]
pub trait IIPSponsorship<TContractState> {
    // IP Management Functions
    fn register_ip(ref self: TContractState, ip_metadata: felt252, license_terms: felt252) -> felt252;
    fn update_ip_metadata(ref self: TContractState, ip_id: felt252, new_metadata: felt252);
    fn deactivate_ip(ref self: TContractState, ip_id: felt252);
    
    // Sponsorship Offer Functions
    fn create_sponsorship_offer(
        ref self: TContractState, 
        ip_id: felt252, 
        min_price: u256, 
        max_price: u256,
        duration: u64,
        specific_sponsor: Option<starknet::ContractAddress>
    ) -> felt252;
    fn cancel_sponsorship_offer(ref self: TContractState, offer_id: felt252);
    fn update_sponsorship_offer(ref self: TContractState, offer_id: felt252, new_min_price: u256, new_max_price: u256);
    
    // Sponsorship Functions
    fn sponsor_ip(ref self: TContractState, offer_id: felt252, bid_amount: u256);
    fn accept_sponsorship(ref self: TContractState, offer_id: felt252, sponsor: starknet::ContractAddress);
    fn reject_sponsorship(ref self: TContractState, offer_id: felt252, sponsor: starknet::ContractAddress);
    
    // License Management
    fn transfer_license(ref self: TContractState, license_id: felt252, new_owner: starknet::ContractAddress);
    fn revoke_license(ref self: TContractState, license_id: felt252);
    
    // View Functions
    fn get_ip_details(self: @TContractState, ip_id: felt252) -> (starknet::ContractAddress, felt252, felt252, bool);
    fn get_sponsorship_offer(self: @TContractState, offer_id: felt252) -> (felt252, u256, u256, u64, starknet::ContractAddress, bool, Option<starknet::ContractAddress>);
    fn get_user_ips(self: @TContractState, owner: starknet::ContractAddress) -> Array<felt252>;
    fn get_user_licenses(self: @TContractState, owner: starknet::ContractAddress) -> Array<felt252>;
    fn get_active_offers(self: @TContractState) -> Array<felt252>;
    fn get_sponsorship_bids(self: @TContractState, offer_id: felt252) -> Array<(starknet::ContractAddress, u256)>;
    fn is_license_valid(self: @TContractState, license_id: felt252) -> bool;
    fn get_license_details(self: @TContractState, license_id: felt252) -> (felt252, starknet::ContractAddress, starknet::ContractAddress, u256, u64, u64, bool, bool);
    fn get_user_offers(self: @TContractState, author: starknet::ContractAddress) -> Array<felt252>;
}
