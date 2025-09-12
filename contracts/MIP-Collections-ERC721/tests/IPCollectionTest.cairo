use core::result::ResultTrait;
use ip_collection_erc_721::interfaces::IIPCollection::{
    IIPCollectionDispatcher, IIPCollectionDispatcherTrait,
};
use ip_collection_erc_721::interfaces::IIPNFT::{IIPNftDispatcher, IIPNftDispatcherTrait};
use openzeppelin::token::erc721::interface::{
    ERC721ABIDispatcher, ERC721ABIDispatcherTrait, IERC721Dispatcher, IERC721DispatcherTrait,
};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;

// Test constants
fn OWNER() -> ContractAddress {
    0x123.try_into().unwrap()
}
fn USER1() -> ContractAddress {
    0x456.try_into().unwrap()
}
fn USER2() -> ContractAddress {
    0x789.try_into().unwrap()
}
fn USER3() -> ContractAddress {
    0x987.try_into().unwrap()
}
fn ZERO() -> ContractAddress {
    0.try_into().unwrap()
}


const COLLECTION_ID: u256 = 1;
const TOKEN_ID: u256 = 1;

// // Deploy the IPCollection contract
fn deploy_contract() -> (IIPCollectionDispatcher, ContractAddress) {
    let owner = OWNER();
    let ip_nft_class_hash = declare("IPNft").unwrap().contract_class();
    let mut calldata = array![];

    owner.serialize(ref calldata);
    ip_nft_class_hash.serialize(ref calldata);

    let declare_result = declare("IPCollection").expect('Failed to declare contract');
    let contract_class = declare_result.contract_class();
    let (contract_address, _) = contract_class
        .deploy(@calldata)
        .expect('Failed to deploy contract');

    let dispatcher = IIPCollectionDispatcher { contract_address };
    (dispatcher, contract_address)
}


// Helper function to create a test collection
fn setup_collection(dispatcher: IIPCollectionDispatcher, ip_address: ContractAddress) -> u256 {
    let owner = OWNER();
    let name: ByteArray = "Test Collection";
    let symbol: ByteArray = "TST";
    let base_uri: ByteArray = "QmCollectionBaseUri/";
    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));
    let collection_id = dispatcher.create_collection(name, symbol, base_uri);
    collection_id
}

#[test]
fn test_create_collection() {
    let (ip_dispatcher, ip_address) = deploy_contract();
    let owner = OWNER();
    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));

    let name: ByteArray = "My Collection";
    let symbol: ByteArray = "MC";
    let base_uri: ByteArray = "QmMyCollection";
    let collection_id = ip_dispatcher
        .create_collection(name.clone(), symbol.clone(), base_uri.clone());

    assert(collection_id == 1, 'Collection ID should be 1');
    let collection = ip_dispatcher.get_collection(collection_id);
    assert(collection.name == name, 'Collection name mismatch');
    assert(collection.symbol == symbol, 'Collection symbol mismatch');
    assert(collection.base_uri == base_uri, 'Collection base_uri mismatch');
    assert(collection.owner == owner, 'Collection owner mismatch');
    assert(collection.is_active, 'Collection should be active');
}

#[test]
fn test_create_multiple_collections() {
    let (dispatcher, ip_address) = deploy_contract();
    let owner = OWNER();
    start_cheat_caller_address(ip_address, owner);

    let name1: ByteArray = "Collection 1";
    let symbol1: ByteArray = "C1";
    let base_uri1: ByteArray = "QmCollection1";
    let collection_id1 = dispatcher.create_collection(name1, symbol1, base_uri1);
    assert(collection_id1 == 1, 'First collection ID should be 1');

    let name2: ByteArray = "Collection 2";
    let symbol2: ByteArray = "C2";
    let base_uri2: ByteArray = "QmCollection2";
    let collection_id2 = dispatcher.create_collection(name2, symbol2, base_uri2);
    assert(collection_id2 == 2, 'Second ID should be 2');

    stop_cheat_caller_address(ip_address);
}

#[test]
fn test_mint_token() {
    let (dispatcher, ip_address) = deploy_contract();
    let owner = OWNER();
    let recipient = USER1();
    let collection_id = setup_collection(dispatcher, ip_address);
    let token_uri: ByteArray = "QmCollectionBaseUri";

    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));
    let token_id = dispatcher.mint(collection_id, recipient, token_uri.clone());
    assert(token_id == 0, 'Token ID should be 0');

    let token_id_arr = format!("{}:{}", collection_id, token_id);

    let token = dispatcher.get_token(token_id_arr);
    assert(token.collection_id == collection_id, 'Token collection ID mismatch');
    assert(token.token_id == token_id, 'Token ID mismatch');
    assert(token.owner == recipient, 'Token owner mismatch');
    assert(token.metadata_uri == token_uri, 'Token metadata URI mismatch');
}

