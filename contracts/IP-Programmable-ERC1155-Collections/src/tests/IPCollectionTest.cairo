use ip_programmable_erc1155_collections::interfaces::IIPCollection::{
    IIPCollectionDispatcher, IIPCollectionDispatcherTrait,
};
use openzeppelin::token::erc1155::interface::{
    IERC1155Dispatcher, IERC1155DispatcherTrait, IERC1155MetadataURIDispatcher,
    IERC1155MetadataURIDispatcherTrait,
};
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin::token::common::erc2981::interface::{
    IERC2981Dispatcher, IERC2981DispatcherTrait, IERC2981AdminDispatcher,
    IERC2981AdminDispatcherTrait, IERC2981InfoDispatcher, IERC2981InfoDispatcherTrait,
};
use openzeppelin::introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use openzeppelin::token::common::erc2981::interface::IERC2981_ID;
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address,
    cheat_block_timestamp, declare,
};
use starknet::ContractAddress;

// ─── Constants ─────────────────────────────────────────────────────────────────

fn OWNER() -> ContractAddress {
    0x100.try_into().unwrap()
}
fn USER1() -> ContractAddress {
    0x200.try_into().unwrap()
}
fn USER2() -> ContractAddress {
    0x300.try_into().unwrap()
}
fn ZERO() -> ContractAddress {
    0.try_into().unwrap()
}

fn IPFS_URI() -> ByteArray {
    "ipfs://QmTestHash1234567890"
}
fn AR_URI() -> ByteArray {
    "ar://txidABCDEFGH"
}
fn IPFS_URI_2() -> ByteArray {
    "ipfs://QmSecondHash9876543210"
}
fn BARE_CID() -> ByteArray {
    "QmBareHashNoPrefix"
}
fn HTTP_URI() -> ByteArray {
    "https://example.com/metadata.json"
}

const TOKEN_ID_1: u256 = 1;
const TOKEN_ID_2: u256 = 2;
const TOKEN_ID_3: u256 = 3;
const VALUE_1: u256 = 10;
const VALUE_2: u256 = 5;
const VALUE_3: u256 = 1;

// ─── Helpers ───────────────────────────────────────────────────────────────────

/// Deploy a fresh ERC1155Receiver mock (used as minting recipient).
fn deploy_receiver() -> ContractAddress {
    let declare_result = declare("ERC1155Receiver").unwrap();
    let contract_class = declare_result.contract_class();
    let (address, _) = contract_class.deploy(@array![]).unwrap();
    address
}

/// Deploy IPCollection with given owner.
fn deploy_collection(owner: ContractAddress) -> (IIPCollectionDispatcher, ContractAddress) {
    let name: ByteArray = "Test IP Collection";
    let symbol: ByteArray = "TIP";

    let mut calldata: Array<felt252> = array![];
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    owner.serialize(ref calldata);

    let declare_result = declare("IPCollection").unwrap();
    let contract_class = declare_result.contract_class();
    let (address, _) = contract_class.deploy(@calldata).unwrap();

    let dispatcher = IIPCollectionDispatcher { contract_address: address };
    (dispatcher, address)
}

// ─── Constructor ───────────────────────────────────────────────────────────────

#[test]
fn test_constructor_owner() {
    let owner = OWNER();
    let (_, address) = deploy_collection(owner);
    let ownable = IOwnableDispatcher { contract_address: address };
    assert_eq!(ownable.owner(), owner);
}

#[test]
fn test_constructor_collection_creator() {
    let owner = OWNER();
    let (collection, _) = deploy_collection(owner);
    assert_eq!(collection.get_collection_creator(), owner);
}

// ─── mint_item ─────────────────────────────────────────────────────────────────

#[test]
fn test_mint_item_ipfs_uri() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient, TOKEN_ID_1, VALUE_1, IPFS_URI());

    let erc1155 = IERC1155Dispatcher { contract_address: address };
    assert_eq!(erc1155.balance_of(recipient, TOKEN_ID_1), VALUE_1);
}

