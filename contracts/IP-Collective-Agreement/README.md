# IP Collective Agreement

A multi-owner ERC-1155 contract for registering collectively-held IP assets with governance proposals, royalty distribution, and dispute resolution.

## Overview

`IPCollectiveAgreement` extends ERC-1155 to support IP assets with multiple co-owners, each holding a share out of 1000 (basis points representing 100%). The contract owner registers IP assets and distributes royalties proportionally. Co-owners can create governance proposals with 7-day voting windows; proposals require >50% share-weighted votes to execute. A designated dispute resolver can record resolution outcomes.

The contract exposes six separate interface modules: `IIPAssetManager`, `IOwnershipRegistry`, `IRevenueDistribution`, `ILicenseManager`, `IGovernance`, and `IBerneCompliance`.

## Storage

| Field | Type | Description |
|---|---|---|
| `ip_data` | `Map<u256, IPData>` | IP metadata, owner count, royalty rate, expiry |
| `owners` | `Map<(u256, u32), ContractAddress>` | Owners indexed by (token_id, index) |
| `ownership_shares` | `Map<(u256, ContractAddress), u256>` | Share out of 1000 per owner |
| `proposals` | `Map<u256, Proposal>` | Governance proposals |
| `votes` | `Map<(u256, ContractAddress), bool>` | Whether an address has voted |
| `dispute_resolver` | `ContractAddress` | Address authorized to resolve disputes |

## Interface / Functions

```cairo
fn register_ip(ref self, token_id, metadata_uri, owners, ownership_shares, royalty_rate, expiry_date, license_terms)  // owner-only
fn distribute_royalties(ref self, token_id: u256, total_amount: u256)  // owner-only
fn create_proposal(ref self, token_id: u256, description: ByteArray)  // any co-owner
fn vote(ref self, token_id: u256, proposal_id: u256, support: bool)  // any co-owner
fn execute_proposal(ref self, token_id: u256, proposal_id: u256)  // anyone after deadline
fn resolve_dispute(ref self, token_id: u256, resolution: ByteArray)  // dispute_resolver only
fn get_ip_metadata(self: @, token_id: u256) -> IPData
fn get_owner(self: @, token_id: u256, index: u32) -> ContractAddress
fn get_ownership_share(self: @, token_id: u256, owner: ContractAddress) -> u256
fn get_proposal(self: @, proposal_id: u256) -> Proposal
fn set_dispute_resolver(ref self, new_resolver: ContractAddress)  // owner-only
```

## Events

`IPRegistered`, `RoyaltyDistributed`, `ProposalCreated`, `Voted`, `ProposalExecuted`, `DisputeResolved`

## Development

```bash
cd contracts/IP-Collective-Agreement
scarb build
scarb test
```

## Dependencies

| Package | Version |
|---|---|
| `starknet` | 2.9.2 |
| `openzeppelin` | v0.20.0 (git) |
| `snforge_std` (dev) | v0.30.0 (git) |
