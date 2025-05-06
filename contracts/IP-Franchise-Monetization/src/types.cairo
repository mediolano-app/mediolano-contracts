use core::starknet::{contract_address_const, ContractAddress};
use core::option::{Option, OptionTrait};
use core::felt252;
use core::traits::Into;
use core::traits::TryInto;


use super::interfaces::{FranchiseTermsTrait, RoyaltyFeesTrait};
use super::errors::FranchiseTermsErrors;

#[derive(Debug, Drop, Serde, starknet::Store, PartialEq)]
pub struct Territory {
    pub id: felt252,
    pub name: ByteArray, // human-readable label
    pub exclusive_to_agreement: Option<u256>,
    pub active: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct FranchiseApplication {
    pub application_id: u256,
    pub franchisee: ContractAddress,
    pub current_terms: FranchiseTerms,
    pub status: ApplicationStatus,
    pub last_proposed_by: ContractAddress,
    pub version: u8,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct FranchiseSaleRequest {
    pub from: ContractAddress,
    pub to: ContractAddress,
    pub sale_price: u256,
    pub status: FranchiseSaleStatus,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct RoyaltyPayment {
    pub payment_id: u32,
    pub royalty_paid: u256,
    pub reported_revenue: u256,
    pub timestamp: u64,
}

#[derive(Drop, Serde, starknet::Store, Clone, PartialEq)]
pub struct RoyaltyFees {
    pub royalty_percent: u8,
    pub payment_schedule: PaymentSchedule,
    pub custom_interval: Option<u64>,
    pub last_payment_id: u32,
    pub max_missed_payments: u32,
}

impl RoyaltyFeesTraitImpl of RoyaltyFeesTrait<RoyaltyFees> {
    fn get_payment_interval(self: @RoyaltyFees) -> u64 {
        let schedule = self.payment_schedule;
        let custom = *self.custom_interval;
        match schedule {
            PaymentSchedule::Monthly => 30 * 24 * 60 * 60,
            PaymentSchedule::Quarterly => 3 * 30 * 24 * 60 * 60,
            PaymentSchedule::SemiAnnually => 6 * 30 * 24 * 60 * 60,
            PaymentSchedule::Annually => 365 * 24 * 60 * 60,
            PaymentSchedule::Custom => custom.unwrap_or(0),
            _ => 0,
        }
    }

    fn calculate_missed_payments(
        self: @RoyaltyFees, license_start: u64, block_timestamp: u64,
    ) -> u32 {
        let payment_interval = self.get_payment_interval();
        if payment_interval == 0 {
            return 0;
        }

        let last_payment_id = *self.last_payment_id;

        if block_timestamp < license_start {
            return 0;
        }

        let total_due_payments = (block_timestamp - license_start) / payment_interval;

        if total_due_payments <= last_payment_id.into() {
            return 0;
        }

        let missed_payments = total_due_payments - last_payment_id.into();
        missed_payments.try_into().unwrap()
    }

    fn is_royalty_due(self: @RoyaltyFees, license_start: u64, block_timestamp: u64) -> bool {
        let payment_interval = self.get_payment_interval();
        if payment_interval == 0 {
            return false;
        }

        let next_payment_due = self.get_next_payment_due(license_start);

        if block_timestamp < next_payment_due {
            return false;
        } else {
            return true;
        }
    }

    fn get_next_payment_due(self: @RoyaltyFees, license_start: u64) -> u64 {
        let payment_interval = self.get_payment_interval();
        if payment_interval == 0 {
            return license_start; // No interval set, default to start
        }

        let last_payment_id = *self.last_payment_id;

        license_start + ((last_payment_id.into() + 1) * payment_interval)
    }

    fn get_royalty_due(self: @RoyaltyFees, revenue: u256) -> u256 {
        let royalty_percent = *self.royalty_percent;
        (revenue * royalty_percent.into()) / 100
    }

    fn get_total_no_expected_payments(self: @RoyaltyFees, duration: u64) -> u64 {
        let payment_interval = self.get_payment_interval();
        if payment_interval == 0 || duration < payment_interval {
            return 0;
        }
        let total_payments = duration / payment_interval;
        total_payments
    }
}

#[derive(Drop, Serde, Clone, starknet::Store)]
pub struct FranchiseTerms {
    pub payment_model: PaymentModel,
    pub payment_token: ContractAddress,
    pub franchise_fee: u256,
    pub license_start: u64,
    pub license_end: u64,
    pub exclusivity: ExclusivityType,
    pub territory_id: u256,
}

impl FranchiseTermsTraitImpl of FranchiseTermsTrait<FranchiseTerms> {
    fn validate_terms_data(self: @FranchiseTerms, block_timestamp: u64) {
        // Validate Date
        let license_start = *self.license_start;
        let license_end = *self.license_end;

        assert(license_start > block_timestamp, FranchiseTermsErrors::StartDateInThePast);

        assert(license_start < license_end, FranchiseTermsErrors::StartDateAfterEndDate);

        assert(license_end > block_timestamp, FranchiseTermsErrors::EndDateInThePast);

        // Max end date -> block_timestamp + 5 years.
        let max_license_end = block_timestamp + (5 * 365 * 24 * 60 * 60);
        assert(license_end < max_license_end, FranchiseTermsErrors::EndDateTooFar);

        // Check Payment Token
        assert(*self.payment_token != zero_address(), FranchiseTermsErrors::InvalidTokenAddress);

        // Check Fees
        let franchise_fee = *self.franchise_fee;
        assert(franchise_fee > 0, FranchiseTermsErrors::FranchiseFeeRequired);

        // Check Payment Model
        match self.payment_model {
            PaymentModel::OneTime(one_time_fee) => {
                assert(*one_time_fee > 0_u256, FranchiseTermsErrors::OneTimeFeeRequired);
            },
            PaymentModel::RoyaltyBased(royalty_fees) => {
                let royalty_percent = *royalty_fees.royalty_percent;
                assert(royalty_percent > 0_u8, FranchiseTermsErrors::RoyaltyPercentRequired);
                assert(royalty_percent <= 100_u8, FranchiseTermsErrors::RoyaltyPercentTooHigh);

                assert(
                    royalty_fees.max_missed_payments > @0_u32,
                    FranchiseTermsErrors::MaxMissedPaymentsRequired,
                );

                assert(
                    royalty_fees.last_payment_id == @0_u32,
                    FranchiseTermsErrors::LastPaymentIdMustBeZero,
                );

                let payment_schedule = royalty_fees.payment_schedule;
                if payment_schedule == @PaymentSchedule::Custom {
                    let custom_interval = royalty_fees.custom_interval;
                    assert(custom_interval.is_some(), FranchiseTermsErrors::CustomIntervalRequired);
                    // min custom interval is daily payments
                    let min_custom_interval = 24 * 60 * 60;
                    let amount = *custom_interval;
                    let amount = amount.unwrap();
                    assert(
                        amount >= min_custom_interval,
                        FranchiseTermsErrors::CustomInvervalBelowMinimum,
                    );
                }

                let payment_interval = royalty_fees.get_payment_interval();

                assert(
                    license_end - license_start > payment_interval,
                    FranchiseTermsErrors::InvalidPaymentInterval,
                );
            },
        }
    }

    fn get_total_franchise_fee(self: @FranchiseTerms) -> u256 {
        match self.payment_model {
            PaymentModel::OneTime(one_time_fee) => *one_time_fee + *self.franchise_fee,
            PaymentModel::RoyaltyBased(_) => *self.franchise_fee,
        }
    }

    fn get_last_payment_id(self: @FranchiseTerms) -> u32 {
        match self.payment_model {
            PaymentModel::OneTime(_) => 0,
            PaymentModel::RoyaltyBased(royalty) => *royalty.last_payment_id,
        }
    }
}

#[derive(Drop, Serde, starknet::Store, Clone, PartialEq)]
pub enum PaymentModel {
    #[default]
    OneTime: u256,
    RoyaltyBased: RoyaltyFees,
}


#[derive(Debug, Drop, Serde, starknet::Store, Clone, PartialEq)]
pub enum ExclusivityType {
    Exclusive,
    #[default]
    NonExclusive,
}

impl ExclusivityTypeIntoFelt252 of Into<ExclusivityType, felt252> {
    fn into(self: ExclusivityType) -> felt252 {
        match self {
            ExclusivityType::Exclusive => 'EXCLUSIVE',
            ExclusivityType::NonExclusive => 'NONEXCLUSIVE',
        }
    }
}

impl Felt252TryIntoExclusivityType of TryInto<felt252, ExclusivityType> {
    fn try_into(self: felt252) -> Option<ExclusivityType> {
        if self == 'EXCLUSIVE' {
            Option::Some(ExclusivityType::Exclusive)
        } else if self == 'NONEXCLUSIVE' {
            Option::Some(ExclusivityType::NonExclusive)
        } else {
            Option::None
        }
    }
}

#[derive(Debug, Drop, Serde, starknet::Store, PartialEq, Clone)]
pub enum PaymentSchedule {
    #[default]
    Monthly,
    Quarterly,
    SemiAnnually,
    Annually,
    Custom,
}

impl PaymentScheduleIntoFelt252 of Into<PaymentSchedule, felt252> {
    fn into(self: PaymentSchedule) -> felt252 {
        match self {
            PaymentSchedule::Monthly => 'MONTHLY',
            PaymentSchedule::Quarterly => 'QUARTERLY',
            PaymentSchedule::SemiAnnually => 'SEMIANNUALLY',
            PaymentSchedule::Annually => 'ANNUALLY',
            PaymentSchedule::Custom => 'CUSTOM',
        }
    }
}

impl Felt252TryIntoPaymentSchedule of TryInto<felt252, PaymentSchedule> {
    fn try_into(self: felt252) -> Option<PaymentSchedule> {
        if self == 'MONTHLY' {
            Option::Some(PaymentSchedule::Monthly)
        } else if self == 'QUARTERLY' {
            Option::Some(PaymentSchedule::Quarterly)
        } else if self == 'SEMIANNUALLY' {
            Option::Some(PaymentSchedule::SemiAnnually)
        } else if self == 'ANNYALLY' {
            Option::Some(PaymentSchedule::Annually)
        } else if self == 'CUSTOM' {
            Option::Some(PaymentSchedule::Custom)
        } else {
            Option::None
        }
    }
}

#[derive(Debug, Drop, Serde, starknet::Store, PartialEq)]
pub enum FranchiseSaleStatus {
    #[default]
    Pending,
    Approved,
    Rejected,
    Completed,
}

impl FranchiseSaleStatusIntoFelt252 of Into<FranchiseSaleStatus, felt252> {
    fn into(self: FranchiseSaleStatus) -> felt252 {
        match self {
            FranchiseSaleStatus::Pending => 'PENDING',
            FranchiseSaleStatus::Approved => 'APPROVED',
            FranchiseSaleStatus::Rejected => 'REJECTED',
            FranchiseSaleStatus::Completed => 'COMPLETED',
        }
    }
}

impl Felt252TryIntoFranchiseSaleStatus of TryInto<felt252, FranchiseSaleStatus> {
    fn try_into(self: felt252) -> Option<FranchiseSaleStatus> {
        if self == 'PENDING' {
            Option::Some(FranchiseSaleStatus::Pending)
        } else if self == 'APPROVED' {
            Option::Some(FranchiseSaleStatus::Approved)
        } else if self == 'REJECTED' {
            Option::Some(FranchiseSaleStatus::Rejected)
        } else if self == 'COMPLETED' {
            Option::Some(FranchiseSaleStatus::Completed)
        } else {
            Option::None
        }
    }
}

#[derive(Debug, Drop, Serde, starknet::Store, PartialEq)]
pub enum ApplicationStatus {
    #[default]
    Pending,
    Revised,
    RevisionAccepted,
    Approved,
    Rejected,
    Cancelled,
}

pub fn zero_address() -> ContractAddress {
    contract_address_const::<0>()
}
