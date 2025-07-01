use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct OwnershipInfo {
    pub total_owners: u32,
    pub is_active: bool,
    pub registration_timestamp: u64,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct IPAssetInfo {
    pub asset_id: u256,
    pub asset_type: felt252,
    pub metadata_uri: ByteArray,
    pub total_supply: u256,
    pub creation_timestamp: u64,
    pub is_verified: bool,
    pub compliance_status: ComplianceStatus,
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

#[derive(Drop, Serde, starknet::Store)]
pub enum ComplianceStatus {
    Pending,
    BerneCompliant,
    NonCompliant,
    UnderReview,
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

impl ComplianceStatusIntoFelt252 of Into<ComplianceStatus, felt252> {
    fn into(self: ComplianceStatus) -> felt252 {
        match self {
            ComplianceStatus::Pending => 'PENDING',
            ComplianceStatus::BerneCompliant => 'BERNE_COMPLIANT',
            ComplianceStatus::NonCompliant => 'NON_COMPLIANT',
            ComplianceStatus::UnderReview => 'UNDER_REVIEW',
        }
    }
}

impl Felt252TryIntoComplianceStatus of TryInto<felt252, ComplianceStatus> {
    fn try_into(self: felt252) -> Option<ComplianceStatus> {
        if self == 'PENDING' {
            Option::Some(ComplianceStatus::Pending)
        } else if self == 'BERNE_COMPLIANT' {
            Option::Some(ComplianceStatus::BerneCompliant)
        } else if self == 'NON_COMPLIANT' {
            Option::Some(ComplianceStatus::NonCompliant)
        } else if self == 'UNDER_REVIEW' {
            Option::Some(ComplianceStatus::UnderReview)
        } else {
            Option::None
        }
    }
}
