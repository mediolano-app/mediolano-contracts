Below is a detailed documentation for your `IPRevenueSharing` Cairo smart contract on Starknet. This documentation is designed to provide clarity for users and developers, explaining the contract’s purpose, functionality, and how it aligns with your project decisions (repurposing an existing NFT, using ERC-721, implementing a pull system, integrating with a separate marketplace, and handling revenue in ERC-20 tokens). It includes an overview, prerequisites, usage instructions, function descriptions, and notes on limitations and assumptions.

---

# IPRevenueSharing Contract Documentation

## Overview

The `IPRevenueSharing` contract is a Cairo-based smart contract deployed on the Starknet network, designed to enable revenue sharing for tokenized intellectual property (IP) assets. It allows users to register an existing ERC-721 NFT as an IP asset, assign fractional ownership shares, list the asset for sale in an external marketplace (e.g., Mediolano IP marketplace), and distribute revenue to fractional owners. Revenue is recorded manually by the contract owner and claimed by fractional owners using a pull-based system, ensuring scalability and flexibility.

### Key Features

- **Repurposing Existing NFTs**: Users register an existing ERC-721 NFT they own as an IP asset, associating it with metadata and fractional shares.
- **Fractional Ownership**: Ownership shares are tracked internally, allowing multiple owners to benefit from revenue without minting additional tokens.
- **Revenue Sharing**: Revenue (e.g., from sales or licensing) is recorded in ERC-20 tokens and claimed manually by fractional owners.
- **Marketplace Integration**: The contract supports listing the NFT for sale, with the assumption that an external marketplace handles the sale process.
- **Scalability**: A pull-based revenue claim system avoids gas-intensive airdrops, making it suitable for large numbers of owners.

### Project Decisions

- **Existing NFT**: Instead of minting new NFTs, the contract repurposes existing ERC-721 NFTs owned by users.
- **ERC-721 Standard**: Uses ERC-721 rather than ERC-1155, with fractional ownership managed internally.
- **Pull System**: Owners claim revenue manually, avoiding the gas cost issues of airdrops for potentially millions of owners.
- **Separate Marketplace**: Sale execution is handled by a separate marketplace contract, with this contract facilitating listing and revenue recording.
- **ERC-20 Revenue**: Revenue is distributed in fungible ERC-20 tokens, not NFTs, for practicality.

---

## Prerequisites

Before interacting with the contract, ensure you have:

- **Starknet Wallet**: A wallet compatible with Starknet (e.g., Argent X or Braavos) with funds for gas fees.
- **Existing ERC-721 NFT**: An NFT you own on a Starknet-compatible ERC-721 contract, representing your IP asset.
- **ERC-20 Tokens**: Access to the ERC-20 token used for revenue (e.g., a stablecoin or STRK), approved for transfer to the contract.
- **Contract Addresses**: The deployed addresses of:
  - `IPRevenueSharing` contract.
  - The ERC-721 NFT contract.
  - The ERC-20 token contract.
- **Marketplace**: A separate Mediolano IP marketplace contract or platform that can process NFT sales and interact with this contract.

---

## Usage Instructions

### Step 1: Register an IP Asset

- **Function**: `create_ip_asset`
- **Purpose**: Register an existing ERC-721 NFT as an IP asset and define its fractional shares.
- **Steps**:
  1. Ensure you own the NFT by checking its `owner_of` function on the ERC-721 contract.
  2. Prepare metadata and license terms as hashes (e.g., IPFS hashes).
  3. Call `create_ip_asset` with:
     - `nft_contract`: Address of the ERC-721 contract.
     - `token_id`: The NFT’s unique ID.
     - `metadata_hash`: Felt252 hash of the IP metadata.
     - `license_terms_hash`: Felt252 hash of the license terms.
     - `total_shares`: Total number of shares (e.g., 100 for 1% each).
  4. The contract assigns all shares to you initially and stores the metadata.

### Step 2: List the IP Asset for Sale

- **Function**: `list_ip_asset`
- **Purpose**: List the NFT for sale on the external marketplace.
- **Steps**:
  1. Approve the `IPRevenueSharing` contract to manage your NFT (call `approve` or `setApprovalForAll` on the ERC-721 contract with the `IPRevenueSharing` address).
  2. Call `list_ip_asset` with:
     - `nft_contract`: Address of the ERC-721 contract.
     - `token_id`: The NFT’s ID.
     - `price`: Sale price in the chosen ERC-20 token.
     - `currency_address`: Address of the ERC-20 token contract.
  3. The listing is marked active, and the marketplace can now process the sale.

### Step 3: Manage Fractional Ownership

- **Functions**: `add_fractional_owner`, `update_fractional_shares`
- **Purpose**: Assign shares to other owners or adjust existing shares (restricted to the NFT seller or contract owner).
- **Steps**:
  - **Add Owner**:
    1. Call `add_fractional_owner` with:
       - `token_id`: The NFT’s ID.
       - `owner`: Address of the new fractional owner.
    2. The owner is added to the list without shares (assign shares separately).
  - **Update Shares**:
    1. Call `update_fractional_shares` with:
       - `token_id`: The NFT’s ID.
       - `owner`: Address of the owner.
       - `new_shares`: Number of shares to assign (must not exceed `total_shares`).
    2. Ensure the sum of all shares equals `total_shares` to maintain consistency.

