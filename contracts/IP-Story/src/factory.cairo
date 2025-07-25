// SPDX-License-Identifier: MIT

#[starknet::contract]
pub mod IPStoryFactory {
    use core::array::ArrayTrait;
    use core::byte_array::ByteArray;
    use starknet::{
        ContractAddress, ClassHash, get_caller_address, get_block_timestamp, contract_address_const,
        syscalls::deploy_syscall,
    };
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::super::{
        interfaces::IIPStoryFactory, types::{StoryMetadata, RoyaltyDistribution}, errors::errors,
        events::{StoryCreated, StoryUpdated},
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
        // Story tracking
        story_count: u256,
        stories: Map<u256, ContractAddress>, // index -> story contract
        story_creators: Map<ContractAddress, ContractAddress>, // story -> creator
        creator_stories: Map<(ContractAddress, u256), ContractAddress>, // (creator, index) -> story
        creator_story_counts: Map<ContractAddress, u256>,
        // Genre and search indexing
        genre_stories: Map<(felt252, u256), ContractAddress>, // (genre, index) -> story
        genre_story_counts: Map<felt252, u256>,
        // Contract configuration
        story_implementation_class_hash: ClassHash,
        moderation_registry: ContractAddress,
        platform_fee_percentage: u8,
        // Components
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        StoryCreated: StoryCreated,
        StoryUpdated: StoryUpdated,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        story_implementation_class_hash: ClassHash,
        moderation_registry: ContractAddress,
        platform_fee_percentage: u8,
    ) {
        // Validation
        assert(owner != contract_address_const::<0>(), errors::CALLER_ZERO_ADDRESS);
        assert(
            moderation_registry != contract_address_const::<0>(), errors::INVALID_CONTRACT_ADDRESS,
        );
        assert(platform_fee_percentage <= 100, errors::INVALID_ROYALTY_PERCENTAGE);

        // Initialize components
        self.ownable.initializer(owner);

        // Initialize factory state
        self.story_implementation_class_hash.write(story_implementation_class_hash);
        self.moderation_registry.write(moderation_registry);
        self.platform_fee_percentage.write(platform_fee_percentage);
        self.story_count.write(0);
    }

    #[abi(embed_v0)]
    impl IPStoryFactoryImpl of IIPStoryFactory<ContractState> {
        fn create_story(
            ref self: ContractState,
            metadata: StoryMetadata,
            shared_owners: Option<Array<ContractAddress>>,
            royalty_distribution: RoyaltyDistribution,
        ) -> ContractAddress {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            // Validate inputs
            self._validate_story_metadata(@metadata);
            self._validate_royalty_distribution(@royalty_distribution);

            // Prepare constructor calldata for story contract
            let mut constructor_calldata = ArrayTrait::new();

            // Add metadata fields
            metadata.title.serialize(ref constructor_calldata);
            metadata.description.serialize(ref constructor_calldata);
            metadata.genre.serialize(ref constructor_calldata);
            metadata.cover_image_ipfs.serialize(ref constructor_calldata);
            metadata.is_collaborative.serialize(ref constructor_calldata);
            metadata.max_chapters.serialize(ref constructor_calldata);
            metadata.content_rating.serialize(ref constructor_calldata);

            // Add creator and shared owners
            caller.serialize(ref constructor_calldata);
            shared_owners.serialize(ref constructor_calldata);

            // Add royalty distribution
            royalty_distribution.serialize(ref constructor_calldata);

            // Add factory and registry addresses
            get_caller_address().serialize(ref constructor_calldata); // factory address
            self.moderation_registry.read().serialize(ref constructor_calldata);

            // Deploy story contract
            let story_index = self.story_count.read();
            let salt: felt252 = caller.into() + metadata.genre.into() + timestamp.into();

            let (story_contract, _) = deploy_syscall(
                self.story_implementation_class_hash.read(),
                salt,
                constructor_calldata.span(),
                false,
            )
                .expect('Story deployment failed');

            // Update storage
            self.stories.write(story_index, story_contract);
            self.story_creators.write(story_contract, caller);

            // Update creator's story list
            let creator_count = self.creator_story_counts.read(caller);
            self.creator_stories.write((caller, creator_count), story_contract);
            self.creator_story_counts.write(caller, creator_count + 1);

            // Update genre index
            let genre_count = self.genre_story_counts.read(metadata.genre);
            self.genre_stories.write((metadata.genre, genre_count), story_contract);
            self.genre_story_counts.write(metadata.genre, genre_count + 1);

            // Update total count
            self.story_count.write(story_index + 1);

            // Emit event
            self
                .emit(
                    StoryCreated {
                        story_contract,
                        creator: caller,
                        title: metadata.title,
                        genre: metadata.genre,
                        is_collaborative: metadata.is_collaborative,
                        timestamp,
                    },
                );

            story_contract
        }

        fn get_story_count(self: @ContractState) -> u256 {
            self.story_count.read()
        }

        fn get_story_by_index(self: @ContractState, index: u256) -> ContractAddress {
            assert(index < self.story_count.read(), errors::INVALID_STORY_INDEX);
            self.stories.read(index)
        }

        fn get_stories_by_creator(
            self: @ContractState, creator: ContractAddress,
        ) -> Array<ContractAddress> {
            let mut stories = ArrayTrait::new();
            let creator_count = self.creator_story_counts.read(creator);
            let mut i = 0;

            while i < creator_count {
                let story = self.creator_stories.read((creator, i));
                stories.append(story);
                i += 1;
            };

            stories
        }

        fn get_stories_by_genre(self: @ContractState, genre: felt252) -> Array<ContractAddress> {
            let mut stories = ArrayTrait::new();
            let genre_count = self.genre_story_counts.read(genre);
            let mut i = 0;

            while i < genre_count {
                let story = self.genre_stories.read((genre, i));
                stories.append(story);
                i += 1;
            };

            stories
        }

        fn get_all_stories_paginated(
            self: @ContractState, offset: u256, limit: u256,
        ) -> Array<ContractAddress> {
            assert(limit > 0 && limit <= 100, errors::LIMIT_TOO_HIGH);

            let mut stories = ArrayTrait::new();
            let total_count = self.story_count.read();
            let end = if offset + limit > total_count {
                total_count
            } else {
                offset + limit
            };
            let mut i = offset;

            while i < end {
                let story = self.stories.read(i);
                stories.append(story);
                i += 1;
            };

            stories
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _validate_story_metadata(self: @ContractState, metadata: @StoryMetadata) {
            assert(metadata.title.len() > 0, errors::TITLE_TOO_SHORT);
            assert(metadata.title.len() <= 100, errors::TITLE_TOO_LONG);
            assert(metadata.description.len() <= 1000, errors::DESCRIPTION_TOO_LONG);
            // Add more validation as needed
        }

        fn _validate_royalty_distribution(
            self: @ContractState, distribution: @RoyaltyDistribution,
        ) {
            let total = *distribution.creator_percentage
                + *distribution.contributor_percentage
                + *distribution.platform_percentage;
            assert(total == 100, errors::ROYALTY_TOTAL_EXCEEDS_100);
        }
    }
}