#[test]
fn test_mint_item_ar_uri() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient, TOKEN_ID_1, VALUE_1, AR_URI());

    let erc1155 = IERC1155Dispatcher { contract_address: address };
    assert_eq!(erc1155.balance_of(recipient, TOKEN_ID_1), VALUE_1);
}

#[test]
fn test_mint_item_stores_creator() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient, TOKEN_ID_1, VALUE_1, IPFS_URI());

    // The creator is the recipient (first `to` address), not the owner.
    assert_eq!(collection.get_token_creator(TOKEN_ID_1), recipient);
}

#[test]
fn test_mint_item_stores_registered_at() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    let mock_timestamp: u64 = 1700000000;
    cheat_block_timestamp(address, mock_timestamp, CheatSpan::TargetCalls(1));
    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient, TOKEN_ID_1, VALUE_1, IPFS_URI());

    assert_eq!(collection.get_token_registered_at(TOKEN_ID_1), mock_timestamp);
}

#[test]
fn test_mint_item_uri_stored() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient, TOKEN_ID_1, VALUE_1, IPFS_URI());

    let metadata = IERC1155MetadataURIDispatcher { contract_address: address };
    assert_eq!(metadata.uri(TOKEN_ID_1), IPFS_URI());
}

#[test]
fn test_get_token_data_all_fields() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    let mock_timestamp: u64 = 1700000000;
    cheat_block_timestamp(address, mock_timestamp, CheatSpan::TargetCalls(1));
    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient, TOKEN_ID_1, VALUE_1, IPFS_URI());

    let token_data = collection.get_token_data(TOKEN_ID_1);
    assert_eq!(token_data.token_id, TOKEN_ID_1);
    assert_eq!(token_data.original_creator, recipient);
    assert_eq!(token_data.registered_at, mock_timestamp);
    assert_eq!(token_data.metadata_uri, IPFS_URI());
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_mint_item_not_owner() {
    let owner = OWNER();
    let (collection, _) = deploy_collection(owner);
    let recipient = deploy_receiver();
    // No cheat: caller defaults to zero (not owner)
    collection.mint_item(recipient, TOKEN_ID_1, VALUE_1, IPFS_URI());
}

#[test]
#[should_panic(expected: 'Recipient is zero address')]
fn test_mint_item_zero_recipient() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(ZERO(), TOKEN_ID_1, VALUE_1, IPFS_URI());
}

#[test]
#[should_panic(expected: 'URI must be ipfs:// or ar://')]
fn test_mint_item_bare_cid_rejected() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient, TOKEN_ID_1, VALUE_1, BARE_CID());
}

#[test]
#[should_panic(expected: 'URI must be ipfs:// or ar://')]
fn test_mint_item_http_uri_rejected() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient, TOKEN_ID_1, VALUE_1, HTTP_URI());
}

// ─── Subsequent mint of same token_id ─────────────────────────────────────────

#[test]
fn test_remint_existing_token_increases_balance() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    // First mint — stores provenance
    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient, TOKEN_ID_1, VALUE_1, IPFS_URI());

    // Second mint — provenance unchanged, balance increases
    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient, TOKEN_ID_1, VALUE_2, "bare-cid-ignored-on-remint");

    let erc1155 = IERC1155Dispatcher { contract_address: address };
    assert_eq!(erc1155.balance_of(recipient, TOKEN_ID_1), VALUE_1 + VALUE_2);
}

#[test]
fn test_remint_existing_token_preserves_creator() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();
    let recipient2 = deploy_receiver();

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient, TOKEN_ID_1, VALUE_1, IPFS_URI());

    // Second mint to different address — creator still the first recipient
    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient2, TOKEN_ID_1, VALUE_2, "ignored");

    assert_eq!(collection.get_token_creator(TOKEN_ID_1), recipient);
}

#[test]
fn test_remint_existing_token_preserves_uri() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient, TOKEN_ID_1, VALUE_1, IPFS_URI());

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient, TOKEN_ID_1, VALUE_2, "different-uri-ignored");

    let metadata = IERC1155MetadataURIDispatcher { contract_address: address };
    assert_eq!(metadata.uri(TOKEN_ID_1), IPFS_URI());
}

