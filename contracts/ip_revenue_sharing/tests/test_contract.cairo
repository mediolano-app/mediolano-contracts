use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address,
};
use ip_revenue_sharing::IPRevenueSharing::{
    IIPRevenueSharingDispatcher, IIPRevenueSharingDispatcherTrait,
};
use ip_revenue_sharing::MockERC721::{IMockERC721Dispatcher, IMockERC721DispatcherTrait};

// Test constants
fn owner() -> ContractAddress {
    starknet::contract_address_const::<'OWNER'>()
}

fn alex() -> ContractAddress {
    starknet::contract_address_const::<'ALEX'>()
}

// fn brenda() -> ContractAddress {
//     starknet::contract_address_const::<0x1122334455>()
// }

// Deploy MockERC721 contract
fn deploy_mock_erc721(owner: ContractAddress) -> ContractAddress {
    let contract = declare("MockERC721").unwrap();
    let mut calldata = array![owner.into()];
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    println!("mockerc721 deployed on: {:?}", contract_address);
    contract_address
}

// Deploy IPRevenueSharing contract
fn deploy_ip_revenue_sharing(owner: ContractAddress) -> ContractAddress {
    let contract = declare("IPRevenueSharing").unwrap();
    let mut calldata = array![owner.into()];
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    println!("ip_revenue_sharing deployed on: {:?}", contract_address);
    contract_address
}

// Helper to mint an NFT
fn mint_nft(
    nft_contract: ContractAddress, caller: ContractAddress, to: ContractAddress, token_id: u256
) {
    let dispatcher = IMockERC721Dispatcher { contract_address: nft_contract };
    start_cheat_caller_address(nft_contract, caller);
    dispatcher.mint(to, token_id);
    stop_cheat_caller_address(nft_contract);
}

// Helper to create an IP asset
fn create_ip_asset(
    ipc: ContractAddress,
    caller: ContractAddress,
    nft_contract: ContractAddress,
    token_id: u256,
    metadata_hash: felt252,
    license_terms_hash: felt252,
    total_shares: u256,
) {
    let dispatcher = IIPRevenueSharingDispatcher { contract_address: ipc };
    start_cheat_caller_address(ipc, caller);
    dispatcher
        .create_ip_asset(nft_contract, token_id, metadata_hash, license_terms_hash, total_shares);
    stop_cheat_caller_address(ipc);
}

#[test]
fn test_create_ip_asset() {
    // 1. Deploy contracts
    let owner = owner();
    let nft_contract = deploy_mock_erc721(owner);
    let ipc_contract = deploy_ip_revenue_sharing(owner);

    // 2. Mint an NFT to Alex as the owner
    let alex = alex();
    let token_id: u256 = 1;
    mint_nft(nft_contract, owner, alex, token_id);

    // Debug: Verify minting worked
    let nft_dispatcher = IMockERC721Dispatcher { contract_address: nft_contract };
    let nft_owner = nft_dispatcher.owner_of(token_id);
    assert(nft_owner == alex, 'NFT not minted to Alex');

    // 3. Create IP asset as Alex
    let metadata_hash = 'metadata_hash'.into();
    let license_terms_hash = 'license_terms'.into();
    let total_shares: u256 = 100;
    create_ip_asset(
        ipc_contract, alex, nft_contract, token_id, metadata_hash, license_terms_hash, total_shares
    );

    // 4. Verify IP asset creation
    let ipc_dispatcher = IIPRevenueSharingDispatcher { contract_address: ipc_contract };
    let shares = ipc_dispatcher.get_fractional_shares(token_id, alex);
    assert(shares == total_shares, 'Shares mismatch');
    let owner_count = ipc_dispatcher.get_fractional_owner_count(token_id);
    assert(owner_count == 1, 'Owner count mismatch');
    let first_owner = ipc_dispatcher.get_fractional_owner(token_id, 0);
    assert(first_owner == alex, 'First owner mismatch');
}
// Helper to list an IP asset
// fn list_ip_asset(
//     ipc: ContractAddress,
//     nft_contract: ContractAddress,
//     token_id: u256,
//     price: u256,
//     currency: ContractAddress,
// ) {
//     let ipc_dispatcher = IIPRevenueSharingDispatcher { contract_address: ipc };
//     start_cheat_caller_address(ipc, owner());
//     ipc_dispatcher.list_ip_asset(nft_contract, token_id, price, currency);
//     stop_cheat_caller_address(ipc);
// }

// #[test]
// fn test_add_fractional_owner() {
//     let ipc = deploy_iprevenuesharing();
//     let nft = nft_contract();

