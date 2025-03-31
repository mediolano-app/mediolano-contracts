use starknet::{ContractAddress, ClassHash};

// *************************************************************************
//                              INTERFACE of IP LICENSING FACTORY
// *************************************************************************
#[starknet::interface]
pub trait IIPLicensingFactory<TContractState> {
    // Create a new IP licensing agreement
    fn create_agreement(
        ref self: TContractState,
        title: ByteArray,
        description: ByteArray,
        ip_metadata: ByteArray,
        signers: Array<ContractAddress>,
    ) -> (u256, ContractAddress);

    // Get agreement address by ID
    fn get_agreement_address(self: @TContractState, agreement_id: u256) -> ContractAddress;

    // Get agreement ID by address
    fn get_agreement_id(self: @TContractState, agreement_address: ContractAddress) -> u256;

    // Get total number of agreements
    fn get_agreement_count(self: @TContractState) -> u256;

    // Get agreements for a specific user
    fn get_user_agreements(self: @TContractState, user: ContractAddress) -> Array<u256>;

    // Get number of agreements for a specific user
    fn get_user_agreement_count(self: @TContractState, user: ContractAddress) -> u256;

    // Update the agreement class hash (only owner)
    fn update_agreement_class_hash(ref self: TContractState, new_class_hash: ClassHash);

    // Get the current agreement class hash
    fn get_agreement_class_hash(self: @TContractState) -> ClassHash;
}
