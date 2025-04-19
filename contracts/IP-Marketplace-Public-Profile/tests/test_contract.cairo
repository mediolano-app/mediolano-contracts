use ip_marketplace_public_profile::PublicProfileMarketplace::IPublicProfileMarketPlaceDispatcherTrait;
use starknet::{ContractAddress, contract_address_const};

use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, spy_events, EventSpyAssertionsTrait, get_class_hash
};

use ip_marketplace_public_profile::PublicProfileMarketplace::{IPublicProfileMarketPlace, IPublicProfileMarketPlaceDispatcher, SellerPublicProfile};

fn USER() -> ContractAddress {
    'recipient'.try_into().unwrap()
}

fn __setup__() -> (IPublicProfileMarketPlaceDispatcher, ContractAddress) {
    _deploy_Public_Profile__()
}

fn _deploy_Public_Profile__() -> (IPublicProfileMarketPlaceDispatcher, ContractAddress) {
    let contract = declare("PublicProfileMarketPlace").unwrap().contract_class();
    let owner: ContractAddress = contract_address_const::<'owner'>();
    let seller_count: u64 = 0;
    let constructor_calldata = array![seller_count.into(), owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = IPublicProfileMarketPlaceDispatcher { contract_address };
    (dispatcher, contract_address)
}

#[test]
fn test_create_seller_profile(){
    let (dispatcher, contract_address) = __setup__();
    let user1 = contract_address_const::<'user1'>();
    let mut seller_count = dispatcher.get_seller_count();
    assert(seller_count == 0, 'Seller Count not zero');
    start_cheat_caller_address(contract_address, user1);
    let user1_profile = dispatcher.create_seller_profile(
        'user', 'mystore', "Where I am", "We just do us", 'me@gmail.com', '080686452', 'myemail@gmail.com'
    );
    stop_cheat_caller_address(contract_address);
    seller_count = dispatcher.get_seller_count();
    assert(seller_count == 1, 'User 1 Not Added');
    let user2 = contract_address_const::<'user2'>();
    start_cheat_caller_address(contract_address, user2);
    let user2_profile = dispatcher.create_seller_profile(
        'user2', 'mystore', "Where I am", "We just do us", 'me@gmail.com', '080686452', 'myemail@gmail.com'
    );
    stop_cheat_caller_address(contract_address);
    seller_count = dispatcher.get_seller_count();
    assert(seller_count == 2, 'User 2 Not Added');
    let user3 = contract_address_const::<'user2'>();
    start_cheat_caller_address(contract_address, user3);
    // Should fail to create profile if you try to repeat with same address
    let user2_profile = dispatcher.create_seller_profile(
        'user2', 'mystore', "Where I am", "We just do us", 'me@gmail.com', '080686452', 'myemail@gmail.com'
    );
    stop_cheat_caller_address(contract_address);
    seller_count = dispatcher.get_seller_count();
    // Count should still be 2
    assert(seller_count == 2, 'User 2 Not Added');
}

#[test]
#[should_panic(expected: 'Error: Unauthorized caller')]
fn test_update_seller_profile(){
    let (dispatcher, contract_address) = __setup__();
    let user1 = contract_address_const::<'user1'>();
    let unauthorized_user = contract_address_const::<'unauthorized_user'>();
    let mut seller_count = dispatcher.get_seller_count();
    assert(seller_count == 0, 'Seller Count not zero');
    start_cheat_caller_address(contract_address, user1);
    dispatcher.create_seller_profile(
        'user', 'mystore', "Where I am", "We just do us", 'me@gmail.com', '080686452', 'myemail@gmail.com'
    );
    dispatcher.update_profile(
        0, 'My new name', 'mystore', "Where I am", "We just do us", 'me@gmail.com', '080686452', 'myemail@gmail.com'
    );
    stop_cheat_caller_address(contract_address);

    let seller = dispatcher.get_specific_seller(0);
    let seller_name = seller.seller_name;
    assert(seller_name == 'My new name', 'Profile not updated');

    start_cheat_caller_address(contract_address, unauthorized_user);
    dispatcher.update_profile(
        0, 'My unauthorized name', 'mystore', "Where I am", "We just do us", 'me@gmail.com', '080686452', 'myemail@gmail.com'
    );
    stop_cheat_caller_address(contract_address)
}

#[test]
fn test_get_all_sellers(){
    let (dispatcher, contract_address) = __setup__();
    let user1 = contract_address_const::<'user1'>();
    let mut seller_count = dispatcher.get_seller_count();
    assert(seller_count == 0, 'Seller Count not zero');
    start_cheat_caller_address(contract_address, user1);
    let user1_profile = dispatcher.create_seller_profile(
        'user', 'mystore', "Where I am", "We just do us", 'me@gmail.com', '080686452', 'myemail@gmail.com'
    );
    stop_cheat_caller_address(contract_address);
    seller_count = dispatcher.get_seller_count();
    assert(seller_count == 1, 'User 1 Not Added');
    let user2 = contract_address_const::<'user2'>();
    start_cheat_caller_address(contract_address, user2);
    let user2_profile = dispatcher.create_seller_profile(
        'user2', 'mystore', "Where I am", "We just do us", 'me@gmail.com', '080686452', 'myemail@gmail.com'
    );
    stop_cheat_caller_address(contract_address);
    seller_count = dispatcher.get_seller_count();
    assert(seller_count == 2, 'User 2 Not Added');
    let user3 = contract_address_const::<'user2'>();
    start_cheat_caller_address(contract_address, user3);
    // Should fail to create profile if you try to repeat with same address
    let user2_profile = dispatcher.create_seller_profile(
        'user2', 'mystore', "Where I am", "We just do us", 'me@gmail.com', '080686452', 'myemail@gmail.com'
    );
    stop_cheat_caller_address(contract_address);
    seller_count = dispatcher.get_seller_count();
    // Count should still be 2
    assert(seller_count == 2, 'User 2 Not Added');
    let contract_users = dispatcher.get_all_sellers();
    let cu1 = contract_users.at(0);
    assert(cu1.seller_address == @user1, 'Wrong addition of user')

}

#[test]
#[should_panic(expected: 'Error: Unauthorized Caller')]
fn test_get_private_info_with_unauthorized_address(){
    let (dispatcher, contract_address) = __setup__();
    let user = contract_address_const::<'user1'>();
    let unauthorized_user = contract_address_const::<'unauthorized_user'>();
    start_cheat_caller_address(contract_address, user);
    let user_profile = dispatcher.create_seller_profile(
        'user', 'mystore', "Where I am", "We just do us", 'me@gmail.com', '080686452', 'myemail@gmail.com'
    );
    let user_private_profile = dispatcher.get_private_info(0);
    stop_cheat_caller_address(contract_address);
    assert(user_private_profile.seller_address == user, 'User Address Added Wrongly');
    assert(user_private_profile.phone_number == '080686452', 'User Phone number wrong');
    start_cheat_caller_address(contract_address, unauthorized_user);
    let user_private_profile_with_unauthorized_caller = dispatcher.get_private_info(0);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'Error: Unauthorized Caller')]
