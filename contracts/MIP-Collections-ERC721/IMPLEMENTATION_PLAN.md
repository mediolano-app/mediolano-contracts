# MIP-Collections-ERC721 — Refactoring Implementation Plan

**Status: COMPLETED — Deployed to Mainnet 2026-04-10**

| | Value |
|---|---|
| `IPNft` class hash | `0x7258e23485a916febabf6a710e16bfdefa276479d47af002209c72906603f6c` |
| `IPCollection` class hash | `0x2e24999206d088a7fc311d05a791c865b1283251c7f15f7c097b84a90feee56` |
| `IPCollection` contract | `0x05c49ee5d3208a2c2e150fdd0c247d1195ed9ab54fa2d5dea7a633f39e4b205b` |
| Owner | `0x02200854036a91e6aad4764ace3feec9b2e2408925ae426563f273e1854ce80c` |
| Scarb | `2.12.0` / Sierra `1.7.0` |
| sncast | `0.58.1` |

All phases below were executed and verified. See AUDIT_REPORT.md for the full security assessment.

---

**Protocol:** Mediolano — Public Goods IP Tokenization on Starknet  
**Date:** 2026-04-10  
**Scope:** Full refactor of `IPCollection` + `IPNft` for security, compliance, and correctness  
**Basis:** Security audit (AUDIT_REPORT.md) + Berne Convention / WIPO compliance requirements

---

## Dependency Order

Changes must be applied in this sequence — each phase depends on the previous:

```
Phase 0: types.cairo           → structs imported by interfaces and contracts
Phase 1: interfaces/IIPNFT     → implemented by IPNft, dispatched by IPCollection
Phase 2: interfaces/IIPCollection → implemented by IPCollection
Phase 3: IPNft.cairo           → depends on IIPNFT + types
Phase 4: IPCollection.cairo    → depends on IPNft dispatcher + IIPCollection + types
Phase 5: tests/                → depends on everything above
```

---

## Phase 0 — `src/types.cairo`

### 0-A: COMP-07 — Extend `TokenData` with legal record fields

`TokenData` is only ever constructed and returned (never stored in a `Map`), so adding fields does not affect on-chain storage layout.

```cairo
// Before
pub struct TokenData {
    pub collection_id: u256,
    pub token_id: u256,
    pub owner: ContractAddress,
    pub metadata_uri: ByteArray,
}

// After
pub struct TokenData {
    pub collection_id: u256,
    pub token_id: u256,
    pub owner: ContractAddress,
    pub metadata_uri: ByteArray,
    pub original_creator: ContractAddress,  // permanent Berne Convention authorship
    pub registered_at: u64,                 // permanent timestamped proof of creation
}
```

### 0-B: M-04 — Harden `bytearray_to_u256` against non-digit bytes

```cairo
fn bytearray_to_u256(bytes: ByteArray) -> u256 {
    let mut result = 0_u256;
    for i in 0..bytes.len() {
        let byte = bytes.at(i).unwrap();
        assert(byte >= 48_u8 && byte <= 57_u8, 'Invalid digit in token ID');
        let digit = byte - 48;
        result = result * 10_u256 + digit.try_into().unwrap();
    }
    result
}
```

### 0-C: L-04 — Validate exactly one `:` separator in `TokenTrait::from_bytes`

Count colons before parsing. Assert exactly one. Assert both segments are non-empty (guards leading/trailing colon edge cases).

### 0-D: Update inline unit tests in `types.cairo`

New tests:
- `test_bytearray_to_u256_non_digit_panics` — `"12a3"` → panic `'Invalid digit in token ID'`
- `test_from_bytes_no_separator_panics` — `"123"` → panic `'Invalid token format'`
- `test_from_bytes_multiple_colons_panics` — `"1:2:3"` → panic

---

## Phase 1 — `src/interfaces/IIPNFT.cairo`

### 1-A: COMP-05 — Replace `burn` with `archive`

