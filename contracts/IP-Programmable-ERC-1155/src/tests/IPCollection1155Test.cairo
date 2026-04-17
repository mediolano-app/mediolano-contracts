use ip_programmable_erc_1155::IPCollection1155::IPCollection1155::{Event, IPMinted, LicenseUpdated};
use ip_programmable_erc_1155::interfaces::IIPCollection1155::{
    IIPCollection1155Dispatcher, IIPCollection1155DispatcherTrait,
};
use openzeppelin::introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use openzeppelin::token::erc1155::interface::{
    IERC1155Dispatcher, IERC1155DispatcherTrait, IERC1155MetadataURIDispatcher,
    IERC1155MetadataURIDispatcherTrait,
};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
    cheat_block_timestamp, cheat_caller_address, declare, spy_events,
};
use starknet::ContractAddress;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

fn CREATOR() -> ContractAddress {
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
    "ipfs://QmTestMetadataHash"
}
fn AR_URI() -> ByteArray {
    "ar://txid123456"
}
fn IPFS_URI_2() -> ByteArray {
    "ipfs://QmSecondMetadataHash"
}
fn HTTP_URI() -> ByteArray {
    "https://example.com/metadata.json"
}
fn EMPTY_URI() -> ByteArray {
    ""
}
fn PARTIAL_IPFS_URI() -> ByteArray {
    "ipfs:/QmFoo"
}
fn LICENSE_CC0() -> ByteArray {
    "CC0-1.0"
}
fn LICENSE_MIT() -> ByteArray {
    "MIT"
}

// OZ v0.20.0 ERC-1155 interface ID
fn IERC1155_ID() -> felt252 {
    0x6114a8f75559e1b39fcba08ce02961a1aa082d9256a158dd3e64964e4b1b52
}

// ---------------------------------------------------------------------------
// Deploy helpers
// ---------------------------------------------------------------------------

fn deploy_contract(creator: ContractAddress) -> (IIPCollection1155Dispatcher, ContractAddress) {
    let contract = declare("IPCollection1155").unwrap().contract_class();
    let mut calldata = array![];
    creator.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    (IIPCollection1155Dispatcher { contract_address: address }, address)
}

fn deploy_mock_account() -> ContractAddress {
    let contract = declare("MockAccount").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![]).unwrap();
    address
}

fn deploy_receiver() -> ContractAddress {
    let contract = declare("ERC1155Receiver").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![]).unwrap();
    address
}

/// Full setup: contract + two independent mock user accounts.
fn setup() -> (IIPCollection1155Dispatcher, ContractAddress, ContractAddress, ContractAddress) {
    let (col, addr) = deploy_contract(CREATOR());
    let user1 = deploy_mock_account();
    let user2 = deploy_mock_account();
    (col, addr, user1, user2)
}

// ---------------------------------------------------------------------------
// Constructor / Deployment
// ---------------------------------------------------------------------------

#[test]
fn test_deploy_succeeds() {
    let (col, _) = deploy_contract(CREATOR());
    assert(col.get_collection_creator() == CREATOR(), 'creator should be set');
}

#[test]
fn test_collection_creator_is_set() {
    let (col, _) = deploy_contract(CREATOR());
    assert(col.get_collection_creator() == CREATOR(), 'creator mismatch');
}

#[test]
fn test_collection_creator_different_from_user() {
    let (col, _) = deploy_contract(USER1());
    assert(col.get_collection_creator() == USER1(), 'creator should be USER1');
    assert(col.get_collection_creator() != USER2(), 'should not be USER2');
}

// ---------------------------------------------------------------------------
// mint_item — success cases
// ---------------------------------------------------------------------------

#[test]
fn test_mint_ipfs_uri_returns_token_id_one() {
    let (col, _, user1, _) = setup();
    let token_id = col.mint_item(user1, 10, IPFS_URI(), LICENSE_CC0());
    assert(token_id == 1, 'first token id should be 1');
}

