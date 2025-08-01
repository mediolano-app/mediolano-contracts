use core::array::ArrayTrait;
use core::traits::TryInto;
use ip_story::events::{
    ChapterAccepted, ChapterFlagged, ChapterMinted, ChapterRejected, ChapterSubmitted,
    ChapterViewed, ModerationHistoryRecorded, ModeratorAssigned, ModeratorRemoved,
    RevenueDistributed, RevenueReceived, RevenueSplitUpdated, RoyaltyClaimed, StoryCreated,
    StoryRegistered, SubmissionVoted,
};
use ip_story::factory::IPStoryFactory;
use ip_story::interfaces::{
    IIPStoryDispatcher, IIPStoryDispatcherTrait, IIPStoryFactoryDispatcher,
    IIPStoryFactoryDispatcherTrait, IModerationRegistryDispatcher,
    IModerationRegistryDispatcherTrait, IRevenueManagerDispatcher, IRevenueManagerDispatcherTrait,
};
use ip_story::registry::ModerationRegistry;
use ip_story::revenue::RevenueManager;
use ip_story::story::IPStory;
use ip_story::types::{RoyaltyDistribution, StoryMetadata};
use openzeppelin_testing::constants::{OWNER, ZERO};
use openzeppelin_testing::deployment::{declare_and_deploy, declare_class};
use openzeppelin_token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{
    CheatSpan, EventSpyAssertionsTrait, cheat_block_timestamp, cheat_caller_address, spy_events,
};
use starknet::class_hash::ClassHash;
use starknet::{ContractAddress, get_block_timestamp};

// Address constants for testing
fn AUTHOR_1() -> ContractAddress {
    declare_and_deploy("ERC1155ReceiverContract", array![])
}

fn AUTHOR_2() -> ContractAddress {
    declare_and_deploy("ERC1155ReceiverContract", array![])
}

fn CREATOR_1() -> ContractAddress {
    'creator_1'.try_into().unwrap()
}

fn CREATOR_2() -> ContractAddress {
    'creator_2'.try_into().unwrap()
}

fn MODERATOR_1() -> ContractAddress {
    'moderator_1'.try_into().unwrap()
}

fn FACTORY() -> ContractAddress {
    'factory'.try_into().unwrap()
}

fn MODERATOR_2() -> ContractAddress {
    'moderator_2'.try_into().unwrap()
}

fn READER_1() -> ContractAddress {
    'reader_1'.try_into().unwrap()
}

fn READER_2() -> ContractAddress {
    'reader_2'.try_into().unwrap()
}

fn REVENUE() -> ContractAddress {
    'revenue'.try_into().unwrap()
}

fn SPONSOR() -> ContractAddress {
    'sponsor'.try_into().unwrap()
}

fn STORY_1() -> ContractAddress {
    'story_1'.try_into().unwrap()
}

fn STORY_2() -> ContractAddress {
    'story_2'.try_into().unwrap()
}

const SAMPLE_IPFS_HASH: felt252 = 'QmSampleHash12345';
const SAMPLE_IPFS_HASH_2: felt252 = 'QmSampleHash67890';

// Helper function to create sample story metadata
fn sample_story_metadata() -> StoryMetadata {
    StoryMetadata {
        title: "The Decentralized Chronicles",
        description: "A collaborative story about the future of Web3",
        genre: 'SCIFI',
        cover_image_ipfs: SAMPLE_IPFS_HASH,
        is_collaborative: true,
        max_chapters: 0, // Unlimited
        content_rating: 'PG13',
    }
}

fn sample_royalty_distribution() -> RoyaltyDistribution {
    RoyaltyDistribution {
        creator_percentage: 40, contributor_percentage: 50, platform_percentage: 10,
    }
}

// Helper function to deploy RevenueManager
fn deploy_revenue_manager(
    owner: ContractAddress, factory: ContractAddress,
) -> IRevenueManagerDispatcher {
    let mut calldata = array![];
    calldata.append_serde(owner);
    calldata.append_serde(factory);

    let revenue_manager_address = declare_and_deploy("RevenueManager", calldata);
    IRevenueManagerDispatcher { contract_address: revenue_manager_address }
}

// Helper function to deploy ModerationRegistry
fn deploy_moderation_registry(
    owner: ContractAddress,
    factory_contract: ContractAddress,
    minimum_moderators_required: u256,
    voting_threshold_percentage: u8,
) -> IModerationRegistryDispatcher {
    let mut calldata = array![];
    calldata.append_serde(owner);
    calldata.append_serde(factory_contract);
    calldata.append_serde(minimum_moderators_required);
    calldata.append_serde(voting_threshold_percentage);

    let moderation_registry_address = declare_and_deploy("ModerationRegistry", calldata);
    IModerationRegistryDispatcher { contract_address: moderation_registry_address }
}

// Helper function to deploy IPStoryFactory
fn deploy_factory(
    owner: ContractAddress,
    story_contract_class_hash: ClassHash,
    moderation_registry: ContractAddress,
    revenue_manager: ContractAddress,
) -> IIPStoryFactoryDispatcher {
    let mut calldata = array![];
    calldata.append_serde(owner);
    calldata.append_serde(story_contract_class_hash);
    calldata.append_serde(moderation_registry);
    calldata.append_serde(revenue_manager);

    let story_factory_address = declare_and_deploy("IPStoryFactory", calldata);
    IIPStoryFactoryDispatcher { contract_address: story_factory_address }
}

// Setup environment with properly ordered deployments and unique addresses per test
fn setup_test_environment() -> (
    IIPStoryFactoryDispatcher, IModerationRegistryDispatcher, IRevenueManagerDispatcher,
) {
    let owner = OWNER;

    // 1. Deploy story contratc first to get class hash
    let story_contract_class = declare_class("IPStory");
    let story_contract_class_hash = story_contract_class.class_hash;

    // 2. Deploy moderation registry and revenue manager with a placeholder factory address first
    let placeholder_factory = FACTORY();
    let moderation_registry = deploy_moderation_registry(
        owner, placeholder_factory, 2, 60,
    ); // min 2 moderators, 60% threshold
    let revenue_manager = deploy_revenue_manager(owner, placeholder_factory);

    // 4. Now deploy factory with the real revenue manager address
    let factory = deploy_factory(
        owner,
        story_contract_class_hash,
        moderation_registry.contract_address,
        revenue_manager.contract_address,
    );

    // 5. Update moderation registry and revenue manager with deployed factory address
    cheat_caller_address(moderation_registry.contract_address, owner, CheatSpan::TargetCalls(1));
    moderation_registry.update_factory_contract(factory.contract_address);
    cheat_caller_address(revenue_manager.contract_address, owner, CheatSpan::TargetCalls(1));
    revenue_manager.update_factory_contract(factory.contract_address);

    (factory, moderation_registry, revenue_manager)
}

// Helper function to deploy a story via factory contract
fn deploy_story(factory: IIPStoryFactoryDispatcher) -> (IIPStoryDispatcher, ContractAddress) {
    let creator = CREATOR_1();

    // Create story through factory contract call
    let metadata = sample_story_metadata();
    let royalty_dist = sample_royalty_distribution();
    let shared_owners: Option<Array<ContractAddress>> = Option::None;

    cheat_caller_address(factory.contract_address, creator, CheatSpan::TargetCalls(1));
    let story_address = factory.create_story(metadata, shared_owners, royalty_dist);
    let story = IIPStoryDispatcher { contract_address: story_address };

    (story, creator)
}

// Helper function to deploy a mock ERC20 token for testing
fn deploy_mock_erc20() -> IERC20Dispatcher {
    let initial_supply = 1000000_u256;
    let recipient = CREATOR_1();

    let mut calldata = array![];
    calldata.append_serde(initial_supply);
    calldata.append_serde(recipient);

    let contract_address = declare_and_deploy("MockERC20", calldata);
    IERC20Dispatcher { contract_address }
}

// Helper function to get ERC1155 balance
fn get_erc1155_balance(
    story_address: ContractAddress, owner: ContractAddress, token_id: u256,
) -> u256 {
    let erc1155 = IERC1155Dispatcher { contract_address: story_address };
    erc1155.balance_of(owner, token_id)
}

// ============================================================================
// FACTORY CONTRACT TESTS
// ============================================================================

#[test]
fn test_factory_initialization() {
    let (factory, _, _) = setup_test_environment();

    // Test initial state
    assert(factory.get_story_count() == 0, 'Should start with 0 stories');

    // Test empty arrays
    let all_stories = factory.get_all_stories_paginated(0, 10);
    assert(all_stories.len() == 0, 'Should have no stories');

    let creator_stories = factory.get_stories_by_creator(CREATOR_1());
    assert(creator_stories.len() == 0, 'Creator should have no stories');

    let genre_stories = factory.get_stories_by_genre('SCIFI');
    assert(genre_stories.len() == 0, 'Genre should have no stories');
}

#[test]
fn test_story_creation_single_creator() {
    let (factory, _, _) = setup_test_environment();
    let creator = CREATOR_1();

    let metadata = sample_story_metadata();
    let royalty_dist = sample_royalty_distribution();

    cheat_caller_address(factory.contract_address, creator, CheatSpan::TargetCalls(1));
    let story_address = factory
        .create_story(metadata.clone(), Option::<Array<ContractAddress>>::None, royalty_dist);

    // Verify story was created
    assert(factory.get_story_count() == 1, 'Story count should be 1');
    assert(factory.get_story_by_index(0) == story_address, 'Story address mismatch');

    // Check creator's stories
    let creator_stories = factory.get_stories_by_creator(creator);
    assert(creator_stories.len() == 1, 'Creator should have 1 story');
    assert(*creator_stories.at(0) == story_address, 'Creator story mismatch');

    // Check genre indexing
    let genre_stories = factory.get_stories_by_genre('SCIFI');
    assert(genre_stories.len() == 1, 'Genre should have 1 story');
    assert(*genre_stories.at(0) == story_address, 'Genre story mismatch');
}

#[test]
fn test_story_creation_with_shared_owners() {
    let (factory, _, _) = setup_test_environment();
    let creator = CREATOR_1();
    let shared_owner = CREATOR_2();

    let metadata = sample_story_metadata();
    let royalty_dist = sample_royalty_distribution();
    let shared_owners = array![shared_owner];

    cheat_caller_address(factory.contract_address, creator, CheatSpan::TargetCalls(1));
    let _story_address = factory.create_story(metadata, Option::Some(shared_owners), royalty_dist);

    // Verify story was created
    assert(factory.get_story_count() == 1, 'Story count should be 1');

    // Both creator and shared owner should be listed as creators
    let creator_stories = factory.get_stories_by_creator(creator);
    assert(creator_stories.len() == 1, 'Creator should have 1 story');

    let shared_owner_stories = factory.get_stories_by_creator(shared_owner);
    assert(shared_owner_stories.len() == 1, 'Shared owner has 1 story');
}

#[test]
fn test_multiple_story_creation() {
    let (factory, _, _) = setup_test_environment();
    let creator1 = CREATOR_1();
    let creator2 = CREATOR_2();

    let metadata1 = StoryMetadata {
        title: "Story 1",
        description: "First story",
        genre: 'SCIFI',
        cover_image_ipfs: SAMPLE_IPFS_HASH,
        is_collaborative: true,
        max_chapters: 10,
        content_rating: 'G',
    };

    let metadata2 = StoryMetadata {
        title: "Story 2",
        description: "Second story",
        genre: 'FANTASY',
        cover_image_ipfs: SAMPLE_IPFS_HASH_2,
        is_collaborative: false,
        max_chapters: 0,
        content_rating: 'R',
    };

    let royalty_dist = sample_royalty_distribution();

    // Creator 1 creates first story
    cheat_caller_address(factory.contract_address, creator1, CheatSpan::TargetCalls(1));
    let story1 = factory
        .create_story(metadata1, Option::<Array<ContractAddress>>::None, royalty_dist);

    // Creator 2 creates second story
    cheat_caller_address(factory.contract_address, creator2, CheatSpan::TargetCalls(1));
    let story2 = factory
        .create_story(metadata2, Option::<Array<ContractAddress>>::None, royalty_dist);

    // Verify total count
    assert(factory.get_story_count() == 2, 'Should have 2 stories');

    // Verify individual access
    assert(factory.get_story_by_index(0) == story1, 'First story mismatch');
    assert(factory.get_story_by_index(1) == story2, 'Second story mismatch');

    // Verify creator-specific access
    let creator1_stories = factory.get_stories_by_creator(creator1);
    assert(creator1_stories.len() == 1, 'Creator1 should have 1 story');

    let creator2_stories = factory.get_stories_by_creator(creator2);
    assert(creator2_stories.len() == 1, 'Creator2 should have 1 story');

    // Verify genre-specific access
    let scifi_stories = factory.get_stories_by_genre('SCIFI');
    assert(scifi_stories.len() == 1, 'SCIFI should have 1 story');

    let fantasy_stories = factory.get_stories_by_genre('FANTASY');
    assert(fantasy_stories.len() == 1, 'FANTASY should have 1 story');
}

