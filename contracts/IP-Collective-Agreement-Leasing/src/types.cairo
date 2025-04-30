use core::starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct IPData {
    pub metadata_uri: ByteArray, // IP metadata stored on IPFS
    pub owner_count: u32, // Number of owners (to track the list size)
    pub royalty_rate: u256, // Royalty percentage (e.g., 50 = 5%)
    pub expiry_date: u64, // Expiry of the IP agreement
    pub license_terms: ByteArray, // Licensing terms (e.g., JSON or IPFS hash)
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Proposal {
    pub proposer: ContractAddress,
    pub description: ByteArray,
    pub vote_count: u256,
    pub executed: bool,
    pub deadline: u64,
}

// Error messages as constants
pub const INVALID_METADATA_URI: felt252 = 'Invalid metadata URI';
pub const MISMATCHED_OWNERS_SHARES: felt252 = 'Mismatched owners and shares';
pub const NO_OWNERS: felt252 = 'At least one owner required';
pub const INVALID_ROYALTY_RATE: felt252 = 'Royalty rate exceeds 100%';
pub const INVALID_SHARES_SUM: felt252 = 'Shares must sum to 100%';
pub const NO_IP_DATA: felt252 = 'No IP data found';
pub const NOT_OWNER: felt252 = 'Not an owner';
pub const PROPOSAL_EXECUTED: felt252 = 'Proposal already executed';
pub const VOTING_ENDED: felt252 = 'Voting period ended';
pub const ALREADY_VOTED: felt252 = 'Already voted';
pub const VOTING_NOT_ENDED: felt252 = 'Voting period not ended';
pub const INSUFFICIENT_VOTES: felt252 = 'Insufficient votes';
pub const NOT_DISPUTE_RESOLVER: felt252 = 'Not dispute resolver';