#[test]
fn test_mint_ar_uri_returns_token_id_one() {
    let (col, _, user1, _) = setup();
    let token_id = col.mint_item(user1, 5, AR_URI(), "");
    assert(token_id == 1, 'first token id should be 1');
}

#[test]
fn test_mint_sequential_ids() {
    let (col, _, user1, user2) = setup();
    let id1 = col.mint_item(user1, 10, IPFS_URI(), LICENSE_CC0());
    let id2 = col.mint_item(user2, 5, AR_URI(), "");
    assert(id1 == 1, 'first id should be 1');
    assert(id2 == 2, 'second id should be 2');
}

#[test]
fn test_mint_balance_increments() {
    let (col, addr, user1, _) = setup();
    col.mint_item(user1, 7, IPFS_URI(), "");
    let erc1155 = IERC1155Dispatcher { contract_address: addr };
    assert(erc1155.balance_of(user1, 1) == 7, 'balance should be 7');
}

#[test]
fn test_mint_large_amount() {
    let (col, addr, user1, _) = setup();
    col.mint_item(user1, 1000000, IPFS_URI(), "");
    let erc1155 = IERC1155Dispatcher { contract_address: addr };
    assert(erc1155.balance_of(user1, 1) == 1000000, 'balance should be 1000000');
}

#[test]
fn test_mint_different_recipients_same_token_type() {
    let (col, addr, user1, user2) = setup();
    // Two separate mints create two separate token types (different IDs)
    let id1 = col.mint_item(user1, 3, IPFS_URI(), "");
    let id2 = col.mint_item(user2, 3, IPFS_URI_2(), "");
    let erc1155 = IERC1155Dispatcher { contract_address: addr };
    assert(erc1155.balance_of(user1, id1) == 3, 'user1 balance should be 3');
    assert(erc1155.balance_of(user2, id2) == 3, 'user2 balance should be 3');
    assert(id1 != id2, 'ids should differ');
}

#[test]
fn test_mint_uri_is_stored() {
    let (col, addr, user1, _) = setup();
    col.mint_item(user1, 1, IPFS_URI(), "");
    let meta = IERC1155MetadataURIDispatcher { contract_address: addr };
    assert(meta.uri(1) == IPFS_URI(), 'uri should match');
}

#[test]
fn test_mint_ar_uri_is_stored() {
    let (col, addr, user1, _) = setup();
    col.mint_item(user1, 1, AR_URI(), "");
    let meta = IERC1155MetadataURIDispatcher { contract_address: addr };
    assert(meta.uri(1) == AR_URI(), 'ar uri should match');
}

#[test]
fn test_mint_creator_recorded() {
    let (col, addr, user1, _) = setup();
    cheat_caller_address(addr, USER1(), CheatSpan::TargetCalls(1));
    col.mint_item(user1, 1, IPFS_URI(), "");
    assert(col.get_token_creator(1) == USER1(), 'creator should be USER1');
}

#[test]
fn test_mint_registered_at_matches_block_timestamp() {
    let (col, addr, user1, _) = setup();
    let ts: u64 = 1700000000;
    cheat_block_timestamp(addr, ts, CheatSpan::TargetCalls(1));
    col.mint_item(user1, 1, IPFS_URI(), "");
    assert(col.get_token_registered_at(1) == ts, 'timestamp should match');
}

#[test]
fn test_mint_license_stored() {
    let (col, _, user1, _) = setup();
    col.mint_item(user1, 1, IPFS_URI(), LICENSE_CC0());
    assert(col.get_license(1) == LICENSE_CC0(), 'license should be CC0');
}

#[test]
fn test_mint_empty_license_allowed() {
    let (col, _, user1, _) = setup();
    col.mint_item(user1, 1, IPFS_URI(), "");
    assert(col.get_license(1) == "", 'empty license should be stored');
}

#[test]
fn test_mint_to_erc1155_receiver() {
    let (col, addr, _, _) = setup();
    let receiver = deploy_receiver();
    col.mint_item(receiver, 5, IPFS_URI(), "");
    let erc1155 = IERC1155Dispatcher { contract_address: addr };
    assert(erc1155.balance_of(receiver, 1) == 5, 'receiver balance should be 5');
}

