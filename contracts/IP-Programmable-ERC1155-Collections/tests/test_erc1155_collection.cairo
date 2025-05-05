use starknet::ContractAddress;
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_testing::deployment::{declare_and_deploy, declare_class};
use openzeppelin_testing::constants::{
    OWNER, BASE_URI, TOKEN_ID, TOKEN_ID_2, TOKEN_VALUE, TOKEN_VALUE_2
};
use openzeppelin_upgrades::interface::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
use snforge_std::{cheat_caller_address, CheatSpan};
use ip_programmable_erc1155_collections::interfaces::{
    IERC1155CollectionMixinDispatcher, IERC1155CollectionMixinDispatcherTrait
};
use super::erc1155_collection_v2::{
    IERC1155CollectionV2MixinDispatcher, IERC1155CollectionV2MixinDispatcherTrait
};

const TOKEN_IDS: [u256; 1] = [TOKEN_ID];
const TOKEN_VALUES: [u256; 1] = [TOKEN_VALUE];
const TOKEN_IDS_2: [u256; 1] = [TOKEN_ID_2];
const TOKEN_VALUES_2: [u256; 1] = [TOKEN_VALUE_2];

fn setup() -> (ContractAddress, IERC1155CollectionMixinDispatcher, ContractAddress) {
    let erc1155_receiver_address = declare_and_deploy("ERC1155ReceiverContract", array![]);

    let mut calldata = array![];
    calldata.append_serde(OWNER);
    calldata.append_serde(BASE_URI());
    calldata.append_serde(erc1155_receiver_address);
    calldata.append_serde(TOKEN_IDS.span());
    calldata.append_serde(TOKEN_VALUES.span());
    let erc1155_collection_address = declare_and_deploy("ERC1155CollectionContract", calldata);

    let erc1155_collection = IERC1155CollectionMixinDispatcher {
        contract_address: erc1155_collection_address
    };

    (erc1155_collection_address, erc1155_collection, erc1155_receiver_address)
}

#[test]
fn test_deploy() {
    let (_, erc1155_collection, erc1155_receiver_address) = setup();

    assert_eq!(erc1155_collection.owner(), OWNER);
    assert_eq!(erc1155_collection.uri(TOKEN_ID), BASE_URI());
    assert_eq!(
        erc1155_collection
            .balance_of_batch(array![erc1155_receiver_address].span(), TOKEN_IDS.span()),
        TOKEN_VALUES.span()
    );
    let contract_class = declare_class("ERC1155CollectionContract");
    assert_eq!(erc1155_collection.class_hash(), contract_class.class_hash);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_upgrade_not_owner() {
    let (erc1155_collection_address, _, _) = setup();

    let contract_class = declare_class("ERC1155CollectionContractV2");
    let upgradeable = IUpgradeableDispatcher { contract_address: erc1155_collection_address };
    upgradeable.upgrade(contract_class.class_hash);
}

#[test]
fn test_upgrade() {
    let (erc1155_collection_address, erc1155_collection, _) = setup();

    let contract_class = declare_class("ERC1155CollectionContractV2");
    let upgradeable = IUpgradeableDispatcher { contract_address: erc1155_collection_address };
    cheat_caller_address(erc1155_collection_address, OWNER, CheatSpan::TargetCalls(1));
    upgradeable.upgrade(contract_class.class_hash);
    assert_eq!(erc1155_collection.class_hash(), contract_class.class_hash);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_mint_not_owner() {
    let (_, erc1155_collection, erc1155_receiver_address) = setup();

    erc1155_collection.mint(erc1155_receiver_address, TOKEN_ID_2, TOKEN_VALUE_2);
}

#[test]
fn test_mint() {
    let (erc1155_collection_address, erc1155_collection, erc1155_receiver_address) = setup();

    cheat_caller_address(erc1155_collection_address, OWNER, CheatSpan::TargetCalls(1));
    erc1155_collection.mint(erc1155_receiver_address, TOKEN_ID_2, TOKEN_VALUE_2);
    assert_eq!(erc1155_collection.balance_of(erc1155_receiver_address, TOKEN_ID_2), TOKEN_VALUE_2);
}

#[test]
fn test_batch_mint() {
    let (erc1155_collection_address, _, erc1155_receiver_address) = setup();

    let contract_class = declare_class("ERC1155CollectionContractV2");
    let upgradeable = IUpgradeableDispatcher { contract_address: erc1155_collection_address };
    cheat_caller_address(erc1155_collection_address, OWNER, CheatSpan::TargetCalls(1));
    upgradeable.upgrade(contract_class.class_hash);

    let erc1155_collection_v2 = IERC1155CollectionV2MixinDispatcher {
        contract_address: erc1155_collection_address
    };

    cheat_caller_address(erc1155_collection_address, OWNER, CheatSpan::TargetCalls(1));
    erc1155_collection_v2
        .batch_mint(erc1155_receiver_address, TOKEN_IDS_2.span(), TOKEN_VALUES_2.span());
    assert_eq!(
        erc1155_collection_v2
            .balance_of_batch(array![erc1155_receiver_address].span(), TOKEN_IDS_2.span()),
        TOKEN_VALUES_2.span()
    );
}
