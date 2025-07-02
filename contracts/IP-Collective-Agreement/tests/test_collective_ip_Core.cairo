use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use ip_collective_agreement::types::{OwnershipInfo, IPAssetInfo, IPAssetType, ComplianceStatus};
use ip_collective_agreement::interface::{
    IOwnershipRegistryDispatcher, IOwnershipRegistryDispatcherTrait, IIPAssetManagerDispatcher,
    IIPAssetManagerDispatcherTrait, IRevenueDistributionDispatcher,
    IRevenueDistributionDispatcherTrait,
};
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use core::num::traits::Bounded;

fn OWNER() -> ContractAddress {
    deploy_erc1155_receiver()
}
fn CREATOR1() -> ContractAddress {
    deploy_erc1155_receiver()
}
fn CREATOR2() -> ContractAddress {
    deploy_erc1155_receiver()
}
fn CREATOR3() -> ContractAddress {
    deploy_erc1155_receiver()
}
fn USER() -> ContractAddress {
    deploy_erc1155_receiver()
}

fn SPENDER() -> ContractAddress {
    'spender'.try_into().unwrap()
}

fn MARKETPLACE() -> ContractAddress {
    'marketplace'.try_into().unwrap()
}

fn deploy_mock_erc20(
    name: ByteArray, symbol: ByteArray, initial_supply: u256, recipient: ContractAddress,
) -> ContractAddress {
    let mut calldata: Array<felt252> = ArrayTrait::new();
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    initial_supply.low.serialize(ref calldata);
    initial_supply.high.serialize(ref calldata);
    recipient.serialize(ref calldata);

    let contract = declare("MockERC20").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

fn deploy_erc1155_receiver() -> ContractAddress {
    let contract_class = declare("ERC1155ReceiverContract").unwrap().contract_class();

    let (contract_address, _) = contract_class.deploy(@array![]).unwrap();
    contract_address
}

// Deploy the contract
fn deploy_contract() -> (ContractAddress, ContractAddress) {
    let contract_class = declare("CollectiveIPCore").unwrap().contract_class();

    let base_uri: ByteArray = "ipfs://QmBaseUri/";
    let owner_address = OWNER();

    let mut calldata = array![];
    owner_address.serialize(ref calldata);
    base_uri.serialize(ref calldata);

    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    (contract_address, owner_address)
}

fn setup() -> (
    ContractAddress,
    IOwnershipRegistryDispatcher,
    IIPAssetManagerDispatcher,
    IERC1155Dispatcher,
    IRevenueDistributionDispatcher,
    IERC20Dispatcher,
    ContractAddress,
) {
    let (contract_address, owner_address) = deploy_contract();
    let ownership_dispatcher = IOwnershipRegistryDispatcher { contract_address };
    let asset_dispatcher = IIPAssetManagerDispatcher { contract_address };
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };
    let revenue_dispatcher = IRevenueDistributionDispatcher { contract_address };
    let erc20_contract = deploy_mock_erc20("TestToken", "TTK", 10000.into(), SPENDER());
    let erc20_dispatcher = IERC20Dispatcher { contract_address: erc20_contract };

    start_cheat_caller_address(erc20_contract, SPENDER());
    // approve the contract to spend maximum amount
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    // fund marketplace with some tokens
    erc20_dispatcher.transfer(MARKETPLACE(), 1000_u256);
    stop_cheat_caller_address(erc20_contract);

    start_cheat_caller_address(erc20_contract, MARKETPLACE());
    // approve the contract to spend maximum amount
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20_contract);

    (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    )
}

// Helper function to create test data
fn create_test_creators_data() -> (Span<ContractAddress>, Span<u256>, Span<u256>) {
    let creators = array![
        deploy_erc1155_receiver(), deploy_erc1155_receiver(), deploy_erc1155_receiver(),
    ]
        .span();

    let ownership_percentages = array![50_u256, 30_u256, 20_u256].span(); // 50%, 30%, 20%
    let governance_weights = array![40_u256, 35_u256, 25_u256].span(); // Different from ownership

    (creators, ownership_percentages, governance_weights)
}

