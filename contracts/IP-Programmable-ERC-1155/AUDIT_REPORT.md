# IP-Programmable-ERC-1155 — Audit Report

**Date:** 2026-04-13
**Auditor:** Claude Sonnet 4.6 (Anthropic) + Medialane team
**Scope:** Full source audit — no code changes made
**Status:** NOT PRODUCTION-READY

---

## 1. Contract Overview

`IP-Programmable-ERC-1155` is a single-contract ERC-1155 multi-token implementation written in Cairo **from scratch** — no OpenZeppelin components used. It is designed to allow minting of multiple digital asset types with per-token IPFS metadata and programmable licensing terms.

**Key facts:**
- Custom ERC-1155 implementation (no OZ dependency)
- Single contract, no factory, no upgradeability
- Starknet 2.9.2 / Cairo edition `2023_11` (outdated — current is 2.12.0 / `2024_07`)
- snforge_std v0.34.0 (outdated — current is 0.58.0)
- **Zero test coverage**
- Deployed only on Sepolia devnet (per README)

---

## 2. Storage Variables

| Variable | Type | Purpose |
|---|---|---|
| `ERC1155_balances` | `Map<(u256, ContractAddress), u256>` | Token balance per (token_id, account) |
| `ERC1155_operator_approvals` | `Map<(ContractAddress, ContractAddress), bool>` | Operator approval per (owner, operator) |
| `ERC1155_uri` | `Map<u256, ByteArray>` | Per-token metadata URI (IPFS) |
| `ERC1155_licenses` | `Map<u256, ByteArray>` | Per-token license data |
| `ERC1155_owned_tokens` | `Map<ContractAddress, u256>` | Count of distinct token types per owner |
| `ERC1155_owned_tokens_list` | `Map<(ContractAddress, u256), u256>` | Indexed list of token IDs per owner |
| `owner` | `ContractAddress` | Contract deployer — **never read, functionally dead** |

---

## 3. Public Interface

### Read Functions
| Function | Signature |
|---|---|
| `balance_of` | `(account: ContractAddress, token_id: u256) -> u256` |
| `balance_of_batch` | `(accounts: Span<ContractAddress>, token_ids: Span<u256>) -> Span<u256>` |
| `is_approved_for_all` | `(owner: ContractAddress, operator: ContractAddress) -> bool` |
| `uri` | `(token_id: u256) -> ByteArray` |
| `get_license` | `(token_id: u256) -> ByteArray` |
| `list_tokens` | `(owner: ContractAddress) -> Span<u256>` |

### Write Functions
| Function | Signature |
|---|---|
| `set_approval_for_all` | `(operator: ContractAddress, approved: bool)` |
| `safe_transfer_from` | `(from, to: ContractAddress, token_id, value: u256, data: Span<felt252>)` |
| `safe_batch_transfer_from` | `(from, to: ContractAddress, token_ids, values: Span<u256>, data: Span<felt252>)` |

### Constructor
```cairo
constructor(token_uri: ByteArray, recipient: ContractAddress, token_ids: Span<u256>, values: Span<u256>)
```
Minting is only possible at deployment time. **No post-deployment mint function exists.**

---

## 4. Events

| Event | Fields | Trigger |
|---|---|---|
| `TransferSingle` | `operator, from, to: ContractAddress, token_id, value: u256` | `safe_transfer_from` |
| `TransferBatch` | `operator, from, to: ContractAddress, token_ids, values: Span<u256>` | `safe_batch_transfer_from` |
| `ApprovalForAll` | `owner, operator: ContractAddress, approved: bool` | `set_approval_for_all` |

**Missing:** No event on mint (constructor), no URI event, no license event.

---

## 5. Access Control

| Action | Who Can Call |
|---|---|
| Mint | **Nobody after deployment** — constructor only |
| Transfer | Token holder OR approved operator |
| Approve operator | Any token holder (for their own tokens) |
| Update URI | Nobody — no setter exists |
| Update license | Nobody — no setter exists |

The `owner` storage variable is written at construction but **never read anywhere in the codebase**. There are no owner-gated functions. It is dead code that consumes a storage slot.

---

## 6. Critical Findings

### [CRITICAL] Token Ownership Tracking is Broken

`ERC1155_owned_tokens` tracks how many **distinct token types** an account holds. `ERC1155_owned_tokens_list` is an append-only indexed list of token IDs. When tokens are transferred, the counter is decremented but the list is **never pruned**.

**Result:** `list_tokens()` returns stale/incorrect token IDs after any transfer occurs.

**Example:**
1. User receives token IDs 1, 2, 3 → `count = 3`, `list = [1, 2, 3]`
2. User transfers all of token 2 → `count = 2`, `list = [1, 2, 3]` (unchanged)
3. `list_tokens(user)` reads indices 0–1 → returns `[1, 2]` — token 2 is still listed despite zero balance

The list has no concept of which index corresponds to which token. There is no swap-and-pop, no tombstone, no removal mechanism.

### [CRITICAL] Programmable Licensing is Non-Functional

