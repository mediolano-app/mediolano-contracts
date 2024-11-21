#[starknet::contract]
mod UserPreferences {
    use core::starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        user_info: Map::<ContractAddress, UserInfo>,
        user_settings: Map::<ContractAddress, UserSettings>,
        user_dapp_preferences: Map::<ContractAddress, DappPreferences>,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct UserInfo {
        username: felt252,
        email: felt252,
        registration_date: u64,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct UserSettings {
        theme: felt252,
        language: felt252,
        notifications_enabled: bool,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct DappPreferences {
        favorite_dapps: Array<felt252>,
        default_network: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UserInfoUpdated: UserInfoUpdated,
        UserSettingsUpdated: UserSettingsUpdated,
        DappPreferencesUpdated: DappPreferencesUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct UserInfoUpdated {
        #[key]
        user: ContractAddress,
        username: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct UserSettingsUpdated {
        #[key]
        user: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct DappPreferencesUpdated {
        #[key]
        user: ContractAddress,
    }

    #[generate_trait]
    impl UserPreferencesImpl of IUserPreferences {
        fn update_user_info(
            ref self: ContractState, username: felt252, email: felt252
        ) {
            let caller = get_caller_address();
            let user_info = UserInfo {
                username: username,
                email: email,
                registration_date: starknet::get_block_timestamp(),
            };
            self.user_info.write(caller, user_info);
            self.emit(UserInfoUpdated { user: caller, username: username });
        }

        fn update_user_settings(
            ref self: ContractState, theme: felt252, language: felt252, notifications_enabled: bool
        ) {
            let caller = get_caller_address();
            let user_settings = UserSettings {
                theme: theme,
                language: language,
                notifications_enabled: notifications_enabled,
            };
            self.user_settings.write(caller, user_settings);
            self.emit(UserSettingsUpdated { user: caller });
        }

        fn update_dapp_preferences(
            ref self: ContractState, favorite_dapps: Array<felt252>, default_network: felt252
        ) {
            let caller = get_caller_address();
            let dapp_preferences = DappPreferences {
                favorite_dapps: favorite_dapps,
                default_network: default_network,
            };
            self.user_dapp_preferences.write(caller, dapp_preferences);
            self.emit(DappPreferencesUpdated { user: caller });
        }

        fn get_user_info(self: @ContractState, user: ContractAddress) -> UserInfo {
            self.user_info.read(user)
        }

        fn get_user_settings(self: @ContractState, user: ContractAddress) -> UserSettings {
            self.user_settings.read(user)
        }

        fn get_dapp_preferences(self: @ContractState, user: ContractAddress) -> DappPreferences {
            self.user_dapp_preferences.read(user)
        }
    }
}