#[test]
fn test_token_uri_match() {
    let (dispatcher, ip_address) = deploy_contract();
    let owner = OWNER();
    let recipient = USER1();
    let collection_id = setup_collection(dispatcher, ip_address);
    let token_uri: ByteArray = "QmCollectionBaseUri";

    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));
    let token_id = dispatcher.mint(collection_id, recipient, token_uri.clone());
    assert(token_id == 0, 'Token ID should be 0');

    let collection_data = dispatcher.get_collection(collection_id);

    let erc721_dispatcher = ERC721ABIDispatcher { contract_address: collection_data.ip_nft };

    let token_uri_1 = erc721_dispatcher.tokenURI(token_id);
    let token_uri_2 = erc721_dispatcher.token_uri(token_id);
    assert(token_uri_1 == token_uri, 'Token URI 1 mismatch');
    assert(token_uri_2 == token_uri, 'Token URI 2 mismatch');
    assert_eq!(token_uri_1, token_uri_2, "Token URI mismatch");
}

#[test]
#[should_panic(expected: ('Only collection owner can mint',))]
fn test_mint_not_owner() {
    let (dispatcher, address) = deploy_contract();
    let non_owner = USER1();
    let recipient = USER2();
    let collection_id = setup_collection(dispatcher, address);
    let token_uri: ByteArray = "QmCollectionBaseUri";

    start_cheat_caller_address(address, non_owner);
    dispatcher.mint(collection_id, recipient, token_uri);
}

#[test]
#[should_panic(expected: ('Recipient is zero address',))]
fn test_mint_to_zero_address() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let collection_id = setup_collection(dispatcher, address);
    let token_uri: ByteArray = "QmCollectionBaseUri";
    start_cheat_caller_address(address, owner);
    dispatcher.mint(collection_id, ZERO(), token_uri);
}

#[test]
#[should_panic(expected: ('Only collection owner can mint',))]
fn test_mint_zero_caller() {
    let (dispatcher, address) = deploy_contract();
    let recipient = USER1();
    let collection_id = setup_collection(dispatcher, address);
    let token_uri: ByteArray = "QmCollectionBaseUri";

    start_cheat_caller_address(address, ZERO());
    dispatcher.mint(collection_id, recipient, token_uri);
}

#[test]
fn test_batch_mint_tokens() {
    let (dispatcher, ip_address) = deploy_contract();
    let owner = OWNER();
    let recipient1 = USER1();
    let recipient2 = USER2();
    let collection_id = setup_collection(dispatcher, ip_address);
    let token_uris = array!["QmCollectionBaseUri1", "QmCollectionBaseUri2"];

    let recipients = array![recipient1, recipient2];

    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));
    let token_ids = dispatcher.batch_mint(collection_id, recipients.clone(), token_uris.clone());

    assert(token_ids.len() == 2, 'Should mint 2 tokens in batch');
    let token0 = dispatcher.get_token(format!("{}:{}", collection_id, *token_ids.at(0)));
    let token1 = dispatcher.get_token(format!("{}:{}", collection_id, *token_ids.at(1)));
    assert(token0.owner == recipient1, 'First token owner mismatch');
    assert(token1.owner == recipient2, 'Second token owner mismatch');
    assert(token0.token_id == 0, 'First token ID should be 0');
    assert(token1.token_id == 1, 'Second token ID should be 1');
    assert(token0.metadata_uri == token_uris.at(0).clone(), 'First token URI mismatch');
    assert(token1.metadata_uri == token_uris.at(1).clone(), 'Second token URI mismatch');
}

#[test]
#[should_panic(expected: ('Recipients array is empty',))]
fn test_batch_mint_empty_recipients() {
    let (dispatcher, ip_address) = deploy_contract();
    let owner = OWNER();
    let collection_id = setup_collection(dispatcher, ip_address);

    let recipients = array![];
    let token_uris = array![];

    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));
    dispatcher.batch_mint(collection_id, recipients, token_uris);
}

