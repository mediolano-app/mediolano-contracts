use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use core::result::ResultTrait;
use ip_collection_erc_721::IPCollection::{IIPCollectionDispatcher, IIPCollectionDispatcherTrait};

// Test constants
fn OWNER() -> ContractAddress {
    contract_address_const::<0x123>()
}
fn USER1() -> ContractAddress {
    contract_address_const::<0x456>()
}
fn USER2() -> ContractAddress {
    contract_address_const::<0x789>()
}
const COLLECTION_ID: u256 = 1;
const TOKEN_ID: u256 = 1;

// Deploy the IPCollection contract
fn deploy_contract() -> (IIPCollectionDispatcher, ContractAddress) {
    let owner = OWNER();
    let mut calldata = array![];
    let name: ByteArray = "IP Collection";
    let symbol: ByteArray = "IPC";
    let base_uri: ByteArray = "ipfs://QmBaseUri";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    owner.serialize(ref calldata);

    let declare_result = declare("IPCollection").expect('Failed to declare contract');
    let contract_class = declare_result.contract_class();
    let (contract_address, _) = contract_class
        .deploy(@calldata)
        .expect('Failed to deploy contract');

    let dispatcher = IIPCollectionDispatcher { contract_address };
    (dispatcher, contract_address)
}

// Helper function to create a test collection
fn setup_collection(dispatcher: IIPCollectionDispatcher, address: ContractAddress) -> u256 {
    let owner = OWNER();
    let name: ByteArray = "Test Collection";
    let symbol: ByteArray = "TST";
    let base_uri: ByteArray = "ipfs://QmCollectionBaseUri";
    start_cheat_caller_address(address, owner);
    let collection_id = dispatcher.create_collection(name, symbol, base_uri);
    stop_cheat_caller_address(address);
    collection_id
}

#[test]
fn test_create_collection() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    start_cheat_caller_address(address, owner);

    let name: ByteArray = "My Collection";
    let symbol: ByteArray = "MC";
    let base_uri: ByteArray = "ipfs://QmMyCollection";
    let collection_id = dispatcher
        .create_collection(name.clone(), symbol.clone(), base_uri.clone());

    assert(collection_id == 1, 'Collection ID should be 1');
    let collection = dispatcher.get_collection(collection_id);
    assert(collection.name == name, 'Collection name mismatch');
    assert(collection.symbol == symbol, 'Collection symbol mismatch');
    assert(collection.base_uri == base_uri, 'Collection base_uri mismatch');
    assert(collection.owner == owner, 'Collection owner mismatch');
    assert(collection.is_active, 'Collection should be active');

    let owner_collections = dispatcher.list_user_collections(owner);
    assert(owner_collections.len() == 1, 'Owner should have 1 collection');
    assert(*owner_collections.at(0) == collection_id, 'Collection ID mismatch');

    stop_cheat_caller_address(address);
}

#[test]
fn test_create_multiple_collections() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    start_cheat_caller_address(address, owner);

    let name1: ByteArray = "Collection 1";
    let symbol1: ByteArray = "C1";
    let base_uri1: ByteArray = "ipfs://QmCollection1";
    let collection_id1 = dispatcher.create_collection(name1, symbol1, base_uri1);
    assert(collection_id1 == 1, 'First collection ID should be 1');

    let name2: ByteArray = "Collection 2";
    let symbol2: ByteArray = "C2";
    let base_uri2: ByteArray = "ipfs://QmCollection2";
    let collection_id2 = dispatcher.create_collection(name2, symbol2, base_uri2);
    assert(collection_id2 == 2, 'Second ID should be 2');

    let owner_collections = dispatcher.list_user_collections(owner);
    assert(owner_collections.len() == 2, 'Owner should have 2 collections');
    assert(*owner_collections.at(0) == collection_id1, 'First collection ID mismatch');
    assert(*owner_collections.at(1) == collection_id2, 'Second collection ID mismatch');

    stop_cheat_caller_address(address);
}

#[test]
#[should_panic(expected: ('Caller is zero address',))]
fn test_create_collection_zero_address() {
    let (dispatcher, address) = deploy_contract();
    start_cheat_caller_address(address, contract_address_const::<0>());
    dispatcher.create_collection("Zero Collection", "ZC", "ipfs://QmZeroCollection");
}

