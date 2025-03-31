use starknet::ContractAddress;

/// Helper function to create a contract address for testing
fn create_contract_address(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

/// Helper function to create a seller address
fn seller_address() -> ContractAddress {
    create_contract_address(1)
}

/// Helper function to create a buyer address
fn buyer_address() -> ContractAddress {
    create_contract_address(2)
}

/// Helper function to create a token address
fn token_address() -> ContractAddress {
    create_contract_address(3)
}

/// Helper function to create an escrow contract address
fn escrow_address() -> ContractAddress {
    create_contract_address(4)
} 