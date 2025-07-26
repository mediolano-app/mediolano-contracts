// SPDX-License-Identifier: MIT

#[starknet::contract]
pub mod ModerationRegistry {
    use core::array::ArrayTrait;
    use core::byte_array::ByteArray;
    use starknet::{
        ContractAddress, get_caller_address, get_block_timestamp, contract_address_const,
    };
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::super::{
        interfaces::IModerationRegistry, types::{ModerationVote}, errors::errors,
        events::{
            StoryRegistered, ModeratorAssigned, ModeratorRemoved, SubmissionVoted, ChapterFlagged,
            ModerationHistoryRecorded,
        },
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::{interface::IUpgradeable, UpgradeableComponent};

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
        // Story registry
        registered_stories: Map<ContractAddress, bool>,
        story_creators: Map<ContractAddress, ContractAddress>, // story -> creator
        // Moderator management
        story_moderators: Map<
            (ContractAddress, ContractAddress), bool,
        >, // (story, moderator) -> is_moderator
        story_moderator_lists: Map<
            (ContractAddress, u256), ContractAddress,
        >, // (story, index) -> moderator
        story_moderator_counts: Map<ContractAddress, u256>, // story -> moderator_count
        moderator_stories: Map<
            (ContractAddress, u256), ContractAddress,
        >, // (moderator, index) -> story
        moderator_story_counts: Map<ContractAddress, u256>, // moderator -> story_count
        // Submission voting system
        submission_votes: Map<
            (ContractAddress, u256), ModerationVote,
        >, // (story, submission_id) -> vote_data
        voter_submissions: Map<
            (ContractAddress, u256, ContractAddress), bool,
        >, // (story, submission_id, voter) -> has_voted
        // Flagged chapter management
        flagged_chapters: Map<(ContractAddress, u256), bool>, // (story, token_id) -> is_flagged
        chapter_flag_votes: Map<
            (ContractAddress, u256), ModerationVote,
        >, // (story, token_id) -> vote_data
        // Moderation history
        moderation_history: Map<
            (ContractAddress, u256), ModerationVote,
        >, // (story, action_id) -> action
        story_action_counts: Map<ContractAddress, u256>, // story -> total_actions
        // Global settings
        minimum_moderators_required: u256,
        voting_threshold_percentage: u8, // % of moderators needed for consensus
        // Components
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        StoryRegistered: StoryRegistered,
        ModeratorAssigned: ModeratorAssigned,
        ModeratorRemoved: ModeratorRemoved,
        SubmissionVoted: SubmissionVoted,
        ChapterFlagged: ChapterFlagged,
        ModerationHistoryRecorded: ModerationHistoryRecorded,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        minimum_moderators_required: u256,
        voting_threshold_percentage: u8,
    ) {
        // Validation
        assert(owner != contract_address_const::<0>(), errors::CALLER_ZERO_ADDRESS);
        assert(voting_threshold_percentage <= 100, errors::INVALID_PARAMETER);
        assert(minimum_moderators_required > 0, errors::INVALID_PARAMETER);

        // Initialize components
        self.ownable.initializer(owner);

        // Initialize settings
        self.minimum_moderators_required.write(minimum_moderators_required);
        self.voting_threshold_percentage.write(voting_threshold_percentage);
    }

    #[abi(embed_v0)]
    impl ModerationRegistryImpl of IModerationRegistry<ContractState> {
        fn register_story(
            ref self: ContractState, story_contract: ContractAddress, creator: ContractAddress,
        ) {
            // Only the story contract itself or factory can register
            let caller = get_caller_address();
            assert(
                caller == story_contract || caller == self.ownable.owner(), errors::UNAUTHORIZED,
            );

            // Validate inputs
            assert(
                story_contract != contract_address_const::<0>(), errors::INVALID_CONTRACT_ADDRESS,
            );
            assert(creator != contract_address_const::<0>(), errors::CALLER_ZERO_ADDRESS);
            assert(!self.registered_stories.read(story_contract), errors::STORY_ALREADY_EXISTS);

            // Register story
            self.registered_stories.write(story_contract, true);
            self.story_creators.write(story_contract, creator);

            // Creator becomes the first moderator
            self.story_moderators.write((story_contract, creator), true);
            self.story_moderator_lists.write((story_contract, 0), creator);
            self.story_moderator_counts.write(story_contract, 1);

            // Add to moderator's story list
            self.moderator_stories.write((creator, 0), story_contract);
            self.moderator_story_counts.write(creator, 1);

            // Initialize action count
            self.story_action_counts.write(story_contract, 0);

            self
                .emit(
                    StoryRegistered {
                        story: story_contract, creator, timestamp: get_block_timestamp(),
                    },
                );
        }