fn register_test_asset(
    contract_address: ContractAddress,
    asset_dispatcher: IIPAssetManagerDispatcher,
    owner: ContractAddress,
) -> (u256, Span<ContractAddress>, Span<u256>, Span<u256>) {
    let asset_type = 'ART';
    let metadata_uri: ByteArray = "ipfs://QmTestArt";
    let creators = array![
        deploy_erc1155_receiver(), deploy_erc1155_receiver(), deploy_erc1155_receiver(),
    ]
        .span();
    let ownership_percentages = array![50_u256, 30_u256, 20_u256].span(); // 50%, 30%, 20%
    let governance_weights = array![40_u256, 35_u256, 25_u256].span();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    (asset_id, creators, ownership_percentages, governance_weights)
}

#[test]
fn test_register_ip_asset_success() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();

    let asset_type = 'ART'; // felt252 representation of IPAssetType::Art
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);

    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri.clone(), creators, ownership_percentages, governance_weights,
        );

    stop_cheat_caller_address(contract_address);

    // Verify asset registration
    assert(asset_id == 1, 'Asset ID should be 1');

    let asset_info = asset_dispatcher.get_asset_info(asset_id);
    assert(asset_info.asset_id == asset_id, 'Wrong asset ID in info');
    assert(asset_info.asset_type == asset_type, 'Wrong asset type');
    assert(asset_info.metadata_uri == metadata_uri, 'Wrong metadata URI');
    assert(asset_info.total_supply == 1000, 'Wrong total supply');
    assert!(asset_info.is_verified == false, "Should not be verified initially");

    // Verify ownership registration
    let ownership_info = ownership_dispatcher.get_ownership_info(asset_id);
    assert(ownership_info.total_owners == 3, 'Wrong number of owners');
    assert(ownership_info.is_active == true, 'Ownership should be active');

    // Verify individual ownership percentages
    assert(
        ownership_dispatcher.get_owner_percentage(asset_id, creator1) == 50,
        'Wrong CREATOR1 percentage',
    );
    assert(
        ownership_dispatcher.get_owner_percentage(asset_id, creator2) == 30,
        'Wrong CREATOR2 percentage',
    );
    assert(
        ownership_dispatcher.get_owner_percentage(asset_id, creator3) == 20,
        'Wrong CREATOR3 percentage',
    );

    // Verify governance weights
    assert!(
        ownership_dispatcher.get_governance_weight(asset_id, creator1) == 40,
        "Wrong CREATOR1 governance weight",
    );
    assert!(
        ownership_dispatcher.get_governance_weight(asset_id, creator2) == 35,
        "Wrong CREATOR2 governance weight",
    );
    assert!(
        ownership_dispatcher.get_governance_weight(asset_id, creator3) == 25,
        "Wrong CREATOR3 governance weight",
    );
}

#[test]
fn test_erc1155_token_minting() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let asset_type = 'MUSIC';
    let metadata_uri: ByteArray = "ipfs://QmMusicMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);

    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );

    stop_cheat_caller_address(contract_address);

    // Verify ERC1155 tokens were minted according to ownership percentages
    let creator1_balance = erc1155_dispatcher.balance_of(creator1, asset_id);
    let creator2_balance = erc1155_dispatcher.balance_of(creator2, asset_id);
    let creator3_balance = erc1155_dispatcher.balance_of(creator3, asset_id);

    assert(creator1_balance == 500, 'Wrong CREATOR1 token balance'); // 50% of 1000
    assert(creator2_balance == 300, 'Wrong CREATOR2 token balance'); // 30% of 1000
    assert(creator3_balance == 200, 'Wrong CREATOR3 token balance'); // 20% of 1000

    // Verify total supply
    assert(asset_dispatcher.get_total_supply(asset_id) == 1000, 'Wrong total supply');
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_register_ip_asset_when_paused() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let owner: ContractAddress = owner_address;
    start_cheat_caller_address(contract_address, owner);

    // Pause the contract
    asset_dispatcher.pause_contract();

    let asset_type = 'ART';
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let user: ContractAddress = USER();

    asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
}

