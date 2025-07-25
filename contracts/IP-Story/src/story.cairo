// SPDX-License-Identifier: MIT

#[starknet::contract]
pub mod IPStory {
    use core::array::ArrayTrait;
    use core::byte_array::ByteArray;
    use starknet::{
        ContractAddress, get_caller_address, get_block_timestamp, get_contract_address,
        contract_address_const,
    };
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::super::{
        interfaces::IIPStory,
        types::{
            StoryMetadata, ChapterSubmission, AcceptedChapter, StoryStats, ModerationAction,
            RoyaltyDistribution,
        },
        errors::errors,
        events::{
            ChapterSubmitted, SubmissionVoted, ChapterAccepted, ChapterRejected, ChapterMinted,
            ChapterFlagged, ModeratorAssigned, ModeratorRemoved, ModerationActionTaken,
            ChapterViewed, RevenueDistributed, RoyaltiesClaimed, CreatorOverride,
            ChapterContentUpdated, ChapterRemoved,
        },
    };
    use openzeppelin::token::erc1155::ERC1155Component;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::access::ownable::OwnableComponent;

    // Components
    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Component implementations
    #[abi(embed_v0)]
    impl ERC1155MixinImpl = ERC1155Component::ERC1155MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        // Story metadata and configuration
        story_metadata: StoryMetadata,
        story_creators: Map<ContractAddress, bool>,
        royalty_distribution: RoyaltyDistribution,
        // Creator and moderator lists for efficient retrieval
        creators_list: Map<u256, ContractAddress>, // index -> creator
        creators_count: u256,
        moderators_list: Map<u256, ContractAddress>, // index -> moderator  
        moderators_count: u256,
        // Chapter submissions (pre-minting)
        next_submission_id: u256,
        submissions: Map<u256, ChapterSubmission>,
        submission_votes: Map<(u256, ContractAddress), bool>, // (submission_id, voter) -> voted
        // Accepted chapters (minted NFTs)
        next_token_id: u256,
        chapters: Map<u256, AcceptedChapter>, // token_id -> chapter
        chapter_numbers: Map<u256, u256>, // chapter_number -> token_id
        submission_to_token: Map<u256, u256>, // submission_id -> token_id
        // Moderation
        moderators: Map<ContractAddress, bool>,
        flagged_chapters: Map<u256, bool>, // token_id -> is_flagged
        // Analytics and engagement
        chapter_views: Map<u256, u256>, // token_id -> view_count
        contributor_earnings: Map<ContractAddress, u256>,
        total_earnings: u256,
        // Story statistics
        stats: StoryStats,
        // Factory and registry references
        factory_contract: ContractAddress,
        moderation_registry: ContractAddress,
        // Components
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ChapterSubmitted: ChapterSubmitted,
        SubmissionVoted: SubmissionVoted,
        ChapterAccepted: ChapterAccepted,
        ChapterRejected: ChapterRejected,
        ChapterMinted: ChapterMinted,
        ChapterFlagged: ChapterFlagged,
        ModeratorAssigned: ModeratorAssigned,
        ModeratorRemoved: ModeratorRemoved,
        ModerationActionTaken: ModerationActionTaken,
        ChapterViewed: ChapterViewed,
        RevenueDistributed: RevenueDistributed,
        RoyaltiesClaimed: RoyaltiesClaimed,
        CreatorOverride: CreatorOverride,
        ChapterContentUpdated: ChapterContentUpdated,
        ChapterRemoved: ChapterRemoved,
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        metadata: StoryMetadata,
        creator: ContractAddress,
        shared_owners: Option<Array<ContractAddress>>,
        royalty_distribution: RoyaltyDistribution,
        factory_contract: ContractAddress,
        moderation_registry: ContractAddress,
    ) {
        // Initialize ERC1155 with base URI
        self.erc1155.initializer("https://api.mediolano.io/ip-story/");

        // Initialize ownership
        self.ownable.initializer(creator);

        // Set story metadata
        self.story_metadata.write(metadata);
        self.royalty_distribution.write(royalty_distribution);

        // Set creator as initial moderator
        self.story_creators.write(creator, true);
        self.moderators.write(creator, true);

        // Initialize creator and moderator lists
        self.creators_count.write(1);
        self.creators_list.write(0, creator);
        self.moderators_count.write(1);
        self.moderators_list.write(0, creator);

        // Add shared owners if provided
        if let Option::Some(owners) = shared_owners {
            let mut i = 0;
            while i < owners.len() {
                let owner = *owners.at(i);
                self.story_creators.write(owner, true);
                self.moderators.write(owner, true);

                // Add to creators list
                let creators_index = self.creators_count.read();
                self.creators_list.write(creators_index, owner);
                self.creators_count.write(creators_index + 1);

                // Add to moderators list
                let moderators_index = self.moderators_count.read();
                self.moderators_list.write(moderators_index, owner);
                self.moderators_count.write(moderators_index + 1);

                i += 1;
            };
        }

        // Set contract references
        self.factory_contract.write(factory_contract);
        self.moderation_registry.write(moderation_registry);

        // Initialize counters
        self.next_submission_id.write(1);
        self.next_token_id.write(1);

        // Initialize stats
        let stats = StoryStats {
            total_chapters: 0,
            total_submissions: 0,
            pending_submissions: 0,
            total_contributors: 0,
            total_readers: 0,
            creation_timestamp: get_block_timestamp(),
            last_update_timestamp: get_block_timestamp(),
        };
        self.stats.write(stats);
    }

    #[abi(embed_v0)]
    impl IPStoryImpl of IIPStory<ContractState> {
        // Story information
        fn get_story_metadata(self: @ContractState) -> StoryMetadata {
            self.story_metadata.read()
        }

        fn get_story_statistics(self: @ContractState) -> StoryStats {
            self.stats.read()
        }

        fn get_story_creators(self: @ContractState) -> Array<ContractAddress> {
            let mut creators = ArrayTrait::new();
            let count = self.creators_count.read();
            let mut i = 0;

            while i < count {
                let creator = self.creators_list.read(i);
                // Only add active creators (double-check they're still marked as creators)
                if self.story_creators.read(creator) {
                    creators.append(creator);
                }
                i += 1;
            };

            creators
        }

        fn is_story_creator(self: @ContractState, address: ContractAddress) -> bool {
            self.story_creators.read(address)
        }

        // Chapter submission functions (permissionless)
        fn submit_chapter(ref self: ContractState, title: ByteArray, ipfs_hash: felt252) -> u256 {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            let submission_id = self.next_submission_id.read();

            // Validate inputs
            assert(title.len() > 0, errors::CHAPTER_TITLE_EMPTY);
            assert(ipfs_hash != 0, errors::INVALID_IPFS_HASH);

            // Check max chapters limit
            let metadata = self.story_metadata.read();
            if metadata.max_chapters > 0 {
                let stats = self.stats.read();
                assert(
                    stats.total_submissions < metadata.max_chapters, errors::MAX_CHAPTERS_EXCEEDED,
                );
            }

            // Create submission
            let submission = ChapterSubmission {
                title: title.clone(),
                ipfs_hash,
                author: caller,
                submission_timestamp: timestamp,
                submission_id,
                is_under_review: false,
                votes_for: 0,
                votes_against: 0,
                reason_if_rejected: "",
            };

            self.submissions.write(submission_id, submission);
            self.next_submission_id.write(submission_id + 1);

            // Update stats
            let mut stats = self.stats.read();
            stats.total_submissions += 1;
            stats.pending_submissions += 1;
            stats.last_update_timestamp = timestamp;
            self.stats.write(stats);

            // Emit event
            self
                .emit(
                    ChapterSubmitted {
                        story: get_contract_address(),
                        submission_id,
                        author: caller,
                        title,
                        ipfs_hash,
                        timestamp,
                    },
                );

            submission_id
        }

        fn get_chapter_submission(self: @ContractState, submission_id: u256) -> ChapterSubmission {
            assert(submission_id < self.next_submission_id.read(), errors::SUBMISSION_NOT_FOUND);
            self.submissions.read(submission_id)
        }

        fn get_chapter_submissions_paginated(
            self: @ContractState, offset: u256, limit: u256,
        ) -> Array<ChapterSubmission> {
            assert(limit > 0 && limit <= 50, errors::LIMIT_TOO_HIGH);

            let mut submissions = ArrayTrait::new();
            let total_submissions = self.next_submission_id.read() - 1;
            let end = if offset + limit > total_submissions {
                total_submissions
            } else {
                offset + limit
            };
            let mut i = offset + 1; // submissions start at ID 1

            while i <= end {
                let submission = self.submissions.read(i);
                submissions.append(submission);
                i += 1;
            };

            submissions
        }

        fn get_pending_submissions(self: @ContractState) -> Array<ChapterSubmission> {
            let mut pending = ArrayTrait::new();
            let total_submissions = self.next_submission_id.read() - 1;
            let mut i = 1;

            while i <= total_submissions {
                let submission = self.submissions.read(i);
                // Check if not yet processed (no corresponding token)
                if self.submission_to_token.read(i) == 0 {
                    pending.append(submission);
                }
                i += 1;
            };

            pending
        }

        fn get_submissions_by_author(
            self: @ContractState, author: ContractAddress,
        ) -> Array<ChapterSubmission> {
            let mut author_submissions = ArrayTrait::new();
            let total_submissions = self.next_submission_id.read() - 1;
            let mut i = 1;

            while i <= total_submissions {
                let submission = self.submissions.read(i);
                if submission.author == author {
                    author_submissions.append(submission);
                }
                i += 1;
            };

            author_submissions
        }

        // Accepted chapter functions (minted NFTs)
        fn accept_chapter(ref self: ContractState, submission_id: u256) -> u256 {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            // Verify caller is a moderator or creator
            assert(
                self.moderators.read(caller) || self.story_creators.read(caller),
                errors::NOT_MODERATOR,
            );

            // Get submission
            let submission = self.submissions.read(submission_id);
            assert(submission.submission_id != 0, errors::SUBMISSION_NOT_FOUND);

            // Check if already processed
            assert(
                self.submission_to_token.read(submission_id) == 0,
                errors::SUBMISSION_ALREADY_PROCESSED,
            );

            // Generate token ID and chapter number
            let token_id = self.next_token_id.read();
            let stats = self.stats.read();
            let chapter_number = stats.total_chapters + 1;

            // Create accepted chapter
            let chapter = AcceptedChapter {
                title: submission.title.clone(),
                ipfs_hash: submission.ipfs_hash,
                author: submission.author,
                submission_id,
                chapter_number,
                acceptance_timestamp: timestamp,
                accepted_by: caller,
                token_id,
            };

            // Store chapter data
            self.chapters.write(token_id, chapter);
            self.chapter_numbers.write(chapter_number, token_id);
            self.submission_to_token.write(submission_id, token_id);
            self.next_token_id.write(token_id + 1);

            // Mint NFT to author
            self
                .erc1155
                .mint_with_acceptance_check(submission.author, token_id, 1, array![].span());

            // Update stats
            let mut updated_stats = stats;
            updated_stats.total_chapters += 1;
            updated_stats.pending_submissions -= 1;
            updated_stats.last_update_timestamp = timestamp;
            self.stats.write(updated_stats);

            // Emit events
            self
                .emit(
                    ChapterAccepted {
                        story: get_contract_address(),
                        submission_id,
                        token_id,
                        chapter_number,
                        author: submission.author,
                        accepted_by: caller,
                        title: submission.title.clone(),
                        timestamp,
                    },
                );

            self
                .emit(
                    ChapterMinted {
                        story: get_contract_address(),
                        token_id,
                        author: submission.author,
                        chapter_number,
                        title: submission.title,
                        ipfs_hash: submission.ipfs_hash,
                        timestamp,
                    },
                );

            token_id
        }

        fn reject_chapter(ref self: ContractState, submission_id: u256, reason: ByteArray) {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            // Verify caller is a moderator or creator
            assert(
                self.moderators.read(caller) || self.story_creators.read(caller),
                errors::NOT_MODERATOR,
            );

            // Validate reason
            assert(reason.len() > 0, errors::REJECTION_REASON_REQUIRED);

            // Get submission
            let submission = self.submissions.read(submission_id);
            assert(submission.submission_id != 0, errors::SUBMISSION_NOT_FOUND);

            // Check if already processed
            assert(
                self.submission_to_token.read(submission_id) == 0,
                errors::SUBMISSION_ALREADY_PROCESSED,
            );

            // Update submission with rejection
            let mut updated_submission = submission;
            updated_submission.reason_if_rejected = reason.clone();
            self.submissions.write(submission_id, updated_submission);

            // Mark as processed (use max u256 to indicate rejection)
            self
                .submission_to_token
                .write(
                    submission_id,
                    0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
                );

            // Update stats
            let mut stats = self.stats.read();
            stats.pending_submissions -= 1;
            stats.last_update_timestamp = timestamp;
            self.stats.write(stats);

            // Emit event
            self
                .emit(
                    ChapterRejected {
                        story: get_contract_address(),
                        submission_id,
                        rejected_by: caller,
                        reason,
                        timestamp,
                    },
                );
        }

        fn get_accepted_chapter(self: @ContractState, token_id: u256) -> AcceptedChapter {
            let chapter = self.chapters.read(token_id);
            assert(chapter.token_id != 0, errors::CHAPTER_NOT_FOUND);
            chapter
        }

        fn get_story_chapters_paginated(
            self: @ContractState, offset: u256, limit: u256,
        ) -> Array<AcceptedChapter> {
            assert(limit > 0 && limit <= 50, errors::LIMIT_TOO_HIGH);

            let mut chapters = ArrayTrait::new();
            let total_chapters = self.stats.read().total_chapters;
            let end = if offset + limit > total_chapters {
                total_chapters
            } else {
                offset + limit
            };
            let mut i = offset + 1; // chapters start at number 1

            while i <= end {
                let token_id = self.chapter_numbers.read(i);
                if token_id != 0 {
                    let chapter = self.chapters.read(token_id);
                    chapters.append(chapter);
                }
                i += 1;
            };

            chapters
        }

        fn get_total_story_chapters(self: @ContractState) -> u256 {
            self.stats.read().total_chapters
        }

        fn get_chapters_by_author(
            self: @ContractState, author: ContractAddress, offset: u256, limit: u256,
        ) -> Array<AcceptedChapter> {
            assert(limit > 0 && limit <= 50, errors::LIMIT_TOO_HIGH);

            let mut author_chapters = ArrayTrait::new();
            let total_tokens = self.next_token_id.read() - 1;
            let mut found_count = 0;
            let mut added_count = 0;
            let mut i = 1;

            while i <= total_tokens && added_count < limit {
                let chapter = self.chapters.read(i);
                if chapter.author == author {
                    if found_count >= offset {
                        author_chapters.append(chapter);
                        added_count += 1;
                    }
                    found_count += 1;
                }
                i += 1;
            };

            author_chapters
        }

        // Moderation and governance
        fn assign_moderator(ref self: ContractState, moderator: ContractAddress) {
            let caller = get_caller_address();

            // Only creators can assign moderators
            assert(self.story_creators.read(caller), errors::NOT_STORY_CREATOR);
            assert(moderator != contract_address_const::<0>(), errors::CALLER_ZERO_ADDRESS);
            assert(!self.moderators.read(moderator), errors::MODERATOR_ALREADY_EXISTS);

            self.moderators.write(moderator, true);

            // Add to moderators list
            let index = self.moderators_count.read();
            self.moderators_list.write(index, moderator);
            self.moderators_count.write(index + 1);

            self
                .emit(
                    ModeratorAssigned {
                        story: get_contract_address(),
                        moderator,
                        assigned_by: caller,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn remove_moderator(ref self: ContractState, moderator: ContractAddress) {
            let caller = get_caller_address();

            // Only creators can remove moderators, and can't remove creators
            assert(self.story_creators.read(caller), errors::NOT_STORY_CREATOR);
            assert(self.moderators.read(moderator), errors::MODERATOR_NOT_FOUND);
            assert(!self.story_creators.read(moderator), errors::CANNOT_REMOVE_CREATOR);

            self.moderators.write(moderator, false);

            // Note: For efficiency, we don't remove from the moderators_list array
            // The get_moderators function filters out inactive moderators

            self
                .emit(
                    ModeratorRemoved {
                        story: get_contract_address(),
                        moderator,
                        removed_by: caller,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn is_moderator(self: @ContractState, address: ContractAddress) -> bool {
            self.moderators.read(address)
        }

        fn get_moderators(self: @ContractState) -> Array<ContractAddress> {
            let mut moderators = ArrayTrait::new();
            let count = self.moderators_count.read();
            let mut i = 0;

            while i < count {
                let moderator = self.moderators_list.read(i);
                // Only add active moderators (filter out those who have been removed)
                if self.moderators.read(moderator) {
                    moderators.append(moderator);
                }
                i += 1;
            };

            moderators
        }

        fn vote_on_submission(
            ref self: ContractState, submission_id: u256, approve: bool, reason: ByteArray,
        ) {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            // Verify submission exists
            let mut submission = self.submissions.read(submission_id);
            assert(submission.submission_id != 0, errors::SUBMISSION_NOT_FOUND);

            // Check if already voted
            assert(!self.submission_votes.read((submission_id, caller)), errors::ALREADY_VOTED);

            // Record vote
            self.submission_votes.write((submission_id, caller), true);

            // Update vote counts
            if approve {
                submission.votes_for += 1;
            } else {
                submission.votes_against += 1;
            }
            self.submissions.write(submission_id, submission.clone());

            // Emit event
            self
                .emit(
                    SubmissionVoted {
                        story: get_contract_address(),
                        submission_id,
                        voter: caller,
                        approve,
                        reason,
                        votes_for: submission.votes_for,
                        votes_against: submission.votes_against,
                        timestamp,
                    },
                );
        }

        fn get_submission_votes(self: @ContractState, submission_id: u256) -> (u32, u32) {
            let submission = self.submissions.read(submission_id);
            (submission.votes_for, submission.votes_against)
        }

        fn creator_override_submission(
            ref self: ContractState, submission_id: u256, action: felt252,
        ) {
            let caller = get_caller_address();

            // Only creators can override
            assert(self.story_creators.read(caller), errors::NOT_STORY_CREATOR);

            // Verify submission exists
            let submission = self.submissions.read(submission_id);
            assert(submission.submission_id != 0, errors::SUBMISSION_NOT_FOUND);

            // Execute action based on type
            if action == ModerationAction::APPROVE {
                self.accept_chapter(submission_id);
            } else if action == ModerationAction::REJECT {
                self.reject_chapter(submission_id, "Creator override");
            }

            // Emit override event
            self
                .emit(
                    CreatorOverride {
                        story: get_contract_address(),
                        creator: caller,
                        submission_id,
                        action,
                        reason: "Creator override",
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        // Post-minting moderation
        fn flag_accepted_chapter(ref self: ContractState, token_id: u256, reason: ByteArray) {
            let caller = get_caller_address();

            // Verify chapter exists
            let chapter = self.chapters.read(token_id);
            assert(chapter.token_id != 0, errors::CHAPTER_NOT_FOUND);

            // Can't flag own content
            assert(chapter.author != caller, errors::CANNOT_FLAG_OWN_CONTENT);
            assert(reason.len() > 0, errors::FLAGGING_REASON_REQUIRED);

            self.flagged_chapters.write(token_id, true);

            self
                .emit(
                    ChapterFlagged {
                        story: get_contract_address(),
                        token_id,
                        flagger: caller,
                        reason,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn update_accepted_chapter_content(
            ref self: ContractState, token_id: u256, new_ipfs_hash: felt252,
        ) {
            let caller = get_caller_address();

            // Only moderators or creators can update content
            assert(
                self.moderators.read(caller) || self.story_creators.read(caller),
                errors::NOT_MODERATOR,
            );

            // Verify chapter exists
            let mut chapter = self.chapters.read(token_id);
            assert(chapter.token_id != 0, errors::CHAPTER_NOT_FOUND);
            assert(new_ipfs_hash != 0, errors::INVALID_IPFS_HASH);

            let old_hash = chapter.ipfs_hash;
            chapter.ipfs_hash = new_ipfs_hash;
            self.chapters.write(token_id, chapter);

            self
                .emit(
                    ChapterContentUpdated {
                        story: get_contract_address(),
                        token_id,
                        updater: caller,
                        old_ipfs_hash: old_hash,
                        new_ipfs_hash,
                        reason: "Content updated by moderator",
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn remove_accepted_chapter(ref self: ContractState, token_id: u256, reason: ByteArray) {
            let caller = get_caller_address();

            // Only creators can remove chapters
            assert(self.story_creators.read(caller), errors::NOT_STORY_CREATOR);

            // Verify chapter exists
            let chapter = self.chapters.read(token_id);
            assert(chapter.token_id != 0, errors::CHAPTER_NOT_FOUND);
            assert(reason.len() > 0, errors::REJECTION_REASON_REQUIRED);

            // Burn the NFT
            self.erc1155.burn(chapter.author, token_id, 1);

            self
                .emit(
                    ChapterRemoved {
                        story: get_contract_address(),
                        token_id,
                        remover: caller,
                        reason,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn get_flagged_chapters(
            self: @ContractState, offset: u256, limit: u256,
        ) -> Array<AcceptedChapter> {
            assert(limit > 0 && limit <= 50, errors::LIMIT_TOO_HIGH);

            let mut flagged = ArrayTrait::new();
            let total_tokens = self.next_token_id.read() - 1;
            let mut found_count = 0;
            let mut added_count = 0;
            let mut i = 1;

            while i <= total_tokens && added_count < limit {
                if self.flagged_chapters.read(i) {
                    if found_count >= offset {
                        let chapter = self.chapters.read(i);
                        flagged.append(chapter);
                        added_count += 1;
                    }
                    found_count += 1;
                }
                i += 1;
            };

            flagged
        }

        // Revenue and engagement
        fn record_chapter_view(ref self: ContractState, chapter_id: u256) {
            let caller = get_caller_address();

            // Verify chapter exists
            let chapter = self.chapters.read(chapter_id);
            assert(chapter.token_id != 0, errors::CHAPTER_NOT_FOUND);

            // Increment view count
            let current_views = self.chapter_views.read(chapter_id);
            self.chapter_views.write(chapter_id, current_views + 1);

            // Update stats
            let mut stats = self.stats.read();
            stats.total_readers += 1;
            self.stats.write(stats);

            self
                .emit(
                    ChapterViewed {
                        story: get_contract_address(),
                        token_id: chapter_id,
                        viewer: caller,
                        view_count: current_views + 1,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn get_chapter_views(self: @ContractState, chapter_id: u256) -> u256 {
            self.chapter_views.read(chapter_id)
        }

        fn calculate_royalties(self: @ContractState) -> RoyaltyDistribution {
            self.royalty_distribution.read()
        }

        fn distribute_revenue(ref self: ContractState, total_amount: u256) {
            let caller = get_caller_address();

            // Only creators can distribute revenue
            assert(self.story_creators.read(caller), errors::NOT_STORY_CREATOR);

            let distribution = self.royalty_distribution.read();
            let creator_share = (total_amount * distribution.creator_percentage.into()) / 100;
            let contributors_share = (total_amount * distribution.contributor_percentage.into())
                / 100;
            let platform_share = (total_amount * distribution.platform_percentage.into()) / 100;

            self.total_earnings.write(self.total_earnings.read() + total_amount);

            self
                .emit(
                    RevenueDistributed {
                        story: get_contract_address(),
                        total_amount,
                        creator_share,
                        contributors_share,
                        platform_share,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn claim_royalties(ref self: ContractState) -> u256 {
            let caller = get_caller_address();
            let earnings = self.contributor_earnings.read(caller);

            assert(earnings > 0, errors::NO_EARNINGS_TO_CLAIM);

            self.contributor_earnings.write(caller, 0);

            self
                .emit(
                    RoyaltiesClaimed {
                        story: get_contract_address(),
                        claimer: caller,
                        amount: earnings,
                        timestamp: get_block_timestamp(),
                    },
                );

            earnings
        }

        fn get_contributor_earnings(self: @ContractState, contributor: ContractAddress) -> u256 {
            self.contributor_earnings.read(contributor)
        }

        // Batch operations
        fn batch_get_chapters(
            self: @ContractState, chapter_ids: Array<u256>,
        ) -> Array<AcceptedChapter> {
            let mut chapters = ArrayTrait::new();
            let mut i = 0;

            while i < chapter_ids.len() {
                let chapter_id = *chapter_ids.at(i);
                let chapter = self.chapters.read(chapter_id);
                if chapter.token_id != 0 {
                    chapters.append(chapter);
                }
                i += 1;
            };

            chapters
        }

        fn batch_accept_chapters(
            ref self: ContractState, submission_ids: Array<u256>,
        ) -> Array<u256> {
            let mut token_ids = ArrayTrait::new();
            let mut i = 0;

            while i < submission_ids.len() {
                let submission_id = *submission_ids.at(i);
                let token_id = self.accept_chapter(submission_id);
                token_ids.append(token_id);
                i += 1;
            };

            token_ids
        }
    }

    // ERC1155 Hooks Implementation
    impl ERC1155HooksImpl of ERC1155Component::ERC1155HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC1155Component::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
        ) {// No logic needed before update
        }

        fn after_update(
            ref self: ERC1155Component::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
        ) {// Could add logic here for tracking transfers, royalties, etc.
        }
    }
}
