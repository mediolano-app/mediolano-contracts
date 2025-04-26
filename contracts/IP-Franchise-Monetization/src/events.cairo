use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct FranchiseAgreementCreated {
    agreement_id: u256,
    agreement_address: ContractAddress,
    franchisee: ContractAddress,
}