#[test]
#[should_panic(expected: "At least one creator required")]
fn test_register_ip_asset_no_creators() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let asset_type = 'ART';
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let empty_creators = array![].span();
    let empty_percentages = array![].span();
    let empty_weights = array![].span();

    start_cheat_caller_address(contract_address, OWNER());

    asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, empty_creators, empty_percentages, empty_weights,
        );
}

#[test]
#[should_panic(expected: "Creators and percentages length mismatch")]
fn test_register_ip_asset_mismatched_arrays() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let asset_type = 'ART';
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let creators = array![CREATOR1(), CREATOR2()].span();
    let ownership_percentages = array![100_u256].span(); // Mismatch: 2 creators, 1 percentage
    let governance_weights = array![100_u256, 0_u256].span();

    start_cheat_caller_address(contract_address, OWNER());

    asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
}

#[test]
#[should_panic(expected: "Total ownership must equal 100%")]
fn test_register_ip_asset_invalid_percentages() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let asset_type = 'ART';
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let creators = array![CREATOR1(), CREATOR2()].span();
    let ownership_percentages = array![60_u256, 30_u256].span(); // Total = 90%, not 100%
    let governance_weights = array![50_u256, 50_u256].span();

    start_cheat_caller_address(contract_address, OWNER());

    asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
}

#[test]
fn test_ownership_transfer() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup(); // Register asset first
    let asset_type = 'ART';
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );

    stop_cheat_caller_address(contract_address);

    // Transfer 10% from CREATOR1 to USER
    let transfer_percentage = 10_u256;

    start_cheat_caller_address(contract_address, creator1);
    let success = ownership_dispatcher
        .transfer_ownership_share(asset_id, creator1, user, transfer_percentage);
    stop_cheat_caller_address(contract_address);

    assert(success == true, 'Transfer should succeed');

    // Verify new ownership percentages
    assert!(
        ownership_dispatcher.get_owner_percentage(asset_id, creator1) == 40,
        "CREATOR1 should have 40% after transfer",
    );
    assert!(
        ownership_dispatcher.get_owner_percentage(asset_id, user) == 10,
        "USER should have 10% after transfer",
    );

    // Verify governance weights transferred proportionally
    let expected_governance_weight = (40 * 10)
        / 50; // (original_weight * percentage) / original_percentage
    assert!(
        ownership_dispatcher.get_governance_weight(asset_id, user) == expected_governance_weight,
        "Wrong governance weight after transfer",
    );
}

#[test]
#[should_panic(expected: "Only owner can transfer their share")]
fn test_ownership_transfer_unauthorized() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = 'ART';
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // Try to transfer CREATOR1's share as USER (unauthorized)
    start_cheat_caller_address(contract_address, USER());
    ownership_dispatcher.transfer_ownership_share(asset_id, creator1, user, 10_u256);
}

#[test]
#[should_panic(expected: "Insufficient ownership share")]
fn test_ownership_transfer_insufficient_share() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = 'ART';
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // Try to transfer more than owned (CREATOR3 has 20%, trying to transfer 25%)
    start_cheat_caller_address(contract_address, creator3);
    ownership_dispatcher.transfer_ownership_share(asset_id, creator3, user, 25_u256);
}

#[test]
fn test_update_metadata() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = 'ART';
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // Update metadata as one of the owners (CREATOR1)
    let new_metadata_uri: ByteArray = "ipfs://QmUpdatedMetadata";

    start_cheat_caller_address(contract_address, creator1);
    let success = asset_dispatcher.update_asset_metadata(asset_id, new_metadata_uri.clone());
    stop_cheat_caller_address(contract_address);

    assert(success == true, 'Metadata update should succeed');

    // Verify metadata was updated
    let asset_info = asset_dispatcher.get_asset_info(asset_id);
    assert(asset_info.metadata_uri == new_metadata_uri, 'Metadata should be updated');

    // Verify URI getter
    let uri = asset_dispatcher.get_asset_uri(asset_id);
    assert!(uri == new_metadata_uri, "URI getter should return updated metadata");
}

