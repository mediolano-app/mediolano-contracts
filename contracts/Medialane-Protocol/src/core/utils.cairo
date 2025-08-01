// selector!(
//     "\"OrderParameters\"("
//         "\"offerer\":\"ContractAddress\","
//         "\"offer\":\"OfferItem\","
//         "\"consideration\":\"ConsiderationItem\","
//         "\"start_time\":\"felt\","
//         "\"end_time\":\"felt\","
//         "\"salt\":\"felt\","
//         "\"nonce\":\"felt\""
//     ")"
//     "\"ConsiderationItem\"("
//         "\"item_type\":\"shortstring\","
//         "\"token\":\"ContractAddress\","
//         "\"identifier_or_criteria\":\"felt\","
//         "\"start_amount\":\"felt\","
//         "\"end_amount\":\"felt\","
//         "\"recipient\":\"ContractAddress\""
//     ")"
//     "\"OfferItem\"("
//         "\"item_type\":\"shortstring\","
//         "\"token\":\"ContractAddress\","
//         "\"identifier_or_criteria\":\"felt\","
//         "\"start_amount\":\"felt\","
//         "\"end_amount\":\"felt\""
//     ")"
// );

pub const ORDER_PARAMETERS_TYPE_HASH: felt252 = selector!(
    "\"OrderParameters\"(\"offerer\":\"ContractAddress\",\"offer\":\"OfferItem\",\"consideration\":\"ConsiderationItem\",\"start_time\":\"felt\",\"end_time\":\"felt\",\"salt\":\"felt\",\"nonce\":\"felt\")\"ConsiderationItem\"(\"item_type\":\"shortstring\",\"token\":\"ContractAddress\",\"identifier_or_criteria\":\"felt\",\"start_amount\":\"felt\",\"end_amount\":\"felt\",\"recipient\":\"ContractAddress\")\"OfferItem\"(\"item_type\":\"shortstring\",\"token\":\"ContractAddress\",\"identifier_or_criteria\":\"felt\",\"start_amount\":\"felt\",\"end_amount\":\"felt\")",
);

// selector!(
//   "\"OrderFulfillment\"(
//        \"order_hash\":\"felt\",
//        \"fulfiller\":\"ContractAddress\",
//        \"nonce\":\"felt\",
//    )",
// );
pub const FULFILLMENT_TYPE_HASH: felt252 = selector!(
    "\"OrderFulfillment\"(\"order_hash\":\"felt\",\"fulfiller\":\"ContractAddress\",\"nonce\":\"felt\")",
);


// selector!(
//     "\"OrderCancellation\"(
//         \"order_hash\":\"felt\",
//         \"offerer\":\"ContractAddress\",
//         \"nonce\":\"felt\"
//     )",
// );
pub const CANCELATION_TYPE_HASH: felt252 = selector!(
    "\"OrderCancellation\"(\"order_hash\":\"felt\",\"offerer\":\"ContractAddress\",\"nonce\":\"felt\")",
);


pub fn felt_to_u8(value: felt252) -> u8 {
    value.try_into().unwrap()
}

pub fn felt_to_u32(value: felt252) -> u32 {
    value.try_into().unwrap()
}

pub fn felt_to_u64(value: felt252) -> u64 {
    value.try_into().unwrap()
}

pub fn felt_to_u128(value: felt252) -> u128 {
    value.try_into().unwrap()
}

pub fn felt_to_u256(value: felt252) -> u256 {
    value.into()
}
