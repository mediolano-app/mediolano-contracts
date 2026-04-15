# IP Club

A two-contract system for permissionless NFT-gated IP communities on Starknet. Each club deploys a dedicated `IPClubNFT` ERC-721 contract; membership is proven by NFT ownership.

## Overview

`IPClub` manages community creation, membership validation, and optional entry fees. When a creator calls `create_club`, a dedicated `IPClubNFT` ERC-721 contract is deployed via `deploy_syscall`. Users join by calling `join_club`, which collects the entry fee (if any) and mints a membership NFT. The registry is upgradeable; `IPClubNFT` contracts are immutable once deployed.

## Contracts

| Contract | Upgradeable | Role |
|---|---|---|
| `IPClub` | Yes | Registry — creates clubs, validates membership, collects fees |
| `IPClubNFT` | No | Per-club ERC-721 — minting restricted to its `IPClub` manager |

## Key Types

```cairo
struct ClubRecord {
    id: u256,
    name: ByteArray,
    symbol: ByteArray,
    metadata_uri: ByteArray,
    status: ClubStatus,      // Inactive | Open | Closed
    num_members: u256,
    creator: ContractAddress,
    club_nft: ContractAddress,
    max_members: Option<u256>,
    entry_fee: Option<u256>,
    payment_token: ContractAddress,
}
```

## Interface

### IPClub

```cairo
fn create_club(name, symbol, metadata_uri, max_members, entry_fee, payment_token) -> u256
fn join_club(club_id)
fn close_club(club_id)
fn get_club_record(club_id) -> ClubRecord
fn is_member(club_id, user) -> bool
fn get_last_club_id() -> u256
fn upgrade(new_class_hash)   // owner only
```

### IPClubNFT

```cairo
fn mint(recipient)              // IPClub manager only
fn has_nft(user) -> bool
fn get_nft_creator() -> ContractAddress
fn get_ip_club_manager() -> ContractAddress
fn get_associated_club_id() -> u256
fn get_last_minted_id() -> u256
```

## Events

| Event | Description |
|---|---|
| `NewClubCreated` | Emitted when a club is created |
| `NewMember` | Emitted when a user joins |
| `ClubClosed` | Emitted when a creator closes a club |
| `NFTMinted` | Emitted by `IPClubNFT` on mint |

## Example Flow

1. Deploy `IPClub` with `(admin, ip_club_nft_class_hash)`.
2. Creator calls `create_club(...)` — an `IPClubNFT` is deployed automatically.
3. Users call `join_club(club_id)` — entry fee is collected, membership NFT minted.
4. Any contract can gate access with `is_member(club_id, user)`.
5. Creator calls `close_club(club_id)` to stop new members.

## Development

```bash
cd contracts/IP-Club

# Build
scarb build

# Test
scarb test
```

## Dependencies

| Package | Version |
|---|---|
| `starknet` | `2.9.1` |
| `openzeppelin` | `v0.17.0` |
| `snforge_std` | `0.31.0` |

> **Status: Pre-production.** This contract has not been audited. Do not use in production without a security review.
