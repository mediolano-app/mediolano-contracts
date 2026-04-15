# IP-Programmable-ERC1155-Collections — Audit Report

**Date:** 2026-04-13
**Auditor:** Claude Sonnet 4.6 (Anthropic) + Medialane team
**Scope:** Full source audit — no code changes made
**Status:** NOT PRODUCTION-READY (testnet only)

---

## 1. Contract Overview

`IP-Programmable-ERC1155-Collections` is a two-contract system: a **factory** that deploys individual ERC-1155 **collection** instances. Each collection is independently owned and upgradeable. The architecture closely mirrors `MIP-Collections-ERC721` (the ERC-721 factory used on Medialane), adapted for the ERC-1155 standard.

**Key facts:**
- Factory + Collection pattern (2 contracts)
- Built on OpenZeppelin Cairo v2.0.0-alpha.1 (**pre-release — not stable**)
- Starknet 2.11.4 / Cairo edition `2024_07`
- snforge_std 0.41.0
- 10 test functions (gaps in coverage)
- Each collection is upgradeable via `UpgradeableComponent`
- Deployed on Sepolia testnet

---

## 2. Architecture

```
ERC1155CollectionsFactoryContract
  └── deploy_erc1155_collection()
        └── deploy_syscall(class_hash, salt, calldata)
              └── ERC1155CollectionContract (new instance)
                    ├── OwnableComponent     (caller becomes owner)
                    ├── ERC1155Component     (tokens, balances, approvals)
                    ├── SRC5Component        (interface introspection)
                    └── UpgradeableComponent (owner can upgrade class)
```

---

## 3. Storage Variables

### ERC1155CollectionContract
| Variable | Type | Purpose |
|---|---|---|
| `src5` | `SRC5Component::Storage` | Interface introspection (ERC-165 equivalent) |
| `ownable` | `OwnableComponent::Storage` | Owner address + transfer logic |
| `upgradeable` | `UpgradeableComponent::Storage` | Upgrade mechanism |
| `erc1155` | `ERC1155Component::Storage` | Balances, approvals, URIs |
| `ERC1155Collection_class_hash` | `ClassHash` | Stored class hash (mirrors deployed class) |

### ERC1155CollectionsFactoryContract
| Variable | Type | Purpose |
|---|---|---|
| `ownable` | `OwnableComponent::Storage` | Factory owner |
| `erc1155_collections_class_hash` | `ClassHash` | Class hash used for new deployments |
| `contract_address_salt` | `felt252` | Incremental salt for `deploy_syscall` |

---

## 4. Public Interface

### ERC1155CollectionContract

| Function | Access | Description |
|---|---|---|
| `owner()` | Anyone | Returns current owner |
| `transfer_ownership(new_owner)` | Owner only | Transfers ownership |
| `renounce_ownership()` | Owner only | Permanently removes owner |
| `balance_of(account, token_id)` | Anyone | Token balance |
| `balance_of_batch(accounts, token_ids)` | Anyone | Batch balance query |
| `uri(token_id)` | Anyone | Token metadata URI |
| `is_approved_for_all(owner, operator)` | Anyone | Approval status |
| `set_approval_for_all(operator, approved)` | Token holder | Grant/revoke operator |
| `safe_transfer_from(from, to, token_id, value, data)` | Holder or operator | Single token transfer |
| `safe_batch_transfer_from(from, to, token_ids, values, data)` | Holder or operator | Batch transfer |
| `mint(to, token_id, value)` | **Owner only** | Mint single token type |
| `upgrade(new_class_hash)` | **Owner only** | Upgrade contract class |
| `class_hash()` | Anyone | Returns stored class hash |

### ERC1155CollectionsFactoryContract

| Function | Access | Description |
|---|---|---|
| `owner()` | Anyone | Returns factory owner |
| `transfer_ownership(new_owner)` | Owner only | Transfer factory ownership |
| `erc1155_collections_class_hash()` | Anyone | Returns current collection class hash |
| `update_erc1155_collections_class_hash(new_hash)` | **Owner only** | Update class hash for new deployments |
| `deploy_erc1155_collection(token_uri, recipient, token_ids, values)` | **Anyone** | Deploy new collection instance |

