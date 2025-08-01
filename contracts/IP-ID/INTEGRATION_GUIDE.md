# IP-ID Contract Integration Guide

## Overview
This guide provides comprehensive instructions for integrating with the enhanced IP-ID contract, designed for seamless interoperability with the MIP Protocol and broader Starknet ecosystem.

## Quick Start

### 1. Contract Interface
```cairo
use ip_id::IPIdentity::{IIPIdentityDispatcher, IIPIdentityDispatcherTrait};

// Initialize the dispatcher
let ip_identity = IIPIdentityDispatcher { contract_address: IP_ID_CONTRACT_ADDRESS };
```

### 2. Basic IP Registration
```cairo
let token_id = ip_identity.register_ip_id(
    ip_id,                    // Unique IP identifier
    metadata_uri,             // IPFS or HTTP URI
    ip_type,                  // "image", "video", "audio", etc.
    license_terms,            // License description
    collection_id,            // MIP collection ID (0 if none)
    royalty_rate,            // Basis points (250 = 2.5%)
    licensing_fee,           // Fee in wei
    commercial_use,          // true/false
    derivative_works,        // true/false
    attribution_required,    // true/false
    metadata_standard,       // "ERC721", "ERC1155", etc.
    external_url,           // Additional info URL
    tags,                   // "art,digital,nft"
    jurisdiction            // "US", "EU", etc.
);
```

## Integration Patterns

### 1. DeFi Integration
```cairo
// Check if IP can be used as collateral
fn can_use_as_collateral(ip_id: felt252) -> bool {
    let ip_identity = IIPIdentityDispatcher { contract_address: IP_ID_CONTRACT_ADDRESS };
    
    // Verify IP is registered and verified
    if !ip_identity.is_ip_id_registered(ip_id) {
        return false;
    }
    
    if !ip_identity.is_ip_verified(ip_id) {
        return false;
    }
    
    // Check commercial use permission
    ip_identity.can_use_commercially(ip_id)
}

// Get IP valuation data
fn get_ip_valuation_data(ip_id: felt252) -> (u256, u256, bool) {
    let ip_identity = IIPIdentityDispatcher { contract_address: IP_ID_CONTRACT_ADDRESS };
    let (_, royalty_rate, licensing_fee, commercial_use, _, _) = 
        ip_identity.get_ip_licensing_terms(ip_id);
    
    (royalty_rate, licensing_fee, commercial_use)
}
```

### 2. NFT Marketplace Integration
```cairo
// Verify IP ownership before listing
fn verify_listing_permissions(ip_id: felt252, seller: ContractAddress) -> bool {
    let ip_identity = IIPIdentityDispatcher { contract_address: IP_ID_CONTRACT_ADDRESS };
    
    // Check if seller owns the IP
    let owner = ip_identity.get_ip_owner(ip_id);
    if owner != seller {
        return false;
    }
    
    // Check if IP allows commercial use
    ip_identity.can_use_commercially(ip_id)
}

// Get marketplace display data
fn get_marketplace_data(ip_id: felt252) -> (ByteArray, ByteArray, ByteArray, u256) {
    let ip_identity = IIPIdentityDispatcher { contract_address: IP_ID_CONTRACT_ADDRESS };
    let (metadata_uri, ip_type, metadata_standard, external_url) = 
        ip_identity.get_ip_metadata_info(ip_id);
    let (_, royalty_rate, _, _, _, _) = ip_identity.get_ip_licensing_terms(ip_id);
    
    (metadata_uri, ip_type, external_url, royalty_rate)
}
```

### 3. DAO Integration
```cairo
// Proposal to acquire IP rights
fn create_ip_acquisition_proposal(ip_id: felt252) -> bool {
    let ip_identity = IIPIdentityDispatcher { contract_address: IP_ID_CONTRACT_ADDRESS };
    
    // Verify IP exists and get licensing terms
    if !ip_identity.is_ip_id_registered(ip_id) {
        return false;
    }
    
    let (license_terms, royalty_rate, licensing_fee, commercial_use, derivative_works, attribution_required) = 
        ip_identity.get_ip_licensing_terms(ip_id);
    
    // Create proposal with IP licensing data
    // ... DAO-specific logic here
    
    true
}

// Batch query for DAO IP portfolio
fn get_dao_ip_portfolio(dao_address: ContractAddress) -> Array<felt252> {
    let ip_identity = IIPIdentityDispatcher { contract_address: IP_ID_CONTRACT_ADDRESS };
    ip_identity.get_owner_ip_ids(dao_address)
}
```

## Event Handling

### 1. Setting Up Event Listeners
```cairo
// Listen for IP registrations
#[event]
#[derive(Drop, starknet::Event)]
enum Event {
    IPRegistered: IPRegistered,
}

#[derive(Drop, starknet::Event)]
struct IPRegistered {
    ip_id: felt252,
    owner: ContractAddress,
    collection_id: u256,
    commercial_use: bool,
}

// Event handler implementation
impl EventHandler {
    fn handle_ip_registered(event: IPRegistered) {
        // Index the new IP
        // Update collection statistics
        // Notify relevant services
    }
}
```

### 2. Indexing Strategy
```cairo
// Efficient indexing using batch queries
fn index_collection_ips(collection_id: u256) {
    let ip_identity = IIPIdentityDispatcher { contract_address: IP_ID_CONTRACT_ADDRESS };
    let ip_ids = ip_identity.get_ip_ids_by_collection(collection_id);
    
    // Batch get IP data
    let ip_data_array = ip_identity.get_multiple_ip_data(ip_ids);
    
    // Process and index data
    let mut i = 0;
    while i < ip_data_array.len() {
        let ip_data = ip_data_array.at(i);
        // Index individual IP data
        i += 1;
    };
}
```