fn test_add_social_link(){
    let (dispatcher, contract_address) = __setup__();
    let user = contract_address_const::<'user'>();
    let unauthorized_user = contract_address_const::<'unauthorized_user'>();
    let link_1 = ('X', 'https://x.com');
    let link_2 = ('Facebook', 'https://facebook.com');
    let link_3 = ('Telegram', 'https://tg.com');
    start_cheat_caller_address(contract_address, user);
    dispatcher.add_social_link(0, 'X', 'https://x.com');
    dispatcher.add_social_link(0, 'Facebook', 'https://facebook.com');
    dispatcher.add_social_link(0, 'Telegram', 'https://tg.com');

    let social_links = dispatcher.get_social_links(0);
    stop_cheat_caller_address(contract_address);
    let first_link = social_links.at(0).try_into().unwrap();
    let second_link = social_links.at(1).try_into().unwrap();
    let third_link = social_links.at(2).try_into().unwrap();
    assert(first_link == @link_1.try_into().unwrap(), 'Error: Link added wrongly');
    assert(second_link == @link_2.try_into().unwrap(), 'Error: Link added wrongly');
    assert(third_link == @link_3.try_into().unwrap(), 'Error: Link added wrongly');

    start_cheat_caller_address(contract_address, unauthorized_user);
    let social_links_with_unauthorized_caller = dispatcher.get_private_info(0);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic]
fn test_functions_fail_with_zero_address(){
    let (dispatcher, contract_address) = __setup__();
    let zero_address = contract_address_const::<0>();
    let link_1 = ('X', 'https://x.com');
    let link_2 = ('Facebook', 'https://facebook.com');
    let link_3 = ('Telegram', 'https://tg.com');
    start_cheat_caller_address(contract_address, zero_address);
    let user_profile = dispatcher.create_seller_profile(
        'user', 'mystore', "Where I am", "We just do us", 'me@gmail.com', '080686452', 'myemail@gmail.com'
    );
    dispatcher.add_social_link(0, 'X', 'https://x.com');
    dispatcher.add_social_link(0, 'Facebook', 'https://facebook.com');
    dispatcher.add_social_link(0, 'Telegram', 'https://tg.com');
    stop_cheat_caller_address(contract_address);
}
