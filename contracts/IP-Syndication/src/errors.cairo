pub mod Errors {
    pub const PRICE_IS_ZERO: felt252 = 'Price can not be zero';
    pub const SYNDICATION_NON_ACTIVE: felt252 = 'Syndication not active';
    pub const SYNDICATION_IS_ACTIVE: felt252 = 'Syndication is active';
    pub const ADDRESS_NOT_WHITELISTED: felt252 = 'Address not whitelisted';
    pub const AMOUNT_IS_ZERO: felt252 = 'Amount can not be zero';
    pub const INVALID_CURRENCY_ADDRESS: felt252 = 'Invalid currency address';
    pub const FUNDRAISING_COMPLETED: felt252 = 'Fundraising already completed';
    pub const NOT_IN_WHITELIST_MODE: felt252 = 'Not in whitelist mode';
    pub const NOT_IP_OWNER: felt252 = 'Not IP owner';
    pub const COMPLETED_OR_CANCELLED: felt252 = 'Syn: completed or cancelled';
    pub const SYNDICATION_NOT_COMPLETED: felt252 = 'Syndication not completed';
    pub const NON_SYNDICATE_PARTICIPANT: felt252 = 'Not Syndication Participant';
    pub const ALREADY_MINTED: felt252 = 'Already minted';
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
    pub const ALREADY_REFUNDED: felt252 = 'Already refunded';
}
