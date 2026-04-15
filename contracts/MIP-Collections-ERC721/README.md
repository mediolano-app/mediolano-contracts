# MIP-Collections-ERC721

Registry and factory contract for ERC-721 IP collections on Starknet. Each collection deploys its own standalone `IPNft` contract, keeping provenance records permanently immutable while the registry itself remains upgradeable.

## Overview

`MIP-Collections-ERC721` is the core collection management contract for the Mediolano IP protocol. It operates as both a **registry** (tracking all collections and their metadata) and a **factory** (deploying a dedicated `IPNft` ERC-721 contract per collection via `deploy_syscall`).

The two-contract architecture is intentional:

| Contract | Upgradeable | Role |
|---|---|---|
| `IPCollection` | Yes (owner only) | Registry, factory, index of all collections and stats |
| `IPNft` | No | Standalone ERC-721 — holds the immutable IP provenance record |

`IPNft` contracts are deployed once and never upgraded, preserving the legal authorship record. `IPCollection` can be upgraded to add features without touching the legal records.

## Architecture

```
IPCollection (upgradeable registry)
  ├── create_collection(name, symbol, base_uri)
  │     └── deploy_syscall → IPNft (standalone ERC-721, immutable)
  │                           ├── token_creators: Map<u256, ContractAddress>
  │                           └── token_registered_at: Map<u256, u64>
  ├── mint(collection_id, recipient, token_uri) → token_id
  ├── batch_mint(collection_id, recipients[], token_uris[]) → token_ids[]
  ├── archive(token) / batch_archive(tokens[])
  └── transfer_token(from, to, token) / batch_transfer(from, to, tokens[])
```

## Token Identifier Format

Tokens are identified by a `ByteArray` string in the format `"collection_id:token_id"`, e.g. `"3:17"`. This is parsed by `TokenTrait::from_bytes` which validates that exactly one `:` separator is present and both segments are valid decimal numbers.

## Storage

| Field | Type | Description |
|---|---|---|
| `collections` | `Map<u256, Collection>` | Collection metadata by ID |
| `collection_count` | `u256` | Total collections ever created (IDs start at 1) |
| `collection_stats` | `Map<u256, CollectionStats>` | Mint/archive/transfer counters per collection |
| `ip_nft_class_hash` | `ClassHash` | Class hash used to deploy new `IPNft` contracts |
| `user_collections` | `Map<(ContractAddress, u256), u256>` | Enumerable list of collection IDs per owner |
| `user_collection_index` | `Map<ContractAddress, u256>` | Count of collections per owner |

## Key Types

```cairo
struct Collection {
    name: ByteArray,
    symbol: ByteArray,
    base_uri: ByteArray,
    owner: ContractAddress,
    ip_nft: ContractAddress,   // address of the deployed IPNft contract
    is_active: bool,
}

struct CollectionStats {
    total_minted: u256,
    total_archived: u256,
    total_transfers: u256,
    last_mint_time: u64,
    last_archive_time: u64,
    last_transfer_time: u64,
}

struct TokenData {
    collection_id: u256,
    token_id: u256,
    owner: ContractAddress,
    metadata_uri: ByteArray,
    original_creator: ContractAddress,  // immutable — Berne Convention record
    registered_at: u64,                 // immutable — proof of creation date
}
```

## Interface

### Collection management
```cairo
fn create_collection(name, symbol, base_uri) -> u256
fn update_collection_metadata(collection_id, name, symbol, base_uri)
fn set_collection_active(collection_id, is_active)
fn get_collection(collection_id) -> Collection
fn get_collection_count() -> u256
fn get_collection_stats(collection_id) -> CollectionStats
fn is_valid_collection(collection_id) -> bool
fn is_collection_owner(collection_id, owner) -> bool
fn list_user_collections(user) -> Span<u256>
```

### Token operations
```cairo
fn mint(collection_id, recipient, token_uri) -> u256
fn batch_mint(collection_id, recipients[], token_uris[]) -> Span<u256>
fn archive(token: ByteArray)              // replaces burn — record preserved
fn batch_archive(tokens: Array<ByteArray>)
fn transfer_token(from, to, token)
fn batch_transfer(from, to, tokens[])
fn get_token(token: ByteArray) -> TokenData
fn is_valid_token(token: ByteArray) -> bool
fn list_user_tokens_per_collection(collection_id, user) -> Span<u256>
```

### Admin
```cairo
fn upgrade(new_class_hash)               // IPCollection owner only
fn upgrade_ip_nft_class_hash(new_class_hash)  // updates future IPNft deploys only
```

## Events

| Event | Key fields |
|---|---|
| `CollectionCreated` | collection_id, owner, name, symbol, base_uri |
| `CollectionUpdated` | collection_id, owner, name, symbol, base_uri, timestamp |
| `TokenMinted` | collection_id, token_id, owner, metadata_uri |
| `TokenMintedBatch` | collection_id, token_ids, owners, operator, timestamp |
| `TokenArchived` | collection_id, token_id, operator, timestamp |
| `TokenArchivedBatch` | tokens, operator, timestamp |
| `TokenTransferred` | collection_id, token_id, operator, timestamp |
| `TokenTransferredBatch` | from, to, tokens, operator, timestamp |

## Archive vs Burn

This contract uses **archive** instead of ERC-721 burn. Archiving marks a token as inactive while preserving the on-chain provenance record — the original creator address and registration timestamp in the `IPNft` contract are never deleted. This satisfies the Berne Convention requirement that IP authorship records be permanent.

## Transfer Flow

Transfers go through `IPCollection` (not directly through the `IPNft`). Before calling `transfer_token` or `batch_transfer`, the caller must have approved `IPCollection`'s contract address on the `IPNft`. The caller must also be the token owner or an approved operator.

## Deployments

| Network | Contract | Address |
|---|---|---|
| Mainnet | `IPCollection` (registry) | `0x05c49ee5d3208a2c2e150fdd0c247d1195ed9ab54fa2d5dea7a633f39e4b205b` |
| Mainnet | `IPNft` (class) | `0x02e24999206d088a7fc311d05a791c865b1283251c7f15f7c097b84a90feee56` |

## Development

```bash
cd contracts/MIP-Collections-ERC721

# Build
scarb build

# Run all tests
scarb test

# Run a specific test
snforge test test_create_collection
```

## Dependencies

| Package | Version |
|---|---|
| `starknet` | `2.12.0` |
| `openzeppelin` | `v0.20.0` |
| `snforge_std` | `0.58.0` |
