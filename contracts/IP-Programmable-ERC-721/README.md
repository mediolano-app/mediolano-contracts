# IP-Programmable-ERC-721

Standalone, permissionless, immutable ERC-721 collection contract for the [Mediolano](https://mediolano.app) IP protocol on Starknet.

Any address can deploy a collection instance and any address can mint into it — no admin, no owner, no upgradeability. Each token carries a permanent IP provenance record (original creator + registration timestamp) written immutably at mint time, satisfying the Berne Convention authorship standard across 181 countries.

---

## Architecture

- **Single contract, no factory.** Each deployment is a standalone collection.
- **Permissionless mint.** Any caller, any recipient — no access control.
- **Immutable.** No `UpgradeableComponent`, no admin roles, no setter functions on provenance data.
- **Safe mint.** Uses `safe_mint` to prevent token lockup in non-receiver contracts.
- **Full per-token URI.** Each token stores its complete `ipfs://` or `ar://` URI — no base URI concatenation.
- **ERC721 Enumerable.** Full enumeration support via OZ `ERC721EnumerableComponent`.

## Interface

```cairo
fn mint_item(recipient: ContractAddress, token_uri: ByteArray) -> u256
fn get_collection_creator() -> ContractAddress
fn get_token_creator(token_id: u256) -> ContractAddress
fn get_token_registered_at(token_id: u256) -> u64
fn get_token_data(token_id: u256) -> TokenData
```

## IP Provenance

```cairo
pub struct TokenData {
    token_id: u256,
    owner: ContractAddress,
    metadata_uri: ByteArray,
    original_creator: ContractAddress,  // immutable — set at mint
    registered_at: u64,                 // block timestamp at mint — immutable
}
```

---

## Deployments (Starknet Mainnet)

### Class Hash
```
0x1bd7e39c5135b32b664e34cbbb4eafbd707a0fbc3ec2ef28657f52577d277d7
```

### Deployed Collections

| Collection | Address | Symbol |
|---|---|---|
| MIP (Medialane Genesis) | `0x06ed61abba98a44d45bed2c4b1a456df15053c3321cfd6e007afb33b7226c9f0` | MIP |
| Genesis Mint BR | `0x01f8b92e3b9e963b8eacb075207e2cc89d4614ff2ac6c2702c7ae10ad19a9db8` | GMBR |

### Deploy a New Collection

The class is already declared — just deploy a new instance:

```bash
sncast deploy \
  --class-hash 0x1bd7e39c5135b32b664e34cbbb4eafbd707a0fbc3ec2ef28657f52577d277d7 \
  --arguments '"My Collection","SYM",0x<your_address>'
```

---

## Development

```bash
# Build
scarb build

# Test (40 tests)
scarb test

# Format
scarb fmt
```

### Dependencies
```toml
starknet = "2.12.0"
openzeppelin = { git = "https://github.com/OpenZeppelin/cairo-contracts.git", tag = "v0.20.0" }
snforge_std = "0.58.0"   # dev
```

---

## Security

- No reentrancy vectors (Cairo single-threaded execution)
- No integer overflow (Cairo 2 native bounds checking)
- No token lockup risk (`safe_mint` checks `IERC721Receiver` or `ISRC6` on recipient)
- IP provenance fields have no setters — structurally immutable after mint

See [REPORT.md](./REPORT.md) for the full audit and deployment report.
