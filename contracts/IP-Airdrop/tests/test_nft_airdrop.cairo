use starknet::ContractAddress;
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_testing::deployment::declare_and_deploy;
use openzeppelin_testing::constants::{OWNER, ALICE, BOB, CHARLIE, NAME, SYMBOL, BASE_URI};
use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use snforge_std::{cheat_caller_address, CheatSpan, start_cheat_caller_address};
use ip_nft_airdrop::interface::{INFTAirdropDispatcher, INFTAirdropDispatcherTrait};

const MERKLE_ROOT: felt252 = 0x0558d724716107821c95b3336677e9c073d254a0944f3f13ae611092c25486f4;
const ALICE_PROOF: [felt252; 2] = [
    0x02ddc48ae4d274cb9aa9eca47b2d499948698e8eac9715569847ca352fcba6,
    0x039f24bca59c78288edcbc64f7b173e144a28c37e7ba8903865ddbd47b81acc4,
];
const ALICE_AMOUNT: u32 = 1;
const ALICE_TOKEN_IDS: [u256; ALICE_AMOUNT] = [1];
const BOB_PROOF: [felt252; 2] = [
    0x0190e85d8de359eb2869b3d4ce6b94fab9b254ada3c50eadf0e41250c27b3988,
    0x039f24bca59c78288edcbc64f7b173e144a28c37e7ba8903865ddbd47b81acc4,
];
const BOB_AMOUNT: u32 = 2;
const BOB_TOKEN_IDS: [u256; BOB_AMOUNT] = [2, 3];
const CHARLIE_PROOF: [felt252; 1] = [
    0x055a9fa4bd67075bf77cf0ee4441530e8363eb4e7f53abfc4aa1210255a574ea
];
const CHARLIE_AMOUNT: u32 = 3;
const CHARLIE_TOKEN_IDS: [u256; CHARLIE_AMOUNT] = [4, 5, 6];

fn setup() -> (ContractAddress, INFTAirdropDispatcher, IERC721Dispatcher) {
    let mut calldata = array![];
    calldata.append_serde(OWNER());
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(MERKLE_ROOT);
    let nft_airdrop_address = declare_and_deploy("NFTAirdrop", calldata);

    let nft_airdrop = INFTAirdropDispatcher { contract_address: nft_airdrop_address };
    let erc721 = IERC721Dispatcher { contract_address: nft_airdrop_address };

    (nft_airdrop_address, nft_airdrop, erc721)
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_whitelist_not_owner() {
    let (_, nft_airdrop, _) = setup();

    nft_airdrop.whitelist(ALICE(), ALICE_AMOUNT);
}

#[test]
fn test_whitelist() {
    let (nft_airdrop_address, nft_airdrop, _) = setup();

    start_cheat_caller_address(nft_airdrop_address, OWNER());

    nft_airdrop.whitelist(ALICE(), ALICE_AMOUNT);
    assert_eq!(nft_airdrop.whitelist_balance_of(ALICE()), ALICE_AMOUNT);
    nft_airdrop.whitelist(BOB(), BOB_AMOUNT);
    assert_eq!(nft_airdrop.whitelist_balance_of(BOB()), BOB_AMOUNT);
    nft_airdrop.whitelist(CHARLIE(), CHARLIE_AMOUNT);
    assert_eq!(nft_airdrop.whitelist_balance_of(CHARLIE()), CHARLIE_AMOUNT);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_airdrop_not_owner() {
    let (_, nft_airdrop, _) = setup();

    nft_airdrop.airdrop();
}

#[test]
fn test_airdrop() {
    let (nft_airdrop_address, nft_airdrop, erc721) = setup();

    start_cheat_caller_address(nft_airdrop_address, OWNER());

    nft_airdrop.whitelist(ALICE(), ALICE_AMOUNT);
    assert_eq!(nft_airdrop.whitelist_balance_of(ALICE()), ALICE_AMOUNT);
    nft_airdrop.whitelist(BOB(), BOB_AMOUNT);
    assert_eq!(nft_airdrop.whitelist_balance_of(BOB()), BOB_AMOUNT);
    nft_airdrop.whitelist(CHARLIE(), CHARLIE_AMOUNT);
    assert_eq!(nft_airdrop.whitelist_balance_of(CHARLIE()), CHARLIE_AMOUNT);

    nft_airdrop.airdrop();
    assert_owner_of_tokens(erc721, ALICE(), ALICE_TOKEN_IDS.span());
    assert_owner_of_tokens(erc721, BOB(), BOB_TOKEN_IDS.span());
    assert_owner_of_tokens(erc721, CHARLIE(), CHARLIE_TOKEN_IDS.span());

    assert_eq!(nft_airdrop.whitelist_balance_of(ALICE()), 0);
    assert_eq!(nft_airdrop.whitelist_balance_of(BOB()), 0);
    assert_eq!(nft_airdrop.whitelist_balance_of(CHARLIE()), 0);
}

#[test]
#[should_panic(expected: 'INVALID_PROOF')]
fn test_claim_with_proof_invalid_caller() {
    let (nft_airdrop_address, nft_airdrop, _) = setup();

    cheat_caller_address(nft_airdrop_address, OWNER(), CheatSpan::TargetCalls(1));

    nft_airdrop.claim_with_proof(ALICE_PROOF.span(), ALICE_AMOUNT);
}

#[test]
#[should_panic(expected: 'INVALID_PROOF')]
fn test_claim_with_proof_invalid_proof() {
    let (nft_airdrop_address, nft_airdrop, _) = setup();

    cheat_caller_address(nft_airdrop_address, ALICE(), CheatSpan::TargetCalls(1));

    nft_airdrop.claim_with_proof(array![].span(), ALICE_AMOUNT);
}

#[test]
#[should_panic(expected: 'INVALID_PROOF')]
fn test_claim_with_proof_invalid_amount() {
    let (nft_airdrop_address, nft_airdrop, _) = setup();

    cheat_caller_address(nft_airdrop_address, ALICE(), CheatSpan::TargetCalls(1));

    nft_airdrop.claim_with_proof(ALICE_PROOF.span(), 0);
}

fn assert_owner_of_tokens(
    erc721: IERC721Dispatcher, owner: ContractAddress, token_ids: Span<u256>,
) {
    for token_id in token_ids {
        assert_eq!(erc721.owner_of(*token_id), owner);
    };
}

#[test]
fn test_claim_with_proof() {
    let (nft_airdrop_address, nft_airdrop, erc721) = setup();

    cheat_caller_address(nft_airdrop_address, ALICE(), CheatSpan::TargetCalls(1));
    nft_airdrop.claim_with_proof(ALICE_PROOF.span(), ALICE_AMOUNT);
    assert_owner_of_tokens(erc721, ALICE(), ALICE_TOKEN_IDS.span());

    cheat_caller_address(nft_airdrop_address, BOB(), CheatSpan::TargetCalls(1));
    nft_airdrop.claim_with_proof(BOB_PROOF.span(), BOB_AMOUNT);
    assert_owner_of_tokens(erc721, BOB(), BOB_TOKEN_IDS.span());

    cheat_caller_address(nft_airdrop_address, CHARLIE(), CheatSpan::TargetCalls(1));
    nft_airdrop.claim_with_proof(CHARLIE_PROOF.span(), CHARLIE_AMOUNT);
    assert_owner_of_tokens(erc721, CHARLIE(), CHARLIE_TOKEN_IDS.span());
}
