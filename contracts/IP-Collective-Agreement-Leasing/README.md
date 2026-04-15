# IP Collective Agreement Leasing

An ERC-1155 contract for collectively-owned IP assets with governance proposals, royalty distribution, dispute resolution, and time-bounded leasing.

## Overview

`CollectiveIPAgreement` combines ERC-1155 multi-token ownership with multi-party IP governance. Multiple co-owners hold shares (out of 1000) in each IP token. The contract owner registers IP assets and distributes royalties. Co-owners vote on proposals weighted by their share; proposals require >50% share to execute after a 7-day window. A designated dispute resolver can emit resolution records.

This contract is structurally identical to `IP-Collective-Agreement` with updated tooling versions.

## Storage

| Field | Type | Description |
|---|---|---|
| `ip_data` | `Map<u256, IPData>` | IP metadata, owner count, royalty rate, expiry |
| `owners` | `Map<(u256, u32), ContractAddress>` | Owners indexed by (token_id, index) |
| `ownership_shares` | `Map<(u256, ContractAddress), u256>` | Share out of 1000 per owner |
| `proposals` | `Map<u256, Proposal>` | Governance proposals |
| `votes` | `Map<(u256, ContractAddress), bool>` | Vote record per proposal/voter |
| `dispute_resolver` | `ContractAddress` | Authorized dispute resolution address |

## Interface / Functions

```cairo
fn register_ip(ref self, token_id, metadata_uri, owners, ownership_shares, royalty_rate, expiry_date, license_terms)  // owner-only
fn distribute_royalties(ref self, token_id: u256, total_amount: u256)  // owner-only
fn create_proposal(ref self, token_id: u256, description: ByteArray)
fn vote(ref self, token_id: u256, proposal_id: u256, support: bool)
fn execute_proposal(ref self, token_id: u256, proposal_id: u256)
fn resolve_dispute(ref self, token_id: u256, resolution: ByteArray)  // resolver-only
fn get_ip_metadata / get_owner / get_ownership_share / get_proposal / get_total_supply
fn set_dispute_resolver(ref self, new_resolver: ContractAddress)  // owner-only
```

## Events

`IPRegistered`, `RoyaltyDistributed`, `ProposalCreated`, `Voted`, `ProposalExecuted`, `DisputeResolved`

## Development

```bash
cd contracts/IP-Collective-Agreement-Leasing
scarb build
scarb test
```

## Dependencies

| Package | Version |
|---|---|
| `starknet` | 2.9.2 |
| `openzeppelin` | v0.20.0 (git) |
| `snforge_std` (dev) | 0.36.0 |