#[test]
#[should_panic(expected: ('Recipient is zero address',))]
fn test_batch_mint_zero_recipient() {
    let (dispatcher, ip_address) = deploy_contract();
    let owner = OWNER();
    let collection_id = setup_collection(dispatcher, ip_address);
    let token_uris = array!["QmCollectionBaseUri"];
    let recipients = array![ZERO()];
    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));
    dispatcher.batch_mint(collection_id, recipients, token_uris);
}

#[test]
fn test_burn_token() {
    let (dispatcher, ip_address) = deploy_contract();
    let owner = OWNER();
    let recipient = USER1();
    let collection_id = setup_collection(dispatcher, ip_address);
    let token_uri: ByteArray = "QmCollectionBaseUri";

    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));
    let token_id = dispatcher.mint(collection_id, recipient, token_uri);

    let token = format!("{}:{}", collection_id, token_id);
    cheat_caller_address(ip_address, recipient, CheatSpan::TargetCalls(1));
    dispatcher.burn(token);
}

#[test]
#[should_panic(expected: ('Caller not token owner',))]
fn test_burn_not_owner() {
    let (dispatcher, ip_address) = deploy_contract();
    let owner = OWNER();
    let recipient = USER1();
    let non_owner = USER2();
    let collection_id = setup_collection(dispatcher, ip_address);
    let token_uri: ByteArray = "QmCollectionBaseUri";

    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));
    let token_id = dispatcher.mint(collection_id, recipient, token_uri);

    let token = format!("{}:{}", collection_id, token_id);
    cheat_caller_address(ip_address, non_owner, CheatSpan::TargetCalls(1));
    dispatcher.burn(token);
}

#[test]
fn test_transfer_token_success() {
    let (dispatcher, ip_address) = deploy_contract();
    let owner = OWNER();
    let from_user = USER1();
    let to_user = USER2();
    let collection_id = setup_collection(dispatcher, ip_address);
    let token_uri: ByteArray = "QmCollectionBaseUri";

    // Mint token to from_user
    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));
    let token_id = dispatcher.mint(collection_id, from_user, token_uri);

    let collection_data = dispatcher.get_collection(collection_id);

    let erc721_dispatcher = IERC721Dispatcher { contract_address: collection_data.ip_nft };

    cheat_caller_address(collection_data.ip_nft, from_user, CheatSpan::TargetCalls(1));
    erc721_dispatcher.approve(ip_address, token_id);

    cheat_caller_address(ip_address, from_user, CheatSpan::TargetCalls(1));
    let token = format!("{}:{}", collection_id, token_id);
    dispatcher.transfer_token(from_user, to_user, token);
}

#[test]
#[should_panic(expected: ('Contract not approved',))]
fn test_transfer_token_not_approved() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let from_user = USER1();
    let to_user = USER2();
    let collection_id = setup_collection(dispatcher, address);
    let token_uri: ByteArray = "QmCollectionBaseUri";

    start_cheat_caller_address(address, owner);
    let token_id = dispatcher.mint(collection_id, from_user, token_uri);
    stop_cheat_caller_address(address);

    start_cheat_caller_address(address, from_user);
    let token = format!("{}:{}", collection_id, token_id);
    dispatcher.transfer_token(from_user, to_user, token);
}
#[test]
#[should_panic(expected: ('Collection is not active',))]
fn test_transfer_token_inactive_collection() {
    let (dispatcher, ip_address) = deploy_contract();
    let owner = OWNER();
    let from_user = USER1();
    let to_user = USER2();
    let collection_id = setup_collection(dispatcher, ip_address);
    let token_uri: ByteArray = "QmCollectionBaseUri";

    // Mint token to from_user
    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));
    let token_id = dispatcher.mint(collection_id, from_user, token_uri);

    cheat_caller_address(ip_address, from_user, CheatSpan::TargetCalls(1));
    let token = format!("{}:{}", collection_id + 1, token_id);

    dispatcher.transfer_token(from_user, to_user, token);
}

#[test]
fn test_list_user_collections_empty() {
    let (dispatcher, _) = deploy_contract();
    let random_user = USER2();
    let collections = dispatcher.list_user_collections(random_user);
    assert(collections.len() == 0, 'Should have no collections');
}