        fn assign_story_moderator(
            ref self: ContractState, story_contract: ContractAddress, moderator: ContractAddress,
        ) {
            let caller = get_caller_address();

            // Validate story exists and caller is creator
            assert(self.registered_stories.read(story_contract), errors::STORY_NOT_REGISTERED);
            assert(self.story_creators.read(story_contract) == caller, errors::NOT_STORY_CREATOR);
            assert(moderator != contract_address_const::<0>(), errors::CALLER_ZERO_ADDRESS);
            assert(
                !self.story_moderators.read((story_contract, moderator)),
                errors::MODERATOR_ALREADY_EXISTS,
            );

            // Add moderator
            self.story_moderators.write((story_contract, moderator), true);

            let moderator_index = self.story_moderator_counts.read(story_contract);
            self.story_moderator_lists.write((story_contract, moderator_index), moderator);
            self.story_moderator_counts.write(story_contract, moderator_index + 1);

            // Add to moderator's story list
            let story_index = self.moderator_story_counts.read(moderator);
            self.moderator_stories.write((moderator, story_index), story_contract);
            self.moderator_story_counts.write(moderator, story_index + 1);

            // Record action
            self
                ._record_moderation_action(
                    story_contract,
                    caller,
                    'ASSIGN_MODERATOR',
                    0, // Use 0 for moderator-related actions since target_id expects u256
                    "Moderator assigned by creator",
                );

            self
                .emit(
                    ModeratorAssigned {
                        story: story_contract,
                        moderator,
                        assigned_by: caller,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn remove_story_moderator(
            ref self: ContractState, story_contract: ContractAddress, moderator: ContractAddress,
        ) {
            let caller = get_caller_address();

            // Validate story exists and caller is creator
            assert(self.registered_stories.read(story_contract), errors::STORY_NOT_REGISTERED);
            assert(self.story_creators.read(story_contract) == caller, errors::NOT_STORY_CREATOR);
            assert(
                self.story_moderators.read((story_contract, moderator)),
                errors::MODERATOR_NOT_FOUND,
            );

            // Can't remove creator
            assert(moderator != caller, errors::CANNOT_REMOVE_CREATOR);

            // Remove moderator
            self.story_moderators.write((story_contract, moderator), false);

            // Record action
            self
                ._record_moderation_action(
                    story_contract,
                    caller,
                    'REMOVE_MODERATOR',
                    0, // Use 0 for moderator-related actions since target_id expects u256
                    "Moderator removed by creator",
                );

            self
                .emit(
                    ModeratorRemoved {
                        story: story_contract,
                        moderator,
                        removed_by: caller,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn vote_on_submission(
            ref self: ContractState,
            story_contract: ContractAddress,
            submission_id: u256,
            approve: bool,
            reason: ByteArray,
        ) {
            let caller = get_caller_address();

            // Validate caller is a moderator
            assert(self.registered_stories.read(story_contract), errors::STORY_NOT_REGISTERED);
            assert(self.story_moderators.read((story_contract, caller)), errors::NOT_MODERATOR);

            // Check if already voted
            assert(
                !self.voter_submissions.read((story_contract, submission_id, caller)),
                errors::ALREADY_VOTED,
            );

            // Mark as voted
            self.voter_submissions.write((story_contract, submission_id, caller), true);

            // Update vote count
            let mut vote_data = self.submission_votes.read((story_contract, submission_id));
            if vote_data.target_id == 0 {
                // Initialize vote data
                vote_data =
                    ModerationVote {
                        story_contract,
                        moderator: caller,
                        action: if approve {
                            'APPROVE'
                        } else {
                            'REJECT'
                        },
                        target_id: submission_id,
                        reason: reason.clone(),
                        timestamp: get_block_timestamp(),
                        votes_for: if approve {
                            1
                        } else {
                            0
                        },
                        votes_against: if approve {
                            0
                        } else {
                            1
                        },
                        is_resolved: false,
                    };
            } else {
                if approve {
                    vote_data.votes_for += 1;
                } else {
                    vote_data.votes_against += 1;
                }
            }

            // Get the values before writing to storage
            let votes_for = vote_data.votes_for;
            let votes_against = vote_data.votes_against;

            self.submission_votes.write((story_contract, submission_id), vote_data);

            self
                .emit(
                    SubmissionVoted {
                        story: story_contract,
                        submission_id,
                        voter: caller,
                        approve,
                        votes_for,
                        votes_against,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn get_submission_votes(
            self: @ContractState, story_contract: ContractAddress, submission_id: u256,
        ) -> (u32, u32) {
            let vote_data = self.submission_votes.read((story_contract, submission_id));
            (vote_data.votes_for, vote_data.votes_against)
        }

        fn can_accept_submission(
            self: @ContractState, story_contract: ContractAddress, submission_id: u256,
        ) -> bool {
            let vote_data = self.submission_votes.read((story_contract, submission_id));
            let total_moderators = self.story_moderator_counts.read(story_contract);
            let threshold_percentage = self.voting_threshold_percentage.read();

            // Calculate required votes for consensus
            let required_votes = (total_moderators * threshold_percentage.into()) / 100;

            // Check if enough votes for approval
            vote_data.votes_for >= required_votes.try_into().unwrap()
        }

        fn creator_override_submission(
            ref self: ContractState,
            story_contract: ContractAddress,
            submission_id: u256,
            action: felt252,
            reason: ByteArray,
        ) {
            let caller = get_caller_address();

            // Only story creator can override
            assert(self.registered_stories.read(story_contract), errors::STORY_NOT_REGISTERED);
            assert(self.story_creators.read(story_contract) == caller, errors::NOT_STORY_CREATOR);

            // Mark vote as resolved
            let mut vote_data = self.submission_votes.read((story_contract, submission_id));
            vote_data.is_resolved = true;
            vote_data.action = action;
            vote_data.reason = reason.clone();
            self.submission_votes.write((story_contract, submission_id), vote_data);

            // Record override action
            self
                ._record_moderation_action(
                    story_contract, caller, 'CREATOR_OVERRIDE', submission_id, reason,
                );
        }

        fn flag_accepted_chapter(
            ref self: ContractState,
            story_contract: ContractAddress,
            token_id: u256,
            reason: ByteArray,
        ) {
            let caller = get_caller_address();

            // Anyone can flag content, but require them to be a moderator
            assert(self.registered_stories.read(story_contract), errors::STORY_NOT_REGISTERED);
            assert(self.story_moderators.read((story_contract, caller)), errors::NOT_MODERATOR);

            // Mark as flagged
            self.flagged_chapters.write((story_contract, token_id), true);

            // Initialize flag vote
            let flag_vote = ModerationVote {
                story_contract,
                moderator: caller,
                action: 'FLAG',
                target_id: token_id,
                reason: reason.clone(),
                timestamp: get_block_timestamp(),
                votes_for: 0,
                votes_against: 0,
                is_resolved: false,
            };

            self.chapter_flag_votes.write((story_contract, token_id), flag_vote);

            self
                .emit(
                    ChapterFlagged {
                        story: story_contract,
                        token_id,
                        flagger: caller,
                        reason,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn vote_on_flagged_chapter(
            ref self: ContractState,
            story_contract: ContractAddress,
            token_id: u256,
            action: felt252, // 'HIDE', 'REMOVE', 'APPROVE'
            reason: ByteArray,
        ) {
            let caller = get_caller_address();

            // Validate caller is a moderator
            assert(self.registered_stories.read(story_contract), errors::STORY_NOT_REGISTERED);
            assert(self.story_moderators.read((story_contract, caller)), errors::NOT_MODERATOR);
            assert(self.flagged_chapters.read((story_contract, token_id)), errors::CONTENT_FLAGGED);

            // Update vote
            let mut vote_data = self.chapter_flag_votes.read((story_contract, token_id));
            if action == 'APPROVE' {
                vote_data.votes_for += 1;
            } else {
                vote_data.votes_against += 1;
            }

            self.chapter_flag_votes.write((story_contract, token_id), vote_data);
        }

        fn resolve_flagged_chapter(
            ref self: ContractState,
            story_contract: ContractAddress,
            token_id: u256,
            final_action: felt252,
            reason: ByteArray,
        ) {
            let caller = get_caller_address();

            // Only creator can resolve
            assert(self.story_creators.read(story_contract) == caller, errors::NOT_STORY_CREATOR);

            // Mark as resolved
            let mut vote_data = self.chapter_flag_votes.read((story_contract, token_id));
            vote_data.is_resolved = true;
            vote_data.action = final_action;
            self.chapter_flag_votes.write((story_contract, token_id), vote_data);

            // Remove flag if approved
            if final_action == 'APPROVE' {
                self.flagged_chapters.write((story_contract, token_id), false);
            }

            // Record resolution
            self
                ._record_moderation_action(
                    story_contract, caller, 'RESOLVE_FLAG', token_id, reason,
                );
        }

        fn is_story_moderator(
            self: @ContractState, story_contract: ContractAddress, moderator: ContractAddress,
        ) -> bool {
            self.story_moderators.read((story_contract, moderator))
        }

        fn get_story_moderators(
            self: @ContractState, story_contract: ContractAddress,
        ) -> Array<ContractAddress> {
            let mut moderators = ArrayTrait::new();
            let count = self.story_moderator_counts.read(story_contract);
            let mut i = 0;

            while i < count {
                let moderator = self.story_moderator_lists.read((story_contract, i));
                // Only add active moderators
                if self.story_moderators.read((story_contract, moderator)) {
                    moderators.append(moderator);
                }
                i += 1;
            };

            moderators
        }

        fn get_moderated_stories(
            self: @ContractState, moderator: ContractAddress,
        ) -> Array<ContractAddress> {
            let mut stories = ArrayTrait::new();
            let count = self.moderator_story_counts.read(moderator);
            let mut i = 0;

            while i < count {
                let story = self.moderator_stories.read((moderator, i));
                // Only add if still a moderator
                if self.story_moderators.read((story, moderator)) {
                    stories.append(story);
                }
                i += 1;
            };

            stories
        }

        fn get_submission_voting_details(
            self: @ContractState, story_contract: ContractAddress, submission_id: u256,
        ) -> ModerationVote {
            self.submission_votes.read((story_contract, submission_id))
        }

        fn record_moderation_action(
            ref self: ContractState,
            story_contract: ContractAddress,
            moderator: ContractAddress,
            action: felt252,
            target_id: u256,
            reason: ByteArray,
        ) {
            // Only allow calls from registered stories or moderators
            let caller = get_caller_address();
            assert(
                caller == story_contract || self.story_moderators.read((story_contract, caller)),
                errors::UNAUTHORIZED,
            );

            self._record_moderation_action(story_contract, moderator, action, target_id, reason);
        }

        fn get_moderation_history(
            self: @ContractState, story_contract: ContractAddress, offset: u256, limit: u256,
        ) -> Array<ModerationVote> {
            assert(limit > 0 && limit <= 100, errors::LIMIT_TOO_HIGH);

            let mut history = ArrayTrait::new();
            let total_actions = self.story_action_counts.read(story_contract);
            let end = if offset + limit > total_actions {
                total_actions
            } else {
                offset + limit
            };
            let mut i = offset;

            while i < end {
                let action = self.moderation_history.read((story_contract, i));
                history.append(action);
                i += 1;
            };

            history
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
    impl InternalFunctions of InternalFunctionsTrait {
        fn _record_moderation_action(
            ref self: ContractState,
            story_contract: ContractAddress,
            moderator: ContractAddress,
            action: felt252,
            target_id: u256,
            reason: ByteArray,
        ) {
            let action_id = self.story_action_counts.read(story_contract);

            let moderation_action = ModerationVote {
                story_contract,
                moderator,
                action,
                target_id,
                reason: reason.clone(),
                timestamp: get_block_timestamp(),
                votes_for: 0,
                votes_against: 0,
                is_resolved: true,
            };

            self.moderation_history.write((story_contract, action_id), moderation_action);
            self.story_action_counts.write(story_contract, action_id + 1);

            self
                .emit(
                    ModerationHistoryRecorded {
                        story: story_contract,
                        action_id,
                        moderator,
                        action,
                        target_id,
                        timestamp: get_block_timestamp(),
                    },
                );
        }
    }
}