```cairo
// REMOVE
fn burn(ref self: ContractState, token_id: u256);

// ADD
/// Archives a token. Preserves the on-chain record permanently for Berne Convention
/// compliance. Archived tokens cannot be transferred or re-archived.
/// Only callable by DEFAULT_ADMIN_ROLE (IPCollection factory).
fn archive(ref self: ContractState, token_id: u256);

/// Returns true if the token has been archived (record permanently preserved).
fn is_archived(self: @ContractState, token_id: u256) -> bool;
```

### 1-B: COMP-06 — Add legal record getters

```cairo
/// Returns the original creator address stored immutably at mint time.
fn get_token_creator(self: @ContractState, token_id: u256) -> ContractAddress;

/// Returns the block timestamp stored immutably at mint time.
fn get_token_registered_at(self: @ContractState, token_id: u256) -> u64;
```

---

## Phase 2 — `src/interfaces/IIPCollection.cairo`

### 2-A: COMP-05 — Replace `burn`/`batch_burn` with `archive`/`batch_archive`

```cairo
// REMOVE
fn burn(ref self: ContractState, token: ByteArray);
fn batch_burn(ref self: ContractState, tokens: Array<ByteArray>);

// ADD
fn archive(ref self: ContractState, token: ByteArray);
fn batch_archive(ref self: ContractState, tokens: Array<ByteArray>);
```

### 2-B: M-03 — Add `set_collection_active`

```cairo
/// Toggles the active state of a collection. Only callable by the collection owner.
fn set_collection_active(ref self: ContractState, collection_id: u256, is_active: bool);
```

### 2-C: L-01 — Add `update_collection_metadata`

```cairo
/// Updates mutable metadata (name, symbol, base_uri) for a collection.
/// Only callable by the collection owner. Emits CollectionUpdated.
fn update_collection_metadata(
    ref self: ContractState,
    collection_id: u256,
    name: ByteArray,
    symbol: ByteArray,
    base_uri: ByteArray,
);
```

### 2-D: COMP-08 — Add `get_collection_count`

```cairo
/// Returns the total number of collections ever created.
fn get_collection_count(self: @ContractState) -> u256;
```

---

## Phase 3 — `src/IPNft.cairo`

Apply in this sub-order within the file:

### 3-A: COMP-01 — Remove `UpgradeableComponent` ⚠️ CRITICAL LEGAL REQUIREMENT

Remove entirely:
- `use openzeppelin::upgrades::UpgradeableComponent`
- `use openzeppelin::upgrades::interface::IUpgradeable`
- `component!(path: UpgradeableComponent, ...)`
- `impl UpgradeableInternalImpl = ...`
- `upgradeable` field from `Storage`
- `UpgradeableEvent` variant from `Event`
- The entire `impl UpgradeableImpl of IUpgradeable<ContractState>` block

> **Cairo gotcha — storage layout:** Removing a `#[substorage(v0)]` field shifts Pedersen-derived storage keys for all subsequent fields. This is a breaking change for already-deployed instances — which is intentional: existing IPNft contracts become permanently immutable (exactly what COMP-01 requires). New collections will deploy under the new class hash via `upgrade_ip_nft_class_hash` in IPCollection.

### 3-B: R-04 — Remove `OwnableComponent` (redundant with AccessControl)

Nothing in `IPNft` calls `ownable.assert_only_owner()`. All privileged operations use `DEFAULT_ADMIN_ROLE`. Ownable is decorative and confusing.

Remove:
- `use openzeppelin::access::ownable::OwnableComponent`
- `component!(path: OwnableComponent, ...)`
- `impl OwnableMixinImpl` and `impl OwnableInternalImpl`
- `ownable` field from `Storage`
- `OwnableEvent` variant from `Event`
- `owner: ContractAddress` parameter from `constructor`
- `self.ownable.initializer(owner)` call from constructor

> **Cairo gotcha — deploy calldata:** `IPCollection.create_collection` must be updated in Phase 4-O to remove the `owner` argument from the serialized constructor calldata. This is the highest-risk coupling in the entire refactor.

### 3-C: COMP-02 + COMP-03 — Add immutable per-token storage

```cairo
// Add to Storage struct
token_creators: Map<u256, ContractAddress>,  // original_creator, written once at mint
token_registered_at: Map<u256, u64>,         // block timestamp at mint, written once
```

