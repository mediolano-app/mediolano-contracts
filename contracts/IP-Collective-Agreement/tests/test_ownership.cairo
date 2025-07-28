use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp,
    stop_cheat_block_timestamp,
};
use core::num::traits::Bounded;

use ip_collective_agreement::interface::{
    IOwnershipRegistryDispatcher, IOwnershipRegistryDispatcherTrait, IIPAssetManagerDispatcher,
    IIPAssetManagerDispatcherTrait, IRevenueDistributionDispatcher,
    IRevenueDistributionDispatcherTrait,
};

use super::test_utils::{USER, setup, register_test_asset};

#[test]
fn test_transfer_more_than_owned() {
    let (contract_address, ownership_dispatcher, asset_dispatcher, _, _, _, _, owner_address) =
        setup();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator3 = *creators[2]; // Has 20%
    let new_owner = USER();

    start_cheat_caller_address(contract_address, creator3);

    ownership_dispatcher
        .transfer_ownership_share(
            asset_id, creator3, new_owner, 25_u256,
        ); // Try to transfer 25% when only owning 20%

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_governance_weight_transfer_calculation() {
    let (contract_address, ownership_dispatcher, asset_dispatcher, _, _, _, _, owner_address) =
        setup();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0]; // 50% ownership, 40% governance
    let new_owner = USER();

    // Transfer 25% ownership (half of creator1's ownership)
    start_cheat_caller_address(contract_address, creator1);
    ownership_dispatcher.transfer_ownership_share(asset_id, creator1, new_owner, 25_u256);
    stop_cheat_caller_address(contract_address);

    // Check governance weights were transferred proportionally
    let creator1_new_gov = ownership_dispatcher.get_governance_weight(asset_id, creator1);
    let new_owner_gov = ownership_dispatcher.get_governance_weight(asset_id, new_owner);

    // Should transfer half of governance weight: 40 / 2 = 20
    assert!(creator1_new_gov == 20, "Creator1 should have 20 governance weight remaining");
    assert!(new_owner_gov == 20, "New owner should get 20 governance weight");
}

#[test]
fn test_transfer_to_existing_owner() {
    let (contract_address, ownership_dispatcher, asset_dispatcher, _, _, _, _, owner_address) =
        setup();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0]; // 50%
    let creator2 = *creators[1]; // 30%

    let initial_creator2_percentage = ownership_dispatcher.get_owner_percentage(asset_id, creator2);
    let initial_creator2_gov = ownership_dispatcher.get_governance_weight(asset_id, creator2);

    // Transfer from creator1 to creator2 (existing owner)
    start_cheat_caller_address(contract_address, creator1);
    ownership_dispatcher.transfer_ownership_share(asset_id, creator1, creator2, 10_u256);
    stop_cheat_caller_address(contract_address);

    // Check percentages updated correctly
    let new_creator1_percentage = ownership_dispatcher.get_owner_percentage(asset_id, creator1);
    let new_creator2_percentage = ownership_dispatcher.get_owner_percentage(asset_id, creator2);

    assert!(new_creator1_percentage == 40, "Creator1 should have 40% after transfer");
    assert!(new_creator2_percentage == 40, "Creator2 should have 40% after receiving transfer");

    // Governance weights should also update
    let new_creator2_gov = ownership_dispatcher.get_governance_weight(asset_id, creator2);
    // Creator2 should get additional governance proportional to ownership transferred
    // 10% ownership transfer from 50% should transfer (40 * 10) / 50 = 8 governance
    assert!(
        new_creator2_gov == initial_creator2_gov + 8,
        "Creator2 should get proportional governance weight",
    );
}