#[test]
#[should_panic(expected: "Only owners can update metadata")]
fn test_update_metadata_unauthorized() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = 'ART';
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // Try to update metadata as non-owner
    let new_metadata_uri: ByteArray = "ipfs://QmUpdatedMetadata";

    start_cheat_caller_address(contract_address, user);
    asset_dispatcher.update_asset_metadata(asset_id, new_metadata_uri);
}

#[test]
fn test_mint_additional_tokens() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = 'ART';
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    let initial_supply = asset_dispatcher.get_total_supply(asset_id);
    let mint_amount = 500_u256;

    // Mint additional tokens as an owner (CREATOR1)
    start_cheat_caller_address(contract_address, creator1);
    let success = asset_dispatcher.mint_additional_tokens(asset_id, user, mint_amount);
    stop_cheat_caller_address(contract_address);

    assert(success == true, 'Minting should succeed');

    // Verify total supply increased
    let new_supply = asset_dispatcher.get_total_supply(asset_id);
    assert(new_supply == initial_supply + mint_amount, 'Total supply should increase');

    // Verify user received the tokens
    let user_balance = erc1155_dispatcher.balance_of(user, asset_id);
    assert!(user_balance == mint_amount, "User should receive minted tokens");
}

#[test]
#[should_panic(expected: "Only owners can mint tokens")]
fn test_mint_additional_tokens_unauthorized() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = 'ART';
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // Try to mint as non-owner
    start_cheat_caller_address(contract_address, user);
    asset_dispatcher.mint_additional_tokens(asset_id, user, 500_u256);
}

#[test]
fn test_access_control_functions() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = 'ART';
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // Test is_owner function
    assert(ownership_dispatcher.is_owner(asset_id, creator1) == true, 'CREATOR1 should be owner');
    assert(ownership_dispatcher.is_owner(asset_id, creator2) == true, 'CREATOR2 should be owner');
    assert(ownership_dispatcher.is_owner(asset_id, user) == false, 'USER should not be owner');

    // Test has_governance_rights function
    assert!(
        ownership_dispatcher.has_governance_rights(asset_id, creator1) == true,
        "CREATOR1 should have governance rights",
    );
    assert!(
        ownership_dispatcher.has_governance_rights(asset_id, user) == false,
        "USER should not have governance rights",
    );
}

// TODO: Fix test
#[test]
fn test_verify_asset_ownership() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = 'ART';
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // Verify ownership verification returns true for registered asset
    assert!(
        asset_dispatcher.verify_asset_ownership(asset_id) == true,
        "Asset ownership should be verified",
    );

    assert!(
        asset_dispatcher.verify_asset_ownership(asset_id) == true,
        "Asset ownership should be verified",
    );

    // Test with non-existent asset
    assert!(
        asset_dispatcher.verify_asset_ownership(50_u256) == false,
        "Non-existent asset should not be verified",
    );
}

#[test]
fn test_multiple_asset_registration() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);

    // Register multiple assets
    let asset_id_1 = asset_dispatcher
        .register_ip_asset(
            'ART', "ipfs://QmArt", creators, ownership_percentages, governance_weights,
        );

    let asset_id_2 = asset_dispatcher
        .register_ip_asset(
            'MUSIC', "ipfs://QmMusic", creators, ownership_percentages, governance_weights,
        );

    let asset_id_3 = asset_dispatcher
        .register_ip_asset(
            'LITERATURE',
            "ipfs://QmLiterature",
            creators,
            ownership_percentages,
            governance_weights,
        );

    stop_cheat_caller_address(contract_address);

    // Verify sequential asset IDs
    assert(asset_id_1 == 1, 'First asset should have ID 1');
    assert(asset_id_2 == 2, 'Second asset should have ID 2');
    assert(asset_id_3 == 3, 'Third asset should have ID 3');

    // Verify each asset has correct data
    let asset_info_1 = asset_dispatcher.get_asset_info(asset_id_1);
    let asset_info_2 = asset_dispatcher.get_asset_info(asset_id_2);
    let asset_info_3 = asset_dispatcher.get_asset_info(asset_id_3);

    assert(asset_info_1.asset_type == 'ART', 'Wrong asset type for asset 1');
    assert(asset_info_2.asset_type == 'MUSIC', 'Wrong asset type for asset 2');
    assert(asset_info_3.asset_type == 'LITERATURE', 'Wrong asset type for asset 3');
}