#[test]
fn test_batch_transfer_tokens_success() {
    let (dispatcher, ip_address) = deploy_contract();
    let owner = OWNER();
    let from_user = USER1();
    let to_user = USER2();
    let collection_id = setup_collection(dispatcher, ip_address);

    // Mint two tokens to from_user
    let recipients = array![from_user, from_user];
    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));
    let token_uris = array!["QmCollectionBaseUri", "QmCollectionBaseUri"];
    let token_ids = dispatcher.batch_mint(collection_id, recipients.clone(), token_uris);

    let collection_data = dispatcher.get_collection(collection_id);
    let erc721_dispatcher = IERC721Dispatcher { contract_address: collection_data.ip_nft };

    // Approve contract for both tokens
    cheat_caller_address(collection_data.ip_nft, from_user, CheatSpan::TargetCalls(2));
    erc721_dispatcher.approve(ip_address, *token_ids.at(0));
    erc721_dispatcher.approve(ip_address, *token_ids.at(1));

    // Prepare tokens as ByteArray
    let token0 = format!("{}:{}", collection_id, *token_ids.at(0));
    let token1 = format!("{}:{}", collection_id, *token_ids.at(1));
    let tokens = array![token0, token1];
    cheat_caller_address(ip_address, from_user, CheatSpan::TargetCalls(1));
    dispatcher.batch_transfer(from_user, to_user, tokens.clone());

    // Check new owners
    let token_data0 = dispatcher.get_token(tokens.clone().at(0).clone());
    let token_data1 = dispatcher.get_token(tokens.clone().at(1_u32).clone());
    assert(token_data0.owner == to_user, 'Token0 should be transferred');
    assert(token_data1.owner == to_user, 'Token1 should be transferred');
}

#[test]
#[should_panic(expected: ('Collection is not active',))]
fn test_batch_transfer_inactive_collection() {
    let (dispatcher, ip_address) = deploy_contract();
    let owner = OWNER();
    let from_user = USER1();
    let to_user = USER2();
    let collection_id = setup_collection(dispatcher, ip_address);
    let token_uris = array!["QmCollectionBaseUri"];
    // Mint token to from_user
    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));
    let token_ids = dispatcher.batch_mint(collection_id, array![from_user], token_uris);

    // Use wrong collection_id (inactive)
    let token = format!("{}:{}", collection_id + 1, *token_ids.at(0));
    let tokens = array![token];

    cheat_caller_address(ip_address, from_user, CheatSpan::TargetCalls(1));
    dispatcher.batch_transfer(from_user, to_user, tokens);
}

#[test]
fn test_verification_functions() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let collection_id = setup_collection(dispatcher, address);
    let token_uri = "QmCollectionBaseUri";

    start_cheat_caller_address(address, owner);
    let token_id = dispatcher.mint(collection_id, USER1(), token_uri);
    let token = format!("{}:{}", collection_id, token_id);
    assert(dispatcher.is_valid_collection(collection_id), 'Collection should be valid');
    assert(dispatcher.is_valid_token(token), 'Token should be valid');
    assert(dispatcher.is_collection_owner(collection_id, owner), 'Owner should be correct');
    stop_cheat_caller_address(address);
}