> **Cairo note:** `Map` storage entries use independent key hashing — appending new `Map` fields does not affect existing storage slot calculations. Safe to add.

### 3-D: COMP-05 — Add `token_archived` storage and implement `archive`

```cairo
// Add to Storage struct
token_archived: Map<u256, bool>,
```

Replace `burn` implementation with:

```cairo
fn archive(ref self: ContractState, token_id: u256) {
    self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
    self.erc721._require_owned(token_id);                      // must exist
    assert(!self.token_archived.read(token_id), 'Already archived');
    self.token_archived.write(token_id, true);
    // Do NOT call erc721.burn — the on-chain record is preserved permanently
}

fn is_archived(self: @ContractState, token_id: u256) -> bool {
    self.token_archived.read(token_id)
}
```

Update `ERC721HooksImpl.before_update` to block transfers of archived tokens:

```cairo
impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
    fn before_update(
        ref self: ERC721Component::ComponentState<ContractState>,
        to: ContractAddress,
        token_id: u256,
        auth: ContractAddress,
    ) {
        let mut contract_state = self.get_contract_mut();
        // Block transfer if token is archived (preserve immutability of the legal record)
        assert(!contract_state.token_archived.read(token_id), 'Token is archived');
        contract_state.erc721_enumerable.before_update(to, token_id);
    }
}
```

> **Cairo note:** `Map<u256, bool>` defaults to `false` for unwritten keys — archived check is safe on initial mint without any extra initialization.
>
> **Archived tokens and `_require_owned`:** Since we do NOT call `erc721.burn`, the ERC721 owner field remains set. `_require_owned` succeeds for archived tokens — callers can still query the legal record via `get_token_creator` and `get_token_registered_at`. This is intentional.

### 3-E: COMP-04 — Validate URI prefix in `mint`

Add a private helper `bytearray_starts_with` (byte-by-byte comparison for prefix length). Use it in `mint`:

```cairo
fn mint(ref self: ContractState, recipient: ContractAddress, token_id: u256, token_uri: ByteArray) {
    self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
    // COMP-04: Only permanent, content-addressed storage URIs are legally valid
    let valid_uri = bytearray_starts_with(@token_uri, @"ipfs://")
        || bytearray_starts_with(@token_uri, @"ar://");
    assert(valid_uri, 'URI must be ipfs:// or ar://');
    assert(token_id != 0, 'Token ID cannot be zero');
    self.erc721.mint(recipient, token_id);
    self.uris.write(token_id, token_uri);
    self.token_creators.write(token_id, recipient);                    // COMP-02
    self.token_registered_at.write(token_id, get_block_timestamp());   // COMP-03
}
```

> **Cairo note:** `ByteArray` has no native `starts_with`. Implement as:
> ```cairo
> fn bytearray_starts_with(haystack: @ByteArray, needle: @ByteArray) -> bool {
>     let n = needle.len();
>     if haystack.len() < n { return false; }
>     let mut i: u32 = 0;
>     let mut matches = true;
>     while i < n {
>         if haystack.at(i).unwrap() != needle.at(i).unwrap() {
>             matches = false;
>             break;
>         }
>         i += 1;
>     }
>     matches
> }
> ```

### 3-F: COMP-06 — Implement legal record getters

```cairo
fn get_token_creator(self: @ContractState, token_id: u256) -> ContractAddress {
    self.erc721._require_owned(token_id);
    self.token_creators.read(token_id)
}

fn get_token_registered_at(self: @ContractState, token_id: u256) -> u64 {
    self.erc721._require_owned(token_id);
    self.token_registered_at.read(token_id)
}
```

### 3-G: Update `IPNft` constructor signature

Remove `owner: ContractAddress` parameter. Remove `self.ownable.initializer(owner)`. Keep `collection_manager` for DEFAULT_ADMIN_ROLE.

```cairo
#[constructor]
fn constructor(
    ref self: ContractState,
    name: ByteArray,
    symbol: ByteArray,
    base_uri: ByteArray,
    collection_id: u256,          // owner param removed
    collection_manager: ContractAddress,
) {
    self.erc721.initializer(name, symbol, base_uri);
    self.accesscontrol.initializer();
    self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, collection_manager);
    self.erc721_enumerable.initializer();
    self.collection_id.write(collection_id);
    self.collection_manager.write(collection_manager);
}
```

