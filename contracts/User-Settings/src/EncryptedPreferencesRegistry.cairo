use starknet::ContractAddress;

// Structure for storing encrypted user settings
// Each setting contains the encrypted data, nonce for encryption,
// associated public key, timestamp of last update, and version number
#[derive(Drop, Serde, starknet::Store)]
struct EncryptedSetting {
    data: felt252,
    nonce: felt252,
    pub_key: felt252,
    timestamp: u64,
    version: felt252
}

// Structure for storing wallet-specific encryption data
// Tracks the current public key, version, and last update time
#[derive(Drop, Serde, starknet::Store)]
struct WalletData {
    pub_key: felt252,
    version: felt252,
    last_updated: u64
}

#[starknet::interface]
pub trait IEncryptedPreferencesRegistry<TContractState> {
    fn store_setting(
        ref self: TContractState,
        key: felt252,
        encrypted_data: Array<felt252>,
        wallet_signature: Array<felt252>,
        pub_key: felt252
    );
    fn get_setting(self: @TContractState, user: ContractAddress, key: felt252) -> (felt252, felt252);
    fn remove_setting(ref self: TContractState, key: felt252);
    fn update_wallet_key(
        ref self: TContractState,
        new_pub_key: felt252,
        signature: Array<felt252>
    );
    fn verify_setting(
        self: @TContractState,
        user: ContractAddress,
        key: felt252,
        signature: Array<felt252>
    ) -> bool;
}

#[starknet::contract]
mod EncryptedPreferencesRegistry {
    use starknet::{ContractAddress, get_caller_address};
    use core::array::ArrayTrait;
    use super::{EncryptedSetting, WalletData};

    #[storage]
    struct Storage {
        settings: starknet::storage::Map::<(ContractAddress, felt252), EncryptedSetting>,
        authorized_apps: starknet::storage::Map::<ContractAddress, bool>,
        wallet_data: starknet::storage::Map::<ContractAddress, WalletData>,
        encryption_versions: starknet::storage::Map::<ContractAddress, felt252>,
        owner: ContractAddress,
        mediolano_app: ContractAddress,
        total_settings: starknet::storage::Map::<ContractAddress, u64>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SettingUpdated: SettingUpdated,
        SettingRemoved: SettingRemoved,
        WalletKeyUpdated: WalletKeyUpdated
    }

    #[derive(Drop, starknet::Event)]
    struct SettingUpdated {
        #[key]
        user: ContractAddress,
        key: felt252,
        version: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct SettingRemoved {
        #[key]
        user: ContractAddress,
        key: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct WalletKeyUpdated {
        #[key]
        user: ContractAddress,
        pub_key: felt252,
        version: felt252
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        owner: ContractAddress,
        mediolano_app: ContractAddress
    ) {
        self.owner.write(owner);
        self.mediolano_app.write(mediolano_app);
        self.authorized_apps.write(mediolano_app, true);
    }

    #[abi(embed_v0)]
    impl EncryptedPreferencesRegistryImpl of super::IEncryptedPreferencesRegistry<ContractState> {
        fn store_setting(
            ref self: ContractState,
            key: felt252,
            encrypted_data: Array<felt252>,
            wallet_signature: Array<felt252>,
            pub_key: felt252
        ) {
            let caller = get_caller_address();
            self.assert_authorized(caller);
            self.verify_signature(caller, wallet_signature.span(), pub_key);

            let version = self._get_next_version(caller);
            let setting = EncryptedSetting {
                data: *encrypted_data.at(0),
                nonce: *encrypted_data.at(1),
                pub_key,
                timestamp: starknet::get_block_timestamp(),
                version
            };

            self.settings.write((caller, key), setting);
            self._increment_total_settings(caller);

            self.emit(Event::SettingUpdated(
                SettingUpdated { user: caller, key, version }
            ));
        }

        fn get_setting(
            self: @ContractState,
            user: ContractAddress,
            key: felt252
        ) -> (felt252, felt252) {
            let setting = self.settings.read((user, key));
            (setting.data, setting.nonce)
        }

        fn remove_setting(ref self: ContractState, key: felt252) {
            let caller = get_caller_address();
            self.assert_authorized(caller);

            let empty_setting = EncryptedSetting {
                data: 0,
                nonce: 0,
                pub_key: 0,
                timestamp: 0,
                version: 0
            };
            self.settings.write((caller, key), empty_setting);

            self.emit(Event::SettingRemoved(
                SettingRemoved { user: caller, key }
            ));
        }

        fn update_wallet_key(
            ref self: ContractState,
            new_pub_key: felt252,
            signature: Array<felt252>
        ) {
            let caller = get_caller_address();
            self.assert_authorized(caller);

            let current_data = self.wallet_data.read(caller);
            self.verify_signature(caller, signature.span(), current_data.pub_key);

            let version = self._get_next_version(caller);
            let wallet_data = WalletData {
                pub_key: new_pub_key,
                version,
                last_updated: starknet::get_block_timestamp()
            };

            self.wallet_data.write(caller, wallet_data);
            self.encryption_versions.write(caller, version);

            self.emit(Event::WalletKeyUpdated(
                WalletKeyUpdated { user: caller, pub_key: new_pub_key, version }
            ));
        }

        fn verify_setting(
            self: @ContractState,
            user: ContractAddress,
            key: felt252,
            signature: Array<felt252>
        ) -> bool {
            let setting = self.settings.read((user, key));
            self._verify_signature_internal(user, signature.span(), setting.pub_key)
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn assert_authorized(self: @ContractState, user: ContractAddress) {
            assert(self.authorized_apps.read(user), 'Unauthorized app');
        }

        fn verify_signature(
            self: @ContractState,
            user: ContractAddress,
            signature: Span<felt252>,
            pub_key: felt252
        ) {
            assert(self._verify_signature_internal(user, signature, pub_key), 'Invalid signature');
        }

        fn _verify_signature_internal(
            self: @ContractState,
            user: ContractAddress,
            signature: Span<felt252>,
            pub_key: felt252
        ) -> bool {
            signature.len() > 0 && *signature.at(0) != 0
        }

        fn _get_next_version(self: @ContractState, user: ContractAddress) -> felt252 {
            self.encryption_versions.read(user) + 1
        }

        fn _increment_total_settings(ref self: ContractState, user: ContractAddress) {
            let current = self.total_settings.read(user);
            self.total_settings.write(user, current + 1);
        }
    }
}