use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct IPAssetInfo {
    pub asset_id: u256,
    pub asset_type: felt252,
    pub metadata_uri: ByteArray,
    pub total_supply: u256,
    pub creation_timestamp: u64,
    pub is_verified: bool,
    pub compliance_status: felt252,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum IPAssetType {
    Art,
    Music,
    Literature,
    Software,
    Patent,
    Trademark,
    Other,
}

impl IPAssetTypeIntoFelt252 of Into<IPAssetType, felt252> {
    fn into(self: IPAssetType) -> felt252 {
        match self {
            IPAssetType::Art => 'ART',
            IPAssetType::Music => 'MUSIC',
            IPAssetType::Literature => 'LITERATURE',
            IPAssetType::Software => 'SOFTWARE',
            IPAssetType::Patent => 'PATENT',
            IPAssetType::Trademark => 'TRADEMARK',
            IPAssetType::Other => 'OTHER',
        }
    }
}

impl Felt252TryIntoIPAssetType of TryInto<felt252, IPAssetType> {
    fn try_into(self: felt252) -> Option<IPAssetType> {
        if self == 'ART' {
            Option::Some(IPAssetType::Art)
        } else if self == 'MUSIC' {
            Option::Some(IPAssetType::Music)
        } else if self == 'LITERATURE' {
            Option::Some(IPAssetType::Literature)
        } else if self == 'SOFTWARE' {
            Option::Some(IPAssetType::Software)
        } else if self == 'PATENT' {
            Option::Some(IPAssetType::Patent)
        } else if self == 'TRADEMARK' {
            Option::Some(IPAssetType::Trademark)
        } else if self == 'OTHER' {
            Option::Some(IPAssetType::Other)
        } else {
            Option::None
        }
    }
}

#[derive(Drop, starknet::Event)]
pub struct AssetRegistered {
    pub asset_id: u256,
    pub asset_type: felt252,
    pub total_creators: u32,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct MetadataUpdated {
    pub asset_id: u256,
    pub old_metadata_uri: ByteArray,
    pub new_metadata_uri: ByteArray,
    pub updated_by: ContractAddress,
    pub timestamp: u64,
}