---

## Phase 4 — `src/IPCollection.cairo`

### 4-A: COMP-05 — Replace `burn`/`batch_burn` events and rename to `archive`

Rename event structs in the `Event` enum:
- `TokenBurned` → `TokenArchived`
- `TokenBurnedBatch` → `TokenArchivedBatch`

Also rename fields in `CollectionStats` in `types.cairo`:
- `total_burned` → `total_archived`
- `last_burn_time` → `last_archive_time`

> **Cairo note:** Renaming struct fields in a `#[derive(starknet::Store)]` type stored in a `Map` is safe as long as field order and types are unchanged — the storage slot is computed positionally, not by name.

### 4-B: C-01 — Fix `batch_archive` — add ownership check in loop

```cairo
fn batch_archive(ref self: ContractState, tokens: Array<ByteArray>) {
    assert(tokens.len() > 0, 'Tokens array is empty');
    let caller = get_caller_address();
    let timestamp = get_block_timestamp();
    let mut i: u32 = 0;
    while i < tokens.len() {
        let token = TokenTrait::from_bytes(tokens.at(i).clone());
        let collection = self.collections.read(token.collection_id);
        assert(collection.is_active, 'Collection is not active');
        let token_owner = IERC721Dispatcher { contract_address: collection.ip_nft }
            .owner_of(token.token_id);
        assert(token_owner == caller, 'Caller not token owner');   // C-01 fix
        IIPNftDispatcher { contract_address: collection.ip_nft }.archive(token.token_id);
        let mut stats = self.collection_stats.read(token.collection_id);
        stats.total_archived += 1;
        stats.last_archive_time = timestamp;
        self.collection_stats.entry(token.collection_id).write(stats);
        i += 1;
    }
    self.emit(TokenArchivedBatch { tokens: tokens.clone(), operator: caller, timestamp });
}
```

### 4-C: R-05 — Token IDs start at 1

In `mint()`:
```cairo
// Before
let next_token_id = collection_stats.total_minted;
// After
let next_token_id = collection_stats.total_minted + 1;
```

In `batch_mint()`:
```cairo
// Before
let next_token_id = collection_stats.total_minted + i.into();
// After
let next_token_id = collection_stats.total_minted + i.into() + 1;
```

### 4-D: R-01 — Remove redundant cross-contract call in `mint()`

```cairo
// REMOVE these two lines (lines 258-259 in original):
// let metadata_uri = IERC721Dispatcher { contract_address: collection.ip_nft }
//     .token_uri(next_token_id);

// Use local variable directly in event:
self.emit(TokenMinted { collection_id, token_id: next_token_id, owner: recipient, metadata_uri: token_uri });
```

### 4-E: H-01 — Fix `batch_transfer` — add approval + caller authorization

```cairo
fn batch_transfer(ref self: ContractState, from: ContractAddress, to: ContractAddress, tokens: Array<ByteArray>) {
    assert(tokens.len() > 0, 'Tokens array is empty');
    let caller = get_caller_address();
    let timestamp = get_block_timestamp();
    let mut i: u32 = 0;
    while i < tokens.len() {
        let token = TokenTrait::from_bytes(tokens.at(i).clone());
        let collection = self.collections.read(token.collection_id);
        assert(collection.is_active, 'Collection is not active');
        let ip_nft = IERC721Dispatcher { contract_address: collection.ip_nft };
        // H-01: require contract approval
        let approved = ip_nft.get_approved(token.token_id);
        assert(approved == get_contract_address(), 'Contract not approved');
        // H-01: require caller is authorized
        let token_owner = ip_nft.owner_of(token.token_id);
        assert(
            caller == token_owner || ip_nft.is_approved_for_all(token_owner, caller),
            'Not authorized'
        );
        ip_nft.transfer_from(from, to, token.token_id);
        // R-03: update transfer stats
        let mut stats = self.collection_stats.read(token.collection_id);
        stats.total_transfers += 1;
        stats.last_transfer_time = timestamp;
        self.collection_stats.entry(token.collection_id).write(stats);
        i += 1;
    }
    self.emit(TokenTransferredBatch { from, to, tokens: tokens.clone(), operator: caller, timestamp });
}
```

