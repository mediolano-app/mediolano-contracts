pub mod IPStoryErrors {
    // Story Management Errors
    pub const ONLY_STORY_CREATOR_CAN_UPDATE: felt252 = 'Only story creator can update';
    pub const STORY_NOT_FOUND: felt252 = 'Story not found';
    pub const STORY_NOT_ACTIVE: felt252 = 'Story is not active';
    pub const INVALID_ROYALTY_PERCENTAGE: felt252 = 'Invalid royalty percentage';
    pub const STORY_TITLE_EMPTY: felt252 = 'Story title cannot be empty';

    // Chapter Management Errors
    pub const CHAPTER_NOT_FOUND: felt252 = 'Chapter not found';
    pub const CHAPTER_ALREADY_APPROVED: felt252 = 'Chapter already approved';
    pub const CHAPTER_ALREADY_REJECTED: felt252 = 'Chapter already rejected';
    pub const CHAPTER_ALREADY_MINTED: felt252 = 'Chapter already minted';
    pub const CHAPTER_NOT_APPROVED: felt252 = 'Chapter not approved';
    pub const CHAPTER_CONTENT_EMPTY: felt252 = 'Chapter content cannot be empty';
    pub const CHAPTER_TITLE_EMPTY: felt252 = 'Chapter title cannot be empty';
    pub const ONLY_CHAPTER_AUTHOR_CAN_MINT: felt252 = 'Only chapter author can mint';

    // Moderation Errors
    pub const NOT_AUTHORIZED_TO_MODERATE: felt252 = 'Not authorized to moderate';
    pub const ONLY_STORY_CREATOR_OR_MODERATOR: felt252 = 'Only creator or moderator';
    pub const MODERATOR_ALREADY_EXISTS: felt252 = 'Moderator already exists';
    pub const MODERATOR_NOT_FOUND: felt252 = 'Moderator not found';
    pub const CANNOT_REMOVE_STORY_CREATOR: felt252 = 'Cannot remove story creator';

    // Royalty Errors
    pub const NO_ROYALTIES_TO_CLAIM: felt252 = 'No royalties to claim';
    pub const INSUFFICIENT_ROYALTY_FUNDS: felt252 = 'Insufficient royalty funds';
    pub const ROYALTY_PERCENTAGE_TOO_HIGH: felt252 = 'Royalty percentage too high';

    // ERC1155 Errors
    pub const INVALID_TOKEN_ID: felt252 = 'Invalid token ID';
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
    pub const TRANSFER_TO_ZERO_ADDRESS: felt252 = 'Transfer to zero address';
    pub const TRANSFER_FROM_ZERO_ADDRESS: felt252 = 'Transfer from zero address';
    pub const CALLER_NOT_OWNER_OR_APPROVED: felt252 = 'Caller not owner or approved';
    pub const INVALID_ARRAY_LENGTH: felt252 = 'Invalid array length';
    pub const TRANSFER_TO_NON_ERC1155_RECEIVER: felt252 = 'Transfer to non-receiver';

    // General Errors
    pub const ZERO_ADDRESS_NOT_ALLOWED: felt252 = 'Zero address not allowed';
    pub const CALLER_IS_ZERO_ADDRESS: felt252 = 'Caller is zero address';
    pub const ARRAY_LENGTH_MISMATCH: felt252 = 'Array length mismatch';
    pub const UNAUTHORIZED_ACCESS: felt252 = 'Unauthorized access';
    pub const INVALID_INTERFACE_ID: felt252 = 'Invalid interface ID';

    // Access Control Errors
    pub const ONLY_STORY_CREATOR: felt252 = 'Only story creator allowed';
    pub const ONLY_ADMIN: felt252 = 'Only admin allowed';
    pub const ONLY_MODERATOR: felt252 = 'Only moderator allowed';
}