/////////////////////////////////
/// REVENUE DISTRIBUTION TESTS //
/// /////////////////////////////

#[test]
fn test_receive_revenue_success() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let licensee = SPENDER();

    // Register test asset
    let (asset_id, _, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );

    // Receive revenue
    let revenue_amount = 1000_u256;

    start_cheat_caller_address(contract_address, licensee);
    let success = revenue_dispatcher
        .receive_revenue(asset_id, erc20_dispatcher.contract_address, revenue_amount);
    stop_cheat_caller_address(contract_address);

    assert!(success == true, "Revenue receiving should succeed");

    // Verify accumulated revenue
    let accumulated = revenue_dispatcher
        .get_accumulated_revenue(asset_id, erc20_dispatcher.contract_address);
    assert!(accumulated == revenue_amount, "Wrong accumulated revenue");
}

#[test]
fn test_multiple_revenue_receipts() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let licensee = SPENDER();
    let marketplace = MARKETPLACE();
    let erc20 = erc20_dispatcher.contract_address;

    // Register test asset
    let (asset_id, _, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );

    // Multiple revenue receipts from different sources
    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 500_u256);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, marketplace);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 300_u256);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 200_u256);
    stop_cheat_caller_address(contract_address);

    // Verify total accumulated revenue
    let accumulated = revenue_dispatcher.get_accumulated_revenue(asset_id, erc20);
    assert!(accumulated == 1000, "Should accumulate all revenue");
}

#[test]
fn test_distribute_revenue_success() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let licensee = SPENDER();
    let erc20 = erc20_dispatcher.contract_address;

    // Register test asset and receive revenue
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];

    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 1000_u256);
    stop_cheat_caller_address(contract_address);

    // Distribute revenue as CREATOR1
    start_cheat_caller_address(contract_address, creator1);
    let success = revenue_dispatcher.distribute_revenue(asset_id, erc20, 800_u256);
    stop_cheat_caller_address(contract_address);

    assert!(success == true, "Revenue distribution should succeed");

    // Verify pending revenue for each owner
    let creator1_pending = revenue_dispatcher.get_pending_revenue(asset_id, creator1, erc20);
    let creator2_pending = revenue_dispatcher.get_pending_revenue(asset_id, creator2, erc20);
    let creator3_pending = revenue_dispatcher.get_pending_revenue(asset_id, creator3, erc20);

    assert!(creator1_pending == 400, "CREATOR1 should have 400 pending"); // 50% of 800
    assert!(creator2_pending == 240, "CREATOR2 should have 240 pending"); // 30% of 800
    assert!(creator3_pending == 160, "CREATOR3 should have 160 pending"); // 20% of 800

    // Verify remaining accumulated revenue
    let remaining_accumulated = revenue_dispatcher.get_accumulated_revenue(asset_id, erc20);
    assert!(remaining_accumulated == 200, "Should have 200 remaining"); // 1000 - 800

    // Verify total distributed
    let total_distributed = revenue_dispatcher.get_total_revenue_distributed(asset_id, erc20);
    assert!(total_distributed == 800, "Total distributed should be 800");
}

