# IP Negotiation Escrow Smart Contract

A Cairo smart contract for facilitating secure escrow services in IP (Intellectual Property) negotiations on the Starknet blockchain.

## Overview

This smart contract implements an escrow system for IP negotiations, enabling secure transactions between IP sellers and buyers. It ensures that funds are safely held in escrow and only released to the seller upon fulfillment of the transaction conditions.

## Features

- **Order Creation**: Allows IP sellers to create escrow orders with specific pricing and token identifiers.
- **Order Management**: Provides functionality to retrieve, modify, and track orders.
- **Secure Fund Handling**: Manages the secure deposit of funds by buyers and ensures proper transfer upon transaction fulfillment.
- **Order Fulfillment**: Enables sellers to fulfill orders and receive payment once conditions are met.
- **Event Tracking**: Emits events for key actions such as order creation, fund deposits, and order fulfillment.
- **Token-to-Order Mapping**: Associates each tokenId with a unique order for easy reference.

## Architecture

The contract implements the following core components:

### Order Structure

```cairo
pub struct Order {
    creator: ContractAddress,  // Address of the user who created the order
    price: u256,               // Price of the IP in the specified token
    token_id: u256,            // Unique identifier for the IP asset
    fulfilled: bool,           // Whether the order has been completed
    id: felt252,               // Unique ID for the order
}
```

### Storage

The contract maintains the following state:

- `erc20`: The ERC20 token dispatcher used for payments
- `token_address`: The ERC20 token contract address
- `orders`: Mapping from order_id to Order
- `token_to_order`: Mapping from token_id to order_id
- `order_count`: Total number of orders created

### Events

The contract emits the following events:

- `OrderCreated`: When a new order is created
- `FundsDeposited`: When a buyer deposits funds for an order
- `OrderFulfilled`: When an order is successfully fulfilled
- `OrderCancelled`: When an order is cancelled

## Escrow Process Workflow

1. **Order Creation**:
   - Seller creates an order specifying the token_id and price
   - The order is stored with a unique order_id

2. **Order Retrieval**:
   - Buyers can query orders by order_id or token_id

3. **Deposit Funds**:
   - Buyer deposits the required amount into the escrow contract

4. **Fulfillment**:
   - Seller fulfills the order, releasing the token to the buyer
   - Funds are transferred from escrow to the seller

5. **Order Finalization**:
   - The order is marked as fulfilled

## Security Mechanisms

- Verification of caller identity for critical operations
- Checks to ensure correct order state transitions
- Validation of fund amounts
- Prevention of duplicate orders for the same token

## Installation and Setup

### Prerequisites

- Scarb (Cairo package manager)
- Starknet Foundry (for testing)

### Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd mediolano-contracts/contracts/IP-Negotiation-Escrow
   ```

2. Install dependencies:
   ```bash
   scarb install
   ```

3. Build the contract:
   ```bash
   scarb build
   ```

4. Run tests:
   ```bash
   scarb test
   ```

## Contract Interface

```cairo
#[starknet::interface]
pub trait IIPNegotiationEscrow<TContractState> {
    fn create_order(
        ref self: TContractState,
        creator: ContractAddress,
        price: u256,
        token_id: u256,
    ) -> felt252;
    
    fn get_order(self: @TContractState, order_id: felt252) -> Order;
    fn get_order_by_token_id(self: @TContractState, token_id: u256) -> Order;
    fn deposit_funds(ref self: TContractState, order_id: felt252);
    fn fulfill_order(ref self: TContractState, order_id: felt252);
    fn cancel_order(ref self: TContractState, order_id: felt252);
}
```

## Usage Examples

### Creating an Order

```cairo
// Assuming escrow is an instance of IIPNegotiationEscrowDispatcher
let seller = get_caller_address();
let token_id = u256 { low: 123, high: 0 };
let price = u256 { low: 1000000000000000000, high: 0 }; // 1 token with 18 decimals

let order_id = escrow.create_order(seller, price, token_id);
```

### Depositing Funds

```cairo
// Buyer must approve the escrow contract to spend tokens first
erc20.approve(escrow_address, price);

// Then deposit funds
escrow.deposit_funds(order_id);
```

### Fulfilling an Order

```cairo
// Only the seller can fulfill the order
escrow.fulfill_order(order_id);
```

## Testing

The contract includes comprehensive tests covering:

- Order creation
- Fund deposits
- Order fulfillment
- Error handling and edge cases

Run tests with:
```bash
scarb test
```

## License

This project is licensed under the MIT License - see the LICENSE file for details. 