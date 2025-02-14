use core::starknet::{contract_address_const, ContractAddress, get_caller_address};
use starknet::storage::{Map, StorageMapReadAccess, StoragePointerWriteAccess, StoragePathEntry, StoragePointerReadAccess, StorageMapWriteAccess};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, EventSpyAssertionsTrait, spy_events, load, mock_call
};

use ip_collection::IPCollection::{IIPCollectionDispatcher, IIPCollectionDispatcherTrait};
use openzeppelin_token::erc721::interface::{
    IERC721Dispatcher, IERC721DispatcherTrait, IERC721MetadataDispatcher,
    IERC721MetadataDispatcherTrait, IERC721Receiver, IERC721ReceiverDispatcher, IERC721ReceiverDispatcherTrait
};

fn deploy_contract() -> (IIPCollectionDispatcher, ContractAddress){
    let contract = declare("IPCollection").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    let dispatcher = IIPCollectionDispatcher { contract_address };
    (dispatcher, contract_address)
}

#[test]
fn test_mint(){
    let (ipcollection, ipcollection_address) = deploy_contract();
    let erc721 = IERC721Dispatcher { contract_address: ipcollection_address };
    let caller = contract_address_const::<'123'>();
    start_cheat_caller_address(ipcollection_address,caller);
    let token_id = ipcollection.mint(caller);
    assert_eq!(erc721.balance_of(caller), 1, "user should have first nft");
    assert_eq!(ipcollection.user_tokens, );
    stop_cheat_caller_address(ipcollection_address);
}

#[test]
fn test_burn(){
    let (ipcollection, ipcollection_address) = deploy_contract();

}