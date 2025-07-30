use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct UserProfile {
    // Personal Information
    pub username: ByteArray,
    pub name: ByteArray,
    pub bio: ByteArray,
    pub location: ByteArray,
    pub email: ByteArray,
    pub phone: ByteArray,
    pub org: ByteArray,
    pub website: ByteArray,
    
    // Social Media Links
    pub x_handle: ByteArray,
    pub linkedin: ByteArray,
    pub instagram: ByteArray,
    pub tiktok: ByteArray,
    pub facebook: ByteArray,
    pub discord: ByteArray,
    pub youtube: ByteArray,
    pub github: ByteArray,
    
    // Boolean Settings
    pub display_public_profile: bool,
    pub email_notifications: bool,
    pub marketplace_profile: bool,
    
    // Metadata
    pub is_registered: bool,
    pub last_updated: u64,
}

#[derive(Drop, Serde)]
pub struct SocialMediaLinks {
    pub x_handle: ByteArray,
    pub linkedin: ByteArray,
    pub instagram: ByteArray,
    pub tiktok: ByteArray,
    pub facebook: ByteArray,
    pub discord: ByteArray,
    pub youtube: ByteArray,
    pub github: ByteArray,
}

#[derive(Drop, Serde)]
pub struct PersonalInfo {
    pub username: ByteArray,
    pub name: ByteArray,
    pub bio: ByteArray,
    pub location: ByteArray,
    pub email: ByteArray,
    pub phone: ByteArray,
    pub org: ByteArray,
    pub website: ByteArray,
}

#[derive(Drop, Serde)]
pub struct ProfileSettings {
    pub display_public_profile: bool,
    pub email_notifications: bool,
    pub marketplace_profile: bool,
}

#[starknet::interface]
pub trait IUserPublicProfile<TContractState> {
    fn register_profile(
        ref self: TContractState,
        personal_info: PersonalInfo,
        social_links: SocialMediaLinks,
        settings: ProfileSettings,
    );
    fn update_personal_info(ref self: TContractState, personal_info: PersonalInfo);
    fn update_social_links(ref self: TContractState, social_links: SocialMediaLinks);
    fn update_settings(ref self: TContractState, settings: ProfileSettings);
    fn get_profile(self: @TContractState, user: ContractAddress) -> UserProfile;
    fn get_personal_info(self: @TContractState, user: ContractAddress) -> PersonalInfo;
    fn get_social_links(self: @TContractState, user: ContractAddress) -> SocialMediaLinks;
    fn get_settings(self: @TContractState, user: ContractAddress) -> ProfileSettings;
    fn is_profile_registered(self: @TContractState, user: ContractAddress) -> bool;
    fn get_profile_count(self: @TContractState) -> u32;
    fn get_username(self: @TContractState, user: ContractAddress) -> ByteArray;
    fn is_profile_public(self: @TContractState, user: ContractAddress) -> bool;
}