// ─── batch_mint_item ───────────────────────────────────────────────────────────

#[test]
fn test_batch_mint_item() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    let token_ids: Array<u256> = array![TOKEN_ID_1, TOKEN_ID_2, TOKEN_ID_3];
    let values: Array<u256> = array![VALUE_1, VALUE_2, VALUE_3];
    let uris: Array<ByteArray> = array![IPFS_URI(), AR_URI(), IPFS_URI_2()];

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.batch_mint_item(recipient, token_ids.span(), values.span(), uris);

    let erc1155 = IERC1155Dispatcher { contract_address: address };
    assert_eq!(erc1155.balance_of(recipient, TOKEN_ID_1), VALUE_1);
    assert_eq!(erc1155.balance_of(recipient, TOKEN_ID_2), VALUE_2);
    assert_eq!(erc1155.balance_of(recipient, TOKEN_ID_3), VALUE_3);
}

#[test]
fn test_batch_mint_item_stores_per_token_uri() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    let token_ids: Array<u256> = array![TOKEN_ID_1, TOKEN_ID_2];
    let values: Array<u256> = array![VALUE_1, VALUE_2];
    let uris: Array<ByteArray> = array![IPFS_URI(), AR_URI()];

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.batch_mint_item(recipient, token_ids.span(), values.span(), uris);

    let metadata = IERC1155MetadataURIDispatcher { contract_address: address };
    assert_eq!(metadata.uri(TOKEN_ID_1), IPFS_URI());
    assert_eq!(metadata.uri(TOKEN_ID_2), AR_URI());
}

#[test]
fn test_batch_mint_item_stores_per_token_creator() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    let token_ids: Array<u256> = array![TOKEN_ID_1, TOKEN_ID_2];
    let values: Array<u256> = array![VALUE_1, VALUE_2];
    let uris: Array<ByteArray> = array![IPFS_URI(), AR_URI()];

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.batch_mint_item(recipient, token_ids.span(), values.span(), uris);

    assert_eq!(collection.get_token_creator(TOKEN_ID_1), recipient);
    assert_eq!(collection.get_token_creator(TOKEN_ID_2), recipient);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_batch_mint_item_not_owner() {
    let owner = OWNER();
    let (collection, _) = deploy_collection(owner);
    let recipient = deploy_receiver();

    let token_ids: Array<u256> = array![TOKEN_ID_1];
    let values: Array<u256> = array![VALUE_1];
    let uris: Array<ByteArray> = array![IPFS_URI()];

    collection.batch_mint_item(recipient, token_ids.span(), values.span(), uris);
}

#[test]
#[should_panic(expected: 'Recipient is zero address')]
fn test_batch_mint_item_zero_recipient() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);

    let token_ids: Array<u256> = array![TOKEN_ID_1];
    let values: Array<u256> = array![VALUE_1];
    let uris: Array<ByteArray> = array![IPFS_URI()];

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.batch_mint_item(ZERO(), token_ids.span(), values.span(), uris);
}

#[test]
#[should_panic(expected: 'Array length mismatch')]
fn test_batch_mint_item_ids_values_mismatch() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    let token_ids: Array<u256> = array![TOKEN_ID_1, TOKEN_ID_2];
    let values: Array<u256> = array![VALUE_1]; // shorter
    let uris: Array<ByteArray> = array![IPFS_URI(), AR_URI()];

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.batch_mint_item(recipient, token_ids.span(), values.span(), uris);
}

#[test]
#[should_panic(expected: 'Array length mismatch')]
fn test_batch_mint_item_ids_uris_mismatch() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    let token_ids: Array<u256> = array![TOKEN_ID_1, TOKEN_ID_2];
    let values: Array<u256> = array![VALUE_1, VALUE_2];
    let uris: Array<ByteArray> = array![IPFS_URI()]; // shorter

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.batch_mint_item(recipient, token_ids.span(), values.span(), uris);
}

// ─── Provenance query guards ───────────────────────────────────────────────────

#[test]
#[should_panic(expected: 'Token does not exist')]
fn test_get_token_creator_nonexistent() {
    let owner = OWNER();
    let (collection, _) = deploy_collection(owner);
    collection.get_token_creator(TOKEN_ID_1);
}

