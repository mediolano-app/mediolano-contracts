use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address,
};
use ip_revenue_sharing::IPRevenueSharing::{
    IIPRevenueSharingDispatcher, IIPRevenueSharingDispatcherTrait,
};
use ip_revenue_sharing::MockERC721::{IMockErc721Dispatcher, IMockErc721DispatcherTrait};

// Test constants
fn owner() -> ContractAddress {
    starknet::contract_address_const::<0x123456789>()
}

fn alex() -> ContractAddress {
    starknet::contract_address_const::<0x987654321>()
}

fn brenda() -> ContractAddress {
    starknet::contract_address_const::<0x1122334455>()
}

// Deploy Mock ERC721 Contract
fn deploy_mock_erc721() -> ContractAddress {
    let contract = declare("MockErc721").unwrap();
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append('https://example.com/'.into()); // Base URI
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

// Helper to mint an NFT to a specific address
fn mint_nft(nft_contract: ContractAddress, recipient: ContractAddress, token_id: u256) {
    let nft_dispatcher = IMockErc721Dispatcher { contract_address: nft_contract };
    start_cheat_caller_address(nft_contract, recipient);
    nft_dispatcher.mint(recipient, token_id);
    stop_cheat_caller_address(nft_contract);
}


// Deploy IPRevenueSharing
fn deploy_iprevenuesharing() -> ContractAddress {
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner().into());

    let contract = declare("IPRevenueSharing").unwrap();
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    contract_address
}

// Helper to create an IP asset
fn create_ip_asset(
    ipc: ContractAddress,
    nft_contract: ContractAddress,
    token_id: u256,
    metadata_hash: felt252,
    license_terms_hash: felt252,
    total_shares: u256,
) {
    let ipc_dispatcher = IIPRevenueSharingDispatcher { contract_address: ipc };
    start_cheat_caller_address(ipc, owner());
    ipc_dispatcher
        .create_ip_asset(nft_contract, token_id, metadata_hash, license_terms_hash, total_shares);
    stop_cheat_caller_address(ipc);
}

// Helper to list an IP asset
fn list_ip_asset(
    ipc: ContractAddress,
    nft_contract: ContractAddress,
    token_id: u256,
    price: u256,
    currency: ContractAddress,
) {
    let ipc_dispatcher = IIPRevenueSharingDispatcher { contract_address: ipc };
    start_cheat_caller_address(ipc, owner());
    ipc_dispatcher.list_ip_asset(nft_contract, token_id, price, currency);
    stop_cheat_caller_address(ipc);
}

#[test]
fn test_create_ip_asset() {
    let ipc = deploy_iprevenuesharing();
    let nft = deploy_mock_erc721();

    // Mint an NFT to the owner
    mint_nft(nft, owner(), 1.into());

    // Debug: Print the token ID
    let token_id: u256 = 1.into();
    println!("Token ID: {}", token_id);

    // Create IP asset
    create_ip_asset(ipc, nft, 1.into(), 'metadata_hash'.into(), 'license_terms'.into(), 100.into());

    // Verify the IP asset was created
    let ipc_dispatcher = IIPRevenueSharingDispatcher { contract_address: ipc };
    let shares = ipc_dispatcher.get_fractional_shares(1.into(), owner());
    assert(shares == 100.into(), 'Initial shares mismatch');
    let owner_count = ipc_dispatcher.get_fractional_owner_count(1.into());
    assert(owner_count == 1, 'Owner count mismatch');
    let first_owner = ipc_dispatcher.get_fractional_owner(1.into(), 0);
    assert(first_owner == owner(), 'Creator not first owner');
}
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


