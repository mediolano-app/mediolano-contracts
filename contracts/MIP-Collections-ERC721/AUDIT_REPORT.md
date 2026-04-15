# Security Audit Report — MIP-Collections-ERC721

**Protocol:** Mediolano — Programmable IP on Starknet  
**Contract:** `IPCollection` + `IPNft`  
**Package:** `ip_collection_erc_721 v0.1.0`  
**Cairo Edition:** `2024_07`  
**OpenZeppelin Cairo:** `v0.20.0`  
**Starknet:** `2.12.0` / Sierra `1.7.0`  
**snforge_std:** `0.58.1`  
**Audit Date:** 2026-04-10  
**Auditor:** Claude Code (Anthropic)  
**Scope:** All source files in `src/` and `tests/`

---

## Mainnet Deployment

| | Value |
|---|---|
| Network | Starknet Mainnet |
| `IPNft` class hash | `0x7258e23485a916febabf6a710e16bfdefa276479d47af002209c72906603f6c` |
| `IPCollection` class hash | `0x2e24999206d088a7fc311d05a791c865b1283251c7f15f7c097b84a90feee56` |
| `IPCollection` contract address | `0x05c49ee5d3208a2c2e150fdd0c247d1195ed9ab54fa2d5dea7a633f39e4b205b` |
| Owner / Deployer | `0x02200854036a91e6aad4764ace3feec9b2e2408925ae426563f273e1854ce80c` |
| Deployed | 2026-04-10 |

