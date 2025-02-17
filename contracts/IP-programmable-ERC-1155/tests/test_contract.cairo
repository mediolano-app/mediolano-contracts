mod ip_asset_contract;

use ip_asset_contract::lib::IPAssetContract;
use starknet::{ContractAddress, get_caller_address};
use array::ArrayTrait;

#[test]
fn test_mint() {
    // Deploy the contract
    let owner: ContractAddress = 0x12345;
    let contract = IPAssetContract::deploy(@owner);

    // Mint a new token
    let token_id: u256 = 1;
    let amount: u256 = 10;
    let license_terms: felt252 = 'Commercial Use Allowed';
    contract.mint(owner, token_id, amount, license_terms);

    // Check the balance
    let balance = contract.balance_of(owner, token_id);
    assert(balance == amount, 'Balance should be 10');

    // Check the license
    let license = contract.view_license(token_id);
    assert(license == license_terms, 'License terms should match');
}

#[test]
fn test_transfer() {
    // Deploy the contract
    let owner: ContractAddress = 0x12345;
    let recipient: ContractAddress = 0x67890;
    let contract = IPAssetContract::deploy(@owner);

    // Mint a new token
    let token_id: u256 = 1;
    let amount: u256 = 10;
    let license_terms: felt252 = 'Commercial Use Allowed';
    contract.mint(owner, token_id, amount, license_terms);

    // Transfer the token
    contract.safe_transfer_from(owner, recipient, token_id, amount, ArrayTrait::new());

    // Check the balances
    let owner_balance = contract.balance_of(owner, token_id);
    let recipient_balance = contract.balance_of(recipient, token_id);
    assert(owner_balance == 0, 'Owner balance should be 0');
    assert(recipient_balance == amount, 'Recipient balance should be 10');
}

#[test]
fn test_metadata() {
    // Deploy the contract
    let owner: ContractAddress = 0x12345;
    let contract = IPAssetContract::deploy(@owner);

    // Mint a new token
    let token_id: u256 = 1;
    let amount: u256 = 10;
    let license_terms: felt252 = 'Commercial Use Allowed';
    contract.mint(owner, token_id, amount, license_terms);

    // Check the metadata URI
    let uri = contract.uri(token_id);
    assert(uri == 'https://my-ipfs-base-uri/1', 'URI should match');
}

#[test]
fn test_licensing() {
    // Deploy the contract
    let owner: ContractAddress = 0x12345;
    let contract = IPAssetContract::deploy(@owner);

    // Mint a new token
    let token_id: u256 = 1;
    let amount: u256 = 10;
    let license_terms: felt252 = 'Commercial Use Allowed';
    contract.mint(owner, token_id, amount, license_terms);

    // Check the license
    let license = contract.view_license(token_id);
    assert(license == license_terms, 'License terms should match');
}

#[test]
fn test_batch_transfer() {
    // Deploy the contract
    let owner: ContractAddress = 0x12345;
    let recipient: ContractAddress = 0x67890;
    let contract = IPAssetContract::deploy(@owner);

    // Mint multiple tokens
    let token_ids: Array<u256> = array![1, 2, 3];
    let amounts: Array<u256> = array![10, 20, 30];
    let license_terms: felt252 = 'Commercial Use Allowed';
    for (token_id, amount) in token_ids.iter().zip(amounts.iter()) {
        contract.mint(owner, *token_id, *amount, license_terms);
    }

    // Transfer the tokens in a batch
    contract.safe_batch_transfer_from(owner, recipient, token_ids, amounts, ArrayTrait::new());

    // Check the balances
    for (token_id, amount) in token_ids.iter().zip(amounts.iter()) {
        let owner_balance = contract.balance_of(owner, *token_id);
        let recipient_balance = contract.balance_of(recipient, *token_id);
        assert(owner_balance == 0, 'Owner balance should be 0');
        assert(recipient_balance == *amount, 'Recipient balance should match');
    }
}
