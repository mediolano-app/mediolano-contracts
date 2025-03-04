use starknet::ContractAddress;

#[derive(Drop, Clone, Serde, starknet::Store)]
pub struct IPMetadata {
    pub ip_id: u256,
    pub owner: ContractAddress,
    pub price: u256,
    pub name: felt252,
    pub description: ByteArray,
    pub uri: ByteArray,
    pub licensing_terms: felt252,
    pub token_id: u256,
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct SyndicationDetails {
    pub ip_id: u256,
    pub status: Status,
    pub mode: Mode,
    pub total_raised: u256,
    pub participant_count: u256,
    pub currency_address: ContractAddress,
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct ParticipantDetails {
    pub address: ContractAddress,
    pub amount_deposited: u256,
    pub minted: bool,
    pub token_id: u256,
    pub amount_refunded: u256,
    pub share: u256
}


#[derive(Drop, Copy, Serde, PartialEq, starknet::Store)]
pub enum Status {
    #[default]
    Pending,
    Active,
    Completed,
    Cancelled,
}

#[derive(Drop, Copy, Serde, PartialEq, starknet::Store)]
pub enum Mode {
    #[default]
    Public,
    Whitelist,
}
