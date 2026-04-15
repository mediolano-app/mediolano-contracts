# IP Assets Visibility

A lightweight contract that lets IP asset owners set and query per-asset visibility flags on-chain.

## Overview

`VisibilityManagement` stores a `u8` visibility status (0 = hidden, 1 = visible) keyed by `(token_address, asset_id, owner)`. Any address can set its own visibility preference for any token/asset pair. There are no access controls beyond the implicit ownership of the caller address.

> **Note:** This contract has no OpenZeppelin dependencies and no tests. It is a minimal prototype.

## Storage

| Field | Type | Description |
|---|---|---|
| `visibility` | `Map<(ContractAddress, u256, ContractAddress), u8>` | Visibility flag per token, asset, and owner |

## Interface / Functions

```cairo
fn set_visibility(ref self, token_address: ContractAddress, asset_id: u256, visibility_status: u8)
```
Sets the caller's visibility preference for the given token/asset. `visibility_status` must be 0 or 1.

```cairo
fn get_visibility(self: @, token_address: ContractAddress, asset_id: u256, owner: ContractAddress) -> u8
```
Returns the visibility status for the given token/asset/owner combination.

## Events

| Event | Fields |
|---|---|
| `VisibilityChanged` | `token_address`, `asset_id`, `owner`, `visibility_status` |

## Development

```bash
cd contracts/IP-Assets-Visibility
scarb build
scarb test
```

## Dependencies

| Package | Version |
|---|---|
| `starknet` | 2.9.2 |
| `snforge_std` (dev) | 0.35.1 |
