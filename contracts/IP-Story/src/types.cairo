// SPDX-License-Identifier: MIT
use core::byte_array::ByteArray;
use starknet::ContractAddress;

/// Story metadata for creation and management
#[derive(Drop, Clone, Serde, starknet::Store)]
pub struct StoryMetadata {
    pub title: ByteArray,
    pub description: ByteArray,
    pub genre: felt252,
    pub cover_image_ipfs: felt252, // IPFS hash for cover image
    pub is_collaborative: bool, // Whether multiple creators are allowed
    pub max_chapters: u256, // 0 means unlimited
    pub content_rating: felt252 // e.g., 'G', 'PG', 'R'
}

/// Chapter submission structure (permissionless proposals)
#[derive(Drop, Clone, Serde, starknet::Store)]
pub struct ChapterSubmission {
    pub title: ByteArray,
    pub ipfs_hash: felt252, // Full content on IPFS
    pub author: ContractAddress,
    pub submission_timestamp: u64,
    pub submission_id: u256,
    pub is_under_review: bool,
    pub votes_for: u32,
    pub votes_against: u32,
    pub reason_if_rejected: ByteArray,
}

/// Accepted chapter structure (minted as ERC1155 NFTs)
#[derive(Drop, Clone, Serde, starknet::Store)]
pub struct AcceptedChapter {
    pub title: ByteArray,
    pub ipfs_hash: felt252, // Full content on IPFS
    pub author: ContractAddress,
    pub submission_id: u256, // Links back to original submission
    pub chapter_number: u256, // Sequential number in story
    pub acceptance_timestamp: u64,
    pub accepted_by: ContractAddress, // Moderator or creator who approved
    pub token_id: u256 // ERC1155 token ID
}

/// Chapter metadata for IPFS
#[derive(Drop, Clone, Serde)]
pub struct ChapterMetadata {
    pub title: ByteArray,
    pub content: ByteArray,
    pub author: ContractAddress,
    pub chapter_number: u256,
    pub word_count: u256,
    pub content_warnings: Array<felt252>,
    pub creation_timestamp: u64,
}

/// Story statistics for analytics
#[derive(Drop, Clone, Serde, starknet::Store)]
pub struct StoryStats {
    pub total_chapters: u256,
    pub total_submissions: u256,
    pub pending_submissions: u256,
    pub total_contributors: u256,
    pub total_readers: u256,
    pub creation_timestamp: u64,
    pub last_update_timestamp: u64,
}

/// Moderation action types (using felt252 for simplicity)
pub mod ModerationAction {
    pub const FLAG: felt252 = 'FLAG';
    pub const APPROVE: felt252 = 'APPROVE';
    pub const REJECT: felt252 = 'REJECT';
    pub const UPDATE_CONTENT: felt252 = 'UPDATE_CONTENT';
    pub const REMOVE: felt252 = 'REMOVE';
}

/// Moderation vote record
#[derive(Drop, Clone, Serde, starknet::Store)]
pub struct ModerationVote {
    pub voter: ContractAddress,
    pub submission_id: u256,
    pub action: felt252, // Use felt252 instead of enum
    pub reason: ByteArray,
    pub timestamp: u64,
}

/// Revenue distribution weights
#[derive(Drop, Clone, Serde, starknet::Store)]
pub struct RoyaltyDistribution {
    pub creator_percentage: u8, // Story creator's share
    pub contributor_percentage: u8, // Chapter contributors' share
    pub platform_percentage: u8 // Platform fee
}
