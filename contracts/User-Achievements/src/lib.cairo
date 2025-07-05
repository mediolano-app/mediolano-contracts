use starknet::ContractAddress;

#[derive(Drop, Serde, PartialEq, starknet::Store)]
pub struct Achievement {
    pub achievement_type: AchievementType,
    pub timestamp: u64,
    pub metadata_id: felt252,
    pub asset_id: Option<felt252>,
    pub category: Option<felt252>,
    pub points: u32,
}

#[derive(Drop, Serde, PartialEq, starknet::Store)]
pub struct Badge {
    pub badge_type: BadgeType,
    pub timestamp: u64,
    pub metadata_id: felt252,
    pub is_active: bool,
}

#[derive(Drop, Serde, PartialEq, starknet::Store)]
pub struct Certificate {
    pub certificate_type: CertificateType,
    pub timestamp: u64,
    pub metadata_id: felt252,
    pub expiry_date: Option<u64>,
    pub is_valid: bool,
}

#[derive(Drop, Serde, PartialEq,  starknet::Store)]
pub struct LeaderboardEntry {
    pub user: ContractAddress,
    pub total_points: u32,
    pub achievements_count: u32,
    pub badges_count: u32,
    pub certificates_count: u32,
}

#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Serde, PartialEq, starknet::Store, Copy)]
pub enum AchievementType {
    Mint,
    Sale,
    License,
    Transfer,
    Collection,
    Collaboration,
    Innovation,
    Community,
    Custom,
}

#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Serde, PartialEq, starknet::Store, Copy)]
pub enum ActivityType {
    AssetMinted,
    AssetSold,
    AssetLicensed,
    AssetTransferred,
    CollectionCreated,
    CollaborationJoined,
    InnovationAwarded,
    CommunityContribution,
    CustomActivity,
}

#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Serde, PartialEq, starknet::Store, Copy)]
pub enum BadgeType {
    Creator,
    Seller,
    Licensor,
    Collector,
    Innovator,
    CommunityLeader,
    EarlyAdopter,
    TopPerformer,
    CustomBadge,
}

#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Serde, PartialEq, starknet::Store, Copy)]
pub enum CertificateType {
    CreatorCertificate,
    SellerCertificate,
    LicensorCertificate,
    InnovationCertificate,
    CommunityCertificate,
    AchievementCertificate,
    CustomCertificate,
}

// Define the contract interface
#[starknet::interface]
pub trait IUserAchievements<TContractState> {
    // Core achievement recording functions
    fn record_achievement(
        ref self: TContractState,
        user: ContractAddress,
        achievement_type: AchievementType,
        metadata_id: felt252,
        asset_id: Option<felt252>,
        category: Option<felt252>,
        points: u32,
    );

    // Permissionless recording by Mediolano platform
    fn record_activity_event(
        ref self: TContractState,
        user: ContractAddress,
        activity_type: ActivityType,
        metadata_id: felt252,
        asset_id: Option<felt252>,
        category: Option<felt252>,
    );

    // Badge and certificate management
    fn mint_badge(
        ref self: TContractState,
        user: ContractAddress,
        badge_type: BadgeType,
        metadata_id: felt252,
    );

    fn mint_certificate(
        ref self: TContractState,
        user: ContractAddress,
        certificate_type: CertificateType,
        metadata_id: felt252,
        expiry_date: Option<u64>,
    );

    // Query functions
    fn get_user_achievements(
        self: @TContractState,
        user: ContractAddress,
        start_index: u32,
        count: u32,
    ) -> Array<Achievement>;

    fn get_user_activity_count(self: @TContractState, user: ContractAddress) -> u32;
    fn get_user_total_points(self: @TContractState, user: ContractAddress) -> u32;
    fn get_user_badges(self: @TContractState, user: ContractAddress) -> Array<Badge>;
    fn get_user_certificates(self: @TContractState, user: ContractAddress) -> Array<Certificate>;

    // Leaderboard functions
    fn get_leaderboard(
        self: @TContractState,
        start_index: u32,
        count: u32,
    ) -> Array<LeaderboardEntry>;

    fn get_user_rank(self: @TContractState, user: ContractAddress) -> u32;

    // Configuration functions (owner only)
    fn set_activity_points(
        ref self: TContractState,
        activity_type: ActivityType,
        points: u32,
    );