#[test]
fn test_story_pagination() {
    let (factory, _, _) = setup_test_environment();
    let creator = CREATOR_1();
    let royalty_dist = sample_royalty_distribution();

    // Create 5 stories with unique metadata to avoid deployment conflicts
    cheat_caller_address(factory.contract_address, creator, CheatSpan::TargetCalls(5));
    let mut story_addresses = array![];
    let mut i: u32 = 0;
    while i < 5_u32 {
        // Use unique timestamp for each story to ensure different salt
        cheat_block_timestamp(
            factory.contract_address, get_block_timestamp() + i.into(), CheatSpan::TargetCalls(1),
        );

        let metadata = StoryMetadata {
            title: "Story",
            description: "Description",
            genre: if i % 2 == 0 {
                'SCIFI'
            } else {
                'FANTASY'
            }, // Alternate genres for uniqueness
            cover_image_ipfs: SAMPLE_IPFS_HASH + i.into(), // Unique IPFS hash
            is_collaborative: true,
            max_chapters: 0,
            content_rating: 'PG',
        };

        let story_addr = factory
            .create_story(metadata, Option::<Array<ContractAddress>>::None, royalty_dist);
        story_addresses.append(story_addr);
        i += 1;
    }

    // Test pagination
    let page0 = factory.get_all_stories_paginated(0, 2); // First 2
    assert(page0.len() == 2, 'Page 0 should have 2 stories');
    assert(*page0.at(0) == *story_addresses.at(0), 'Page 0 first story mismatch');
    assert(*page0.at(1) == *story_addresses.at(1), 'Page 0 second story mismatch');

    let page1 = factory.get_all_stories_paginated(2, 2); // Next 2
    assert(page1.len() == 2, 'Page 1 should have 2 stories');
    assert(*page1.at(0) == *story_addresses.at(2), 'Page 1 first story mismatch');
    assert(*page1.at(1) == *story_addresses.at(3), 'Page 1 second story mismatch');

    let page2 = factory.get_all_stories_paginated(4, 2); // Last 1
    assert(page2.len() == 1, 'Page 2 should have 1 story');
    assert(*page2.at(0) == *story_addresses.at(4), 'Page 2 story mismatch');

    let page3 = factory.get_all_stories_paginated(5, 2); // Should be empty
    assert(page3.len() == 0, 'Page 3 should be empty');
}

#[test]
fn test_genre_filtering() {
    let (factory, _, _) = setup_test_environment();
    let creator = CREATOR_1();
    let royalty_dist = sample_royalty_distribution();

    // Create stories with different genres
    cheat_caller_address(factory.contract_address, creator, CheatSpan::TargetCalls(4));

    // 2 SCIFI stories
    let scifi1 = factory
        .create_story(
            StoryMetadata {
                title: "SciFi 1",
                description: "First sci-fi",
                genre: 'SCIFI',
                cover_image_ipfs: SAMPLE_IPFS_HASH,
                is_collaborative: true,
                max_chapters: 0,
                content_rating: 'PG',
            },
            Option::<Array<ContractAddress>>::None,
            royalty_dist,
        );

    let scifi2 = factory
        .create_story(
            StoryMetadata {
                title: "SciFi 2",
                description: "Second sci-fi",
                genre: 'SCIFI',
                cover_image_ipfs: SAMPLE_IPFS_HASH,
                is_collaborative: true,
                max_chapters: 0,
                content_rating: 'PG',
            },
            Option::<Array<ContractAddress>>::None,
            royalty_dist,
        );

    // 1 FANTASY story
    let fantasy1 = factory
        .create_story(
            StoryMetadata {
                title: "Fantasy 1",
                description: "First fantasy",
                genre: 'FANTASY',
                cover_image_ipfs: SAMPLE_IPFS_HASH,
                is_collaborative: true,
                max_chapters: 0,
                content_rating: 'PG',
            },
            Option::<Array<ContractAddress>>::None,
            royalty_dist,
        );

    // 1 MYSTERY story
    let mystery1 = factory
        .create_story(
            StoryMetadata {
                title: "Mystery 1",
                description: "First mystery",
                genre: 'MYSTERY',
                cover_image_ipfs: SAMPLE_IPFS_HASH,
                is_collaborative: true,
                max_chapters: 0,
                content_rating: 'PG',
            },
            Option::<Array<ContractAddress>>::None,
            royalty_dist,
        );

    // Test genre filtering
    let scifi_stories = factory.get_stories_by_genre('SCIFI');
    assert(scifi_stories.len() == 2, 'Should have 2 SCIFI stories');
    assert(*scifi_stories.at(0) == scifi1, 'First SCIFI story mismatch');
    assert(*scifi_stories.at(1) == scifi2, 'Second SCIFI story mismatch');

    let fantasy_stories = factory.get_stories_by_genre('FANTASY');
    assert(fantasy_stories.len() == 1, 'Should have 1 FANTASY story');
    assert(*fantasy_stories.at(0) == fantasy1, 'FANTASY story mismatch');

    let mystery_stories = factory.get_stories_by_genre('MYSTERY');
    assert(mystery_stories.len() == 1, 'Should have 1 MYSTERY story');
    assert(*mystery_stories.at(0) == mystery1, 'MYSTERY story mismatch');

    let horror_stories = factory.get_stories_by_genre('HORROR');
    assert(horror_stories.len() == 0, 'Should have 0 HORROR stories');
}

#[test]
#[should_panic(expected: ('Title too short',))]
fn test_invalid_metadata_validation_empty_title() {
    let (factory, _, _) = setup_test_environment();
    let creator = CREATOR_1();

    let invalid_metadata = StoryMetadata {
        title: "", // Empty title should fail
        description: "Valid description",
        genre: 'SCIFI',
        cover_image_ipfs: SAMPLE_IPFS_HASH,
        is_collaborative: true,
        max_chapters: 0,
        content_rating: 'PG',
    };

    cheat_caller_address(factory.contract_address, creator, CheatSpan::TargetCalls(1));
    factory.create_story(invalid_metadata, Option::None, sample_royalty_distribution());
}

#[test]
#[should_panic(expected: ('Total royalty exceeds 100%',))]
fn test_invalid_royalty_distribution() {
    let (factory, _, _) = setup_test_environment();
    let creator = CREATOR_1();

    let invalid_royalty = RoyaltyDistribution {
        creator_percentage: 60,
        contributor_percentage: 50, // 60 + 50 + 10 = 120% > 100%
        platform_percentage: 10,
    };

    cheat_caller_address(factory.contract_address, creator, CheatSpan::TargetCalls(1));
    factory.create_story(sample_story_metadata(), Option::None, invalid_royalty);
}

#[test]
#[should_panic(expected: ('Invalid story index',))]
fn test_get_story_by_invalid_index() {
    let (factory, _, _) = setup_test_environment();

    // Try to access story at index 0 when no stories exist
    factory.get_story_by_index(0);
}

#[test]
#[should_panic(expected: ('Limit too high',))]
fn test_pagination_limit_validation() {
    let (factory, _, _) = setup_test_environment();

    // Try to use limit higher than allowed maximum
    factory.get_all_stories_paginated(0, 101); // Assuming max limit is 100
}

#[test]
fn test_factory_boundary_conditions() {
    let (factory, _, _) = setup_test_environment();
    let creator = CREATOR_1();

    // Test with minimum valid metadata
    let min_metadata = StoryMetadata {
        title: "A", // Single character title
        description: "",
        genre: 'OTHER',
        cover_image_ipfs: 0,
        is_collaborative: false,
        max_chapters: 1, // Minimum chapters
        content_rating: 'G',
    };

    let min_royalty = RoyaltyDistribution {
        creator_percentage: 100, contributor_percentage: 0, platform_percentage: 0,
    };

    cheat_caller_address(factory.contract_address, creator, CheatSpan::TargetCalls(1));
    let story_addr = factory.create_story(min_metadata, Option::None, min_royalty);

    assert(factory.get_story_count() == 1, 'Should create story with data');
    assert(factory.get_story_by_index(0) == story_addr, 'Story address should match');
}

#[test]
fn test_factory_events() {
    let (factory, _, _) = setup_test_environment();
    let creator = CREATOR_1();
    let mut spy = spy_events();

    let metadata = sample_story_metadata();
    let royalty_dist = sample_royalty_distribution();

    cheat_caller_address(factory.contract_address, creator, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(factory.contract_address, 12345, CheatSpan::TargetCalls(1));

    let story_address = factory.create_story(metadata.clone(), Option::None, royalty_dist);

    // Verify StoryCreated event was emitted from factory
    spy
        .assert_emitted(
            @array![
                (
                    factory.contract_address,
                    IPStoryFactory::Event::StoryCreated(
                        StoryCreated {
                            story_contract: story_address,
                            creator: creator,
                            title: metadata.title,
                            genre: metadata.genre,
                            is_collaborative: metadata.is_collaborative,
                            timestamp: 12345,
                        },
                    ),
                ),
            ],
        );
}

// ============================================================================
// STORY CONTRACT TESTS
// ============================================================================

#[test]
fn test_story_initialization() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);

    // Test story metadata
    let metadata = story.get_story_metadata();
    assert(metadata.title == "The Decentralized Chronicles", 'Title mismatch');
    assert(metadata.genre == 'SCIFI', 'Genre mismatch');
    assert(metadata.is_collaborative == true, 'Collaborative flag mismatch');

    // Test story statistics
    let stats = story.get_story_statistics();
    assert(stats.total_chapters == 0, 'Should start with 0 chapters');
    assert(stats.total_submissions == 0, 'Should start with 0 submissions');
    assert(stats.pending_submissions == 0, 'Should start with 0 pending');
    assert(stats.total_contributors == 0, 'Contributors should be 0');

    // Test story creators
    let creators = story.get_story_creators();
    assert(creators.len() == 1, 'Should have 1 creator');
    assert(*creators.at(0) == creator, 'Creator mismatch');
    assert(story.is_story_creator(creator), 'Creator check failed');
    assert(!story.is_story_creator(AUTHOR_1()), 'Non-creator check failed');
}

