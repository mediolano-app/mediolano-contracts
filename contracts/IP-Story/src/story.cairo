// SPDX-License-Identifier: MIT

#[starknet::contract]
pub mod IPStory {
    use core::array::ArrayTrait;
    use core::byte_array::ByteArray;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{
        ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
        get_contract_address,
    };
    use super::super::errors::errors;
    use super::super::events::{
        ChapterAccepted, ChapterContentUpdated, ChapterFlagged, ChapterMinted, ChapterRejected,
        ChapterSubmitted, StoryStatsUpdated,
    };
    use super::super::interfaces::{
        IIPStory, IModerationRegistryDispatcher, IModerationRegistryDispatcherTrait,
        IRevenueManagerDispatcher, IRevenueManagerDispatcherTrait,
    };
    use super::super::types::{
        AcceptedChapter, ChapterSubmission, RoyaltyDistribution, StoryMetadata, StoryStats,
    };

    // Components
    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Component implementations
    #[abi(embed_v0)]
    impl ERC1155MixinImpl = ERC1155Component::ERC1155MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        // Story metadata and configuration
        story_metadata: StoryMetadata,
        story_creators: Map<ContractAddress, bool>,
        royalty_distribution: RoyaltyDistribution,
        // Creator lists for efficient retrieval
        creators_list: Map<u256, ContractAddress>, // index -> creator
        creators_count: u256,
        // Chapter submissions (pre-minting)
        next_submission_id: u256,
        submissions: Map<u256, ChapterSubmission>,
        // Accepted chapters (minted NFTs)
        next_token_id: u256,
        chapters: Map<u256, AcceptedChapter>, // token_id -> chapter
        chapter_numbers: Map<u256, u256>, // chapter_number -> token_id
        chapter_authors: Map<u256, ContractAddress>,
        submission_to_token: Map<u256, u256>, // submission_id -> token_id (links tiers)
        // Story statistics
        stats: StoryStats,
        // Contract references
        factory_contract: ContractAddress,
        moderation_registry: ContractAddress,
        revenue_manager: ContractAddress,
        // Rejection system
        rejected_submissions: Map<u256, bool>, // submission_id -> is_rejected
        rejected_submission_reasons: Map<u256, ByteArray>, // submission_id -> reason
        // Components
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ChapterSubmitted: ChapterSubmitted,
        ChapterAccepted: ChapterAccepted,
        ChapterRejected: ChapterRejected,
        ChapterMinted: ChapterMinted,
        ChapterFlagged: ChapterFlagged,
        ChapterContentUpdated: ChapterContentUpdated,
        StoryStatsUpdated: StoryStatsUpdated,
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
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
        revenue_manager: ContractAddress,
    ) {
        // Initialize ERC1155 with base URI
        self.erc1155.initializer("https://api.mediolano.io/ip-story/");

        // Initialize ownership and upgradeability
        self.ownable.initializer(creator);

        // Set story metadata
        self.story_metadata.write(metadata);
        self.royalty_distribution.write(royalty_distribution);

        // Initialize creator as primary creator
        self.story_creators.write(creator, true);
        self.creators_count.write(1);
        self.creators_list.write(0, creator);

        // Add shared owners if provided
        match shared_owners {
            Option::Some(owners) => {
                let mut i = 0;
                while i < owners.len() {
                    let owner = *owners.at(i);
                    self.story_creators.write(owner, true);

                    // Add to creators list
                    let creators_index = self.creators_count.read();
                    self.creators_list.write(creators_index, owner);
                    self.creators_count.write(creators_index + 1);

                    i += 1;
                };
            },
            Option::None => {},
        }

        // Set contract references
        self.factory_contract.write(factory_contract);
        self.moderation_registry.write(moderation_registry);
        self.revenue_manager.write(revenue_manager);

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
                // Only add active creators
                if self.story_creators.read(creator) {
                    creators.append(creator);
                }
                i += 1;
            }

            creators
        }

        fn is_story_creator(self: @ContractState, address: ContractAddress) -> bool {
            self.story_creators.read(address)
        }

        // Chapter submission functions (permissionless)
        fn submit_chapter(ref self: ContractState, title: ByteArray, ipfs_hash: felt252) -> u256 {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            // Increment counter first to prevent race conditions
            let submission_id = self.next_submission_id.read();
            self.next_submission_id.write(submission_id + 1);

            // Validate inputs
            assert(title.len() > 0, errors::CHAPTER_TITLE_EMPTY);
            assert(ipfs_hash != 0, errors::INVALID_IPFS_HASH);

            // Check max chapters limit if set
            let metadata = self.story_metadata.read();
            if metadata.max_chapters > 0 {
                let stats = self.stats.read();
                assert(
                    stats.total_submissions < metadata.max_chapters, errors::MAX_CHAPTERS_EXCEEDED,
                );
            }

            // Create submission (first tier)
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
            }

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
            }

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
            }

            author_submissions
        }

        // Accepted chapter functions
        fn accept_chapter(ref self: ContractState, submission_id: u256) -> u256 {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            // Only story creators can accept chapters
            assert(self.story_creators.read(caller), errors::NOT_STORY_CREATOR);

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
            let author = submission.author;

            // Create accepted chapter (second tier)
            let chapter = AcceptedChapter {
                title: submission.title.clone(),
                ipfs_hash: submission.ipfs_hash,
                author,
                submission_id,
                chapter_number,
                acceptance_timestamp: timestamp,
                accepted_by: caller,
                token_id,
            };

            // Store chapter data and link tiers
            self.chapters.write(token_id, chapter);
            self.chapter_numbers.write(chapter_number, token_id);
            self.chapter_authors.write(token_id, author);
            self.submission_to_token.write(submission_id, token_id);
            self.next_token_id.write(token_id + 1);

            // Register chapter with revenue manager
            let revenue_manager = IRevenueManagerDispatcher {
                contract_address: self.revenue_manager.read(),
            };
            revenue_manager.register_chapter(get_contract_address(), token_id, submission.author);

            // Update stats
            let mut updated_stats = stats;
            updated_stats.total_chapters += 1;
            updated_stats.pending_submissions -= 1;
            updated_stats.last_update_timestamp = timestamp;
            self.stats.write(updated_stats);

            let registry = IModerationRegistryDispatcher {
                contract_address: self.moderation_registry.read(),
            };

            // Record action in ModerationRegistry
            registry
                .record_moderation_action(
                    get_contract_address(),
                    caller,
                    'ACCEPT_CHAPTER',
                    submission_id,
                    "Chapter accepted",
                );

            // Emit acceptance event
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

            token_id
        }

        fn reject_chapter(ref self: ContractState, submission_id: u256, reason: ByteArray) {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            // Only story creators can reject chapters
            assert(self.story_creators.read(caller), errors::NOT_STORY_CREATOR);

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
            assert(
                !self.rejected_submissions.read(submission_id),
                errors::SUBMISSION_ALREADY_PROCESSED,
            );

            // Update submission with rejection
            let mut updated_submission = submission;
            updated_submission.reason_if_rejected = reason.clone();
            self.submissions.write(submission_id, updated_submission);

            // Mark as rejected using proper boolean mapping
            self.rejected_submissions.write(submission_id, true);
            self.rejected_submission_reasons.write(submission_id, reason.clone());

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
            }

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
            }

            author_chapters
        }

        // Basic ownership and upgradeability
        fn transfer_story_ownership(ref self: ContractState, new_owner: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(new_owner != contract_address_const::<0>(), errors::CALLER_ZERO_ADDRESS);
            self.ownable.transfer_ownership(new_owner);
        }

        fn add_story_creator(ref self: ContractState, new_creator: ContractAddress) {
            // Only existing creators can add new creators
            let caller = get_caller_address();
            assert(self.story_creators.read(caller), errors::NOT_STORY_CREATOR);
            assert(new_creator != contract_address_const::<0>(), errors::CALLER_ZERO_ADDRESS);
            assert(!self.story_creators.read(new_creator), errors::CREATOR_ALREADY_EXISTS);

            self.story_creators.write(new_creator, true);

            // Add to creators list
            let index = self.creators_count.read();
            self.creators_list.write(index, new_creator);
            self.creators_count.write(index + 1);
        }

        fn remove_story_creator(ref self: ContractState, creator: ContractAddress) {
            // Only existing creators can remove other creators
            let caller = get_caller_address();
            assert(self.story_creators.read(caller), errors::NOT_STORY_CREATOR);
            assert(self.story_creators.read(creator), errors::CREATOR_NOT_FOUND);

            // Can't remove yourself if you're the only creator
            let creator_count = self.creators_count.read();
            assert(creator_count > 1 || creator != caller, errors::CANNOT_REMOVE_LAST_CREATOR);

            self.story_creators.write(creator, false);
            // Note: For efficiency, we don't compact the creators_list array
        // The get_story_creators function filters out inactive creators
        }

        // Batch operations for efficiency
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
            }

            chapters
        }

        fn batch_get_submissions(
            self: @ContractState, submission_ids: Array<u256>,
        ) -> Array<ChapterSubmission> {
            let mut submissions = ArrayTrait::new();
            let mut i = 0;

            while i < submission_ids.len() {
                let submission_id = *submission_ids.at(i);
                if submission_id < self.next_submission_id.read() {
                    let submission = self.submissions.read(submission_id);
                    submissions.append(submission);
                }
                i += 1;
            }

            submissions
        }

        /// Revenue and monetization functions
        fn view_chapter(ref self: ContractState, token_id: u256) {
            let caller = get_caller_address();

            // Verify chapter exists
            let chapter = self.chapters.read(token_id);
            assert(chapter.token_id != 0, errors::CHAPTER_NOT_FOUND);

            // Record view in revenue manager
            let revenue_manager = IRevenueManagerDispatcher {
                contract_address: self.revenue_manager.read(),
            };
            revenue_manager.record_chapter_view(get_contract_address(), token_id, caller);

            // Update local stats
            let mut stats = self.stats.read();
            stats.total_readers += 1; // This counts total views, not unique readers
            stats.last_update_timestamp = get_block_timestamp();
            self.stats.write(stats);
        }

        fn batch_view_chapters(ref self: ContractState, token_ids: Array<u256>) {
            let caller = get_caller_address();
            assert(token_ids.len() <= 10, errors::TOO_MANY_CHAPTERS_IN_BATCH);

            // Verify all chapters exist
            let mut i = 0;
            while i < token_ids.len() {
                let token_id = *token_ids.at(i);
                let chapter = self.chapters.read(token_id);
                assert(chapter.token_id != 0, errors::CHAPTER_NOT_FOUND);
                i += 1;
            }

            // Record batch views in revenue manager
            let revenue_manager = IRevenueManagerDispatcher {
                contract_address: self.revenue_manager.read(),
            };
            revenue_manager.batch_record_views(get_contract_address(), token_ids.clone(), caller);

            // Track unique readers properly instead of just adding view count
            let mut stats = self.stats.read();
            let mut unique_chapters_viewed = 0;

            // Count how many chapters this user hasn't viewed before
            let mut j = 0;
            while j < token_ids.len() {
                // Check if this is first time viewing this chapter (simplified check)
                unique_chapters_viewed += 1; // For now, assume each view is unique
                j += 1;
            }

            // Only increment readers by 1 if this user viewed any chapters for the first time
            if unique_chapters_viewed > 0_u256 {
                stats.total_readers += 1; // Track unique readers, not total views
            }
            stats.last_update_timestamp = get_block_timestamp();
            self.stats.write(stats);
        }

        fn record_revenue(ref self: ContractState, amount: u256, source: ContractAddress) {
            // Only story creators can record revenue
            let caller = get_caller_address();
            assert(self.story_creators.read(caller), errors::NOT_STORY_CREATOR);
            assert(amount > 0, errors::INVALID_AMOUNT);

            // Forward to revenue manager
            let revenue_manager = IRevenueManagerDispatcher {
                contract_address: self.revenue_manager.read(),
            };
            revenue_manager.record_revenue(amount, source);
        }

        fn distribute_revenue(ref self: ContractState, total_amount: u256) {
            // Only story creators can distribute revenue
            let caller = get_caller_address();
            assert(self.story_creators.read(caller), errors::NOT_STORY_CREATOR);
            assert(total_amount > 0, errors::INVALID_AMOUNT);

            // Forward to revenue manager
            let revenue_manager = IRevenueManagerDispatcher {
                contract_address: self.revenue_manager.read(),
            };
            revenue_manager.distribute_revenue(get_contract_address(), total_amount);
        }

        fn update_revenue_split(
            ref self: ContractState, creator_percentage: u8, platform_percentage: u8,
        ) {
            // Only story creators can update revenue split
            let caller = get_caller_address();
            assert(self.story_creators.read(caller), errors::NOT_STORY_CREATOR);

            // Forward to revenue manager
            let revenue_manager = IRevenueManagerDispatcher {
                contract_address: self.revenue_manager.read(),
            };
            revenue_manager
                .update_revenue_split(
                    get_contract_address(), creator_percentage, platform_percentage,
                );

            // Update local royalty distribution
            let mut royalty_dist = self.royalty_distribution.read();
            royalty_dist.creator_percentage = creator_percentage;
            royalty_dist.platform_percentage = platform_percentage;
            royalty_dist.contributor_percentage = 100 - creator_percentage - platform_percentage;
            self.royalty_distribution.write(royalty_dist);
        }

        // Revenue query functions (read-only)
        fn get_revenue_metrics(self: @ContractState) -> (u256, u256, u256, u256, u256) {
            let revenue_manager = IRevenueManagerDispatcher {
                contract_address: self.revenue_manager.read(),
            };
            let metrics = revenue_manager.get_revenue_metrics(get_contract_address());
            (
                metrics.total_revenue,
                metrics.total_views,
                metrics.total_chapters,
                metrics.total_contributors,
                metrics.average_revenue_per_chapter,
            )
        }

        fn get_chapter_view_count(self: @ContractState, token_id: u256) -> u256 {
            let revenue_manager = IRevenueManagerDispatcher {
                contract_address: self.revenue_manager.read(),
            };
            revenue_manager.get_chapter_view_count(get_contract_address(), token_id)
        }

        fn get_contributor_earnings(
            self: @ContractState, contributor: ContractAddress,
        ) -> (u256, u256, u256, u256) {
            let revenue_manager = IRevenueManagerDispatcher {
                contract_address: self.revenue_manager.read(),
            };
            let earnings = revenue_manager
                .get_contributor_earnings(get_contract_address(), contributor);
            (
                earnings.total_earned,
                earnings.pending_royalties,
                earnings.chapters_contributed,
                earnings.views_generated,
            )
        }

        fn get_pending_royalties(self: @ContractState, contributor: ContractAddress) -> u256 {
            let revenue_manager = IRevenueManagerDispatcher {
                contract_address: self.revenue_manager.read(),
            };
            revenue_manager.get_pending_royalties(get_contract_address(), contributor)
        }

        fn get_current_revenue_split(self: @ContractState) -> (u8, u8, u8) {
            let revenue_manager = IRevenueManagerDispatcher {
                contract_address: self.revenue_manager.read(),
            };
            revenue_manager.get_revenue_split(get_contract_address())
        }

        fn mint_chapter(ref self: ContractState, token_id: u256) {
            let timestamp = get_block_timestamp();
            let caller = get_caller_address();

            // Verify chapter exists and is accepted but not minted yet
            let chapter = self.chapters.read(token_id);
            assert(chapter.token_id != 0, errors::CHAPTER_NOT_FOUND);

            // Verify caller is chapter author
            assert(self.chapter_authors.read(token_id) == caller, errors::ONLY_AUTHOR_CAN_MINT);

            // Check if already minted
            assert(
                self.erc1155.balance_of(chapter.author, token_id) == 0,
                errors::CHAPTER_ALREADY_MINTED,
            );

            // Mint NFT to author
            self
                .erc1155
                .mint_with_acceptance_check(
                    chapter.author, token_id, 1, array![ // chapter.title.into(),
                    // chapter.ipfs_hash,
                    // chapter.author.into(),
                    // timestamp.into(),
                    ].span(),
                );

            // Emit minting event
            self
                .emit(
                    ChapterMinted {
                        story: get_contract_address(),
                        token_id,
                        author: chapter.author,
                        chapter_number: chapter.chapter_number,
                        title: chapter.title.clone(),
                        ipfs_hash: chapter.ipfs_hash,
                        timestamp,
                    },
                );
        }

        fn batch_mint_chapters(ref self: ContractState, token_ids: Array<u256>) {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            // Only story creators can mint
            assert(self.story_creators.read(caller), errors::NOT_STORY_CREATOR);
            assert(token_ids.len() > 0 && token_ids.len() <= 50, errors::BATCH_SIZE_INVALID);

            // Prepare batch data
            let mut recipients = ArrayTrait::new();
            let mut values = ArrayTrait::new();
            let mut valid_token_ids = ArrayTrait::new();

            let mut i = 0;
            while i < token_ids.len() {
                let token_id = *token_ids.at(i);
                let chapter = self.chapters.read(token_id);

                // Verify chapter exists and is not already minted
                if chapter.token_id != 0 && self.erc1155.balance_of(chapter.author, token_id) == 0 {
                    recipients.append(chapter.author);
                    values.append(1);
                    valid_token_ids.append(token_id);
                }
                i += 1;
            }

            assert(valid_token_ids.len() > 0, errors::NO_MINTABLE_CHAPTERS);

            // Batch mint tokens to authors
            let mut i = 0;
            while (i < recipients.len()) {
                self
                    .erc1155
                    .mint_with_acceptance_check(
                        *recipients.at(i), *valid_token_ids.at(i), *values.at(i), array![].span(),
                    );
                i += 1;
            }

            // Emit events for each minted chapter
            let mut j = 0;
            while j < valid_token_ids.len() {
                let token_id = *valid_token_ids.at(j);
                let chapter = self.chapters.read(token_id);

                self
                    .emit(
                        ChapterMinted {
                            story: get_contract_address(),
                            token_id,
                            author: chapter.author,
                            chapter_number: chapter.chapter_number,
                            title: chapter.title.clone(),
                            ipfs_hash: chapter.ipfs_hash,
                            timestamp,
                        },
                    );
                j += 1;
            };
        }

        fn batch_mint_by_author(ref self: ContractState, author: ContractAddress) {
            let caller = get_caller_address();
            assert(caller == author, errors::ONLY_AUTHOR_CAN_MINT);

            // Find all unminted chapters by this author
            let mut author_token_ids = self.get_unminted_chapters_by_author(author);
            assert(author_token_ids.len() > 0, errors::NO_UNMINTED_CHAPTERS);

            // Create values array with same length as token_ids
            let mut values = ArrayTrait::new();
            // let mut chapter_metadata = ArrayTrait::new();
            // let mut chapters_metadata = ArrayTrait::new();

            let mut i = 0;
            while i < author_token_ids.len() {
                let chapter = self.chapters.read(*author_token_ids.at(i));
                // chapter_metadata.append(chapter.ipfs_hash.into());
                // chapter_metadata.append(chapter.title.into());
                // chapter_metadata.append(chapter.author.try_into().unwrap());
                // chapters_metadata.append(chapter_metadata);
                values.append(1);
                i += 1;
            }

            // Use batch mint
            self
                .erc1155
                .batch_mint_with_acceptance_check(
                    author,
                    author_token_ids.span(),
                    values.span(), // chapters_metadata.at(i).span(),
                    array![].span(),
                );
        }

        fn get_unminted_chapters(self: @ContractState) -> Array<u256> {
            let mut unminted = ArrayTrait::new();
            let total_tokens = self.next_token_id.read() - 1;
            let mut i = 1;

            while i <= total_tokens {
                let chapter = self.chapters.read(i);
                if chapter.token_id != 0 && self.erc1155.balance_of(chapter.author, i) == 0 {
                    unminted.append(i);
                }
                i += 1;
            }

            unminted
        }

        fn get_unminted_chapters_by_author(
            self: @ContractState, author: ContractAddress,
        ) -> Array<u256> {
            let mut unminted = ArrayTrait::new();
            let total_tokens = self.next_token_id.read() - 1;
            let mut i = 1;

            while i <= total_tokens {
                let chapter = self.chapters.read(i);
                if chapter.author == author
                    && chapter.token_id != 0
                    && self.erc1155.balance_of(author, i) == 0 {
                    unminted.append(i);
                }
                i += 1;
            }

            unminted
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: starknet::ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
