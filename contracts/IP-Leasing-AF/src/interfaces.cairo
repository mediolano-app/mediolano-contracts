use starknet::ContractAddress;
use ip_leasing::types::{Lease, LeaseOffer};

#[starknet::interface]
pub trait IIPLeasing<TContractState> {
    fn create_lease_offer(
        ref self: TContractState,
        token_id: u256,
        amount: u256,
        lease_fee: u256,
        duration: u64,
        license_terms_uri: ByteArray,
    );
    fn cancel_lease_offer(ref self: TContractState, token_id: u256);
    fn start_lease(ref self: TContractState, token_id: u256);
    fn renew_lease(ref self: TContractState, token_id: u256, additional_duration: u64);
    fn expire_lease(ref self: TContractState, token_id: u256);
    fn terminate_lease(ref self: TContractState, token_id: u256, reason: ByteArray);
    fn mint_ip(ref self: TContractState, to: ContractAddress, token_id: u256, amount: u256);
    fn get_lease(self: @TContractState, token_id: u256) -> Lease;
    fn get_lease_offer(self: @TContractState, token_id: u256) -> LeaseOffer;
    fn get_active_leases_by_owner(self: @TContractState, owner: ContractAddress) -> Array<u256>;
    fn get_active_leases_by_lessee(self: @TContractState, lessee: ContractAddress) -> Array<u256>;
}