#[test]
fn test_chapter_submission() {
    let (factory, _, _) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let author = AUTHOR_1();
    let mut spy = spy_events();

    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(story.contract_address, 12345, CheatSpan::TargetCalls(1));

    let submission_id = story.submit_chapter("Chapter 1: The Beginning", SAMPLE_IPFS_HASH);

    // Verify submission was created
    assert(submission_id == 1, 'Submission ID should be 1');

    // Check submission details
    let submission = story.get_chapter_submission(submission_id);
    assert(submission.title == "Chapter 1: The Beginning", 'Submission title mismatch');
    assert(submission.ipfs_hash == SAMPLE_IPFS_HASH, 'IPFS hash mismatch');
    assert(submission.author == author, 'Author mismatch');
    assert(submission.submission_id == submission_id, 'Submission ID mismatch');
    assert(!submission.is_under_review, 'Should not be under review');

    // Check story statistics updated
    let stats = story.get_story_statistics();
    assert(stats.total_submissions == 1, 'Total submissions should be 1');
    assert(stats.pending_submissions == 1, 'Pending submissions should be 1');

    // Verify ChapterSubmitted event
    spy
        .assert_emitted(
            @array![
                (
                    story.contract_address,
                    IPStory::Event::ChapterSubmitted(
                        ChapterSubmitted {
                            story: story.contract_address,
                            submission_id,
                            author,
                            title: "Chapter 1: The Beginning",
                            ipfs_hash: SAMPLE_IPFS_HASH,
                            timestamp: 12345,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_multiple_chapter_submissions() {
    let (factory, _, _) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let author1 = AUTHOR_1();
    let author2 = AUTHOR_2();

    // Author 1 submits first chapter
    cheat_caller_address(story.contract_address, author1, CheatSpan::TargetCalls(1));
    let submission_id1 = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);

    // Author 2 submits second chapter
    cheat_caller_address(story.contract_address, author2, CheatSpan::TargetCalls(1));
    let submission_id2 = story.submit_chapter("Chapter 2", SAMPLE_IPFS_HASH_2);

    // Verify both submissions
    assert(submission_id1 == 1, '1st submission ID should be 1');
    assert(submission_id2 == 2, '2nd submission ID should be 2');

    let submission1 = story.get_chapter_submission(submission_id1);
    let submission2 = story.get_chapter_submission(submission_id2);

    assert(submission1.author == author1, 'First author mismatch');
    assert(submission2.author == author2, 'Second author mismatch');
    assert(submission1.title == "Chapter 1", 'First title mismatch');
    assert(submission2.title == "Chapter 2", 'Second title mismatch');

    // Check statistics
    let stats = story.get_story_statistics();
    assert(stats.total_submissions == 2, 'Should have 2 total submissions');
    assert(stats.pending_submissions == 2, 'Should be 2 pending submissions');
}

#[test]
fn test_chapter_acceptance() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author = AUTHOR_1();
    let mut spy = spy_events();

    // Submit chapter
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    let submission_id = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);

    // Creator accepts chapter
    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(story.contract_address, 54321, CheatSpan::TargetCalls(1));
    let token_id = story.accept_chapter(submission_id);

    // Verify token was minted
    assert(token_id == 1, 'Token ID should be 1');

    // Check accepted chapter
    let chapter = story.get_accepted_chapter(token_id);
    assert(chapter.title == "Chapter 1", 'Chapter title mismatch');
    assert(chapter.author == author, 'Chapter author mismatch');
    assert(chapter.submission_id == submission_id, 'Submission link mismatch');
    assert(chapter.chapter_number == 1, 'Chapter number should be 1');
    assert(chapter.accepted_by == creator, 'Accepted by mismatch');
    assert(chapter.token_id == token_id, 'Token ID mismatch');

    // Check statistics updated
    let stats = story.get_story_statistics();
    assert(stats.total_chapters == 1, 'Should have 1 chapter');
    assert(stats.pending_submissions == 0, 'Should have 0 pending');

    // Verify events
    spy
        .assert_emitted(
            @array![
                (
                    story.contract_address,
                    IPStory::Event::ChapterAccepted(
                        ChapterAccepted {
                            story: story.contract_address,
                            submission_id,
                            token_id,
                            chapter_number: 1,
                            author,
                            accepted_by: creator,
                            title: "Chapter 1",
                            timestamp: 54321,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_chapter_rejection() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author = AUTHOR_1();
    let mut spy = spy_events();

    // Submit chapter
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    let submission_id = story.submit_chapter("Bad Chapter", SAMPLE_IPFS_HASH);

    // Creator rejects chapter
    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(story.contract_address, 54321, CheatSpan::TargetCalls(1));
    story.reject_chapter(submission_id, "Does not fit story theme");

    // Check statistics updated
    let stats = story.get_story_statistics();
    assert(stats.total_chapters == 0, 'Should have 0 chapters');
    assert(stats.pending_submissions == 0, 'Should have 0 pending');

    // Verify ChapterRejected event
    spy
        .assert_emitted(
            @array![
                (
                    story.contract_address,
                    IPStory::Event::ChapterRejected(
                        ChapterRejected {
                            story: story.contract_address,
                            submission_id,
                            rejected_by: creator,
                            reason: "Does not fit story theme",
                            timestamp: 54321,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_chapter_submission_pagination() {
    let (factory, _, _) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let author = AUTHOR_1();

    // Submit 5 chapters
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(5));
    let mut submission_ids = array![];
    let mut i: u32 = 0;
    while i < 5_u32 {
        let submission_id = story.submit_chapter("Chapter", SAMPLE_IPFS_HASH);
        submission_ids.append(submission_id);
        i += 1;
    }

    // Test pagination
    let page0 = story.get_chapter_submissions_paginated(0, 2);
    assert(page0.len() == 2, 'Page 1 should have 2 submission');
    assert(page0.at(0).submission_id == submission_ids.at(0), 'Page 0 1st submission mismatch');
    assert(page0.at(1).submission_id == submission_ids.at(1), 'Page 0 2nd submission mismatch');

    let page1 = story.get_chapter_submissions_paginated(2, 2);
    assert(page1.len() == 2, 'Page 1 should have 2 submission');

    let page2 = story.get_chapter_submissions_paginated(4, 2);
    assert(page2.len() == 1, 'Page 2 should have 1 submission');

    // Test pending submissions
    let pending = story.get_pending_submissions();
    assert(pending.len() == 5, 'Should be 5 pending submissions');
}

#[test]
fn test_accepted_chapters_pagination() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author = AUTHOR_1();

    // Submit and accept 3 chapters
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(3));
    let mut token_ids = array![];
    let mut i = 0;
    while i < 3_u32 {
        let submission_id = story.submit_chapter("Chapter", SAMPLE_IPFS_HASH);

        cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
        let token_id = story.accept_chapter(submission_id);
        token_ids.append(token_id);

        cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
        i += 1;
    }

    // Test total chapters count
    assert(story.get_total_story_chapters() == 3, 'Should have 3 total chapters');

    // Test pagination
    let page0 = story.get_story_chapters_paginated(0, 2);
    assert(page0.len() == 2, 'Page 0 should have 2 chapters');
    assert(page0.at(0).token_id == token_ids.at(0), 'Page 0 first chapter mismatch');
    assert(page0.at(1).token_id == token_ids.at(1), 'Page 0 second chapter mismatch');

    let page1 = story.get_story_chapters_paginated(2, 2);
    assert(page1.len() == 1, 'Page 1 should have 1 chapter');
    assert(page1.at(0).token_id == token_ids.at(2), 'Page 1 chapter mismatch');
}

#[test]
fn test_chapters_by_author() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author1 = AUTHOR_1();
    let author2 = AUTHOR_2();

    // Author 1 submits and gets 2 chapters accepted
    cheat_caller_address(story.contract_address, author1, CheatSpan::TargetCalls(2));
    let submission1 = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);
    let submission2 = story.submit_chapter("Chapter 3", SAMPLE_IPFS_HASH);

    // Author 2 submits and gets 1 chapter accepted
    cheat_caller_address(story.contract_address, author2, CheatSpan::TargetCalls(1));
    let submission3 = story.submit_chapter("Chapter 2", SAMPLE_IPFS_HASH);

    // Accept all chapters
    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(3));
    let _token1 = story.accept_chapter(submission1);
    let _token2 = story.accept_chapter(submission3);
    let _token3 = story.accept_chapter(submission2);

    // Test chapters by author
    let author1_chapters = story.get_chapters_by_author(author1, 0, 10);
    assert(author1_chapters.len() == 2, 'Author 1 should have 2 chapters');
    assert(author1_chapters.at(0).author == @author1, 'Author 1 chapter 0 mismatch');
    assert(author1_chapters.at(1).author == @author1, 'Author 1 chapter 1 mismatch');

    let author2_chapters = story.get_chapters_by_author(author2, 0, 10);
    assert(author2_chapters.len() == 1, 'Author 2 should have 1 chapter');
    assert(author2_chapters.at(0).author == @author2, 'Author 2 chapter mismatch');
}

#[test]
fn test_story_creator_management() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let new_creator = CREATOR_2();

    // Add new creator
    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    story.add_story_creator(new_creator);

    // Verify new creator was added
    assert(story.is_story_creator(new_creator), 'New creator should be added');

    let creators = story.get_story_creators();
    assert(creators.len() == 2, 'Should have 2 creators');

    // New creator should be able to accept chapters
    cheat_caller_address(story.contract_address, AUTHOR_1(), CheatSpan::TargetCalls(1));
    let submission_id = story.submit_chapter("Test Chapter", SAMPLE_IPFS_HASH);

    cheat_caller_address(story.contract_address, new_creator, CheatSpan::TargetCalls(1));
    let token_id = story.accept_chapter(submission_id);
    assert(token_id == 1, 'New creator can accept');

    // Remove creator
    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    story.remove_story_creator(new_creator);

    assert(!story.is_story_creator(new_creator), 'Creator should be removed');
}

#[test]
fn test_batch_operations() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author = AUTHOR_1();

    // Submit and accept multiple chapters
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(3));
    let submission1 = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);
    let submission2 = story.submit_chapter("Chapter 2", SAMPLE_IPFS_HASH);
    let submission3 = story.submit_chapter("Chapter 3", SAMPLE_IPFS_HASH);

    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(3));
    let token1 = story.accept_chapter(submission1);
    let _token2 = story.accept_chapter(submission2);
    let token3 = story.accept_chapter(submission3);

    // Test batch get chapters
    let chapter_ids = array![token1, token3]; // Get chapters 1 and 3
    let batch_chapters = story.batch_get_chapters(chapter_ids);
    assert(batch_chapters.len() == 2, 'Batch should return 2 chapters');
    assert(batch_chapters.at(0).token_id == @token1, 'First batch chapter mismatch');
    assert(batch_chapters.at(1).token_id == @token3, 'Second batch chapter mismatch');

    // Test batch get submissions
    let submission_ids = array![submission1, submission2];
    let batch_submissions = story.batch_get_submissions(submission_ids);
    assert(batch_submissions.len() == 2, 'Should return 2 submissions');
    assert(batch_submissions.at(0).submission_id == @submission1, '1st batch submission mismatch');
    assert(batch_submissions.at(1).submission_id == @submission2, '2nd batch submission mismatch');
}

#[test]
fn test_max_chapters_limit() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author = AUTHOR_1();

    // Submit first chapter (should succeed)
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    let submission1 = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);

    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    story.accept_chapter(submission1);

    // Submit second chapter (should succeed)
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    let submission2 = story.submit_chapter("Chapter 2", SAMPLE_IPFS_HASH);

    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    story.accept_chapter(submission2);

    // Verify we have 2 chapters
    assert(story.get_total_story_chapters() == 2, 'Should have 2 chapters');
}

#[test]
#[should_panic(expected: ('Chapter title cannot be empty',))]
fn test_empty_chapter_title_fails() {
    let (factory, _, _) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let author = AUTHOR_1();

    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    story.submit_chapter("", SAMPLE_IPFS_HASH); // Empty title should fail
}

#[test]
#[should_panic(expected: ('Invalid IPFS hash provided',))]
fn test_invalid_ipfs_hash_fails() {
    let (factory, _, _) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let author = AUTHOR_1();

    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    story.submit_chapter("Valid Title", 0); // Zero IPFS hash should fail
}

#[test]
#[should_panic(expected: ('Not a story creator',))]
fn test_non_creator_accept_fails() {
    let (factory, _, _) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let author = AUTHOR_1();
    let non_creator = AUTHOR_2();

    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    let submission_id = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);

    cheat_caller_address(story.contract_address, non_creator, CheatSpan::TargetCalls(1));
    story.accept_chapter(submission_id); // Non-creator should not be able to accept
}

#[test]
#[should_panic(expected: ('Submission already processed',))]
fn test_double_accept_fails() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author = AUTHOR_1();

    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    let submission_id = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);

    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(2));
    story.accept_chapter(submission_id); // First accept should succeed
    story.accept_chapter(submission_id); // Second accept should fail
}

#[test]
#[should_panic(expected: ('Cannot remove last creator',))]
fn test_cannot_remove_last_creator() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);

    // Try to remove the only creator
    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    story.remove_story_creator(creator); // Should fail
}

// ============================================================================
// NFT MINTING FUNCTION TESTS
// ============================================================================

#[test]
fn test_mint_chapter_success() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author = AUTHOR_1();
    let mut spy = spy_events();

    // Submit and accept chapter first
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    let submission_id = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);

    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    let token_id = story.accept_chapter(submission_id);

    // Verify chapter is accepted but not minted yet
    let balance_before = get_erc1155_balance(story.contract_address, author, token_id);
    assert(balance_before == 0, 'Should not be minted yet');

    // Now mint the chapter
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(story.contract_address, 99999, CheatSpan::TargetCalls(1));
    story.mint_chapter(token_id);

    // Verify chapter was minted
    let balance_after = get_erc1155_balance(story.contract_address, author, token_id);
    assert(balance_after == 1, 'Chapter should be minted');

    // Verify ChapterMinted event
    spy
        .assert_emitted(
            @array![
                (
                    story.contract_address,
                    IPStory::Event::ChapterMinted(
                        ChapterMinted {
                            story: story.contract_address,
                            token_id,
                            author,
                            chapter_number: 1,
                            title: "Chapter 1",
                            ipfs_hash: SAMPLE_IPFS_HASH,
                            timestamp: 99999,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: ('Chapter not found',))]
fn test_mint_nonexistent_chapter_fails() {
    let (factory, _, _) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let author = AUTHOR_1();

    // Try to mint non-existent chapter
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    story.mint_chapter(999); // Should fail
}

#[test]
#[should_panic(expected: ('Only author mints chapter NFT',))]
fn test_mint_by_non_author_fails() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author1 = AUTHOR_1();
    let author2 = AUTHOR_2();

    // Submit and accept chapter
    cheat_caller_address(story.contract_address, author1, CheatSpan::TargetCalls(1));
    let submission_id = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);

    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    let token_id = story.accept_chapter(submission_id);

    cheat_caller_address(story.contract_address, author2, CheatSpan::TargetCalls(1));
    story.mint_chapter(token_id); // Should fail
}

#[test]
#[should_panic(expected: ('Chapter already minted',))]
fn test_mint_already_minted_chapter_fails() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author = AUTHOR_1();

    // Submit and accept chapter
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    let submission_id = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);

    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    let token_id = story.accept_chapter(submission_id);

    // Mint chapter first time
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    story.mint_chapter(token_id);

    // Try to mint again - should fail
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    story.mint_chapter(token_id); // Should fail
}