---

## 5. Events

### ERC1155CollectionContract
| Event | Source | Fields |
|---|---|---|
| `OwnershipTransferred` | OwnableComponent | `previous_owner, new_owner: ContractAddress` |
| `Upgraded` | UpgradeableComponent | `class_hash: ClassHash` |
| `TransferSingle` | ERC1155Component | `operator, from, to: ContractAddress, token_id, value: u256` |
| `TransferBatch` | ERC1155Component | `operator, from, to: ContractAddress, token_ids, values: Span` |
| `ApprovalForAll` | ERC1155Component | `owner, operator: ContractAddress, approved: bool` |
| `URI` | ERC1155Component | `value: ByteArray, token_id: u256` |

### ERC1155CollectionsFactoryContract
| Event | Source | Fields |
|---|---|---|
| `OwnershipTransferred` | OwnableComponent | `previous_owner, new_owner: ContractAddress` |

**Critical gap:** No `CollectionDeployed` event and no `ClassHashUpdated` event from the factory. Off-chain indexers cannot track deployments without polling.

---

## 6. Access Control

| Action | Who |
|---|---|
| Deploy new collection | **Anyone** (caller becomes collection owner) |
| Mint into a collection | Collection owner only |
| Upgrade a collection | Collection owner only |
| Update factory class hash | Factory owner only |
| Transfer factory ownership | Factory owner only |
| Transfers / approvals | Token holder or approved operator |

This model is **owner-gated minting** — the opposite of the permissionless pattern used in `IP-Programmable-ERC-721` and the genesis mint. A collection deployed via this factory can only be minted by the address that deployed it.

---

## 7. Findings

### [HIGH] Factory Missing `CollectionDeployed` Event

`deploy_erc1155_collection()` emits no custom event. The only event the factory ever emits is `OwnershipTransferred` from OwnableComponent. There is no on-chain record of which collections have been deployed by this factory, what their addresses are, or who deployed them.

**Impact:** The Medialane indexer cannot discover and index new collections without polling every transaction against the factory. The `MIP-Collections-ERC721` factory has the same gap — it is a known issue in the ERC-721 stack too.

**Fix:** Add:
```cairo
#[derive(Drop, starknet::Event)]
struct CollectionDeployed {
    #[key]
    collection_address: ContractAddress,
    owner: ContractAddress,
    token_uri: ByteArray,
}
```

### [HIGH] All Tokens in a Collection Share the Same URI

The constructor accepts a single `token_uri: ByteArray` applied identically to every token ID in the initial batch:

```cairo
// Same URI written to every token_id at deployment
self.erc1155.batch_mint_with_acceptance_check(recipient, token_ids, values, array![].span());
```

Post-deployment `mint(to, token_id, value)` uses OZ's `mint_with_acceptance_check` which does not set a token-specific URI at all.

**Impact:** A collection with token IDs 1, 2, 3 representing different IP assets (different artwork, different licenses) cannot have different metadata. All resolve to the same IPFS file.

**Contrast:** `IP-Programmable-ERC-1155` (the single-contract version) has `ERC1155_uri: Map<u256, ByteArray>` — per-token URIs — though its setter is also missing.

### [HIGH] No URI Setter or Update Mechanism

There is no function to set or update a token's URI after deployment. The URI passed to the constructor is the only URI a collection ever has.

**Impact:** If the IPFS CID is wrong at deployment, or if token metadata needs to evolve (new license terms, updated description), there is no path to correct it short of deploying a new collection.

### [MEDIUM] Predictable Deployment Salt

`contract_address_salt` is a sequential felt252 incremented by 1 on each deployment:

```cairo
let salt = self.contract_address_salt.read();
self.contract_address_salt.write(salt + 1);
```

**Impact:** Collection addresses are deterministically predictable. An observer can calculate the address of the next deployed collection before it is deployed. On Starknet this is a lower risk than Ethereum (no frontrunning miners), but it is still a design weakness.