#[test]
fn test_mint_emits_ipminted_event() {
    let (col, addr, user1, _) = setup();
    let mut spy = spy_events();
    let ts: u64 = 1700000000;
    cheat_caller_address(addr, USER1(), CheatSpan::TargetCalls(1));
    cheat_block_timestamp(addr, ts, CheatSpan::TargetCalls(1));
    let token_id = col.mint_item(user1, 10, IPFS_URI(), LICENSE_CC0());
    let expected = Event::IPMinted(
        IPMinted {
            token_id,
            recipient: user1,
            amount: 10,
            uri: IPFS_URI(),
            creator: USER1(),
            registered_at: ts,
        },
    );
    spy.assert_emitted(@array![(addr, expected)]);
}

// ---------------------------------------------------------------------------
// mint_item — failure cases
// ---------------------------------------------------------------------------

#[test]
#[should_panic(expected: ('Recipient is zero address',))]
fn test_mint_zero_recipient_panics() {
    let (col, _, _, _) = setup();
    col.mint_item(ZERO(), 1, IPFS_URI(), "");
}

#[test]
#[should_panic(expected: ('Amount must be positive',))]
fn test_mint_zero_amount_panics() {
    let (col, _, user1, _) = setup();
    col.mint_item(user1, 0, IPFS_URI(), "");
}

#[test]
#[should_panic(expected: ('URI must be ipfs:// or ar://',))]
fn test_mint_http_uri_rejected() {
    let (col, _, user1, _) = setup();
    col.mint_item(user1, 1, HTTP_URI(), "");
}

#[test]
#[should_panic(expected: ('URI must be ipfs:// or ar://',))]
fn test_mint_empty_uri_rejected() {
    let (col, _, user1, _) = setup();
    col.mint_item(user1, 1, EMPTY_URI(), "");
}

#[test]
#[should_panic(expected: ('URI must be ipfs:// or ar://',))]
fn test_mint_partial_ipfs_prefix_rejected() {
    let (col, _, user1, _) = setup();
    col.mint_item(user1, 1, PARTIAL_IPFS_URI(), "");
}

#[test]
#[should_panic]
fn test_mint_to_non_receiver_contract_rejected() {
    // Minting to a contract that implements neither ERC1155Receiver nor ISRC6 must revert.
    let (col, _, _, _) = setup();
    // Deploy another IPCollection1155 as recipient — it has no receiver/account interface.
    let (_, non_receiver_addr) = deploy_contract(CREATOR());
    col.mint_item(non_receiver_addr, 1, IPFS_URI(), "");
}

// ---------------------------------------------------------------------------
// set_license
// ---------------------------------------------------------------------------

#[test]
fn test_set_license_by_creator_succeeds() {
    let (col, addr, user1, _) = setup();
    cheat_caller_address(addr, USER1(), CheatSpan::TargetCalls(2));
    col.mint_item(user1, 1, IPFS_URI(), "");
    col.set_license(1, LICENSE_MIT());
    assert(col.get_license(1) == LICENSE_MIT(), 'license should be MIT');
}

#[test]
fn test_set_license_overwrites_previous() {
    let (col, addr, user1, _) = setup();
    cheat_caller_address(addr, USER1(), CheatSpan::TargetCalls(3));
    col.mint_item(user1, 1, IPFS_URI(), LICENSE_CC0());
    col.set_license(1, LICENSE_MIT());
    col.set_license(1, "Apache-2.0");
    assert(col.get_license(1) == "Apache-2.0", 'license should be Apache');
}

#[test]
fn test_set_license_emits_event() {
    let (col, addr, user1, _) = setup();
    let mut spy = spy_events();
    cheat_caller_address(addr, USER1(), CheatSpan::TargetCalls(2));
    col.mint_item(user1, 1, IPFS_URI(), "");
    col.set_license(1, LICENSE_CC0());
    let expected = Event::LicenseUpdated(
        LicenseUpdated { token_id: 1, creator: USER1(), license: LICENSE_CC0() },
    );
    spy.assert_emitted(@array![(addr, expected)]);
}