#[test]
fn test_batch_mint_chapters_success() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author1 = AUTHOR_1();
    let author2 = AUTHOR_2();
    let mut spy = spy_events();

    // Submit and accept multiple chapters
    cheat_caller_address(story.contract_address, author1, CheatSpan::TargetCalls(2));
    let submission_id1 = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);
    let submission_id2 = story.submit_chapter("Chapter 2", SAMPLE_IPFS_HASH_2);

    cheat_caller_address(story.contract_address, author2, CheatSpan::TargetCalls(1));
    let submission_id3 = story.submit_chapter("Chapter 3", SAMPLE_IPFS_HASH);

    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(3));
    let token_id1 = story.accept_chapter(submission_id1);
    let token_id2 = story.accept_chapter(submission_id2);
    let token_id3 = story.accept_chapter(submission_id3);

    // Verify chapters are not minted yet
    assert(
        get_erc1155_balance(story.contract_address, author1, token_id1) == 0,
        'Chapter 1 not minted yet',
    );
    assert(
        get_erc1155_balance(story.contract_address, author1, token_id2) == 0,
        'Chapter 2 not minted yet',
    );
    assert(
        get_erc1155_balance(story.contract_address, author2, token_id3) == 0,
        'Chapter 3 not minted yet',
    );

    // Batch mint chapters
    let token_ids = array![token_id1, token_id2, token_id3];
    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(story.contract_address, 88888, CheatSpan::TargetCalls(1));
    story.batch_mint_chapters(token_ids);

    // Verify all chapters were minted
    assert(
        get_erc1155_balance(story.contract_address, author1, token_id1) == 1,
        'Chapter 1 should be minted',
    );
    assert(
        get_erc1155_balance(story.contract_address, author1, token_id2) == 1,
        'Chapter 2 should be minted',
    );
    assert(
        get_erc1155_balance(story.contract_address, author2, token_id3) == 1,
        'Chapter 3 should be minted',
    );

    // Verify multiple ChapterMinted events were emitted
    spy
        .assert_emitted(
            @array![
                (
                    story.contract_address,
                    IPStory::Event::ChapterMinted(
                        ChapterMinted {
                            story: story.contract_address,
                            token_id: token_id1,
                            author: author1,
                            chapter_number: 1,
                            title: "Chapter 1",
                            ipfs_hash: SAMPLE_IPFS_HASH,
                            timestamp: 88888,
                        },
                    ),
                ),
            ],
        );

    spy
        .assert_emitted(
            @array![
                (
                    story.contract_address,
                    IPStory::Event::ChapterMinted(
                        ChapterMinted {
                            story: story.contract_address,
                            token_id: token_id2,
                            author: author1,
                            chapter_number: 2,
                            title: "Chapter 2",
                            ipfs_hash: SAMPLE_IPFS_HASH_2,
                            timestamp: 88888,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_batch_mint_chapters_partial_success() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author = AUTHOR_1();

    // Submit and accept chapters
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(2));
    let submission_id1 = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);
    let submission_id2 = story.submit_chapter("Chapter 2", SAMPLE_IPFS_HASH_2);

    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(2));
    let token_id1 = story.accept_chapter(submission_id1);
    let token_id2 = story.accept_chapter(submission_id2);

    // Mint one chapter manually first
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(story.contract_address, 88888, CheatSpan::TargetCalls(1));
    story.mint_chapter(token_id1);

    // Verify balances before batch mint
    assert(
        get_erc1155_balance(story.contract_address, author, token_id1) == 1,
        'Chapter 1 already minted',
    );
    assert(
        get_erc1155_balance(story.contract_address, author, token_id2) == 0,
        'Chapter 2 not minted yet',
    );

    // Try to batch mint both (one already minted, one not)
    let token_ids = array![token_id1, token_id2];
    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(story.contract_address, 88889, CheatSpan::TargetCalls(1));
    story.batch_mint_chapters(token_ids);

    // Verify balances after batch mint
    assert(
        get_erc1155_balance(story.contract_address, author, token_id1) == 1,
        'Chapter 1 stays minted',
    );
    assert(
        get_erc1155_balance(story.contract_address, author, token_id2) == 1,
        'Chapter 2 should be minted',
    );
}

#[test]
#[should_panic(expected: ('Not a story creator',))]
fn test_batch_mint_chapters_non_creator_fails() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author = AUTHOR_1();
    let non_creator = AUTHOR_2();

    // Submit and accept chapter
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    let submission_id = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);

    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    let token_id = story.accept_chapter(submission_id);

    // Non-creator tries to batch mint
    let token_ids = array![token_id];
    cheat_caller_address(story.contract_address, non_creator, CheatSpan::TargetCalls(1));
    story.batch_mint_chapters(token_ids); // Should fail
}

#[test]
#[should_panic(expected: ('Invalid batch size',))]
fn test_batch_mint_chapters_empty_array_fails() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);

    // Try to batch mint with empty array
    let token_ids = array![];
    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    story.batch_mint_chapters(token_ids); // Should fail
}

#[test]
#[should_panic(expected: ('No valid chapters to mint',))]
fn test_batch_mint_chapters_no_valid_chapters_fails() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);

    // Try to batch mint non-existent chapters
    let token_ids = array![999, 1000, 1001];
    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    story.batch_mint_chapters(token_ids); // Should fail
}

#[test]
fn test_batch_mint_by_author_success() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author1 = AUTHOR_1();
    let author2 = AUTHOR_2();

    // Author1 submits multiple chapters
    cheat_caller_address(story.contract_address, author1, CheatSpan::TargetCalls(3));
    let submission_id1 = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);
    let submission_id2 = story.submit_chapter("Chapter 2", SAMPLE_IPFS_HASH_2);
    let submission_id3 = story.submit_chapter("Chapter 3", SAMPLE_IPFS_HASH);

    // Author2 submits one chapter
    cheat_caller_address(story.contract_address, author2, CheatSpan::TargetCalls(1));
    let submission_id4 = story.submit_chapter("Chapter 4", SAMPLE_IPFS_HASH);

    // Accept all chapters
    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(4));
    let token_id1 = story.accept_chapter(submission_id1);
    let token_id2 = story.accept_chapter(submission_id2);
    let token_id3 = story.accept_chapter(submission_id3);
    let token_id4 = story.accept_chapter(submission_id4);

    // Verify chapters are not minted yet
    assert(
        get_erc1155_balance(story.contract_address, author1, token_id1) == 0,
        'Chapter 1 not minted yet',
    );
    assert(
        get_erc1155_balance(story.contract_address, author1, token_id2) == 0,
        'Chapter 2 not minted yet',
    );
    assert(
        get_erc1155_balance(story.contract_address, author1, token_id3) == 0,
        'Chapter 3 not minted yet',
    );
    assert(
        get_erc1155_balance(story.contract_address, author1, token_id4) == 0,
        'Chapter 4 not minted yet',
    );

    // Batch mint by author1
    cheat_caller_address(story.contract_address, author1, CheatSpan::TargetCalls(1));
    story.batch_mint_by_author(author1);

    // Verify only author1's chapters were minted
    assert(
        get_erc1155_balance(story.contract_address, author1, token_id1) == 1,
        'Chapter 1 should be minted',
    );
    assert(
        get_erc1155_balance(story.contract_address, author1, token_id2) == 1,
        'Chapter 2 should be minted',
    );
    assert(
        get_erc1155_balance(story.contract_address, author1, token_id3) == 1,
        'Chapter 3 should be minted',
    );
    assert(
        get_erc1155_balance(story.contract_address, author2, token_id4) == 0,
        'Chapter 4 still not minted',
    );

    // Batch mint by author2
    cheat_caller_address(story.contract_address, author2, CheatSpan::TargetCalls(1));
    story.batch_mint_by_author(author2);

    // Verify author2's chapter was minted
    assert(
        get_erc1155_balance(story.contract_address, author2, token_id4) == 1,
        'Chapter 4 should be minted',
    );
}

#[test]
#[should_panic(expected: ('Only author mints chapter NFT',))]
fn test_batch_mint_by_author_non_author_fails() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author = AUTHOR_1();
    let non_author = READER_1();

    // Submit and accept chapter
    cheat_caller_address(story.contract_address, author, CheatSpan::TargetCalls(1));
    let submission_id = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);

    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(1));
    story.accept_chapter(submission_id);

    // Non-author tries to batch mint by author
    cheat_caller_address(story.contract_address, non_author, CheatSpan::TargetCalls(1));
    story.batch_mint_by_author(author); // Should fail
}

#[test]
#[should_panic(expected: ('No unminted chapters for author',))]
fn test_batch_mint_by_author_no_chapters_fails() {
    let (factory, _, _) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let author_with_no_chapters = AUTHOR_1();

    // Try to batch mint for author with no chapters
    cheat_caller_address(
        story.contract_address, author_with_no_chapters, CheatSpan::TargetCalls(1),
    );
    story.batch_mint_by_author(author_with_no_chapters); // Should fail
}

#[test]
fn test_get_unminted_chapters() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author1 = AUTHOR_1();
    let author2 = AUTHOR_2();

    // Initially no unminted chapters
    let initial_unminted = story.get_unminted_chapters();
    assert(initial_unminted.len() == 0, 'Should have none unminted');

    // Submit and accept chapters
    cheat_caller_address(story.contract_address, author1, CheatSpan::TargetCalls(2));
    let submission_id1 = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);
    let submission_id2 = story.submit_chapter("Chapter 2", SAMPLE_IPFS_HASH_2);

    cheat_caller_address(story.contract_address, author2, CheatSpan::TargetCalls(1));
    let submission_id3 = story.submit_chapter("Chapter 3", SAMPLE_IPFS_HASH);

    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(3));
    let token_id1 = story.accept_chapter(submission_id1);
    let token_id2 = story.accept_chapter(submission_id2);
    let token_id3 = story.accept_chapter(submission_id3);

    // Check unminted chapters
    let unminted = story.get_unminted_chapters();
    assert(unminted.len() == 3, 'Should have 3 unminted chapters');
    assert(*unminted.at(0) == token_id1, 'First unminted token mismatch');
    assert(*unminted.at(1) == token_id2, 'Second unminted token mismatch');
    assert(*unminted.at(2) == token_id3, 'Third unminted token mismatch');

    // Mint one chapter
    cheat_caller_address(story.contract_address, author1, CheatSpan::TargetCalls(1));
    story.mint_chapter(token_id1);

    // Check unminted chapters again
    let remaining_unminted = story.get_unminted_chapters();
    assert(remaining_unminted.len() == 2, 'Should have 2 pending unminted');
    assert(*remaining_unminted.at(0) == token_id2, 'Second token should remain');
    assert(*remaining_unminted.at(1) == token_id3, 'Third token should remain');
}