## Best Practices

### 1. Gas Optimization
- Use batch query functions when possible
- Cache frequently accessed data
- Implement pagination for large datasets

### 2. Error Handling
```cairo
fn safe_get_ip_data(ip_id: felt252) -> Option<IPIDData> {
    let ip_identity = IIPIdentityDispatcher { contract_address: IP_ID_CONTRACT_ADDRESS };
    
    if !ip_identity.is_ip_id_registered(ip_id) {
        return Option::None;
    }
    
    Option::Some(ip_identity.get_ip_id_data(ip_id))
}
```

### 3. Permission Checking
```cairo
fn check_usage_permissions(ip_id: felt252, use_case: ByteArray) -> bool {
    let ip_identity = IIPIdentityDispatcher { contract_address: IP_ID_CONTRACT_ADDRESS };
    
    match use_case {
        "commercial" => ip_identity.can_use_commercially(ip_id),
        "derivative" => ip_identity.can_create_derivatives(ip_id),
        "attribution" => ip_identity.requires_attribution(ip_id),
        _ => false,
    }
}
```

## Common Integration Scenarios

### 1. Content Platform Integration
```cairo
// Verify content can be displayed
fn can_display_content(ip_id: felt252, platform_type: ByteArray) -> bool {
    let ip_identity = IIPIdentityDispatcher { contract_address: IP_ID_CONTRACT_ADDRESS };
    
    if !ip_identity.is_ip_verified(ip_id) {
        return false;
    }
    
    match platform_type {
        "commercial" => ip_identity.can_use_commercially(ip_id),
        "educational" => true, // Usually allowed
        "personal" => !ip_identity.can_use_commercially(ip_id), // Non-commercial only
        _ => false,
    }
}
```

### 2. Licensing Platform Integration
```cairo
// Calculate licensing fee
fn calculate_licensing_fee(ip_id: felt252, usage_duration: u64, usage_scope: ByteArray) -> u256 {
    let ip_identity = IIPIdentityDispatcher { contract_address: IP_ID_CONTRACT_ADDRESS };
    let (_, royalty_rate, base_fee, _, _, _) = ip_identity.get_ip_licensing_terms(ip_id);
    
    let mut total_fee = base_fee;
    
    // Apply duration multiplier
    if usage_duration > 365 { // More than 1 year
        total_fee = total_fee * 2;
    }
    
    // Apply scope multiplier
    match usage_scope {
        "global" => total_fee = total_fee * 3,
        "regional" => total_fee = total_fee * 2,
        "local" => total_fee = total_fee * 1,
        _ => total_fee = total_fee * 1,
    }
    
    total_fee
}
```

### 3. Analytics Platform Integration
```cairo
// Get collection analytics
fn get_collection_analytics(collection_id: u256) -> (u256, u256, u256) {
    let ip_identity = IIPIdentityDispatcher { contract_address: IP_ID_CONTRACT_ADDRESS };
    let ip_ids = ip_identity.get_ip_ids_by_collection(collection_id);
    
    let total_ips = ip_ids.len();
    let verified_ips = ip_identity.get_verified_ip_ids(1000, 0); // Get all verified
    
    let mut verified_in_collection = 0;
    let mut commercial_allowed = 0;
    
    let mut i = 0;
    while i < ip_ids.len() {
        let ip_id = *ip_ids.at(i);
        
        if ip_identity.is_ip_verified(ip_id) {
            verified_in_collection += 1;
        }
        
        if ip_identity.can_use_commercially(ip_id) {
            commercial_allowed += 1;
        }
        
        i += 1;
    };
    
    (total_ips.into(), verified_in_collection, commercial_allowed)
}
```

## Testing Your Integration

### 1. Unit Tests
```cairo
#[test]
fn test_ip_registration_integration() {
    let (ip_identity, _) = deploy_ip_identity();
    
    // Test registration
    let ip_id = 123;
    let token_id = ip_identity.register_ip_id(
        ip_id, "ipfs://test", "image", "MIT", 1, 250, 1000,
        true, true, true, "ERC721", "https://test.com", "test", "US"
    );
    
    // Test integration functions
    assert(ip_identity.is_ip_id_registered(ip_id), 'IP should be registered');
    assert(ip_identity.can_use_commercially(ip_id), 'Should allow commercial use');
}
```

### 2. Integration Tests
```cairo
#[test]
fn test_cross_contract_integration() {
    // Deploy both contracts
    let (ip_identity, _) = deploy_ip_identity();
    let (marketplace, _) = deploy_marketplace();
    
    // Register IP
    let ip_id = 123;
    ip_identity.register_ip_id(/* parameters */);
    
    // Test marketplace integration
    let can_list = marketplace.verify_listing_permissions(ip_id, owner);
    assert(can_list, 'Should be able to list');
}
```

## Troubleshooting

### Common Issues
1. **"Invalid IP ID" Error**: Ensure IP is registered before querying
2. **"Caller is not the owner" Error**: Verify ownership before updates
3. **Gas Limit Exceeded**: Use batch functions for multiple operations
4. **Event Not Emitted**: Check event listener configuration

### Debug Functions
```cairo
fn debug_ip_state(ip_id: felt252) {
    let ip_identity = IIPIdentityDispatcher { contract_address: IP_ID_CONTRACT_ADDRESS };
    
    println!("IP Registered: {}", ip_identity.is_ip_id_registered(ip_id));
    println!("IP Verified: {}", ip_identity.is_ip_verified(ip_id));
    println!("Owner: {}", ip_identity.get_ip_owner(ip_id));
    println!("Commercial Use: {}", ip_identity.can_use_commercially(ip_id));
}
```

This integration guide provides a comprehensive foundation for building applications that leverage the enhanced IP-ID contract capabilities.
