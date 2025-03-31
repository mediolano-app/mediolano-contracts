use core::pedersen::pedersen;
use starknet::ContractAddress;
use core::traits::Into;

fn create_contract_address(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

#[test]
fn test_pedersen_hash() {
    let seller = create_contract_address(1);
    let token_id_low = 1;
    let token_id_high = 0;
    let count_low = 0;
    let count_high = 0;
    
    let hash1 = pedersen(token_id_low.into(), token_id_high.into());
    let hash2 = pedersen(hash1, count_low.into());
    let hash3 = pedersen(hash2, count_high.into());
    let order_id = pedersen(hash3, seller.into());
    
    assert(order_id != 0, 'Hash should not be zero');
    
    let seller2 = create_contract_address(2);
    let hash1_2 = pedersen(token_id_low.into(), token_id_high.into());
    let hash2_2 = pedersen(hash1_2, count_low.into());
    let hash3_2 = pedersen(hash2_2, count_high.into());
    let order_id2 = pedersen(hash3_2, seller2.into());
    
    assert(order_id != order_id2, 'Hashes should be different');
}

#[test]
fn test_order_id_generation() {
    let token_id1 = u256 { low: 1, high: 0 };
    let token_id2 = u256 { low: 2, high: 0 };
    let count = u256 { low: 0, high: 0 };
    let creator = create_contract_address(1);
    
    let hash1_1 = pedersen(token_id1.low.into(), token_id1.high.into());
    let hash1_2 = pedersen(hash1_1, count.low.into());
    let hash1_3 = pedersen(hash1_2, count.high.into());
    let order_id1 = pedersen(hash1_3, creator.into());
    
    let hash2_1 = pedersen(token_id2.low.into(), token_id2.high.into());
    let hash2_2 = pedersen(hash2_1, count.low.into());
    let hash2_3 = pedersen(hash2_2, count.high.into());
    let order_id2 = pedersen(hash2_3, creator.into());
    
    assert(order_id1 != order_id2, 'Hashes should differ');
    
    let count2 = u256 { low: 1, high: 0 };
    
    let hash3_1 = pedersen(token_id1.low.into(), token_id1.high.into());
    let hash3_2 = pedersen(hash3_1, count2.low.into());
    let hash3_3 = pedersen(hash3_2, count2.high.into());
    let order_id3 = pedersen(hash3_3, creator.into());
    
    assert(order_id1 != order_id3, 'Hashes should differ');
} 