Voyager:
- Contract: https://voyager.online/contract/0x05c49ee5d3208a2c2e150fdd0c247d1195ed9ab54fa2d5dea7a633f39e4b205b
- `IPNft` class: https://voyager.online/class/0x07258e23485a916febabf6a710e16bfdefa276479d47af002209c72906603f6c
- `IPCollection` class: https://voyager.online/class/0x02e24999206d088a7fc311d05a791c865b1283251c7f15f7c097b84a90feee56

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Findings Summary](#3-findings-summary)
4. [Resolved Findings](#4-resolved-findings)
5. [Remaining Observations](#5-remaining-observations)
6. [Test Coverage Assessment](#6-test-coverage-assessment)
7. [Conclusion](#7-conclusion)

---

## 1. Executive Summary

The MIP-Collections-ERC721 contract system is the foundational layer of the Mediolano IP protocol. It provides a **factory pattern** for permissionless ERC-721 IP collection creation, with zero-fee tokenization of intellectual property assets on Starknet.

The initial audit (same date) identified one critical vulnerability, two high-severity issues, and several medium/low severity findings. **All findings have been fully resolved** in the current codebase prior to mainnet deployment.

The refactor also introduced significant architectural upgrades beyond the security fixes:
- **Burn → Archive**: Destructive token burning replaced with permanent archival, preserving the on-chain IP provenance record for Berne Convention compliance.
- **IPNft made immutable**: `UpgradeableComponent` removed from `IPNft` by design — the legal record (URI, creator, timestamp) cannot be altered post-deployment.
- **Ownable → AccessControl on IPNft**: Unified access control under `DEFAULT_ADMIN_ROLE` granted to the IPCollection factory.
- **Immutable legal record fields**: `original_creator` and `registered_at` stored per-token at mint time, never overwritable.
- **URI enforcement**: Token metadata must use `ipfs://` or `ar://` — centralized or mutable URIs are rejected at the contract level.

| Severity | Initial Count | Resolved | Remaining |
|---|---|---|---|
| Critical | 1 | 1 | 0 |
| High | 1 | 1 | 0 |
| Medium | 4 | 4 | 0 |
| Low | 4 | 4 | 0 |
| Informational | 4 | 2 | 2 |

---

## 2. Architecture Overview

The system consists of two Cairo contracts:

### `IPCollection` (Factory / Registry)

The central contract. Any caller can invoke `create_collection()`, which:
1. Deploys a fresh `IPNft` ERC-721 contract per collection via `deploy_syscall`.
2. Assigns the caller as collection owner.
3. Assigns itself (`get_contract_address()`) as `collection_manager` (DEFAULT_ADMIN_ROLE) on the deployed NFT.
4. Stores collection metadata and tracks per-user collection indices.

It acts as the **single entry point** for all mint, archive, and transfer operations, delegating to the appropriate `IPNft` contract via `collection_id`.

```
User
 │
 ▼
IPCollection (factory + router) — upgradeable, owner-controlled
 ├── collections: Map<u256, Collection>
 ├── collection_stats: Map<u256, CollectionStats>
 ├── user_collections: Map<(addr, u256), u256>
 └── user_collection_index: Map<addr, u256>
 │
 ▼ deploy_syscall (once per collection)
IPNft (per-collection ERC-721) — IMMUTABLE by design
 ├── ERC721Component (OZ)
 ├── ERC721EnumerableComponent (OZ)
 ├── AccessControlComponent (DEFAULT_ADMIN_ROLE = IPCollection address)
 └── SRC5Component
```

### `IPNft` (Per-Collection ERC-721)

Each collection gets its own `IPNft` instance. Key properties:
- **Immutable**: No `UpgradeableComponent` — the legal IP record cannot be altered.
- `mint()` and `archive()` restricted to `DEFAULT_ADMIN_ROLE` (the factory).
- Per-token URIs stored in `uris: Map<u256, ByteArray>` — written once at mint, never updated.
- `original_creator` and `registered_at` stored immutably per token.
- Archived tokens cannot be transferred (`before_update` hook enforces this).
- `ERC721EnumerableComponent` enables `all_tokens_of_owner` queries.

### Token Identifier Encoding

Tokens are addressed via `ByteArray` string `"<collection_id>:<token_id>"` (e.g., `"3:17"`). The `TokenTrait::from_bytes` parser decodes this into a `Token { collection_id, token_id }` struct. Exactly one `:` separator is required; both segments must be non-empty decimal digits.

---

## 3. Findings Summary

| ID | Severity | Title | Status |
|---|---|---|---|
| C-01 | Critical | `batch_archive` — no caller authorization in loop | **RESOLVED** |
| H-01 | High | `batch_transfer` — skips approval and caller check | **RESOLVED** |
| M-01 | Medium | `batch_mint` — no array length parity check | **RESOLVED** |
| M-02 | Medium | `transfer_token` — authorizes contract, not caller | **RESOLVED** |
| M-03 | Medium | No collection pause/deactivate mechanism | **RESOLVED** |
| M-04 | Medium | `bytearray_to_u256` — no digit range validation | **RESOLVED** |
| L-01 | Low | `CollectionUpdated` event never emitted | **RESOLVED** |
| L-02 | Low | No input validation on `create_collection` | **RESOLVED** |
| L-03 | Low | `get_token` silently returns zero struct | **RESOLVED** |
| L-04 | Low | `from_bytes` — silent wrong results on malformed input | **RESOLVED** |
| I-01 | Info | `upgrade_ip_nft_class_hash` only affects new deployments | Acknowledged |
| I-02 | Info | `deploy_syscall` uses hardcoded salt `0` | Acknowledged |
| I-03 | Info | No circulating supply getter | Acknowledged |
| I-04 | Info | Token IDs started at `0` | **RESOLVED** (IDs start at 1) |

---

## 4. Resolved Findings

### C-01 — Critical: `batch_archive` Ownership Check (was `batch_burn`)

**Resolution:** `batch_burn` was removed and replaced with `batch_archive`. Inside the archive loop, ownership is verified for every token:
```cairo
let token_owner = IERC721Dispatcher { contract_address: collection.ip_nft }
    .owner_of(token.token_id);
assert(token_owner == caller, 'Caller not token owner');
```
Additionally, per-collection stats are accumulated in a `Felt252Dict` and written once per unique collection rather than once per token, reducing storage writes.

---

### H-01 — High: `batch_transfer` Authorization

**Resolution:** Both approval and caller authorization checks added inside the loop:
```cairo
let approved = ip_nft.get_approved(token.token_id);
assert(approved == get_contract_address(), 'Contract not approved');
let token_owner = ip_nft.owner_of(token.token_id);
assert(caller == token_owner || ip_nft.is_approved_for_all(token_owner, caller), 'Not authorized');
```

---

### M-01 — Medium: `batch_mint` Array Length Parity

**Resolution:**
```cairo
assert(token_uris.len() == n, 'Array lengths mismatch');
```

---

### M-02 — Medium: `transfer_token` Caller Authorization

**Resolution:** Caller is now checked against owner or `isApprovedForAll`:
```cairo
assert(caller == token_owner || ip_nft.is_approved_for_all(token_owner, caller), 'Not authorized');
```

---

### M-03 — Medium: Collection Pause Mechanism

**Resolution:** `set_collection_active(collection_id, is_active)` implemented, restricted to the collection owner.

---

### M-04 — Medium: `bytearray_to_u256` Digit Validation

**Resolution:**
```cairo
assert(byte >= 48_u8 && byte <= 57_u8, 'Invalid digit in token ID');
```

---

### L-01 — Low: `CollectionUpdated` Event

**Resolution:** `update_collection_metadata(collection_id, name, symbol, base_uri)` implemented, restricted to the collection owner, emits `CollectionUpdated`.

---

### L-02 — Low: `create_collection` Input Validation

**Resolution:**
```cairo
assert(name.len() > 0, 'Name cannot be empty');
assert(symbol.len() > 0, 'Symbol cannot be empty');
```

---

### L-03 — Low: `get_token` Silent Zero Struct

**Resolution:** `get_token` now asserts `collection.is_active` and delegates to `nft.get_full_token_data(token_id)` which calls `_require_owned` internally — reverts if the token does not exist.

---

### L-04 — Low: `from_bytes` Silent Misparse

**Resolution:** The parser now enforces exactly one `:` separator and non-empty segments on both sides before parsing:
```cairo
assert(colon_count == 1 && col_bytes.len() > 0 && tok_bytes.len() > 0, 'Invalid token format');
```

---

### I-04 — Informational: Token IDs Start at 0

**Resolution:** Token IDs now start at 1. `next_token_id = collection_stats.total_minted + 1` in both `mint` and `batch_mint`.

---

## 5. Remaining Observations

### I-01 — `upgrade_ip_nft_class_hash` Only Affects Future Deployments

`upgrade_ip_nft_class_hash` updates the class hash used for future `deploy_syscall` invocations. Already-deployed `IPNft` contracts are separate immutable instances and are unaffected — this is intentional by design (see COMP-01). Acknowledged.

### I-02 — `deploy_syscall` Uses Hardcoded Salt `0`

Salt `0` is hardcoded in `deploy_syscall`. Deployed addresses are still unique because `collection_id` is part of the constructor calldata. No security impact. Acknowledged.

### New — Low: `update_collection_metadata` Does Not Sync Deployed IPNft

When `update_collection_metadata` is called on `IPCollection`, it updates the metadata in IPCollection's own storage but does **not** propagate changes to the deployed `IPNft` instance. Clients querying `name()`, `symbol()`, or the base URI directly on the `IPNft` ERC-721 contract will see the original values. This is an intentional consequence of making `IPNft` immutable. **Integrators must read collection metadata through `IPCollection`, not `IPNft` directly.**

### New — Low: Dict Key Uses `collection_id.low`

`batch_archive` and `batch_transfer` accumulate per-collection stats in a `Felt252Dict` keyed by `collection_id.low`. If two collections ever had the same `.low` with different `.high` values, stats would be incorrectly merged. In practice this cannot occur since collection IDs are sequential `u256` values starting from 1 with `high = 0`. Acknowledged.

---

## 6. Test Coverage Assessment

The test suite covers the primary happy paths and key negative cases across all major operations.

### Covered

| Scenario | Test |
|---|---|
| Create single / multiple collections | `test_create_collection`, `test_create_multiple_collections` |
| Mint token, verify metadata | `test_mint_token`, `test_token_uri_match` |
| Mint by non-owner / zero address / zero caller | `test_mint_not_owner`, `test_mint_to_zero_address`, `test_mint_zero_caller` |
| Batch mint, verify owners | `test_batch_mint_tokens` |
| Batch mint empty / zero recipient | `test_batch_mint_empty_recipients`, `test_batch_mint_zero_recipient` |
| Archive token / non-owner revert | `test_burn_token` (archive), `test_burn_not_owner` |
| Transfer with / without approval | `test_transfer_token_success`, `test_transfer_token_not_approved` |
| Transfer inactive collection | `test_transfer_token_inactive_collection` |
| Batch transfer success / inactive | `test_batch_transfer_tokens_success`, `test_batch_transfer_inactive_collection` |
| User collection listing | `test_list_user_collections_empty`, `test_user_collections_mapping` |
| Base URI, token listing | `test_base_uri`, `test_get_all_user_tokens` |
| Validity checks | `test_verification_functions` |

### Recommended Additions

| Test | Finding |
|---|---|
| `test_batch_archive_unauthorized` — USER2 archives USER1's tokens | C-01 regression |
| `test_batch_transfer_unauthorized_caller` — third party caller | H-01 regression |
| `test_batch_mint_length_mismatch` | M-01 regression |
| `test_archive_preserves_record` — URI/creator/timestamp queryable after archive | COMP-05 |
| `test_archived_token_transfer_blocked` | COMP-05 |
| `test_mint_invalid_uri_rejected` — `https://` → revert | COMP-04 |
| `test_get_token_creator` / `test_get_token_registered_at` | COMP-02/03 |
| `test_set_collection_active_toggle` | M-03 |
| `test_update_collection_metadata` | L-01 |

---

## 7. Conclusion

The MIP-Collections-ERC721 system has a solid architectural foundation. All critical, high, medium, and low security findings from the initial audit have been resolved. The system has been successfully declared and deployed to Starknet Mainnet.

The architecture correctly implements permissionless IP tokenization with Berne Convention compliance: on-chain authorship records are immutable, metadata is content-addressed, and IP records are preserved (not destroyed) when no longer active. The factory pattern, per-collection immutable ERC-721 contracts, and clean separation between `IPCollection` and `IPNft` provide a strong foundation for IP tokenization at scale.

---

*Report generated by Claude Code (claude-sonnet-4-6) — 2026-04-10*
