#![cfg(test)]

use super::*;
use starknet::testing::{deploy_contract, CallContext};

#[test]
fn test_create_and_list_item() {
    let mut context = CallContext::default();
    let marketplace = deploy_contract!(IPRevenueSharingMarketplace, context, 300);
    let nft_contract = deploy_contract!(IERC721Dispatcher, context);
    
    let seller = context.new_account();
    let token_id = 1;
    let price = 1000;
    let currency = deploy_contract!(IERC20Dispatcher, context);
    let total_shares = 100;
    
    nft_contract.mock_owner_of(token_id, seller);
    nft_contract.mock_approval_for_marketplace(token_id, marketplace);
    
    context.call(
        &marketplace,
        seller,
        "create_and_list_item",
        (nft_contract, token_id, price, currency, 1234, 5678, total_shares),
    );
    
    let listing = marketplace.listings((nft_contract, token_id));
    assert_eq!(listing.seller, seller);
    assert_eq!(listing.price, price);
    assert_eq!(listing.fractional.total_shares, total_shares);
}

#[test]
fn test_buy_item() {
    let mut context = CallContext::default();
    let marketplace = deploy_contract!(IPRevenueSharingMarketplace, context, 300);
    let nft_contract = deploy_contract!(IERC721Dispatcher, context);
    let currency = deploy_contract!(IERC20Dispatcher, context);
    
    let seller = context.new_account();
    let buyer = context.new_account();
    let token_id = 1;
    let price = 1000;
    let total_shares = 100;
    
    nft_contract.mock_owner_of(token_id, seller);
    nft_contract.mock_approval_for_marketplace(token_id, marketplace);
    currency.mock_balance(buyer, 2000);
    
    context.call(
        &marketplace,
        seller,
        "create_and_list_item",
        (nft_contract, token_id, price, currency, 1234, 5678, total_shares),
    );
    
    context.call(&marketplace, buyer, "buy_item", (nft_contract, token_id));
    
    let listing = marketplace.listings((nft_contract, token_id));
    assert!(!listing.active, "Item should no longer be active");
    assert_eq!(nft_contract.owner_of(token_id), buyer);
    assert_eq!(currency.balance(seller), price - (price * 300 / 10000)); // Fee deducted
}

#[test]
fn test_claim_royalty() {
    let mut context = CallContext::default();
    let marketplace = deploy_contract!(IPRevenueSharingMarketplace, context, 300);
    let nft_contract = deploy_contract!(IERC721Dispatcher, context);
    let currency = deploy_contract!(IERC20Dispatcher, context);
    
    let seller = context.new_account();
    let buyer = context.new_account();
    let fractional_owner = context.new_account();
    let token_id = 1;
    let price = 1000;
    let total_shares = 100;
    
    nft_contract.mock_owner_of(token_id, seller);
    nft_contract.mock_approval_for_marketplace(token_id, marketplace);
    currency.mock_balance(buyer, 2000);
    
    context.call(
        &marketplace,
        seller,
        "create_and_list_item",
        (nft_contract, token_id, price, currency, 1234, 5678, total_shares),
    );
    
    context.call(&marketplace, buyer, "buy_item", (nft_contract, token_id));
    
    marketplace.fractional_shares.write((token_id, fractional_owner), 50); // Owns 50%
    context.call(&marketplace, fractional_owner, "claim_royalty", (token_id,));
    
    let claimed = marketplace.pending_revenue((token_id, fractional_owner));
    assert_eq!(claimed, (price - (price * 300 / 10000)) / 2);
}
