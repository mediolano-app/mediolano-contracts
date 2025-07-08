use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use core::result::ResultTrait;
use ip_collection_erc_721::interfaces::IIPCollection::{
    IIPCollectionDispatcher, IIPCollectionDispatcherTrait,
};
// use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};

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
// // Deploy the IPCollection contract
// fn deploy_contract() -> (IIPCollectionDispatcher, ContractAddress) {
//     let owner = OWNER();
//     let mut calldata = array![];
//     let name: ByteArray = "IP Collection";
//     let symbol: ByteArray = "IPC";
//     let base_uri: ByteArray = "ipfs://QmBaseUri";
//     name.serialize(ref calldata);
//     symbol.serialize(ref calldata);
//     base_uri.serialize(ref calldata);
//     owner.serialize(ref calldata);

//     let declare_result = declare("IPCollection").expect('Failed to declare contract');
//     let contract_class = declare_result.contract_class();
//     let (contract_address, _) = contract_class
//         .deploy(@calldata)
//         .expect('Failed to deploy contract');

//     let dispatcher = IIPCollectionDispatcher { contract_address };
//     (dispatcher, contract_address)
// }

// // Helper function to create a test collection
// fn setup_collection(dispatcher: IIPCollectionDispatcher, address: ContractAddress) -> u256 {
//     let owner = OWNER();
//     let name: ByteArray = "Test Collection";
//     let symbol: ByteArray = "TST";
//     let base_uri: ByteArray = "ipfs://QmCollectionBaseUri";
//     start_cheat_caller_address(address, owner);
//     let collection_id = dispatcher.create_collection(name, symbol, base_uri);
//     stop_cheat_caller_address(address);
//     collection_id
// }

// #[test]
// fn test_create_collection() {
//     let (dispatcher, address) = deploy_contract();
//     let owner = OWNER();
//     start_cheat_caller_address(address, owner);

//     let name: ByteArray = "My Collection";
//     let symbol: ByteArray = "MC";
//     let base_uri: ByteArray = "ipfs://QmMyCollection";
//     let collection_id = dispatcher
//         .create_collection(name.clone(), symbol.clone(), base_uri.clone());

//     assert(collection_id == 1, 'Collection ID should be 1');
//     let collection = dispatcher.get_collection(collection_id);
//     assert(collection.name == name, 'Collection name mismatch');
//     assert(collection.symbol == symbol, 'Collection symbol mismatch');
//     assert(collection.base_uri == base_uri, 'Collection base_uri mismatch');
//     assert(collection.owner == owner, 'Collection owner mismatch');
//     assert(collection.is_active, 'Collection should be active');

//     stop_cheat_caller_address(address);
// }

// #[test]
// fn test_create_multiple_collections() {
//     let (dispatcher, address) = deploy_contract();
//     let owner = OWNER();
//     start_cheat_caller_address(address, owner);

//     let name1: ByteArray = "Collection 1";
//     let symbol1: ByteArray = "C1";
//     let base_uri1: ByteArray = "ipfs://QmCollection1";
//     let collection_id1 = dispatcher.create_collection(name1, symbol1, base_uri1);
//     assert(collection_id1 == 1, 'First collection ID should be 1');

//     let name2: ByteArray = "Collection 2";
//     let symbol2: ByteArray = "C2";
//     let base_uri2: ByteArray = "ipfs://QmCollection2";
//     let collection_id2 = dispatcher.create_collection(name2, symbol2, base_uri2);
//     assert(collection_id2 == 2, 'Second ID should be 2');

//     stop_cheat_caller_address(address);
// }

// #[test]
// #[should_panic(expected: ('Caller is zero address',))]
// fn test_create_collection_zero_address() {
//     let (dispatcher, address) = deploy_contract();
//     start_cheat_caller_address(address, contract_address_const::<0>());
//     dispatcher.create_collection("Zero Collection", "ZC", "ipfs://QmZeroCollection");
// }

// #[test]
// fn test_mint_token() {
//     let (dispatcher, address) = deploy_contract();
//     let owner = OWNER();
//     let recipient = USER1();
//     let collection_id = setup_collection(dispatcher, address);

//     start_cheat_caller_address(address, owner);
//     let token_id = dispatcher.mint(collection_id, recipient);
//     assert(token_id == 1, 'Token ID should be 1');

//     let token = dispatcher.get_token(token_id);
//     assert(token.collection_id == collection_id, 'Token collection ID mismatch');
//     assert(token.token_id == token_id, 'Token ID mismatch');
//     assert(token.owner == recipient, 'Token owner mismatch');
//     assert(token.metadata_uri == "ipfs://QmCollectionBaseUri", 'Token metadata URI mismatch');

//     stop_cheat_caller_address(address);
// }

// #[test]
// #[should_panic(expected: ('Caller is not the owner',))]
// fn test_mint_not_owner() {
//     let (dispatcher, address) = deploy_contract();
//     let non_owner = USER1();
//     let recipient = USER2();
//     let collection_id = setup_collection(dispatcher, address);

//     start_cheat_caller_address(address, non_owner);
//     dispatcher.mint(collection_id, recipient);
// }