#[test]
fn test_distribute_all_revenue() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let licensee = SPENDER();
    let erc20 = erc20_dispatcher.contract_address;

    // Register test asset and receive revenue
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];

    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 1500_u256);
    stop_cheat_caller_address(contract_address);

    // Distribute all accumulated revenue
    start_cheat_caller_address(contract_address, creator2);
    let success = revenue_dispatcher.distribute_all_revenue(asset_id, erc20);
    stop_cheat_caller_address(contract_address);

    assert!(success == true, "Distribute all should succeed");

    // Verify all revenue was distributed
    let remaining_accumulated = revenue_dispatcher.get_accumulated_revenue(asset_id, erc20);
    assert!(remaining_accumulated == 0, "Should have no remaining revenue");

    // Verify pending amounts
    let creator1_pending = revenue_dispatcher.get_pending_revenue(asset_id, creator1, erc20);
    assert!(creator1_pending == 750, "CREATOR1 should have 750 pending"); // 50% of 1500
}

#[test]
fn test_withdraw_pending_revenue() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let licensee = SPENDER();
    let erc20 = erc20_dispatcher.contract_address;

    // Register test asset, receive and distribute revenue
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1: ContractAddress = *creators[0];

    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 1000_u256);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator1);
    revenue_dispatcher.distribute_all_revenue(asset_id, erc20);
    stop_cheat_caller_address(contract_address);

    // Withdraw as CREATOR1
    start_cheat_caller_address(contract_address, creator1);
    let withdrawn_amount = revenue_dispatcher.withdraw_pending_revenue(asset_id, erc20);
    stop_cheat_caller_address(contract_address);

    assert(withdrawn_amount == 500, 'Should withdraw 500'); // 50% of 1000

    // Verify pending revenue is now zero
    let creator1_pending = revenue_dispatcher.get_pending_revenue(asset_id, creator1, erc20);
    assert!(creator1_pending == 0, "Pending should be zero after withdrawal");

    // Verify total earned tracking
    let creator1_total_earned = revenue_dispatcher
        .get_owner_total_earned(asset_id, creator1, erc20);
    assert!(creator1_total_earned == 500, "Total earned should be 500");
}

// TODO: Fix test
#[test]
#[should_panic(expected: ('Invalid asset ID',))]
fn test_receive_revenue_invalid_asset() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let licensee = SPENDER();
    let erc20 = erc20_dispatcher.contract_address;

    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(999_u256, erc20, 1000_u256); // Non-existent asset
}

#[test]
#[should_panic(expected: "Amount must be greater than zero")]
fn test_receive_revenue_zero_amount() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let licensee = SPENDER();
    let erc20 = erc20_dispatcher.contract_address;

    let (asset_id, _, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );

    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 0_u256);
}

#[test]
#[should_panic(expected: "Only owners can distribute revenue")]
fn test_distribute_revenue_not_owner() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let licensee = SPENDER();
    let erc20 = erc20_dispatcher.contract_address;
    let non_owner = contract_address_const::<0x888>();

    // Register test asset and receive revenue
    let (asset_id, _, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );

    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 1000_u256);
    stop_cheat_caller_address(contract_address);

    // Try to distribute as non-owner
    start_cheat_caller_address(contract_address, non_owner);
    revenue_dispatcher.distribute_revenue(asset_id, erc20, 500_u256);
}

#[test]
#[should_panic(expected: "Insufficient accumulated revenue")]
fn test_distribute_revenue_insufficient_accumulated() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let licensee = SPENDER();
    let erc20 = erc20_dispatcher.contract_address;

    // Register test asset and receive small amount
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1: ContractAddress = *creators[0];

    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 500_u256);
    stop_cheat_caller_address(contract_address);

    // Try to distribute more than accumulated
    start_cheat_caller_address(contract_address, creator1);
    revenue_dispatcher.distribute_revenue(asset_id, erc20, 1000_u256);
}

#[test]
#[should_panic(expected: ('Not an asset owner',))]
fn test_withdraw_not_owner() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let licensee = SPENDER();
    let erc20 = erc20_dispatcher.contract_address;
    let non_owner = contract_address_const::<0x888>();

    // Register test asset, receive and distribute revenue
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1: ContractAddress = *creators[0];

    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 1000_u256);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator1);
    revenue_dispatcher.distribute_all_revenue(asset_id, erc20);
    stop_cheat_caller_address(contract_address);

    // Try to withdraw as non-owner
    start_cheat_caller_address(contract_address, non_owner);
    revenue_dispatcher.withdraw_pending_revenue(asset_id, erc20);
}