**Better practice:** `keccak256(caller, token_uri, block_timestamp, salt)` as the salt.

### [MEDIUM] No Recipient Validation in Factory

`deploy_erc1155_collection(token_uri, recipient, ...)` passes `recipient` directly to the collection constructor. There is no `assert(!recipient.is_zero(), ...)` check in the factory before calling `deploy_syscall`.

**Impact:** A careless caller can deploy a collection where all initial tokens are minted to the zero address. OZ's `batch_mint_with_acceptance_check` may or may not catch this internally depending on the component version.

### [MEDIUM] OZ Dependency on Pre-Release Version

All five OZ libraries are pinned to `v2.0.0-alpha.1`:
```toml
openzeppelin_access = { git = "...", tag = "v2.0.0-alpha.1" }
openzeppelin_token = { git = "...", tag = "v2.0.0-alpha.1" }
...
```

**Impact:** Alpha software has no stability guarantees. APIs can change between alpha releases. The rest of the Mediolano stack uses OZ v0.20.0 (stable) with a different import style (`openzeppelin::` bundle). These are **not compatible** — they are separate library versions with different module paths.

### [MEDIUM] Test Coverage Gaps

10 tests exist, covering deployment, access control, and upgrade. Not covered:

- `safe_transfer_from` — no transfer tests
- `safe_batch_transfer_from` — no batch transfer tests
- `set_approval_for_all` / `is_approved_for_all` — no approval tests
- Zero address recipient edge cases
- Token balance queries after transfer
- Factory with invalid class hash
- Factory with zero recipient

### [LOW] No `batch_mint` on Base Collection Contract

The base `ERC1155CollectionContract` only has `mint(to, token_id, value)` — single token type, single call. The V2 test helper adds `batch_mint()`. Efficient multi-token minting requires an upgrade after deployment, which is an unnecessary friction for any creator deploying via the factory.

### [LOW] `ERC1155Collection_class_hash` Redundancy

The contract stores its own class hash in custom storage and updates it on every upgrade. In Starknet, the class hash of a deployed contract is always available via `get_contract_class_hash_at(address)` on the RPC. The custom storage slot is redundant and introduces a potential drift risk if ever not updated correctly.

### [LOW] No Pause Mechanism

No circuit breaker. If a collection is compromised or tokens need to be frozen (legal dispute over IP), there is no way to halt transfers without upgrading the contract class.

---

## 8. ERC-1155 Standard Compliance

| Spec Requirement | Status |
|---|---|
| `balance_of`, `balance_of_batch` | ✅ Via OZ component |
| `safe_transfer_from` with receiver callback | ✅ OZ handles `onERC1155Received` |
| `safe_batch_transfer_from` with receiver callback | ✅ OZ handles batch callback |
| `ApprovalForAll` | ✅ Via OZ component |
| `URI` event | ✅ OZ emits on URI set |
| `{id}` substitution in URI | ❌ Not implemented |
| Interface introspection (SRC5) | ✅ Registered via SRC5Component |

This contract is significantly more compliant than the single-contract version — the OZ ERC1155Component handles receiver callbacks correctly.

---

## 9. Ecosystem Fit Assessment

### vs. IP-Programmable-ERC-721 (permissionless genesis mint)

| Aspect | ERC-721 (`IP-Programmable-ERC-721`) | ERC-1155 Collections |
|---|---|---|
| Mint access | Permissionless (anyone) | Owner only |
| URI per token | Full, stored at mint | Uniform for all tokens |
| IP provenance | `token_creators` + `registered_at` | Not tracked |
| OZ version | v0.20.0 (stable, bundle) | v2.0.0-alpha.1 (pre-release, split) |
| Tests | 40 / 40 passing | 10, with gaps |

ERC-1155 Collections uses **owner-gated minting** — incompatible with the genesis/open-edition pattern. It is closer to a creator-controlled drop, not a public collection.

### vs. MIP-Collections-ERC721 (factory, multi-collection single owner)