### 4-F: M-02 — Fix `transfer_token` caller authorization + R-03 stats

```cairo
fn transfer_token(ref self: ContractState, from: ContractAddress, to: ContractAddress, token: ByteArray) {
    let token = TokenTrait::from_bytes(token);
    let collection = self.collections.read(token.collection_id);
    assert(collection.is_active, 'Collection is not active');
    let caller = get_caller_address();
    let ip_nft = IERC721Dispatcher { contract_address: collection.ip_nft };
    let approved = ip_nft.get_approved(token.token_id);
    assert(approved == get_contract_address(), 'Contract not approved');
    // M-02: verify caller is authorized
    let token_owner = ip_nft.owner_of(token.token_id);
    assert(
        caller == token_owner || ip_nft.is_approved_for_all(token_owner, caller),
        'Not authorized'
    );
    ip_nft.transfer_from(from, to, token.token_id);
    // R-03: update transfer stats
    let timestamp = get_block_timestamp();
    let mut stats = self.collection_stats.read(token.collection_id);
    stats.total_transfers += 1;
    stats.last_transfer_time = timestamp;
    self.collection_stats.entry(token.collection_id).write(stats);
    self.emit(TokenTransferred { collection_id: token.collection_id, token_id: token.token_id, operator: caller, timestamp });
}
```

### 4-G: M-01 — Validate array lengths in `batch_mint`

Add at the top of `batch_mint` before any loop:
```cairo
assert(recipients.len() == token_uris.len(), 'Array lengths mismatch');
```

### 4-H: L-02 — Validate non-empty name/symbol in `create_collection`

```cairo
assert(name.len() > 0, 'Name cannot be empty');
assert(symbol.len() > 0, 'Symbol cannot be empty');
```

### 4-I: L-01 — Implement `update_collection_metadata`

```cairo
fn update_collection_metadata(
    ref self: ContractState,
    collection_id: u256,
    name: ByteArray,
    symbol: ByteArray,
    base_uri: ByteArray,
) {
    let caller = get_caller_address();
    let mut collection = self.collections.read(collection_id);
    assert(collection.owner == caller, 'Not collection owner');
    assert(name.len() > 0, 'Name cannot be empty');
    assert(symbol.len() > 0, 'Symbol cannot be empty');
    collection.name = name.clone();
    collection.symbol = symbol.clone();
    collection.base_uri = base_uri.clone();
    self.collections.entry(collection_id).write(collection);
    self.emit(CollectionUpdated {
        collection_id, owner: caller, name, symbol, base_uri,
        timestamp: get_block_timestamp(),
    });
}
```

> **Cairo note:** The entire struct must be read, modified, and written back. Partial field update is not available for `Map<u256, Collection>`. `ip_nft` and `is_active` are preserved through this read-modify-write.

### 4-J: M-03 — Add `set_collection_active`

```cairo
fn set_collection_active(ref self: ContractState, collection_id: u256, is_active: bool) {
    let caller = get_caller_address();
    let mut collection = self.collections.read(collection_id);
    assert(collection.owner == caller, 'Not collection owner');
    collection.is_active = is_active;
    self.collections.entry(collection_id).write(collection);
}
```

### 4-K: L-03 — Make `get_token` revert on invalid input

```cairo
fn get_token(self: @ContractState, token: ByteArray) -> TokenData {
    let token = TokenTrait::from_bytes(token);
    let collection = self.collections.read(token.collection_id);
    assert(collection.is_active, 'Collection is not active');
    let ip_nft = IERC721Dispatcher { contract_address: collection.ip_nft };
    let owner = ip_nft.owner_of(token.token_id);   // reverts if non-existent
    let token_uri = ip_nft.token_uri(token.token_id);
    let nft = IIPNftDispatcher { contract_address: collection.ip_nft };
    TokenData {
        collection_id: token.collection_id,
        token_id: token.token_id,
        owner,
        metadata_uri: token_uri,
        original_creator: nft.get_token_creator(token.token_id),  // COMP-07
        registered_at: nft.get_token_registered_at(token.token_id), // COMP-07
    }
}
```

