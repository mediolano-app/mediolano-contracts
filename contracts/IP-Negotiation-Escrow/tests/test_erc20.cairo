use starknet::ContractAddress;
use ip_negotiation_escrow::mock_erc20::{IERC20Dispatcher};

fn create_contract_address(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

fn token_address() -> ContractAddress {
    create_contract_address(3)
}

#[test]
fn test_erc20_interface() {
    let token_contract = token_address();
    let _erc20 = IERC20Dispatcher { contract_address: token_contract };
    
    assert(true, 'ERC20 interface compiles');
} 