//     create_ip_asset(ipc, nft, 1.into(), 'metadata_hash'.into(), 'license_terms'.into(),
//     100.into());

//     let ipc_dispatcher = IIPRevenueSharingDispatcher { contract_address: ipc };
//     start_cheat_caller_address(ipc, owner());
//     ipc_dispatcher.add_fractional_owner(1.into(), alex());
//     stop_cheat_caller_address(ipc);

//     let owner_count = ipc_dispatcher.get_fractional_owner_count(1.into());
//     assert(owner_count == 2, 'Owner count mismatch');
//     let second_owner = ipc_dispatcher.get_fractional_owner(1.into(), 1);
//     assert(second_owner == alex(), 'alex not added');
// }

// #[test]
// fn test_full_flow_list_sell_claim() {
//     let ipc = deploy_iprevenuesharing();
//     let nft = nft_contract();
//     let currency = currency_contract();

//     // Create and list IP asset
//     create_ip_asset(ipc, nft, 1.into(), 'metadata_hash'.into(), 'license_terms'.into(),
//     100.into());
//     list_ip_asset(ipc, nft, 1.into(), 1000.into(), currency);

//     let ipc_dispatcher = IIPRevenueSharingDispatcher { contract_address: ipc };
//     start_cheat_caller_address(ipc, owner());
//     ipc_dispatcher.add_fractional_owner(1.into(), alex());
//     stop_cheat_caller_address(ipc);
//     start_cheat_caller_address(ipc, owner());
//     ipc_dispatcher.update_fractional_shares(1.into(), alex(), 50.into());
//     stop_cheat_caller_address(ipc);

//     // Simulate marketplace sale
//     start_cheat_caller_address(ipc, owner()); // Owner as proxy for marketplace
//     ipc_dispatcher.record_sale_revenue(nft, 1.into(), 1000.into());
//     stop_cheat_caller_address(ipc);

//     // Check contract balance increased
//     let balance_before_claim = ipc_dispatcher.get_contract_balance(currency);
//     assert(balance_before_claim == 1000.into(), 'balance mismatch');

//     // alex claims revenue
//     let alex_claimed_before = ipc_dispatcher.get_claimed_revenue(1.into(), alex());
//     assert(alex_claimed_before == 0.into(), 'claimed revenue should be 0');
//     start_cheat_caller_address(ipc, alex());
//     ipc_dispatcher.claim_royalty(1.into());
//     stop_cheat_caller_address(ipc);
//     let alex_claimed_after = ipc_dispatcher.get_claimed_revenue(1.into(), alex());
//     assert(alex_claimed_after == 500.into(), 'alex claimed revenue mismatch');
//     let balance_after_claim = ipc_dispatcher.get_contract_balance(currency);
//     assert(balance_after_claim == 500.into(), 'balance mismatch');
// }

// #[test]
// #[should_panic(expected: ('No revenue to claim',))]
// fn test_claim_before_sale() {
//     let ipc = deploy_iprevenuesharing();
//     let nft = nft_contract();
//     let currency = currency_contract();

//     create_ip_asset(ipc, nft, 1.into(), 'metadata_hash'.into(), 'license_terms'.into(),
//     100.into());
//     list_ip_asset(ipc, nft, 1.into(), 1000.into(), currency);

//     let ipc_dispatcher = IIPRevenueSharingDispatcher { contract_address: ipc };
//     start_cheat_caller_address(ipc, owner());
//     ipc_dispatcher.add_fractional_owner(1.into(), alex());
//     stop_cheat_caller_address(ipc);
//     start_cheat_caller_address(ipc, owner());
//     ipc_dispatcher.update_fractional_shares(1.into(), alex(), 50.into());
//     stop_cheat_caller_address(ipc);

//     // Try to claim before any sale
//     start_cheat_caller_address(ipc, alex());
//     ipc_dispatcher.claim_royalty(1.into());
//     stop_cheat_caller_address(ipc);
// }

// #[test]
// #[should_panic(expected: ('Not authorized',))]
// fn test_unauthorized_record_sale_revenue() {
//     let ipc = deploy_iprevenuesharing();
//     let nft = nft_contract();
//     let currency = currency_contract();

//     create_ip_asset(ipc, nft, 1.into(), 'metadata_hash'.into(), 'license_terms'.into(),
//     100.into());
//     list_ip_asset(ipc, nft, 1.into(), 1000.into(), currency);

//     let ipc_dispatcher = IIPRevenueSharingDispatcher { contract_address: ipc };
//     start_cheat_caller_address(ipc, alex()); // alex isn’t owner
//     ipc_dispatcher.record_sale_revenue(nft, 1.into(), 1000.into());
//     stop_cheat_caller_address(ipc);
// }


