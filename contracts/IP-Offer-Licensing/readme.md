# IP Offer Licensing Contract

A Starknet smart contract for managing intellectual property licensing offers. This contract enables creators to create, accept, reject, and cancel licensing offers for their IP tokens.

## Features

- Create licensing offers for IP tokens
- Accept offers with automatic payment transfer
- Reject offers
- Cancel offers
- Claim refunds for rejected/cancelled offers
- Query offers by IP token, creator, or owner

## Contract Structure

### Storage

- `offers`: Map of offer IDs to Offer structs
- `offer_count`: Counter for total offers
- `ip_token_contract`: Address of the IP token contract
- `ip_offers`: Index of offers by IP token ID
- `creator_offers`: Index of offers by creator
- `owner_offers`: Index of offers by owner

### Main Functions

- `create_offer`: Create a new licensing offer
- `accept_offer`: Accept an offer and transfer payment
- `reject_offer`: Reject an offer
- `cancel_offer`: Cancel an offer
- `claim_refund`: Claim refund for rejected/cancelled offer
- `get_offer`: Get offer details by ID
- `get_offers_by_ip`: Get all offers for an IP token
- `get_offers_by_creator`: Get all offers created by an address
- `get_offers_by_owner`: Get all offers owned by an address

## Events

- `OfferCreated`: Emitted when a new offer is created
- `OfferAccepted`: Emitted when an offer is accepted
- `OfferRejected`: Emitted when an offer is rejected
- `OfferCancelled`: Emitted when an offer is cancelled
- `RefundClaimed`: Emitted when a refund is claimed

## Integration

The contract integrates with:
- ERC721 for IP token ownership verification
- ERC20 for payment handling
- Ownable for access control
- SRC5 for interface support

## Development

### Prerequisites

- Scarb
- Starknet Foundry
- Cairo 1.0

### Building

```bash
scarb build
```

### Testing

```bash
scarb test
```

## License

MIT
