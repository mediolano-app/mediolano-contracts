// SPDX-License-Identifier: MIT
use core::array::Array;
use core::byte_array::ByteArray;
use starknet::ContractAddress;
use super::types::{
    AcceptedChapter, ChapterRevenue, ChapterSubmission, ContributorEarnings, ModerationVote,
    RevenueDistribution as RevenueDistributionType, RevenueMetrics, RoyaltyDistribution,
    StoryMetadata, StoryStats,
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

    // Basic ownership and upgradeability
    fn transfer_story_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn add_story_creator(ref self: TContractState, new_creator: ContractAddress);
    fn remove_story_creator(ref self: TContractState, creator: ContractAddress);

    // Batch operations for efficiency
    fn batch_get_chapters(
        self: @TContractState, chapter_ids: Array<u256>,
    ) -> Array<AcceptedChapter>;
    fn batch_get_submissions(
        self: @TContractState, submission_ids: Array<u256>,
    ) -> Array<ChapterSubmission>;

    // Revenue and monetization functions (Story contract calls to Revenue Manager)
    fn view_chapter(ref self: TContractState, token_id: u256);
    fn batch_view_chapters(ref self: TContractState, token_ids: Array<u256>);
    fn record_revenue(ref self: TContractState, amount: u256, source: ContractAddress);
    fn distribute_revenue(ref self: TContractState, total_amount: u256);
    fn update_revenue_split(
        ref self: TContractState, creator_percentage: u8, platform_percentage: u8,
    );

    // Revenue query functions (read-only)
    fn get_revenue_metrics(
        self: @TContractState,
    ) -> (
        u256, u256, u256, u256, u256,
    ); // (total_revenue, total_views, total_chapters, total_contributors, avg_revenue_per_chapter)
    fn get_chapter_view_count(self: @TContractState, token_id: u256) -> u256;
    fn get_contributor_earnings(
        self: @TContractState, contributor: ContractAddress,
    ) -> (
        u256, u256, u256, u256,
    ); // (total_earned, pending_royalties, chapters_contributed, views_generated)
    fn get_pending_royalties(self: @TContractState, contributor: ContractAddress) -> u256;
    fn get_current_revenue_split(
        self: @TContractState,
    ) -> (u8, u8, u8); // (creator, contributors, platform)
    // NFT Minting functions
    fn mint_chapter(ref self: TContractState, token_id: u256);
    fn batch_mint_chapters(ref self: TContractState, token_ids: Array<u256>);
    fn batch_mint_by_author(ref self: TContractState, author: ContractAddress);
    fn get_unminted_chapters(self: @TContractState) -> Array<u256>;
    fn get_unminted_chapters_by_author(
        self: @TContractState, author: ContractAddress,
    ) -> Array<u256>;
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
    // Submission voting system
    fn vote_on_submission(
        ref self: TContractState,
        story_contract: ContractAddress,
        submission_id: u256,
        approve: bool,
        reason: ByteArray,
    );
    fn get_submission_votes(
        self: @TContractState, story_contract: ContractAddress, submission_id: u256,
    ) -> (u32, u32); // (votes_for, votes_against)
    fn can_accept_submission(
        self: @TContractState, story_contract: ContractAddress, submission_id: u256,
    ) -> bool;
    fn creator_override_submission(
        ref self: TContractState,
        story_contract: ContractAddress,
        submission_id: u256,
        action: felt252, // 'ACCEPT' or 'REJECT'
        reason: ByteArray,
    );
    // Post-minting moderation
    fn flag_accepted_chapter(
        ref self: TContractState,
        story_contract: ContractAddress,
        token_id: u256,
        reason: ByteArray,
    );
    fn vote_on_flagged_chapter(
        ref self: TContractState,
        story_contract: ContractAddress,
        token_id: u256,
        action: felt252, // 'HIDE', 'REMOVE', 'APPROVE'
        reason: ByteArray,
    );
    fn resolve_flagged_chapter(
        ref self: TContractState,
        story_contract: ContractAddress,
        token_id: u256,
        final_action: felt252,
        reason: ByteArray,
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
    fn get_submission_voting_details(
        self: @TContractState, story_contract: ContractAddress, submission_id: u256,
    ) -> ModerationVote;
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
    // Factory management
    fn update_factory_contract(ref self: TContractState, factory_address: ContractAddress);
}

/// Interface for Revenue Management
#[starknet::interface]
pub trait IRevenueManager<TContractState> {
    // Story registration
    fn register_story(
        ref self: TContractState,
        story_id: ContractAddress,
        creator: ContractAddress,
        creator_percentage: u8,
        platform_percentage: u8,
        payment_token: ContractAddress,
    );
    fn add_story_creator(
        ref self: TContractState, story_id: ContractAddress, creator: ContractAddress,
    );
    fn register_chapter(
        ref self: TContractState,
        story_id: ContractAddress,
        token_id: u256,
        author: ContractAddress,
    );
    fn record_chapter_view(
        ref self: TContractState,
        story_id: ContractAddress,
        chapter_id: u256,
        viewer: ContractAddress,
    );
    fn record_revenue(ref self: TContractState, amount: u256, source: ContractAddress);
    // Royalty distribution
    fn calculate_royalties(
        self: @TContractState, story_id: ContractAddress,
    ) -> RevenueDistributionType;
    fn distribute_revenue(ref self: TContractState, story_id: ContractAddress, total_amount: u256);
    fn claim_royalties(ref self: TContractState, story_id: ContractAddress) -> u256;
    // Getters
    fn get_revenue_metrics(self: @TContractState, story_id: ContractAddress) -> RevenueMetrics;
    fn get_chapter_revenue(
        self: @TContractState, story_id: ContractAddress, token_id: u256,
    ) -> ChapterRevenue;
    fn get_contributor_earnings(
        self: @TContractState, story_id: ContractAddress, contributor: ContractAddress,
    ) -> ContributorEarnings;
    fn get_pending_royalties(
        self: @TContractState, story_id: ContractAddress, contributor: ContractAddress,
    ) -> u256;
    fn get_chapter_view_count(
        self: @TContractState, story_id: ContractAddress, token_id: u256,
    ) -> u256;
    // Revenue configuration per storyy
    fn update_revenue_split(
        ref self: TContractState,
        story_id: ContractAddress,
        creator_percentage: u8,
        platform_percentage: u8,
    );
    fn get_revenue_split(
        self: @TContractState, story_id: ContractAddress,
    ) -> (u8, u8, u8); // (creator, contributors, platform)
    // Batch operations
    fn batch_record_views(
        ref self: TContractState,
        story_id: ContractAddress,
        chapter_ids: Array<u256>,
        viewer: ContractAddress,
    );
    fn batch_distribute_to_contributors(
        ref self: TContractState,
        story_id: ContractAddress,
        contributors: Array<ContractAddress>,
        amounts: Array<u256>,
    );
    // Factory management
    fn update_factory_contract(ref self: TContractState, factory_address: ContractAddress);
}
