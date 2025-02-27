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
    //TODO pub collection_id: u256,
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct SyndicationDetails {
    pub ip_id: u256,
    pub status: Status,
    pub mode: Mode,
    pub total_raised: u256,
    pub participant_count: u256,
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct ParticipantDetails {
    pub address: ContractAddress,
    pub amount_deposited: u256,
    pub minted: bool,
    pub collection_id: u256,
    // pub amount_refunded: u256,
}


#[derive(Drop, Copy, Serde, PartialEq, starknet::Store)]
pub enum Status {
    #[default]
    Pending,
    Active,
    Completed,
    Cancelled,
}

// impl StatusIntoFelt252 of Into<Status, felt252> {
//     fn into(self: Status) -> felt252 {
//         match self {
//             Status::Pending => 'PENDING',
//             Status::Active => 'ACTIVE',
//             Status::Completed => 'COMPLETED',
//             Status::Cancelled => 'CANCELLED',
//         }
//     }
// }

// impl Felt252TryIntoStatus of TryInto<felt252, Status> {
//     fn try_into(self: felt252) -> Option<Status> {
//         if self == 'PENDING' {
//             Option::Some(Status::Pending)
//         } else if self == 'ACTIVE' {
//             Option::Some(Status::Active)
//         } else if self == 'COMPLETED' {
//             Option::Some(Status::Completed)
//         } else if self == 'CANCELLED' {
//             Option::Some(Status::Cancelled)
//         } else {
//             Option::None
//         }
//     }
// }

#[derive(Drop, Copy, Serde, PartialEq, starknet::Store)]
pub enum Mode {
    #[default]
    Public,
    Whitelist,
}
// impl ModeIntoFelt252 of Into<Mode, felt252> {
//     fn into(self: Mode) -> felt252 {
//         match self {
//             Mode::Public => 'PUBLIC',
//             Mode::Whitelist => 'WHITELIST',
//         }
//     }
// }

// impl Felt252TryIntoMode of TryInto<felt252, Mode> {
//     fn try_into(self: felt252) -> Option<Mode> {
//         if self == 'PUBLIC' {
//             Option::Some(Mode::Public)
//         } else if self == 'WHITELIST' {
//             Option::Some(Mode::Whitelist)
//         } else {
//             Option::None
//         }
//     }
// }


