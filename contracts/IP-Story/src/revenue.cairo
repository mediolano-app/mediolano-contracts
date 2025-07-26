// SPDX-License-Identifier: MIT

#[starknet::contract]
pub mod RevenueManager {
    use core::array::ArrayTrait;
    use starknet::{
        ContractAddress, get_caller_address, get_block_timestamp, get_contract_address,
        storage::{
            Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
            StoragePointerWriteAccess,
        },
    };
    use core::traits::TryInto;
    use core::traits::Into;
    use core::option::OptionTrait;
    use core::num::traits::Zero;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::{interface::IUpgradeable, UpgradeableComponent};

    // ETH contract address on Starknet
    const ETH_CONTRACT_ADDRESS: felt252 =
        0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;

    use super::super::{
        errors::errors, interfaces::IRevenueManager,
        events::{
            RevenueReceived, RoyaltiesDistributed, RoyaltyClaimed, RevenueSplitUpdated,
            RevenueDistributed, ContributorRegistered, ChapterViewed,
        },
        types::{RevenueMetrics, ContributorEarnings, ChapterRevenue, RevenueDistribution},
    };

    // Components
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Component implementations
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        // Multi-story revenue tracking
        story_revenue_metrics: Map<ContractAddress, RevenueMetrics>, // story -> metrics
        story_chapter_revenues: Map<
            (ContractAddress, u256), ChapterRevenue,
        >, // (story, token_id) -> revenue data
        story_contributor_earnings: Map<
            (ContractAddress, ContractAddress), ContributorEarnings,
        >, // (story, contributor) -> earnings
        story_pending_royalties: Map<
            (ContractAddress, ContractAddress), u256,
        >, // (story, contributor) -> pending amount
        // Revenue configuration per story
        story_creator_percentage: Map<ContractAddress, u8>, // story -> creator %
        story_platform_percentage: Map<ContractAddress, u8>, // story -> platform %
        story_contributors_percentage: Map<ContractAddress, u8>, // story -> contributors %
        // View tracking for reader-weighted distribution per story
        story_chapter_views: Map<(ContractAddress, u256), u256>, // (story, token_id) -> total views
        story_unique_viewers: Map<
            (ContractAddress, u256, ContractAddress), bool,
        >, // (story, token_id, viewer) -> has_viewed
        story_chapter_view_weights: Map<
            (ContractAddress, u256), u256,
        >, // (story, token_id) -> calculated weight score
        story_total_view_weight: Map<ContractAddress, u256>, // story -> sum of all view weights
        // Revenue distribution history per story
        story_distribution_history: Map<
            (ContractAddress, u256), RevenueDistribution,
        >, // (story, distribution_id) -> distribution data
        story_next_distribution_id: Map<ContractAddress, u256>, // story -> next distribution id
        // Payment and configuration per story
        story_payment_token: Map<
            ContractAddress, ContractAddress,
        >, // story -> ERC20 token (0 = ETH)
        // Story context - integration with story contracts
        story_creators: Map<
            (ContractAddress, ContractAddress), bool,
        >, // (story, creator) -> is_creator
        story_registered_chapters: Map<
            (ContractAddress, u256), bool,
        >, // (story, token_id) -> is_registered
        story_contributor_list: Map<
            (ContractAddress, u256), ContractAddress,
        >, // (story, index) -> contributor address
        story_total_contributors: Map<ContractAddress, u256>, // story -> total contributors
        // Global registry
        registered_stories: Map<ContractAddress, bool>, // story -> is_registered
        factory_contract: ContractAddress, // Factory that can register stories
        // Components
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        RevenueReceived: RevenueReceived,
        RoyaltiesDistributed: RoyaltiesDistributed,
        RoyaltyClaimed: RoyaltyClaimed,
        ChapterViewed: ChapterViewed,
        RevenueSplitUpdated: RevenueSplitUpdated,
        RevenueDistributed: RevenueDistributed,
        ContributorRegistered: ContributorRegistered,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, factory_contract: ContractAddress,
    ) {
        // Initialize components
        self.ownable.initializer(owner);

        // Set factory that can register stories
        self.factory_contract.write(factory_contract);
    }

    #[abi(embed_v0)]
    impl RevenueManagerImpl of IRevenueManager<ContractState> {
        // Story registration
        fn register_story(
            ref self: ContractState,
            story_id: ContractAddress,
            creator: ContractAddress,
            creator_percentage: u8,
            platform_percentage: u8,
            payment_token: ContractAddress,
        ) {
            self
                ._register_story(
                    story_id, creator, creator_percentage, platform_percentage, payment_token,
                );
        }

        fn add_story_creator(
            ref self: ContractState, story_id: ContractAddress, creator: ContractAddress,
        ) {
            self._add_story_creator(story_id, creator);
        }

        fn register_chapter(
            ref self: ContractState,
            story_id: ContractAddress,
            token_id: u256,
            author: ContractAddress,
        ) {
            self._register_chapter(story_id, token_id, author);
        }

        fn record_chapter_view(
            ref self: ContractState,
            story_id: ContractAddress,
            chapter_id: u256,
            viewer: ContractAddress,
        ) {
            let caller = get_caller_address();
            assert(caller == story_id, errors::ONLY_STORIES_CAN_RECORD_VIEWS);

            assert(self.registered_stories.read(story_id), errors::STORY_NOT_REGISTERED);
            assert(
                self.story_registered_chapters.read((story_id, chapter_id)),
                errors::CHAPTER_NOT_REGISTERED,
            );

            // Check if this is a unique view
            let view_key = (story_id, chapter_id, viewer);
            let is_unique = !self.story_unique_viewers.read(view_key);

            // Always increment total views
            let current_views = self.story_chapter_views.read((story_id, chapter_id));
            self.story_chapter_views.write((story_id, chapter_id), current_views + 1);

            // Update chapter revenue data
            let mut chapter_revenue = self.story_chapter_revenues.read((story_id, chapter_id));
            chapter_revenue.total_views += 1;
            chapter_revenue.last_viewed = get_block_timestamp();

            if is_unique {
                self.story_unique_viewers.write(view_key, true);
                chapter_revenue.unique_views += 1;

                // Update view weight (unique views have higher weight)
                let new_weight = self
                    ._calculate_view_weight(
                        chapter_revenue.unique_views, chapter_revenue.total_views,
                    );
                let old_weight = chapter_revenue.view_weight;
                chapter_revenue.view_weight = new_weight;

                // Update total view weight for distribution calculations
                let total_weight = self.story_total_view_weight.read(story_id);
                self
                    .story_total_view_weight
                    .write(story_id, total_weight - old_weight + new_weight);

                // Update contributor view count
                let chapter_author = chapter_revenue.author;
                let mut contributor_earnings = self
                    .story_contributor_earnings
                    .read((story_id, chapter_author));
                contributor_earnings.views_generated += 1;
                self
                    .story_contributor_earnings
                    .write((story_id, chapter_author), contributor_earnings);
            }

            self.story_chapter_revenues.write((story_id, chapter_id), chapter_revenue);

            // Update story metrics
            let mut metrics = self.story_revenue_metrics.read(story_id);
            metrics.total_views += 1;
            metrics.last_updated = get_block_timestamp();
            self.story_revenue_metrics.write(story_id, metrics);

            self
                .emit(
                    ChapterViewed {
                        story: story_id,
                        token_id: chapter_id,
                        viewer,
                        new_view_count: current_views + 1,
                        is_unique_view: is_unique,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn calculate_royalties(
            self: @ContractState, story_id: ContractAddress,
        ) -> RevenueDistribution {
            assert(self.registered_stories.read(story_id), errors::STORY_NOT_REGISTERED);

            let metrics = self.story_revenue_metrics.read(story_id);
            let total_revenue = metrics.total_revenue;

            // Get revenue split percentages for this story
            let creator_percentage = self.story_creator_percentage.read(story_id);
            let platform_percentage = self.story_platform_percentage.read(story_id);
            let contributors_percentage = self.story_contributors_percentage.read(story_id);

            // Calculate distribution amounts
            let creator_share = (total_revenue * creator_percentage.into()) / 100;
            let platform_share = (total_revenue * platform_percentage.into()) / 100;
            let contributors_share = (total_revenue * contributors_percentage.into()) / 100;

            RevenueDistribution {
                total_amount: total_revenue,
                creator_share,
                contributors_share,
                platform_share,
                distribution_timestamp: get_block_timestamp(),
            }
        }

        fn distribute_revenue(
            ref self: ContractState, story_id: ContractAddress, total_amount: u256,
        ) {
            assert(self.registered_stories.read(story_id), errors::STORY_NOT_REGISTERED);
            assert(total_amount > 0, errors::INVALID_AMOUNT);

            // Only story creators can trigger distribution
            let caller = get_caller_address();
            assert(
                self.story_creators.read((story_id, caller)), errors::ONLY_CREATORS_CAN_DISTRIBUTE,
            );

            // Calculate distribution
            let distribution = self.calculate_royalties(story_id);

            // Distribute to contributors based on reader engagement (view-weighted)
            self._distribute_to_contributors_weighted(story_id, distribution.contributors_share);

            // Update metrics
            let mut metrics = self.story_revenue_metrics.read(story_id);
            metrics.total_revenue += total_amount;
            metrics.last_updated = get_block_timestamp();
            if metrics.total_chapters > 0 {
                metrics.average_revenue_per_chapter = metrics.total_revenue
                    / metrics.total_chapters;
            }
            self.story_revenue_metrics.write(story_id, metrics);

            // Record distribution history
            let distribution_id = self.story_next_distribution_id.read(story_id);
            self.story_distribution_history.write((story_id, distribution_id), distribution);
            self.story_next_distribution_id.write(story_id, distribution_id + 1);

            self
                .emit(
                    RoyaltiesDistributed {
                        story: story_id,
                        total_amount,
                        creator_share: distribution.creator_share,
                        contributor_count: self
                            .story_total_contributors
                            .read(story_id)
                            .try_into()
                            .unwrap(),
                        timestamp: get_block_timestamp(),
                    },
                );

            self
                .emit(
                    RevenueDistributed {
                        story: story_id,
                        distribution_id,
                        total_amount,
                        recipients_count: self
                            .story_total_contributors
                            .read(story_id)
                            .try_into()
                            .unwrap(),
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn claim_royalties(ref self: ContractState, story_id: ContractAddress) -> u256 {
            // Apply Checks-Effects-Interactions pattern to prevent reentrancy

            // 1. CHECKS - Already done above
            let caller = get_caller_address();
            let pending = self.story_pending_royalties.read((story_id, caller));
            assert(pending > 0, errors::NO_ROYALTIES_TO_CLAIM);

            // 2. EFFECTS - Update state BEFORE external calls
            self.story_pending_royalties.write((story_id, caller), 0);

            let mut earnings = self.story_contributor_earnings.read((story_id, caller));
            earnings.total_earned += pending;
            earnings.last_payout = get_block_timestamp();
            self.story_contributor_earnings.write((story_id, caller), earnings.clone());

            // 3. INTERACTIONS - External calls LAST
            let payment_token = self.story_payment_token.read(story_id);
            if payment_token.is_zero() {
                // ETH transfer using Starknet's native ETH contract
                let eth_contract_address: ContractAddress = starknet::contract_address_const::<
                    ETH_CONTRACT_ADDRESS,
                >();
                let eth_contract = IERC20Dispatcher { contract_address: eth_contract_address };

                let contract_balance = eth_contract.balance_of(get_contract_address());
                assert(contract_balance >= pending, errors::INSUFFICIENT_BALANCE);

                // Proper error handling for ETH transfers
                let success = eth_contract.transfer(caller, pending);
                if !success {
                    // REVERT state changes if transfer fails
                    self.story_pending_royalties.write((story_id, caller), pending);
                    let mut reverted_earnings = self
                        .story_contributor_earnings
                        .read((story_id, caller));
                    reverted_earnings.total_earned -= pending;
                    reverted_earnings
                        .last_payout = earnings
                        .last_payout; // Restore previous timestamp
                    self.story_contributor_earnings.write((story_id, caller), reverted_earnings);

                    assert(false, errors::TOKEN_TRANSFER_FAILED);
                }
            } else {
                // ERC20 transfer
                let token = IERC20Dispatcher { contract_address: payment_token };

                let contract_balance = token.balance_of(get_contract_address());
                assert(contract_balance >= pending, errors::INSUFFICIENT_BALANCE);

                // Proper error handling for ERC20 transfers
                let success = token.transfer(caller, pending);
                if !success {
                    // REVERT state changes if transfer fails
                    self.story_pending_royalties.write((story_id, caller), pending);
                    let mut reverted_earnings = self
                        .story_contributor_earnings
                        .read((story_id, caller));
                    reverted_earnings.total_earned -= pending;
                    reverted_earnings
                        .last_payout = earnings
                        .last_payout; // Restore previous timestamp
                    self.story_contributor_earnings.write((story_id, caller), reverted_earnings);

                    assert(false, errors::TOKEN_TRANSFER_FAILED);
                }
            }

            self
                .emit(
                    RoyaltyClaimed {
                        story: story_id,
                        claimer: caller,
                        amount: pending,
                        timestamp: get_block_timestamp(),
                    },
                );

            pending
        }

        fn record_revenue(ref self: ContractState, amount: u256, source: ContractAddress) {
            assert(amount > 0, errors::INVALID_AMOUNT);
            let story_id = get_caller_address();

            // Verify the caller is a registered story
            assert(self.registered_stories.read(story_id), errors::STORY_NOT_REGISTERED);

            let mut metrics = self.story_revenue_metrics.read(story_id);
            metrics.total_revenue += amount;
            metrics.last_updated = get_block_timestamp();
            self.story_revenue_metrics.write(story_id, metrics);

            self
                .emit(
                    RevenueReceived {
                        story: story_id, amount, source, timestamp: get_block_timestamp(),
                    },
                );
        }

        fn get_revenue_metrics(self: @ContractState, story_id: ContractAddress) -> RevenueMetrics {
            self.story_revenue_metrics.read(story_id)
        }

        fn get_chapter_revenue(
            self: @ContractState, story_id: ContractAddress, token_id: u256,
        ) -> ChapterRevenue {
            self.story_chapter_revenues.read((story_id, token_id))
        }

        fn get_contributor_earnings(
            self: @ContractState, story_id: ContractAddress, contributor: ContractAddress,
        ) -> ContributorEarnings {
            self.story_contributor_earnings.read((story_id, contributor))
        }

        fn get_pending_royalties(
            self: @ContractState, story_id: ContractAddress, contributor: ContractAddress,
        ) -> u256 {
            self.story_pending_royalties.read((story_id, contributor))
        }

        fn get_chapter_view_count(
            self: @ContractState, story_id: ContractAddress, token_id: u256,
        ) -> u256 {
            self.story_chapter_views.read((story_id, token_id))
        }

        fn update_revenue_split(
            ref self: ContractState,
            story_id: ContractAddress,
            creator_percentage: u8,
            platform_percentage: u8,
        ) {
            let caller = get_caller_address();

            assert(self.story_creators.read((story_id, caller)), errors::ONLY_CREATORS_CAN_UPDATE);
            assert(creator_percentage <= 100, errors::INVALID_PERCENTAGES);
            assert(platform_percentage <= 100, errors::INVALID_PERCENTAGES);
            assert(creator_percentage + platform_percentage <= 100, errors::INVALID_PERCENTAGES);

            let old_creator = self.story_creator_percentage.read(story_id);
            let old_platform = self.story_platform_percentage.read(story_id);

            let contributors_percentage = 100 - creator_percentage - platform_percentage;

            self.story_creator_percentage.write(story_id, creator_percentage);
            self.story_platform_percentage.write(story_id, platform_percentage);
            self.story_contributors_percentage.write(story_id, contributors_percentage);

            self
                .emit(
                    RevenueSplitUpdated {
                        story: story_id,
                        updater: caller,
                        old_creator,
                        new_creator: creator_percentage,
                        old_platform,
                        new_platform: platform_percentage,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn get_revenue_split(self: @ContractState, story_id: ContractAddress) -> (u8, u8, u8) {
            (
                self.story_creator_percentage.read(story_id),
                self.story_contributors_percentage.read(story_id),
                self.story_platform_percentage.read(story_id),
            )
        }

        fn batch_record_views(
            ref self: ContractState,
            story_id: ContractAddress,
            chapter_ids: Array<u256>,
            viewer: ContractAddress,
        ) {
            let caller = get_caller_address();
            assert(caller == story_id, errors::ONLY_STORIES_CAN_RECORD_VIEWS);
            assert(chapter_ids.len() <= 10, errors::TOO_MANY_CHAPTERS_IN_BATCH);

            // Cache frequently accessed values to reduce storage reads
            let story_metrics = self.story_revenue_metrics.read(story_id);
            let current_timestamp = get_block_timestamp();
            let total_weight = self.story_total_view_weight.read(story_id);

            let mut new_total_weight = total_weight;
            let mut total_new_views = 0_u256;

            let mut i = 0;
            while i < chapter_ids.len() {
                let chapter_id = *chapter_ids.at(i);

                // Check if this is a unique view for this chapter
                let view_key = (story_id, chapter_id, viewer);
                let is_unique = !self.story_unique_viewers.read(view_key);

                if is_unique {
                    self.story_unique_viewers.write(view_key, true);

                    // Read chapter revenue once and batch update
                    let mut chapter_revenue = self
                        .story_chapter_revenues
                        .read((story_id, chapter_id));
                    chapter_revenue.unique_views += 1;
                    chapter_revenue.total_views += 1;
                    chapter_revenue.last_viewed = current_timestamp;

                    // Update view weight calculation
                    let old_weight = chapter_revenue.view_weight;
                    let new_weight = self
                        ._calculate_view_weight(
                            chapter_revenue.unique_views, chapter_revenue.total_views,
                        );
                    chapter_revenue.view_weight = new_weight;

                    // Accumulate weight changes instead of reading/writing storage  repeatedly
                    new_total_weight = new_total_weight - old_weight + new_weight;

                    let chapter_author = chapter_revenue.author;
                    self.story_chapter_revenues.write((story_id, chapter_id), chapter_revenue);

                    // Batch contributor updates by reading once, modifying, writing once
                    let mut contributor_earnings = self
                        .story_contributor_earnings
                        .read((story_id, chapter_author));
                    contributor_earnings.views_generated += 1;
                    self
                        .story_contributor_earnings
                        .write((story_id, chapter_author), contributor_earnings);
                }

                // Always increment total views
                let current_views = self.story_chapter_views.read((story_id, chapter_id));
                self.story_chapter_views.write((story_id, chapter_id), current_views + 1);

                total_new_views += 1;
                i += 1;
            };

            // Single storage write for total view weight instead of multiple
            self.story_total_view_weight.write(story_id, new_total_weight);

            // Single storage write for updated metrics
            let mut updated_metrics = story_metrics;
            updated_metrics.total_views += total_new_views;
            updated_metrics.last_updated = current_timestamp;
            self.story_revenue_metrics.write(story_id, updated_metrics);
        }

        fn batch_distribute_to_contributors(
            ref self: ContractState,
            story_id: ContractAddress,
            contributors: Array<ContractAddress>,
            amounts: Array<u256>,
        ) {
            assert(contributors.len() == amounts.len(), errors::ARRAYS_LENGTH_MISMATCH);
            assert(contributors.len() <= 50, errors::TOO_MANY_RECIPIENTS);

            let caller = get_caller_address();
            assert(
                self.story_creators.read((story_id, caller)), errors::ONLY_CREATORS_CAN_DISTRIBUTE,
            );

            let mut i = 0;
            while i < contributors.len() {
                let contributor = *contributors.at(i);
                let amount = *amounts.at(i);

                if amount > 0 {
                    // Add to pending royalties
                    let current_pending = self
                        .story_pending_royalties
                        .read((story_id, contributor));
                    self
                        .story_pending_royalties
                        .write((story_id, contributor), current_pending + amount);

                    // Update contributor earnings
                    let mut earnings = self
                        .story_contributor_earnings
                        .read((story_id, contributor));
                    earnings.pending_royalties += amount;
                    self.story_contributor_earnings.write((story_id, contributor), earnings);
                }

                i += 1;
            };
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: starknet::ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _register_story(
            ref self: ContractState,
            story_id: ContractAddress,
            creator: ContractAddress,
            creator_percentage: u8,
            platform_percentage: u8,
            payment_token: ContractAddress,
        ) {
            // Only factory can register stories
            assert(
                get_caller_address() == self.factory_contract.read(),
                errors::ONLY_FACTORY_CAN_REGISTER,
            );
            assert(!self.registered_stories.read(story_id), errors::STORY_ALREADY_REGISTERED);
            assert(creator_percentage + platform_percentage <= 100, errors::INVALID_PERCENTAGES);

            // Register the story
            self.registered_stories.write(story_id, true);

            // Set revenue configuration for this story
            let contributors_percentage = 100 - creator_percentage - platform_percentage;
            self.story_creator_percentage.write(story_id, creator_percentage);
            self.story_platform_percentage.write(story_id, platform_percentage);
            self.story_contributors_percentage.write(story_id, contributors_percentage);
            self.story_payment_token.write(story_id, payment_token);

            // Register the creator
            self.story_creators.write((story_id, creator), true);

            // Initialize metrics for this story
            let metrics = RevenueMetrics {
                total_revenue: 0,
                total_views: 0,
                total_chapters: 0,
                total_contributors: 0,
                average_revenue_per_chapter: 0,
                last_updated: get_block_timestamp(),
            };
            self.story_revenue_metrics.write(story_id, metrics);

            // Initialize distribution tracking
            self.story_next_distribution_id.write(story_id, 1);
            self.story_total_view_weight.write(story_id, 0);
        }

        fn _add_story_creator(
            ref self: ContractState, story_id: ContractAddress, creator: ContractAddress,
        ) {
            // Only existing creators can add new creators
            let caller = get_caller_address();
            assert(self.story_creators.read((story_id, caller)), errors::ONLY_CREATORS_CAN_UPDATE);
            self.story_creators.write((story_id, creator), true);
        }

        fn _register_chapter(
            ref self: ContractState,
            story_id: ContractAddress,
            token_id: u256,
            author: ContractAddress,
        ) {
            assert(self.registered_stories.read(story_id), errors::STORY_NOT_REGISTERED);

            let chapter_revenue = ChapterRevenue {
                token_id,
                author,
                total_views: 0,
                unique_views: 0,
                revenue_generated: 0,
                royalties_paid: 0,
                last_viewed: 0,
                view_weight: 0,
            };
            self.story_chapter_revenues.write((story_id, token_id), chapter_revenue);
            self.story_registered_chapters.write((story_id, token_id), true);

            // Initialize or update contributor earnings for this story
            let mut earnings = self.story_contributor_earnings.read((story_id, author));
            if earnings.contributor.is_zero() {
                // New contributor for this story
                earnings.contributor = author;
                let contributor_index = self.story_total_contributors.read(story_id);
                self.story_contributor_list.write((story_id, contributor_index), author);
                self.story_total_contributors.write(story_id, contributor_index + 1);

                self
                    .emit(
                        ContributorRegistered {
                            story: story_id,
                            contributor: author,
                            chapter_count: 1,
                            timestamp: get_block_timestamp(),
                        },
                    );
            }

            earnings.chapters_contributed += 1;
            self.story_contributor_earnings.write((story_id, author), earnings);

            // Update story metrics
            let mut metrics = self.story_revenue_metrics.read(story_id);
            metrics.total_chapters += 1;
            metrics.total_contributors = self.story_total_contributors.read(story_id);
            if metrics.total_revenue > 0 {
                metrics.average_revenue_per_chapter = metrics.total_revenue
                    / metrics.total_chapters;
            }
            self.story_revenue_metrics.write(story_id, metrics);
        }

        fn _calculate_view_weight(
            self: @ContractState, unique_views: u256, total_views: u256,
        ) -> u256 {
            if total_views < unique_views {
                return unique_views * 3; // If data is inconsistent, use only unique views
            }

            // Calculate weighted score based on unique views vs total views
            // Unique views get higher weight to prevent view farming
            let unique_weight = unique_views * 3; // 3x weight for unique views
            let repeat_views = total_views - unique_views;
            let repeat_weight = repeat_views * 1; // 1x weight for repeat views

            unique_weight + repeat_weight
        }

        fn _distribute_to_contributors_weighted(
            ref self: ContractState, story_id: ContractAddress, total_amount: u256,
        ) {
            let total_weight = self.story_total_view_weight.read(story_id);

            if total_weight == 0 {
                return; // No views yet, nothing to distribute
            }

            let contributor_count = self.story_total_contributors.read(story_id);
            let mut i = 0;

            while i < contributor_count {
                let contributor = self.story_contributor_list.read((story_id, i));
                let contributor_weight = self._calculate_contributor_weight(story_id, contributor);

                if contributor_weight > 0 {
                    let contributor_share = (total_amount * contributor_weight) / total_weight;

                    if contributor_share > 0 {
                        // Add to pending royalties for this story
                        let current_pending = self
                            .story_pending_royalties
                            .read((story_id, contributor));
                        self
                            .story_pending_royalties
                            .write((story_id, contributor), current_pending + contributor_share);

                        // Update contributor earnings for this story
                        let mut earnings = self
                            .story_contributor_earnings
                            .read((story_id, contributor));
                        earnings.pending_royalties += contributor_share;
                        self.story_contributor_earnings.write((story_id, contributor), earnings);
                    }
                }

                i += 1;
            };
        }

        fn _calculate_contributor_weight(
            self: @ContractState, story_id: ContractAddress, contributor: ContractAddress,
        ) -> u256 {
            // Calculate total weight for this contributor in this specific story
            let earnings = self.story_contributor_earnings.read((story_id, contributor));

            // Weight based on views generated in this story
            let views_generated = earnings.views_generated;

            // Weight based on unique views and chapter quality
            views_generated * 3 // Higher weight for engagement
        }
    }
}