// #[test]
// #[should_panic(expected: ('Recipient is zero address',))]
// fn test_mint_to_zero_address() {
//     let (dispatcher, address) = deploy_contract();
//     let owner = OWNER();
//     let collection_id = setup_collection(dispatcher, address);

//     start_cheat_caller_address(address, owner);
//     dispatcher.mint(collection_id, contract_address_const::<0>());
// }

// #[test]
// #[should_panic(expected: ('Caller is not the owner',))]
// fn test_mint_zero_caller() {
//     let (dispatcher, address) = deploy_contract();
//     let recipient = USER1();
//     let collection_id = setup_collection(dispatcher, address);

//     start_cheat_caller_address(address, contract_address_const::<0>());
//     dispatcher.mint(collection_id, recipient);
// }

// #[test]
// #[should_panic(expected: ('ERC721: unauthorized caller',))]
// fn test_burn_not_owner() {
//     let (dispatcher, address) = deploy_contract();
//     let owner = OWNER();
//     let recipient = USER1();
//     let non_owner = USER2();
//     let collection_id = setup_collection(dispatcher, address);

//     start_cheat_caller_address(address, owner);
//     let token_id = dispatcher.mint(collection_id, recipient);
//     stop_cheat_caller_address(address);

//     start_cheat_caller_address(address, non_owner);
//     dispatcher.burn(token_id);
// }

// #[test]
// #[should_panic(expected: ('Contract not approved',))]
// fn test_transfer_token_not_approved() {
//     let (dispatcher, address) = deploy_contract();
//     let owner = OWNER();
//     let from_user = USER1();
//     let to_user = USER2();
//     let collection_id = setup_collection(dispatcher, address);

//     start_cheat_caller_address(address, owner);
//     let token_id = dispatcher.mint(collection_id, from_user);
//     stop_cheat_caller_address(address);

//     start_cheat_caller_address(address, from_user);
//     dispatcher.transfer_token(from_user, to_user, token_id);
// }

// #[test]
// #[should_panic(expected: ('Caller is zero address',))]
// fn test_transfer_token_zero_caller() {
//     let (dispatcher, address) = deploy_contract();
//     let owner = OWNER();
//     let from_user = USER1();
//     let to_user = USER2();
//     let collection_id = setup_collection(dispatcher, address);

//     start_cheat_caller_address(address, owner);
//     let token_id = dispatcher.mint(collection_id, from_user);
//     stop_cheat_caller_address(address);

//     start_cheat_caller_address(address, contract_address_const::<0>());
//     dispatcher.transfer_token(from_user, to_user, token_id);
// }

// #[test]
// fn test_list_user_collections_empty() {
//     let (dispatcher, _) = deploy_contract();
//     let random_user = USER2();
//     let collections = dispatcher.list_user_collections(random_user);
//     assert(collections.len() == 0, 'Should have no collections');
// }

// #[test]
// fn test_list_user_tokens_empty() {
//     let (dispatcher, _) = deploy_contract();
//     let random_user = USER2();
//     let tokens = dispatcher.list_user_tokens(random_user);
//     assert(tokens.len() == 0, 'Should have no tokens');
// }

// // FIXED: Ensured caller spoofing persists for all mint calls and verified owner
// #[test]
// #[should_panic(expected: ('Caller is not the owner',))]
// fn test_list_all_tokens_not_owner() {
//     let (dispatcher, address) = deploy_contract();
//     let owner = OWNER();
//     let user1 = USER1();
//     let user2 = USER2();
//     start_cheat_caller_address(address, owner); // Spoof owner for entire test

//     // Create two collections
//     let collection_id1 = setup_collection(dispatcher, address); // Already spoofs owner
//     let collection_id2 = dispatcher.create_collection("Collection B", "CB",
//     "ipfs://QmCollectionB");

//     // Mint tokens to different users across collections
//     let token_id1 = dispatcher.mint(collection_id1, user1); // Token 1 in Collection 1
//     let token_id2 = dispatcher.mint(collection_id1, user2); // Token 2 in Collection 1
//     let token_id3 = dispatcher.mint(collection_id2, user1); // Token 3 in Collection 2

//     // Verify all tokens are listed
//     let all_tokens = dispatcher.list_all_tokens();
//     assert(all_tokens.len() == 3, 'Should have 3 tokens');
//     assert(*all_tokens.at(0) == token_id1, 'First token ID mismatch');
//     assert(*all_tokens.at(1) == token_id2, 'Second token ID mismatch');
//     assert(*all_tokens.at(2) == token_id3, 'Third token ID mismatch');

//     // Verify empty contract
//     let (dispatcher_empty, _) = deploy_contract();
//     let empty_tokens = dispatcher_empty.list_all_tokens();
//     assert(empty_tokens.len() == 0, 'Should have 0 tokens');

//     stop_cheat_caller_address(address);
// }

// // FIXED: Ensured caller spoofing persists for all mint calls and verified owner
// #[test]
// #[should_panic(expected: ('Caller is not the owner',))]
// fn test_list_collection_tokens_not_owner() {
//     let (dispatcher, address) = deploy_contract();
//     let owner = OWNER();
//     let user1 = USER1();
//     let user2 = USER2();
//     start_cheat_caller_address(address, owner); // Spoof owner for entire test