    fn set_owner(ref self: TContractState, new_owner: ContractAddress);
}

// Define the contract module
#[starknet::contract]
pub mod UserAchievements {
    // Always use full paths for core library imports.
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use starknet::get_block_timestamp;
    
    // Always add all storage imports
    use starknet::storage::*;
    use core::array::ArrayTrait;
    use core::option::OptionTrait;
    use super::*;



    #[storage]
    struct Storage {
        // Core data structures
        user_achievements: Map<(ContractAddress, u32), Achievement>,
        user_activity_count: Map<ContractAddress, u32>,
        user_total_points: Map<ContractAddress, u32>,
        user_badges: Map<(ContractAddress, u32), Badge>,
        user_certificates: Map<(ContractAddress, u32), Certificate>,
        user_badge_count: Map<ContractAddress, u32>,
        user_certificate_count: Map<ContractAddress, u32>,

        // Leaderboard tracking
        leaderboard_entries: Map<u32, LeaderboardEntry>,
        leaderboard_count: u32,
        user_rank: Map<ContractAddress, u32>,

        // Configuration
        activity_points: Map<u32, u32>, // Maps activity_type_id to points
        owner: ContractAddress,

        // Statistics
        total_users: u32,
        total_achievements: u32,
        total_badges_minted: u32,
        total_certificates_minted: u32,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AchievementRecorded: AchievementRecorded,
        ActivityEventRecorded: ActivityEventRecorded,
        BadgeMinted: BadgeMinted,
        CertificateMinted: CertificateMinted,
        PointsUpdated: PointsUpdated,
        LeaderboardUpdated: LeaderboardUpdated,
        OwnerChanged: OwnerChanged,
    }