### 4-L: COMP-08 — Add `get_collection_count`

```cairo
fn get_collection_count(self: @ContractState) -> u256 {
    self.collection_count.read()
}
```

### 4-M: CRITICAL — Update `deploy_syscall` calldata to match new `IPNft` constructor

```cairo
// Before (includes owner: caller at position 4)
(name.clone(), symbol.clone(), base_uri.clone(), caller, collection_id, collection_manager)
    .serialize(ref constructor_calldata);

// After (owner removed — constructor no longer takes it)
(name.clone(), symbol.clone(), base_uri.clone(), collection_id, collection_manager)
    .serialize(ref constructor_calldata);
```

> ⚠️ **Highest implementation risk.** Constructor calldata is positional. If this is out of sync with the `IPNft` constructor, `collection_id` receives the value of `caller` and `collection_manager` is unset. The deploy will succeed but storage will be silently corrupted. Verify by running `test_create_collection` immediately after this change.

### 4-N: Update `batch_mint` token URI prefix for COMP-04

The `batch_mint` function passes `token_uri` directly to `IPNft.mint()`. Since `IPNft.mint()` now validates the URI prefix, no change is needed in `batch_mint` itself — the validation is enforced at the `IPNft` level. Confirm that test URIs are updated.

---

## Phase 5 — `tests/IPCollectionTest.cairo`

### Tests that break (must be updated)

| Test | Why broken | Fix |
|---|---|---|
| `test_mint_token` | Asserts `token_id == 0`; first ID is now `1` | Assert `token_id == 1` |
| `test_token_uri_match` | Same | Assert `token_id == 1` |
| `test_batch_mint_tokens` | Asserts `token0.token_id == 0`, `token1.token_id == 1` | Change to `1` and `2` |
| `test_get_all_user_tokens` | `token_id3 == 2` will be `3`; IDs shift throughout | Update all ID assertions +1 |
| `test_burn_token` | Function renamed to `archive` | `dispatcher.archive(token)` |
| `test_burn_not_owner` | Same rename + panic message may change | Update call + expected message |
| All tests with `token_uri: "QmCollectionBaseUri"` | COMP-04 rejects non-`ipfs://` URIs | Change to `"ipfs://QmCollectionBaseUri"` in every test |

### New tests required

**Security regressions (highest priority):**
- `test_batch_archive_unauthorized` — `USER2` calls `batch_archive` on `USER1`'s tokens → `'Caller not token owner'` (C-01)
- `test_batch_transfer_not_approved` — no contract approval → `'Contract not approved'` (H-01)
- `test_batch_transfer_unauthorized_caller` — caller is not the `from` address and has no approval → `'Not authorized'` (H-01)
- `test_batch_mint_length_mismatch` — `recipients.len() != token_uris.len()` → `'Array lengths mismatch'` (M-01)
- `test_transfer_token_unauthorized_caller` — third party calls `transfer_token` → `'Not authorized'` (M-02)

**Compliance:**
- `test_archive_preserves_record` — archive a token, then query `get_token_creator`, `get_token_registered_at`, `token_uri` — all still return correct values (COMP-05)
- `test_archived_token_transfer_blocked` — archive then attempt transfer → `'Token is archived'` (COMP-05)
- `test_mint_invalid_uri_http_rejected` — `"https://example.com"` → `'URI must be ipfs:// or ar://'` (COMP-04)
- `test_mint_valid_ar_uri` — `"ar://txid"` → mints successfully (COMP-04)
- `test_get_token_creator` — mint, assert `get_token_creator(token_id) == recipient` (COMP-02/06)
- `test_get_token_registered_at` — mint with non-zero block timestamp, assert `get_token_registered_at > 0` (COMP-03/06) — use `start_cheat_block_timestamp` cheatcode
- `test_token_data_includes_creator_and_timestamp` — `get_token` returns populated `original_creator` and `registered_at` (COMP-07)

