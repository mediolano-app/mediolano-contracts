use starknet::{ContractAddress, get_caller_address, get_block_timestamp, testing};
use core::traits::Into;
use ip_ticket::{IPTicketService, IPTicketService::IPTicketService::Event as TicketEvent};
use ip_ticket::interface::{IIPTicketServiceDispatcherTrait, IIPTicketServiceDispatcher};
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait};
use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use snforge_std::{
    start_cheat_caller_address, stop_cheat_caller_address, spy_events, EventSpyAssertionsTrait,
};
use super::test_utils::{setup, OWNER, MINTER};



#[test]
fn test_create_ip_asset_success() {
    let (ticket_service, _, owner) = setup();
    let mut spy = spy_events();

    start_cheat_caller_address(ticket_service.contract_address, owner);
    let price: u256 = 100.into();
    let max_supply: u256 = 5.into();
    let expiration: u256 = 1000.into();
    let royalty_percentage: u256 = 500.into(); // 5%
    let metadata_uri: felt252 = 'ip://metadata';

    let ip_asset_id = ticket_service
        .create_ip_asset(price, max_supply, expiration, royalty_percentage, metadata_uri);
    stop_cheat_caller_address(ticket_service.contract_address);

    assert_eq!(ip_asset_id, 1.into(), "IP asset ID should be 1");
    spy
        .assert_emitted(
            @array![
                (
                    ticket_service.contract_address,
                    TicketEvent::IPAssetCreated(
                        IPTicketService::IPTicketService::IPAssetCreated {
                            ip_asset_id,
                            owner,
                            price,
                            max_supply,
                            expiration,
                            royalty_percentage,
                            metadata_uri,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_mint_ticket_success() {
    let (ticket_service, _, owner) = setup();
    let mut spy = spy_events();
    let minter = MINTER(); // Use MINTER from test_utils, already funded and approved

    // Create IP asset
    start_cheat_caller_address(ticket_service.contract_address, owner);
    let price: u256 = 100.into();
    let max_supply: u256 = 2.into();
    let expiration: u256 = 1000.into();
    let royalty_percentage: u256 = 500.into();
    let metadata_uri: felt252 = 'ip://metadata';
    let ip_asset_id = ticket_service
        .create_ip_asset(price, max_supply, expiration, royalty_percentage, metadata_uri);
    stop_cheat_caller_address(ticket_service.contract_address);

    // Mint ticket (MINTER is already funded and approved in setup)
    start_cheat_caller_address(ticket_service.contract_address, minter);
    ticket_service.mint_ticket(ip_asset_id);
    stop_cheat_caller_address(ticket_service.contract_address);

    // Verify ERC721 ownership and ticket validity
    let erc721 = IERC721Dispatcher { contract_address: ticket_service.contract_address };
    assert_eq!(erc721.owner_of(1.into()), minter, "Minter should own token 1");
    assert!(ticket_service.has_valid_ticket(minter, ip_asset_id), "Ticket should be valid");

    spy
        .assert_emitted(
            @array![
                (
                    ticket_service.contract_address,
                    TicketEvent::TicketMinted(
                        IPTicketService::IPTicketService::TicketMinted {
                            token_id: 1.into(), ip_asset_id, owner: minter,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: ('Max supply reached',))]
fn test_mint_ticket_exceeds_max_supply() {
    let (ticket_service, _, owner) = setup();
    let minter = MINTER(); // Already funded and approved

    // Create IP asset with max_supply = 1
    start_cheat_caller_address(ticket_service.contract_address, owner);
    let price: u256 = 100.into();
    let max_supply: u256 = 1.into();
    let expiration: u256 = 1000.into();
    let royalty_percentage: u256 = 500.into();
    let metadata_uri: felt252 = 'ip://metadata';
    let ip_asset_id = ticket_service
        .create_ip_asset(price, max_supply, expiration, royalty_percentage, metadata_uri);
    stop_cheat_caller_address(ticket_service.contract_address);

    // Mint first ticket (succeeds)
    start_cheat_caller_address(ticket_service.contract_address, minter);
    ticket_service.mint_ticket(ip_asset_id);
    // Mint second ticket (should fail)
    ticket_service.mint_ticket(ip_asset_id);
    stop_cheat_caller_address(ticket_service.contract_address);
}

#[test]
#[should_panic(expected: ('ERC20: insufficient allowance',))]
fn test_mint_ticket_insufficient_allowance() {
    let (ticket_service, erc20, owner) = setup();
    let minter = MINTER();

    // Create IP asset
    start_cheat_caller_address(ticket_service.contract_address, owner);
    let price: u256 = 100.into();
    let max_supply: u256 = 1.into();
    let expiration: u256 = 1000.into();
    let royalty_percentage: u256 = 500.into();
    let metadata_uri: felt252 = 'ip://metadata';
    let ip_asset_id = ticket_service
        .create_ip_asset(price, max_supply, expiration, royalty_percentage, metadata_uri);
    stop_cheat_caller_address(ticket_service.contract_address);

    // Revoke approval set by setup to simulate insufficient allowance
    start_cheat_caller_address(erc20.contract_address, minter);
    erc20.approve(ticket_service.contract_address, 0.into());
    stop_cheat_caller_address(erc20.contract_address);

    // Attempt to mint without approval
    start_cheat_caller_address(ticket_service.contract_address, minter);
    ticket_service.mint_ticket(ip_asset_id);
    stop_cheat_caller_address(ticket_service.contract_address);
}

#[test]
fn test_has_valid_ticket_expired() {
    let (ticket_service, _, owner) = setup();
    let minter = MINTER();

    // Create IP asset with past expiration
    start_cheat_caller_address(ticket_service.contract_address, owner);
    let price: u256 = 100.into();
    let max_supply: u256 = 1.into();
    let expiration: u256 = 500.into();
    let royalty_percentage: u256 = 500.into();
    let metadata_uri: felt252 = 'ip://metadata';
    let ip_asset_id = ticket_service
        .create_ip_asset(price, max_supply, expiration, royalty_percentage, metadata_uri);
    stop_cheat_caller_address(ticket_service.contract_address);

    // Mint ticket (MINTER is already funded and approved)
    start_cheat_caller_address(ticket_service.contract_address, minter);
    ticket_service.mint_ticket(ip_asset_id);
    stop_cheat_caller_address(ticket_service.contract_address);

    // Set block timestamp past expiration
    testing::set_block_timestamp(1000);

    assert!(!ticket_service.has_valid_ticket(minter, ip_asset_id), "Ticket should be expired");
}

#[test]
fn test_royalty_info() {
    let (ticket_service, _, owner) = setup();
    let minter = MINTER();

    // Create IP asset
    start_cheat_caller_address(ticket_service.contract_address, owner);
    let price: u256 = 100.into();
    let max_supply: u256 = 1.into();
    let expiration: u256 = 1000.into();
    let royalty_percentage: u256 = 500.into(); // 5%
    let metadata_uri: felt252 = 'ip://metadata';
    let ip_asset_id = ticket_service
        .create_ip_asset(price, max_supply, expiration, royalty_percentage, metadata_uri);
    stop_cheat_caller_address(ticket_service.contract_address);

    // Mint ticket (MINTER is already funded and approved)
    start_cheat_caller_address(ticket_service.contract_address, minter);
    ticket_service.mint_ticket(ip_asset_id);
    stop_cheat_caller_address(ticket_service.contract_address);

    // Check royalty info
    let sale_price: u256 = 1000.into();
    let (royalty_receiver, royalty_amount) = ticket_service.royaltyInfo(1.into(), sale_price);
    assert_eq!(royalty_receiver, owner, "Royalty receiver should be owner");
    assert_eq!(royalty_amount, 50.into(), "Royalty should be 5% of 1000"); // 1000 * 5% = 50
}

#[test]
fn test_multiple_ip_assets_and_tickets() {
    let (ticket_service, _, owner) = setup();
    let minter = MINTER();

    // Create two IP assets
    start_cheat_caller_address(ticket_service.contract_address, owner);
    let price1: u256 = 100.into();
    let price2: u256 = 200.into();
    let max_supply: u256 = 2.into();
    let expiration: u256 = 1000.into();
    let royalty_percentage: u256 = 500.into();
    let metadata_uri1: felt252 = 'ip://metadata1';
    let metadata_uri2: felt252 = 'ip://metadata2';

    let ip_asset_id1 = ticket_service
        .create_ip_asset(price1, max_supply, expiration, royalty_percentage, metadata_uri1);
    let ip_asset_id2 = ticket_service
        .create_ip_asset(price2, max_supply, expiration, royalty_percentage, metadata_uri2);
    stop_cheat_caller_address(ticket_service.contract_address);

    // Mint tickets for both IP assets (MINTER is already funded and approved)
    start_cheat_caller_address(ticket_service.contract_address, minter);
    ticket_service.mint_ticket(ip_asset_id1);
    ticket_service.mint_ticket(ip_asset_id2);
    stop_cheat_caller_address(ticket_service.contract_address);

    // Verify ownership and validity
    let erc721 = IERC721Dispatcher { contract_address: ticket_service.contract_address };
    assert_eq!(erc721.owner_of(1.into()), minter, "Minter should own token 1");
    assert_eq!(erc721.owner_of(2.into()), minter, "Minter should own token 2");
    assert!(ticket_service.has_valid_ticket(minter, ip_asset_id1), "Ticket 1 should be valid");
    assert!(ticket_service.has_valid_ticket(minter, ip_asset_id2), "Ticket 2 should be valid");
}
