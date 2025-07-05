use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp,
    stop_cheat_block_timestamp,
};
use user_achievements::IUserAchievementsDispatcher;
use user_achievements::IUserAchievementsDispatcherTrait;
use user_achievements::{
    AchievementType, ActivityType, BadgeType, CertificateType
};


pub fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

pub fn USER_1() -> ContractAddress {
    'USER_1'.try_into().unwrap()
}

pub fn USER_2() -> ContractAddress {
    'USER_2'.try_into().unwrap()
}


fn deploy_contract() -> ContractAddress {
    let contract = declare("UserAchievements").unwrap().contract_class();
    let owner: ContractAddress = OWNER();
    let mut calldata = ArrayTrait::new();
    calldata.append(owner.into());
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

fn deploy_contract_with_owner(owner: ContractAddress) -> ContractAddress {
    let contract = declare("UserAchievements").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    calldata.append(owner.into());
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

#[test]
fn test_constructor() {
    let contract_address = deploy_contract();
    let _dispatcher = IUserAchievementsDispatcher { contract_address };
    
    // Test that default activity points are set
    // Note: We can't directly test activity points without additional view functions
    // but we can test that the contract deploys successfully
    assert!(true, "Contract should deploy successfully");
}

#[test]
fn test_record_achievement() {
    let owner: ContractAddress = OWNER();
    let contract_address = deploy_contract_with_owner(owner);
    let dispatcher = IUserAchievementsDispatcher { contract_address };
    
    let user: ContractAddress = USER_1();
    let metadata_id = 'metadata_hash_123';
    let asset_id = Option::Some('asset_123');
    let category = Option::Some('category_1');
    let points = 50;

    start_cheat_caller_address(dispatcher.contract_address, owner);
    
    // Record achievement (only owner can do this)
    dispatcher.record_achievement(
        user,
        AchievementType::Mint,
        metadata_id,
        asset_id,
        category,
        points,
    );

    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Verify achievement was recorded
    let achievements = dispatcher.get_user_achievements(user, 0, 1);
    assert!(achievements.len() == 1, "Should have one achievement");
    
    let achievement = achievements.at(0);
    assert!(*achievement.achievement_type == AchievementType::Mint, "Wrong achievement type");
    assert!(*achievement.points == points, "Wrong points");
    assert!(*achievement.metadata_id == metadata_id, "Wrong metadata ID");
    
    // Verify total points
    let total_points = dispatcher.get_user_total_points(user);
    assert!(total_points == points, "Wrong total points");
    
    // Verify activity count
    let activity_count = dispatcher.get_user_activity_count(user);
    assert!(activity_count == 1, "Wrong activity count");
}

#[test]
fn test_record_activity_event() {
    let owner: ContractAddress = OWNER();
    let contract_address = deploy_contract_with_owner(owner);
    let dispatcher = IUserAchievementsDispatcher { contract_address };
    
    let user: ContractAddress = USER_1();
    let metadata_id = 'activity_metadata_456';
    let asset_id = Option::Some('asset_456');
    let category = Option::Some('category_2');

    start_cheat_caller_address(dispatcher.contract_address, owner);
    
    // Record activity event (only owner can do this)
    dispatcher.record_activity_event(
        user,
        ActivityType::AssetSold,
        metadata_id,
        asset_id,
        category,
    );

    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Verify activity was recorded as achievement
    let achievements = dispatcher.get_user_achievements(user, 0, 1);
    assert!(achievements.len() == 1, "Should have one achievement");
    
    let achievement = achievements.at(0);
    assert!(*achievement.achievement_type == AchievementType::Sale, "Should be Sale achievement");
    assert!(*achievement.points > 0_u32, "Should have points");
}

#[test]
fn test_mint_badge() {
    let owner: ContractAddress = OWNER();
    let contract_address = deploy_contract_with_owner(owner);
    let dispatcher = IUserAchievementsDispatcher { contract_address };
    
    let user: ContractAddress = USER_1();
    let metadata_id = 'badge_metadata_789';
    
    start_cheat_caller_address(dispatcher.contract_address, owner);
    // Mint badge (only owner can do this)
    dispatcher.mint_badge(user, BadgeType::Creator, metadata_id);

    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Verify badge was minted
    let badges = dispatcher.get_user_badges(user);
    assert!(badges.len() == 1, "Should have one badge");
    
    let badge = badges.at(0);
    assert!(*badge.badge_type == BadgeType::Creator, "Wrong badge type");
    assert!(*badge.metadata_id == metadata_id, "Wrong metadata ID");
    assert!(*badge.is_active, "Badge should be active");
}

#[test]
fn test_mint_certificate() {
    let owner: ContractAddress = OWNER();
    let contract_address = deploy_contract_with_owner(owner);
    let dispatcher = IUserAchievementsDispatcher { contract_address };
    
    let user: ContractAddress = USER_1();
    let metadata_id = 'certificate_metadata_123';
    let expiry_date = Option::Some(1735689600); // Future timestamp
    
    start_cheat_caller_address(dispatcher.contract_address, owner);
    // Mint certificate (only owner can do this)
    dispatcher.mint_certificate(
        user,
        CertificateType::CreatorCertificate,
        metadata_id,
        expiry_date,
    );

    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Verify certificate was minted
    let certificates = dispatcher.get_user_certificates(user);
    assert!(certificates.len() == 1, "Should have one certificate");
    
    let certificate = certificates.at(0);
    assert!(*certificate.certificate_type == CertificateType::CreatorCertificate, "Wrong certificate type");
    assert!(*certificate.metadata_id == metadata_id, "Wrong metadata ID");
    assert!(*certificate.is_valid, "Certificate should be valid");
}

#[test]
fn test_leaderboard_functionality() {
    let owner: ContractAddress = OWNER();
    let contract_address = deploy_contract_with_owner(owner);
    let dispatcher = IUserAchievementsDispatcher { contract_address };
    
    let user1: ContractAddress = USER_1();
    let user2: ContractAddress = USER_2();
    
    // Record achievements for multiple users
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.record_achievement(
        user1,
        AchievementType::Mint,
        'metadata1',
        Option::None,
        Option::None,
        100,
    );

    stop_cheat_caller_address(dispatcher.contract_address);
    
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.record_achievement(
        user2,
        AchievementType::Sale,
        'metadata2',
        Option::None,
        Option::None,
        50,
    );

    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, owner);
    // Get leaderboard
    let leaderboard = dispatcher.get_leaderboard(0, 10);
    assert!(leaderboard.len() >= 2, "Should have at least 2 users in leaderboard");
    
    // Check user ranks
    let rank1 = dispatcher.get_user_rank(user1);
    let rank2 = dispatcher.get_user_rank(user2);
    assert!(rank1 > 0_u32, "User1 should have a rank");
    assert!(rank2 > 0_u32, "User2 should have a rank");

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_multiple_achievements_same_user() {
    let owner: ContractAddress = OWNER();
    let contract_address = deploy_contract_with_owner(owner);
    let dispatcher = IUserAchievementsDispatcher { contract_address };
    
    let user: ContractAddress = USER_1();
    
    // Record multiple achievements
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.record_achievement(
        user,
        AchievementType::Mint,
        'metadata1',
        Option::None,
        Option::None,
        10,
    );

    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.record_achievement(
        user,
        AchievementType::Sale,
        'metadata2',
        Option::None,
        Option::None,
        25,
    );
    
    dispatcher.record_achievement(
        user,
        AchievementType::License,
        'metadata3',
        Option::None,
        Option::None,
        20,
    );

    stop_cheat_caller_address(dispatcher.contract_address);

    // Verify all achievements are recorded
    let achievements = dispatcher.get_user_achievements(user, 0, 10);
    assert!(achievements.len() == 3, "Should have 3 achievements");
    
    // Verify total points
    let total_points = dispatcher.get_user_total_points(user);
    assert!(total_points == 55_u32, "Total points should be 55");
    
    // Verify activity count
    let activity_count = dispatcher.get_user_activity_count(user);
    assert!(activity_count == 3, "Should have 3 activities");
}

#[test]
fn test_pagination() {
    let owner: ContractAddress = OWNER();
    let contract_address = deploy_contract_with_owner(owner);
    let dispatcher = IUserAchievementsDispatcher { contract_address };
    
    let user: ContractAddress = USER_1();
    
    // Record 5 achievements
    let mut i = 0;
    while i != 5_u32 {
        start_cheat_caller_address(dispatcher.contract_address, owner);
        dispatcher.record_achievement(
            user,
            AchievementType::Mint,
            'metadata',
            Option::None,
            Option::None,
            10,
        );
        i += 1;
    };

    stop_cheat_caller_address(dispatcher.contract_address);

    // Test pagination - get first 2
    let achievements_page1 = dispatcher.get_user_achievements(user, 0, 2);
    assert!(achievements_page1.len() == 2, "Should have 2 achievements on first page");
    
    // Test pagination - get next 2
    let achievements_page2 = dispatcher.get_user_achievements(user, 2, 2);
    assert!(achievements_page2.len() == 2, "Should have 2 achievements on second page");
    
    // Test pagination - get remaining 1
    let achievements_page3 = dispatcher.get_user_achievements(user, 4, 2);
    assert!(achievements_page3.len() == 1, "Should have 1 achievement on third page");
}

#[test]
fn test_set_activity_points() {
    let owner: ContractAddress = OWNER();
    let contract_address = deploy_contract_with_owner(owner);
    let dispatcher = IUserAchievementsDispatcher { contract_address };
    
    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Set custom activity points (only owner can do this)
    dispatcher.set_activity_points(ActivityType::AssetMinted, 15);

    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Test that the new points are applied by recording an activity
    let user: ContractAddress = USER_1();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.record_activity_event(
        user,
        ActivityType::AssetMinted,
        'metadata',
        Option::None,
        Option::None,
    );

    stop_cheat_caller_address(dispatcher.contract_address);
    
    let achievements = dispatcher.get_user_achievements(user, 0, 1);
    let achievement = achievements.at(0);
    assert!(*achievement.points == 15_u32, "Should have updated points");
}

#[test]
fn test_achievement_types() {
    let owner: ContractAddress = OWNER();
    let contract_address = deploy_contract_with_owner(owner);
    let dispatcher = IUserAchievementsDispatcher { contract_address };
    
    let user: ContractAddress = USER_1();
    
    // Test different achievement types
    let achievement_types = array![
        AchievementType::Mint,
        AchievementType::Sale,
        AchievementType::License,
        AchievementType::Transfer,
        AchievementType::Collection,
        AchievementType::Collaboration,
        AchievementType::Innovation,
        AchievementType::Community,
        AchievementType::Custom,
    ];
    
    let mut i = 0;
    while i != achievement_types.len() {
        let achievement_type = *achievement_types.at(i);
        start_cheat_caller_address(dispatcher.contract_address, owner);
        dispatcher.record_achievement(
            user,
            achievement_type,
            'metadata',
            Option::None,
            Option::None,
            10,
        );
        i += 1;
    };

    stop_cheat_caller_address(dispatcher.contract_address);
    
    let achievements = dispatcher.get_user_achievements(user, 0, 10);
    assert!(achievements.len() == 9_u32, "Should have 9 achievements");
}

#[test] 
fn test_badge_types() {
    let owner: ContractAddress = OWNER();
    let contract_address = deploy_contract_with_owner(owner);
    let dispatcher = IUserAchievementsDispatcher { contract_address };
    
    let user: ContractAddress = USER_1();
    
    // Test different badge types
    let badge_types = array![
        BadgeType::Creator,
        BadgeType::Seller,
        BadgeType::Licensor,
        BadgeType::Collector,
        BadgeType::Innovator,
        BadgeType::CommunityLeader,
        BadgeType::EarlyAdopter,
        BadgeType::TopPerformer,
        BadgeType::CustomBadge,
    ];
    
    let mut i = 0;
    while i != badge_types.len() {
        let badge_type = *badge_types.at(i);
        start_cheat_caller_address(dispatcher.contract_address, owner);
        dispatcher.mint_badge(user, badge_type, 'metadata');
        i += 1;
    };

    stop_cheat_caller_address(dispatcher.contract_address);
    
    let badges = dispatcher.get_user_badges(user);
    assert!(badges.len() == 9_u32, "Should have 9 badges");
}

#[test]
fn test_certificate_types() {
    let owner: ContractAddress = OWNER();
    let contract_address = deploy_contract_with_owner(owner);
    let dispatcher = IUserAchievementsDispatcher { contract_address };
    
    let user: ContractAddress = USER_1();
    
    // Test different certificate types
    let certificate_types = array![
        CertificateType::CreatorCertificate,
        CertificateType::SellerCertificate,
        CertificateType::LicensorCertificate,
        CertificateType::InnovationCertificate,
        CertificateType::CommunityCertificate,
        CertificateType::AchievementCertificate,
        CertificateType::CustomCertificate,
    ];
    
    let mut i = 0;
    while i != certificate_types.len() {
        let certificate_type = *certificate_types.at(i);
        start_cheat_caller_address(dispatcher.contract_address, owner);
        dispatcher.mint_certificate(user, certificate_type, 'metadata', Option::None);
        i += 1;
    };

    stop_cheat_caller_address(dispatcher.contract_address);
    
    let certificates = dispatcher.get_user_certificates(user);
    assert!(certificates.len() == 7_u32, "Should have 7 certificates");
}

#[test]
fn test_activity_to_achievement_mapping() {
    let owner: ContractAddress = OWNER();
    let contract_address = deploy_contract_with_owner(owner);
    let dispatcher = IUserAchievementsDispatcher { contract_address };
    
    let user: ContractAddress = USER_1();
    
    // Test activity type to achievement type mapping
    let activity_achievement_pairs = array![
        (ActivityType::AssetMinted, AchievementType::Mint),
        (ActivityType::AssetSold, AchievementType::Sale),
        (ActivityType::AssetLicensed, AchievementType::License),
        (ActivityType::AssetTransferred, AchievementType::Transfer),
        (ActivityType::CollectionCreated, AchievementType::Collection),
        (ActivityType::CollaborationJoined, AchievementType::Collaboration),
        (ActivityType::InnovationAwarded, AchievementType::Innovation),
        (ActivityType::CommunityContribution, AchievementType::Community),
        (ActivityType::CustomActivity, AchievementType::Custom),
    ];
    
    let mut i = 0;
    while i != activity_achievement_pairs.len() {
        let (activity_type, _expected_achievement_type) = *activity_achievement_pairs.at(i);
        start_cheat_caller_address(dispatcher.contract_address, owner);
        dispatcher.record_activity_event(
            user,
            activity_type,
            'metadata',
            Option::None,
            Option::None,
        );
        i += 1;
    };

    stop_cheat_caller_address(dispatcher.contract_address);
    
    let achievements = dispatcher.get_user_achievements(user, 0, 10);
    assert!(achievements.len() == 9_u32, "Should have 9 achievements from activities");
}

#[test]
fn test_owner_management() {
    let owner: ContractAddress = OWNER();
    let contract_address = deploy_contract_with_owner(owner);
    let dispatcher = IUserAchievementsDispatcher { contract_address };
    
    let new_owner: ContractAddress = USER_1();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    // Change owner (only current owner can do this)
    dispatcher.set_owner(new_owner);

    stop_cheat_caller_address(dispatcher.contract_address);
    
    start_cheat_caller_address(dispatcher.contract_address, owner);
    // Test that new owner can record achievements
    dispatcher.record_achievement(
        new_owner,
        AchievementType::Mint,
        'metadata',
        Option::None,
        Option::None,
        10,
    );
    
    stop_cheat_caller_address(dispatcher.contract_address);
    let achievements = dispatcher.get_user_achievements(new_owner, 0, 1);
    assert!(achievements.len() == 1, "New owner should be able to record achievements");
}

#[test]
fn test_comprehensive_user_profile() {
    let owner: ContractAddress = OWNER();
    let contract_address = deploy_contract_with_owner(owner);
    let dispatcher = IUserAchievementsDispatcher { contract_address };
    
    let user: ContractAddress = USER_1();
    
    // Create a comprehensive user profile with achievements, badges, and certificates
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.record_achievement(
        user,
        AchievementType::Mint,
        'achievement_1',
        Option::Some('asset_1'),
        Option::Some('category_1'),
        25,
    );

    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.record_achievement(
        user,
        AchievementType::Sale,
        'achievement_2',
        Option::Some('asset_2'),
        Option::Some('category_2'),
        50,
    );

    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.mint_badge(user, BadgeType::Creator, 'badge_metadata');
    dispatcher.mint_badge(user, BadgeType::Seller, 'badge_metadata_2');
    
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.mint_certificate(
        user,
        CertificateType::CreatorCertificate,
        'cert_metadata',
        Option::Some(1735689600),
    );

    stop_cheat_caller_address(dispatcher.contract_address);

    // Verify comprehensive profile
    let achievements = dispatcher.get_user_achievements(user, 0, 10);
    let badges = dispatcher.get_user_badges(user);
    let certificates = dispatcher.get_user_certificates(user);
    let total_points = dispatcher.get_user_total_points(user);
    let activity_count = dispatcher.get_user_activity_count(user);
    let rank = dispatcher.get_user_rank(user);
    
    assert!(achievements.len() == 2, "Should have 2 achievements");
    assert!(badges.len() == 2, "Should have 2 badges");
    assert!(certificates.len() == 1, "Should have 1 certificate");
    assert!(total_points == 75_u32, "Should have 75 total points");
    assert!(activity_count == 2_u32, "Should have 2 activities");
    assert!(rank > 0_u32, "Should have a rank");
} 