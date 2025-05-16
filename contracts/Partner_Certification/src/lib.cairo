use starknet::ContractAddress;

// Define a struct for integration data storage
#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct IntegrationData {
    template_id: felt252,
    config_hash: felt252,
}

// Define the contract interface
#[starknet::interface]
pub trait IPartnerCertification<TContractState> {
    // External functions (state modifying)
    fn request_certification(ref self: TContractState);
    fn approve_certification(ref self: TContractState, applicant: ContractAddress);
    fn reject_certification(ref self: TContractState, applicant: ContractAddress);
    fn revoke_certification(ref self: TContractState, partner: ContractAddress);
    fn update_integration_config(ref self: TContractState, template_id: felt252, config_hash: felt252);
    fn update_tier(ref self: TContractState, partner: ContractAddress, new_tier: felt252);
    fn assign_note(ref self: TContractState, partner: ContractAddress, note_hash: felt252);
    fn assign_nft_identity(ref self: TContractState, partner: ContractAddress, nft_id: u256);

    // View functions (read-only)
    fn get_partner_status(self: @TContractState, account: ContractAddress) -> felt252;
    fn get_integration_data(self: @TContractState, account: ContractAddress) -> IntegrationData;
    fn get_registration_timestamp(self: @TContractState, account: ContractAddress) -> u64;
    fn get_tier(self: @TContractState, account: ContractAddress) -> felt252;
    fn get_note(self: @TContractState, account: ContractAddress) -> felt252;
    fn get_nft_identity(self: @TContractState, account: ContractAddress) -> u256;
}

