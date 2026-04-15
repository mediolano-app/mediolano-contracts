# IP Airdrop

An ERC-721 NFT airdrop contract that distributes IP asset tokens to recipients via an owner-managed whitelist or Merkle proof verification.

## Overview

`NFTAirdrop` is an ownable ERC-721 contract that supports two distribution paths: the owner can whitelist addresses with token quantities and trigger a bulk airdrop, or recipients can self-claim by presenting a valid Merkle proof. Leaf hashes are computed using double Pedersen hashing of `(address, amount)`.

## Storage

| Field | Type | Description |
|---|---|---|
| `merkle_root` | `felt252` | Root of the Merkle tree for proof-based claims |
| `next_token_id` | `u256` | Auto-incrementing token ID counter (starts at 1) |
| `whitelists` | `Vec<(ContractAddress, u32)>` | List of (address, remaining allocation) pairs |

## Interface / Functions

```cairo
fn whitelist(ref self, to: ContractAddress, amount: u32)
```
Owner-only. Adds or updates a whitelist entry for `to` with `amount` tokens.

```cairo
fn whitelist_balance_of(self: @, to: ContractAddress) -> u32
```
Returns the pending whitelist allocation for `to`.

```cairo
fn airdrop(ref self)
```
Owner-only. Iterates the whitelist and batch-mints tokens to each entry with a non-zero amount, then resets their allocation to zero.

```cairo
fn claim_with_proof(ref self, proof: Span<felt252>, amount: u32)
```
Allows a caller to claim tokens by submitting a Merkle proof that verifies `(caller, amount)` against the stored root.

## Events

Inherits standard ERC-721 events (`Transfer`, `Approval`, `ApprovalForAll`) and `OwnableComponent` events via OpenZeppelin components.

## Development

```bash
cd contracts/IP-Airdrop
scarb build
scarb test
```

## Dependencies

| Package | Version |
|---|---|
| `starknet` | 2.9.4 |
| `openzeppelin_token` | 1.0.0 |
| `openzeppelin_access` | 1.0.0 |
| `openzeppelin_introspection` | 1.0.0 |
| `openzeppelin_merkle_tree` | 1.0.0 |
| `snforge_std` (dev) | 0.34.0 |
