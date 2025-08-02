pub mod errors {
    pub const INVALID_SIGNATURE_LENGTH: felt252 = 'Invalid signature length';
    pub const INVALID_SIGNATURE: felt252 = 'Invalid signature';
    pub const ORDER_EXPIRED: felt252 = 'Order expired';
    pub const ORDER_NOT_YET_VALID: felt252 = 'Order not yet valid';
    pub const INVALID_NONCE: felt252 = 'Invalid nonce';
    pub const ORDER_NOT_FOUND: felt252 = 'Order not found';
    pub const ORDER_ALREADY_CREATED: felt252 = 'Order already created';
    pub const ORDER_ALREADY_FILLED: felt252 = 'Order already filled';
    pub const ORDER_CANCELLED: felt252 = 'Order cancelled';
    pub const INSUFFICIENT_APPROVAL: felt252 = 'Insufficient approval';
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
    pub const TRANSFER_FAILED: felt252 = 'Transfer failed';
    pub const INVALID_ITEM_TYPE: felt252 = 'Invalid item type';
    pub const OFFER_CONSIDERATION_MISMATCH: felt252 = 'Mismatch items';
    pub const CALLER_NOT_OFFERER: felt252 = 'Caller not offerer';
    pub const UNSUPPORTED_TOKEN_STANDARD: felt252 = 'Unsupported token';
    pub const INVALID_AMOUNT: felt252 = 'Invalid amount';
    pub const NATIVE_TRANSFER_FAILED: felt252 = 'STRK transfer failed';
    pub const INVALID_ORDER_LENGTHS: felt252 = 'Invalid item lengths';
    pub const HASH_SERIALIZATION_FAILED: felt252 = 'Hash serialization failed';
}