#[test]
#[should_panic(expected: "No pending revenue")]
fn test_withdraw_no_pending_revenue() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();

    // Register test asset (no revenue received/distributed)
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1: ContractAddress = *creators[0];

    let erc20 = erc20_dispatcher.contract_address;
    // Try to withdraw without any pending revenue
    start_cheat_caller_address(contract_address, creator1);
    revenue_dispatcher.withdraw_pending_revenue(asset_id, erc20);
}

#[test]
fn test_minimum_distribution() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let licensee = SPENDER();
    let erc20 = erc20_dispatcher.contract_address;

    // Register test asset
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1: ContractAddress = *creators[0];

    // Set minimum distribution
    start_cheat_caller_address(contract_address, creator1);
    let success = revenue_dispatcher.set_minimum_distribution(asset_id, 100_u256, erc20);
    stop_cheat_caller_address(contract_address);

    assert!(success == true, "Should set minimum distribution");

    // Verify minimum was set
    let min_amount = revenue_dispatcher.get_minimum_distribution(asset_id, erc20);
    assert!(min_amount == 100, "Wrong minimum distribution");

    // Receive revenue
    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 1000_u256);
    stop_cheat_caller_address(contract_address);

    // Try to distribute amount equal to minimum (should succeed)
    start_cheat_caller_address(contract_address, creator1);
    let distribute_success = revenue_dispatcher.distribute_revenue(asset_id, erc20, 100_u256);
    stop_cheat_caller_address(contract_address);

    assert!(distribute_success == true, "Should distribute minimum amount");
}

#[test]
#[should_panic(expected: "Amount below minimum distribution")]
fn test_distribute_below_minimum() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let licensee = SPENDER();
    let erc20 = erc20_dispatcher.contract_address;

    // Register test asset and set minimum
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1: ContractAddress = *creators[0];

    start_cheat_caller_address(contract_address, creator1);
    revenue_dispatcher.set_minimum_distribution(asset_id, 500_u256, erc20);
    stop_cheat_caller_address(contract_address);

    // Receive revenue
    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 1000_u256);
    stop_cheat_caller_address(contract_address);

    // Try to distribute below minimum
    start_cheat_caller_address(contract_address, creator1);
    revenue_dispatcher.distribute_revenue(asset_id, erc20, 300_u256); // Below 500
}

#[test]
fn test_revenue_flow_with_ownership_transfer() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let licensee = SPENDER();
    let erc20 = erc20_dispatcher.contract_address;
    let new_owner = USER();

    // Register test asset
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1: ContractAddress = *creators[0];

    // Initial revenue receipt and distribution
    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 1000_u256);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator1);
    revenue_dispatcher.distribute_all_revenue(asset_id, erc20);
    stop_cheat_caller_address(contract_address);

    // CREATOR1 transfers 20% to new_owner
    start_cheat_caller_address(contract_address, creator1);
    ownership_dispatcher.transfer_ownership_share(asset_id, creator1, new_owner, 20_u256);
    stop_cheat_caller_address(contract_address);

    // New revenue after ownership change
    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 2000_u256);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator1);
    revenue_dispatcher.distribute_all_revenue(asset_id, erc20);
    stop_cheat_caller_address(contract_address);

    // Verify pending revenue reflects new ownership structure
    // CREATOR1 now has 30% (was 50%, transferred 20%)
    let creator1_pending = revenue_dispatcher.get_pending_revenue(asset_id, creator1, erc20);
    // Should be 500 (from first distribution) + 600 (30% of 2000) = 1100
    assert!(creator1_pending == 1100, "CREATOR1 should have 1100 pending");

    // new_owner should have 20% of second distribution = 400
    let new_owner_pending = revenue_dispatcher.get_pending_revenue(asset_id, new_owner, erc20);

    assert!(new_owner_pending == 400, "New owner should have 400 pending");
}

