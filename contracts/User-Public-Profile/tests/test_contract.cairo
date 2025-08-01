use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};

use publicprofile::{
    IUserPublicProfileDispatcher, IUserPublicProfileDispatcherTrait,
    PersonalInfo, SocialMediaLinks, ProfileSettings
};

fn deploy_contract() -> ContractAddress {
    let contract = declare("UserPublicProfile").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

fn get_sample_personal_info() -> PersonalInfo {
    PersonalInfo {
        username: "alice_dev",
        name: "Alice Developer",
        bio: "Full-stack developer passionate about blockchain",
        location: "San Francisco, CA",
        email: "alice@example.com",
        phone: "+1-555-0123",
        org: "TechCorp Inc.",
        website: "https://alice.dev",
    }
}

fn get_sample_social_links() -> SocialMediaLinks {
    SocialMediaLinks {
        x_handle: "@alice_dev",
        linkedin: "linkedin.com/in/alice-dev",
        instagram: "@alice.codes",
        tiktok: "@alice_codes",
        facebook: "alice.developer",
        discord: "alice_dev#1234",
        youtube: "@AliceDev",
        github: "github.com/alice-dev",
    }
}

fn get_sample_settings() -> ProfileSettings {
    ProfileSettings {
        display_public_profile: true,
        email_notifications: true,
        marketplace_profile: true,
    }
}

#[test]
fn test_register_profile() {
    let contract_address = deploy_contract();
    let dispatcher = IUserPublicProfileDispatcher { contract_address };

    let user1: ContractAddress = 0x123.try_into().unwrap();
    start_cheat_caller_address(contract_address, user1);

    let personal_info = get_sample_personal_info();
    let social_links = get_sample_social_links();
    let settings = get_sample_settings();

    // Register profile
    dispatcher.register_profile(personal_info, social_links, settings);

    // Verify profile is registered
    assert(dispatcher.is_profile_registered(user1), 'Profile not registered');
    
    // Verify profile count
    assert(dispatcher.get_profile_count() == 1, 'Profile count wrong');
    
    // Verify username
    assert(dispatcher.get_username(user1) == "alice_dev", 'Username mismatch');
    
    // Verify profile is public
    assert(dispatcher.is_profile_public(user1), 'Profile not public');

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_get_profile_components() {
    let contract_address = deploy_contract();
    let dispatcher = IUserPublicProfileDispatcher { contract_address };

    let user1: ContractAddress = 0x123.try_into().unwrap();
    start_cheat_caller_address(contract_address, user1);

    let personal_info = get_sample_personal_info();
    let social_links = get_sample_social_links();
    let settings = get_sample_settings();

    // Register profile
    dispatcher.register_profile(personal_info, social_links, settings);

    // Get and verify personal info
    let retrieved_personal = dispatcher.get_personal_info(user1);
    assert(retrieved_personal.username == "alice_dev", 'Username mismatch');
    assert(retrieved_personal.name == "Alice Developer", 'Name mismatch');
    assert(retrieved_personal.email == "alice@example.com", 'Email mismatch');

    // Get and verify social links
    let retrieved_social = dispatcher.get_social_links(user1);
    assert(retrieved_social.x_handle == "@alice_dev", 'X handle mismatch');
    assert(retrieved_social.github == "github.com/alice-dev", 'GitHub mismatch');

    // Get and verify settings
    let retrieved_settings = dispatcher.get_settings(user1);
    assert(retrieved_settings.display_public_profile == true, 'Public profile wrong');
    assert(retrieved_settings.email_notifications == true, 'Email notifications wrong');
    assert(retrieved_settings.marketplace_profile == true, 'Marketplace profile wrong');

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_update_personal_info() {
    let contract_address = deploy_contract();
    let dispatcher = IUserPublicProfileDispatcher { contract_address };

    let user1: ContractAddress = 0x123.try_into().unwrap();
    start_cheat_caller_address(contract_address, user1);

    let personal_info = get_sample_personal_info();
    let social_links = get_sample_social_links();
    let settings = get_sample_settings();

    // Register profile
    dispatcher.register_profile(personal_info, social_links, settings);

    // Update personal info
    let updated_personal = PersonalInfo {
        username: "alice_senior_dev",
        name: "Alice Senior Developer",
        bio: "Senior full-stack developer and blockchain expert",
        location: "New York, NY",
        email: "alice.senior@example.com",
        phone: "+1-555-9999",
        org: "BlockchainCorp",
        website: "https://alicesenior.dev",
    };

    dispatcher.update_personal_info(updated_personal);

    // Verify updates
    let retrieved_personal = dispatcher.get_personal_info(user1);
    assert(retrieved_personal.username == "alice_senior_dev", 'Username not updated');
    assert(retrieved_personal.name == "Alice Senior Developer", 'Name not updated');
    assert(retrieved_personal.location == "New York, NY", 'Location not updated');

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_update_social_links() {
    let contract_address = deploy_contract();
    let dispatcher = IUserPublicProfileDispatcher { contract_address };

    let user1: ContractAddress = 0x123.try_into().unwrap();
    start_cheat_caller_address(contract_address, user1);

    let personal_info = get_sample_personal_info();
    let social_links = get_sample_social_links();
    let settings = get_sample_settings();

    // Register profile
    dispatcher.register_profile(personal_info, social_links, settings);

    // Update social links
    let updated_social = SocialMediaLinks {
        x_handle: "@alice_senior",
        linkedin: "linkedin.com/in/alice-senior-dev",
        instagram: "@alice.senior.codes",
        tiktok: "@alice_senior_codes",
        facebook: "alice.senior.developer",
        discord: "alice_senior#5678",
        youtube: "@AliceSeniorDev",
        github: "github.com/alice-senior-dev",
    };

    dispatcher.update_social_links(updated_social);

    // Verify updates
    let retrieved_social = dispatcher.get_social_links(user1);
    assert(retrieved_social.x_handle == "@alice_senior", 'X handle not updated');
    assert(retrieved_social.github == "github.com/alice-senior-dev", 'GitHub not updated');

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_update_settings() {
    let contract_address = deploy_contract();
    let dispatcher = IUserPublicProfileDispatcher { contract_address };

    let user1: ContractAddress = 0x123.try_into().unwrap();
    start_cheat_caller_address(contract_address, user1);

    let personal_info = get_sample_personal_info();
    let social_links = get_sample_social_links();
    let settings = get_sample_settings();

    // Register profile
    dispatcher.register_profile(personal_info, social_links, settings);

    // Update settings
    let updated_settings = ProfileSettings {
        display_public_profile: false,
        email_notifications: false,
        marketplace_profile: true,
    };

    dispatcher.update_settings(updated_settings);

    // Verify updates
    let retrieved_settings = dispatcher.get_settings(user1);
    assert(retrieved_settings.display_public_profile == false, 'Public profile not updated');
    assert(retrieved_settings.email_notifications == false, 'Email notifications wrong');
    assert(retrieved_settings.marketplace_profile == true, 'Marketplace setting wrong');

    // Verify profile is now private
    assert(!dispatcher.is_profile_public(user1), 'Profile should be private');

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_privacy_controls() {
    let contract_address = deploy_contract();
    let dispatcher = IUserPublicProfileDispatcher { contract_address };

    let user1: ContractAddress = 0x123.try_into().unwrap();
    let user2: ContractAddress = 0x456.try_into().unwrap();

    // User1 registers with private profile
    start_cheat_caller_address(contract_address, user1);
    
    let personal_info = get_sample_personal_info();
    let social_links = get_sample_social_links();
    let private_settings = ProfileSettings {
        display_public_profile: false,  // Private profile
        email_notifications: true,
        marketplace_profile: true,
    };

    dispatcher.register_profile(personal_info, social_links, private_settings);
    
    // Verify profile is marked as private
    assert(!dispatcher.is_profile_public(user1), 'Profile should be private');
    
    // User1 can still access their own profile
    let own_info = dispatcher.get_personal_info(user1);
    assert(own_info.username == "alice_dev", 'Own profile access failed');
    
    stop_cheat_caller_address(contract_address);

    // User2 can check if profile exists but can't access details
    start_cheat_caller_address(contract_address, user2);
    
    // User2 can see that User1 has a profile
    assert(dispatcher.is_profile_registered(user1), 'Profile should be registered');
    
    // But can see it's private
    assert(!dispatcher.is_profile_public(user1), 'Profile should show private');
    
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_multiple_users() {
    let contract_address = deploy_contract();
    let dispatcher = IUserPublicProfileDispatcher { contract_address };

    let user1: ContractAddress = 0x123.try_into().unwrap();
    let user2: ContractAddress = 0x456.try_into().unwrap();

    // User1 registers
    start_cheat_caller_address(contract_address, user1);
    dispatcher.register_profile(get_sample_personal_info(), get_sample_social_links(), get_sample_settings());
    stop_cheat_caller_address(contract_address);

    // User2 registers
    start_cheat_caller_address(contract_address, user2);
    let user2_personal = PersonalInfo {
        username: "bob_designer",
        name: "Bob Designer",
        bio: "UI/UX Designer specializing in Web3",
        location: "Austin, TX",
        email: "bob@example.com",
        phone: "+1-555-0456",
        org: "DesignStudio",
        website: "https://bob.design",
    };
    dispatcher.register_profile(user2_personal, get_sample_social_links(), get_sample_settings());
    stop_cheat_caller_address(contract_address);

    // Verify both users are registered
    assert(dispatcher.is_profile_registered(user1), 'User1 not registered');
    assert(dispatcher.is_profile_registered(user2), 'User2 not registered');
    assert(dispatcher.get_profile_count() == 2, 'Profile count wrong');

    // User1 can access User2's public profile
    start_cheat_caller_address(contract_address, user1);
    let user2_info = dispatcher.get_personal_info(user2);
    assert(user2_info.username == "bob_designer", 'User2 username wrong');
    stop_cheat_caller_address(contract_address);
}
