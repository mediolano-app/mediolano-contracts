// SPDX-License-Identifier: MIT
use core::array::Array;
use core::byte_array::ByteArray;
use starknet::ContractAddress;
use super::types::{
    StoryMetadata, ChapterSubmission, AcceptedChapter, StoryStats, ModerationVote,
    RoyaltyDistribution,
};

/// Interface for the Story Factory Contract
#[starknet::interface]
pub trait IIPStoryFactory<TContractState> {
    // Story creation and management
    fn create_story(
        ref self: TContractState,
        metadata: StoryMetadata,
        shared_owners: Option<Array<ContractAddress>>,
        royalty_distribution: RoyaltyDistribution,
    ) -> ContractAddress;

    fn get_story_count(self: @TContractState) -> u256;
    fn get_story_by_index(self: @TContractState, index: u256) -> ContractAddress;
    fn get_stories_by_creator(
        self: @TContractState, creator: ContractAddress,
    ) -> Array<ContractAddress>;
    fn get_stories_by_genre(self: @TContractState, genre: felt252) -> Array<ContractAddress>;
    fn get_all_stories_paginated(
        self: @TContractState, offset: u256, limit: u256,
    ) -> Array<ContractAddress>;
}

/// Interface for individual IP Story Contract (Core ERC1155)
#[starknet::interface]
pub trait IIPStory<TContractState> {
    // Story information
    fn get_story_metadata(self: @TContractState) -> StoryMetadata;
    fn get_story_statistics(self: @TContractState) -> StoryStats;
    fn get_story_creators(self: @TContractState) -> Array<ContractAddress>;
    fn is_story_creator(self: @TContractState, address: ContractAddress) -> bool;

    // Chapter submission functions (permissionless)
    fn submit_chapter(ref self: TContractState, title: ByteArray, ipfs_hash: felt252) -> u256;
    fn get_chapter_submission(self: @TContractState, submission_id: u256) -> ChapterSubmission;
    fn get_chapter_submissions_paginated(
        self: @TContractState, offset: u256, limit: u256,
    ) -> Array<ChapterSubmission>;
    fn get_pending_submissions(self: @TContractState) -> Array<ChapterSubmission>;
    fn get_submissions_by_author(
        self: @TContractState, author: ContractAddress,
    ) -> Array<ChapterSubmission>;

    // Accepted chapter functions (minted NFTs)
    fn accept_chapter(ref self: TContractState, submission_id: u256) -> u256; // Returns token_id
    fn reject_chapter(ref self: TContractState, submission_id: u256, reason: ByteArray);
    fn get_accepted_chapter(self: @TContractState, token_id: u256) -> AcceptedChapter;
    fn get_story_chapters_paginated(
        self: @TContractState, offset: u256, limit: u256,
    ) -> Array<AcceptedChapter>;
    fn get_total_story_chapters(self: @TContractState) -> u256;
    fn get_chapters_by_author(
        self: @TContractState, author: ContractAddress, offset: u256, limit: u256,
    ) -> Array<AcceptedChapter>;

    // Moderation and governance
    fn assign_moderator(ref self: TContractState, moderator: ContractAddress);
    fn remove_moderator(ref self: TContractState, moderator: ContractAddress);
    fn is_moderator(self: @TContractState, address: ContractAddress) -> bool;
    fn get_moderators(self: @TContractState) -> Array<ContractAddress>;

    fn vote_on_submission(
        ref self: TContractState, submission_id: u256, approve: bool, reason: ByteArray,
    );
    fn get_submission_votes(
        self: @TContractState, submission_id: u256,
    ) -> (u32, u32); // (votes_for, votes_against)
    fn creator_override_submission(ref self: TContractState, submission_id: u256, action: felt252);

    // Post-minting moderation
    fn flag_accepted_chapter(ref self: TContractState, token_id: u256, reason: ByteArray);
    fn update_accepted_chapter_content(
        ref self: TContractState, token_id: u256, new_ipfs_hash: felt252,
    );
    fn remove_accepted_chapter(ref self: TContractState, token_id: u256, reason: ByteArray);
    fn get_flagged_chapters(
        self: @TContractState, offset: u256, limit: u256,
    ) -> Array<AcceptedChapter>;

    // Revenue and engagement
    fn record_chapter_view(ref self: TContractState, chapter_id: u256);
    fn get_chapter_views(self: @TContractState, chapter_id: u256) -> u256;
    fn calculate_royalties(self: @TContractState) -> RoyaltyDistribution;
    fn distribute_revenue(ref self: TContractState, total_amount: u256);
    fn claim_royalties(ref self: TContractState) -> u256;
    fn get_contributor_earnings(self: @TContractState, contributor: ContractAddress) -> u256;

    // Batch operations
    fn batch_get_chapters(
        self: @TContractState, chapter_ids: Array<u256>,
    ) -> Array<AcceptedChapter>;
    fn batch_accept_chapters(ref self: TContractState, submission_ids: Array<u256>) -> Array<u256>;
}

/// Interface for Moderation Registry
#[starknet::interface]
pub trait IModerationRegistry<TContractState> {
    // Moderator management
    fn register_story(
        ref self: TContractState, story_contract: ContractAddress, creator: ContractAddress,
    );
    fn assign_story_moderator(
        ref self: TContractState, story_contract: ContractAddress, moderator: ContractAddress,
    );
    fn remove_story_moderator(
        ref self: TContractState, story_contract: ContractAddress, moderator: ContractAddress,
    );

    // Query functions
    fn is_story_moderator(
        self: @TContractState, story_contract: ContractAddress, moderator: ContractAddress,
    ) -> bool;
    fn get_story_moderators(
        self: @TContractState, story_contract: ContractAddress,
    ) -> Array<ContractAddress>;
    fn get_moderated_stories(
        self: @TContractState, moderator: ContractAddress,
    ) -> Array<ContractAddress>;

    // Moderation actions and history
    fn record_moderation_action(
        ref self: TContractState,
        story_contract: ContractAddress,
        moderator: ContractAddress,
        action: felt252,
        target_id: u256,
        reason: ByteArray,
    );
    fn get_moderation_history(
        self: @TContractState, story_contract: ContractAddress, offset: u256, limit: u256,
    ) -> Array<ModerationVote>;
}
