The task is about developing a Cairo smart contract for minting new digital assets derived from existing NFTs in the Mediolano.app portfolio. The goal is to enable the creation of new assets, each having a programmable licensing feature, and storing their metadata securely in IPFS. The contract should also integrate well with the existing Mediolano system and be secure.

Here's a breakdown of the task:

Core Features:
Minting New Digital Assets: The contract will mint new digital assets based on pre-existing NFTs. This means new assets are derived or created using data from existing NFTs in the Mediolano portfolio.

Programmable Licensing: The licensing of these new assets should be programmable, which means the terms of use, ownership rights, and other licensing conditions can be customized for each new asset. This is more flexible than the standard licensing models.

Metadata in IPFS: The metadata for these new assets will be stored on IPFS (InterPlanetary File System), a decentralized storage system. This ensures the data is persistent, secure, and accessible by anyone who interacts with the assets.

Seamless Integration with Mediolano.app: The smart contract needs to work seamlessly with the existing Mediolano platform, meaning it must integrate well with the current system’s architecture and features.

Security: The contract must follow best security practices to prevent vulnerabilities, ensuring the digital assets and licensing mechanisms are secure.

Criteria:
The smart contract should be written in Cairo, the programming language for StarkNet, and must adhere to best practices in terms of both security and efficiency.
It should implement the necessary functions to handle programmable licensing.
The contract should properly handle and store metadata in IPFS.
Integration with Mediolano's existing NFTs is crucial, meaning the contract should recognize and work with the current NFTs.
Comprehensive Documentation must be provided to explain the code and its usage to developers and users.
Next Steps:
To approach this, you'll need to:

Review the ERC-721 standard since the digital assets are likely NFTs.
Define how the programmable licensing will work (e.g., licensing terms, permissions, and flexibility).
Ensure that the IPFS integration is smooth and the data is properly linked to the digital assets.
Implement the contract with a focus on security, such as protection against common attacks like reentrancy, and ensure it’s efficient to minimize gas costs.
Write detailed documentation for the contract.
This will enable Mediolano.app users to create new, licensed digital assets from existing NFTs with fully programmable and secure terms.

fn mint_license_nft(
ref self: ContractState,
recipient: ContractAddress,
original_nft_id: u256,
license_type: u8,
royalty_rate: u256,
sublicensing: bool,
metadata_cid: String,
) {
assert(resipient.is_non_zero(), "INVALID_ADDRESS: Address cannot be zero");
assert(original_nft_id > 0, "INVALID_ORIGINAL_NFT_ID: Original NFT ID must be valid");
assert(royalty_rate <= 100, "INVALID_ROYALTY_RATE: Must be between 0 and 100");

            // Check if the caller owns the original NFT
            let caller = get_caller_address();
            let nft_owner = self.erc721.owner_of(original_nft_id);
            assert(
                caller == nft_owner, "UNAUTHORIZED: Caller is not the owner of the original NFT"
            );

            // Generate a new token ID
            let new_token_id = self.last_minted_id.read() + 1;

            // Mint the derived NFT
            self.erc721.mint(owner, new_token_id);

            // Record the timestamp of minting
            let timestamp = get_block_timestamp();

            // Update storage mappings
            self.user_token_id.write(owner, new_token_id);
            self.mint_timestamp.write(new_token_id, timestamp);
            self.original_to_derived.write(original_nft_id, new_token_id);

            // Add licensing data for the derived NFT
            let license_details = LicenseDetails {
                license_type,
                royalty_rate,
                sublicensing,
                metadata_cid,
            };
            self.licensing_data.write(new_token_id, license_details);

            // Update the last minted ID
            self.last_minted_id.write(new_token_id);

            // Emit an event
            LicensingEvent {
                token_id: new_token_id,
                original_nft_id,
                license_type,
                royalty_rate,
                sublicensing,
                metadata_cid,
                timestamp,
            }
            .emit();
        }
