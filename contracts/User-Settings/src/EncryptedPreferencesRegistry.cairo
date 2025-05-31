#[starknet::contract]
pub mod EncryptedPreferencesRegistry {
    use OwnableComponent::InternalTrait;
    use core::array::ArrayTrait;
    use core::hash::{HashStateExTrait, HashStateTrait};
    use core::poseidon::PoseidonTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{
        ClassHash, ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
    };
    use user_settings::interfaces::settings_interfaces::{IEncryptedPreferencesRegistry};
    use user_settings::structs::settings_structs::{
        AccountSetting, AdvancedSettings, FacebookVerification, GasPricePreference,
        IPProtectionLevel, IPSettings, NetworkSettings, NetworkType, NotificationSettings, Security,
        SocialVerification, XVerification,
    };
    // use core::ecdsa;

    const SUPPORTED_VERSION: felt252 = 1; // Update with each major change
    const TIME_WINDOW: u64 = 300; // 5 minutes

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        authorized_apps: Map::<ContractAddress, bool>,
        owner: ContractAddress,
        mediolano_app: ContractAddress,
        users_account_settings: Map::<ContractAddress, AccountSetting>,
        users_ip_settings: Map::<ContractAddress, IPSettings>,
        users_notification_settings: Map::<ContractAddress, NotificationSettings>,
        users_security_settings: Map::<ContractAddress, Security>,
        users_network_settings: Map::<ContractAddress, NetworkSettings>,
        users_advanced_settings: Map::<ContractAddress, AdvancedSettings>,
        users_social_verification: Map::<
            ContractAddress, SocialVerification,
        >, // Map::<user-address - (social media, true or false)>
        // security features
        // users_pubkeys: Map::<ContractAddress, felt252>,
        // users_nonces: Map::<ContractAddress, felt252>,
        // users_versions: Map::<ContractAddress, felt252>,
        users_last_updated: Map::<ContractAddress, u64>,
    }

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        SettingUpdated: SettingUpdated,
        SettingRemoved: SettingRemoved,
        WalletKeyUpdated: WalletKeyUpdated,
        SocialVerificationUpdated: SocialVerificationUpdated,
        AccountDeleted: AccountDeleted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SettingUpdated {
        #[key]
        pub user: ContractAddress,
        pub setting_type: felt252,
        pub timestamp: u64,
        // version: felt252
    }

    #[derive(Drop, starknet::Event)]
    pub struct SettingRemoved {
        #[key]
        pub user: ContractAddress,
        pub setting_type: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WalletKeyUpdated {
        #[key]
        pub user: ContractAddress,
        pub pub_key: felt252,
        pub version: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SocialVerificationUpdated {
        #[key]
        pub user: ContractAddress,
        pub x_verified: bool,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AccountDeleted {
        #[key]
        pub user: ContractAddress,
        pub setting: felt252,
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, mediolano_app: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.owner.write(owner);
        self.mediolano_app.write(mediolano_app);
        self.authorized_apps.entry(owner).write(true);
        self.authorized_apps.entry(mediolano_app).write(true);
        // self.users_nonces.entry(owner).write(1);
    // self.users_nonces.entry(mediolano_app).write(1);
    // self.users_versions.entry(owner).write(SUPPORTED_VERSION);
    // self.users_versions.entry(mediolano_app).write(SUPPORTED_VERSION);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            // Replace the class hash upgrading the contract
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    pub impl EncryptedPreferencesRegistryImpl of IEncryptedPreferencesRegistry<ContractState> {
        fn store_account_details(
            ref self: ContractState,
            name: felt252,
            email: felt252,
            username: felt252,
            // nonce: felt252,
            timestamp: u64,
            // version: felt252,
        // pub_key: felt252,
        // wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');

            // Verify timestamp and update state
            self
                .verify_settings_update(
                    caller,
                    timestamp //message_hash, nonce, timestamp, version, pub_key, wallet_signature
                );
            let current_timestamp = get_block_timestamp();

            let account_details = AccountSetting { name, email, username };
            self.users_account_settings.entry(caller).write(account_details);

            // Emit event
            self
                .emit(
                    Event::SettingUpdated(
                        SettingUpdated {
                            user: caller,
                            setting_type: 'account_details',
                            timestamp: current_timestamp,
                            // version: version
                        },
                    ),
                );
        }

        fn update_account_details(
            ref self: ContractState,
            name: Option<felt252>,
            email: Option<felt252>,
            username: Option<felt252>,
            // nonce: felt252,
            timestamp: u64,
            // version: felt252,
        // pub_key: felt252,
        // wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');

            let account_details = self.users_account_settings.entry(caller).read();
            let (mut account_name, mut account_email, mut account_username) = (
                name, email, username,
            );
            if !account_name.is_some() {
                account_name = Option::Some(account_details.name);
            }
            if !account_email.is_some() {
                account_email = Option::Some(account_details.email);
            }
            if !account_username.is_some() {
                account_username = Option::Some(account_details.username);
            }

            let unwrapped_name = account_name.unwrap();
            let unwrapped_email = account_email.unwrap();
            let unwrapped_username = account_username.unwrap();

            // Verify timestamp and update state
            self
                .verify_settings_update(
                    caller,
                    timestamp //message_hash, nonce, timestamp, version, pub_key, wallet_signature
                );

            let current_timestamp = get_block_timestamp();

            let new_account_info = AccountSetting {
                name: unwrapped_name, email: unwrapped_email, username: unwrapped_username,
            };
            self.users_account_settings.entry(caller).write(new_account_info);

            // Emit event
            self
                .emit(
                    Event::SettingUpdated(
                        SettingUpdated {
                            user: caller,
                            setting_type: 'account_details',
                            timestamp: current_timestamp,
                            // version: version
                        },
                    ),
                );
        }

        fn store_ip_management_settings(
            ref self: ContractState,
            protection_level: u8,
            automatic_ip_registration: bool,
            // nonce: felt252,
            timestamp: u64,
            // version: felt252,
        // pub_key: felt252,
        // wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            assert(protection_level == 1 || protection_level == 0, 'Invalid Protection Level');
            let processed_protection_level = self
                .reverse_process_ip_protection_level(protection_level)
                .unwrap();

            // Verify timestamp and update state
            self
                .verify_settings_update(
                    caller,
                    timestamp //message_hash, timestamp, nonce, timestamp, version, pub_key, wallet_signature
                );

            let current_timestamp = get_block_timestamp();

            let ip_settings = IPSettings {
                ip_protection_level: processed_protection_level, automatic_ip_registration,
            };
            self.users_ip_settings.entry(caller).write(ip_settings);

            // Emit event
            self
                .emit(
                    Event::SettingUpdated(
                        SettingUpdated {
                            user: caller, setting_type: 'ip_settings', timestamp: current_timestamp,
                            // version: version
                        },
                    ),
                );
        }

        fn update_ip_management_settings(
            ref self: ContractState,
            protection_level: Option<u8>,
            automatic_ip_registration: Option<bool>,
            // nonce: felt252,
            timestamp: u64,
            // version: felt252,
        // pub_key: felt252,
        // wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');

            let ip_settings = self.users_ip_settings.entry(caller).read();
            let (mut protection_level_current, mut auto_reg_current) = (
                protection_level, automatic_ip_registration,
            );

            if !protection_level_current.is_some() {
                protection_level_current =
                    Option::Some(self.process_ip_protection_level(ip_settings.ip_protection_level));
            }
            if !auto_reg_current.is_some() {
                auto_reg_current = Option::Some(ip_settings.automatic_ip_registration);
            }

            let unwrapped_protection = self
                .reverse_process_ip_protection_level((protection_level_current.unwrap()))
                .unwrap();
            let unwrapped_auto_reg = auto_reg_current.unwrap();

            // Verify timestamp and update state
            self
                .verify_settings_update(
                    caller,
                    timestamp // message_hash, nonce, timestamp, version, pub_key, wallet_signature
                );
            let current_timestamp = get_block_timestamp();
            let new_ip_settings = IPSettings {
                ip_protection_level: unwrapped_protection,
                automatic_ip_registration: unwrapped_auto_reg,
            };
            self.users_ip_settings.entry(caller).write(new_ip_settings);

            // Emit event
            self
                .emit(
                    Event::SettingUpdated(
                        SettingUpdated {
                            user: caller, setting_type: 'ip_settings', timestamp: current_timestamp,
                            // version: version
                        },
                    ),
                );
        }

        fn store_notification_settings(
            ref self: ContractState,
            enable_notifications: bool,
            ip_updates: bool,
            blockchain_events: bool,
            account_activity: bool,
            // nonce: felt252,
            timestamp: u64,
            // version: felt252,
        // pub_key: felt252,
        // wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');

            // Verify timestamp
            self
                .verify_settings_update(
                    caller,
                    timestamp //message_hash, nonce, timestamp, version, pub_key, wallet_signature
                );

            let notification_settings = NotificationSettings {
                enabled: enable_notifications, ip_updates, blockchain_events, account_activity,
            };
            let current_timestamp = get_block_timestamp();
            self.users_notification_settings.entry(caller).write(notification_settings);

            // Emit event
            self
                .emit(
                    Event::SettingUpdated(
                        SettingUpdated {
                            user: caller,
                            setting_type: 'notification_settings',
                            timestamp: current_timestamp,
                        },
                    ),
                );
        }

        fn update_notification_settings(
            ref self: ContractState,
            enable_notifications: Option<bool>,
            ip_updates: Option<bool>,
            blockchain_events: Option<bool>,
            account_activity: Option<bool>,
            // nonce: felt252,
            timestamp: u64,
            // version: felt252,
        // pub_key: felt252,
        // wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');

            let notification_settings = self.users_notification_settings.entry(caller).read();
            let (
                mut enabled_current,
                mut updates_current,
                mut blockchain_events_current,
                mut account_activity_current,
            ) =
                (
                enable_notifications, ip_updates, blockchain_events, account_activity,
            );

            if !enabled_current.is_some() {
                enabled_current = Option::Some(notification_settings.enabled);
            }
            if !updates_current.is_some() {
                updates_current = Option::Some(notification_settings.ip_updates);
            }
            if !blockchain_events_current.is_some() {
                blockchain_events_current = Option::Some(notification_settings.blockchain_events);
            }
            if !account_activity_current.is_some() {
                account_activity_current = Option::Some(notification_settings.account_activity);
            }

            let unwrapped_enabled = enabled_current.unwrap();
            let unwrapped_updates = updates_current.unwrap();
            let unwrapped_blockchain = blockchain_events_current.unwrap();
            let unwrapped_activity = account_activity_current.unwrap();

            // Verify timestamp and update state
            self
                .verify_settings_update(
                    caller,
                    timestamp //message_hash, nonce, timestamp, version, pub_key, wallet_signature
                );

            let new_notification_settings = NotificationSettings {
                enabled: unwrapped_enabled,
                ip_updates: unwrapped_updates,
                blockchain_events: unwrapped_blockchain,
                account_activity: unwrapped_activity,
            };
            self.users_notification_settings.entry(caller).write(new_notification_settings);

            // Emit event
            self
                .emit(
                    Event::SettingUpdated(
                        SettingUpdated {
                            user: caller,
                            setting_type: 'notification_settings',
                            timestamp: get_block_timestamp(),
                            // version: version
                        },
                    ),
                );
        }

        fn store_security_settings(ref self: ContractState, password: felt252, // nonce: felt252,
        timestamp: u64// version: felt252,
        // pub_key: felt252,
        // wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');

            let felt_caller: felt252 = caller.into();

            let hashed_password: felt252 = PoseidonTrait::new()
                .update_with(password)
                .update_with(timestamp)
                .update_with(felt_caller)
                .finalize()
                .into();

            // Verify timestamp and update state
            self
                .verify_settings_update(
                    caller,
                    timestamp // message_hash, nonce, timestamp, version, pub_key, wallet_signature
                );

            let security_settings = Security {
                password: hashed_password, two_factor_authentication: false,
            };
            self.users_security_settings.entry(caller).write(security_settings);

            // Emit event
            self
                .emit(
                    Event::SettingUpdated(
                        SettingUpdated {
                            user: caller,
                            setting_type: 'security_settings',
                            timestamp: get_block_timestamp(),
                            // version: version
                        },
                    ),
                );
        }

        fn update_security_settings(ref self: ContractState, password: felt252, // nonce: felt252,
        timestamp: u64// version: felt252,
        // pub_key: felt252,
        // wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');

            // Verify timestamp and update state
            self
                .verify_settings_update(
                    caller,
                    timestamp //message_hash, nonce, timestamp, version, pub_key, wallet_signature
                );
            let mut security_settings = self.users_security_settings.entry(caller).read();

            let felt_caller: felt252 = caller.into();

            let hashed_password = PoseidonTrait::new()
                .update_with(password)
                .update_with(felt_caller)
                .finalize();

            security_settings =
                Security {
                    password: hashed_password,
                    two_factor_authentication: security_settings.two_factor_authentication,
                };
            self.users_security_settings.entry(caller).write(security_settings);

            // Emit event
            self
                .emit(
                    Event::SettingUpdated(
                        SettingUpdated {
                            user: caller,
                            setting_type: 'security_settings',
                            timestamp: get_block_timestamp(),
                            // version: version
                        },
                    ),
                );
        }

        fn store_network_settings(
            ref self: ContractState, network_type: u8, gas_price_preference: u8, // nonce: felt252,
            timestamp: u64,
            // version: felt252,
        // pub_key: felt252,
        // wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized Caller');
            assert(network_type == 0 || network_type == 1, 'Invalid Network Type');
            assert(
                gas_price_preference == 0 || gas_price_preference == 1 || gas_price_preference == 2,
                'Invalid Gas Price Preference',
            );

            let processed_network_type = self.reverse_process_network_type(network_type).unwrap();
            let processed_gas_price_preference = self
                .reverse_process_gas_price_preference(gas_price_preference)
                .unwrap();

            // Verify timestamp and update state
            self
                .verify_settings_update(
                    caller,
                    timestamp //message_hash, nonce, timestamp, version, pub_key, wallet_signature
                );

            let network_settings = NetworkSettings {
                network_type: processed_network_type,
                gas_price_preference: processed_gas_price_preference,
            };
            self.users_network_settings.entry(caller).write(network_settings);

            // Emit event
            self
                .emit(
                    Event::SettingUpdated(
                        SettingUpdated {
                            user: caller,
                            setting_type: 'network_settings',
                            timestamp: get_block_timestamp(),
                            // version: version
                        },
                    ),
                );
        }

        fn update_network_settings(
            ref self: ContractState,
            network_type: Option<u8>,
            gas_price_preference: Option<u8>,
            // nonce: felt252,
            timestamp: u64,
            // version: felt252,
        // pub_key: felt252,
        // wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized Caller');

            let network_settings = self.users_network_settings.entry(caller).read();
            let (mut network_type_current, mut gas_price_current) = (
                network_type, gas_price_preference,
            );

            if !network_type_current.is_some() {
                network_type_current =
                    Option::Some(self.process_network_type(network_settings.network_type));
            }
            if !gas_price_current.is_some() {
                gas_price_current =
                    Option::Some(
                        self.process_gas_price_preference(network_settings.gas_price_preference),
                    );
            }

            let unwrapped_network_type = (self
                .reverse_process_network_type(network_type_current.unwrap()))
                .unwrap();
            let unwrapped_gas_price = (self
                .reverse_process_gas_price_preference(gas_price_current.unwrap()))
                .unwrap();

            // Verify timestamp and update state
            self
                .verify_settings_update(
                    caller,
                    timestamp //message_hash, nonce, timestamp, version, pub_key, wallet_signature
                );

            let new_network_settings = NetworkSettings {
                network_type: unwrapped_network_type, gas_price_preference: unwrapped_gas_price,
            };
            self.users_network_settings.entry(caller).write(new_network_settings);

            // Emit event
            self
                .emit(
                    Event::SettingUpdated(
                        SettingUpdated {
                            user: caller,
                            setting_type: 'network_settings',
                            timestamp: get_block_timestamp(),
                            // version: version
                        },
                    ),
                );
        }

        fn store_advanced_settings(ref self: ContractState, api_key: felt252, // nonce: felt252,
        timestamp: u64// version: felt252,
        // pub_key: felt252,
        // wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');

            // Verify timestamp and update state
            self
                .verify_settings_update(
                    caller,
                    timestamp //message_hash, nonce, timestamp, version, pub_key, wallet_signature
                );

            let mut advanced_settings = self.users_advanced_settings.entry(caller).read();

            advanced_settings =
                AdvancedSettings { api_key, data_retention: advanced_settings.data_retention };
            self.users_advanced_settings.entry(caller).write(advanced_settings);

            // Emit event
            self
                .emit(
                    Event::SettingUpdated(
                        SettingUpdated {
                            user: caller,
                            setting_type: 'advanced_settings',
                            timestamp: get_block_timestamp(),
                            // version: version
                        },
                    ),
                );
        }

        // New function for X verification
        fn store_X_verification(
            ref self: ContractState, x_verified: bool, // nonce: felt252,
            timestamp: u64, // version: felt252,
            // pub_key: felt252,
            // wallet_signature: Array<felt252>,
            handler: felt252,
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');

            // Verify timestamp and update state
            self
                .verify_settings_update(
                    caller,
                    timestamp //message_hash, nonce, timestamp, version, pub_key, wallet_signature
                );

            let current_users_social_verification = self
                .users_social_verification
                .entry(caller)
                .read();

            let x_verication = XVerification { is_verified: true, handler, user_address: caller };

            let social_verification = SocialVerification {
                x_verification_status: x_verication,
                facebook_verification_status: current_users_social_verification
                    .facebook_verification_status,
            };
            self.users_social_verification.entry(caller).write(social_verification);

            // Emit event
            self
                .emit(
                    Event::SocialVerificationUpdated(
                        SocialVerificationUpdated {
                            user: caller, x_verified: x_verified, timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn regenerate_api_key(ref self: ContractState, // nonce: felt252,
        timestamp: u64// version: felt252,
        // pub_key: felt252,
        // wallet_signature: Array<felt252>
        ) -> felt252 {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');

            // Verify timestamp validity
            self.verify_settings_update(caller, timestamp);

            // Read current advanced settings
            let mut advanced_settings = self.users_advanced_settings.entry(caller).read();

            // Generate new API key using Poseidon hash
            let mut hasher = PoseidonTrait::new();
            hasher = hasher.update(caller.into()); // Caller address
            hasher = hasher.update(timestamp.into()); // Current timestamp
            hasher = hasher.update(advanced_settings.api_key); // Previous API key for uniqueness
            let new_api_key = hasher.finalize();

            // Update advanced settings with new API key
            advanced_settings.api_key = new_api_key;
            self.users_advanced_settings.entry(caller).write(advanced_settings);

            // Emit event
            self
                .emit(
                    Event::SettingUpdated(
                        SettingUpdated {
                            user: caller,
                            setting_type: 'advanced_settings',
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );

            // Return new API key
            new_api_key
        }

        fn delete_account(ref self: ContractState, // nonce: felt252,
        timestamp: u64// version: felt252,
        // pub_key: felt252,
        // wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');

            // Verify timestamp and update state
            self
                .verify_settings_update(
                    caller,
                    timestamp //message_hash, nonce, timestamp, version, pub_key, wallet_signature
                );

            let current_timestamp = get_block_timestamp();
            // Reset all user settings (we're not actually deleting from storage since that's not
            // possible)
            // But we can reset everything to default values
            self.users_account_settings.entry(caller).write(Default::default());
            self.users_notification_settings.entry(caller).write(Default::default());
            self.users_ip_settings.entry(caller).write(Default::default());
            self.users_security_settings.entry(caller).write(Default::default());
            self.users_advanced_settings.entry(caller).write(Default::default());
            self.users_network_settings.entry(caller).write(Default::default());
            let zero_address = contract_address_const::<0>();
            let x_verification = XVerification {
                is_verified: false, handler: 0, user_address: zero_address,
            };
            let facebook_verification = FacebookVerification {
                is_verified: false, handler: 0, user_address: zero_address,
            };
            let social_verification = SocialVerification {
                x_verification_status: x_verification,
                facebook_verification_status: facebook_verification,
            };
            self.users_social_verification.entry(caller).write(social_verification);

            // Emit events for account deletion
            self
                .emit(
                    Event::AccountDeleted(
                        AccountDeleted {
                            user: caller, setting: 'account_deleted', timestamp: current_timestamp,
                        },
                    ),
                )
        }

        // READ FUNCTIONS
        fn get_account_settings(self: @ContractState, user: ContractAddress) -> AccountSetting {
            self.users_account_settings.entry(user).read()
        }

        fn get_network_settings(self: @ContractState, user: ContractAddress) -> NetworkSettings {
            self.users_network_settings.entry(user).read()
        }

        fn get_ip_settings(self: @ContractState, user: ContractAddress) -> IPSettings {
            self.users_ip_settings.entry(user).read()
        }

        fn get_notification_settings(
            self: @ContractState, user: ContractAddress,
        ) -> NotificationSettings {
            self.users_notification_settings.entry(user).read()
        }

        fn get_security_settings(self: @ContractState, user: ContractAddress) -> Security {
            self.users_security_settings.entry(user).read()
        }

        fn get_advanced_settings(self: @ContractState, user: ContractAddress) -> AdvancedSettings {
            self.users_advanced_settings.entry(user).read()
        }

        // New getter for social verification
        fn get_social_verification(
            self: @ContractState, user: ContractAddress,
        ) -> SocialVerification {
            self.users_social_verification.entry(user).read()
        }
    }

    #[generate_trait]
    pub impl InternalFunctions of InternalFunctionsTrait {
        fn assert_authorized(self: @ContractState, caller: ContractAddress) -> bool {
            self.authorized_apps.entry(caller).read()
        }

        fn verify_settings_update(
            ref self: ContractState, caller: ContractAddress, // message_hash: felt252,
            // nonce: felt252,
            timestamp: u64,
            // version: felt252,
        // pub_key: felt252,
        // wallet_signature: Array<felt252>
        ) {
            let current_time = get_block_timestamp();
            assert(
                timestamp <= current_time + TIME_WINDOW && timestamp >= current_time - TIME_WINDOW,
                'Invalid timestamp',
            );
            self.users_last_updated.entry(caller).write(timestamp);
        }

        // Hashing functions for message signing
        fn hash_account_details(
            self: @ContractState, name: felt252, email: felt252, username: felt252, // nonce: felt252,
            timestamp: u64,
            // version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            let processed_timestamp: felt252 = timestamp.try_into().unwrap();
            hash_state = hash_state.update_with(name);
            hash_state = hash_state.update_with(email);
            hash_state = hash_state.update_with(username);
            // hash_state = hash_state.update_with(nonce);
            hash_state = hash_state.update_with(processed_timestamp);
            // hash_state = hash_state.update_with(version);
            hash_state.finalize()
        }

        fn hash_ip_settings(
            self: @ContractState,
            protection_level: u8,
            automatic_ip_registration: bool,
            // nonce: felt252,
            timestamp: u64,
            // version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            assert(protection_level == 1 || protection_level == 0, 'Invalid Protection Level');
            hash_state = hash_state.update(protection_level.into());
            hash_state = hash_state.update(if automatic_ip_registration {
                1
            } else {
                0
            });
            // hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            // hash_state = hash_state.update(version);
            hash_state.finalize()
        }

        fn hash_notification_settings(
            self: @ContractState,
            enable_notifications: bool,
            ip_updates: bool,
            blockchain_events: bool,
            account_activity: bool,
            // nonce: felt252,
            timestamp: u64,
            // version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            hash_state = hash_state.update(if enable_notifications {
                1
            } else {
                0
            });
            hash_state = hash_state.update(if ip_updates {
                1
            } else {
                0
            });
            hash_state = hash_state.update(if blockchain_events {
                1
            } else {
                0
            });
            hash_state = hash_state.update(if account_activity {
                1
            } else {
                0
            });
            // hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            // hash_state = hash_state.update(version);
            hash_state.finalize()
        }

        fn hash_security_settings(
            self: @ContractState, password: felt252, // nonce: felt252,
            timestamp: u64,
            // version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            hash_state = hash_state.update(password);
            // hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            // hash_state = hash_state.update(version);
            hash_state.finalize()
        }

        fn hash_network_settings(
            self: @ContractState, network_type: u8, gas_price_preference: u8, // nonce: felt252,
            timestamp: u64,
            // version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            assert(network_type == 1 || network_type == 0, 'Invalid Network Type');
            assert(
                gas_price_preference == 1 || gas_price_preference == 0 || gas_price_preference == 2,
                'Invalid Network Type',
            );
            let mut processed_network_type = NetworkType::TESTNET;
            if network_type == 1 {
                processed_network_type = NetworkType::MAINNET;
            }
            let mut processed_gas_price_preference = GasPricePreference::MEDIUM;
            if gas_price_preference == 0 {
                processed_gas_price_preference = GasPricePreference::LOW
            }
            if gas_price_preference == 2 {
                processed_gas_price_preference = GasPricePreference::HIGH;
            }
            hash_state = hash_state.update(network_type.into());
            hash_state = hash_state.update(gas_price_preference.into());
            // hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            // hash_state = hash_state.update(version);
            hash_state.finalize()
        }

        fn hash_advanced_settings(
            self: @ContractState, api_key: felt252, // nonce: felt252,
            timestamp: u64,
            // version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            hash_state = hash_state.update(api_key);
            // hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            // hash_state = hash_state.update(version);
            hash_state.finalize()
        }

        fn hash_social_verification(
            self: @ContractState, x_verified: bool, // nonce: felt252,
            timestamp: u64,
            // version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            hash_state = hash_state.update(if x_verified {
                1
            } else {
                0
            });
            // hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            // hash_state = hash_state.update(version);
            hash_state.finalize()
        }

        fn hash_wallet_update(
            self: @ContractState, new_pub_key: felt252, // nonce: felt252,
            timestamp: u64,
            // version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            hash_state = hash_state.update(new_pub_key);
            // hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            // hash_state = hash_state.update(version);
            hash_state.finalize()
        }

        fn hash_api_key_regeneration(self: @ContractState, // nonce: felt252,
        timestamp: u64// version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            hash_state = hash_state.update('regenerate_api');
            // hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            // hash_state = hash_state.update(version);
            hash_state.finalize()
        }

        fn hash_account_deletion(self: @ContractState, // nonce: felt252,
        timestamp: u64// version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            hash_state = hash_state.update('delete_account');
            // hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            // hash_state = hash_state.update(version);
            hash_state.finalize()
        }

        fn process_network_type(self: @ContractState, network_type: NetworkType) -> u8 {
            match network_type {
                NetworkType::TESTNET => { 0 },
                NetworkType::MAINNET => { 1 },
            }
        }

        fn reverse_process_network_type(
            self: @ContractState, network_type_ref: u8,
        ) -> Option<NetworkType> {
            match network_type_ref {
                0 => { Option::Some(NetworkType::TESTNET) },
                1 => { Option::Some(NetworkType::MAINNET) },
                _ => { Option::None },
            }
        }

        fn process_gas_price_preference(
            self: @ContractState, gas_price_preference: GasPricePreference,
        ) -> u8 {
            match gas_price_preference {
                GasPricePreference::LOW => { 0 },
                GasPricePreference::MEDIUM => { 1 },
                GasPricePreference::HIGH => { 2 },
            }
        }

        fn reverse_process_gas_price_preference(
            self: @ContractState, gas_price_preference_ref: u8,
        ) -> Option<GasPricePreference> {
            match gas_price_preference_ref {
                0 => { Option::Some(GasPricePreference::LOW) },
                1 => { Option::Some(GasPricePreference::MEDIUM) },
                2 => { Option::Some(GasPricePreference::HIGH) },
                _ => { Option::None },
            }
        }

        fn process_ip_protection_level(
            self: @ContractState, ip_protection_level: IPProtectionLevel,
        ) -> u8 {
            match ip_protection_level {
                IPProtectionLevel::STANDARD => { 0 },
                IPProtectionLevel::ADVANCED => { 1 },
            }
        }

        fn reverse_process_ip_protection_level(
            self: @ContractState, ip_protection_level_ref: u8,
        ) -> Option<IPProtectionLevel> {
            match ip_protection_level_ref {
                0 => { Option::Some(IPProtectionLevel::STANDARD) },
                1 => { Option::Some(IPProtectionLevel::ADVANCED) },
                _ => { Option::None },
            }
        }
    }
}
