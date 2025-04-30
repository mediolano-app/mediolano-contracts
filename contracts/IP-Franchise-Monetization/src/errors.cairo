pub mod Errors {
    pub const InvalidIpAsset: felt252 = 'invalid ip asset';
    pub const NotOwner: felt252 = 'Caller not asset owner';
    pub const NotApproved: felt252 = 'ip asset not approved by owner';
    pub const IpAssetNotLinked: felt252 = 'ip asset not linked';
    pub const IpAssetAlreadyLinked: felt252 = 'ip asset already linked';
    pub const InvalidIpId: felt252 = 'invalid ip id';
    pub const InvalidIpNftId: felt252 = 'invalid ip nft id';
    pub const InvalidIpNftAddress: felt252 = 'invalid ip nft address';

    pub const invalidTerritoryId: felt252 = 'invalid territory id';
    pub const royaltyFeesNotAllowed: felt252 = 'royalty fees not allowed';
    pub const TerritoryAlreadyLinked: felt252 = 'territory already linked';
    pub const ApplicationNotApproved: felt252 = 'application not approved';
    pub const NotApplicationOwner: felt252 = 'Caller not application owner';
    pub const CannotCancelApplication: felt252 = 'Cannot cancel application';
    pub const NotAuthorized: felt252 = 'Caller not authorized';
    pub const InvalidApplicationStatus: felt252 = 'invalid application status';
    pub const AgreementLicenseNotOver: felt252 = 'agreement license not over';
    pub const TerritoryNotActive: felt252 = 'Territory inactive';
    pub const FranchiseAgreementNotListed: felt252 = 'Franchise not listed for sale';
}

pub mod FranchiseAgreementErrors {
    pub const Erc20TransferFailed: felt252 = 'ERC20 transfer failed';
    pub const NotFranchiseManager: felt252 = 'Only manager can perform action';
    pub const SaleRequestNotFound: felt252 = 'Sale request not found';
    pub const InvalidSaleStatus: felt252 = 'Invalid sale status';
    pub const OnlyBuyerCanFinalizeSale: felt252 = 'Only buyer can finalize sale';
    pub const RevenueMismatch: felt252 = 'Revenue mismatch';
    pub const InvalidRevenueAmount: felt252 = 'Invalid revenue amount';
    pub const InvalidRoyaltyAmount: felt252 = 'Invalid royalty amount';
    pub const FranchiseIpNotLinked: felt252 = 'Franchise IP not linked';
    pub const FranchiseAgreementNotActive: felt252 = 'Franchise Agreement no active';
    pub const MaxMissedPaymentsNotReached: felt252 = 'Max missed payments not reached';
    pub const MissedPaymentsExceedsMax: felt252 = 'Missed payments exceed max';
}

pub mod FranchiseTermsErrors {
    pub const StartDateInThePast: felt252 = 'Start date in the past';
    pub const StartDateAfterEndDate: felt252 = 'Start date is after end date';
    pub const EndDateInThePast: felt252 = 'End date in the past';
    pub const EndDateTooFar: felt252 = 'End date too far in the future';
    pub const FranchiseFeeRequired: felt252 = 'Franchise fee required';
    pub const OneTimeFeeRequired: felt252 = 'One time fee required';
    pub const RoyaltyFeesRequired: felt252 = 'Royalty fees required';
    pub const RoyaltyFeesNotAllowed: felt252 = 'Royalty fees  not allowed';
    pub const RoyaltyPercentRequired: felt252 = 'Royalty percent required';
    pub const RoyaltyPercentTooHigh: felt252 = 'Royalty percent too high';
    pub const CustomIntervalRequired: felt252 = 'Custom interval required';
    pub const CustomInvervalBelowMinimum: felt252 = 'Custom interval below minimum';
    pub const InvalidTokenAddress: felt252 = 'Invalid token address';
    pub const InvalidPaymentInterval: felt252 = 'Invalid payment interval';
    pub const MaxMissedPaymentsRequired: felt252 = 'Max missed payments required';
    pub const LastPaymentIdMustBeZero: felt252 = 'Last payment id must be zero';
}
