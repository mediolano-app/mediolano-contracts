pub mod Errors {
    pub const START_PRIZE_IS_ZERO: felt252 = 'Start price is zero';
    pub const CALLER_NOT_OWNER: felt252 = 'Caller is not owner';
    pub const CURRENCY_ADDRESS_ZERO: felt252 = 'Currency address is zero';
    pub const INVALID_AUCTION: felt252 = 'Invalid auction';
    pub const BIDDER_IS_OWNER: felt252 = 'Bidder is owner';
    pub const AUCTION_CLOSED: felt252 = 'Auction closed';
    pub const AMOUNT_LESS_THAN_START_PRICE: felt252 = 'Amount less than start price';
    pub const SALT_IS_ZERO: felt252 = 'Salt is zero';
    pub const INSUFFICIENT_FUNDS: felt252 = 'Insufficient funds';
    pub const AUCTION_STILL_OPEN: felt252 = 'Auction is still open';
    pub const NO_BID_FOUND: felt252 = 'No bid found';
    pub const WRONG_AMOUNT_OR_SALT: felt252 = 'Wrong amount or salt';
    pub const REVEAL_TIME_NOT_OVER: felt252 = 'Reveal time not over';
    pub const AUCTION_IS_FINALIZED: felt252 = 'Auction already finalized';
    pub const BID_REFUNDED: felt252 = 'Bid refunded';
    pub const AMOUNT_EXCEEDS_BALANCE: felt252 = 'Amount exceeds balance';
    pub const CALLER_ALREADY_WON_AUCTION: felt252 = 'Caller already won auction';
}
