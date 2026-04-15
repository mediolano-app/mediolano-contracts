# IP Colab Collections

A collaborative IP collection contract where contributors submit creative assets for verifier review before NFT minting, with built-in marketplace listing and co-creator royalty support.

## Overview

`IPCollection` manages a multi-step lifecycle for collaborative IP: contributors submit asset URIs grouped into typed contribution categories, authorized verifiers score and approve/reject submissions, and verified contributions can then be minted as NFTs. Minted contributions can be listed for sale and assigned a single co-creator with a royalty percentage.

> **Note:** No OpenZeppelin dependencies are used. NFT minting emits an event but does not call an external ERC-721 contract — actual token issuance is event-driven. No tests present.

## Storage

| Field | Type | Description |
|---|---|---|
| `contributions` | `Map<u256, Contribution>` | Contribution records keyed by ID |
| `verifiers` | `Map<ContractAddress, bool>` | Authorized verifier addresses |
| `contribution_types` | `Map<felt252, ContributionType>` | Type definitions with quality floor and supply cap |
| `type_counts` | `Map<felt252, u256>` | Number of submissions per type |

## Interface / Functions

```cairo
fn submit_contribution(ref self, asset_uri: felt252, metadata: felt252, contribution_type: felt252)
fn batch_submit_contributions(ref self, assets: Array<felt252>, metadatas: Array<felt252>, types: Array<felt252>)
fn verify_contribution(ref self, contribution_id: u256, verified: bool, quality_score: u8)
fn mint_nft(ref self, contribution_id: u256, recipient: ContractAddress)
fn list_contribution(ref self, contribution_id: u256, price: u256)
fn unlist_contribution(ref self, contribution_id: u256)
fn update_price(ref self, contribution_id: u256, new_price: u256)
fn add_co_creator(ref self, contribution_id: u256, co_creator: ContractAddress, royalty_percentage: u8)
fn register_contribution_type(ref self, type_id: felt252, min_quality_score: u8, submission_deadline: u64, max_supply: u256)  // owner-only
fn add_verifier(ref self, verifier: ContractAddress)  // owner-only
fn remove_verifier(ref self, verifier: ContractAddress)  // owner-only
fn get_contribution(self: @, contribution_id: u256) -> Contribution
fn get_contributions_count(self: @) -> u256
fn get_contributor_contributions(self: @, contributor: ContractAddress) -> Array<u256>
```

## Events

`ContributionSubmitted`, `ContributionVerified`, `NFTMinted`, `BatchSubmitted`, `TypeRegistered`, `ContributionListed`, `ContributionUnlisted`, `PriceUpdated`, `CoCreatorAdded`, `VerifierAdded`, `VerifierRemoved`

## Development

```bash
cd contracts/IP-Colab-Collections
scarb build
scarb test
```

## Dependencies

| Package | Version |
|---|---|
| `starknet` | 2.8.5 |
| `snforge_std` (dev) | v0.27.0 (git) |
