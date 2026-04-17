// DESIGN: IPCollection1155 is permanently immutable — no UpgradeableComponent, no admin roles.
// It is a standalone, permissionless ERC-1155 multi-token contract. Any caller can mint a
// new token type (auto-assigned sequential ID) and any amount to any recipient. The contract
// deployer address is purely informational and holds zero on-chain power after deployment.
//
// IP PROVENANCE: The original creator address and block timestamp of the first mint are
// written once per token type and can never be changed. This constitutes the immutable
// authorship record under the Berne Convention (181-country IP protection).
//
// PROGRAMMABLE LICENSING: Each token type has independently mutable license terms stored
// on-chain. Only the original creator of that token type can update its license. An empty
// license means no license has been set yet.
//
// URI STRATEGY: Every token type requires a full content-addressed URI (ipfs:// or ar://)
// at mint time. The frontend normalizes bare IPFS CIDs to ipfs:// before calling mint_item.
// No base URI concatenation — each token stores its complete metadata pointer.

#[starknet::contract]
pub mod IPCollection1155 {
    use core::num::traits::Zero;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::interface::IERC1155MetadataURI;
    use openzeppelin::token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use crate::interfaces::IIPCollection1155::IIPCollection1155;
    use crate::types::{TokenData, bytearray_starts_with};

    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // --- Exposed ABI implementations ---
    // ERC-1155 standard transfers and approvals.
    #[abi(embed_v0)]
    impl ERC1155Impl = ERC1155Component::ERC1155Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1155CamelImpl = ERC1155Component::ERC1155CamelImpl<ContractState>;
    // SRC5 / ERC165 interface introspection.
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    // --- Internal implementations (not exposed) ---
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        /// Address that deployed this contract. Informational only — holds no special power.
        collection_creator: ContractAddress,
        /// Internal token ID counter. Starts at 1; increments on each mint_item call.
        next_token_id: u256,
        /// Full content-addressed URI per token type. Written once at first mint.
        token_uris: Map<u256, ByteArray>,
        /// Per-token programmable license terms. Mutable by original creator only.
        token_licenses: Map<u256, ByteArray>,
        /// Original caller per token type — immutable Berne Convention authorship record.
        token_creators: Map<u256, ContractAddress>,
        /// Block timestamp at first mint — immutable proof of creation date.
        token_registered_at: Map<u256, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        IPMinted: IPMinted,
        LicenseUpdated: LicenseUpdated,
    }

    /// Emitted on every successful mint_item call.
    /// `token_id` and `recipient` are indexed for efficient indexer filtering.
    #[derive(Drop, starknet::Event)]
    pub struct IPMinted {
        #[key]
        pub token_id: u256,
        #[key]
        pub recipient: ContractAddress,
        pub amount: u256,
        pub uri: ByteArray,
        pub creator: ContractAddress,
        pub registered_at: u64,
    }

    /// Emitted when the original creator updates a token type's license.
    #[derive(Drop, starknet::Event)]
    pub struct LicenseUpdated {
        #[key]
        pub token_id: u256,
        pub creator: ContractAddress,
        pub license: ByteArray,
    }

    /// Deploys a new standalone IPCollection1155.
    ///
    /// # Arguments
    /// * `collection_creator` - Address recorded as the deployer (informational, holds no power)
    #[constructor]
    fn constructor(ref self: ContractState, collection_creator: ContractAddress) {
        // base_uri intentionally empty — every token stores its full ipfs:// or ar:// URI.
        self.erc1155.initializer("");
        self.collection_creator.write(collection_creator);
        // Token IDs start at 1; zero is reserved as "non-existent"
        self.next_token_id.write(1);
    }

    // --- ERC1155 URI override ---
    // Returns the per-token URI stored at mint time.
    // Returns empty string for token IDs that do not exist (never minted).

    #[abi(embed_v0)]
    impl ERC1155MetadataURIImpl of IERC1155MetadataURI<ContractState> {
        fn uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.token_uris.read(token_id)
        }
    }

    // --- IIPCollection1155 implementation ---

    #[abi(embed_v0)]
    impl IPCollection1155Impl of IIPCollection1155<ContractState> {
        /// Mints `amount` units of a new token type to `recipient`.
        ///
        /// Permissionless — callable by anyone.
        /// Assigns the next sequential token ID.
        /// Validates: recipient != zero, amount > 0, uri starts with ipfs:// or ar://.
        fn mint_item(
            ref self: ContractState,
            recipient: ContractAddress,
            amount: u256,
            token_uri: ByteArray,
            license: ByteArray,
        ) -> u256 {
            assert(!recipient.is_zero(), 'Recipient is zero address');
            assert(amount > 0, 'Amount must be positive');

            let valid_uri = bytearray_starts_with(@token_uri, @"ipfs://")
                || bytearray_starts_with(@token_uri, @"ar://");
            assert(valid_uri, 'URI must be ipfs:// or ar://');

            let token_id = self.next_token_id.read();
            self.next_token_id.write(token_id + 1);

            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            // Write immutable provenance before minting (reentrancy-safe: Cairo is single-threaded)
            self.token_uris.write(token_id, token_uri.clone());
            self.token_licenses.write(token_id, license);
            self.token_creators.write(token_id, caller);
            self.token_registered_at.write(token_id, timestamp);

            // mint_with_acceptance_check calls onERC1155Received if recipient is a contract
            self.erc1155.mint_with_acceptance_check(recipient, token_id, amount, array![].span());

            self
                .emit(
                    IPMinted {
                        token_id,
                        recipient,
                        amount,
                        uri: token_uri,
                        creator: caller,
                        registered_at: timestamp,
                    },
                );

            token_id
        }

        /// Updates the license terms for a token type.
        /// Only the original creator can call this.
        fn set_license(ref self: ContractState, token_id: u256, license: ByteArray) {
            let creator = self.token_creators.read(token_id);
            assert(creator.is_non_zero(), 'Token does not exist');
            let caller = get_caller_address();
            assert(caller == creator, 'Only creator can set license');

            self.token_licenses.write(token_id, license.clone());
            self.emit(LicenseUpdated { token_id, creator, license });
        }

        fn get_collection_creator(self: @ContractState) -> ContractAddress {
            self.collection_creator.read()
        }

        /// Returns the original creator of a token type.
        /// Reverts if the token does not exist.
        fn get_token_creator(self: @ContractState, token_id: u256) -> ContractAddress {
            let creator = self.token_creators.read(token_id);
            assert(creator.is_non_zero(), 'Token does not exist');
            creator
        }

        /// Returns the block timestamp recorded at first mint.
        /// Reverts if the token does not exist.
        fn get_token_registered_at(self: @ContractState, token_id: u256) -> u64 {
            let creator = self.token_creators.read(token_id);
            assert(creator.is_non_zero(), 'Token does not exist');
            self.token_registered_at.read(token_id)
        }

        fn get_license(self: @ContractState, token_id: u256) -> ByteArray {
            self.token_licenses.read(token_id)
        }

        /// Returns all provenance fields for a token type in a single call.
        /// Reverts if the token does not exist.
        fn get_token_data(self: @ContractState, token_id: u256) -> TokenData {
            let creator = self.token_creators.read(token_id);
            assert(creator.is_non_zero(), 'Token does not exist');
            TokenData {
                token_id,
                metadata_uri: self.token_uris.read(token_id),
                original_creator: creator,
                registered_at: self.token_registered_at.read(token_id),
            }
        }
    }
}