#[test]
#[should_panic(expected: 'Token does not exist')]
fn test_get_token_registered_at_nonexistent() {
    let owner = OWNER();
    let (collection, _) = deploy_collection(owner);
    collection.get_token_registered_at(TOKEN_ID_1);
}

#[test]
#[should_panic(expected: 'Token does not exist')]
fn test_get_token_data_nonexistent() {
    let owner = OWNER();
    let (collection, _) = deploy_collection(owner);
    collection.get_token_data(TOKEN_ID_1);
}

// ─── ERC-1155 standard behaviour ──────────────────────────────────────────────

#[test]
fn test_transfer_between_receivers() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let receiver1 = deploy_receiver();
    let receiver2 = deploy_receiver();

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(receiver1, TOKEN_ID_1, VALUE_1, IPFS_URI());

    let erc1155 = IERC1155Dispatcher { contract_address: address };
    // receiver1 transfers to receiver2
    cheat_caller_address(address, receiver1, CheatSpan::TargetCalls(1));
    erc1155.safe_transfer_from(receiver1, receiver2, TOKEN_ID_1, VALUE_2, array![].span());

    assert_eq!(erc1155.balance_of(receiver1, TOKEN_ID_1), VALUE_1 - VALUE_2);
    assert_eq!(erc1155.balance_of(receiver2, TOKEN_ID_1), VALUE_2);
}

#[test]
fn test_balance_of_unminted_is_zero() {
    let owner = OWNER();
    let (_, address) = deploy_collection(owner);
    let erc1155 = IERC1155Dispatcher { contract_address: address };
    assert_eq!(erc1155.balance_of(USER1(), TOKEN_ID_1), 0);
}

#[test]
fn test_multiple_token_ids_independent_balances() {
    let owner = OWNER();
    let (collection, address) = deploy_collection(owner);
    let recipient = deploy_receiver();

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient, TOKEN_ID_1, VALUE_1, IPFS_URI());
    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    collection.mint_item(recipient, TOKEN_ID_2, VALUE_2, AR_URI());

    let erc1155 = IERC1155Dispatcher { contract_address: address };
    assert_eq!(erc1155.balance_of(recipient, TOKEN_ID_1), VALUE_1);
    assert_eq!(erc1155.balance_of(recipient, TOKEN_ID_2), VALUE_2);
    // Unrelated token is still zero
    assert_eq!(erc1155.balance_of(recipient, TOKEN_ID_3), 0);
}

// ─── ERC-2981 royalty ──────────────────────────────────────────────────────────

#[test]
fn test_royalty_default_is_zero_on_deploy() {
    let owner = OWNER();
    let (_, address) = deploy_collection(owner);
    let erc2981 = IERC2981Dispatcher { contract_address: address };
    let (_, amount) = erc2981.royalty_info(TOKEN_ID_1, 10_000);
    assert_eq!(amount, 0);
}

#[test]
fn test_supports_erc2981_interface() {
    let owner = OWNER();
    let (_, address) = deploy_collection(owner);
    let src5 = ISRC5Dispatcher { contract_address: address };
    assert!(src5.supports_interface(IERC2981_ID));
}

#[test]
fn test_set_default_royalty_owner() {
    let owner = OWNER();
    let (_, address) = deploy_collection(owner);
    let erc2981_admin = IERC2981AdminDispatcher { contract_address: address };

    // 5% royalty (500 / 10_000)
    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    erc2981_admin.set_default_royalty(owner, 500);

    let erc2981 = IERC2981Dispatcher { contract_address: address };
    let (receiver, amount) = erc2981.royalty_info(TOKEN_ID_1, 10_000);
    assert_eq!(receiver, owner);
    assert_eq!(amount, 500); // 5% of 10_000
}

