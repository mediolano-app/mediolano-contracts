use snforge_std::DeclareResultTrait;
use starknet::{ContractAddress, contract_address_const};
use snforge_std::{cheat_caller_address, declare, CheatSpan, ContractClassTrait};
use ip_crowfunding::IPCrowdfunding::{IIPCrowdfundingDispatcher, IIPCrowdfundingDispatcherTrait};

fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn alice() -> ContractAddress {
    contract_address_const::<'alice'>()
}

fn bob() -> ContractAddress {
    contract_address_const::<'bob'>()
}

fn deploy_ipcrowdfunding(owner: ContractAddress, token: ContractAddress) -> ContractAddress {
    let contract_class = declare("IPCrowdfunding").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(owner.into());
    calldata.append(token.into());
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
}

fn create_campaign(
    ipc: ContractAddress,
    title: felt252,
    description: felt252,
    goal_amount: u256,
    duration: u64,
) {
    let ipc_dispatcher = IIPCrowdfundingDispatcher { contract_address: ipc };
    cheat_caller_address(ipc, owner(), CheatSpan::TargetCalls(1));
    ipc_dispatcher.create_campaign(title, description, goal_amount, duration);
}

#[test]
fn test_create_campaign() {
    let owner = owner();
    let token = contract_address_const::<'token'>();
    let ipc = deploy_ipcrowdfunding(owner, token);

    let ipc_dispatcher = IIPCrowdfundingDispatcher { contract_address: ipc };
    cheat_caller_address(ipc, owner, CheatSpan::TargetCalls(1));
    ipc_dispatcher.create_campaign('Campaign 1'.into(), 'Description'.into(), 1000.into(), 1000);

    let campaign = ipc_dispatcher.get_campaign(1.into());
    assert(campaign.title == 'Campaign 1'.into(), 'Campaign title mismatch');
    assert(campaign.description == 'Description'.into(), 'Campaign description mismatch');
    assert(campaign.goal_amount == 1000.into(), 'Campaign goal amount mismatch');
    assert(campaign.creator == owner, 'Campaign creator mismatch');
}