#[test]
fn test_mint_token() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let recipient = USER1();
    let collection_id = setup_collection(dispatcher, address);

    start_cheat_caller_address(address, owner);
    let token_id = dispatcher.mint(collection_id, recipient);
    assert(token_id == 1, 'Token ID should be 1');

    let token = dispatcher.get_token(token_id);
    assert(token.collection_id == collection_id, 'Token collection ID mismatch');
    assert(token.token_id == token_id, 'Token ID mismatch');
    assert(token.owner == recipient, 'Token owner mismatch');
    assert(token.metadata_uri == "ipfs://QmCollectionBaseUri1.json", 'Token metadata URI mismatch');

    let recipient_tokens = dispatcher.list_user_tokens(recipient);
    assert(recipient_tokens.len() == 1, 'Recipient should have 1 token');
    assert(*recipient_tokens.at(0) == token_id, 'TokID mismatch in rec tokens');

    stop_cheat_caller_address(address);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_mint_not_owner() {
    let (dispatcher, address) = deploy_contract();
    let non_owner = USER1();
    let recipient = USER2();
    let collection_id = setup_collection(dispatcher, address);

    start_cheat_caller_address(address, non_owner);
    dispatcher.mint(collection_id, recipient);
}

#[test]
#[should_panic(expected: ('Recipient is zero address',))]
fn test_mint_to_zero_address() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let collection_id = setup_collection(dispatcher, address);

    start_cheat_caller_address(address, owner);
    dispatcher.mint(collection_id, contract_address_const::<0>());
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_mint_zero_caller() {
    let (dispatcher, address) = deploy_contract();
    let recipient = USER1();
    let collection_id = setup_collection(dispatcher, address);

    start_cheat_caller_address(address, contract_address_const::<0>());
    dispatcher.mint(collection_id, recipient);
}

#[test]
#[should_panic(expected: ('ERC721: unauthorized caller',))]
fn test_burn_not_owner() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let recipient = USER1();
    let non_owner = USER2();
    let collection_id = setup_collection(dispatcher, address);

    start_cheat_caller_address(address, owner);
    let token_id = dispatcher.mint(collection_id, recipient);
    stop_cheat_caller_address(address);

    start_cheat_caller_address(address, non_owner);
    dispatcher.burn(token_id);
}

#[test]
#[should_panic(expected: ('Contract not approved',))]
fn test_transfer_token_not_approved() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let from_user = USER1();
    let to_user = USER2();
    let collection_id = setup_collection(dispatcher, address);

    start_cheat_caller_address(address, owner);
    let token_id = dispatcher.mint(collection_id, from_user);
    stop_cheat_caller_address(address);

    start_cheat_caller_address(address, from_user);
    dispatcher.transfer_token(from_user, to_user, token_id);
}

#[test]
#[should_panic(expected: ('Caller is zero address',))]
fn test_transfer_token_zero_caller() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let from_user = USER1();
    let to_user = USER2();
    let collection_id = setup_collection(dispatcher, address);

    start_cheat_caller_address(address, owner);
    let token_id = dispatcher.mint(collection_id, from_user);
    stop_cheat_caller_address(address);

    start_cheat_caller_address(address, contract_address_const::<0>());
    dispatcher.transfer_token(from_user, to_user, token_id);
}

#[test]
fn test_list_user_collections_empty() {
    let (dispatcher, _) = deploy_contract();
    let random_user = USER2();
    let collections = dispatcher.list_user_collections(random_user);
    assert(collections.len() == 0, 'Should have no collections');
}

#[test]
fn test_list_user_tokens_empty() {
    let (dispatcher, _) = deploy_contract();
    let random_user = USER2();
    let tokens = dispatcher.list_user_tokens(random_user);
    assert(tokens.len() == 0, 'Should have no tokens');
}

// FIXED: Ensured caller spoofing persists for all mint calls and verified owner
#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_list_all_tokens_not_owner() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let user1 = USER1();
    let user2 = USER2();
    start_cheat_caller_address(address, owner); // Spoof owner for entire test

    // Create two collections
    let collection_id1 = setup_collection(dispatcher, address); // Already spoofs owner
    let collection_id2 = dispatcher.create_collection("Collection B", "CB", "ipfs://QmCollectionB");

    // Mint tokens to different users across collections
    let token_id1 = dispatcher.mint(collection_id1, user1); // Token 1 in Collection 1
    let token_id2 = dispatcher.mint(collection_id1, user2); // Token 2 in Collection 1
    let token_id3 = dispatcher.mint(collection_id2, user1); // Token 3 in Collection 2

    // Verify all tokens are listed
    let all_tokens = dispatcher.list_all_tokens();
    assert(all_tokens.len() == 3, 'Should have 3 tokens');
    assert(*all_tokens.at(0) == token_id1, 'First token ID mismatch');
    assert(*all_tokens.at(1) == token_id2, 'Second token ID mismatch');
    assert(*all_tokens.at(2) == token_id3, 'Third token ID mismatch');

    // Verify empty contract
    let (dispatcher_empty, _) = deploy_contract();
    let empty_tokens = dispatcher_empty.list_all_tokens();
    assert(empty_tokens.len() == 0, 'Should have 0 tokens');

    stop_cheat_caller_address(address);
}