#[test]
fn test_partial_distributions_and_withdrawals() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    let licensee = SPENDER();
    let erc20 = erc20_dispatcher.contract_address;

    // Register test asset
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];

    // Receive revenue in chunks
    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 1000_u256);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 500_u256);
    stop_cheat_caller_address(contract_address);

    // Partial distribution
    start_cheat_caller_address(contract_address, creator1);
    revenue_dispatcher.distribute_revenue(asset_id, erc20, 800_u256);
    stop_cheat_caller_address(contract_address);

    // CREATOR1 withdraws
    start_cheat_caller_address(contract_address, creator1);
    let first_withdrawal = revenue_dispatcher.withdraw_pending_revenue(asset_id, erc20);
    stop_cheat_caller_address(contract_address);

    assert!(first_withdrawal == 400, "First withdrawal should be 400"); // 50% of 800

    // Distribute remaining revenue
    start_cheat_caller_address(contract_address, creator2);
    revenue_dispatcher.distribute_all_revenue(asset_id, erc20); // Distribute remaining 700
    stop_cheat_caller_address(contract_address);

    // CREATOR1 withdraws again
    start_cheat_caller_address(contract_address, creator1);
    let second_withdrawal = revenue_dispatcher.withdraw_pending_revenue(asset_id, erc20);
    stop_cheat_caller_address(contract_address);

    assert!(second_withdrawal == 350, "Second withdrawal should be 350"); // 50% of 700

    // Verify total earned
    let creator1_total_earned = revenue_dispatcher
        .get_owner_total_earned(asset_id, creator1, erc20);
    assert!(creator1_total_earned == 750, "Total earned should be 750"); // 400 + 350
}

#[test]
fn test_complete_revenue_cycle() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();
    setup();
    let licensee = SPENDER();
    let marketplace = MARKETPLACE();
    let erc20 = erc20_dispatcher.contract_address;

    // Register test asset
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];

    // Step 1: Multiple revenue sources
    start_cheat_caller_address(contract_address, licensee);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 600_u256);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, marketplace);
    revenue_dispatcher.receive_revenue(asset_id, erc20, 400_u256);
    stop_cheat_caller_address(contract_address);

    // Step 2: Owner-controlled distribution
    start_cheat_caller_address(contract_address, creator1);
    revenue_dispatcher.distribute_all_revenue(asset_id, erc20);
    stop_cheat_caller_address(contract_address);

    // Step 3: All owners withdraw
    start_cheat_caller_address(contract_address, creator1);
    let creator1_withdrawn = revenue_dispatcher.withdraw_pending_revenue(asset_id, erc20);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator2);
    let creator2_withdrawn = revenue_dispatcher.withdraw_pending_revenue(asset_id, erc20);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, creator3);
    let creator3_withdrawn = revenue_dispatcher.withdraw_pending_revenue(asset_id, erc20);
    stop_cheat_caller_address(contract_address);

    // Verify complete cycle
    assert!(creator1_withdrawn == 500, "CREATOR1 should withdraw 500"); // 50% of 1000
    assert!(creator2_withdrawn == 300, "CREATOR2 should withdraw 300"); // 30% of 1000
    assert!(creator3_withdrawn == 200, "CREATOR3 should withdraw 200"); // 20% of 1000

    // Verify no pending revenue remains
    let total_pending = revenue_dispatcher.get_pending_revenue(asset_id, creator1, erc20)
        + revenue_dispatcher.get_pending_revenue(asset_id, creator2, erc20)
        + revenue_dispatcher.get_pending_revenue(asset_id, creator3, erc20);
    assert!(total_pending == 0, "Should have no pending revenue");

    // Verify total distributed
    let total_distributed = revenue_dispatcher.get_total_revenue_distributed(asset_id, erc20);
    assert!(total_distributed == 1000, "Total distributed should be 1000");
}