**New functions:**
- `test_set_collection_active_toggle` — owner deactivates, `is_valid_collection` returns false, reactivates, returns true (M-03)
- `test_set_collection_active_not_owner` → `'Not collection owner'` panic (M-03)
- `test_update_collection_metadata` — owner updates, asserts new name/symbol stored, `ip_nft` address unchanged (L-01)
- `test_update_collection_metadata_not_owner` → panic (L-01)
- `test_create_collection_empty_name` → `'Name cannot be empty'` (L-02)
- `test_create_collection_empty_symbol` → `'Symbol cannot be empty'` (L-02)
- `test_get_token_invalid_reverts` — non-existent token → revert (L-03)
- `test_get_collection_count` — create 2 collections, assert `get_collection_count() == 2` (COMP-08)
- `test_transfer_stats_updated` — transfer, assert `total_transfers == 1` and `last_transfer_time != 0` (R-03)

**Parser:**
- `test_from_bytes_non_digit_panics` — `"12a:3"` → panic (M-04)
- `test_from_bytes_no_colon_panics` — `"123"` → panic (L-04)
- `test_from_bytes_multiple_colons_panics` — `"1:2:3"` → panic (L-04)

---

## Cairo-Specific Gotchas Summary

| Risk | Details |
|---|---|
| **deploy_syscall calldata (Phase 4-M)** | Highest risk. Calldata is positional. Must remove `owner` arg in sync with `IPNft` constructor change. Test immediately with `test_create_collection`. |
| **Storage layout on component removal** | Removing `UpgradeableComponent` and `OwnableComponent` substorage shifts slot offsets. Breaking change for existing instances — intentional (they become permanently immutable). New collections use the new class hash. |
| **`bytearray_starts_with` helper** | `ByteArray` has no native prefix check. Must implement byte-by-byte. Check `haystack.len() >= needle.len()` before the loop. |
| **`Map<u256, bool>` default** | Unwritten keys return `false`. `token_archived` is correct at mint without initialization. Do not add unnecessary writes. |
| **`before_update` fires on mint** | The archived check in `before_update` fires during the initial mint call too. Since `token_archived` defaults to `false`, the assert passes cleanly. No guard needed. |
| **`get_block_timestamp()` in tests** | Returns `0` by default in snforge. Use `start_cheat_block_timestamp(address, value)` in any test asserting `registered_at > 0`. |
| **Struct field rename vs. storage** | Renaming `total_burned` → `total_archived` in `CollectionStats` is purely a source rename. The `starknet::Store` derive computes slots positionally. On-chain layout is unchanged. |

---

## Change Classification by Item

| ID | Severity | Phase | Category |
|---|---|---|---|
| C-01 | Critical | 4-B | Security |
| H-01 | High | 4-E | Security |
| COMP-01 | Critical (legal) | 3-A | Compliance |
| COMP-02 | High (legal) | 3-E/F | Compliance |
| COMP-03 | High (legal) | 3-E/F | Compliance |
| COMP-04 | High (legal) | 3-E | Compliance |
| COMP-05 | High (legal) | 1-A, 2-A, 3-D, 4-A/B | Compliance |
| COMP-06 | Medium | 1-B, 3-F | Compliance |
| COMP-07 | Medium | 0-A, 4-K | Compliance |
| COMP-08 | Medium | 2-D, 4-L | Compliance |
| M-01 | Medium | 4-G | Security |
| M-02 | Medium | 4-F | Security |
| M-03 | Medium | 2-B, 4-J | Feature |
| M-04 | Medium | 0-B | Security |
| L-01 | Low | 2-C, 4-I | Feature |
| L-02 | Low | 4-H | Security |
| L-03 | Low | 4-K | Correctness |
| L-04 | Low | 0-C | Security |
| R-01 | Refactor | 4-D | Gas |
| R-02 | Refactor | 4-F | Cleanliness |
| R-03 | Refactor | 4-E/F | Correctness |
| R-04 | Refactor | 3-B | Architecture |
| R-05 | Refactor | 4-C | Correctness |

---

*Plan authored 2026-04-10 — execute phases sequentially, run `scarb build` after each phase before proceeding.*
