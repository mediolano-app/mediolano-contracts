# IP-Programmable-ERC-1155

A self-contained ERC-1155 multi-token contract for IP assets on Starknet. Tokens are minted at deploy time and carry per-token metadata URIs and licensing fields.

> **Status: Prototype / Pre-production.** This contract is a minimal hand-rolled ERC-1155 without OpenZeppelin components. It lacks access control, has known token-tracking bugs, and has no test suite. See `AUDIT_REPORT.md` for details. Use `IP-Programmable-ERC1155-Collections` for production deployments.

## Overview

`IP-Programmable-ERC-1155` is a single-contract ERC-1155 implementation for programmable IP licensing where:

- All tokens are batch-minted to a designated recipient at construction time.
- Each token type shares the same URI (set at deploy time).
- A per-token `license` field stores IP licensing terms.
- Token holders can transfer their balances using standard ERC-1155 transfer calls.

## Storage

| Field | Type | Description |
|---|---|---|
| `ERC1155_balances` | `Map<(u256, ContractAddress), u256>` | Token balance per (token_id, holder) |
| `ERC1155_operator_approvals` | `Map<(ContractAddress, ContractAddress), bool>` | Operator approvals |
| `ERC1155_uri` | `Map<u256, ByteArray>` | Metadata URI per token (same value for all, set at deploy) |
| `ERC1155_licenses` | `Map<u256, ByteArray>` | License terms per token |
| `ERC1155_owned_tokens` | `Map<ContractAddress, u256>` | Count of token types owned by an address |
| `ERC1155_owned_tokens_list` | `Map<(ContractAddress, u256), u256>` | Enumerable token ID list per owner |
| `owner` | `ContractAddress` | Contract deployer |

## Constructor

```cairo
constructor(
    token_uri: ByteArray,       // shared URI applied to all token IDs
    recipient: ContractAddress, // address that receives all minted tokens
    token_ids: Span<u256>,      // list of token IDs to mint
    values: Span<u256>,         // corresponding quantities
)
```

`token_ids` and `values` must be the same length. The deployer is stored as `owner`.

## Interface

```cairo
// Standard ERC-1155
fn balance_of(account, token_id) -> u256
fn balance_of_batch(accounts, token_ids) -> Span<u256>
fn set_approval_for_all(operator, approved)
fn is_approved_for_all(owner, operator) -> bool
fn safe_transfer_from(from, to, token_id, value, data)
fn safe_batch_transfer_from(from, to, token_ids, values, data)
fn uri(token_id) -> ByteArray

// IP extensions
fn get_license(token_id) -> ByteArray
fn list_tokens(owner) -> Span<u256>
```

## Events

| Event | Fields |
|---|---|
| `TransferSingle` | operator, from, to, token_id, value |
| `TransferBatch` | operator, from, to, token_ids, values |
| `ApprovalForAll` | owner, operator, approved |

## Known Limitations

- **No license setter** — `ERC1155_licenses` storage exists but there is no post-deploy setter function.
- **Token tracking bug** — `list_tokens` can produce incorrect results after transfers.
- **No OpenZeppelin** — ERC-1155 logic is hand-rolled without the battle-tested OZ components.
- **No access control** — `owner` is stored but not enforced on any function.
- **No test suite** — zero tests.
- **Uniform URI** — all token IDs receive the same URI at deploy.

## Development

```bash
cd contracts/IP-Programmable-ERC-1155

# Build
scarb build
```

## Dependencies

| Package | Version |
|---|---|
| `starknet` | `2.9.2` |
| `snforge_std` | `v0.34.0` |