| Aspect | MIP-Collections-ERC721 | ERC-1155 Collections |
|---|---|---|
| Pattern | Factory + ERC-721 per collection | Factory + ERC-1155 per collection |
| Token standard | ERC-721 (NFT, 1-of-1) | ERC-1155 (multi-token, fungible/semi-fungible) |
| Owner model | Collection owner deploys and mints | Same |
| Upgradeability | ✅ UpgradeableComponent | ✅ UpgradeableComponent |
| Factory events | ❌ Missing | ❌ Missing (same gap) |
| OZ version | v0.20.0 (stable) | v2.0.0-alpha.1 (pre-release) |

Architecturally the closest contract in the stack. The factory/collection pattern is identical. The OZ version mismatch is the most significant incompatibility.

### vs. Medialane Marketplace (`0x0234f4e8...`)

The Medialane marketplace was built for ERC-721. ERC-1155 tokens from this contract **will not be tradeable** on the marketplace without changes to the marketplace contract to support:
- `safe_transfer_from` with the ERC-1155 signature (different from ERC-721)
- `is_approved_for_all` instead of per-token `approve`
- Quantity-aware orders (ERC-1155 allows selling N-of-M)

This is the **most significant ecosystem gap** — deploying ERC-1155 collections without marketplace support means tokens have no exchange venue on the platform.

### vs. Mediolano Protocol SDK

The SDK (`medialane-sdk`) exposes `COLLECTION_CONTRACT_MAINNET` which currently points to an ERC-721 collection. ERC-1155 collections deployed via this factory would need their own SDK constant or a unified multi-standard interface.

---

## 10. Test Results

Run `scarb test` from the contract directory to verify current state. 10 tests defined:

| Test | File | Covers |
|---|---|---|
| `test_deploy` | collection | Constructor, owner, uri, balance, class_hash |
| `test_upgrade_not_owner` | collection | Access control on upgrade |
| `test_upgrade` | collection | Owner can upgrade to V2 |
| `test_mint_not_owner` | collection | Access control on mint |
| `test_mint` | collection | Owner can mint new token |
| `test_batch_mint` | collection | V2 batch_mint after upgrade |
| `test_deploy` | factory | Factory constructor |
| `test_update_erc1155_collections_class_hash_not_owner` | factory | Class hash update access control |
| `test_update_erc1155_collections_class_hash` | factory | Owner updates class hash |
| `test_deploy_erc1155_collection` | factory | Factory deploys collection |

**Not covered:** transfers, approvals, zero-address edge cases, batch transfers, multi-token URI queries.

---

## 11. Summary

| Category | Rating |
|---|---|
| Code quality | Good — clean OZ component composition |
| Security | Medium — missing validations, pre-release OZ, no events |
| Test coverage | Partial — core flows covered, transfers/approvals not |
| Standard compliance | Good — OZ handles ERC-1155 spec correctly |
| Feature completeness | Medium — URI immutability and missing factory events are blockers |
| Ecosystem fit | Poor — OZ version mismatch, no marketplace support, no IP provenance |
| Production readiness | **NOT READY** |

### Priority Fixes Before Production

1. **Upgrade OZ to v0.20.0** (match the rest of the Mediolano stack)
2. **Add `CollectionDeployed` event** to factory
3. **Add per-token URI support** — mint should accept a `token_uri` parameter
4. **Add `recipient` validation** in factory
5. **Expand test coverage** — transfers, approvals, edge cases
6. **Add IP provenance** — `token_creators` and `registered_at` maps (align with ERC-721 standard)
7. **Coordinate with marketplace team** on ERC-1155 support before any mainnet deployment

---

## 12. Files Audited

```
contracts/IP-Programmable-ERC1155-Collections/
├── Scarb.toml
├── snfoundry.toml
├── src/
│   ├── lib.cairo
│   ├── interfaces.cairo
│   ├── erc1155_collection.cairo
│   └── erc1155_collections_factory.cairo
└── tests/
    ├── test_erc1155_collection.cairo
    ├── test_erc1155_collections_factory.cairo
    ├── erc1155_receiver.cairo          (test helper)
    └── erc1155_collection_v2.cairo     (test helper — upgrade target)
```
