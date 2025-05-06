use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct IPAssetLinked {
    pub ip_token_id: u256,
    pub ip_token_address: ContractAddress,
    pub owner: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct IPAssetUnLinked {
    pub ip_token_id: u256,
    pub ip_token_address: ContractAddress,
    pub owner: ContractAddress,
    pub timestamp: u64,
}


#[derive(Drop, starknet::Event)]
pub struct FranchiseAgreementCreated {
    pub agreement_id: u256,
    pub agreement_address: ContractAddress,
    pub franchisee: ContractAddress,
    pub timestamp: u64,
}


#[derive(Drop, starknet::Event)]
pub struct NewFranchiseApplication {
    pub application_id: u256,
    pub franchisee: ContractAddress,
    pub timestamp: u64,
}


#[derive(Drop, starknet::Event)]
pub struct FranchiseApplicationRevised {
    pub application_id: u256,
    pub reviser: ContractAddress,
    pub application_version: u8,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ApplicationRevisionAccepted {
    pub application_id: u256,
    pub franchisee: ContractAddress,
    pub timestamp: u64,
}


#[derive(Drop, starknet::Event)]
pub struct FranchiseApplicationCanceled {
    pub application_id: u256,
    pub franchisee: ContractAddress,
    pub timestamp: u64,
}


#[derive(Drop, starknet::Event)]
pub struct FranchiseApplicationApproved {
    pub application_id: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct FranchiseApplicationRejected {
    pub application_id: u256,
    pub timestamp: u64,
}


#[derive(Drop, starknet::Event)]
pub struct FranchiseSaleInitiated {
    pub agreement_id: u256,
    pub sale_id: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct FranchiseSaleApproved {
    pub agreement_id: u256,
    pub agreement_address: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct FranchiseSaleRejected {
    pub agreement_id: u256,
    pub agreement_address: ContractAddress,
    pub timestamp: u64,
}


#[derive(Drop, starknet::Event)]
pub struct FranchiseAgreementRevoked {
    pub agreement_id: u256,
    pub agreement_address: ContractAddress,
    pub timestamp: u64,
}


#[derive(Drop, starknet::Event)]
pub struct FranchiseAgreementReinstated {
    pub agreement_id: u256,
    pub agreement_address: ContractAddress,
    pub timestamp: u64,
}


#[derive(Drop, starknet::Event)]
pub struct FranchiseAgreementActivated {
    pub agreement_id: u256,
    pub timestamp: u64,
}


#[derive(Drop, starknet::Event)]
pub struct SaleRequestInitiated {
    pub agreement_id: u256,
    pub sale_price: u256,
    pub to: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct SaleRequestApproved {
    pub agreement_id: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct SaleRequestRejected {
    pub agreement_id: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct SaleRequestFinalized {
    pub agreement_id: u256,
    pub new_franchisee: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RoyaltyPaymentMade {
    pub agreement_id: u256,
    pub total_royalty: u256,
    pub total_revenue: u256,
    pub timestamp: u64,
}


#[derive(Drop, starknet::Event)]
pub struct FranchiseLicenseRevoked {
    pub agreement_id: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct FranchiseLicenseReinstated {
    pub agreement_id: u256,
    pub timestamp: u64,
}


#[derive(Drop, starknet::Event)]
pub struct NewTerritoryAdded {
    pub territory_id: u256,
    pub name: ByteArray,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct TerritoryDeactivated {
    pub territory_id: u256,
    pub timestamp: u64,
}

