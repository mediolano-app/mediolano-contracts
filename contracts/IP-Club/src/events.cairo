use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct NewClubCreated {
    pub club_id: u256,
    pub creator: ContractAddress,
    pub metadata_uri: ByteArray,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ClubClosed {
    pub club_id: u256,
    pub creator: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct NewMember {
    pub club_id: u256,
    pub member: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct NftMinted {
    pub club_id: u256,
    pub token_id: u256,
    pub recipient: ContractAddress,
    pub timestamp: u64,
}
