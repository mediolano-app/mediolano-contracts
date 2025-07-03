use starknet::ContractAddress;


#[derive(Drop, Serde, starknet::Store)]
pub enum ComplianceStatus {
    Pending,
    BerneCompliant,
    NonCompliant,
    UnderReview,
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

