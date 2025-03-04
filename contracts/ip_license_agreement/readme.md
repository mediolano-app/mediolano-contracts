# Proof of IP Licensing Smart Contracts

This project implements a system for creating and managing intellectual property
licensing agreements on the Starknet blockchain. The system allows for the
creation of public licensing agreements between different web3 users through
Starknet wallet addresses, providing public consultation and visibility.

## Features

- Create and manage licensing agreements for intellectual property
- Allow designated addresses to sign the contract
- Store signatures, addresses, and contract metadata publicly
- Enable the contract owner to approve the immutability of the contract,
  generating a Proof of Licensing
- Provide functions to consult the public data of the immutable contract

## Architecture

The system consists of two main contracts:

1. **IPLicensingFactory**: A factory contract that deploys and manages
   individual licensing agreement contracts.
2. **IPLicensingAgreement**: A contract representing a single licensing
   agreement, which handles signatures and immutability.

### IPLicensingFactory

The factory contract is responsible for:

- Deploying new licensing agreement contracts
- Keeping track of all agreements
- Mapping agreements to users
- Providing functions to query agreements

### IPLicensingAgreement

The agreement contract is responsible for:

- Storing agreement metadata (title, description, IP metadata)
- Managing signers and signatures
- Handling the immutability of the agreement
- Providing functions to query agreement data

## Usage

### Creating a New Agreement

To create a new licensing agreement:

1. Call the `create_agreement` function on the factory contract with:
   - `title`: Title of the agreement
   - `description`: Description of the agreement
   - `ip_metadata`: Metadata about the intellectual property
   - `signers`: Array of Starknet addresses that are allowed to sign the
     agreement

The function returns the agreement ID and the address of the deployed agreement
contract.

### Signing an Agreement

To sign an agreement:

1. Call the `sign_agreement` function on the agreement contract.

Note: Only addresses that were specified as signers during creation can sign the
agreement.

### Making an Agreement Immutable

Once all parties have signed the agreement, the owner can make it immutable:

1. Call the `make_immutable` function on the agreement contract.

This generates a Proof of Licensing by making the agreement immutable on the
blockchain.

### Querying Agreement Data

The following functions are available to query agreement data:

- `get_metadata`: Returns the basic metadata of the agreement
- `get_additional_metadata`: Returns additional metadata by key
- `is_signer`: Checks if an address is a signer
- `has_signed`: Checks if an address has signed
- `get_signature_timestamp`: Gets the timestamp of a signature
- `get_signers`: Gets all signers
- `is_fully_signed`: Checks if all signers have signed
- `get_owner`: Gets the owner of the agreement

## Testing

The contracts include comprehensive tests that verify:

- Factory deployment
- Agreement creation
- Agreement signing
- Making agreements immutable
- Error handling for invalid operations

To run the tests:

```bash
scarb test
```

## Security Considerations

The contracts implement several security measures:

- Only designated signers can sign agreements
- Only the owner can make an agreement immutable
- Once immutable, an agreement cannot be modified
- Signatures are timestamped and stored on-chain
- All operations emit events for transparency

## License

This project is licensed under the MIT License - see the LICENSE file for
details.

# New IP Licensing - Cairo Smart Contract

Cairo smart contract that enables the minting of new digital assets with
programmable licensing. These new assets will be derived from pre-existing NFT
assets in the Mediolano.app portfolio.

Requirements:

Minting New Assets: Ability to mint new digital assets derived from existing
NFTs. Programmable Licensing: Implement programmable licensing for these new
assets. Metadata Storage in IPFS, ensuring it is linked to the digital assets.
Integration: Ensure the smart contract integrates seamlessly with the existing
Mediolano.app portfolio. Security: Implement security measures to protect the
assets and the licensing process.

Criteria:

The smart contract is written in Cairo and follows best practices for security
and efficiency. Implements functions for digital assets with programmable
licensing. Metadata stored in IPFS is properly linked. The smart contract
integrates smoothly with the existing NFT assets in the Mediolano.app portfolio.
Comprehensive documentation is provided for the smart contract code and its
usage.

Additional Information:

Refer to the ERC-721 standard documentation for details on the functionalities.
Ensure that the programmable licensing feature is flexible and can accommodate
various licensing terms. Provide detailed documentation to help developers and
users understand and utilize the new features.

![Mediolano.app](https://mediolano.app/wp-content/uploads/2024/09/mediolano-logo-dark-1.svg)

> [!IMPORTANT]
> Mediolano dapp is in constant development and the current version runs on
> Starknet's Sepolia devnet. Use for testing purposes only.