### Step 4: Record Revenue

- **Function**: `record_sale_revenue`
- **Purpose**: Log revenue from the IP asset (e.g., sale proceeds or licensing fees), restricted to the contract owner.
- **Steps**:
  1. Approve the ERC-20 token transfer from your wallet to the `IPRevenueSharing` contract.
  2. Call `record_sale_revenue` with:
     - `nft_contract`: Address of the ERC-721 contract.
     - `token_id`: The NFT’s ID.
     - `amount`: Revenue amount in ERC-20 tokens.
  3. The contract increases the asset’s `accrued_revenue` and stores the funds.

### Step 5: Claim Revenue

- **Function**: `claim_royalty`
- **Purpose**: Allow fractional owners to claim their share of the revenue.
- **Steps**:
  1. Call `claim_royalty` with:
     - `token_id`: The NFT’s ID.
  2. The contract calculates your share based on your `fractional_shares` and transfers the ERC-20 tokens to your wallet.

### Step 6: View Information

- **Functions**: `get_fractional_owner`, `get_fractional_owner_count`, `get_fractional_shares`, `get_contract_balance`, `get_claimed_revenue`
- **Purpose**: Check ownership, shares, or revenue details.
- **Examples**:
  - `get_fractional_shares(token_id, your_address)`: Returns your share count.
  - `get_contract_balance(currency_address)`: Shows the contract’s ERC-20 balance.

---

## Function Descriptions

| Function                     | Description                                                                      | Access Restrictions      |
| ---------------------------- | -------------------------------------------------------------------------------- | ------------------------ |
| `create_ip_asset`            | Registers an existing ERC-721 NFT as an IP asset with metadata and total shares. | NFT owner only           |
| `list_ip_asset`              | Lists the NFT for sale with a price and currency, requiring approval.            | NFT owner only           |
| `remove_listing`             | Deactivates the NFT listing.                                                     | NFT seller only          |
| `add_fractional_owner`       | Adds a new fractional owner to the list.                                         | Seller or contract owner |
| `update_fractional_shares`   | Updates an owner’s share count.                                                  | Seller or contract owner |
| `record_sale_revenue`        | Records revenue in ERC-20 tokens, increasing `accrued_revenue`.                  | Contract owner only      |
| `claim_royalty`              | Allows an owner to claim their revenue share based on their fraction.            | Fractional owners only   |
| `get_fractional_owner`       | Returns the address of a fractional owner by index.                              | Public (read-only)       |
| `get_fractional_owner_count` | Returns the number of fractional owners.                                         | Public (read-only)       |
| `get_fractional_shares`      | Returns an owner’s share count for an IP asset.                                  | Public (read-only)       |
| `get_contract_balance`       | Returns the contract’s balance in a specified ERC-20 token.                      | Public (read-only)       |
| `get_claimed_revenue`        | Returns the revenue already claimed by an owner for an IP asset.                 | Public (read-only)       |

---

## Events

- **RoyaltyClaimed**: Emitted when an owner claims revenue.
  - `token_id`: NFT ID.
  - `owner`: Claimant’s address.
  - `amount`: Claimed amount.
- **RevenueRecorded**: Emitted when revenue is recorded.
  - `token_id`: NFT ID.
  - `amount`: Revenue amount.

---

## Assumptions and Limitations

### Assumptions

- **Existing NFT**: Users must own an ERC-721 NFT before interacting with the contract.
- **Marketplace**: A separate Mediolano IP marketplace contract handles NFT sales and transfers proceeds to this contract (manually or via integration).
- **Revenue Source**: Revenue is recorded by the contract owner, implying an external process (e.g., marketplace sales) generates it.
- **ERC-20 Consistency**: All revenue uses a single ERC-20 token per listing, with consistent decimals.

### Limitations

- **No Airdrops**: Revenue distribution is pull-based (manual claims) rather than push-based (airdrops), deviating from the task’s "airdrops" criterion for scalability reasons.
- **Non-Tradeable Fractions**: Fractional shares are internal and cannot be traded as NFTs on the marketplace.
- **Manual Revenue Recording**: Relies on the contract owner to record revenue, introducing a central point of trust.
- **Marketplace Dependency**: Sale execution depends on an external contract, requiring coordination.

---

## Deployment

- **Network**: Starknet testnet.
- **Steps**:
  1. Compile the Cairo contract using the Starknet toolchain.
  2. Deploy with the constructor parameter `owner` set to the deployer’s address.
  3. Verify the deployment address and test interactions.

---

## Testing Recommendations

- **Unit Tests**:
  - Register an NFT and verify metadata and shares.
  - List and remove listings, checking state changes.
  - Add fractional owners and update shares, ensuring totals align.
  - Record revenue and claim it, validating payouts.
- **Edge Cases**:
  - Zero shares or revenue.
  - Unauthorized access attempts.
  - Maximum fractional owners.

---
