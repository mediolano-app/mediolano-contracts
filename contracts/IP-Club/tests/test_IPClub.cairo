use crate::utils::*;
use ip_club::interfaces::IIPClub::IIPClubDispatcherTrait;
use ip_club::interfaces::IIPClubNFT::{IIPClubNFTDispatcher, IIPClubNFTDispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20DispatcherTrait};
use ip_club::types::ClubStatus;
use snforge_std::{cheat_caller_address, CheatSpan};

#[test]
fn test_create_club_successfully() {
    let TestContracts { ip_club, .. } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::None;
    let entry_fee = Option::None;
    let payment_token = Option::None;

    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );

    let club_id = ip_club.get_last_club_id();

    let club_record = ip_club.get_club_record(club_id);

    assert!(club_record.name == club_name, "Club name should match");
    assert!(club_record.symbol == club_symbol, "Club symbol should match");
    assert!(club_record.metadata_uri == metadata_uri, "Club metadata should match");
    assert!(club_record.max_members == Option::None, "Club config should match");
    assert!(club_record.entry_fee == Option::None, "Club config should match");
    assert!(club_record.payment_token == Option::None, "Club config should match");
    assert!(club_record.status == ClubStatus::Open, "Club status should be open");
}

#[test]
#[should_panic(expected: 'Max members cannot be zero')]
fn test_create_club_with_invalid_max_members() {
    let TestContracts { ip_club, .. } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::Some(0);
    let entry_fee = Option::None;
    let payment_token = Option::None;

    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );
}

#[test]
#[should_panic(expected: 'Invalid fee configuration')]
fn test_create_club_with_invalid_fee_configuration_type1() {
    // Passing Payment Token without Fee
    let TestContracts { ip_club, erc20_token } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::None;
    let entry_fee = Option::None;
    let payment_token = Option::Some(erc20_token.contract_address);

    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );
}


#[test]
#[should_panic(expected: 'Invalid fee configuration')]
fn test_create_club_with_invalid_fee_configuration_type2() {
    // Passing Fee without Payment Token
    let TestContracts { ip_club, .. } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::None;
    let entry_fee = Option::Some(1000);
    let payment_token = Option::None;

    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );
}


#[test]
#[should_panic(expected: 'Entry fee cannot be zero')]
fn test_create_club_with_zero_entry_fee() {
    let TestContracts { ip_club, erc20_token } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::None;
    let entry_fee = Option::Some(0);
    let payment_token = Option::Some(erc20_token.contract_address);

    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );
}

#[test]
#[should_panic(expected: 'Payment token cannot be null')]
fn test_create_club_with_invalid_payment_token() {
    let TestContracts { ip_club, .. } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::None;
    let entry_fee = Option::Some(1000);
    let payment_token = Option::Some(ZERO_ADDRESS());

    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );
}

#[test]
fn test_ip_club_nft_deployed_on_club_creation() {
    let TestContracts { ip_club, .. } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::None;
    let entry_fee = Option::None;
    let payment_token = Option::None;

    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );

    let club_id = ip_club.get_last_club_id();

    let club_record = ip_club.get_club_record(club_id);

    let ip_club_nft = IIPClubNFTDispatcher { contract_address: club_record.club_nft };
    let associated_club_id = ip_club_nft.get_associated_club_id();
    let ip_club_manager = ip_club_nft.get_ip_club_manager();

    assert!(associated_club_id == club_id, "club id should match");
    assert!(ip_club_manager == ip_club.contract_address, "club address should match");
}

#[test]
fn test_close_club_successfully() {
    let TestContracts { ip_club, .. } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::None;
    let entry_fee = Option::None;
    let payment_token = Option::None;

    cheat_caller_address(ip_club.contract_address, CREATOR(), CheatSpan::TargetCalls(1));
    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );

    let club_id = ip_club.get_last_club_id();

    cheat_caller_address(ip_club.contract_address, CREATOR(), CheatSpan::TargetCalls(1));
    ip_club.close_club(club_id);

    let club_record = ip_club.get_club_record(club_id);
    assert!(club_record.status == ClubStatus::Closed, "club status should be closed");
}

