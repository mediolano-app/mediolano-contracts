#[starknet::contract]
pub mod EncryptedPreferencesRegistry {
    use OwnableComponent::InternalTrait;
use starknet::{ContractAddress, get_caller_address, get_block_timestamp, ClassHash};
    use core::array::ArrayTrait;
    use contract::structs::settings_structs::{
        AccountSetting, IPProtectionLevel, IPSettings, NotificationSettings, Security, NetworkSettings, AdvancedSettings, NetworkType,
        GasPricePreference, SocialVerification, XVerification
    };
    use contract::interfaces::settings_interfaces::{IEncryptedPreferencesRegistry};
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use core::poseidon::PoseidonTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::ecdsa;

    const SUPPORTED_VERSION: felt252 = 0x1; // Update with each major change
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
        users_social_verification: Map::<ContractAddress, SocialVerification>, // Map::<user-address - (social media, true or false)>
        // security features
        users_pubkeys: Map::<ContractAddress, felt252>,
        users_nonces: Map::<ContractAddress, felt252>,
        users_versions: Map::<ContractAddress, felt252>,
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
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        SettingUpdated: SettingUpdated,
        SettingRemoved: SettingRemoved,
        WalletKeyUpdated: WalletKeyUpdated,
        SocialVerificationUpdated: SocialVerificationUpdated
    }

    #[derive(Drop, starknet::Event)]
    struct SettingUpdated {
        #[key]
        user: ContractAddress,
        setting_type: felt252,
        version: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct SettingRemoved {
        #[key]
        user: ContractAddress,
        setting_type: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct WalletKeyUpdated {
        #[key]
        user: ContractAddress,
        pub_key: felt252,
        version: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct SocialVerificationUpdated {
        #[key]
        user: ContractAddress,
        x_verified: bool
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        owner: ContractAddress,
        mediolano_app: ContractAddress
    ) {
        self.ownable.initializer(owner);
        self.owner.write(owner);
        self.mediolano_app.write(mediolano_app);
        self.authorized_apps.write(mediolano_app, true);
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
            nonce: felt252,
            timestamp: u64, 
            version: felt252,
            pub_key: felt252,
            wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            
            // Hash the account details to create a message hash
            let message_hash = self.hash_account_details(name, email, username, nonce, timestamp, version);
            
            // Verify signature and update security state
            self.verify_settings_update(
                caller, message_hash, nonce, timestamp, version, pub_key, wallet_signature
            );
            
            let account_details = AccountSetting {
                name, 
                email,
                username
            };
            self.users_account_settings.entry(caller).write(account_details);
            
            // Emit event
            self.emit(Event::SettingUpdated(
                SettingUpdated { 
                    user: caller, 
                    setting_type: 'account_details', 
                    version: version 
                }
            ));
        }

        fn update_account_details(
            ref self: ContractState, 
            name: Option<felt252>, 
            email: Option<felt252>, 
            username: Option<felt252>,
            nonce: felt252,
            timestamp: u64, 
            version: felt252,
            pub_key: felt252,
            wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            
            let account_details = self.users_account_settings.entry(caller).read();
            let (mut account_name, mut account_email, mut account_username) = (
                name, email, username
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
            
            // Hash the updated account details for message hash
            let message_hash = self.hash_account_details(
                unwrapped_name, 
                unwrapped_email, 
                unwrapped_username, 
                nonce, 
                timestamp, 
                version
            );
            
            // Verify signature and update security state
            self.verify_settings_update(
                caller, message_hash, nonce, timestamp, version, pub_key, wallet_signature
            );
            
            let new_account_info = AccountSetting {
                name: unwrapped_name,
                email: unwrapped_email,
                username: unwrapped_username
            };
            self.users_account_settings.entry(caller).write(new_account_info);
            
            // Emit event
            self.emit(Event::SettingUpdated(
                SettingUpdated { 
                    user: caller, 
                    setting_type: 'account_details', 
                    version: version 
                }
            ));
        }
        
        fn store_ip_management_settings(
            ref self: ContractState, 
            protection_level: u8, 
            automatic_ip_registration: bool,
            nonce: felt252,
            timestamp: u64, 
            version: felt252,
            pub_key: felt252,
            wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            assert(protection_level == 1 || protection_level == 0, 'Invalid Protection Level');
            let processed_protection_level = self.reverse_process_ip_protection_level(protection_level).unwrap();
            
            // Hash the IP settings for message hash
            let message_hash = self.hash_ip_settings(
                protection_level, automatic_ip_registration, nonce, timestamp, version
            );
            
            // Verify signature and update security state
            self.verify_settings_update(
                caller, message_hash, nonce, timestamp, version, pub_key, wallet_signature
            );
            
            let ip_settings = IPSettings {
                ip_protection_level: processed_protection_level,
                automatic_ip_registration
            };
            self.users_ip_settings.entry(caller).write(ip_settings);
            
            // Emit event
            self.emit(Event::SettingUpdated(
                SettingUpdated { 
                    user: caller, 
                    setting_type: 'ip_settings', 
                    version: version 
                }
            ));
        }

        fn update_ip_management_settings(
            ref self: ContractState, 
            protection_level: Option<IPProtectionLevel>, 
            automatic_ip_registration: Option<bool>,
            nonce: felt252,
            timestamp: u64, 
            version: felt252,
            pub_key: felt252,
            wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            
            let ip_settings = self.users_ip_settings.entry(caller).read();
            let (mut protection_level_current, mut auto_reg_current) = (
                protection_level, automatic_ip_registration
            );
            
            if !protection_level_current.is_some() {
                protection_level_current = Option::Some(ip_settings.ip_protection_level);
            }
            if !auto_reg_current.is_some() {
                auto_reg_current = Option::Some(ip_settings.automatic_ip_registration);
            }
            
            let unwrapped_protection = protection_level_current.unwrap();
            let unwrapped_auto_reg = auto_reg_current.unwrap();

            let mut processed_unwrapped_protection = 0;

            if unwrapped_protection == IPProtectionLevel::STANDARD {
                processed_unwrapped_protection = 1
            }
            
            // Hash the updated IP settings for message hash
            let message_hash = self.hash_ip_settings(
                processed_unwrapped_protection, unwrapped_auto_reg, nonce, timestamp, version
            );
            
            // Verify signature and update security state
            self.verify_settings_update(
                caller, message_hash, nonce, timestamp, version, pub_key, wallet_signature
            );
            
            let new_ip_settings = IPSettings {
                ip_protection_level: unwrapped_protection,
                automatic_ip_registration: unwrapped_auto_reg
            };
            self.users_ip_settings.entry(caller).write(new_ip_settings);
            
            // Emit event
            self.emit(Event::SettingUpdated(
                SettingUpdated { 
                    user: caller, 
                    setting_type: 'ip_settings', 
                    version: version 
                }
            ));
        }

        fn store_notification_settings(
            ref self: ContractState, 
            enable_notifications: bool, 
            ip_updates: bool, 
            blockchain_events: bool, 
            account_activity: bool,
            nonce: felt252,
            timestamp: u64, 
            version: felt252,
            pub_key: felt252,
            wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            
            // Hash the notification settings for message hash
            let message_hash = self.hash_notification_settings(
                enable_notifications, ip_updates, blockchain_events, account_activity,
                nonce, timestamp, version
            );
            
            // Verify signature and update security state
            self.verify_settings_update(
                caller, message_hash, nonce, timestamp, version, pub_key, wallet_signature
            );
            
            let notification_settings = NotificationSettings {
                enabled: enable_notifications,
                ip_updates,
                blockchain_events,
                account_activity
            };
            self.users_notification_settings.entry(caller).write(notification_settings);
            
            // Emit event
            self.emit(Event::SettingUpdated(
                SettingUpdated { 
                    user: caller, 
                    setting_type: 'notification_settings', 
                    version: version 
                }
            ));
        }

        fn update_notification_settings(
            ref self: ContractState, 
            enable_notifications: Option<bool>,
            ip_updates: Option<bool>, 
            blockchain_events: Option<bool>, 
            account_activity: Option<bool>,
            nonce: felt252,
            timestamp: u64, 
            version: felt252,
            pub_key: felt252,
            wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            
            let notification_settings = self.users_notification_settings.entry(caller).read();
            let (mut enabled_current, mut updates_current, mut blockchain_events_current, mut account_activity_current) = (
                enable_notifications, ip_updates, blockchain_events, account_activity
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
            
            // Hash the updated notification settings for message hash
            let message_hash = self.hash_notification_settings(
                unwrapped_enabled, unwrapped_updates, unwrapped_blockchain, unwrapped_activity,
                nonce, timestamp, version
            );
            
            // Verify signature and update security state
            self.verify_settings_update(
                caller, message_hash, nonce, timestamp, version, pub_key, wallet_signature
            );
            
            let new_notification_settings = NotificationSettings {
                enabled: unwrapped_enabled,
                ip_updates: unwrapped_updates,
                blockchain_events: unwrapped_blockchain,
                account_activity: unwrapped_activity
            };
            self.users_notification_settings.entry(caller).write(new_notification_settings);
            
            // Emit event
            self.emit(Event::SettingUpdated(
                SettingUpdated { 
                    user: caller, 
                    setting_type: 'notification_settings', 
                    version: version 
                }
            ));
        }

        fn store_security_settings(
            ref self: ContractState, 
            password: felt252,
            nonce: felt252,
            timestamp: u64, 
            version: felt252,
            pub_key: felt252,
            wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');

            let felt_caller: felt252 = caller.into();
            
            let hashed_password = PoseidonTrait::new().update_with(password).update_with(felt_caller).finalize();

            // Hash the security settings for message hash
            let message_hash = self.hash_security_settings(hashed_password, nonce, timestamp, version);
            
            // Verify signature and update security state
            self.verify_settings_update(
                caller, message_hash, nonce, timestamp, version, pub_key, wallet_signature
            );
            
            let security_settings = Security {
                password: hashed_password,
                two_factor_authentication: false
            };
            self.users_security_settings.entry(caller).write(security_settings);
            
            // Emit event
            self.emit(Event::SettingUpdated(
                SettingUpdated { 
                    user: caller, 
                    setting_type: 'security_settings', 
                    version: version 
                }
            ));
        }

        fn update_security_settings(
            ref self: ContractState, 
            password: felt252,
            nonce: felt252,
            timestamp: u64, 
            version: felt252,
            pub_key: felt252,
            wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            
            // Hash the security settings for message hash
            let message_hash = self.hash_security_settings(password, nonce, timestamp, version);
            
            // Verify signature and update security state
            self.verify_settings_update(
                caller, message_hash, nonce, timestamp, version, pub_key, wallet_signature
            );
            let mut security_settings = self.users_security_settings.entry(caller).read();
            
            security_settings = Security {
                password,
                two_factor_authentication: security_settings.two_factor_authentication
            };
            self.users_security_settings.entry(caller).write(security_settings);
            
            // Emit event
            self.emit(Event::SettingUpdated(
                SettingUpdated { 
                    user: caller, 
                    setting_type: 'security_settings', 
                    version: version 
                }
            ));
        }

        fn store_network_settings(
            ref self: ContractState, 
            network_type: u8, 
            gas_price_preference: u8,
            nonce: felt252,
            timestamp: u64, 
            version: felt252,
            pub_key: felt252,
            wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized Caller');
            assert(network_type == 0 || network_type == 1, 'Invalid Network Type');
            assert(gas_price_preference == 0 || gas_price_preference == 1 || gas_price_preference == 2, 'Invalid Gas Price Preference');

            let processed_network_type = self.reverse_process_network_type(network_type).unwrap();
            let processed_gas_price_preference = self.reverse_process_gas_price_preference(gas_price_preference).unwrap();
            
            // Hash the network settings for message hash
            let message_hash = self.hash_network_settings(
                network_type, gas_price_preference, nonce, timestamp, version
            );
            
            // Verify signature and update security state
            self.verify_settings_update(
                caller, message_hash, nonce, timestamp, version, pub_key, wallet_signature
            );
            
            let network_settings = NetworkSettings {
                network_type: processed_network_type,
                gas_price_preference: processed_gas_price_preference
            };
            self.users_network_settings.entry(caller).write(network_settings);
            
            // Emit event
            self.emit(Event::SettingUpdated(
                SettingUpdated { 
                    user: caller, 
                    setting_type: 'network_settings', 
                    version: version 
                }
            ));
        }

        fn update_network_settings(
            ref self: ContractState, 
            network_type: Option<NetworkType>, 
            gas_price_preference: Option<GasPricePreference>,
            nonce: felt252,
            timestamp: u64, 
            version: felt252,
            pub_key: felt252,
            wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized Caller');
            
            let network_settings = self.users_network_settings.entry(caller).read();
            let (mut network_type_current, mut gas_price_current) = (
                network_type, gas_price_preference
            );
            
            if !network_type_current.is_some() {
                network_type_current = Option::Some(network_settings.network_type);
            }
            if !gas_price_current.is_some() {
                gas_price_current = Option::Some(network_settings.gas_price_preference);
            }
            
            let unwrapped_network_type = self.process_network_type(network_type_current.unwrap());
            let unwrapped_gas_price = self.process_gas_price_preference(gas_price_current.unwrap());
            
            // Hash the updated network settings for message hash
            let message_hash = self.hash_network_settings(
                unwrapped_network_type, unwrapped_gas_price, nonce, timestamp, version
            );
            
            // Verify signature and update security state
            self.verify_settings_update(
                caller, message_hash, nonce, timestamp, version, pub_key, wallet_signature
            );
            
            let new_network_settings = NetworkSettings {
                network_type: network_type_current.unwrap(),
                gas_price_preference: gas_price_current.unwrap()
            };
            self.users_network_settings.entry(caller).write(new_network_settings);
            
            // Emit event
            self.emit(Event::SettingUpdated(
                SettingUpdated { 
                    user: caller, 
                    setting_type: 'network_settings', 
                    version: version 
                }
            ));
        }

        fn store_advanced_settings(
            ref self: ContractState, 
            api_key: felt252,
            nonce: felt252,
            timestamp: u64, 
            version: felt252,
            pub_key: felt252,
            wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            
            // Hash the advanced settings for message hash
            let message_hash = self.hash_advanced_settings(api_key, nonce, timestamp, version);
            
            // Verify signature and update security state
            self.verify_settings_update(
                caller, message_hash, nonce, timestamp, version, pub_key, wallet_signature
            );

            let mut advanced_settings = self.users_advanced_settings.entry(caller).read();
            
            advanced_settings = AdvancedSettings {
                api_key,
                data_retention: advanced_settings.data_retention
            };
            self.users_advanced_settings.entry(caller).write(advanced_settings);
            
            // Emit event
            self.emit(Event::SettingUpdated(
                SettingUpdated { 
                    user: caller, 
                    setting_type: 'advanced_settings', 
                    version: version 
                }
            ));
        }

        // New function for X verification
        fn store_X_verification(
            ref self: ContractState,
            x_verified: bool,
            nonce: felt252,
            timestamp: u64,
            version: felt252,
            pub_key: felt252,
            wallet_signature: Array<felt252>,
            handler: felt252
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            
            // Hash the social verification settings for message hash
            let message_hash = self.hash_social_verification(x_verified, nonce, timestamp, version);
            
            // Verify signature and update security state
            self.verify_settings_update(
                caller, message_hash, nonce, timestamp, version, pub_key, wallet_signature
            );

            let current_users_social_verification = self.users_social_verification.entry(caller).read();

            let x_verication = XVerification {
                is_verified: true,
                handler,
                user_address: caller
            };
            
            let social_verification = SocialVerification {
                x_verification_status: x_verication,
                facebook_verification_status: current_users_social_verification.facebook_verification_status,
            };
            self.users_social_verification.entry(caller).write(social_verification);
            
            // Emit event
            self.emit(Event::SocialVerificationUpdated(
                SocialVerificationUpdated { 
                    user: caller, 
                    x_verified: x_verified
                }
            ));
        }

        fn update_wallet_key(
            ref self: ContractState,
            new_pub_key: felt252,
            nonce: felt252,
            timestamp: u64,
            version: felt252,
            current_pub_key: felt252,
            wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            
            // Hash the wallet key update for message hash
            let message_hash = self.hash_wallet_update(
                new_pub_key, nonce, timestamp, version
            );
            
            // Verify signature with current public key
            self.verify_settings_update(
                caller, message_hash, nonce, timestamp, version, current_pub_key, wallet_signature
            );
            
            // Update user's public key
            self.users_pubkeys.write(caller, new_pub_key);
            
            // Emit event
            self.emit(Event::WalletKeyUpdated(
                WalletKeyUpdated { 
                    user: caller, 
                    pub_key: new_pub_key, 
                    version: version 
                }
            ));
        }

        fn regenerate_api_key(
            ref self: ContractState,
            nonce: felt252,
            timestamp: u64,
            version: felt252,
            pub_key: felt252,
            wallet_signature: Array<felt252>
        ) -> felt252 {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            
            // Hash the api key regeneration request for message hash
            let message_hash = self.hash_api_key_regeneration(nonce, timestamp, version);
            
            // Verify signature and update security state
            self.verify_settings_update(
                caller, message_hash, nonce, timestamp, version, pub_key, wallet_signature
            );

            let numerical_nonce: u64 = nonce.try_into().unwrap();
            let numerical_version: u64 = version.try_into().unwrap();
            
            // Generate a new API key (this is simplified - should use proper randomness)
            let new_api_key = timestamp ^ numerical_nonce ^ numerical_version;

            let felt_api_key: felt252 = new_api_key.into();
            
            // Store the new API key
            let mut advanced_settings = self.users_advanced_settings.entry(caller).read();
            advanced_settings = AdvancedSettings {
                api_key: felt_api_key,
                data_retention: advanced_settings.data_retention
            };
            self.users_advanced_settings.entry(caller).write(advanced_settings);
            
            // Emit event
            self.emit(Event::SettingUpdated(
                SettingUpdated { 
                    user: caller, 
                    setting_type: 'advanced_settings', 
                    version: version 
                }
            ));
            
            new_api_key.into()
        }

        fn delete_account(
            ref self: ContractState,
            nonce: felt252,
            timestamp: u64,
            version: felt252,
            pub_key: felt252,
            wallet_signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            
            // Hash the account deletion request for message hash
            let message_hash = self.hash_account_deletion(nonce, timestamp, version);
            
            // Verify signature and update security state
            self.verify_settings_update(
                caller, message_hash, nonce, timestamp, version, pub_key, wallet_signature
            );
            
            // Reset all user settings (we're not actually deleting from storage since that's not possible)
            // But we can reset everything to default values
            
            // Emit events for all settings being removed
            self.emit(Event::SettingRemoved(SettingRemoved { user: caller, setting_type: 'account_details' }));
            self.emit(Event::SettingRemoved(SettingRemoved { user: caller, setting_type: 'ip_settings' }));
            self.emit(Event::SettingRemoved(SettingRemoved { user: caller, setting_type: 'notification_settings' }));
            self.emit(Event::SettingRemoved(SettingRemoved { user: caller, setting_type: 'security_settings' }));
            self.emit(Event::SettingRemoved(SettingRemoved { user: caller, setting_type: 'network_settings' }));
            self.emit(Event::SettingRemoved(SettingRemoved { user: caller, setting_type: 'advanced_settings' }));
            self.emit(Event::SettingRemoved(SettingRemoved { user: caller, setting_type: 'social_verification' }));
        }

        // READ FUNCTIONS
        fn get_account_settings(self: @ContractState) -> AccountSetting {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            self.users_account_settings.entry(caller).read()
        }

        fn get_network_settings(self: @ContractState) -> NetworkSettings {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            self.users_network_settings.entry(caller).read()
        }

        fn get_ip_settings(self: @ContractState) -> IPSettings {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            self.users_ip_settings.entry(caller).read()
        }

        fn get_notification_settings(self: @ContractState) -> NotificationSettings {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            self.users_notification_settings.entry(caller).read()
        }

        fn get_security_settings(self: @ContractState) -> Security {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            self.users_security_settings.entry(caller).read()
        }

        fn get_advanced_settings(self: @ContractState) -> AdvancedSettings {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            self.users_advanced_settings.entry(caller).read()
        }

        // New getter for social verification
        fn get_social_verification(self: @ContractState) -> SocialVerification {
            let caller = get_caller_address();
            assert(self.assert_authorized(caller), 'Unauthorized caller');
            self.users_social_verification.entry(caller).read()
        }

        // Added getter for user's public key
        fn get_public_key(self: @ContractState) -> felt252 {
            let caller = get_caller_address();
            self.users_pubkeys.read(caller)
        }

        // Added getter for user's nonce
        fn get_nonce(self: @ContractState) -> felt252 {
            let caller = get_caller_address();
            self.users_nonces.read(caller)
        }
    }

    #[generate_trait]
    pub impl InternalFunctions of InternalFunctionsTrait {
        fn assert_authorized(self: @ContractState, caller: ContractAddress) -> bool {
            self.authorized_apps.entry(caller).read()
        }

        // fn verify_settings_update(
        //     self: @ContractState,
        //     caller: ContractAddress,
        //     message_hash: felt252,
        //     nonce: felt252,
        //     timestamp: u64,
        //     version: felt252,
        //     pub_key: felt252,
        //     wallet_signature: Array<felt252>
        // ) {
        //         let current_time = starknet::get_block_timestamp();
        //     assert(
        //         timestamp <= current_time + TIME_WINDOW && 
        //         timestamp >= current_time - TIME_WINDOW,
        //         'Invalid timestamp'
        //     );

        //     // 2. Validate nonce
        //     let stored_nonce = self.users_nonces.read(caller);
        //     assert(nonce == stored_nonce + 1, 'Invalid nonce');
        //     self.users_nonces.write(caller, nonce);

        //     // 3. Validate version
        //     assert(version == SUPPORTED_VERSION, 'Unsupported version');

        //     // 4. Validate public key consistency
        //     let stored_pubkey = self.users_pubkeys.read(caller);
        //     if stored_pubkey == 0 {
        //         // First interaction - store pubkey
        //         self.users_pubkeys.write(caller, pub_key);
        //     } else {
        //         assert(stored_pubkey == pub_key, 'Public key changed');
        //     }

        //     // 5. Validate signature
        //     assert(wallet_signature.len() == 2, 'Invalid signature format');
        //     let sig_r = *wallet_signature.at(0);
        //     let sig_s = *wallet_signature.at(1);
            
        //     let is_valid = ecdsa::check_ecdsa_signature(
        //         sig_r,
        //         sig_s,
        //         pub_key,
        //         message_hash
        //     );
        //     assert(is_valid, 'Invalid signature');
        // }

        fn verify_settings_update(
            ref self: ContractState,
            caller: ContractAddress,
            message_hash: felt252,
            nonce: felt252,
            timestamp: u64,
            version: felt252,
            pub_key: felt252,
            wallet_signature: Array<felt252>
        ) {
            let current_time = get_block_timestamp();
            
            // 1. Validate timestamp is within TIME_WINDOW
            assert(
                timestamp <= current_time + TIME_WINDOW && 
                timestamp >= current_time - TIME_WINDOW,
                'Invalid timestamp'
            );

            // 2. Validate nonce is sequential
            let stored_nonce = self.users_nonces.entry(caller).read();
            assert(nonce == stored_nonce + 1, 'Invalid nonce');
            self.users_nonces.entry(caller).write(nonce);

            // 3. Validate version matches supported version
            assert(version == SUPPORTED_VERSION, 'Unsupported version');

            // 4. Validate public key consistency
            let stored_pubkey = self.users_pubkeys.read(caller);
            if stored_pubkey == 0 {
                // First interaction - store pubkey
                self.users_pubkeys.entry(caller).write(pub_key);
            } else {
                assert(stored_pubkey == pub_key, 'Public key changed');
            }

            // 5. Validate signature
            assert(wallet_signature.len() == 2, 'Invalid signature format');
            let sig_r = *wallet_signature.at(0);
            let sig_s = *wallet_signature.at(1);
            
            let is_valid = ecdsa::check_ecdsa_signature(
                message_hash,
                pub_key,
                sig_r,
                sig_s
            );
            assert(is_valid, 'Invalid signature');
            
            // 6. Update the user's version and last updated timestamp
            self.users_versions.entry(caller).write(version);
            self.users_last_updated.entry(caller).write(timestamp);
        }

         // Hashing functions for message signing
         fn hash_account_details(
            self: @ContractState,
            name: felt252,
            email: felt252,
            username: felt252,
            nonce: felt252,
            timestamp: u64,
            version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            let processed_timestamp: felt252 = timestamp.try_into().unwrap();
            hash_state = hash_state.update_with(name);
            hash_state = hash_state.update_with(email);
            hash_state = hash_state.update_with(username);
            hash_state = hash_state.update_with(nonce);
            hash_state = hash_state.update_with(processed_timestamp);
            hash_state = hash_state.update_with(version);
            hash_state.finalize()
        }
        
        fn hash_ip_settings(
            self: @ContractState,
            protection_level: u8,
            automatic_ip_registration: bool,
            nonce: felt252,
            timestamp: u64,
            version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            assert(protection_level == 1 || protection_level == 0, 'Invalid Protection Level');
            hash_state = hash_state.update(protection_level.into());
            hash_state = hash_state.update(if automatic_ip_registration { 1 } else { 0 });
            hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            hash_state = hash_state.update(version);
            hash_state.finalize()
        }
        
        fn hash_notification_settings(
            self: @ContractState,
            enable_notifications: bool,
            ip_updates: bool,
            blockchain_events: bool,
            account_activity: bool,
            nonce: felt252,
            timestamp: u64,
            version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            hash_state = hash_state.update(if enable_notifications { 1 } else { 0 });
            hash_state = hash_state.update(if ip_updates { 1 } else { 0 });
            hash_state = hash_state.update(if blockchain_events { 1 } else { 0 });
            hash_state = hash_state.update(if account_activity { 1 } else { 0 });
            hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            hash_state = hash_state.update(version);
            hash_state.finalize()
        }
        
        fn hash_security_settings(
            self: @ContractState,
            password: felt252,
            nonce: felt252,
            timestamp: u64,
            version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            hash_state = hash_state.update(password);
            hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            hash_state = hash_state.update(version);
            hash_state.finalize()
        }
        
        fn hash_network_settings(
            self: @ContractState,
            network_type: u8,
            gas_price_preference: u8,
            nonce: felt252,
            timestamp: u64,
            version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            assert(network_type == 1 || network_type == 0, 'Invalid Network Type');
            assert(gas_price_preference == 1 || gas_price_preference == 0 || gas_price_preference == 2, 'Invalid Network Type');
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
            hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            hash_state = hash_state.update(version);
            hash_state.finalize()
        }
        
        fn hash_advanced_settings(
            self: @ContractState,
            api_key: felt252,
            nonce: felt252,
            timestamp: u64,
            version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            hash_state = hash_state.update(api_key);
            hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            hash_state = hash_state.update(version);
            hash_state.finalize()
        }
        
        fn hash_social_verification(
            self: @ContractState,
            x_verified: bool,
            nonce: felt252,
            timestamp: u64,
            version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            hash_state = hash_state.update(if x_verified { 1 } else { 0 });
            hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            hash_state = hash_state.update(version);
            hash_state.finalize()
        }
        
        fn hash_wallet_update(
            self: @ContractState,
            new_pub_key: felt252,
            nonce: felt252,
            timestamp: u64,
            version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            hash_state = hash_state.update(new_pub_key);
            hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            hash_state = hash_state.update(version);
            hash_state.finalize()
        }
        
        fn hash_api_key_regeneration(
            self: @ContractState,
            nonce: felt252,
            timestamp: u64,
            version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            hash_state = hash_state.update('regenerate_api');
            hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            hash_state = hash_state.update(version);
            hash_state.finalize()
        }
        
        fn hash_account_deletion(
            self: @ContractState,
            nonce: felt252,
            timestamp: u64,
            version: felt252
        ) -> felt252 {
            let mut hash_state = PoseidonTrait::new();
            hash_state = hash_state.update('delete_account');
            hash_state = hash_state.update(nonce);
            hash_state = hash_state.update(timestamp.into());
            hash_state = hash_state.update(version);
            hash_state.finalize()
        }
        
        fn process_network_type(self: @ContractState, network_type: NetworkType) -> u8 {
            match network_type {
                NetworkType::TESTNET => { 0 },
                NetworkType::MAINNET => { 1 }
            }
        }

        fn reverse_process_network_type(self: @ContractState, network_type_ref: u8) -> Option<NetworkType> {
            match network_type_ref {
                0 => { Option::Some(NetworkType::TESTNET) },
                1 => { Option::Some(NetworkType::MAINNET) },
                _ => { Option::None }
            }
        }

        fn process_gas_price_preference(self: @ContractState, gas_price_preference: GasPricePreference) -> u8 {
            match gas_price_preference {
                GasPricePreference::LOW => { 0 },
                GasPricePreference::MEDIUM => { 1 },
                GasPricePreference::HIGH => { 2 }
            }
        }

        fn reverse_process_gas_price_preference(self: @ContractState, gas_price_preference_ref: u8) -> Option<GasPricePreference> {
            match gas_price_preference_ref {
                0 => { Option::Some(GasPricePreference::LOW) },
                1 => { Option::Some(GasPricePreference::MEDIUM) },
                2 => { Option::Some(GasPricePreference::HIGH) },
                _ => { Option::None }
            }
        }

        fn process_ip_protection_level(self: @ContractState, ip_protection_level: IPProtectionLevel) -> u8 {
            match ip_protection_level {
                IPProtectionLevel::STANDARD => { 0 },
                IPProtectionLevel::ADVANCED => { 1 }
            }
        }

        fn reverse_process_ip_protection_level(self: @ContractState, ip_protection_level_ref: u8) -> Option<IPProtectionLevel> {
            match ip_protection_level_ref {
                0 => { Option::Some(IPProtectionLevel::STANDARD) },
                1 => { Option::Some(IPProtectionLevel::ADVANCED) },
                _ => { Option::None }
            }
        }

    }

}