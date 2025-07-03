#[starknet::contract]
pub mod xZBERC20 {
    use openzeppelin_access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;
    use starknet::{
        ClassHash, ContractAddress, get_caller_address, get_block_timestamp, get_contract_address,
    };
    use starknet::syscalls::deploy_syscall;

    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry,
    };

    use crate::interfaces::IIPClub::IIPClub;
    use crate::interfaces::IIPClubNFT::{IIPClubNFTDispatcher, IIPClubNFTDispatcherTrait};
    use crate::events::{NewClubCreated, NewMember, ClubClosed};
    use crate::types::{ClubRecord, ClubStatus};

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl AccessControlMixinImpl =
        AccessControlComponent::AccessControlMixinImpl<ContractState>;

    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        ip_club_nft_class_hash: ClassHash, // Class hash for club NFT contracts
        last_club_id: u256, // Last used club ID
        clubs: Map<u256, ClubRecord> // Mapping from club ID to club record
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        NewClubCreated: NewClubCreated, // Emitted when a new club is created
        NewMember: NewMember, // Emitted when a new member joins a club
        ClubClosed: ClubClosed // Emitted when a club is closed
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, ip_club_nft_class_hash: ClassHash,
    ) {
        self.accesscontrol.initializer(); // Initialize access control
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, owner); // Grant admin role to owner
        self.ip_club_nft_class_hash.write(ip_club_nft_class_hash); // Store NFT class hash
    }

    #[abi(embed_v0)]
    impl IPClubImpl of IIPClub<ContractState> {
        /// Creates a new club and deploys its associated NFT contract.
        /// # Description
        /// This function initializes a new club entity and deploys a dedicated NFT contract for it.
        fn create_club(
            ref self: ContractState,
            name: ByteArray,
            symbols: ByteArray,
            metadata_uri: ByteArray,
            max_members: Option<u32>,
            entry_fee: Option<u256>,
            payment_token: Option<ContractAddress>,
        ) {
            let ip_club_manager = get_contract_address(); // Address of this contract
            let creator = get_caller_address(); // Club creator
            let next_club_id = self.last_club_id.read() + 1; // Increment club ID

            let mut constructor_calldata: Array::<felt252> = array![];

            // Serialize constructor arguments for NFT contract
            (
                name.clone(),
                symbols.clone(),
                next_club_id,
                creator,
                ip_club_manager,
                metadata_uri.clone(),
            )
                .serialize(ref constructor_calldata);

            // Deploy the NFT contract for the club
            let (ip_club_nft_address, _) = deploy_syscall(
                self.ip_club_nft_class_hash.read(), 0, constructor_calldata.span(), false,
            )
                .unwrap();

            // Create and store the club record
            let club_record = ClubRecord {
                id: next_club_id,
                name,
                symbols,
                metadata_uri: metadata_uri.clone(),
                status: ClubStatus::Open,
                num_members: 0,
                creator,
                club_nft: ip_club_nft_address,
                max_members,
                entry_fee,
                payment_token,
            };

            self.clubs.entry(next_club_id).write(club_record);

            // Emit event for new club creation
            self
                .emit(
                    NewClubCreated {
                        club_id: next_club_id,
                        creator,
                        metadata_uri,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Closes an existing club, removing it from the registry.
        /// # Access Control
        /// Only the creator of the club can call this function.
        /// # Arguments
        /// * `club_id` - The unique identifier of the club to close.
        fn close_club(ref self: ContractState, club_id: u256) {
            let mut club_record = self.clubs.entry(club_id).read();
            let caller = get_caller_address();

            assert(club_record.status == ClubStatus::Open, 'Club not open');
            assert(club_record.creator == caller, 'Not Authorized');

            club_record.status = ClubStatus::Closed;
            self.clubs.entry(club_id).write(club_record);

            // Emit event for club closure
            self.emit(ClubClosed { club_id, creator: caller, timestamp: get_block_timestamp() });
        }

        /// Allows a user to join a club by minting a membership NFT and transferring the entry fee
        /// if required.
        /// # Details
        /// This function manages the club membership process, including:
        /// - Minting a membership NFT for the user.
        /// - Processing the entry fee payment if an entry fee is specified.
        /// # Access Control
        /// Accessible to any user wishing to join a club.
        fn join_club(ref self: ContractState, club_id: u256) {
            let mut club_record = self.clubs.entry(club_id).read();

            let caller = get_caller_address();

            assert(club_record.status == ClubStatus::Open, 'Club not open');

            let is_member = self.is_member(club_id, caller);
            assert(!is_member, 'Already a member');

            // Check if club is full
            if let Option::Some(max) = club_record.max_members {
                assert(club_record.num_members < max, 'Club full');
            }

            // Handle entry fee payment if required
            if let Option::Some(fee) = club_record.entry_fee {
                let payment_token_address = club_record.payment_token.unwrap();
                let payment_token = IERC20Dispatcher { contract_address: payment_token_address };
                let result = payment_token.transfer_from(caller, club_record.creator, fee);
                assert(result, 'Token Transfer Failed');
            }

            // Mint club NFT to the new member
            let ip_club_nft = IIPClubNFTDispatcher { contract_address: club_record.club_nft };
            ip_club_nft.mint(caller);

            club_record.num_members += 1;

            self.clubs.entry(club_id).write(club_record);

            // Emit event for new member
            self.emit(NewMember { club_id, member: caller, timestamp: get_block_timestamp() });
        }

        // Get the club record for a given club ID
        fn get_club_record(self: @ContractState, club_id: u256) -> ClubRecord {
            self.clubs.entry(club_id).read()
        }

        // Check if a user is a member of a club (owns the club NFT)
        fn is_member(self: @ContractState, club_id: u256, user: ContractAddress) -> bool {
            let club_record = self.clubs.entry(club_id).read();
            let ip_club_nft = IIPClubNFTDispatcher { contract_address: club_record.club_nft };
            ip_club_nft.has_nft(user)
        }
    }

    // Upgradeable logic implementation
    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        // Upgrade contract to a new class hash (only admin)
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
