# IP Assignment

A programmable IP rights assignment contract that supports conditional grants, exclusivity, partial rights percentages, and royalty distribution to assignees.

## Overview

`IPAssignment` lets IP owners register arbitrary IP identifiers (felt252 keys), assign rights to other addresses with configurable conditions (time window, exclusivity, rights percentage, royalty rate), and track royalty balances. Assignment validity is time-bound and enforced on each royalty distribution call. Royalties are credited to per-assignee balances tracked in storage; actual token transfers are left as a stub for integration with a token contract.

> **Note:** The `withdraw_royalties` function records balances but does not perform an actual token transfer. No tests are present.

## Storage

| Field | Type | Description |
|---|---|---|
| `contract_owner` | `ContractAddress` | Admin address |
| `ip_owner` | `Map<felt252, ContractAddress>` | Owner per IP identifier |
| `assignments` | `Map<(felt252, ContractAddress), AssignmentData>` | Assignment conditions per IP/assignee |
| `exclusive_assignee` | `Map<felt252, ContractAddress>` | Exclusive rights holder per IP |
| `total_assigned_rights` | `Map<felt252, u8>` | Total percentage of rights assigned (max 100) |
| `royalty_balances` | `Map<(felt252, ContractAddress), u128>` | Accrued royalties per IP/beneficiary |

## Interface / Functions

```cairo
fn create_ip(ref self, ip_id: felt252)
```
Registers a new IP under the caller. Reverts if the ID is already taken.

```cairo
fn transfer_ip_ownership(ref self, ip_id: felt252, new_owner: ContractAddress)
```
Transfers IP ownership to `new_owner`. Caller must be current owner.

```cairo
fn assign_ip(ref self, ip_id: felt252, assignee: ContractAddress, conditions: AssignmentData)
```
Grants rights to `assignee` with the given conditions. Enforces exclusivity and rights-percentage limits.

```cairo
fn receive_royalty(ref self, ip_id: felt252, amount: u128)
```
Distributes `amount` across active assignees proportional to their royalty rates, crediting balances in storage.

```cairo
fn withdraw_royalties(ref self, ip_id: felt252)
```
Resets the caller's royalty balance to zero (transfer logic is a stub).

```cairo
fn get_assignment_data(self: @, ip_id: felt252, assignee: ContractAddress) -> AssignmentData
fn check_assignment_condition(ref self, ip_id: felt252, assignee: ContractAddress) -> bool
fn get_ip_owner(self: @, ip_id: felt252) -> ContractAddress
fn get_royalty_balance(self: @, ip_id: felt252, beneficiary: ContractAddress) -> u128
```

## Events

| Event | Key Fields |
|---|---|
| `IPCreated` | `ip_id`, `owner`, `timestamp` |
| `IPAssigned` | `ip_id`, `assignee`, `conditions` |
| `IPOwnershipTransferred` | `ip_id`, `previous_owner`, `new_owner` |
| `RoyaltyReceived` | `ip_id`, `amount`, `recipient` |
| `RoyaltyWithdrawn` | `ip_id`, `beneficiary`, `amount` |

## Development

```bash
cd contracts/IP-Assignment
scarb build
scarb test
```

## Dependencies

| Package | Version |
|---|---|
| `starknet` | 2.10.1 |
| `snforge_std` (dev) | 0.38.0 |