#[starknet::contract]
mod UserPublicProfile {
    use super::{UserProfile, SocialMediaLinks, PersonalInfo, ProfileSettings, IUserPublicProfile};
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, 
        StorageMapReadAccess, StorageMapWriteAccess, Map
    };

    #[storage]
    struct Storage {
        profiles: Map<ContractAddress, UserProfile>,
        profile_count: u32,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ProfileRegistered: ProfileRegistered,
        ProfileUpdated: ProfileUpdated,
        SettingsUpdated: SettingsUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct ProfileRegistered {
        #[key]
        user: ContractAddress,
        username: ByteArray,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ProfileUpdated {
        #[key]
        user: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct SettingsUpdated {
        #[key]
        user: ContractAddress,
        timestamp: u64,
    }

    #[abi(embed_v0)]
    impl UserPublicProfileImpl of IUserPublicProfile<ContractState> {
        /// Register a new user profile with all information
        fn register_profile(
            ref self: ContractState,
            personal_info: PersonalInfo,
            social_links: SocialMediaLinks,
            settings: ProfileSettings,
        ) {
            let caller = get_caller_address();
            let current_time = starknet::get_block_timestamp();
            
            let profile = UserProfile {
                // Personal Information
                username: personal_info.username.clone(),
                name: personal_info.name,
                bio: personal_info.bio,
                location: personal_info.location,
                email: personal_info.email,
                phone: personal_info.phone,
                org: personal_info.org,
                website: personal_info.website,
                
                // Social Media Links
                x_handle: social_links.x_handle,
                linkedin: social_links.linkedin,
                instagram: social_links.instagram,
                tiktok: social_links.tiktok,
                facebook: social_links.facebook,
                discord: social_links.discord,
                youtube: social_links.youtube,
                github: social_links.github,
                
                // Boolean Settings
                display_public_profile: settings.display_public_profile,
                email_notifications: settings.email_notifications,
                marketplace_profile: settings.marketplace_profile,
                
                // Metadata
                is_registered: true,
                last_updated: current_time,
            };

            self.profiles.write(caller, profile);
            let current_count = self.profile_count.read();
            self.profile_count.write(current_count + 1);

            self.emit(ProfileRegistered {
                user: caller,
                username: personal_info.username,
                timestamp: current_time,
            });
        }

        /// Update personal information only
        fn update_personal_info(
            ref self: ContractState,
            personal_info: PersonalInfo,
        ) {
            let caller = get_caller_address();
            let profile = self.profiles.read(caller);
            assert(profile.is_registered, 'Profile not registered');

            let current_time = starknet::get_block_timestamp();
            let updated_profile = UserProfile {
                username: personal_info.username,
                name: personal_info.name,
                bio: personal_info.bio,
                location: personal_info.location,
                email: personal_info.email,
                phone: personal_info.phone,
                org: personal_info.org,
                website: personal_info.website,
                x_handle: profile.x_handle,
                linkedin: profile.linkedin,
                instagram: profile.instagram,
                tiktok: profile.tiktok,
                facebook: profile.facebook,
                discord: profile.discord,
                youtube: profile.youtube,
                github: profile.github,
                display_public_profile: profile.display_public_profile,
                email_notifications: profile.email_notifications,
                marketplace_profile: profile.marketplace_profile,
                is_registered: profile.is_registered,
                last_updated: current_time,
            };

            self.profiles.write(caller, updated_profile);
            
            self.emit(ProfileUpdated {
                user: caller,
                timestamp: current_time,
            });
        }

        /// Update social media links only
        fn update_social_links(
            ref self: ContractState,
            social_links: SocialMediaLinks,
        ) {
            let caller = get_caller_address();
            let profile = self.profiles.read(caller);
            assert(profile.is_registered, 'Profile not registered');

            let current_time = starknet::get_block_timestamp();
            let updated_profile = UserProfile {
                username: profile.username,
                name: profile.name,
                bio: profile.bio,
                location: profile.location,
                email: profile.email,
                phone: profile.phone,
                org: profile.org,
                website: profile.website,
                x_handle: social_links.x_handle,
                linkedin: social_links.linkedin,
                instagram: social_links.instagram,
                tiktok: social_links.tiktok,
                facebook: social_links.facebook,
                discord: social_links.discord,
                youtube: social_links.youtube,
                github: social_links.github,
                display_public_profile: profile.display_public_profile,
                email_notifications: profile.email_notifications,
                marketplace_profile: profile.marketplace_profile,
                is_registered: profile.is_registered,
                last_updated: current_time,
            };

            self.profiles.write(caller, updated_profile);
            
            self.emit(ProfileUpdated {
                user: caller,
                timestamp: current_time,
            });
        }

        /// Update profile settings only
        fn update_settings(
            ref self: ContractState,
            settings: ProfileSettings,
        ) {
            let caller = get_caller_address();
            let profile = self.profiles.read(caller);
            assert(profile.is_registered, 'Profile not registered');

            let current_time = starknet::get_block_timestamp();
            let updated_profile = UserProfile {
                username: profile.username,
                name: profile.name,
                bio: profile.bio,
                location: profile.location,
                email: profile.email,
                phone: profile.phone,
                org: profile.org,
                website: profile.website,
                x_handle: profile.x_handle,
                linkedin: profile.linkedin,
                instagram: profile.instagram,
                tiktok: profile.tiktok,
                facebook: profile.facebook,
                discord: profile.discord,
                youtube: profile.youtube,
                github: profile.github,
                display_public_profile: settings.display_public_profile,
                email_notifications: settings.email_notifications,
                marketplace_profile: settings.marketplace_profile,
                is_registered: profile.is_registered,
                last_updated: current_time,
            };

            self.profiles.write(caller, updated_profile);
            
            self.emit(SettingsUpdated {
                user: caller,
                timestamp: current_time,
            });
        }

        /// Get complete user profile
        fn get_profile(self: @ContractState, user: ContractAddress) -> UserProfile {
            let profile = self.profiles.read(user);
            assert(profile.is_registered, 'Profile not found');
            
            // Check if profile is public or if caller is the owner
            let caller = get_caller_address();
            if user != caller {
                assert(profile.display_public_profile, 'Profile is private');
            }
            
            profile
        }

        /// Get personal information only
        fn get_personal_info(self: @ContractState, user: ContractAddress) -> PersonalInfo {
            let profile = self.profiles.read(user);
            assert(profile.is_registered, 'Profile not found');
            
            let caller = get_caller_address();
            if user != caller {
                assert(profile.display_public_profile, 'Profile is private');
            }

            PersonalInfo {
                username: profile.username,
                name: profile.name,
                bio: profile.bio,
                location: profile.location,
                email: profile.email,
                phone: profile.phone,
                org: profile.org,
                website: profile.website,
            }
        }

        /// Get social media links only
        fn get_social_links(self: @ContractState, user: ContractAddress) -> SocialMediaLinks {
            let profile = self.profiles.read(user);
            assert(profile.is_registered, 'Profile not found');
            
            let caller = get_caller_address();
            if user != caller {
                assert(profile.display_public_profile, 'Profile is private');
            }

            SocialMediaLinks {
                x_handle: profile.x_handle,
                linkedin: profile.linkedin,
                instagram: profile.instagram,
                tiktok: profile.tiktok,
                facebook: profile.facebook,
                discord: profile.discord,
                youtube: profile.youtube,
                github: profile.github,
            }
        }

        /// Get profile settings only
        fn get_settings(self: @ContractState, user: ContractAddress) -> ProfileSettings {
            let caller = get_caller_address();
            assert(user == caller, 'Can only view own settings');
            
            let profile = self.profiles.read(user);
            assert(profile.is_registered, 'Profile not found');

            ProfileSettings {
                display_public_profile: profile.display_public_profile,
                email_notifications: profile.email_notifications,
                marketplace_profile: profile.marketplace_profile,
            }
        }

        /// Check if user has a registered profile
        fn is_profile_registered(self: @ContractState, user: ContractAddress) -> bool {
            let profile = self.profiles.read(user);
            profile.is_registered
        }

        /// Get total number of registered profiles
        fn get_profile_count(self: @ContractState) -> u32 {
            self.profile_count.read()
        }

        /// Get user's username (public if profile is public)
        fn get_username(self: @ContractState, user: ContractAddress) -> ByteArray {
            let profile = self.profiles.read(user);
            assert(profile.is_registered, 'Profile not found');
            
            let caller = get_caller_address();
            if user != caller {
                assert(profile.display_public_profile, 'Profile is private');
            }
            
            profile.username
        }

        /// Check if profile is public
        fn is_profile_public(self: @ContractState, user: ContractAddress) -> bool {
            let profile = self.profiles.read(user);
            if !profile.is_registered {
                return false;
            }
            profile.display_public_profile
        }
    }
}