#[test]
#[should_panic(expected: ('Only creator can set license',))]
fn test_set_license_non_creator_rejected() {
    let (col, addr, user1, user2) = setup();
    cheat_caller_address(addr, user1, CheatSpan::TargetCalls(1));
    col.mint_item(user1, 1, IPFS_URI(), "");
    cheat_caller_address(addr, user2, CheatSpan::TargetCalls(1));
    col.set_license(1, LICENSE_MIT());
}

#[test]
#[should_panic(expected: ('Token does not exist',))]
fn test_set_license_nonexistent_token_panics() {
    let (col, _, _, _) = setup();
    col.set_license(999, LICENSE_MIT());
}

// ---------------------------------------------------------------------------
// get_token_data
// ---------------------------------------------------------------------------

#[test]
fn test_get_token_data_all_fields_correct() {
    let (col, addr, user1, _) = setup();
    let ts: u64 = 1700000000;
    cheat_caller_address(addr, USER1(), CheatSpan::TargetCalls(1));
    cheat_block_timestamp(addr, ts, CheatSpan::TargetCalls(1));
    col.mint_item(user1, 5, IPFS_URI(), LICENSE_CC0());
    let data = col.get_token_data(1);
    assert(data.token_id == 1, 'token_id mismatch');
    assert(data.metadata_uri == IPFS_URI(), 'metadata_uri mismatch');
    assert(data.original_creator == USER1(), 'original_creator mismatch');
    assert(data.registered_at == ts, 'registered_at mismatch');
}

#[test]
#[should_panic(expected: ('Token does not exist',))]
fn test_get_token_data_nonexistent_panics() {
    let (col, _, _, _) = setup();
    col.get_token_data(999);
}

#[test]
#[should_panic(expected: ('Token does not exist',))]
fn test_get_token_creator_nonexistent_panics() {
    let (col, _, _, _) = setup();
    col.get_token_creator(999);
}

#[test]
#[should_panic(expected: ('Token does not exist',))]
fn test_get_token_registered_at_nonexistent_panics() {
    let (col, _, _, _) = setup();
    col.get_token_registered_at(999);
}

// ---------------------------------------------------------------------------
// ERC-1155 transfer
// ---------------------------------------------------------------------------

#[test]
fn test_transfer_updates_balances() {
    let (col, addr, user1, user2) = setup();
    col.mint_item(user1, 10, IPFS_URI(), "");
    let erc1155 = IERC1155Dispatcher { contract_address: addr };
    cheat_caller_address(addr, user1, CheatSpan::TargetCalls(1));
    erc1155.safe_transfer_from(user1, user2, 1, 3, array![].span());
    assert(erc1155.balance_of(user1, 1) == 7, 'user1 balance should be 7');
    assert(erc1155.balance_of(user2, 1) == 3, 'user2 balance should be 3');
}

#[test]
fn test_transfer_preserves_creator() {
    let (col, addr, user1, user2) = setup();
    cheat_caller_address(addr, USER1(), CheatSpan::TargetCalls(1));
    col.mint_item(user1, 10, IPFS_URI(), "");
    let erc1155 = IERC1155Dispatcher { contract_address: addr };
    cheat_caller_address(addr, user1, CheatSpan::TargetCalls(1));
    erc1155.safe_transfer_from(user1, user2, 1, 5, array![].span());
    assert(col.get_token_creator(1) == USER1(), 'creator preserved after xfer');
}

#[test]
fn test_transfer_preserves_uri() {
    let (col, addr, user1, user2) = setup();
    col.mint_item(user1, 10, IPFS_URI(), "");
    let erc1155 = IERC1155Dispatcher { contract_address: addr };
    cheat_caller_address(addr, user1, CheatSpan::TargetCalls(1));
    erc1155.safe_transfer_from(user1, user2, 1, 5, array![].span());
    let meta = IERC1155MetadataURIDispatcher { contract_address: addr };
    assert(meta.uri(1) == IPFS_URI(), 'uri preserved after transfer');
}