#[test]
#[should_panic(expected: 'Club not open')]
fn test_close_club_close_only_once() {
    let TestContracts { ip_club, .. } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::None;
    let entry_fee = Option::None;
    let payment_token = Option::None;

    cheat_caller_address(ip_club.contract_address, CREATOR(), CheatSpan::TargetCalls(1));
    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );

    let club_id = ip_club.get_last_club_id();

    cheat_caller_address(ip_club.contract_address, CREATOR(), CheatSpan::TargetCalls(1));
    ip_club.close_club(club_id);

    cheat_caller_address(ip_club.contract_address, CREATOR(), CheatSpan::TargetCalls(1));
    ip_club.close_club(club_id);
}

#[test]
#[should_panic(expected: 'Not Authorized')]
fn test_only_club_creator_can_close_club() {
    let TestContracts { ip_club, .. } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::None;
    let entry_fee = Option::None;
    let payment_token = Option::None;

    cheat_caller_address(ip_club.contract_address, CREATOR(), CheatSpan::TargetCalls(1));
    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );

    let club_id = ip_club.get_last_club_id();

    cheat_caller_address(ip_club.contract_address, USER1(), CheatSpan::TargetCalls(1));
    ip_club.close_club(club_id);
}


#[test]
fn test_join_club_successfully() {
    let TestContracts { ip_club, .. } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::None;
    let entry_fee = Option::None;
    let payment_token = Option::None;

    cheat_caller_address(ip_club.contract_address, CREATOR(), CheatSpan::TargetCalls(1));
    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );

    let club_id = ip_club.get_last_club_id();

    cheat_caller_address(ip_club.contract_address, USER1(), CheatSpan::TargetCalls(1));
    ip_club.join_club(club_id);

    let club_record = ip_club.get_club_record(club_id);

    assert!(club_record.num_members == 1, "first member should reflect");

    let is_member = ip_club.is_member(club_id, USER1());
    assert!(is_member, "should be a member");

    cheat_caller_address(ip_club.contract_address, USER2(), CheatSpan::TargetCalls(1));
    ip_club.join_club(club_id);

    let club_record = ip_club.get_club_record(club_id);

    assert!(club_record.num_members == 2, "second member should reflect");

    let is_member_2 = ip_club.is_member(club_id, USER2());
    assert!(is_member_2, "should be a member");
}

#[test]
fn test_join_club_mints_nft() {
    let TestContracts { ip_club, .. } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::None;
    let entry_fee = Option::None;
    let payment_token = Option::None;

    cheat_caller_address(ip_club.contract_address, CREATOR(), CheatSpan::TargetCalls(1));
    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );

    let club_id = ip_club.get_last_club_id();

    cheat_caller_address(ip_club.contract_address, USER1(), CheatSpan::TargetCalls(1));
    ip_club.join_club(club_id);

    let club_record = ip_club.get_club_record(club_id);

    let ip_club_nft = IIPClubNFTDispatcher { contract_address: club_record.club_nft };
    let last_minted_nft = ip_club_nft.get_last_minted_id();
    assert!(last_minted_nft == 1, "should be 1");
    let user_has_nft = ip_club_nft.has_nft(USER1());
    assert!(user_has_nft, "should have nft");
}