    #[derive(Drop, starknet::Event, Copy)] // Added Copy derive
    struct AchievementRecorded {
        #[key]
        user: ContractAddress,
        achievement_type: AchievementType,
        points: u32,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event, Copy)] // Added Copy derive
    struct ActivityEventRecorded {
        #[key]
        user: ContractAddress,
        activity_type: ActivityType,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event, Copy)] // Added Copy derive
    struct BadgeMinted {
        #[key]
        user: ContractAddress,
        badge_type: BadgeType,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event, Copy)] // Added Copy derive
    struct CertificateMinted {
        #[key]
        user: ContractAddress,
        certificate_type: CertificateType,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event, Copy)] // Added Copy derive
    struct PointsUpdated {
        #[key]
        user: ContractAddress,
        new_total: u32,
        change: u32,
    }

    #[derive(Drop, starknet::Event, Copy)] // Added Copy derive
    struct LeaderboardUpdated {
        user: ContractAddress,
        new_rank: u32,
        total_points: u32,
    }

    #[derive(Drop, starknet::Event, Copy)] // Added Copy derive
    struct OwnerChanged {
        #[key]
        old_owner: ContractAddress,
        #[key]
        new_owner: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);

        // Initialize default activity points using activity type IDs
        self.activity_points.write(0, 10); // AssetMinted
        self.activity_points.write(1, 25); // AssetSold
        self.activity_points.write(2, 20); // AssetLicensed
        self.activity_points.write(3, 5);  // AssetTransferred
        self.activity_points.write(4, 15); // CollectionCreated
        self.activity_points.write(5, 12); // CollaborationJoined
        self.activity_points.write(6, 50); // InnovationAwarded
        self.activity_points.write(7, 8);  // CommunityContribution
        self.activity_points.write(8, 5);  // CustomActivity
    }

    #[abi(embed_v0)]
    impl UserAchievements of IUserAchievements<ContractState> {
        fn record_achievement(
            ref self: ContractState,
            user: ContractAddress,
            achievement_type: AchievementType,
            metadata_id: felt252,
            asset_id: Option<felt252>,      // TODO: add asset_id
            category: Option<felt252>,
            points: u32,
        ) {
            // Only owner (Mediolano platform) can record achievements
            let caller = get_caller_address();
            assert!(caller == self.owner.read(), "Only owner can record achievements");

            let timestamp = get_block_timestamp();
            let current_count = self.user_activity_count.read(user);

            // Create achievement
            let achievement = Achievement {
                achievement_type,
                timestamp,
                metadata_id,
                asset_id,
                category,
                points,
            };

            // Store achievement
            self.user_achievements.write((user, current_count), achievement);
            self.user_activity_count.write(user, current_count + 1);

            // Update total points
            let current_points = self.user_total_points.read(user);
            let new_points = current_points + points;
            self.user_total_points.write(user, new_points);

            // Update global statistics
            self.total_achievements.write(self.total_achievements.read() + 1);

            // Update leaderboard
            self._update_leaderboard(user, new_points);

            // Emit events
            self.emit(Event::AchievementRecorded(AchievementRecorded {
                user,
                achievement_type,
                points,
                timestamp,
            }));

            self.emit(Event::PointsUpdated(PointsUpdated {
                user,
                new_total: new_points,
                change: points,
            }));
        }

        fn record_activity_event(
            ref self: ContractState,
            user: ContractAddress,
            activity_type: ActivityType,
            metadata_id: felt252,
            asset_id: Option<felt252>,
            category: Option<felt252>,
        ) {
            // Only owner (Mediolano platform) can record activity events
            let caller = get_caller_address();
            assert!(caller == self.owner.read(), "Only owner can record activity events");

            let timestamp = get_block_timestamp();
            // Get activity type ID and corresponding points
            let activity_type_id = self._activity_type_to_id(activity_type);
            let points = self.activity_points.read(activity_type_id);

            // Convert activity type to achievement type
            let achievement_type = self._activity_to_achievement_type(activity_type);

            // Record as achievement
            self.record_achievement(
                user,
                achievement_type,
                metadata_id,
                asset_id,
                category,
                points,
            );

            // Emit activity event
            self.emit(Event::ActivityEventRecorded(ActivityEventRecorded {
                user,
                activity_type,
                timestamp,
            }));
        }

        fn mint_badge(
            ref self: ContractState,
            user: ContractAddress,
            badge_type: BadgeType,
            metadata_id: felt252,
        ) {
            // Only owner (Mediolano platform) can mint badges
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can mint badges');

            let timestamp = get_block_timestamp();
            let current_count = self.user_badge_count.read(user);

            let badge = Badge {
                badge_type,
                timestamp,
                metadata_id,
                is_active: true,
            };

            self.user_badges.write((user, current_count), badge);
            self.user_badge_count.write(user, current_count + 1);
            self.total_badges_minted.write(self.total_badges_minted.read() + 1);

            self.emit(Event::BadgeMinted(BadgeMinted {
                user,
                badge_type,
                timestamp,
            }));
        }

        fn mint_certificate(
            ref self: ContractState,
            user: ContractAddress,
            certificate_type: CertificateType,
            metadata_id: felt252,
            expiry_date: Option<u64>,
        ) {
            // Only owner (Mediolano platform) can mint certificates
            let caller = get_caller_address();
            assert!(caller == self.owner.read(), "Only owner can mint certificates");

            let timestamp = get_block_timestamp();
            let current_count = self.user_certificate_count.read(user);

            let certificate = Certificate {
                certificate_type,
                timestamp,
                metadata_id,
                expiry_date,
                is_valid: true,
            };

            self.user_certificates.write((user, current_count), certificate);
            self.user_certificate_count.write(user, current_count + 1);
            self.total_certificates_minted.write(self.total_certificates_minted.read() + 1);

            self.emit(Event::CertificateMinted(CertificateMinted {
                user,
                certificate_type,
                timestamp,
            }));
        }

        fn get_user_achievements(
            self: @ContractState,
            user: ContractAddress,
            start_index: u32,
            count: u32,
        ) -> Array<Achievement> {
            let mut achievements = ArrayTrait::new();
            let total_count = self.user_activity_count.read(user);
            let end_index = if start_index + count > total_count {
                total_count
            } else {
                start_index + count
            };

            let mut i = start_index;
            while i != end_index {
                let achievement = self.user_achievements.read((user, i));
                achievements.append(achievement);
                i += 1;
            };

            achievements
        }

        fn get_user_activity_count(self: @ContractState, user: ContractAddress) -> u32 {
            self.user_activity_count.read(user)
        }

        fn get_user_total_points(self: @ContractState, user: ContractAddress) -> u32 {
            self.user_total_points.read(user)
        }

        fn get_user_badges(self: @ContractState, user: ContractAddress) -> Array<Badge> {
            let mut badges = ArrayTrait::new();
            let count = self.user_badge_count.read(user);

            let mut i = 0;
            while i !=  count {
                let badge = self.user_badges.read((user, i));
                badges.append(badge);
                i += 1;
            };

            badges
        }

        fn get_user_certificates(self: @ContractState, user: ContractAddress) -> Array<Certificate> {
            let mut certificates = ArrayTrait::new();
            let count = self.user_certificate_count.read(user);

            let mut i = 0;
            while i != count {
                let certificate = self.user_certificates.read((user, i));
                certificates.append(certificate);
                i += 1;
            };

            certificates
        }

        fn get_leaderboard(
            self: @ContractState,
            start_index: u32,
            count: u32,
        ) -> Array<LeaderboardEntry> {
            let mut entries = ArrayTrait::new();
            let total_count = self.leaderboard_count.read();
            let end_index = if start_index + count > total_count {
                total_count
            } else {
                start_index + count
            };

            let mut i = start_index;
            while i != end_index {
                let entry = self.leaderboard_entries.read(i);
                entries.append(entry);
                i += 1;
            };

            entries
        }

        fn get_user_rank(self: @ContractState, user: ContractAddress) -> u32 {
            self.user_rank.read(user)
        }

        fn set_activity_points(
            ref self: ContractState,
            activity_type: ActivityType,
            points: u32,
        ) {
            // Only owner can modify activity points
            let caller = get_caller_address();
            assert!(caller == self.owner.read(), "Only owner can set activity points");

            let activity_type_id = self._activity_type_to_id(activity_type);
            self.activity_points.write(activity_type_id, points);
        }

        fn set_owner(ref self: ContractState, new_owner: ContractAddress) {
            // Only current owner can change ownership
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can change ownership');

            let old_owner = self.owner.read();
            self.owner.write(new_owner);

            self.emit(Event::OwnerChanged(OwnerChanged {
                old_owner,
                new_owner,
            }));
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _activity_type_to_id(self: @ContractState, activity_type: ActivityType) -> u32 {
            match activity_type {
                ActivityType::AssetMinted => 0,
                ActivityType::AssetSold => 1,
                ActivityType::AssetLicensed => 2,
                ActivityType::AssetTransferred => 3,
                ActivityType::CollectionCreated => 4,
                ActivityType::CollaborationJoined => 5,
                ActivityType::InnovationAwarded => 6,
                ActivityType::CommunityContribution => 7,
                ActivityType::CustomActivity => 8,
            }
        }

        fn _activity_to_achievement_type(self: @ContractState, activity_type: ActivityType) -> AchievementType {
            match activity_type {
                ActivityType::AssetMinted => AchievementType::Mint,
                ActivityType::AssetSold => AchievementType::Sale,
                ActivityType::AssetLicensed => AchievementType::License,
                ActivityType::AssetTransferred => AchievementType::Transfer,
                ActivityType::CollectionCreated => AchievementType::Collection,
                ActivityType::CollaborationJoined => AchievementType::Collaboration,
                ActivityType::InnovationAwarded => AchievementType::Innovation,
                ActivityType::CommunityContribution => AchievementType::Community,
                ActivityType::CustomActivity => AchievementType::Custom,
            }
        }

        fn _update_leaderboard(ref self: ContractState, user: ContractAddress, new_points: u32) {
            let current_rank = self.user_rank.read(user);
            let achievements_count = self.user_activity_count.read(user);
            let badges_count = self.user_badge_count.read(user);
            let certificates_count = self.user_certificate_count.read(user);

            let entry = LeaderboardEntry {
                user,
                total_points: new_points,
                achievements_count,
                badges_count,
                certificates_count,
            };

            // Simple leaderboard update - in a production system, you might want more sophisticated ranking
            if current_rank == 0 {
                // New user, add to leaderboard
                let count = self.leaderboard_count.read();
                self.leaderboard_entries.write(count, entry);
                self.leaderboard_count.write(count + 1);
                self.user_rank.write(user, count + 1);
                self.total_users.write(self.total_users.read() + 1);
            } else {
                // Update existing entry
                self.leaderboard_entries.write(current_rank - 1, entry);
            }

            self.emit(Event::LeaderboardUpdated(LeaderboardUpdated {
                user,
                new_rank: current_rank,
                total_points: new_points,
            }));
        }
    }

}