#[test]
fn test_user_collections_mapping() {
    let (ip_dispatcher, ip_address) = deploy_contract();

    cheat_caller_address(ip_address, USER1(), CheatSpan::TargetCalls(1));
    let name1: ByteArray = "Collection 1";
    let symbol1: ByteArray = "C1";
    let base_uri1: ByteArray = "QmCollection1";
    let collection_id1 = ip_dispatcher.create_collection(name1, symbol1, base_uri1);
    assert(collection_id1 == 1, 'First collection ID should be 1');

    cheat_caller_address(ip_address, USER2(), CheatSpan::TargetCalls(1));
    let name2: ByteArray = "Collection 2";
    let symbol2: ByteArray = "C2";
    let base_uri2: ByteArray = "QmCollection2";
    let collection_id2 = ip_dispatcher.create_collection(name2, symbol2, base_uri2);
    assert(collection_id2 == 2, 'Second ID should be 2');

    cheat_caller_address(ip_address, USER2(), CheatSpan::TargetCalls(1));
    let name3: ByteArray = "Collection 3";
    let symbol3: ByteArray = "C3";
    let base_uri3: ByteArray = "QmCollection3";
    let collection_id3 = ip_dispatcher.create_collection(name3, symbol3, base_uri3);
    assert(collection_id3 == 3, 'Third ID should be 3');

    cheat_caller_address(ip_address, USER3(), CheatSpan::TargetCalls(1));
    let name4: ByteArray = "Collection 4";
    let symbol4: ByteArray = "C4";
    let base_uri4: ByteArray = "QmCollection4";
    let collection_id4 = ip_dispatcher.create_collection(name4, symbol4, base_uri4);
    assert(collection_id4 == 4, 'Fourth ID should be 4');

    cheat_caller_address(ip_address, USER1(), CheatSpan::TargetCalls(1));
    let name5: ByteArray = "Collection 5";
    let symbol5: ByteArray = "C5";
    let base_uri5: ByteArray = "QmCollection5";
    let collection_id5 = ip_dispatcher.create_collection(name5, symbol5, base_uri5);
    assert(collection_id5 == 5, 'Fifth ID should be 5');

    cheat_caller_address(ip_address, USER1(), CheatSpan::TargetCalls(1));
    let name6: ByteArray = "Collection 6";
    let symbol6: ByteArray = "C6";
    let base_uri6: ByteArray = "QmCollection6";
    let collection_id6 = ip_dispatcher.create_collection(name6, symbol6, base_uri6);
    assert(collection_id6 == 6, 'Sixth ID should be 6');

    cheat_caller_address(ip_address, USER3(), CheatSpan::TargetCalls(1));
    let name7: ByteArray = "Collection 7";
    let symbol7: ByteArray = "C7";
    let base_uri7: ByteArray = "QmCollection7";
    let collection_id7 = ip_dispatcher.create_collection(name7, symbol7, base_uri7);
    assert(collection_id7 == 7, 'Seventh ID should be 7');

    let user1_collections = ip_dispatcher.list_user_collections(USER1());
    assert(
        user1_collections == array![collection_id1, collection_id5, collection_id6].span(),
        'mismatch user1',
    );

    let user2_collections = ip_dispatcher.list_user_collections(USER2());
    assert(user2_collections == array![collection_id2, collection_id3].span(), 'mismatch user2');

    let user3_collections = ip_dispatcher.list_user_collections(USER3());
    assert(user3_collections == array![collection_id4, collection_id7].span(), 'mismatch user3');
}


#[test]
fn test_base_uri() {
    let (ip_dispatcher, ip_address) = deploy_contract();
    let owner = OWNER();
    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));

    let name: ByteArray = "My Collection";
    let symbol: ByteArray = "MC";
    let base_uri: ByteArray = "QmMyCollection";
    let collection_id = ip_dispatcher
        .create_collection(name.clone(), symbol.clone(), base_uri.clone());

    let collection = ip_dispatcher.get_collection(collection_id);

    let collection_base_uri = IIPNftDispatcher { contract_address: collection.ip_nft }.base_uri();
    println!("{}", collection_base_uri);

    assert(collection_base_uri == base_uri, 'base uri mismatch');
}


#[test]
fn test_get_all_user_tokens() {
    let (dispatcher, ip_address) = deploy_contract();
    let owner = OWNER();
    let recipient1 = USER1();
    let recipient2 = USER2();
    let collection_id = setup_collection(dispatcher, ip_address);
    let token_uris = array!["QmCollectionBaseUri1", "QmCollectionBaseUri2"];

    let recipients = array![recipient1, recipient2];

    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));
    let token_ids = dispatcher.batch_mint(collection_id, recipients.clone(), token_uris.clone());

    assert(token_ids.len() == 2, 'Should mint 2 tokens in batch');
    let recipient_token = dispatcher.list_user_tokens_per_collection(collection_id, recipient1);
    assert(recipient_token.len() == 1, 'Recipient1 should have 1 token');
    assert(*recipient_token.at(0) == *token_ids.at(0), 'TokenID mismatch for recipient1');

    // mint another token to  recipient1 in same collection
    let token_uri3 = "QmTokenBaseUri1";
    cheat_caller_address(ip_address, owner, CheatSpan::TargetCalls(1));
    let token_id3 = dispatcher.mint(collection_id, recipient1, token_uri3);
    assert(token_id3 == 2, 'Token ID should be 2');
    let recipients_token = dispatcher.list_user_tokens_per_collection(collection_id, recipient1);
    assert(recipients_token.len() == 2, 'Recipient1 should have 2 tokens');
    assert(*recipients_token.at(0) == *token_ids.at(0), 'TokenID mismatch for recipient1');
    assert(*recipients_token.at(1) == token_id3, 'TokenID mismatch for recipient1');

    // check that recipient2 has only 1 token
    let recipient2_token = dispatcher.list_user_tokens_per_collection(collection_id, recipient2);
    assert(recipient2_token.len() == 1, 'Recipient2 should have 1 token');
    assert(*recipient2_token.at(0) == *token_ids.at(1), 'TokenID mismatch for recipient2');
}