#[test]
fn test_join_club_with_entry_fee() {
    let TestContracts { ip_club, erc20_token } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::None;
    let entry_fee = Option::Some(1000);
    let payment_token = Option::Some(erc20_token.contract_address);

    cheat_caller_address(ip_club.contract_address, CREATOR(), CheatSpan::TargetCalls(1));
    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );

    let club_id = ip_club.get_last_club_id();

    mint_erc20(erc20_token.contract_address, USER1(), 3000);

    let user1_balance_before = erc20_token.balance_of(USER1());
    assert!(user1_balance_before == 3000, "balance should match");

    // Approve Tokens
    cheat_caller_address(erc20_token.contract_address, USER1(), CheatSpan::TargetCalls(1));
    erc20_token.approve(ip_club.contract_address, 1000);

    cheat_caller_address(ip_club.contract_address, USER1(), CheatSpan::TargetCalls(1));
    ip_club.join_club(club_id);

    let user1_balance = erc20_token.balance_of(USER1());
    let creator_balance = erc20_token.balance_of(CREATOR());

    assert!(creator_balance == 1000, "balance should increment");
    assert!(user1_balance == user1_balance_before - 1000, "balance should match");

    let is_member = ip_club.is_member(club_id, USER1());
    assert!(is_member, "not member");
}

#[test]
#[should_panic(expected: 'Already a member')]
fn test_cannot_join_club_twice() {
    let TestContracts { ip_club, .. } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::None;
    let entry_fee = Option::None;
    let payment_token = Option::None;

    cheat_caller_address(ip_club.contract_address, CREATOR(), CheatSpan::TargetCalls(1));
    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );

    let club_id = ip_club.get_last_club_id();

    cheat_caller_address(ip_club.contract_address, USER1(), CheatSpan::TargetCalls(1));
    ip_club.join_club(club_id);

    cheat_caller_address(ip_club.contract_address, USER1(), CheatSpan::TargetCalls(1));
    ip_club.join_club(club_id);
}

#[test]
#[should_panic(expected: 'Club full')]
fn test_cannot_join_club_when_max_members_reached() {
    let TestContracts { ip_club, .. } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::Some(1);
    let entry_fee = Option::None;
    let payment_token = Option::None;

    cheat_caller_address(ip_club.contract_address, CREATOR(), CheatSpan::TargetCalls(1));
    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );

    let club_id = ip_club.get_last_club_id();

    cheat_caller_address(ip_club.contract_address, USER1(), CheatSpan::TargetCalls(1));
    ip_club.join_club(club_id);

    cheat_caller_address(ip_club.contract_address, USER2(), CheatSpan::TargetCalls(1));
    ip_club.join_club(club_id);
}

#[test]
#[should_panic(expected: 'Club not open')]
fn test_cannot_join_when_club_is_closed() {
    let TestContracts { ip_club, .. } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::Some(1);
    let entry_fee = Option::None;
    let payment_token = Option::None;

    cheat_caller_address(ip_club.contract_address, CREATOR(), CheatSpan::TargetCalls(1));
    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );

    let club_id = ip_club.get_last_club_id();

    cheat_caller_address(ip_club.contract_address, CREATOR(), CheatSpan::TargetCalls(1));
    ip_club.close_club(club_id);

    cheat_caller_address(ip_club.contract_address, USER1(), CheatSpan::TargetCalls(1));
    ip_club.join_club(club_id);
}


#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_only_ip_club_can_mint() {
    let TestContracts { ip_club, .. } = initialize_contracts();
    let club_name = "Vipers";
    let club_symbol = "VPs";
    let metadata_uri = "http:://localhost:3000";
    let max_members = Option::Some(1);
    let entry_fee = Option::None;
    let payment_token = Option::None;

    cheat_caller_address(ip_club.contract_address, CREATOR(), CheatSpan::TargetCalls(1));
    ip_club
        .create_club(
            club_name.clone(),
            club_symbol.clone(),
            metadata_uri.clone(),
            max_members,
            entry_fee,
            payment_token,
        );

    let club_id = ip_club.get_last_club_id();
    let club_record = ip_club.get_club_record(club_id);

    let ip_club_nft = IIPClubNFTDispatcher { contract_address: club_record.club_nft };
    cheat_caller_address(ip_club_nft.contract_address, CREATOR(), CheatSpan::TargetCalls(1));
    ip_club_nft.mint(USER1());
}

