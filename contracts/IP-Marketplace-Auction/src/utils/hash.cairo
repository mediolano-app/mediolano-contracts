use core::poseidon::poseidon_hash_span;

pub fn compute_bid_hash(amount: u256, salt: felt252) -> felt252 {
    let mut buf: Array<felt252> = array![];
    buf.append((amount.low).into());
    buf.append((amount.high).into());
    buf.append((salt).into());
    poseidon_hash_span(buf.span())
}