#[test]
fn test_batch_transfer() {
    let (col, addr, user1, user2) = setup();
    col.mint_item(user1, 10, IPFS_URI(), "");
    col.mint_item(user1, 20, AR_URI(), "");
    let erc1155 = IERC1155Dispatcher { contract_address: addr };
    cheat_caller_address(addr, user1, CheatSpan::TargetCalls(1));
    erc1155
        .safe_batch_transfer_from(
            user1, user2, array![1, 2].span(), array![3_u256, 7_u256].span(), array![].span(),
        );
    assert(erc1155.balance_of(user1, 1) == 7, 'user1 token1 balance');
    assert(erc1155.balance_of(user2, 1) == 3, 'user2 token1 balance');
    assert(erc1155.balance_of(user1, 2) == 13, 'user1 token2 balance');
    assert(erc1155.balance_of(user2, 2) == 7, 'user2 token2 balance');
}

// ---------------------------------------------------------------------------
// Approval
// ---------------------------------------------------------------------------

#[test]
fn test_set_approval_for_all() {
    let (_, addr, user1, user2) = setup();
    let erc1155 = IERC1155Dispatcher { contract_address: addr };
    cheat_caller_address(addr, user1, CheatSpan::TargetCalls(1));
    erc1155.set_approval_for_all(user2, true);
    assert(erc1155.is_approved_for_all(user1, user2), 'user2 should be approved');
}

#[test]
fn test_revoke_approval_for_all() {
    let (_, addr, user1, user2) = setup();
    let erc1155 = IERC1155Dispatcher { contract_address: addr };
    cheat_caller_address(addr, user1, CheatSpan::TargetCalls(1));
    erc1155.set_approval_for_all(user2, true);
    cheat_caller_address(addr, user1, CheatSpan::TargetCalls(1));
    erc1155.set_approval_for_all(user2, false);
    assert(!erc1155.is_approved_for_all(user1, user2), 'approval should be revoked');
}

// ---------------------------------------------------------------------------
// Interface support (SRC5 / ERC165)
// ---------------------------------------------------------------------------

#[test]
fn test_supports_interface_erc1155() {
    let (_, addr) = deploy_contract(CREATOR());
    let src5 = ISRC5Dispatcher { contract_address: addr };
    assert(src5.supports_interface(IERC1155_ID()), 'should support IERC1155');
}

// ---------------------------------------------------------------------------
// uri() for unminted tokens
// ---------------------------------------------------------------------------

#[test]
fn test_uri_unminted_token_returns_empty() {
    let (_, addr) = deploy_contract(CREATOR());
    let meta = IERC1155MetadataURIDispatcher { contract_address: addr };
    assert(meta.uri(999) == "", 'unminted uri should be empty');
}

// ---------------------------------------------------------------------------
// balance_of_batch
// ---------------------------------------------------------------------------

#[test]
fn test_balance_of_batch() {
    let (col, addr, user1, user2) = setup();
    col.mint_item(user1, 10, IPFS_URI(), "");
    col.mint_item(user2, 5, AR_URI(), "");
    let erc1155 = IERC1155Dispatcher { contract_address: addr };
    let balances = erc1155
        .balance_of_batch(array![user1, user2].span(), array![1_u256, 2_u256].span());
    assert(*balances.at(0) == 10, 'user1 token1 balance');
    assert(*balances.at(1) == 5, 'user2 token2 balance');
}

// ---------------------------------------------------------------------------
// types unit tests (via inline tests in types.cairo, re-tested here for coverage)
// ---------------------------------------------------------------------------

#[test]
fn test_mint_one_amount_works() {
    let (col, addr, user1, _) = setup();
    col.mint_item(user1, 1, IPFS_URI(), "");
    let erc1155 = IERC1155Dispatcher { contract_address: addr };
    assert(erc1155.balance_of(user1, 1) == 1, 'balance of 1 should work');
}
