use starknet::ContractAddress;

// *************************************************************************
//                              INTERFACE of IP LICENSING AGREEMENT
// *************************************************************************
#[starknet::interface]
pub trait IIPLicensingAgreement<TContractState> {
    // Sign the agreement
    fn sign_agreement(ref self: TContractState);

    // Make the agreement immutable (only owner)
    fn make_immutable(ref self: TContractState);

    // Add additional metadata (only owner and only if not immutable)
    fn add_metadata(ref self: TContractState, key: felt252, value: felt252);

    // Get agreement metadata
    fn get_metadata(self: @TContractState) -> (ByteArray, ByteArray, ByteArray, u64, bool, u64);

    // Get additional metadata
    fn get_additional_metadata(self: @TContractState, key: felt252) -> felt252;

    // Check if address is a signer
    fn is_signer(self: @TContractState, address: ContractAddress) -> bool;

    // Check if address has signed
    fn has_signed(self: @TContractState, address: ContractAddress) -> bool;

    // Get signature timestamp
    fn get_signature_timestamp(self: @TContractState, address: ContractAddress) -> u64;

    // Get all signers
    fn get_signers(self: @TContractState) -> Array<ContractAddress>;

    // Get signer count
    fn get_signer_count(self: @TContractState) -> u256;

    // Get signature count
    fn get_signature_count(self: @TContractState) -> u256;

    // Check if agreement is fully signed
    fn is_fully_signed(self: @TContractState) -> bool;

    // Get factory address
    fn get_factory(self: @TContractState) -> ContractAddress;

    // Get owner
    fn get_owner(self: @TContractState) -> ContractAddress;
}
