# IP Collection for Digital Assets - Cairo Smart Contract ERC-721

To develop a Cairo smart contract to manage an IP collection of digital assets, following the ERC-721 standard. This smart contract should enable the basic functionalities to Mint, List, View, and Transfer these assets, with the metadata being stored in IPFS. Architecture of the contract should be able to keep each user’s NFTs IDs to use them futurely for licensing, exhibiting, etc.

### Requirements:

Minting: Ability to mint new tokens.
Listing: Ability to list all tokens owned by a specific address.
Viewing: Ability to view details of a specific token, including metadata.
Transferring: Ability to transfer tokens between addresses.
Metadata URI: All metadata should be stored in IPFS.

### Criteria:

The smart contract must be written in Cairo.
Conforms to the ERC-721 standard.
Implements functions for Minting, Listing, Viewing, and Transferring tokens.
Metadata is stored in IPFS and properly linked to the tokens.
Include unit tests to ensure all functionalities work as expected.

### Additional Information:

Please refer to the ERC-721 standard documentation for details on the required functionalities.
Ensure that the contract is optimized for efficiency and security.
Provide comprehensive documentation for the smart contract code.

![Mediolano.app](https://mediolano.app/wp-content/uploads/2024/09/mediolano-logo-dark-1.svg)

> [!IMPORTANT]
> Mediolano dapp is in constant development and the current version runs on Starknet's Sepolia devnet. Use for testing purposes only.

IP Collection ERC-721
This repository contains an ERC-721 compliant NFT contract for IP Collections, implemented on StarkNet using Cairo.
Overview
The IPCollection contract enables users to:

    Create NFT collections with a name, symbol, and base URI.
    Mint NFTs within a specific collection.
    Burn NFTs.
    Transfer NFTs between addresses.
    List a user's collections and tokens.
    Retrieve details of collections and tokens.

Features

    ERC-721 Compliance: Utilizes OpenZeppelin's ERC-721 components for StarkNet.
    Collections: Supports creating and managing multiple NFT collections.
    Token Metadata: Stores metadata URIs for tokens, linked to their collections.
    Ownership and Access Control: Uses OpenZeppelin's Ownable component for restricted access (e.g., minting).
    Events: Emits CollectionCreated and TokenMinted events for tracking.
    Testing: Includes unit tests for key functionalities.

Contract Details
Main Components

    IIPCollection Interface: Defines core contract functions.
    Storage: Manages collections, tokens, and ownership mappings.
    Events: Custom events for collection and token creation, plus ERC-721 standard events.

Key Functions

    create_collection: Creates a new NFT collection.
    mint: Mints a new NFT in a specified collection.
    burn: Burns an existing NFT.
    transfer_token: Transfers an NFT between addresses.
    list_user_collections: Lists collections owned by a user.
    list_user_tokens: Lists tokens owned by a user.
    get_collection: Retrieves details of a collection.
    get_token: Retrieves details of a token.

Installation and Deployment

    Prerequisites:
        Install asdf for version management.
        Install the StarkNet toolchain and Cairo compiler.
        Install snforge for testing.
    Set Up asdf and Scarb:
    Set the local Scarb version using asdf:
    bash

    asdf local scarb 2.9.2

    Clone the Repository:
    bash

    git clone <repository-url>
    cd contracts/IP-collection-ERC-721

    Build the Contract:
    Build the contract using Scarb:
    bash

    scarb build

    Deploy the Contract:
    Deploy to a StarkNet network using a deployment tool like starknet-deploy.

Testing
The contract includes tests in src/test/IPCollectionTest.cairo. To run them:

    Ensure snforge is installed.
    Execute the tests:
    bash

    snforge test

Test Cases

    test_create_collection_zero_address: Rejects collection creation from a zero address.
    test_mint_not_owner: Ensures only the owner can mint tokens.
    test_mint_zero_recipient: Rejects minting to a zero address.
    test_mint_zero_caller: Rejects minting from a zero address.
    test_burn_not_owner: Ensures only the token owner can burn a token.
    test_transfer_token_not_approved: Requires approval for token transfers.
    test_transfer_token_zero_caller: Rejects transfers from a zero address.

Commit History

    May 12, 2025: Enhancement: IP Collection ERC-721 (@anonfedora
    )
        Added collection support and improved token management.
        Updated tests for new functionality.
        269 additions, 42 deletions.

License
This project is licensed under the MIT License.
Let me know if you'd like further adjustments!
