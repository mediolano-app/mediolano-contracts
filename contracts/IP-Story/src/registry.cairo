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
        interfaces::IModerationRegistry, types::ModerationVote, errors::errors,
        events::{StoryRegistered, ModerationHistoryRecorded},
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
        // Story registration
        registered_stories: Map<ContractAddress, bool>,
        story_creators: Map<ContractAddress, ContractAddress>, // story -> creator
        story_count: u256,
        stories_list: Map<u256, ContractAddress>, // index -> story
        // Moderator assignments
        story_moderators: Map<
            (ContractAddress, ContractAddress), bool,
        >, // (story, moderator) -> is_moderator
        moderator_stories: Map<
            (ContractAddress, u256), ContractAddress,
        >, // (moderator, index) -> story
        moderator_story_counts: Map<ContractAddress, u256>,
        story_moderator_lists: Map<
            (ContractAddress, u256), ContractAddress,
        >, // (story, index) -> moderator
        story_moderator_counts: Map<ContractAddress, u256>,
        // Moderation history and actions
        next_action_id: u256,
        moderation_actions: Map<u256, ModerationVote>,
        story_action_history: Map<(ContractAddress, u256), u256>, // (story, index) -> action_id
        story_action_counts: Map<ContractAddress, u256>,
        moderator_action_history: Map<
            (ContractAddress, u256), u256,
        >, // (moderator, index) -> action_id
        moderator_action_counts: Map<ContractAddress, u256>,
        // Global moderator registry
        global_moderators: Map<ContractAddress, bool>,
        global_moderator_applications: Map<ContractAddress, bool>,
        // Factory reference
        factory_contract: ContractAddress,
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
        ModerationHistoryRecorded: ModerationHistoryRecorded,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, factory_contract: ContractAddress,
    ) {
        // Validation
        assert(owner != contract_address_const::<0>(), errors::CALLER_ZERO_ADDRESS);
        assert(factory_contract != contract_address_const::<0>(), errors::INVALID_CONTRACT_ADDRESS);

        // Initialize components
        self.ownable.initializer(owner);

        // Set factory reference
        self.factory_contract.write(factory_contract);

        // Initialize counters
        self.story_count.write(0);
        self.next_action_id.write(1);
    }

    #[abi(embed_v0)]
    impl ModerationRegistryImpl of IModerationRegistry<ContractState> {
        // Moderator management
        fn register_story(
            ref self: ContractState, story_contract: ContractAddress, creator: ContractAddress,
        ) {
            let caller = get_caller_address();

            // Only factory can register stories
            assert(caller == self.factory_contract.read(), errors::REGISTRY_ACCESS_DENIED);
            assert(
                story_contract != contract_address_const::<0>(), errors::INVALID_CONTRACT_ADDRESS,
            );
            assert(creator != contract_address_const::<0>(), errors::CALLER_ZERO_ADDRESS);
            assert(!self.registered_stories.read(story_contract), errors::STORY_ALREADY_EXISTS);

            // Register the story
            self.registered_stories.write(story_contract, true);
            self.story_creators.write(story_contract, creator);

            // Add to stories list
            let story_index = self.story_count.read();
            self.stories_list.write(story_index, story_contract);
            self.story_count.write(story_index + 1);

            // Automatically assign creator as moderator
            self._assign_moderator_internal(story_contract, creator);

            // Emit event
            self
                .emit(
                    StoryRegistered {
                        registry: get_caller_address(),
                        story: story_contract,
                        creator,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn assign_story_moderator(
            ref self: ContractState, story_contract: ContractAddress, moderator: ContractAddress,
        ) {
            let caller = get_caller_address();

            // Verify story is registered
            assert(self.registered_stories.read(story_contract), errors::STORY_NOT_REGISTERED);

            // Only story creator or registry owner can assign moderators
            let creator = self.story_creators.read(story_contract);
            assert(
                caller == creator || caller == self.ownable.owner(), errors::REGISTRY_ACCESS_DENIED,
            );

            self._assign_moderator_internal(story_contract, moderator);
        }

        fn remove_story_moderator(
            ref self: ContractState, story_contract: ContractAddress, moderator: ContractAddress,
        ) {
            let caller = get_caller_address();

            // Verify story is registered
            assert(self.registered_stories.read(story_contract), errors::STORY_NOT_REGISTERED);

            // Only story creator or registry owner can remove moderators
            let creator = self.story_creators.read(story_contract);
            assert(
                caller == creator || caller == self.ownable.owner(), errors::REGISTRY_ACCESS_DENIED,
            );

            // Can't remove the story creator
            assert(moderator != creator, errors::CANNOT_REMOVE_CREATOR);

            // Verify moderator exists
            assert(
                self.story_moderators.read((story_contract, moderator)),
                errors::MODERATOR_NOT_FOUND,
            );

            self._remove_moderator_internal(story_contract, moderator);
        }

        // Query functions
        fn is_story_moderator(
            self: @ContractState, story_contract: ContractAddress, moderator: ContractAddress,
        ) -> bool {
            self.story_moderators.read((story_contract, moderator))
        }

        fn get_story_moderators(
            self: @ContractState, story_contract: ContractAddress,
        ) -> Array<ContractAddress> {
            let mut moderators = ArrayTrait::new();
            let moderator_count = self.story_moderator_counts.read(story_contract);
            let mut i = 0;

            while i < moderator_count {
                let moderator = self.story_moderator_lists.read((story_contract, i));
                moderators.append(moderator);
                i += 1;
            };

            moderators
        }

        fn get_moderated_stories(
            self: @ContractState, moderator: ContractAddress,
        ) -> Array<ContractAddress> {
            let mut stories = ArrayTrait::new();
            let story_count = self.moderator_story_counts.read(moderator);
            let mut i = 0;

            while i < story_count {
                let story = self.moderator_stories.read((moderator, i));
                stories.append(story);
                i += 1;
            };

            stories
        }

        // Moderation actions and history
        fn record_moderation_action(
            ref self: ContractState,
            story_contract: ContractAddress,
            moderator: ContractAddress,
            action: felt252,
            target_id: u256,
            reason: ByteArray,
        ) {
            let caller = get_caller_address();

            // Only the story contract itself can record actions
            assert(caller == story_contract, errors::REGISTRY_ACCESS_DENIED);

            // Verify story is registered
            assert(self.registered_stories.read(story_contract), errors::STORY_NOT_REGISTERED);

            // Verify moderator is authorized for this story
            assert(self.story_moderators.read((story_contract, moderator)), errors::NOT_MODERATOR);

            // Create moderation record
            let action_id = self.next_action_id.read();
            let moderation_vote = ModerationVote {
                voter: moderator,
                submission_id: target_id,
                action,
                reason,
                timestamp: get_block_timestamp(),
            };

            // Store the action
            self.moderation_actions.write(action_id, moderation_vote);
            self.next_action_id.write(action_id + 1);

            // Add to story history
            let story_action_count = self.story_action_counts.read(story_contract);
            self.story_action_history.write((story_contract, story_action_count), action_id);
            self.story_action_counts.write(story_contract, story_action_count + 1);

            // Add to moderator history
            let moderator_action_count = self.moderator_action_counts.read(moderator);
            self.moderator_action_history.write((moderator, moderator_action_count), action_id);
            self.moderator_action_counts.write(moderator, moderator_action_count + 1);

            // Emit event
            self
                .emit(
                    ModerationHistoryRecorded {
                        registry: get_caller_address(),
                        story: story_contract,
                        action_id,
                        moderator,
                        action,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn get_moderation_history(
            self: @ContractState, story_contract: ContractAddress, offset: u256, limit: u256,
        ) -> Array<ModerationVote> {
            assert(limit > 0 && limit <= 50, errors::LIMIT_TOO_HIGH);

            let mut history = ArrayTrait::new();
            let total_actions = self.story_action_counts.read(story_contract);
            let end = if offset + limit > total_actions {
                total_actions
            } else {
                offset + limit
            };
            let mut i = offset;

            while i < end {
                let action_id = self.story_action_history.read((story_contract, i));
                let action = self.moderation_actions.read(action_id);
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

    // Additional public functions for registry management
    #[abi(embed_v0)]
    impl RegistryManagementImpl of RegistryManagementTrait<ContractState> {
        fn get_registered_stories_count(self: @ContractState) -> u256 {
            self.story_count.read()
        }

        fn get_registered_story_by_index(self: @ContractState, index: u256) -> ContractAddress {
            assert(index < self.story_count.read(), errors::INVALID_STORY_INDEX);
            self.stories_list.read(index)
        }

        fn get_story_creator(
            self: @ContractState, story_contract: ContractAddress,
        ) -> ContractAddress {
            assert(self.registered_stories.read(story_contract), errors::STORY_NOT_REGISTERED);
            self.story_creators.read(story_contract)
        }

        fn is_registered_story(self: @ContractState, story_contract: ContractAddress) -> bool {
            self.registered_stories.read(story_contract)
        }

        fn add_global_moderator(ref self: ContractState, moderator: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(moderator != contract_address_const::<0>(), errors::CALLER_ZERO_ADDRESS);

            self.global_moderators.write(moderator, true);
        }

        fn remove_global_moderator(ref self: ContractState, moderator: ContractAddress) {
            self.ownable.assert_only_owner();

            self.global_moderators.write(moderator, false);
        }

        fn is_global_moderator(self: @ContractState, moderator: ContractAddress) -> bool {
            self.global_moderators.read(moderator)
        }

        fn get_moderator_action_count(self: @ContractState, moderator: ContractAddress) -> u256 {
            self.moderator_action_counts.read(moderator)
        }

        fn get_story_action_count(self: @ContractState, story_contract: ContractAddress) -> u256 {
            self.story_action_counts.read(story_contract)
        }
    }

    #[starknet::interface]
    trait RegistryManagementTrait<TContractState> {
        fn get_registered_stories_count(self: @TContractState) -> u256;
        fn get_registered_story_by_index(self: @TContractState, index: u256) -> ContractAddress;
        fn get_story_creator(
            self: @TContractState, story_contract: ContractAddress,
        ) -> ContractAddress;
        fn is_registered_story(self: @TContractState, story_contract: ContractAddress) -> bool;
        fn add_global_moderator(ref self: TContractState, moderator: ContractAddress);
        fn remove_global_moderator(ref self: TContractState, moderator: ContractAddress);
        fn is_global_moderator(self: @TContractState, moderator: ContractAddress) -> bool;
        fn get_moderator_action_count(self: @TContractState, moderator: ContractAddress) -> u256;
        fn get_story_action_count(self: @TContractState, story_contract: ContractAddress) -> u256;
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _assign_moderator_internal(
            ref self: ContractState, story_contract: ContractAddress, moderator: ContractAddress,
        ) {
            assert(moderator != contract_address_const::<0>(), errors::CALLER_ZERO_ADDRESS);
            assert(
                !self.story_moderators.read((story_contract, moderator)),
                errors::MODERATOR_ALREADY_EXISTS,
            );

            // Add moderator to story
            self.story_moderators.write((story_contract, moderator), true);

            // Add to story's moderator list
            let story_moderator_count = self.story_moderator_counts.read(story_contract);
            self.story_moderator_lists.write((story_contract, story_moderator_count), moderator);
            self.story_moderator_counts.write(story_contract, story_moderator_count + 1);

            // Add to moderator's story list
            let moderator_story_count = self.moderator_story_counts.read(moderator);
            self.moderator_stories.write((moderator, moderator_story_count), story_contract);
            self.moderator_story_counts.write(moderator, moderator_story_count + 1);
        }

        fn _remove_moderator_internal(
            ref self: ContractState, story_contract: ContractAddress, moderator: ContractAddress,
        ) {
            // Remove moderator mapping
            self.story_moderators.write((story_contract, moderator), false);
            // Note: For simplicity, we don't compact the arrays when removing.
        // In a production system, you might want to implement array compaction
        // or use a more sophisticated data structure.
        }
    }
}
