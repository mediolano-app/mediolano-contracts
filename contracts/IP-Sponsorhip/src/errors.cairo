
pub mod IPSponsorErrors {
    // IP Management Errors
    pub const ONLY_IP_OWNER_CAN_UPDATE: felt252 = 'Only IP owner can update';
    pub const IP_NOT_ACTIVE: felt252 = 'IP is not active';
    pub const ONLY_OWNER_OR_ADMIN: felt252 = 'Only owner or admin';
    pub const IP_ALREADY_INACTIVE: felt252 = 'IP is already inactive';
    
    // Sponsorship Offer Errors
    pub const ONLY_IP_OWNER_CAN_CREATE_OFFERS: felt252 = 'Only IP owner can create offers';
    pub const INVALID_PRICE_RANGE: felt252 = 'Invalid price range';
    pub const DURATION_MUST_BE_POSITIVE: felt252 = 'Duration must be positive';
    pub const ONLY_OFFER_AUTHOR_CAN_CANCEL: felt252 = 'Only offer author can cancel';
    pub const OFFER_NOT_ACTIVE: felt252 = 'Offer is not active';
    pub const ONLY_OFFER_AUTHOR_CAN_UPDATE: felt252 = 'Only offer author can update';
    pub const ONLY_OFFER_AUTHOR_CAN_ACCEPT: felt252 = 'Only offer author can accept';
    pub const ONLY_OFFER_AUTHOR_CAN_REJECT: felt252 = 'Only offer author can reject';
    
    // Bidding Errors
    pub const BID_BELOW_MINIMUM: felt252 = 'Bid below minimum price';
    pub const BID_ABOVE_MAXIMUM: felt252 = 'Bid above maximum price';
    pub const NOT_AUTHORIZED_TO_SPONSOR: felt252 = 'Not authorized to sponsor';
    pub const NO_VALID_BID_FOUND: felt252 = 'No valid bid found';
    
    // License Errors
    pub const ONLY_LICENSE_OWNER_CAN_TRANSFER: felt252 = 'Only license owner can transfer';
    pub const LICENSE_NOT_ACTIVE: felt252 = 'License is not active';
    pub const LICENSE_NOT_TRANSFERABLE: felt252 = 'License is not transferable';
    pub const LICENSE_HAS_EXPIRED: felt252 = 'License has expired';
    pub const NOT_AUTHORIZED_TO_REVOKE: felt252 = 'Not authorized to revoke';
}