// FIXED: Ensured caller spoofing persists for all mint calls and verified owner
#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_list_collection_tokens_not_owner() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let user1 = USER1();
    let user2 = USER2();
    start_cheat_caller_address(address, owner); // Spoof owner for entire test

    // Create two collections
    let collection_id1 = setup_collection(dispatcher, address); // Already spoofs owner
    let collection_id2 = dispatcher.create_collection("Collection B", "CB", "ipfs://QmCollectionB");

    // Mint tokens to different users in collection 1
    let token_id1 = dispatcher.mint(collection_id1, user1); // Token 1 in Collection 1
    let token_id2 = dispatcher.mint(collection_id1, user2); // Token 2 in Collection 1
    // Mint a token in collection 2
    let token_id3 = dispatcher.mint(collection_id2, user1); // Token 3 in Collection 2

    // Verify tokens in collection 1
    let collection1_tokens = dispatcher.list_collection_tokens(collection_id1);
    assert(collection1_tokens.len() == 2, 'Coll 1 should have 2 tokens');
    assert(*collection1_tokens.at(0) == token_id1, 'First token ID mismatch 1');
    assert(*collection1_tokens.at(1) == token_id2, 'Second token ID mismatch 1');

    // Verify tokens 2
    let collection2_tokens = dispatcher.list_collection_tokens(collection_id2);
    assert(collection2_tokens.len() == 1, 'Coll 2 should have 1 token');
    assert(*collection2_tokens.at(0) == token_id3, 'Token ID mismatch 2');

    // Verify non-existent collection
    let empty_tokens = dispatcher.list_collection_tokens(999);
    assert(empty_tokens.len() == 0, 'Non-existent, should have 0');

    stop_cheat_caller_address(address);
}

#[test]
fn test_multiple_tokens_metadata_uris() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let recipient = USER1();
    start_cheat_caller_address(address, owner); // Start spoofing at the beginning

    // Create collection
    let collection_id = dispatcher.create_collection("Test Collection", "TST", "ipfs://QmCollectionBaseUri");

    // Mint multiple tokens
    let token_id1 = dispatcher.mint(collection_id, recipient);
    let token_id2 = dispatcher.mint(collection_id, recipient);
    let token_id3 = dispatcher.mint(collection_id, recipient);

    // Verify token metadata URIs
    let token1 = dispatcher.get_token(token_id1);
    let token2 = dispatcher.get_token(token_id2);
    let token3 = dispatcher.get_token(token_id3);

    assert(token1.metadata_uri == "ipfs://QmCollectionBaseUri1.json", 'Token 1 metadata URI mismatch');
    assert(token2.metadata_uri == "ipfs://QmCollectionBaseUri2.json", 'Token 2 metadata URI mismatch');
    assert(token3.metadata_uri == "ipfs://QmCollectionBaseUri3.json", 'Token 3 metadata URI mismatch');

    stop_cheat_caller_address(address);
}

#[test]
fn test_different_collections_metadata_uris() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let recipient = USER1();
    start_cheat_caller_address(address, owner);

    // Create two collections with different base URIs
    let collection1_id = dispatcher.create_collection(
        "Collection 1", "C1", "ipfs://QmCollection1/"
    );
    let collection2_id = dispatcher.create_collection(
        "Collection 2", "C2", "ipfs://QmCollection2/"
    );

    // Mint tokens in different collections
    let token1_id = dispatcher.mint(collection1_id, recipient);
    let token2_id = dispatcher.mint(collection2_id, recipient);

    // Verify token metadata URIs
    let token1 = dispatcher.get_token(token1_id);
    let token2 = dispatcher.get_token(token2_id);

    // Fix: token IDs are globally incremented, so first token is 1, second is 2
    assert(token1.metadata_uri == "ipfs://QmCollection1/1.json", 'Collection 1 token md mismatch');
    assert(token2.metadata_uri == "ipfs://QmCollection2/2.json", 'Collection 2 token md mismatch');

    stop_cheat_caller_address(address);
}

#[test]
fn test_token_metadata_uri_format() {
    let (dispatcher, address) = deploy_contract();
    let owner = OWNER();
    let recipient = USER1();
    start_cheat_caller_address(address, owner);

    // Create collection with a specific base URI
    let base_uri: ByteArray = "https://example.com/nfts/";
    let collection_id = dispatcher.create_collection("Test Collection", "TST", base_uri);

    // Mint a token
    let token_id = dispatcher.mint(collection_id, recipient);
    let token = dispatcher.get_token(token_id);

    // Verify the metadata URI follows the standard format
    assert(token.metadata_uri == "https://example.com/nfts/1.json", 'Token metadata mismatch');

    stop_cheat_caller_address(address);
}
