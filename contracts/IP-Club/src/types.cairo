use starknet::ContractAddress;

#[derive(Debug, Drop, Serde, starknet::Store, PartialEq, Clone)]
pub enum ClubStatus {
    #[default]
    Inactive,
    Open,
    Closed,
}

#[derive(Debug, Drop, Serde, starknet::Store)]
pub struct ClubRecord {
    pub id: u256,
    pub name: ByteArray,
    pub symbol: ByteArray,
    pub metadata_uri: ByteArray,
    pub status: ClubStatus,
    pub num_members: u32,
    pub creator: ContractAddress,
    pub club_nft: ContractAddress,
    pub max_members: Option<u32>,
    pub entry_fee: Option<u256>,
    pub payment_token: Option<ContractAddress>,
}
