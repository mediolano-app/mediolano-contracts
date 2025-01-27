use starknet::ContractAddress;

#[starknet::interface]
trait IEncryptedPreferencesRegistry<TContractState> {
    fn store_encrypted_preferences(
        ref self: TContractState,
        key: felt252,
        encrypted_data: Span<felt252>,
        encryption_nonce: felt252
    );
    fn get_encrypted_preferences(
        self: @TContractState,
        user: ContractAddress,
        key: felt252
    ) -> (felt252, felt252);
    fn update_encryption_key(
        ref self: TContractState,
        new_encryption_nonce: felt252
    );
    fn remove_preferences(ref self: TContractState, key: felt252);
}

#[starknet::contract]
mod EncryptedPreferencesRegistry {
    use starknet::{ContractAddress, get_caller_address};
    use core::{array::ArrayTrait, array::SpanTrait};

    #[derive(Drop, Serde, starknet::Store)]
    struct EncryptedData {
        data: felt252,  // Store single felt252 for encrypted data
        nonce: felt252
    }

    #[storage]
    struct Storage {
        preferences: LegacyMap::<(ContractAddress, felt252), EncryptedData>,
        authorized_apps: LegacyMap::<ContractAddress, bool>,
        owner: ContractAddress,
        mediolano_app: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PreferencesUpdated: PreferencesUpdated,
        PreferencesRemoved: PreferencesRemoved,
        EncryptionKeyUpdated: EncryptionKeyUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct PreferencesUpdated {
        #[key]
        user: ContractAddress,
        key: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct PreferencesRemoved {
        #[key]
        user: ContractAddress,
        key: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct EncryptionKeyUpdated {
        #[key]
        user: ContractAddress,
        nonce: felt252,
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
        fn store_encrypted_preferences(
            ref self: ContractState,
            key: felt252,
            encrypted_data: Span<felt252>,
            encryption_nonce: felt252
        ) {
            let caller = get_caller_address();
            assert(self.authorized_apps.read(caller), 'Unauthorized app');
            
            // For simplicity, store the first element of encrypted data
            // In a real implementation, you might want to handle multiple felt252s differently
            let data = EncryptedData { 
                data: *encrypted_data.at(0), 
                nonce: encryption_nonce 
            };
            self.preferences.write((caller, key), data);
            
            self.emit(Event::PreferencesUpdated(
                PreferencesUpdated { user: caller, key }
            ));
        }

        fn get_encrypted_preferences(
            self: @ContractState,
            user: ContractAddress,
            key: felt252
        ) -> (felt252, felt252) {
            let stored_data = self.preferences.read((user, key));
            (stored_data.data, stored_data.nonce)
        }

        fn update_encryption_key(
            ref self: ContractState,
            new_encryption_nonce: felt252
        ) {
            let caller = get_caller_address();
            let key = 'encryption_key';
            let data = EncryptedData { data: 0, nonce: new_encryption_nonce };
            self.preferences.write((caller, key), data);
            
            self.emit(Event::EncryptionKeyUpdated(
                EncryptionKeyUpdated { user: caller, nonce: new_encryption_nonce }
            ));
        }

        fn remove_preferences(ref self: ContractState, key: felt252) {
            let caller = get_caller_address();
            assert(self.authorized_apps.read(caller), 'Unauthorized app');
            
            let data = EncryptedData { data: 0, nonce: 0 };
            self.preferences.write((caller, key), data);
            
            self.emit(Event::PreferencesRemoved(
                PreferencesRemoved { user: caller, key }
            ));
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn assert_only_owner(self: @ContractState) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Caller is not the owner');
        }
        
        fn assert_only_mediolano(self: @ContractState) {
            let caller = get_caller_address();
            assert(caller == self.mediolano_app.read(), 'Caller is not Mediolano');
        }
    }
}