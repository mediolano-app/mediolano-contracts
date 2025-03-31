use starknet::{ContractAddress};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, spy_events, EventSpyAssertionsTrait, cheat_caller_address, CheatSpan,
    stop_cheat_block_timestamp,
};
use core::array::ArrayTrait;
use core::byte_array::ByteArray;
use ip_ticket::interface::{
    IIPTicketServiceDispatcher, IIPTicketServiceDispatcherTrait,
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

// Constants for test addresses
pub fn OWNER() -> ContractAddress {
    'owner'.try_into().unwrap()
}

pub fn MINTER() -> ContractAddress {
    'minter'.try_into().unwrap()
}

pub fn deploy_mock_erc20() -> IERC20Dispatcher {
    let contract = declare("MockERC20").unwrap().contract_class();
    let mut calldata = array![];
    let initial_supply: u256 = 10000.into();
    let owner: ContractAddress = OWNER();
    calldata.append(initial_supply.low.into());
    calldata.append(initial_supply.high.into());
    calldata.append(owner.into());

    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    IERC20Dispatcher { contract_address }
}

// Deploy the IPTicketService contract
pub fn deploy_ipticket(erc20_address: ContractAddress) -> IIPTicketServiceDispatcher {
    let contract = declare("IPTicketService").unwrap().contract_class();
    let mut calldata = array![];
    let name: ByteArray = "IP Tickets";
    let symbol: ByteArray = "IPT";
    let token_uri: ByteArray = "https://example.com/";

    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    erc20_address.serialize(ref calldata);
    token_uri.serialize(ref calldata);

    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    IIPTicketServiceDispatcher { contract_address }
}

// Setup function for IPTicketService and MockERC20
pub fn setup() -> (IIPTicketServiceDispatcher, IERC20Dispatcher, ContractAddress) {
    // Deploy MockERC20
    let erc20 = deploy_mock_erc20();

    // Deploy IPTicketService with the ERC20 address
    let ticket_service = deploy_ipticket(erc20.contract_address);

    let owner = OWNER();

    // Fund MINTER and approve IPTicketService to spend tokens
    let minter = MINTER();
    let price: u256 = 100.into(); // Example price from tests
    start_cheat_caller_address(erc20.contract_address, owner);
    erc20.transfer(minter, 1000.into()); // Fund minter with enough tokens
    stop_cheat_caller_address(erc20.contract_address);

    start_cheat_caller_address(erc20.contract_address, minter);
    erc20.approve(ticket_service.contract_address, price * 2); // Approve for multiple mints
    stop_cheat_caller_address(erc20.contract_address);

    (ticket_service, erc20, owner)
}
