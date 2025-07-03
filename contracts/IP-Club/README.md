# 🪐 IPClub: Cairo Smart Contracts for Permissionless NFT-Based Communities

## Overview

**IPClub** enables users to **create, manage, and monetize permissionless communities** on **Starknet** using **NFT-based membership**.
It consists of:

* **`IPClub` contract**: Manages community creation, membership validation, and payments.
* **`IPClubNFT` contract**: ERC721 membership NFTs representing community access.

Creators can establish communities tied to **Programmable IP NFTs or collections**, enabling:

* Users to **mint or buy NFTs** to join.
* Monetization via entry fees.
* NFT-gated exclusive features.

---

## 📜 Contracts

### 1️⃣ `IPClub` Contract

#### Key Responsibilities:

✅ **Community Creation**

* Users can create new clubs specifying:

  * Name, symbol, metadata URI
  * Max members
  * Entry fee and payment token (optional)
* Deploys a dedicated **`IPClubNFT`** contract for the club.

✅ **Permissionless Joining**

* Users can **join a club** by:

  * Paying the entry fee (if required).
  * Minting a membership NFT in the associated `IPClubNFT`.

✅ **Membership Validation**

* Provides `is_member(club_id, user)` to check NFT-based membership.

✅ **Club Management**

* Club creators can **close their club**, preventing further joins.

✅ **Events**

* Emits:

  * `NewClubCreated`
  * `NewMember`
  * `ClubClosed`

✅ **Upgradeable**

* Follows upgradeable architecture using OpenZeppelin Starknet upgrades.

---

### 2️⃣ `IPClubNFT` Contract

A minimal **ERC721 membership NFT contract** deployed for each club.

#### Key Responsibilities:

✅ **Mint Membership NFTs**

* Mints NFTs to users joining the club.
* Restricts minting to the authorized `IPClub` contract.

✅ **Track Ownership**

* Uses ERC721 standard methods for transfers, balance, and ownership checks.

✅ **Event Emission**

* Emits `NFTMinted` upon minting membership NFTs.

✅ **Metadata Management**

* Stores and exposes:

  * Name
  * Symbol
  * Metadata URI

✅ **Access Control**

* Uses role-based control, granting the `IPClub` contract admin privileges for minting.

---

## 🛠️ Key Data Structures

### `ClubRecord`

Stores metadata for each club:

* `id`: Club ID
* `name`, `symbol`, `metadata_uri`
* `status`: (`Inactive`, `Open`, `Closed`)
* `num_members`
* `creator`: Address of the creator
* `club_nft`: Address of associated `IPClubNFT`
* `max_members`: Optional cap on members
* `entry_fee`: Optional entry fee
* `payment_token`: ERC20 token address for payment

---

## Key Functions

### `IPClub`

* `constructor(admin, ip_club_nft_class_hash)`
  Initializes the contract with admin and NFT class hash.

* `create_club(name, symbol, metadata_uri, max_members, entry_fee, payment_token)`
  Creates a new club, deploying a dedicated `IPClubNFT`.

* `join_club(club_id)`
  Allows users to join the club, handling entry fee and minting NFT.

* `close_club(club_id)`
  Allows the creator to close the club.

* `get_club_record(club_id)` → `ClubRecord`
  Fetches a club’s record.

* `is_member(club_id, user)` → `bool`
  Checks if a user is a member.

* `get_last_club_id()` → `u256`
  Returns the last created club ID.

---

### `IPClubNFT`

* `constructor(name, symbol, club_id, creator, ip_club_manager, metadata_uri)`
  Initializes NFT contract for the club.

* `mint(recipient)`
  Mints membership NFT to a recipient (only callable by `IPClub`).

* `has_nft(user)` → `bool`
  Checks if a user owns the membership NFT.

* `get_nft_creator()`, `get_ip_club_manager()`, `get_associated_club_id()`, `get_last_minted_id()`
  Fetches associated metadata for tracking and integrations.

---

## ⚡ Example Flow

1️⃣ **Creator deploys `IPClub`.**

2️⃣ Creator calls `create_club(...)` to set up a new club:
→ `IPClubNFT` is deployed automatically.

3️⃣ Users call `join_club(club_id)`:
→ Pays entry fee if set.
→ Mints NFT representing membership.

4️⃣ Users can access exclusive features gated by `is_member(club_id, user)`.

5️⃣ Creator can call `close_club(club_id)` to prevent new members from joining.

---

## ✅ Testing

The contract tests for:

* Community creation with/without fees.
* Joining clubs with correct payment logic.
* Membership validation checks.
* NFT minting and ownership tracking.

---

## 🛡️ Security & Best Practices

* Uses **OpenZeppelin Starknet libraries** for upgradeability and access control.
* Validates fee and membership constraints.
* Follows **ERC721 standard** for NFT interoperability.

---

## 🚀 Deployment Notes

* Requires `ip_club_nft_class_hash` at deployment (class hash of the `IPClubNFT`).
* Designed for Starknet and Cairo 1 projects using **Scarb** for dependency management.