#[test]
fn test_get_unminted_chapters_by_author() {
    let (factory, _, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author1 = AUTHOR_1();
    let author2 = AUTHOR_2();

    // Initially no unminted chapters for any author
    let initial_author1 = story.get_unminted_chapters_by_author(author1);
    let initial_author2 = story.get_unminted_chapters_by_author(author2);
    assert(initial_author1.len() == 0, 'Author1 should have no unminted');
    assert(initial_author2.len() == 0, 'Author2 should have no unminted');

    // Author1 submits 2 chapters, author2 submits 1
    cheat_caller_address(story.contract_address, author1, CheatSpan::TargetCalls(2));
    let submission_id1 = story.submit_chapter("Chapter 1", SAMPLE_IPFS_HASH);
    let submission_id2 = story.submit_chapter("Chapter 2", SAMPLE_IPFS_HASH_2);

    cheat_caller_address(story.contract_address, author2, CheatSpan::TargetCalls(1));
    let submission_id3 = story.submit_chapter("Chapter 3", SAMPLE_IPFS_HASH);

    // Accept all chapters
    cheat_caller_address(story.contract_address, creator, CheatSpan::TargetCalls(3));
    let token_id1 = story.accept_chapter(submission_id1);
    let token_id2 = story.accept_chapter(submission_id2);
    let token_id3 = story.accept_chapter(submission_id3);

    // Check unminted chapters by author
    let author1_unminted = story.get_unminted_chapters_by_author(author1);
    let author2_unminted = story.get_unminted_chapters_by_author(author2);

    assert(author1_unminted.len() == 2, 'Author1 should have 2 unminted');
    assert(author2_unminted.len() == 1, 'Author2 should have 1 unminted');
    assert(*author1_unminted.at(0) == token_id1, 'Author1 first token mismatch');
    assert(*author1_unminted.at(1) == token_id2, 'Author1 second token mismatch');
    assert(*author2_unminted.at(0) == token_id3, 'Author2 token mismatch');

    // Mint one chapter for author1
    cheat_caller_address(story.contract_address, author1, CheatSpan::TargetCalls(1));
    story.mint_chapter(token_id1);

    // Check updated unminted chapters for author1
    let author1_updated = story.get_unminted_chapters_by_author(author1);
    assert(author1_updated.len() == 1, 'Author1 should have 1 remaining');
    assert(*author1_updated.at(0) == token_id2, 'Author1 tokens mismatch');

    // Author2's unminted should remain unchanged
    let author2_unchanged = story.get_unminted_chapters_by_author(author2);
    assert(author2_unchanged.len() == 1, 'Author2 should still have 1');
    assert(*author2_unchanged.at(0) == token_id3, 'Author2 token unchanged');
}

// ============================================================================
// MODERATION REGISTRY TESTS
// ============================================================================

#[test]
fn test_registry_initialization() {
    let owner = OWNER;
    let moderator = MODERATOR_1();
    let factory_address = FACTORY();
    let registry = deploy_moderation_registry(
        owner, factory_address, 3, 70,
    ); // 3 min moderators, 70% threshold

    // Test initial settings
    let story: ContractAddress = 'test_story'.try_into().unwrap();
    assert(!registry.is_story_moderator(story, moderator), 'Should not be moderator');

    let moderators = registry.get_story_moderators(story);
    assert(moderators.len() == 0, 'Should have no moderators');

    let moderated_stories = registry.get_moderated_stories(moderator);
    assert(moderated_stories.len() == 0, 'Moderator should have 0 stories');
}

#[test]
fn test_story_registration() {
    let mut spy = spy_events();
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);

    // Story should already be registered in setup
    let moderators = registry.get_story_moderators(story.contract_address);
    assert(moderators.len() == 1, 'Should have 1 moderator');
    assert(*moderators.at(0) == creator, 'Creator should be 1st moderator');
    assert(
        registry.is_story_moderator(story.contract_address, creator), 'Creator should be moderator',
    );

    // Verify StoryRegistered event
    spy
        .assert_emitted(
            @array![
                (
                    registry.contract_address,
                    ModerationRegistry::Event::StoryRegistered(
                        StoryRegistered {
                            story: story.contract_address,
                            creator,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_moderator_assignment() {
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let moderator = MODERATOR_1();
    let mut spy = spy_events();

    // Creator assigns moderator
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(registry.contract_address, 12345, CheatSpan::TargetCalls(1));
    registry.assign_story_moderator(story.contract_address, moderator);

    // Verify moderator was assigned
    assert(
        registry.is_story_moderator(story.contract_address, moderator),
        'Moderator should be assigned',
    );

    let moderators = registry.get_story_moderators(story.contract_address);
    assert(moderators.len() == 2, 'Should have 2 moderators');

    let moderated_stories = registry.get_moderated_stories(moderator);
    assert(moderated_stories.len() == 1, 'Moderator should have 1 story');
    assert(*moderated_stories.at(0) == story.contract_address, 'Story mismatch');

    // Verify ModeratorAssigned event
    spy
        .assert_emitted(
            @array![
                (
                    registry.contract_address,
                    ModerationRegistry::Event::ModeratorAssigned(
                        ModeratorAssigned {
                            story: story.contract_address,
                            moderator,
                            assigned_by: creator,
                            timestamp: 12345,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_multiple_moderator_assignment() {
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let moderator1 = MODERATOR_1();
    let moderator2 = MODERATOR_2();

    // Assign multiple moderators
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(2));
    registry.assign_story_moderator(story.contract_address, moderator1);
    registry.assign_story_moderator(story.contract_address, moderator2);

    // Verify both moderators
    assert(
        registry.is_story_moderator(story.contract_address, moderator1),
        'Moderator 1 should be assigned',
    );
    assert(
        registry.is_story_moderator(story.contract_address, moderator2),
        'Moderator 2 should be assigned',
    );

    let moderators = registry.get_story_moderators(story.contract_address);
    assert(moderators.len() == 3, 'Should have 3 moderators'); // creator + 2 assigned

    // Check that both moderators have the story
    let stories1 = registry.get_moderated_stories(moderator1);
    let stories2 = registry.get_moderated_stories(moderator2);
    assert(stories1.len() == 1, 'Moderator 1 should have 1 story');
    assert(stories2.len() == 1, 'Moderator 2 should have 1 story');
}

#[test]
fn test_moderator_removal() {
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let moderator = MODERATOR_1();
    let mut spy = spy_events();

    // First assign moderator
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(1));
    registry.assign_story_moderator(story.contract_address, moderator);

    // Verify assignment
    assert(
        registry.is_story_moderator(story.contract_address, moderator),
        'Moderator should be assigned',
    );

    // Remove moderator
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(registry.contract_address, 54321, CheatSpan::TargetCalls(1));
    registry.remove_story_moderator(story.contract_address, moderator);

    // Verify removal
    assert(
        !registry.is_story_moderator(story.contract_address, moderator),
        'Moderator should be removed',
    );

    let moderators = registry.get_story_moderators(story.contract_address);
    assert(moderators.len() == 1, 'Should have 1 moderator'); // only creator

    // Verify ModeratorRemoved event
    spy
        .assert_emitted(
            @array![
                (
                    registry.contract_address,
                    ModerationRegistry::Event::ModeratorRemoved(
                        ModeratorRemoved {
                            story: story.contract_address,
                            moderator,
                            removed_by: creator,
                            timestamp: 54321,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_submission_voting() {
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let moderator1 = MODERATOR_1();
    let moderator2 = MODERATOR_2();
    let submission_id = 1_u256;
    let mut spy = spy_events();

    // Assign moderators
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(2));
    registry.assign_story_moderator(story.contract_address, moderator1);
    registry.assign_story_moderator(story.contract_address, moderator2);

    // Moderator 1 votes to approve
    cheat_caller_address(registry.contract_address, moderator1, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(registry.contract_address, 12345, CheatSpan::TargetCalls(1));
    registry.vote_on_submission(story.contract_address, submission_id, true, "Good chapter");

    // Check votes
    let (votes_for, votes_against) = registry
        .get_submission_votes(story.contract_address, submission_id);
    assert(votes_for == 1, 'Should have 1 vote for');
    assert(votes_against == 0, 'Should have 0 votes against');

    // Moderator 2 votes to reject
    cheat_caller_address(registry.contract_address, moderator2, CheatSpan::TargetCalls(1));
    registry.vote_on_submission(story.contract_address, submission_id, false, "Needs improvement");

    // Check updated votes
    let (votes_for_2, votes_against_2) = registry
        .get_submission_votes(story.contract_address, submission_id);
    assert(votes_for_2 == 1, 'Should still have 1 vote for');
    assert(votes_against_2 == 1, 'Should have 1 vote against');

    // Verify SubmissionVoted event
    spy
        .assert_emitted(
            @array![
                (
                    registry.contract_address,
                    ModerationRegistry::Event::SubmissionVoted(
                        SubmissionVoted {
                            story: story.contract_address,
                            submission_id,
                            voter: moderator1,
                            approve: true,
                            votes_for: 1,
                            votes_against: 0,
                            timestamp: 12345,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_submission_consensus() {
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let moderator1 = MODERATOR_1();
    let moderator2 = MODERATOR_2();
    let submission_id = 1_u256;

    // Assign moderators (total 3 with creator, need 60% = 2 votes)
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(2));
    registry.assign_story_moderator(story.contract_address, moderator1);
    registry.assign_story_moderator(story.contract_address, moderator2);

    // Initially should not be able to accept
    assert(
        !registry.can_accept_submission(story.contract_address, submission_id),
        'Should not accept without votes',
    );

    // One vote (not enough for 60%)
    cheat_caller_address(registry.contract_address, moderator1, CheatSpan::TargetCalls(1));
    registry.vote_on_submission(story.contract_address, submission_id, true, "Good");
    assert(
        !registry.can_accept_submission(story.contract_address, submission_id),
        'Should not accept with 1 vote',
    );

    // Second vote (should reach consensus)
    cheat_caller_address(registry.contract_address, moderator2, CheatSpan::TargetCalls(1));
    registry.vote_on_submission(story.contract_address, submission_id, true, "Approved");
    assert(
        registry.can_accept_submission(story.contract_address, submission_id),
        'Should accept with 2 votes',
    );
}

#[test]
fn test_creator_override() {
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let moderator1 = MODERATOR_1();
    let submission_id = 1_u256;

    // Assign moderator
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(1));
    registry.assign_story_moderator(story.contract_address, moderator1);

    // Moderator votes against
    cheat_caller_address(registry.contract_address, moderator1, CheatSpan::TargetCalls(1));
    registry.vote_on_submission(story.contract_address, submission_id, false, "Reject");

    // Creator overrides to accept
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(1));
    registry
        .creator_override_submission(
            story.contract_address, submission_id, 'ACCEPT', "Creator decision",
        );

    // Check that override was recorded
    let voting_details = registry
        .get_submission_voting_details(story.contract_address, submission_id);
    assert(voting_details.action == 'ACCEPT', 'Override action mismatch');
    assert(voting_details.is_resolved == true, 'Should be resolved');
}

#[test]
fn test_chapter_flagging() {
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let moderator = MODERATOR_1();
    let token_id = 1_u256;
    let mut spy = spy_events();

    // Assign moderator
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(1));
    registry.assign_story_moderator(story.contract_address, moderator);

    // Moderator flags chapter
    cheat_caller_address(registry.contract_address, moderator, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(registry.contract_address, 12345, CheatSpan::TargetCalls(1));
    registry.flag_accepted_chapter(story.contract_address, token_id, "Inappropriate content");

    // Verify ChapterFlagged event
    spy
        .assert_emitted(
            @array![
                (
                    registry.contract_address,
                    ModerationRegistry::Event::ChapterFlagged(
                        ChapterFlagged {
                            story: story.contract_address,
                            token_id,
                            flagger: moderator,
                            reason: "Inappropriate content",
                            timestamp: 12345,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_flagged_chapter_voting() {
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let moderator1 = MODERATOR_1();
    let moderator2 = MODERATOR_2();
    let token_id = 1_u256;

    // Assign moderators
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(2));
    registry.assign_story_moderator(story.contract_address, moderator1);
    registry.assign_story_moderator(story.contract_address, moderator2);

    // Moderator 1 flags chapter
    cheat_caller_address(registry.contract_address, moderator1, CheatSpan::TargetCalls(1));
    registry.flag_accepted_chapter(story.contract_address, token_id, "Inappropriate");

    // Moderator 2 votes on flagged chapter
    cheat_caller_address(registry.contract_address, moderator2, CheatSpan::TargetCalls(1));
    registry
        .vote_on_flagged_chapter(
            story.contract_address, token_id, 'REMOVE', "Agreed, remove
        it",
        );

    // Creator can resolve the flag
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(1));
    registry
        .resolve_flagged_chapter(story.contract_address, token_id, 'APPROVE', "Content is fine");
}

#[test]
fn test_moderation_history() {
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let moderator = MODERATOR_1();
    let submission_id = 1_u256;
    let mut spy = spy_events();

    // Assign moderator
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(registry.contract_address, 54321, CheatSpan::TargetCalls(1));
    registry.assign_story_moderator(story.contract_address, moderator);

    // Record some moderation actions
    cheat_caller_address(
        registry.contract_address, story.contract_address, CheatSpan::TargetCalls(2),
    );
    registry
        .record_moderation_action(
            story.contract_address, moderator, 'VOTE', submission_id, "Voted on submission",
        );

    registry
        .record_moderation_action(
            story.contract_address, creator, 'OVERRIDE', submission_id, "Creator override",
        );

    // Get moderation history
    let history = registry.get_moderation_history(story.contract_address, 0, 10);
    assert(history.len() == 3, 'Should have 2 history entries');
    assert(*history.at(0).action == 'ASSIGN_MODERATOR', 'First action should be ASSIGN');
    assert(*history.at(1).action == 'VOTE', 'Second action should be VOTE');
    assert(*history.at(2).action == 'OVERRIDE', 'Third action should be OVERRIDE');

    // Verify ModerationHistoryRecorded event
    spy
        .assert_emitted(
            @array![
                (
                    registry.contract_address,
                    ModerationRegistry::Event::ModerationHistoryRecorded(
                        ModerationHistoryRecorded {
                            story: story.contract_address,
                            action_id: 0,
                            moderator: creator,
                            action: 'ASSIGN_MODERATOR',
                            target_id: 0,
                            timestamp: 54321,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_moderation_history_pagination() {
    let (factory, registry, _) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let moderator = MODERATOR_1();

    // Record 5 moderation actions
    cheat_caller_address(
        registry.contract_address, story.contract_address, CheatSpan::TargetCalls(5),
    );
    let mut i = 0;
    while i < 5_u32 {
        registry
            .record_moderation_action(
                story.contract_address, moderator, 'ACTION', i.into(), format!("Action {}", i),
            );
        i += 1;
    }

    // Test pagination
    let page0 = registry.get_moderation_history(story.contract_address, 0, 2);
    assert(page0.len() == 2, 'Page 0 should have 2 entries');

    let page1 = registry.get_moderation_history(story.contract_address, 2, 2);
    assert(page1.len() == 2, 'Page 1 should have 2 entries');

    let page2 = registry.get_moderation_history(story.contract_address, 4, 2);
    assert(page2.len() == 1, 'Page 2 should have 1 entry');
}

#[test]
#[should_panic(expected: ('Not a story creator',))]
fn test_non_creator_assign_moderator_fails() {
    let (factory, registry, _) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let non_creator = AUTHOR_1();
    let moderator = MODERATOR_1();

    cheat_caller_address(registry.contract_address, non_creator, CheatSpan::TargetCalls(1));
    registry.assign_story_moderator(story.contract_address, moderator);
}

#[test]
#[should_panic(expected: ('Moderator already exists',))]
fn test_double_moderator_assignment_fails() {
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let moderator = MODERATOR_1();

    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(2));
    registry.assign_story_moderator(story.contract_address, moderator);
    registry.assign_story_moderator(story.contract_address, moderator); // Should fail
}

#[test]
#[should_panic(expected: ('Not a moderator',))]
fn test_non_moderator_vote_fails() {
    let (factory, registry, _) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let non_moderator = AUTHOR_1();
    let submission_id = 1_u256;

    cheat_caller_address(registry.contract_address, non_moderator, CheatSpan::TargetCalls(1));
    registry.vote_on_submission(story.contract_address, submission_id, true, "Invalid vote");
}

#[test]
#[should_panic(expected: ('Already voted on submission',))]
fn test_double_vote_fails() {
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let moderator = MODERATOR_1();
    let submission_id = 1_u256;

    // Assign moderator
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(1));
    registry.assign_story_moderator(story.contract_address, moderator);

    cheat_caller_address(registry.contract_address, moderator, CheatSpan::TargetCalls(2));
    registry.vote_on_submission(story.contract_address, submission_id, true, "First vote");
    registry
        .vote_on_submission(
            story.contract_address, submission_id, false, "Second vote",
        ); // Should fail
}

#[test]
#[should_panic(expected: ('Cannot remove creator',))]
fn test_cannot_remove_creator_as_moderator() {
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);

    // Try to remove creator as moderator (should fail)
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(1));
    registry.remove_story_moderator(story.contract_address, creator);
}

#[test]
#[should_panic(expected: ('Not a story creator',))]
fn test_non_creator_override_fails() {
    let (factory, registry, _) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let non_creator = AUTHOR_1();
    let submission_id = 1_u256;

    cheat_caller_address(registry.contract_address, non_creator, CheatSpan::TargetCalls(1));
    registry
        .creator_override_submission(
            story.contract_address, submission_id, 'ACCEPT', "Invalid override",
        );
}

#[test]
fn test_story_registration_by_factory() {
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);

    // Verify registration
    assert(
        registry.is_story_moderator(story.contract_address, creator), 'Creator should be moderator',
    );

    let moderators = registry.get_story_moderators(story.contract_address);
    assert(moderators.len() == 1, 'Should have 1 moderator');
    assert(*moderators.at(0) == creator, 'Creator should be 1st moderator');
}

#[test]
#[should_panic(expected: ('Story already exists',))]
fn test_duplicate_story_registration_fails() {
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let creator = CREATOR_1();

    // Try to register the same story again
    cheat_caller_address(
        registry.contract_address, factory.contract_address, CheatSpan::TargetCalls(1),
    );
    registry.register_story(story.contract_address, creator);
}

#[test]
fn test_complex_voting_scenario() {
    let (factory, registry, _) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let moderator1 = MODERATOR_1();
    let moderator2 = MODERATOR_2();
    let submission_id = 1_u256;

    // Assign 2 moderators (total 3 with creator, threshold 60% = 2 votes needed)
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(2));
    registry.assign_story_moderator(story.contract_address, moderator1);
    registry.assign_story_moderator(story.contract_address, moderator2);

    // Scenario: 1 approve, 1 reject, 1 no vote - should not accept
    cheat_caller_address(registry.contract_address, moderator1, CheatSpan::TargetCalls(1));
    registry.vote_on_submission(story.contract_address, submission_id, true, "Approve");

    cheat_caller_address(registry.contract_address, moderator2, CheatSpan::TargetCalls(1));
    registry.vote_on_submission(story.contract_address, submission_id, false, "Reject");

    // Should not be able to accept (only 1 approve out of 3 total, need 2)
    assert(
        !registry.can_accept_submission(story.contract_address, submission_id),
        'Should not accept split votes',
    );

    // Creator votes to approve - should now be acceptable
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(1));
    registry.vote_on_submission(story.contract_address, submission_id, true, "Creator approve");

    // Now should be acceptable (2 approves out of 3)
    assert(
        registry.can_accept_submission(story.contract_address, submission_id),
        'Should accept with 2 approvals',
    );
}

#[test]
fn test_voting_threshold_edge_cases() {
    // Initialize all addresses and contracts
    let owner = OWNER;
    let creator = CREATOR_1();
    let moderator1 = MODERATOR_1();
    let moderator2 = MODERATOR_2();

    // Deploy test contracts
    let story_contract_class = declare_class("IPStory");
    let story_contract_class_hash = story_contract_class.class_hash;
    let factory_address = FACTORY();

    // Create moderation registry with 100% approval requirement
    let registry = deploy_moderation_registry(
        owner, factory_address, 1, 100,
    ); // min 2 moderators, 100% threshold
    let revenue_manager = deploy_revenue_manager(owner, factory_address);
    let factory = deploy_factory(
        owner,
        story_contract_class_hash,
        registry.contract_address,
        revenue_manager.contract_address,
    );

    // Finish deployment setup
    cheat_caller_address(registry.contract_address, owner, CheatSpan::TargetCalls(1));
    registry.update_factory_contract(factory.contract_address);
    cheat_caller_address(revenue_manager.contract_address, owner, CheatSpan::TargetCalls(1));
    revenue_manager.update_factory_contract(factory.contract_address);

    // Create and register story
    let metadata = sample_story_metadata();
    let royalty_dist = sample_royalty_distribution();
    let shared_owners: Option<Array<ContractAddress>> = Option::None;

    cheat_caller_address(factory.contract_address, creator, CheatSpan::TargetCalls(1));
    let story_address = factory.create_story(metadata, shared_owners, royalty_dist);
    let submission_id = 1_u256;

    // Assign moderators
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(2));
    registry.assign_story_moderator(story_address, moderator1);
    registry.assign_story_moderator(story_address, moderator2);

    // 2 out of 3 approve (66% but need 100%)
    cheat_caller_address(registry.contract_address, creator, CheatSpan::TargetCalls(1));
    registry.vote_on_submission(story_address, submission_id, true, "Approve");

    cheat_caller_address(registry.contract_address, moderator1, CheatSpan::TargetCalls(1));
    registry.vote_on_submission(story_address, submission_id, true, "Approve");

    // Should not be acceptable yet (need all 3)
    assert(
        !registry.can_accept_submission(story_address, submission_id),
        'Should need unanimous approval',
    );

    // Third vote
    cheat_caller_address(registry.contract_address, moderator2, CheatSpan::TargetCalls(1));
    registry.vote_on_submission(story_address, submission_id, true, "Approve");

    // Now should be acceptable
    assert(
        registry.can_accept_submission(story_address, submission_id),
        'Should take unanimous approval',
    );
}

// ============================================================================
// REVENUE MANAGER TESTS
// ============================================================================

#[test]
fn test_revenue_manager_initialization() {
    let (_, _, revenue_manager) = setup_test_environment();

    // Test initial state for non-registered story
    let story = STORY_1();
    let metrics = revenue_manager.get_revenue_metrics(story);
    assert(metrics.total_revenue == 0, 'Should start with 0 revenue');
    assert(metrics.total_views == 0, 'Should start with 0 views');
    assert(metrics.total_chapters == 0, 'Should start with 0 chapters');

    // Test initial split for non-registered story
    let (creator_pct, contributors_pct, platform_pct) = revenue_manager.get_revenue_split(story);
    assert(creator_pct == 0, 'Creator split should be 0% ');
    assert(contributors_pct == 0, 'Contributor split should be 0%');
    assert(platform_pct == 0, 'Platform split should be 0%');
}

#[test]
fn test_story_registration_with_revenue() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, _) = deploy_story(factory);

    // Test that story was registered with correct revenue split
    let (creator_pct, contributors_pct, platform_pct) = revenue_manager
        .get_revenue_split(story.contract_address);
    assert(creator_pct == 40, 'Creator split should be 40% ');
    assert(contributors_pct == 50, 'Contributor split should be 50%');
    assert(platform_pct == 10, 'Platform split should be 10%');

    // Test initial metrics
    let metrics = revenue_manager.get_revenue_metrics(story.contract_address);
    assert(metrics.total_revenue == 0, 'Should start with 0 revenue');
    assert(metrics.total_contributors == 0, 'Should have 0 contributors');
}

#[test]
fn test_chapter_registration() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let author = AUTHOR_1();
    let token_id = 1_u256;

    // Register chapter (simulating story contract call)
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(1),
    );
    revenue_manager.register_chapter(story.contract_address, token_id, author);

    // Check chapter revenue was initialized
    let chapter_revenue = revenue_manager.get_chapter_revenue(story.contract_address, token_id);
    assert(chapter_revenue.token_id == token_id, 'Chapter token ID mismatch');
    assert(chapter_revenue.author == author, 'Chapter author mismatch');
    assert(chapter_revenue.total_views == 0, 'Chapter should have 0 views');
    assert(chapter_revenue.revenue_generated == 0, 'Chapter should have 0 revenue');

    // Check story metrics updated
    let metrics = revenue_manager.get_revenue_metrics(story.contract_address);
    assert(metrics.total_chapters == 1, 'Story should have 1 chapter');
    assert(metrics.total_contributors == 1, 'Story should have 1 contributor');

    // Check contributor earnings
    let earnings = revenue_manager.get_contributor_earnings(story.contract_address, author);
    assert(earnings.contributor == author, 'Contributor address mismatch');
    assert(earnings.chapters_contributed == 1, 'Should have 1 contribution');
    assert(earnings.total_earned == 0, 'Should have earned 0 initially');
}

#[test]
fn test_multiple_chapter_registration() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let author1 = AUTHOR_1();
    let author2 = AUTHOR_2();

    // Register multiple chapters
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(3),
    );
    revenue_manager.register_chapter(story.contract_address, 1, author1);
    revenue_manager.register_chapter(story.contract_address, 2, author2);
    revenue_manager
        .register_chapter(story.contract_address, 3, author1); // Author 1 contributes again

    // Check story metrics
    let metrics = revenue_manager.get_revenue_metrics(story.contract_address);
    assert(metrics.total_chapters == 3, 'Should have 3 chapters');
    assert(metrics.total_contributors == 2, 'Should be 2 unique contributors');

    // Check author 1 earnings (2 chapters)
    let earnings1 = revenue_manager.get_contributor_earnings(story.contract_address, author1);
    assert(earnings1.chapters_contributed == 2, 'Author 1 should have 2 chapters');

    // Check author 2 earnings (1 chapter)
    let earnings2 = revenue_manager.get_contributor_earnings(story.contract_address, author2);
    assert(earnings2.chapters_contributed == 1, 'Author 2 should have 1 chapter');
}

#[test]
fn test_chapter_view_recording() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let author = AUTHOR_1();
    let reader = READER_1();
    let token_id = 1_u256;
    let mut spy = spy_events();

    // Register chapter first
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(1),
    );
    revenue_manager.register_chapter(story.contract_address, token_id, author);

    // Record chapter view
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(1),
    );
    cheat_block_timestamp(revenue_manager.contract_address, 12345, CheatSpan::TargetCalls(1));
    revenue_manager.record_chapter_view(story.contract_address, token_id, reader);

    // Check chapter views updated
    let view_count = revenue_manager.get_chapter_view_count(story.contract_address, token_id);
    assert(view_count == 1, 'Chapter should have 1 view');

    // Check chapter revenue updated
    let chapter_revenue = revenue_manager.get_chapter_revenue(story.contract_address, token_id);
    assert(chapter_revenue.total_views == 1, 'Chapter total views should = 1');
    assert(chapter_revenue.unique_views == 1, 'Chapter unique views should = 1');

    // Check story metrics updated
    let metrics = revenue_manager.get_revenue_metrics(story.contract_address);
    assert(metrics.total_views == 1, 'Story should have 1 total view');

    // Check contributor earnings updated
    let earnings = revenue_manager.get_contributor_earnings(story.contract_address, author);
    assert(earnings.views_generated == 1, 'Author should have 1 view');

    // Verify ChapterViewed event
    spy
        .assert_emitted(
            @array![
                (
                    revenue_manager.contract_address,
                    RevenueManager::Event::ChapterViewed(
                        ChapterViewed {
                            story: story.contract_address,
                            token_id,
                            viewer: reader,
                            new_view_count: 1,
                            is_unique_view: true,
                            timestamp: 12345,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_unique_vs_repeat_views() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let author = AUTHOR_1();
    let reader = READER_1();
    let token_id = 1_u256;

    // Register chapter
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(1),
    );
    revenue_manager.register_chapter(story.contract_address, token_id, author);

    // First view (should be unique)
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(1),
    );
    revenue_manager.record_chapter_view(story.contract_address, token_id, reader);

    let chapter_revenue_1 = revenue_manager.get_chapter_revenue(story.contract_address, token_id);
    assert(chapter_revenue_1.total_views == 1, 'Should have 1 total view');
    assert(chapter_revenue_1.unique_views == 1, 'Should have 1 unique view');

    // Second view by same reader (should not be unique)
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(1),
    );
    revenue_manager.record_chapter_view(story.contract_address, token_id, reader);

    let chapter_revenue_2 = revenue_manager.get_chapter_revenue(story.contract_address, token_id);
    assert(chapter_revenue_2.total_views == 2, 'Should have 2 total views');
    assert(chapter_revenue_2.unique_views == 1, 'Should still have 1 unique view');
}

#[test]
fn test_batch_view_recording() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let author = AUTHOR_1();
    let reader = READER_1();

    // Register multiple chapters
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(3),
    );
    revenue_manager.register_chapter(story.contract_address, 1, author);
    revenue_manager.register_chapter(story.contract_address, 2, author);
    revenue_manager.register_chapter(story.contract_address, 3, author);

    // Batch record views
    let chapter_ids = array![1_u256, 2_u256, 3_u256];
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(1),
    );
    revenue_manager.batch_record_views(story.contract_address, chapter_ids, reader);

    // Check all chapters have views
    assert(
        revenue_manager.get_chapter_view_count(story.contract_address, 1) == 1,
        'Chapter 1 should have 1 view',
    );
    assert(
        revenue_manager.get_chapter_view_count(story.contract_address, 2) == 1,
        'Chapter 2 should have 1 view',
    );
    assert(
        revenue_manager.get_chapter_view_count(story.contract_address, 3) == 1,
        'Chapter 3 should have 1 view',
    );

    // Check story metrics
    let metrics = revenue_manager.get_revenue_metrics(story.contract_address);
    assert(metrics.total_views == 3, 'Story should have 3 total views');
}

#[test]
fn test_revenue_recording() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let revenue_source = REVENUE();
    let mut spy = spy_events();

    // Record revenue (simulating story contract call)
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(1),
    );
    cheat_block_timestamp(revenue_manager.contract_address, 54321, CheatSpan::TargetCalls(1));
    revenue_manager.record_revenue(1000_u256, revenue_source);

    // Check metrics updated
    let metrics = revenue_manager.get_revenue_metrics(story.contract_address);
    assert(metrics.total_revenue == 1000, 'Should have 1000 total revenue');

    // Verify RevenueReceived event
    spy
        .assert_emitted(
            @array![
                (
                    revenue_manager.contract_address,
                    RevenueManager::Event::RevenueReceived(
                        RevenueReceived {
                            story: story.contract_address,
                            amount: 1000,
                            source: revenue_source,
                            timestamp: 54321,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_royalty_calculation() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, creator) = deploy_story(factory);

    // Record some revenue
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(1),
    );
    revenue_manager.record_revenue(1000_u256, creator);

    // Calculate royalties
    let distribution = revenue_manager.calculate_royalties(story.contract_address);
    assert(distribution.total_amount == 1000, 'Total amount should be 1000');
    assert(distribution.creator_share == 400, 'Creator share should be 400');
    assert(distribution.contributors_share == 500, 'Contributor share should be 500');
    assert(distribution.platform_share == 100, 'Platform share should be 100');
}

#[test]
fn test_revenue_distribution() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author = AUTHOR_1();
    let mut spy = spy_events();

    // Register chapter and record views to give author some weight
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(2),
    );
    revenue_manager.register_chapter(story.contract_address, 1, author);
    revenue_manager.record_chapter_view(story.contract_address, 1, READER_1());

    // Record revenue
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(1),
    );
    revenue_manager.record_revenue(1000_u256, creator);

    // Distribute revenue (only creator can trigger)
    cheat_caller_address(revenue_manager.contract_address, creator, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(revenue_manager.contract_address, 67890, CheatSpan::TargetCalls(1));
    revenue_manager.distribute_revenue(story.contract_address, 1000_u256);

    // Check that author has pending royalties
    let pending = revenue_manager.get_pending_royalties(story.contract_address, author);
    assert(pending > 0, 'Should have pending royalties');

    // Verify RevenueDistributed event
    spy
        .assert_emitted(
            @array![
                (
                    revenue_manager.contract_address,
                    RevenueManager::Event::RevenueDistributed(
                        RevenueDistributed {
                            story: story.contract_address,
                            distribution_id: 1,
                            total_amount: 1000,
                            creator_share: 400,
                            contributor_count: 1,
                            timestamp: 67890,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_royalty_claiming() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author = AUTHOR_1();
    let mut spy = spy_events();

    // Deploy mock ERC20 token and set it as payment token for the story
    let mock_token = deploy_mock_erc20();

    // First, set the story to use the mock token as payment method
    cheat_caller_address(revenue_manager.contract_address, creator, CheatSpan::TargetCalls(1));
    revenue_manager.set_payment_token(story.contract_address, mock_token.contract_address);

    // Approve RevenueManager to spend tokens on behalf of creator
    let erc20_token = IERC20Dispatcher { contract_address: mock_token.contract_address };
    cheat_caller_address(mock_token.contract_address, creator, CheatSpan::TargetCalls(1));
    erc20_token.approve(revenue_manager.contract_address, 10000_u256);

    // Transfer some tokens to the revenue manager contract to cover royalty payments
    cheat_caller_address(mock_token.contract_address, creator, CheatSpan::TargetCalls(1));
    erc20_token.transfer(revenue_manager.contract_address, 10000_u256);

    // Setup: register chapter, record views, distribute revenue
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(2),
    );
    revenue_manager.register_chapter(story.contract_address, 1, author);
    revenue_manager.record_chapter_view(story.contract_address, 1, READER_1());

    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(1),
    );
    revenue_manager.record_revenue(1000_u256, creator);

    cheat_caller_address(revenue_manager.contract_address, creator, CheatSpan::TargetCalls(1));
    revenue_manager.distribute_revenue(story.contract_address, 1000_u256);

    // Check pending royalties before claiming
    let pending_before = revenue_manager.get_pending_royalties(story.contract_address, author);
    assert(pending_before > 0, 'Should have pending royalties');

    // Check author's token balance before claiming
    let author_balance_before = erc20_token.balance_of(author);

    // Claim royalties
    cheat_caller_address(revenue_manager.contract_address, author, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(revenue_manager.contract_address, 11111, CheatSpan::TargetCalls(1));
    let claimed_amount = revenue_manager.claim_royalties(story.contract_address);

    assert(claimed_amount == pending_before, 'Claimed amount mismatch');

    // Check pending royalties after claiming
    let pending_after = revenue_manager.get_pending_royalties(story.contract_address, author);
    assert(pending_after == 0, 'Should have 0 pending royalties');

    // Check that author received the tokens
    let author_balance_after = erc20_token.balance_of(author);
    assert(author_balance_after == author_balance_before + claimed_amount, 'Token transfer failed');

    // Check RevenueManager's token balance decreased
    let manager_balance_after = erc20_token.balance_of(revenue_manager.contract_address);
    assert(manager_balance_after == 10000_u256 - claimed_amount, 'Manager balance incorrect');

    // Check earnings updated
    let earnings = revenue_manager.get_contributor_earnings(story.contract_address, author);
    assert(earnings.total_earned == claimed_amount, 'Total earned should == claimed');

    // Verify RoyaltyClaimed event
    spy
        .assert_emitted(
            @array![
                (
                    revenue_manager.contract_address,
                    RevenueManager::Event::RoyaltyClaimed(
                        RoyaltyClaimed {
                            story: story.contract_address,
                            claimer: author,
                            amount: claimed_amount,
                            timestamp: 11111,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_revenue_split_updates() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let mut spy = spy_events();

    // Check initial split
    let (creator_pct, contributors_pct, platform_pct) = revenue_manager
        .get_revenue_split(story.contract_address);
    assert(creator_pct == 40, 'Initial creator should be 40%');
    assert(platform_pct == 10, 'Initial platform should be 10%');
    assert(contributors_pct == 50, 'Initial contributor != 10%');

    // Update revenue split (only creator can do this)
    cheat_caller_address(revenue_manager.contract_address, creator, CheatSpan::TargetCalls(1));
    cheat_block_timestamp(revenue_manager.contract_address, 11111, CheatSpan::TargetCalls(1));
    revenue_manager
        .update_revenue_split(story.contract_address, 30, 20); // 30% creator, 20% platform

    // Check updated split
    let (new_creator, new_contributors, new_platform) = revenue_manager
        .get_revenue_split(story.contract_address);
    assert(new_creator == 30, 'Updated creator should be 30%');
    assert(new_platform == 20, 'Updated platform should be 20%');
    assert(new_contributors == 50, 'Updated contributor should = 50'); // 100 - 30 - 20

    // Verify RevenueSplitUpdated event
    spy
        .assert_emitted(
            @array![
                (
                    revenue_manager.contract_address,
                    RevenueManager::Event::RevenueSplitUpdated(
                        RevenueSplitUpdated {
                            story: story.contract_address,
                            updater: creator,
                            old_creator_percentage: creator_pct,
                            new_creator_percentage: new_creator,
                            old_platform_percentage: platform_pct,
                            new_platform_percentage: new_platform,
                            timestamp: 11111,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_batch_contributor_distribution() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author1 = AUTHOR_1();
    let author2 = AUTHOR_2();

    // Setup contributors
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(2),
    );
    revenue_manager.register_chapter(story.contract_address, 1, author1);
    revenue_manager.register_chapter(story.contract_address, 2, author2);

    // Batch distribute to contributors
    let contributors = array![author1, author2];
    let amounts = array![300_u256, 200_u256];

    cheat_caller_address(revenue_manager.contract_address, creator, CheatSpan::TargetCalls(1));
    revenue_manager.batch_distribute_to_contributors(story.contract_address, contributors, amounts);

    // Check pending royalties
    assert(
        revenue_manager.get_pending_royalties(story.contract_address, author1) == 300,
        'Author1 should have 300 pending',
    );
    assert(
        revenue_manager.get_pending_royalties(story.contract_address, author2) == 200,
        'Author2 should have 200 pending',
    );
}

#[test]
fn test_multi_story_revenue_isolation() {
    let creator1 = CREATOR_1();
    let creator2 = CREATOR_2();
    let (factory, _, revenue_manager) = setup_test_environment();
    let story1 = STORY_1();
    let story2 = STORY_2();

    // Register two stories with different splits
    cheat_caller_address(
        revenue_manager.contract_address, factory.contract_address, CheatSpan::TargetCalls(2),
    );
    revenue_manager.register_story(story1, creator1, 50, 10, ZERO); // 50% creator, 10% platform
    revenue_manager.register_story(story2, creator2, 30, 20, ZERO); // 30% creator, 20% platform

    // Check splits are isolated
    let (creator1_pct, _, platform1_pct) = revenue_manager.get_revenue_split(story1);
    let (creator2_pct, _, platform2_pct) = revenue_manager.get_revenue_split(story2);

    assert(creator1_pct == 50, 'Story 1 creator should be 50%');
    assert(platform1_pct == 10, 'Story 1 platform should be 10%');
    assert(creator2_pct == 30, 'Story 2 creator should be 30%');
    assert(platform2_pct == 20, 'Story 2 platform should be 20%');

    // Record revenue for each story
    cheat_caller_address(revenue_manager.contract_address, story1, CheatSpan::TargetCalls(1));
    revenue_manager.record_revenue(1000_u256, creator1);

    cheat_caller_address(revenue_manager.contract_address, story2, CheatSpan::TargetCalls(1));
    revenue_manager.record_revenue(500_u256, creator2);

    // Check metrics are isolated
    let metrics1 = revenue_manager.get_revenue_metrics(story1);
    let metrics2 = revenue_manager.get_revenue_metrics(story2);

    assert(metrics1.total_revenue == 1000, 'Story 1 revenue should = 1000');
    assert(metrics2.total_revenue == 500, 'Story 2 revenue should = 500');
}

#[test]
fn test_weighted_distribution_algorithm() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let author1 = AUTHOR_1();
    let author2 = AUTHOR_2();
    let reader1 = READER_1();
    let reader2 = READER_2();

    // Setup: Author 1 has 1 chapter with 3 views, Author 2 has 1 chapter with 1 view
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(6),
    );
    revenue_manager.register_chapter(story.contract_address, 1, author1);
    revenue_manager.register_chapter(story.contract_address, 2, author2);

    // Author 1 gets more views (should get higher weight)
    revenue_manager.record_chapter_view(story.contract_address, 1, reader1);
    revenue_manager.record_chapter_view(story.contract_address, 1, reader2);
    revenue_manager.record_chapter_view(story.contract_address, 1, AUTHOR_2()); // 3 total views

    // Author 2 gets fewer views
    revenue_manager.record_chapter_view(story.contract_address, 2, reader1); // 1 total view

    // Record and distribute revenue
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(1),
    );
    revenue_manager.record_revenue(1000_u256, creator);

    cheat_caller_address(revenue_manager.contract_address, creator, CheatSpan::TargetCalls(1));
    revenue_manager.distribute_revenue(story.contract_address, 1000_u256);

    // Author 1 should get more royalties due to higher view count
    let pending1 = revenue_manager.get_pending_royalties(story.contract_address, author1);
    let pending2 = revenue_manager.get_pending_royalties(story.contract_address, author2);

    assert(pending1 > pending2, 'Author 1 should get more');
    assert(pending1 + pending2 == 500, 'Total should equal contributors');
}

#[test]
#[should_panic(expected: ('Only factory can register',))]
fn test_non_factory_register_story_fails() {
    let (_, _, revenue_manager) = setup_test_environment();
    let non_factory = AUTHOR_1();

    cheat_caller_address(revenue_manager.contract_address, non_factory, CheatSpan::TargetCalls(1));
    revenue_manager.register_story(STORY_1(), CREATOR_1(), 40, 10, ZERO);
}

#[test]
#[should_panic(expected: ('Only story contracts can record',))]
fn test_non_story_record_view_fails() {
    let (_, _, revenue_manager) = setup_test_environment();
    let non_story = AUTHOR_1();

    cheat_caller_address(revenue_manager.contract_address, non_story, CheatSpan::TargetCalls(1));
    revenue_manager.record_chapter_view(STORY_1(), 1, READER_1());
}

#[test]
#[should_panic(expected: ('Only creator can distribute',))]
fn test_non_creator_distribute_fails() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, _) = deploy_story(factory);
    let non_creator = AUTHOR_1();

    cheat_caller_address(revenue_manager.contract_address, non_creator, CheatSpan::TargetCalls(1));
    revenue_manager.distribute_revenue(story.contract_address, 1000_u256);
}

#[test]
#[should_panic(expected: ('No royalties to claim',))]
fn test_claim_zero_royalties_fails() {
    let (_, _, revenue_manager) = setup_test_environment();
    let author = AUTHOR_1();

    // Try to claim without any pending royalties
    cheat_caller_address(revenue_manager.contract_address, author, CheatSpan::TargetCalls(1));
    revenue_manager.claim_royalties(STORY_1());
}

#[test]
#[should_panic(expected: ('Invalid percentages',))]
fn test_invalid_revenue_split_update_fails() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, creator) = deploy_story(factory);

    // Try to set percentages that exceed 100%
    cheat_caller_address(revenue_manager.contract_address, creator, CheatSpan::TargetCalls(1));
    revenue_manager.update_revenue_split(story.contract_address, 80, 30); // 80 + 30 = 110% > 100%
}

#[test]
#[should_panic(expected: ('Arrays length mismatch',))]
fn test_batch_distribute_length_mismatch_fails() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let contributors = array![AUTHOR_1(), AUTHOR_2()]; // 2 contributors
    let amounts = array![100_u256]; // 1 amount - mismatch!

    cheat_caller_address(revenue_manager.contract_address, creator, CheatSpan::TargetCalls(1));
    revenue_manager.batch_distribute_to_contributors(story.contract_address, contributors, amounts);
}

#[test]
#[should_panic(expected: ('Too many chapters in batch',))]
fn test_batch_view_limit_exceeded_fails() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, _) = deploy_story(factory);

    // Try to record views for more than allowed limit (assuming 10 is the limit)
    let mut chapter_ids = array![];
    let mut i = 0;
    while i < 11_u32 { // Exceed limit
        chapter_ids.append(i.into());
        i += 1;
    }

    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(1),
    );
    revenue_manager.batch_record_views(story.contract_address, chapter_ids, READER_1());
}

#[test]
#[should_panic(expected: ('Amount must be greater than 0',))]
fn test_revenue_edge_cases() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, creator) = deploy_story(factory);

    // Test zero revenue distribution
    cheat_caller_address(revenue_manager.contract_address, creator, CheatSpan::TargetCalls(1));
    revenue_manager.distribute_revenue(story.contract_address, 0_u256);

    // Should not cause any issues
    let metrics = revenue_manager.get_revenue_metrics(story.contract_address);
    assert(metrics.total_revenue == 0, 'Should still have 0 revenue');
}

#[test]
fn test_creator_addition_to_revenue() {
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, creator) = deploy_story(factory);
    let new_creator = CREATOR_2();

    // Add new creator (only existing creator can do this)
    cheat_caller_address(revenue_manager.contract_address, creator, CheatSpan::TargetCalls(1));
    revenue_manager.add_story_creator(story.contract_address, new_creator);

    // New creator should be able to distribute revenue
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(1),
    );
    revenue_manager.record_revenue(1000_u256, creator);

    cheat_caller_address(revenue_manager.contract_address, new_creator, CheatSpan::TargetCalls(1));
    revenue_manager.distribute_revenue(story.contract_address, 1000_u256); // Should not fail
}

#[test]
fn test_comprehensive_revenue_workflow() { // Setup test contracts
    let (factory, _, revenue_manager) = setup_test_environment();
    let (story, creator) = deploy_story(factory);

    // Setup sender and receiver caller addresses
    let author1 = AUTHOR_1();
    let author2 = AUTHOR_2();
    let reader1 = READER_1();
    let reader2 = READER_2();

    // 0. Deploy mock ERC20 token and set it as payment token for the story
    let mock_token = deploy_mock_erc20();

    // First, set the story to use the mock token as payment method
    cheat_caller_address(revenue_manager.contract_address, creator, CheatSpan::TargetCalls(1));
    revenue_manager.set_payment_token(story.contract_address, mock_token.contract_address);

    // Approve RevenueManager to spend tokens on behalf of creator
    let erc20_token = IERC20Dispatcher { contract_address: mock_token.contract_address };
    cheat_caller_address(mock_token.contract_address, creator, CheatSpan::TargetCalls(1));
    erc20_token.approve(revenue_manager.contract_address, 10000_u256);

    // Transfer some tokens to the revenue manager contract to cover royalty payments
    cheat_caller_address(mock_token.contract_address, creator, CheatSpan::TargetCalls(1));
    erc20_token.transfer(revenue_manager.contract_address, 10000_u256);

    // Full workflow: register chapters, record views, generate revenue, distribute, claim

    // 1. Register chapters
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(3),
    );
    revenue_manager.register_chapter(story.contract_address, 1, author1);
    revenue_manager.register_chapter(story.contract_address, 2, author2);
    revenue_manager.register_chapter(story.contract_address, 3, author1);

    // 2. Record views
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(6),
    );
    revenue_manager.record_chapter_view(story.contract_address, 1, reader1);
    revenue_manager.record_chapter_view(story.contract_address, 1, reader2);
    revenue_manager.record_chapter_view(story.contract_address, 2, reader1);
    revenue_manager.record_chapter_view(story.contract_address, 3, reader1);
    revenue_manager.record_chapter_view(story.contract_address, 3, reader2);

    // 3. Generate revenue
    cheat_caller_address(
        revenue_manager.contract_address, story.contract_address, CheatSpan::TargetCalls(2),
    );
    revenue_manager.record_revenue(1000_u256, creator);
    revenue_manager.record_revenue(500_u256, SPONSOR());

    // 4. Distribute revenue
    cheat_caller_address(revenue_manager.contract_address, creator, CheatSpan::TargetCalls(1));
    revenue_manager.distribute_revenue(story.contract_address, 1500_u256);

    // 5. Check and claim royalties
    let pending1 = revenue_manager.get_pending_royalties(story.contract_address, author1);
    let pending2 = revenue_manager.get_pending_royalties(story.contract_address, author2);

    assert(pending1 > 0, 'Author 1 should have royalties');
    assert(pending2 > 0, 'Author 2 should have royalties');

    // Author 1 should get more (contributed 2 chapters with 4 total views)
    // Author 2 should get less (contributed 1 chapter with 1 total view)
    assert(pending1 > pending2, 'Author 1 should receive more');

    // 6. Claim royalties
    cheat_caller_address(revenue_manager.contract_address, author1, CheatSpan::TargetCalls(1));
    let claimed1 = revenue_manager.claim_royalties(story.contract_address);
    assert(claimed1 == pending1, 'Claimed should match pending');

    cheat_caller_address(revenue_manager.contract_address, author2, CheatSpan::TargetCalls(1));
    let claimed2 = revenue_manager.claim_royalties(story.contract_address);
    assert(claimed2 == pending2, 'Claimed should match pending');

    // 7. Verify final state
    let final_metrics = revenue_manager.get_revenue_metrics(story.contract_address);
    assert(final_metrics.total_revenue == 1500, 'Should have 1500 total revenue');
    assert(final_metrics.total_views == 5, 'Should have 5 total views');
    assert(final_metrics.total_chapters == 3, 'Should have 3 chapters');
    assert(final_metrics.total_contributors == 2, 'Should have 2 contributors');

    let earnings1 = revenue_manager.get_contributor_earnings(story.contract_address, author1);
    let earnings2 = revenue_manager.get_contributor_earnings(story.contract_address, author2);

    assert(earnings1.total_earned == claimed1, 'Author1 total earned != claimed');
    assert(earnings2.total_earned == claimed2, 'Author2 total earned != claimed');
}

// ERC-compliant token contracts
#[starknet::contract]
mod ERC1155ReceiverContract {
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc1155::ERC1155ReceiverComponent;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(
        path: ERC1155ReceiverComponent, storage: erc1155_receiver, event: ERC1155ReceiverEvent,
    );

    // ERC1155Receiver Mixin
    #[abi(embed_v0)]
    impl ERC1155ReceiverMixinImpl =
        ERC1155ReceiverComponent::ERC1155ReceiverMixinImpl<ContractState>;
    impl ERC1155ReceiverInternalImpl = ERC1155ReceiverComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc1155_receiver: ERC1155ReceiverComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC1155ReceiverEvent: ERC1155ReceiverComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc1155_receiver.initializer();
    }
}

#[starknet::contract]
mod MockERC20 {
    use openzeppelin_token::erc20::{DefaultConfig, ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // ERC20 Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_supply: u256, recipient: ContractAddress) {
        let name = "MyToken";
        let symbol = "MTK";

        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }
}
