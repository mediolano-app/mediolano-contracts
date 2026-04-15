# IP Collection ERC-721

An ownable, enumerable, upgradeable ERC-721 collection contract for IP assets with per-user token tracking via Alexandria storage lists.

## Overview

`IPCollection` is a fully OZ-component-based ERC-721 contract. The owner can mint tokens to any recipient; any holder can burn or transfer. A `List<u256>` in Alexandria storage tracks each user's owned token IDs for efficient enumeration. The contract supports upgrades via `UpgradeableComponent`.

## Storage

| Field | Type | Description |
|---|---|---|
| `token_id_count` | `u256` | Auto-incrementing token ID counter |
| `user_tokens` | `Map<ContractAddress, List<u256>>` | Per-address list of owned token IDs |

Plus `ERC721Component`, `ERC721EnumerableComponent`, `OwnableComponent`, and `UpgradeableComponent` substorages.

## Interface / Functions

```cairo
fn mint(ref self, recipient: ContractAddress) -> u256
```
Owner-only. Mints the next token ID to `recipient` and appends the ID to their token list.

```cairo
fn burn(ref self, token_id: u256)
```
Burns `token_id` by transferring to the zero address.

```cairo
fn list_user_tokens(self: @, owner: ContractAddress) -> Array<u256>
```
Returns the array of token IDs held by `owner`.

```cairo
fn transfer_token(ref self, from: ContractAddress, to: ContractAddress, token_id: u256)
```
Transfers `token_id` via the ERC-721 component. Requires the contract itself to be approved.

```cairo
fn upgrade(ref self, new_class_hash: ClassHash)
```
Owner-only. Upgrades the contract to a new class hash.

## Development

```bash
cd contracts/IP-collection-ERC-721
scarb build
scarb test
```

## Dependencies

| Package | Version |
|---|---|
| `starknet` | 2.12.0 |
| `openzeppelin` | 0.20.0 (git) |
| `alexandria_storage` | git (keep-starknet-strange) |
| `snforge_std` (dev) | 0.58.0 |
