# IP Bulk Tokenization

A batch IP-asset tokenizer that mints multiple ERC-721 tokens in a single transaction by delegating to an external NFT contract.

## Overview

`IPTokenizer` accepts arrays of `IPAssetData` structs, validates each asset's type and license terms, stores metadata on-chain, and calls `mint` on a linked IPNFT contract for each asset. Batches are tracked by ID with status flags (pending / processing / completed / failed). The contract is pausable and owned, with a configurable batch-size limit.

Asset types: `Patent`, `Trademark`, `Copyright`, `TradeSecret`.
License terms: `Standard`, `Premium`, `Exclusive`, `Custom`.

## Storage

| Field | Type | Description |
|---|---|---|
| `nft_contract` | `ContractAddress` | Address of the companion IPNFT ERC-721 contract |
| `batch_limit` | `u32` | Maximum assets per batch (default from constants) |
| `batch_counter` | `u256` | Auto-incrementing batch ID |
| `batch_status` | `Map<u256, u8>` | 0=pending, 1=processing, 2=completed, 3=failed |
| `tokens` | `Map<u256, IPAssetData>` | On-chain metadata per token ID |
| `token_counter` | `u256` | Auto-incrementing token ID |
| `gateway` | `ByteArray` | IPFS gateway base URL |

## Interface / Functions

```cairo
fn bulk_tokenize(ref self, assets: Array<IPAssetData>) -> Array<u256>
```
Validates and mints all assets in one call. Returns the array of minted token IDs.

```cairo
fn get_token_metadata(self: @, token_id: u256) -> IPAssetData
fn get_token_owner(self: @, token_id: u256) -> ContractAddress
fn get_token_expiry(self: @, token_id: u256) -> u64
fn update_metadata(ref self, token_id: u256, new_metadata: ByteArray)   // owner-only
fn update_license_terms(ref self, token_id: u256, new_terms: LicenseTerms)  // owner-only
fn transfer_token(ref self, token_id: u256, to: ContractAddress)  // owner-only
fn get_batch_status(self: @, batch_id: u256) -> u8
fn get_batch_limit(self: @) -> u32
fn set_batch_limit(ref self, new_limit: u32)  // owner-only
fn set_paused(ref self, paused: bool)  // owner-only
fn get_ipfs_gateway(self: @) -> ByteArray
fn set_ipfs_gateway(ref self, gateway: ByteArray)  // owner-only
fn get_hash(self: @, token_id: u256) -> ByteArray
```

## Events

| Event | Fields |
|---|---|
| `BatchProcessed` | `batch_id`, `token_ids` |
| `BatchFailed` | `batch_id`, `reason` |
| `TokenMinted` | `token_id`, `owner` |
| `TokenTransferred` | `token_id`, `from`, `to` |

## Development

```bash
cd contracts/IP-Bulk-Tokenization
scarb build
scarb test
```

## Dependencies

| Package | Version |
|---|---|
| `starknet` | 2.8.4 |
| `openzeppelin` | v0.20.0 (git) |
| `snforge_std` (dev) | v0.34.0 (git) |
