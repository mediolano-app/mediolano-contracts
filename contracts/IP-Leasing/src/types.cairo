use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Lease {
    pub lessee: ContractAddress,
    pub amount: u256,
    pub start_time: u64,
    pub end_time: u64,
    pub is_active: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct LeaseOffer {
    pub owner: ContractAddress,
    pub amount: u256,
    pub lease_fee: u256,
    pub duration: u64,
    pub license_terms_uri: ByteArray,
    pub is_active: bool,
}

// CollectiveIPAgreement errors
pub const MISMATCHED_OWNERS_SHARES: felt252 = 'MISMATCHED_OWNERS_SHARES';
pub const NO_OWNERS: felt252 = 'NO_OWNERS';
pub const INVALID_ROYALTY_RATE: felt252 = 'INVALID_ROYALTY_RATE';
pub const INVALID_SHARES_SUM: felt252 = 'INVALID_SHARES_SUM';
pub const NO_IP_DATA: felt252 = 'NO_IP_DATA';
pub const NOT_OWNER: felt252 = 'NOT_OWNER';
pub const PROPOSAL_EXECUTED: felt252 = 'PROPOSAL_EXECUTED';
pub const VOTING_ENDED: felt252 = 'VOTING_ENDED';
pub const ALREADY_VOTED: felt252 = 'ALREADY_VOTED';
pub const VOTING_NOT_ENDED: felt252 = 'VOTING_NOT_ENDED';
pub const INSUFFICIENT_VOTES: felt252 = 'INSUFFICIENT_VOTES';
pub const NOT_DISPUTE_RESOLVER: felt252 = 'NOT_DISPUTE_RESOLVER';
pub const INVALID_METADATA_URI: felt252 = 'INVALID_METADATA_URI';
