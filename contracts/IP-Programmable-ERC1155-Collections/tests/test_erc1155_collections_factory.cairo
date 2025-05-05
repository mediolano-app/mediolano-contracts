use starknet::ContractAddress;
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_testing::deployment::{declare_and_deploy, declare_class};
use openzeppelin_testing::constants::{OWNER, BASE_URI, TOKEN_ID, TOKEN_VALUE};
use snforge_std::{cheat_caller_address, CheatSpan};
use ip_programmable_erc1155_collections::interfaces::{
    IERC1155CollectionsFactoryMixinDispatcher, IERC1155CollectionsFactoryMixinDispatcherTrait,
    IERC1155CollectionMixinDispatcher, IERC1155CollectionMixinDispatcherTrait
};

const TOKEN_IDS: [u256; 1] = [TOKEN_ID];
const TOKEN_VALUES: [u256; 1] = [TOKEN_VALUE];

fn setup() -> (ContractAddress, IERC1155CollectionsFactoryMixinDispatcher) {
    let erc1155_collections_contract_class = declare_class("ERC1155CollectionContract");
    let mut calldata = array![];
    calldata.append_serde(OWNER);
    calldata.append_serde(erc1155_collections_contract_class.class_hash);
    let erc1155_collections_factory_address = declare_and_deploy(
        "ERC1155CollectionsFactoryContract", calldata
    );

    let erc1155_collections_factory = IERC1155CollectionsFactoryMixinDispatcher {
        contract_address: erc1155_collections_factory_address
    };

    (erc1155_collections_factory_address, erc1155_collections_factory)
}

#[test]
fn test_deploy() {
    let (_, erc1155_collections_factory) = setup();

    assert_eq!(erc1155_collections_factory.owner(), OWNER);

    let erc1155_collections_contract_class = declare_class("ERC1155CollectionContract");
    assert_eq!(
        erc1155_collections_factory.erc1155_collections_class_hash(),
        erc1155_collections_contract_class.class_hash
    );
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_update_erc1155_collections_class_hash_not_owner() {
    let (_, erc1155_collections_factory) = setup();

    let erc1155_collections_contract_class = declare_class("ERC1155CollectionContractV2");
    erc1155_collections_factory
        .update_erc1155_collections_class_hash(erc1155_collections_contract_class.class_hash);
}

#[test]
fn test_update_erc1155_collections_class_hash() {
    let (erc1155_collections_factory_address, erc1155_collections_factory) = setup();

    let erc1155_collections_contract_class = declare_class("ERC1155CollectionContractV2");
    cheat_caller_address(erc1155_collections_factory_address, OWNER, CheatSpan::TargetCalls(1));
    erc1155_collections_factory
        .update_erc1155_collections_class_hash(erc1155_collections_contract_class.class_hash);
    assert_eq!(
        erc1155_collections_factory.erc1155_collections_class_hash(),
        erc1155_collections_contract_class.class_hash
    );
}

#[test]
fn test_deploy_erc1155_collection() {
    let (erc1155_collections_factory_address, erc1155_collections_factory) = setup();

    let erc1155_receiver_address = declare_and_deploy("ERC1155ReceiverContract", array![]);

    cheat_caller_address(erc1155_collections_factory_address, OWNER, CheatSpan::TargetCalls(1));
    let erc1155_collection_address = erc1155_collections_factory
        .deploy_erc1155_collection(
            BASE_URI(), erc1155_receiver_address, TOKEN_IDS.span(), TOKEN_VALUES.span()
        );

    let erc1155_collection = IERC1155CollectionMixinDispatcher {
        contract_address: erc1155_collection_address
    };
    assert_eq!(erc1155_collection.owner(), OWNER);
    let erc1155_collections_contract_class = declare_class("ERC1155CollectionContract");
    assert_eq!(erc1155_collection.class_hash(), erc1155_collections_contract_class.class_hash);
    assert_eq!(
        erc1155_collection
            .balance_of_batch(array![erc1155_receiver_address].span(), TOKEN_IDS.span()),
        TOKEN_VALUES.span()
    );
}