//     // Create two collections
//     let collection_id1 = setup_collection(dispatcher, address); // Already spoofs owner
//     let collection_id2 = dispatcher.create_collection("Collection B", "CB",
//     "ipfs://QmCollectionB");

//     // Mint tokens to different users in collection 1
//     let token_id1 = dispatcher.mint(collection_id1, user1); // Token 1 in Collection 1
//     let token_id2 = dispatcher.mint(collection_id1, user2); // Token 2 in Collection 1
//     // Mint a token in collection 2
//     let token_id3 = dispatcher.mint(collection_id2, user1); // Token 3 in Collection 2

//     // Verify tokens in collection 1
//     let collection1_tokens = dispatcher.list_collection_tokens(collection_id1);
//     assert(collection1_tokens.len() == 2, 'Coll 1 should have 2 tokens');
//     assert(*collection1_tokens.at(0) == token_id1, 'First token ID mismatch 1');
//     assert(*collection1_tokens.at(1) == token_id2, 'Second token ID mismatch 1');

//     // Verify tokens 2
//     let collection2_tokens = dispatcher.list_collection_tokens(collection_id2);
//     assert(collection2_tokens.len() == 1, 'Coll 2 should have 1 token');
//     assert(*collection2_tokens.at(0) == token_id3, 'Token ID mismatch 2');

//     // Verify non-existent collection
//     let empty_tokens = dispatcher.list_collection_tokens(999);
//     assert(empty_tokens.len() == 0, 'Non-existent, should have 0');

//     stop_cheat_caller_address(address);
// }

// #[test]
// fn test_mint_batch() {
//     let (dispatcher, address) = deploy_contract();
//     let owner = OWNER();
//     let recipients = array![USER1(), USER2()];
//     let collection_id = setup_collection(dispatcher, address);

//     start_cheat_caller_address(address, owner);
//     let token_ids = dispatcher.mint_batch(collection_id, recipients.clone());
//     assert(token_ids.len() == 2, 'Should mint 2 tokens');
//     let token1 = dispatcher.get_token(*token_ids.at(0));
//     let token2 = dispatcher.get_token(*token_ids.at(1));
//     assert(token1.owner == USER1(), 'First token owner mismatch');
//     assert(token2.owner == USER2(), 'Second token owner mismatch');
//     stop_cheat_caller_address(address);
// }

// #[test]
// fn test_transfer_batch() {
//     let (dispatcher, address) = deploy_contract();
//     let owner = OWNER();
//     let recipients = array![USER1(), USER1()];
//     let collection_id = setup_collection(dispatcher, address);

//     start_cheat_caller_address(address, owner);
//     let token_ids = dispatcher.mint_batch(collection_id, recipients.clone());
//     dispatcher.transfer_batch(USER1(), USER2(), token_ids.clone());
//     let token1 = dispatcher.get_token(*token_ids.at(0));
//     let token2 = dispatcher.get_token(*token_ids.at(1));
//     assert(token1.owner == USER2(), 'First token should be transfd');
//     assert(token2.owner == USER2(), 'Second token should be transf');
//     stop_cheat_caller_address(address);
// }

// #[test]
// fn test_update_collection_metadata() {
//     let (dispatcher, address) = deploy_contract();
//     let owner = OWNER();
//     let collection_id = setup_collection(dispatcher, address);

//     start_cheat_caller_address(address, owner);
//     dispatcher.update_collection_metadata(collection_id, "New Name", "NEW",
//     "ipfs://QmNewBaseUri");
//     let collection = dispatcher.get_collection(collection_id);
//     assert(collection.name == "New Name", 'Name should be updated');
//     assert(collection.symbol == "NEW", 'Symbol should be updated');
//     assert(collection.base_uri == "ipfs://QmNewBaseUri", 'Base URI should be updated');
//     stop_cheat_caller_address(address);
// }

// #[test]
// fn test_verification_functions() {
//     let (dispatcher, address) = deploy_contract();
//     let owner = OWNER();
//     let collection_id = setup_collection(dispatcher, address);

//     start_cheat_caller_address(address, owner);
//     let token_id = dispatcher.mint(collection_id, USER1());
//     assert(dispatcher.is_valid_collection(collection_id), 'Collection should be valid');
//     assert(dispatcher.is_valid_token(token_id), 'Token should be valid');
//     assert(dispatcher.is_collection_owner(collection_id, owner), 'Owner should be correct');
//     stop_cheat_caller_address(address);
// }

// #[test]
// fn test_get_collection_stats() {
//     let (dispatcher, address) = deploy_contract();
//     let owner = OWNER();
//     let collection_id = setup_collection(dispatcher, address);

//     start_cheat_caller_address(address, owner);
//     let _ = dispatcher.mint(collection_id, USER1());
//     let stats = dispatcher.get_collection_stats(collection_id);
//     assert(stats.total_supply == 1, 'Total supply should be 1');
//     stop_cheat_caller_address(address);
// }


