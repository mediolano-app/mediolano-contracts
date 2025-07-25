// SPDX-License-Identifier: MIT
use core::byte_array::ByteArray;
use starknet::ContractAddress;
use super::types::{RoyaltyDistribution};

/// Events for Story Factory Contract
#[derive(Drop, starknet::Event)]
pub struct StoryCreated {
    #[key]
    pub story_contract: ContractAddress,
    #[key]
    pub creator: ContractAddress,
    pub title: ByteArray,
    pub genre: felt252,
    pub is_collaborative: bool,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct StoryUpdated {
    #[key]
    pub story_contract: ContractAddress,
    pub updater: ContractAddress,
    pub field_updated: felt252, // 'title', 'description', 'genre', etc.
    pub timestamp: u64,
}

/// Events for Chapter Submissions (Pre-minting)
#[derive(Drop, starknet::Event)]
pub struct ChapterSubmitted {
    #[key]
    pub story: ContractAddress,
    #[key]
    pub submission_id: u256,
    #[key]
    pub author: ContractAddress,
    pub title: ByteArray,
    pub ipfs_hash: felt252,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct SubmissionVoted {
    #[key]
    pub story: ContractAddress,
    #[key]
    pub submission_id: u256,
    #[key]
    pub voter: ContractAddress,
    pub approve: bool,
    pub reason: ByteArray,
    pub votes_for: u32,
    pub votes_against: u32,
    pub timestamp: u64,
}

/// Events for Accepted Chapters (Post-minting NFTs)
#[derive(Drop, starknet::Event)]
pub struct ChapterAccepted {
    #[key]
    pub story: ContractAddress,
    #[key]
    pub submission_id: u256,
    #[key]
    pub token_id: u256,
    pub chapter_number: u256,
    pub author: ContractAddress,
    pub accepted_by: ContractAddress,
    pub title: ByteArray,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ChapterRejected {
    #[key]
    pub story: ContractAddress,
    #[key]
    pub submission_id: u256,
    pub rejected_by: ContractAddress,
    pub reason: ByteArray,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ChapterMinted {
    #[key]
    pub story: ContractAddress,
    #[key]
    pub token_id: u256,
    #[key]
    pub author: ContractAddress,
    pub chapter_number: u256,
    pub title: ByteArray,
    pub ipfs_hash: felt252,
    pub timestamp: u64,
}

/// Events for Content Moderation
#[derive(Drop, starknet::Event)]
pub struct ChapterFlagged {
    #[key]
    pub story: ContractAddress,
    #[key]
    pub token_id: u256,
    #[key]
    pub flagger: ContractAddress,
    pub reason: ByteArray,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ChapterContentUpdated {
    #[key]
    pub story: ContractAddress,
    #[key]
    pub token_id: u256,
    pub updater: ContractAddress,
    pub old_ipfs_hash: felt252,
    pub new_ipfs_hash: felt252,
    pub reason: ByteArray,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ChapterRemoved {
    #[key]
    pub story: ContractAddress,
    #[key]
    pub token_id: u256,
    pub remover: ContractAddress,
    pub reason: ByteArray,
    pub timestamp: u64,
}

/// Events for Moderation and Governance
#[derive(Drop, starknet::Event)]
pub struct ModeratorAssigned {
    #[key]
    pub story: ContractAddress,
    #[key]
    pub moderator: ContractAddress,
    pub assigned_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ModeratorRemoved {
    #[key]
    pub story: ContractAddress,
    #[key]
    pub moderator: ContractAddress,
    pub removed_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ModerationActionTaken {
    #[key]
    pub story: ContractAddress,
    #[key]
    pub moderator: ContractAddress,
    pub action: felt252,
    pub target_id: u256, // submission_id or token_id
    pub reason: ByteArray,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct CreatorOverride {
    #[key]
    pub story: ContractAddress,
    #[key]
    pub creator: ContractAddress,
    pub submission_id: u256,
    pub action: felt252,
    pub reason: ByteArray,
    pub timestamp: u64,
}

/// Events for Revenue and Engagement
#[derive(Drop, starknet::Event)]
pub struct ChapterViewed {
    #[key]
    pub story: ContractAddress,
    #[key]
    pub token_id: u256,
    #[key]
    pub viewer: ContractAddress,
    pub view_count: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RevenueDistributed {
    #[key]
    pub story: ContractAddress,
    pub total_amount: u256,
    pub creator_share: u256,
    pub contributors_share: u256,
    pub platform_share: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RoyaltiesClaimed {
    #[key]
    pub story: ContractAddress,
    #[key]
    pub claimer: ContractAddress,
    pub amount: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RoyaltyDistributionUpdated {
    #[key]
    pub story: ContractAddress,
    pub updater: ContractAddress,
    pub old_distribution: RoyaltyDistribution,
    pub new_distribution: RoyaltyDistribution,
    pub timestamp: u64,
}

/// Events for Story Statistics and Analytics
#[derive(Drop, starknet::Event)]
pub struct StoryStatsUpdated {
    #[key]
    pub story: ContractAddress,
    pub total_chapters: u256,
    pub total_submissions: u256,
    pub total_contributors: u256,
    pub total_readers: u256,
    pub timestamp: u64,
}

/// Events for Batch Operations
#[derive(Drop, starknet::Event)]
pub struct BatchChaptersAccepted {
    #[key]
    pub story: ContractAddress,
    pub accepter: ContractAddress,
    pub submission_ids: Array<u256>,
    pub token_ids: Array<u256>,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct BatchOperationCompleted {
    #[key]
    pub story: ContractAddress,
    pub operator: ContractAddress,
    pub operation_type: felt252, // 'accept', 'reject', 'flag', etc.
    pub items_processed: u256,
    pub successful: u256,
    pub failed: u256,
    pub timestamp: u64,
}

/// Events for Registry Operations
#[derive(Drop, starknet::Event)]
pub struct StoryRegistered {
    #[key]
    pub registry: ContractAddress,
    #[key]
    pub story: ContractAddress,
    #[key]
    pub creator: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ModerationHistoryRecorded {
    #[key]
    pub registry: ContractAddress,
    #[key]
    pub story: ContractAddress,
    pub action_id: u256,
    pub moderator: ContractAddress,
    pub action: felt252,
    pub timestamp: u64,
}
