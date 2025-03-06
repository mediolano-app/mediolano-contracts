#[starknet::contract]
pub mod IPLicensingFactory {
    // *************************************************************************
    //                             IMPORTS
    // *************************************************************************
    use starknet::storage::StorageMapWriteAccess;
    use starknet::storage::StorageMapReadAccess;
    use starknet::{ContractAddress, get_caller_address, get_contract_address, ClassHash};
    use starknet::syscalls::deploy_syscall;
    use core::num::traits::zero::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::storage::{Map, StoragePointerWriteAccess, StoragePointerReadAccess};
    use ip_license_agreement::interfaces::IIPLicensingFactory;
    use core::byte_array::ByteArrayTrait;
    // use ip_license_agreement::interfaces::IIPLicensingAgreement;

    // *************************************************************************
    //                             COMPONENTS
    // *************************************************************************
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Ownable Mixin
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // *************************************************************************
    //                             STORAGE
    // *************************************************************************
    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        // Class hash of the IP Licensing Agreement contract
        agreement_class_hash: ClassHash,
        // Mapping from agreement ID to agreement contract address
        agreements: Map<u256, ContractAddress>,
        // Total number of agreements created
        agreement_count: u256,
        // Mapping from agreement contract address to agreement ID
        agreement_ids: Map<ContractAddress, u256>,
        // Mapping from user address to array of agreement IDs they are involved in
        user_agreements: Map<(ContractAddress, u256), u256>,
        // Count of agreements per user
        user_agreement_count: Map<ContractAddress, u256>,
    }

    // *************************************************************************
    //                             EVENTS
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        AgreementCreated: AgreementCreated,
    }

    #[derive(Drop, starknet::Event)]
    struct AgreementCreated {
        agreement_id: u256,
        agreement_address: ContractAddress,
        creator: ContractAddress,
        title: ByteArray,
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(
        ref self: ContractState, admin: ContractAddress, agreement_class_hash: ClassHash,
    ) {
        self.ownable.initializer(admin);
        self.agreement_class_hash.write(agreement_class_hash);
        self.agreement_count.write(0);
    }

    // *************************************************************************
    //                            IMPLEMENTATION
    // *************************************************************************
    #[abi(embed_v0)]
    impl IPLicensingFactoryImpl of IIPLicensingFactory::IIPLicensingFactory<ContractState> {
        // Create a new IP licensing agreement
        fn create_agreement(
            ref self: ContractState,
            title: ByteArray,
            description: ByteArray,
            ip_metadata: ByteArray,
            signers: Array<ContractAddress>,
        ) -> (u256, ContractAddress) {
            // Validate inputs
            assert(title.len() > 0, 'EMPTY_TITLE');
            assert(description.len() > 0, 'EMPTY_DESCRIPTION');
            assert(ip_metadata.len() > 0, 'EMPTY_METADATA');
            assert(signers.len() > 0, 'NO_SIGNERS');

            let creator = get_caller_address();
            let agreement_id = self.agreement_count.read() + 1;

            // Store title for event emission
            let event_title = title.clone();

            // Deploy new agreement contract
            let mut constructor_calldata = ArrayTrait::new();

            // Convert ContractAddress to felt252
            let creator_felt: felt252 = creator.into();
            constructor_calldata.append(creator_felt);

            let factory_address_felt: felt252 = get_contract_address().into();
            constructor_calldata.append(factory_address_felt);

            // Add ByteArrays to calldata using helper function
            append_byte_array_to_calldata(ref constructor_calldata, title);
            append_byte_array_to_calldata(ref constructor_calldata, description);
            append_byte_array_to_calldata(ref constructor_calldata, ip_metadata);

            // Add signers to calldata
            constructor_calldata.append(signers.len().into());
            let mut i = 0;
            while i < signers.len() {
                let signer_felt: felt252 = (*signers.at(i)).into();
                constructor_calldata.append(signer_felt);
                i += 1;
            };

            let (agreement_address, _) = deploy_syscall(
                self.agreement_class_hash.read(), 0, constructor_calldata.span(), false,
            )
                .unwrap();

            // Update storage
            self.agreements.write(agreement_id, agreement_address);
            self.agreement_ids.write(agreement_address, agreement_id);
            self.agreement_count.write(agreement_id);

            // Add to creator's agreements
            let creator_agreement_count = self.user_agreement_count.read(creator);
            self.user_agreements.write((creator, creator_agreement_count + 1), agreement_id);
            self.user_agreement_count.write(creator, creator_agreement_count + 1);

            // Add to each signer's agreements
            i = 0;
            while i < signers.len() {
                let signer = *signers.at(i);
                if signer != creator {
                    let signer_agreement_count = self.user_agreement_count.read(signer);
                    self.user_agreements.write((signer, signer_agreement_count + 1), agreement_id);
                    self.user_agreement_count.write(signer, signer_agreement_count + 1);
                }
                i += 1;
            };

            // Emit event
            self
                .emit(
                    AgreementCreated {
                        agreement_id, agreement_address, creator, title: event_title,
                    },
                );

            (agreement_id, agreement_address)
        }

        // Get agreement address by ID
        fn get_agreement_address(self: @ContractState, agreement_id: u256) -> ContractAddress {
            let agreement_address = self.agreements.read(agreement_id);
            assert(agreement_address.is_non_zero(), 'AGREEMENT_NOT_FOUND');
            agreement_address
        }

        // Get agreement ID by address
        fn get_agreement_id(self: @ContractState, agreement_address: ContractAddress) -> u256 {
            let agreement_id = self.agreement_ids.read(agreement_address);
            assert(agreement_id != 0, 'AGREEMENT_NOT_FOUND');
            agreement_id
        }

        // Get total number of agreements
        fn get_agreement_count(self: @ContractState) -> u256 {
            self.agreement_count.read()
        }

        // Get agreements for a specific user
        fn get_user_agreements(self: @ContractState, user: ContractAddress) -> Array<u256> {
            let count = self.user_agreement_count.read(user);
            let mut agreements = ArrayTrait::new();
            let mut i: u256 = 1;
            while i <= count {
                agreements.append(self.user_agreements.read((user, i)));
                i += 1;
            };
            agreements
        }

        // Get number of agreements for a specific user
        fn get_user_agreement_count(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_agreement_count.read(user)
        }

        // Update the agreement class hash (only owner)
        fn update_agreement_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.agreement_class_hash.write(new_class_hash);
        }

        // Get the current agreement class hash
        fn get_agreement_class_hash(self: @ContractState) -> ClassHash {
            self.agreement_class_hash.read()
        }
    }

    // *************************************************************************
    //                            HELPER FUNCTIONS
    // *************************************************************************
    // Helper function to append a ByteArray to calldata
    fn append_byte_array_to_calldata(ref calldata: Array<felt252>, byte_array: ByteArray) {
        calldata.append(byte_array.len().into());
        let mut i = 0;
        while i < byte_array.len() {
            let char = byte_array.at(i).unwrap();
            let char_felt: felt252 = char.into();
            calldata.append(char_felt);
            i += 1;
        };
    }
}
