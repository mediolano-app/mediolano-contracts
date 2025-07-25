// SPDX-License-Identifier: MIT

/// Error constants for IP Story protocol
pub mod errors {
    // General errors
    pub const CALLER_ZERO_ADDRESS: felt252 = 'Caller cannot be zero address';
    pub const INVALID_CONTRACT_ADDRESS: felt252 = 'Invalid contract address';
    pub const UNAUTHORIZED: felt252 = 'Unauthorized caller';
    pub const INVALID_PARAMETER: felt252 = 'Invalid parameter provided';

    // Story creation errors
    pub const STORY_ALREADY_EXISTS: felt252 = 'Story already exists';
    pub const INVALID_STORY_METADATA: felt252 = 'Invalid story metadata';
    pub const TITLE_TOO_SHORT: felt252 = 'Title too short';
    pub const TITLE_TOO_LONG: felt252 = 'Title too long';
    pub const DESCRIPTION_TOO_LONG: felt252 = 'Description too long';
    pub const INVALID_GENRE: felt252 = 'Invalid genre';
    pub const INVALID_CONTENT_RATING: felt252 = 'Invalid content rating';
    pub const MAX_CHAPTERS_EXCEEDED: felt252 = 'Max chapters limit exceeded';

    // Story ownership and creator errors
    pub const NOT_STORY_CREATOR: felt252 = 'Not a story creator';
    pub const CREATOR_ALREADY_EXISTS: felt252 = 'Creator already exists';
    pub const INVALID_SHARED_OWNERS: felt252 = 'Invalid shared owners list';
    pub const OWNERS_LIST_TOO_LONG: felt252 = 'Too many shared owners';

    // Chapter submission errors
    pub const INVALID_IPFS_HASH: felt252 = 'Invalid IPFS hash';
    pub const SUBMISSION_NOT_FOUND: felt252 = 'Submission not found';
    pub const SUBMISSION_ALREADY_PROCESSED: felt252 = 'Submission already processed';
    pub const CHAPTER_TITLE_EMPTY: felt252 = 'Chapter title cannot be empty';
    pub const DUPLICATE_SUBMISSION: felt252 = 'Duplicate submission detected';
    pub const SUBMISSION_UNDER_REVIEW: felt252 = 'Submission under review';

    // Chapter acceptance/rejection errors
    pub const CHAPTER_NOT_FOUND: felt252 = 'Chapter not found';
    pub const CHAPTER_ALREADY_EXISTS: felt252 = 'Chapter already exists';
    pub const INVALID_TOKEN_ID: felt252 = 'Invalid token ID';
    pub const CHAPTER_ALREADY_MINTED: felt252 = 'Chapter already minted';
    pub const REJECTION_REASON_REQUIRED: felt252 = 'Rejection reason required';

    // Moderation errors
    pub const NOT_MODERATOR: felt252 = 'Not a moderator';
    pub const MODERATOR_ALREADY_EXISTS: felt252 = 'Moderator already exists';
    pub const MODERATOR_NOT_FOUND: felt252 = 'Moderator not found';
    pub const CANNOT_REMOVE_CREATOR: felt252 = 'Cannot remove story creator';
    pub const INSUFFICIENT_MODERATOR_VOTES: felt252 = 'Insufficient moderator votes';
    pub const ALREADY_VOTED: felt252 = 'Already voted on submission';
    pub const VOTING_PERIOD_ENDED: felt252 = 'Voting period has ended';
    pub const INVALID_MODERATION_ACTION: felt252 = 'Invalid moderation action';

    // Content moderation errors
    pub const CONTENT_FLAGGED: felt252 = 'Content has been flagged';
    pub const CONTENT_REMOVED: felt252 = 'Content has been removed';
    pub const FLAGGING_REASON_REQUIRED: felt252 = 'Flagging reason required';
    pub const CANNOT_FLAG_OWN_CONTENT: felt252 = 'Cannot flag own content';

    // Revenue and royalty errors
    pub const INVALID_ROYALTY_PERCENTAGE: felt252 = 'Invalid royalty percentage';
    pub const ROYALTY_TOTAL_EXCEEDS_100: felt252 = 'Total royalty exceeds 100%';
    pub const NO_EARNINGS_TO_CLAIM: felt252 = 'No earnings to claim';
    pub const REVENUE_DISTRIBUTION_FAILED: felt252 = 'Revenue distribution failed';
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';

    // Pagination and query errors
    pub const INVALID_PAGINATION_PARAMS: felt252 = 'Invalid pagination params';
    pub const LIMIT_TOO_HIGH: felt252 = 'Limit too high';
    pub const OFFSET_OUT_OF_BOUNDS: felt252 = 'Offset out of bounds';
    pub const NO_RESULTS_FOUND: felt252 = 'No results found';

    // Factory errors
    pub const FACTORY_NOT_INITIALIZED: felt252 = 'Factory not initialized';
    pub const STORY_DEPLOYMENT_FAILED: felt252 = 'Story deployment failed';
    pub const INVALID_STORY_INDEX: felt252 = 'Invalid story index';

    // ERC1155 related errors
    pub const TOKEN_NOT_EXISTS: felt252 = 'Token does not exist';
    pub const INSUFFICIENT_BALANCE_FOR_TRANSFER: felt252 = 'Insufficient balance';
    pub const TRANSFER_TO_ZERO_ADDRESS: felt252 = 'Transfer to zero address';
    pub const APPROVAL_TO_CURRENT_OWNER: felt252 = 'Approval to current owner';

    // Batch operation errors
    pub const BATCH_ARRAY_MISMATCH: felt252 = 'Batch arrays length mismatch';
    pub const BATCH_TOO_LARGE: felt252 = 'Batch size too large';
    pub const BATCH_OPERATION_FAILED: felt252 = 'Batch operation failed';

    // Registry errors
    pub const STORY_NOT_REGISTERED: felt252 = 'Story not registered';
    pub const REGISTRY_ACCESS_DENIED: felt252 = 'Registry access denied';
    pub const MODERATION_HISTORY_NOT_FOUND: felt252 = 'Moderation history not found';

    // View tracking errors
    pub const VIEW_TRACKING_DISABLED: felt252 = 'View tracking disabled';
    pub const INVALID_CHAPTER_VIEW: felt252 = 'Invalid chapter view';

    // Upgrade errors
    pub const UPGRADE_FAILED: felt252 = 'Contract upgrade failed';
    pub const INVALID_CLASS_HASH: felt252 = 'Invalid class hash';
}
