#[starknet::contract]
pub mod IPClubNFT {
    use ERC721Component::InternalTrait;
    use openzeppelin_access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};

    use starknet::{ContractAddress, get_block_timestamp};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    use crate::interfaces::IIPClubNFT::IIPClubNFT;
    use crate::events::NftMinted;

    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl AccessControlMixinImpl = AccessControlComponent::AccessControlMixinImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        creator: ContractAddress, // Address of the NFT creator
        club_id: u256, // Club identifier
        ip_club_manager: ContractAddress, // Address of the IP club manager
        last_token_id: u256 // Last minted token ID
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        NFTMinted: NftMinted,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        club_id: u256,
        creator: ContractAddress,
        ip_club_manager: ContractAddress,
        metadata_uri: ByteArray,
    ) {
        // Initialize ERC721 with name, symbol, and metadata URI
        self.erc721.initializer(name, symbol, metadata_uri);
        // Initialize AccessControl
        self.accesscontrol.initializer();
        // Grant admin role to the IP club manager
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, ip_club_manager);

        // Store creator, manager, club ID, and reset last token ID
        self.creator.write(creator);
        self.ip_club_manager.write(ip_club_manager);
        self.last_token_id.write(0);
        self.club_id.write(club_id);
    }

    // Implementation of the IIPClubNFT interface
    #[abi(embed_v0)]
    impl IIPClubNFTImpl of IIPClubNFT<ContractState> {
        /// Mints a new NFT and assigns it to the specified recipient address.
        /// # Arguments
        /// * `recipient` - The address that will receive the newly minted NFT.
        /// # Access Control
        /// Only authorized club nft manager can call this function.
        // Mint a new NFT to the recipient address
        fn mint(ref self: ContractState, recipient: ContractAddress) {
            // Only admin can mint
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);

            // Ensure recipient does not already own an NFT
            let has_nft = self.has_nft(recipient);
            assert(!has_nft, 'Already has nft');

            // Increment token ID and mint NFT
            let next_token_id = self.last_token_id.read() + 1;
            self.erc721.mint(recipient, next_token_id);
            self.last_token_id.write(next_token_id);

            // Emit NFTMinted event
            self
                .emit(
                    NftMinted {
                        club_id: self.club_id.read(),
                        token_id: next_token_id,
                        recipient,
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        // Check if a user already owns an NFT
        fn has_nft(self: @ContractState, user: ContractAddress) -> bool {
            let balance = self.erc721.balance_of(user);
            balance > 0
        }

        // Get the creator address
        fn get_nft_creator(self: @ContractState) -> ContractAddress {
            self.creator.read()
        }

        // Get the IP club manager address
        fn get_ip_club_manager(self: @ContractState) -> ContractAddress {
            self.ip_club_manager.read()
        }

        // Get the Club ID
        fn get_associated_club_id(self: @ContractState) -> u256 {
            self.club_id.read()
        }

        // Get last minted ID
        fn get_last_minted_id(self: @ContractState) -> u256 {
            self.last_token_id.read()
        }
    }
}
