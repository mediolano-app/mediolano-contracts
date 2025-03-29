use starknet::ContractAddress;
use ip_negotiation_escrow::ip_negotiation_escrow::{
    IIPNegotiationEscrowDispatcher
};

fn create_contract_address(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

fn seller_address() -> ContractAddress {
    create_contract_address(1)
}

fn escrow_address() -> ContractAddress {
    create_contract_address(4)
}

#[test]
fn test_escrow_interface() {
    let escrow_contract = escrow_address();
    let _dispatcher = IIPNegotiationEscrowDispatcher { contract_address: escrow_contract };
    
    assert(true, 'Escrow interface compiles');
} 