// Define the contract module
#[starknet::contract]
pub mod PartnerCertification {
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StorageMapReadAccess, StorageMapWriteAccess, Map};
    use starknet::get_caller_address;
    use starknet::get_block_timestamp;
    use super::IntegrationData;

    // Define storage variables
    #[storage]
    pub struct Storage {
        // Mapping from partner address to their certification status (0: None, 1: Pending, 2: Approved, 3: Rejected, 4: Revoked)
        certified_partners: Map<ContractAddress, felt252>,
        // Mapping from partner address to their integration data
        integration_data: Map<ContractAddress, IntegrationData>,
        // The address of the DAO authorized to approve/reject/revoke certifications
        dao_address: ContractAddress,
        // Mapping from partner address to their registration timestamp
        registration_timestamps: Map<ContractAddress, u64>,
        // Mapping from partner address to their tier status
        tiered_status: Map<ContractAddress, felt252>,
        // Mapping from partner address to a hash representing a note
        notes: Map<ContractAddress, felt252>,
        // Mapping from partner address to an NFT identity ID
        nft_identity: Map<ContractAddress, u256>,
    }

    // Define contract events
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        CertificationRequested: CertificationRequested,
        CertificationApproved: CertificationApproved,
        CertificationRejected: CertificationRejected,
        CertificationRevoked: CertificationRevoked,
        IntegrationConfigUpdated: IntegrationConfigUpdated,
        TierUpdated: TierUpdated,
        NoteAssigned: NoteAssigned,
        NftIdentityAssigned: NftIdentityAssigned,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CertificationRequested {
        user: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CertificationApproved {
        applicant: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CertificationRejected {
        applicant: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CertificationRevoked {
        partner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IntegrationConfigUpdated {
        user: ContractAddress,
        template_id: felt252,
        config_hash: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TierUpdated {
        partner: ContractAddress,
        new_tier: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct NoteAssigned {
        partner: ContractAddress,
        note_hash: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct NftIdentityAssigned {
        partner: ContractAddress,
        nft_id: u256,
    }

    // Constructor function
    #[constructor]
    fn constructor(ref self: ContractState, _dao_address: ContractAddress) {
        self.dao_address.write(_dao_address);
    }

    // Implement the contract interface
    #[abi(embed_v0)]
    pub impl PartnerCertificationImpl of super::IPartnerCertification<ContractState> {
        // Request certification for the caller
        fn request_certification(ref self: ContractState) {
            let caller = get_caller_address();
            let status = self.certified_partners.read(caller);
            assert(status == 0, 'Already registered'); // Ensure not already registered

            let timestamp = get_block_timestamp();
            self.certified_partners.write(caller, 1); // Set status to Pending
            self.registration_timestamps.write(caller, timestamp);

            self.emit(Event::CertificationRequested(CertificationRequested { user: caller }));
        }

        // Approve a pending certification request
        fn approve_certification(ref self: ContractState, applicant: ContractAddress) {
            let caller = get_caller_address();
            let dao = self.dao_address.read();
            assert(caller == dao, 'Only DAO can approve'); // Only DAO can call this function

            let status = self.certified_partners.read(applicant);
            assert(status == 1, 'Must be pending'); // Must be pending status

            self.certified_partners.write(applicant, 2); // Set status to Approved

            self.emit(Event::CertificationApproved(CertificationApproved { applicant }));
        }

        // Reject a pending certification request
        fn reject_certification(ref self: ContractState, applicant: ContractAddress) {
            let caller = get_caller_address();
            let dao = self.dao_address.read();
            assert(caller == dao, 'Only DAO can reject'); // Only DAO can call this function

            let status = self.certified_partners.read(applicant);
            assert(status == 1, 'Must be pending'); // Must be pending status

            self.certified_partners.write(applicant, 3); // Set status to Rejected

            self.emit(Event::CertificationRejected(CertificationRejected { applicant }));
        }

        // Revoke an approved certification
        fn revoke_certification(ref self: ContractState, partner: ContractAddress) {
            let caller = get_caller_address();
            let dao = self.dao_address.read();
            assert(caller == dao, 'Only DAO can revoke'); // Only DAO can call this function

            // Optional: Add check if status is Approved (2) before revoking, depending on desired logic
            // let status = self.certified_partners.read(partner);
            // assert(status == 2, 'Must be approved');

            self.certified_partners.write(partner, 4); // Set status to Revoked

            self.emit(Event::CertificationRevoked(CertificationRevoked { partner }));
        }

        // Update integration configuration for an approved partner
        fn update_integration_config(ref self: ContractState, template_id: felt252, config_hash: felt252) {
            let caller = get_caller_address();
            let status = self.certified_partners.read(caller);
            assert(status == 2, 'Only approved partners'); // Only approved partners can update config

            self.integration_data.write(caller, IntegrationData { template_id, config_hash });

            self.emit(Event::IntegrationConfigUpdated(IntegrationConfigUpdated { user: caller, template_id, config_hash }));
        }

        // Update the tier status for a partner (DAO only)
        fn update_tier(ref self: ContractState, partner: ContractAddress, new_tier: felt252) {
            let caller = get_caller_address();
            let dao = self.dao_address.read();
            assert(caller == dao, 'Only DAO can update tier'); // Only DAO can call this function

            self.tiered_status.write(partner, new_tier);

            self.emit(Event::TierUpdated(TierUpdated { partner, new_tier }));
        }

        // Assign a note hash to a partner (DAO only)
        fn assign_note(ref self: ContractState, partner: ContractAddress, note_hash: felt252) {
            let caller = get_caller_address();
            let dao = self.dao_address.read();
            assert(caller == dao, 'Only DAO can assign note'); // Only DAO can call this function

            self.notes.write(partner, note_hash);

            self.emit(Event::NoteAssigned(NoteAssigned { partner, note_hash }));
        }

        // Assign an NFT identity to a partner (DAO only)
        fn assign_nft_identity(ref self: ContractState, partner: ContractAddress, nft_id: u256) {
            let caller = get_caller_address();
            let dao = self.dao_address.read();
            assert(caller == dao, 'Only DAO can assign NFT'); // Only DAO can call this function

            self.nft_identity.write(partner, nft_id);

            self.emit(Event::NftIdentityAssigned(NftIdentityAssigned { partner, nft_id }));
        }

        // Retrieve the certification status of an account
        fn get_partner_status(self: @ContractState, account: ContractAddress) -> felt252 {
            self.certified_partners.read(account)
        }

        // Retrieve the integration data for an account
        fn get_integration_data(self: @ContractState, account: ContractAddress) -> IntegrationData {
            self.integration_data.read(account)
        }

        // Retrieve the registration timestamp for an account
        fn get_registration_timestamp(self: @ContractState, account: ContractAddress) -> u64 {
            self.registration_timestamps.read(account)
        }

        // Retrieve the tier status for an account
        fn get_tier(self: @ContractState, account: ContractAddress) -> felt252 {
            self.tiered_status.read(account)
        }

        // Retrieve the note hash for an account
        fn get_note(self: @ContractState, account: ContractAddress) -> felt252 {
            self.notes.read(account)
        }

        // Retrieve the NFT identity for an account
        fn get_nft_identity(self: @ContractState, account: ContractAddress) -> u256 {
            self.nft_identity.read(account)
        }
    }
}