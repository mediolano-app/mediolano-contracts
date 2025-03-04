#[starknet::contract]
pub mod IPLicensingAgreement {
    // *************************************************************************
    //                             IMPORTS
    // *************************************************************************
    use openzeppelin::access::ownable::interface::IOwnable;
    use starknet::storage::StorageMapWriteAccess;
    use starknet::storage::StorageMapReadAccess;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use core::num::traits::zero::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::storage::{Map, StoragePointerWriteAccess, StoragePointerReadAccess};
    use ip_license_agreement::interfaces::IIPLicensingAgreement;

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
        // Factory contract address
        factory: ContractAddress,
        // Agreement metadata
        title: ByteArray,
        description: ByteArray,
        ip_metadata: ByteArray,
        creation_timestamp: u64,
        // Immutability status
        is_immutable: bool,
        immutability_timestamp: u64,
        // Signers
        signers: Map<ContractAddress, bool>,
        signer_addresses: Map<u256, ContractAddress>,
        signer_count: u256,
        // Signatures
        signatures: Map<ContractAddress, bool>,
        signature_timestamps: Map<ContractAddress, u64>,
        signature_count: u256,
        // Additional metadata
        additional_metadata: Map<felt252, felt252>,
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
        AgreementSigned: AgreementSigned,
        AgreementMadeImmutable: AgreementMadeImmutable,
        MetadataAdded: MetadataAdded,
    }

    #[derive(Drop, starknet::Event)]
    struct AgreementSigned {
        signer: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct AgreementMadeImmutable {
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct MetadataAdded {
        key: felt252,
        value: felt252,
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(
        ref self: ContractState,
        creator: ContractAddress,
        factory: ContractAddress,
        title: ByteArray,
        description: ByteArray,
        ip_metadata: ByteArray,
        signers: Array<ContractAddress>,
    ) {
        self.ownable.initializer(creator);
        self.factory.write(factory);
        self.title.write(title);
        self.description.write(description);
        self.ip_metadata.write(ip_metadata);
        self.creation_timestamp.write(get_block_timestamp());
        self.is_immutable.write(false);
        self.immutability_timestamp.write(0);
        self.signature_count.write(0);

        // Add signers
        let mut i: u32 = 0;
        let mut signer_count: u256 = 0;
        while i < signers.len() {
            let signer = *signers.at(i);
            if !self.signers.read(signer) && signer.is_non_zero() {
                signer_count += 1;
                self.signers.write(signer, true);
                self.signer_addresses.write(signer_count, signer);
            }
            i += 1;
        };
        self.signer_count.write(signer_count);
    }

    // *************************************************************************
    //                            IMPLEMENTATION
    // *************************************************************************
    #[abi(embed_v0)]
    impl IPLicensingAgreementImpl of IIPLicensingAgreement::IIPLicensingAgreement<ContractState> {
        // Sign the agreement
        fn sign_agreement(ref self: ContractState) {
            let caller = get_caller_address();

            // Validate caller is a signer
            assert(self.signers.read(caller), 'NOT_A_SIGNER');

            // Validate agreement is not immutable
            assert(!self.is_immutable.read(), 'AGREEMENT_IMMUTABLE');

            // Validate caller has not already signed
            assert(!self.signatures.read(caller), 'ALREADY_SIGNED');

            // Record signature
            self.signatures.write(caller, true);
            self.signature_timestamps.write(caller, get_block_timestamp());
            self.signature_count.write(self.signature_count.read() + 1);

            // Emit event
            self.emit(AgreementSigned { signer: caller, timestamp: get_block_timestamp() });
        }

        // Make the agreement immutable (only owner)
        fn make_immutable(ref self: ContractState) {
            // Only owner can make immutable
            self.ownable.assert_only_owner();

            // Validate agreement is not already immutable
            assert(!self.is_immutable.read(), 'ALREADY_IMMUTABLE');
            // Validate agreement is fully signed (all signers have signed)

            // Make immutable
            self.is_immutable.write(true);
            self.immutability_timestamp.write(get_block_timestamp());

            // Emit event
            self.emit(AgreementMadeImmutable { timestamp: get_block_timestamp() });
        }

        // Add additional metadata (only owner and only if not immutable)
        fn add_metadata(ref self: ContractState, key: felt252, value: felt252) {
            // Only owner can add metadata
            self.ownable.assert_only_owner();

            // Validate agreement is not immutable
            assert(!self.is_immutable.read(), 'AGREEMENT_IMMUTABLE');

            // Validate inputs
            assert(key.is_non_zero(), 'EMPTY_KEY');
            assert(value.is_non_zero(), 'EMPTY_VALUE');

            // Add metadata
            self.additional_metadata.write(key, value);

            // Emit event
            self.emit(MetadataAdded { key, value });
        }

        // Get agreement metadata
        fn get_metadata(self: @ContractState) -> (ByteArray, ByteArray, ByteArray, u64, bool, u64) {
            (
                self.title.read(),
                self.description.read(),
                self.ip_metadata.read(),
                self.creation_timestamp.read(),
                self.is_immutable.read(),
                self.immutability_timestamp.read(),
            ) // TODO: add additional metadata
        }

        // Get additional metadata
        fn get_additional_metadata(self: @ContractState, key: felt252) -> felt252 {
            self.additional_metadata.read(key)
        }

        // Check if address is a signer
        fn is_signer(self: @ContractState, address: ContractAddress) -> bool {
            self.signers.read(address)
        }

        // Check if address has signed
        fn has_signed(self: @ContractState, address: ContractAddress) -> bool {
            self.signatures.read(address)
        }

        // Get signature timestamp
        fn get_signature_timestamp(self: @ContractState, address: ContractAddress) -> u64 {
            assert(self.signatures.read(address), 'NOT_SIGNED');
            self.signature_timestamps.read(address)
        }

        // Get all signers
        fn get_signers(self: @ContractState) -> Array<ContractAddress> {
            let count = self.signer_count.read();
            let mut signers = ArrayTrait::new();
            let mut i: u256 = 1;
            while i <= count {
                signers.append(self.signer_addresses.read(i));
                i += 1;
            };
            signers
        }

        // Get signer count
        fn get_signer_count(self: @ContractState) -> u256 {
            self.signer_count.read()
        }

        // Get signature count
        fn get_signature_count(self: @ContractState) -> u256 {
            self.signature_count.read()
        }

        // Check if agreement is fully signed
        fn is_fully_signed(self: @ContractState) -> bool {
            self.signature_count.read() == self.signer_count.read()
        }

        // Get factory address
        fn get_factory(self: @ContractState) -> ContractAddress {
            self.factory.read()
        }

        // Get owner
        fn get_owner(self: @ContractState) -> ContractAddress {
            self.ownable.owner()
        }
    }
}