`ERC1155_licenses` storage and `get_license()` getter both exist, but **no setter function exists**. Licenses are initialized as empty ByteArray at deployment and can never be updated. The entire programmable licensing feature is a stub.

### [CRITICAL] No Post-Deployment Minting

The constructor is the only place `batch_mint()` is called for minting (when `from` is zero). There is no `mint()` function. Once deployed, the token supply is permanently fixed. This contradicts the requirement: *"Ability to mint new digital assets"*.

### [HIGH] `data` Parameter in Safe Transfers is Ignored

`safe_transfer_from` and `safe_batch_transfer_from` accept a `data: Span<felt252>` parameter per the ERC-1155 spec. The spec requires calling `onERC1155Received` on the recipient if it is a contract. This contract **does not perform any receiver callback**, making transfers to contracts that require it unsafe. Tokens can be permanently lost.

### [HIGH] `owner` Variable is Dead Code

The deployer's address is written to `owner` storage at construction but never read. No function uses it. It creates a false impression of access control. Should be removed entirely.

### [MEDIUM] Constructor Allows Duplicate Token IDs

No uniqueness check on `token_ids`. If the same token ID appears twice in the array, the URI is overwritten silently. Balances are additive (both mints succeed), but URI only reflects the last write for that ID.

### [MEDIUM] Zero Test Coverage

The project has **no test files whatsoever**. A smart contract handling digital assets and financial transactions with zero automated test coverage is a critical omission before any deployment.

### [MEDIUM] Outdated Dependencies

| Dependency | Current | Latest (repo standard) |
|---|---|---|
| starknet | 2.9.2 | 2.12.0 |
| Cairo edition | 2023_11 | 2024_07 |
| snforge_std | v0.34.0 | 0.58.0 |

OZ is entirely absent. The rest of the Mediolano codebase uses OZ v0.20.0 for ERC-721.

### [LOW] Misnamed Internal Function

`batch_mint()` handles both minting (`from == zero`) and transfers (`from != zero`). The name implies mint-only. Should be named `_internal_transfer()` or similar to avoid developer confusion.

### [LOW] Inconsistent Error String Usage

Some assertions use `.into()`, others do not. Inconsistent style across the codebase.

---

## 7. ERC-1155 Standard Compliance Gaps

| Spec Requirement | Status |
|---|---|
| `onERC1155Received` callback on safe transfer | ❌ Not implemented |
| `onERC1155BatchReceived` callback | ❌ Not implemented |
| `{id}` substitution in URI | ❌ Not implemented |
| `URI` event on URI change | ❌ Not implemented |
| Interface introspection (SRC5/ERC165) | ❌ Not implemented |

---

## 8. Ecosystem Fit Assessment

### vs. IP-Programmable-ERC-721 (genesis mint pattern)
The ERC-721 contract is permissionless — anyone can mint to anyone. This ERC-1155 is locked to constructor-only minting by the deployer. **Not equivalent** in deployment model. The ERC-721 already has per-token URI storage, IP provenance, and `safe_mint` — all done correctly with OZ components. This ERC-1155 reimplements those concepts incorrectly from scratch.

### vs. MIP-Collections-ERC721 (factory pattern)
MIP-Collections uses OZ v0.20.0 components, a factory deploying per-collection contracts, `deploy_syscall`, and full test coverage. This contract shares none of that architecture and would not integrate cleanly with it.

### vs. Medialane Marketplace (`0x0234f4e8...`)
ERC-1155 tokens from this contract **cannot be listed or traded** on the Medialane marketplace unless the marketplace explicitly supports ERC-1155 `safe_transfer_from` with the correct selector and approval pattern. The current marketplace is built around ERC-721 (`transfer_from`, `approve`). No integration path exists without marketplace changes.

---

## 9. Summary

| Category | Rating |
|---|---|
| Code quality | Poor — custom implementation with critical bugs |
| Security | Poor — broken enumeration, missing callbacks, dead owner |
| Test coverage | 0% |
| Standard compliance | Partial — missing receiver callbacks and introspection |
| Feature completeness | Poor — core features (mint, license setter) missing |
| Ecosystem fit | Not compatible with current Mediolano stack |
| Production readiness | **NOT READY** |

### Recommendation

This contract should be **rewritten** rather than patched. The recommended approach is to:

1. Adopt OZ v0.20.0 `ERC1155Component` (consistent with rest of Mediolano stack)
2. Add permissionless `mint_item()` mirroring the ERC-721 pattern
3. Add per-token license storage with a proper setter + event
4. Validate URIs with `ipfs://` or `ar://` prefix (frontend normalizes bare CIDs)
5. Write comprehensive tests (target ≥30 test functions)
6. Update Starknet to 2.12.0 and Cairo edition to 2024_07

---

## 10. Files Audited

```
contracts/IP-Programmable-ERC-1155/
├── Scarb.toml
├── src/
│   ├── lib.cairo
│   └── programmableERC.cairo
└── readme.md

Tests: none
```