#[test]
fn test_royalty_amount_calculation() {
    let owner = OWNER();
    let (_, address) = deploy_collection(owner);
    let erc2981_admin = IERC2981AdminDispatcher { contract_address: address };
    let erc2981 = IERC2981Dispatcher { contract_address: address };

    // Set 8% royalty (800 / 10_000) — same as Lil Duckies on Elements
    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    erc2981_admin.set_default_royalty(owner, 800);

    let sale_price: u256 = 1_000_000; // 1 STRK in micro-units
    let (_, amount) = erc2981.royalty_info(TOKEN_ID_1, sale_price);
    assert_eq!(amount, 80_000); // 8% of 1_000_000
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_default_royalty_not_owner() {
    let owner = OWNER();
    let (_, address) = deploy_collection(owner);
    let erc2981_admin = IERC2981AdminDispatcher { contract_address: address };

    // USER1 is not the owner — should panic
    cheat_caller_address(address, USER1(), CheatSpan::TargetCalls(1));
    erc2981_admin.set_default_royalty(USER1(), 500);
}

#[test]
fn test_set_token_royalty_overrides_default() {
    let owner = OWNER();
    let (_, address) = deploy_collection(owner);
    let erc2981_admin = IERC2981AdminDispatcher { contract_address: address };
    let erc2981 = IERC2981Dispatcher { contract_address: address };

    // Default: 5%
    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    erc2981_admin.set_default_royalty(owner, 500);

    // Token 2 override: 10%
    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    erc2981_admin.set_token_royalty(TOKEN_ID_2, USER2(), 1000);

    let (_, default_amount) = erc2981.royalty_info(TOKEN_ID_1, 10_000);
    let (token2_receiver, token2_amount) = erc2981.royalty_info(TOKEN_ID_2, 10_000);

    assert_eq!(default_amount, 500);    // TOKEN_ID_1 uses default 5%
    assert_eq!(token2_amount, 1000);    // TOKEN_ID_2 uses override 10%
    assert_eq!(token2_receiver, USER2());
}

#[test]
fn test_delete_default_royalty() {
    let owner = OWNER();
    let (_, address) = deploy_collection(owner);
    let erc2981_admin = IERC2981AdminDispatcher { contract_address: address };
    let erc2981 = IERC2981Dispatcher { contract_address: address };

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    erc2981_admin.set_default_royalty(owner, 500);

    // Confirm it was set
    let (_, amount_before) = erc2981.royalty_info(TOKEN_ID_1, 10_000);
    assert_eq!(amount_before, 500);

    // Delete it
    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    erc2981_admin.delete_default_royalty();

    let (_, amount_after) = erc2981.royalty_info(TOKEN_ID_1, 10_000);
    assert_eq!(amount_after, 0);
}

#[test]
fn test_reset_token_royalty_falls_back_to_default() {
    let owner = OWNER();
    let (_, address) = deploy_collection(owner);
    let erc2981_admin = IERC2981AdminDispatcher { contract_address: address };
    let erc2981 = IERC2981Dispatcher { contract_address: address };

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    erc2981_admin.set_default_royalty(owner, 500);
    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    erc2981_admin.set_token_royalty(TOKEN_ID_1, USER2(), 1000);

    // Confirm override is active
    let (_, override_amount) = erc2981.royalty_info(TOKEN_ID_1, 10_000);
    assert_eq!(override_amount, 1000);

    // Reset token royalty — should fall back to default 5%
    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    erc2981_admin.reset_token_royalty(TOKEN_ID_1);

    let (receiver_after, amount_after) = erc2981.royalty_info(TOKEN_ID_1, 10_000);
    assert_eq!(amount_after, 500);
    assert_eq!(receiver_after, owner);
}

#[test]
fn test_default_royalty_info_returns_denominator() {
    let owner = OWNER();
    let (_, address) = deploy_collection(owner);
    let erc2981_admin = IERC2981AdminDispatcher { contract_address: address };
    let erc2981_info = IERC2981InfoDispatcher { contract_address: address };

    cheat_caller_address(address, owner, CheatSpan::TargetCalls(1));
    erc2981_admin.set_default_royalty(owner, 750);

    let (receiver, numerator, denominator) = erc2981_info.default_royalty();
    assert_eq!(receiver, owner);
    assert_eq!(numerator, 750);
    assert_eq!(denominator, 10_000); // DefaultConfig FEE_DENOMINATOR
}
