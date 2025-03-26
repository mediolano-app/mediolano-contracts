use core::starknet::{contract_address_const, ContractAddress, get_caller_address};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, mock_call
};
use ip_collection::IPCollection::{IIPCollectionDispatcher, IIPCollectionDispatcherTrait};
use openzeppelin_token::erc721::interface::{
    IERC721Dispatcher, IERC721DispatcherTrait
};

// Helper function to deploy the contract
fn deploy_contract() -> (IIPCollectionDispatcher, ContractAddress) {
    let contract = declare("IPCollection").unwrap().contract_class();
    let owner = contract_address_const::<'owner'>();
    let (contract_address, _) = contract.deploy(@array![owner.into()]).unwrap();
    let dispatcher = IIPCollectionDispatcher { contract_address };
    (dispatcher, contract_address)
}

// Test creating a community
#[test]
fn test_create_community() {
    let (ipcollection, _) = deploy_contract();
    let caller = contract_address_const::<'creator'>();
    start_cheat_caller_address(ipcollection.contract_address, caller);

    let fee_token = contract_address_const::<'fee_token'>();
    let fee_recipient = contract_address_const::<'fee_recipient'>();
    let ip_nft_address = contract_address_const::<'ip_nft'>();
    let ip_nft_token_id = 1;

    let community_id = ipcollection.create_community(
        "Test Community",
        "A test community",
        100,
        fee_token,
        fee_recipient,
        ip_nft_address,
        ip_nft_token_id
    );

    assert_eq!(community_id, 1, "Community ID should be 1");

    stop_cheat_caller_address(ipcollection.contract_address);
}

// Test minting an NFT
#[test]
fn test_mint() {
    let (ipcollection, _) = deploy_contract();
    let creator = contract_address_const::<'creator'>();
    let minter = contract_address_const::<'minter'>();
    let fee_token = contract_address_const::<'fee_token'>();
    let fee_recipient = contract_address_const::<'fee_recipient'>();
    let ip_nft_address = contract_address_const::<'ip_nft'>();
    let ip_nft_token_id = 1;

    // Create community
    start_cheat_caller_address(ipcollection.contract_address, creator);
    let community_id = ipcollection.create_community(
        "Test Community",
        "A test community",
        100,
        fee_token,
        fee_recipient,
        ip_nft_address,
        ip_nft_token_id
    );
    stop_cheat_caller_address(ipcollection.contract_address);

    // Mock ERC20 transfer_from to simulate successful fee payment
    mock_call(fee_token, selector!("transfer_from"), array![true.into()]);

    // Mint token
    start_cheat_caller_address(ipcollection.contract_address, minter);
    let token_id = ipcollection.mint(community_id);
    stop_cheat_caller_address(ipcollection.contract_address);

    let erc721 = IERC721Dispatcher { contract_address: ipcollection.contract_address };
    assert_eq!(erc721.balance_of(minter), 1, "Minter should have 1 NFT");

    let tokens = ipcollection.list_user_tokens(minter);
    assert_eq!(tokens.len(), 1, "Minter should have 1 token");
    assert_eq!(*tokens.at(0), token_id, "Token ID should match");
}

// Test checking membership
#[test]
fn test_is_member() {
    let (ipcollection, _) = deploy_contract();
    let creator = contract_address_const::<'creator'>();
    let minter = contract_address_const::<'minter'>();
    let fee_token = contract_address_const::<'fee_token'>();
    let fee_recipient = contract_address_const::<'fee_recipient'>();
    let ip_nft_address = contract_address_const::<'ip_nft'>();
    let ip_nft_token_id = 1;

    // Create community
    start_cheat_caller_address(ipcollection.contract_address, creator);
    let community_id = ipcollection.create_community(
        "Test Community",
        "A test community",
        100,
        fee_token,
        fee_recipient,
        ip_nft_address,
        ip_nft_token_id
    );
    stop_cheat_caller_address(ipcollection.contract_address);

    // Mock ERC20 transfer_from
    mock_call(fee_token, selector!("transfer_from"), array![true.into()]);

    // Mint token
    start_cheat_caller_address(ipcollection.contract_address, minter);
    ipcollection.mint(community_id);
    stop_cheat_caller_address(ipcollection.contract_address);

    // Check membership
    let is_member = ipcollection.is_member(minter, community_id);
    assert_eq!(is_member, true, "Minter should be a member");

    let non_member = contract_address_const::<'non_member'>();
    let is_member = ipcollection.is_member(non_member, community_id);
    assert_eq!(is_member, false, "Non-minter should not be a member");
}

// Test burning an NFT
#[test]
fn test_burn() {
    let (ipcollection, _) = deploy_contract();
    let owner = contract_address_const::<'owner'>();
    let creator = contract_address_const::<'creator'>();
    let minter = contract_address_const::<'minter'>();
    let fee_token = contract_address_const::<'fee_token'>();
    let fee_recipient = contract_address_const::<'fee_recipient'>();
    let ip_nft_address = contract_address_const::<'ip_nft'>();
    let ip_nft_token_id = 1;

    // Create community
    start_cheat_caller_address(ipcollection.contract_address, creator);
    let community_id = ipcollection.create_community(
        "Test Community",
        "A test community",
        100,
        fee_token,
        fee_recipient,
        ip_nft_address,
        ip_nft_token_id
    );
    stop_cheat_caller_address(ipcollection.contract_address);

    // Mock ERC20 transfer_from
    mock_call(fee_token, selector!("transfer_from"), array![true.into()]);

    // Mint token
    start_cheat_caller_address(ipcollection.contract_address, minter);
    let token_id = ipcollection.mint(community_id);
    stop_cheat_caller_address(ipcollection.contract_address);

    let erc721 = IERC721Dispatcher { contract_address: ipcollection.contract_address };
    assert_eq!(erc721.balance_of(minter), 1, "Minter should have 1 NFT before burn");

    // Burn token as contract owner
    start_cheat_caller_address(ipcollection.contract_address, owner);
    ipcollection.burn(token_id);
    stop_cheat_caller_address(ipcollection.contract_address);

    assert_eq!(erc721.balance_of(minter), 0, "Minter should have 0 NFTs after burn");

    let tokens = ipcollection.list_user_tokens(minter);
    assert_eq!(tokens.len(), 0, "Minter should have no tokens after burn");
}