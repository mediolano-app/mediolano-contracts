use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address,
};
use ip_revenue_sharing::IPRevenueSharing::{
    IIPRevenueSharingDispatcher, IIPRevenueSharingDispatcherTrait,
};
use ip_revenue_sharing::Mock721::{IMediolanoDispatcher, IMediolanoDispatcherTrait};

use ip_revenue_sharing::MockERC20;

use openzeppelin::token::erc721::interface::{
    IERC721Dispatcher, IERC721DispatcherTrait, IERC721MetadataDispatcher,
    IERC721MetadataDispatcherTrait,
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

// Test constants
fn owner() -> ContractAddress {
    starknet::contract_address_const::<'OWNER'>()
}

fn alex() -> ContractAddress {
    starknet::contract_address_const::<'ALEX'>()
}

fn bob() -> ContractAddress {
    starknet::contract_address_const::<'BOB'>()
}

// Deploy MockERC721 contract
fn deploy_mock_erc721(name: ByteArray) -> ContractAddress {
    let token_uri: ByteArray = "https://mediolano_uri.com";
    let mut calldata: Array<felt252> = ArrayTrait::new();
    token_uri.serialize(ref calldata);

    let contract = declare(name).unwrap();
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
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

    let contract = declare("MockERC20").unwrap();
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

// Deploy IPRevenueSharing contract
fn deploy_ip_revenue_sharing(owner: ContractAddress) -> ContractAddress {
    let contract = declare("IPRevenueSharing").unwrap();
    let mut calldata = array![owner.into()];
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

// Helper to mint an NFT
fn mint_nft(
    nft_contract: ContractAddress, caller: ContractAddress, to: ContractAddress, token_id: u256,
) {
    let dispatcher = IMediolanoDispatcher { contract_address: nft_contract };
    start_cheat_caller_address(nft_contract, caller);
    dispatcher.mint(to, token_id);
    stop_cheat_caller_address(nft_contract);
}

// Passing Tests (Unchanged)
#[test]
fn test_revenue_contract_deployed() {
    let owner = owner();
    let revenue_contract = deploy_ip_revenue_sharing(owner);
    let dispatcher = IIPRevenueSharingDispatcher { contract_address: revenue_contract };
    let contract_balance = dispatcher.get_contract_balance(revenue_contract);
    let zero_address = starknet::contract_address_const::<'0'>();
    assert(revenue_contract != zero_address, 'Revenue contract not deployed');
    assert(contract_balance == 0_u256, 'Contract balance is empty');
}

#[test]
fn test_create_ip_asset() {
    let owner = owner();
    let alex = alex();
    let nft_contract = deploy_mock_erc721("Mediolano");
    let revenue_contract = deploy_ip_revenue_sharing(owner);
    let dispatcher = IIPRevenueSharingDispatcher { contract_address: revenue_contract };
    let token_id: u256 = 1;
    mint_nft(nft_contract, owner, alex, token_id);
    let metadata_hash = 'metadata_hash'.try_into().unwrap();
    let license_terms_hash = 'license_terms'.try_into().unwrap();
    let total_shares: u256 = 100;
    start_cheat_caller_address(revenue_contract, alex);
    dispatcher
        .create_ip_asset(nft_contract, token_id, metadata_hash, license_terms_hash, total_shares);
    stop_cheat_caller_address(revenue_contract); // Added stop_cheat_caller_address
    let shares = dispatcher.get_fractional_shares(nft_contract, token_id, alex);
    assert(shares == total_shares, 'Shares mismatch');
    let owner_count = dispatcher.get_fractional_owner_count(nft_contract, token_id);
    assert(owner_count == 1, 'Owner count mismatch');
    let first_owner = dispatcher.get_fractional_owner(nft_contract, token_id, 0);
    assert(first_owner == alex, 'First owner mismatch');
}

// Corrected Failing Tests
#[test]
#[should_panic(expected: ('Not Token Owner',))]
fn test_create_ip_asset_not_owner() {
    let owner = owner();
    let alex = alex();
    let nft_contract = deploy_mock_erc721("Mediolano");
    let revenue_contract = deploy_ip_revenue_sharing(owner);
    let dispatcher = IIPRevenueSharingDispatcher { contract_address: revenue_contract };

    let token_id: u256 = 1;
    mint_nft(nft_contract, owner, owner, token_id); // Mint to owner, not alex

    let metadata_hash = 'metadata_hash'.try_into().unwrap();
    let license_terms_hash = 'license_terms'.try_into().unwrap();
    let total_shares: u256 = 100;

    start_cheat_caller_address(revenue_contract, alex);
    dispatcher
        .create_ip_asset(nft_contract, token_id, metadata_hash, license_terms_hash, total_shares);
    stop_cheat_caller_address(revenue_contract);
}

#[test]
fn test_list_ip_asset() {
    let owner = owner();
    let alex = alex();
    let nft_contract = deploy_mock_erc721("Mediolano");
    let revenue_contract = deploy_ip_revenue_sharing(owner);
    let erc20_contract = deploy_mock_erc20("TestToken", "TTK", 10000.into(), owner);
    let dispatcher = IIPRevenueSharingDispatcher { contract_address: revenue_contract };
    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_contract };

    let token_id: u256 = 1;
    mint_nft(nft_contract, owner, alex, token_id);
    start_cheat_caller_address(revenue_contract, alex);
    dispatcher
        .create_ip_asset(
            nft_contract,
            token_id,
            'metadata'.try_into().unwrap(),
            'license'.try_into().unwrap(),
            100.into(),
        );
    stop_cheat_caller_address(revenue_contract);

    start_cheat_caller_address(nft_contract, alex);
    nft_dispatcher.approve(revenue_contract, token_id);
    stop_cheat_caller_address(nft_contract);

    start_cheat_caller_address(revenue_contract, alex);
    dispatcher.list_ip_asset(nft_contract, token_id, 1000.into(), erc20_contract);
    stop_cheat_caller_address(revenue_contract);

    assert(nft_dispatcher.get_approved(token_id) == revenue_contract, 'Approval not set');
    assert(nft_dispatcher.owner_of(token_id) == alex, 'Ownership changed');
}

#[test]
#[should_panic(expected: ('Not approved for marketplace',))]
fn test_list_ip_asset_no_approval() {
    let owner = owner();
    let alex = alex();
    let nft_contract = deploy_mock_erc721("Mediolano");
    let revenue_contract = deploy_ip_revenue_sharing(owner);
    let erc20_contract = deploy_mock_erc20("TestToken", "TTK", 10000.into(), owner);
    let dispatcher = IIPRevenueSharingDispatcher { contract_address: revenue_contract };

    let token_id: u256 = 1;
    mint_nft(nft_contract, owner, alex, token_id);
    start_cheat_caller_address(revenue_contract, alex);
    dispatcher
        .create_ip_asset(
            nft_contract,
            token_id,
            'metadata'.try_into().unwrap(),
            'license'.try_into().unwrap(),
            100.into(),
        );
    stop_cheat_caller_address(revenue_contract);

    start_cheat_caller_address(revenue_contract, alex);
    dispatcher.list_ip_asset(nft_contract, token_id, 1000.into(), erc20_contract);
    stop_cheat_caller_address(revenue_contract);
}

#[test]
fn test_add_fractional_owner() {
    let owner = owner();
    let alex = alex();
    let bob = bob();
    let nft_contract = deploy_mock_erc721("Mediolano");
    let revenue_contract = deploy_ip_revenue_sharing(owner);
    let dispatcher = IIPRevenueSharingDispatcher { contract_address: revenue_contract };

    let token_id: u256 = 1;
    mint_nft(nft_contract, owner, alex, token_id);
    start_cheat_caller_address(revenue_contract, alex);
    dispatcher
        .create_ip_asset(
            nft_contract,
            token_id,
            'metadata'.try_into().unwrap(),
            'license'.try_into().unwrap(),
            100.into(),
        );
    stop_cheat_caller_address(revenue_contract);

    start_cheat_caller_address(revenue_contract, alex);
    dispatcher.add_fractional_owner(nft_contract, token_id, bob);
    stop_cheat_caller_address(revenue_contract);

    let owner_count = dispatcher.get_fractional_owner_count(nft_contract, token_id);
    assert(owner_count == 2, 'Owner count mismatch');
    let second_owner = dispatcher.get_fractional_owner(nft_contract, token_id, 1);
    assert(second_owner == bob, 'Bob not added');
}


#[test]
#[should_panic(expected: ('No revenue to claim',))]
fn test_claim_before_sale() {
    let owner = owner();
    let alex = alex();
    let bob = bob();
    let nft_contract = deploy_mock_erc721("Mediolano");
    let revenue_contract = deploy_ip_revenue_sharing(owner);
    let erc20_contract = deploy_mock_erc20("TestToken", "TTK", 10000.into(), owner);
    let ipc_dispatcher = IIPRevenueSharingDispatcher { contract_address: revenue_contract };
    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_contract };

    let token_id: u256 = 1;
    mint_nft(nft_contract, owner, alex, token_id);
    start_cheat_caller_address(revenue_contract, alex);
    ipc_dispatcher
        .create_ip_asset(
            nft_contract,
            token_id,
            'metadata'.try_into().unwrap(),
            'license'.try_into().unwrap(),
            100.into(),
        );
    stop_cheat_caller_address(revenue_contract);

    start_cheat_caller_address(nft_contract, alex);
    nft_dispatcher.approve(revenue_contract, token_id);
    stop_cheat_caller_address(nft_contract);

    start_cheat_caller_address(revenue_contract, alex);
    ipc_dispatcher.list_ip_asset(nft_contract, token_id, 1000.into(), erc20_contract);
    stop_cheat_caller_address(revenue_contract);

    start_cheat_caller_address(revenue_contract, alex);
    ipc_dispatcher.add_fractional_owner(nft_contract, token_id, bob);
    stop_cheat_caller_address(revenue_contract);
    start_cheat_caller_address(revenue_contract, alex);
    ipc_dispatcher.update_fractional_shares(nft_contract, token_id, bob, 50.into());
    stop_cheat_caller_address(revenue_contract);

    start_cheat_caller_address(revenue_contract, bob);
    ipc_dispatcher.claim_royalty(nft_contract, token_id);
    stop_cheat_caller_address(revenue_contract);
}

#[test]
fn test_full_flow_list_sell_claim() {
    let owner = owner();
    let alex = alex();
    let bob = bob();
    let nft_contract = deploy_mock_erc721("Mediolano");
    let revenue_contract = deploy_ip_revenue_sharing(owner);
    let erc20_contract = deploy_mock_erc20("TestToken", "TTK", 10000.into(), owner);
    let ipc_dispatcher = IIPRevenueSharingDispatcher { contract_address: revenue_contract };
    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_contract };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: erc20_contract };

    let token_id: u256 = 1;
    mint_nft(nft_contract, owner, alex, token_id);
    start_cheat_caller_address(revenue_contract, alex);
    ipc_dispatcher
        .create_ip_asset(
            nft_contract,
            token_id,
            'metadata'.try_into().unwrap(),
            'license'.try_into().unwrap(),
            100.into(),
        );
    stop_cheat_caller_address(revenue_contract);

    start_cheat_caller_address(nft_contract, alex);
    nft_dispatcher.approve(revenue_contract, token_id);
    stop_cheat_caller_address(nft_contract);

    start_cheat_caller_address(revenue_contract, alex);
    ipc_dispatcher.list_ip_asset(nft_contract, token_id, 1000.into(), erc20_contract);
    stop_cheat_caller_address(revenue_contract);

    start_cheat_caller_address(revenue_contract, alex);
    ipc_dispatcher.add_fractional_owner(nft_contract, token_id, bob);
    ipc_dispatcher.update_fractional_shares(nft_contract, token_id, bob, 50.into());
    stop_cheat_caller_address(revenue_contract);

    start_cheat_caller_address(erc20_contract, owner);
    erc20_dispatcher.approve(revenue_contract, 1000.into());
    stop_cheat_caller_address(erc20_contract);
    start_cheat_caller_address(erc20_contract, owner);
    erc20_dispatcher.transfer(revenue_contract, 1000.into());
    stop_cheat_caller_address(erc20_contract);
    start_cheat_caller_address(revenue_contract, owner);
    ipc_dispatcher.record_sale_revenue(nft_contract, token_id, 1000.into());
    stop_cheat_caller_address(revenue_contract);

    assert(
        erc20_dispatcher.balance_of(revenue_contract) == 1000.into(), 'Contract balance mismatch',
    );

    start_cheat_caller_address(revenue_contract, alex);
    ipc_dispatcher.claim_royalty(nft_contract, token_id);
    stop_cheat_caller_address(revenue_contract);
    let alex_claimed = ipc_dispatcher.get_claimed_revenue(nft_contract, token_id, alex);
    assert(alex_claimed == 500.into(), 'Alex claimed mismatch');

    start_cheat_caller_address(revenue_contract, bob);
    ipc_dispatcher.claim_royalty(nft_contract, token_id);
    stop_cheat_caller_address(revenue_contract);
    let bob_claimed = ipc_dispatcher.get_claimed_revenue(nft_contract, token_id, bob);
    assert(bob_claimed == 500.into(), 'Bob claimed mismatch');

    assert(erc20_dispatcher.balance_of(revenue_contract) == 0.into(), 'Final balance mismatch');
}
