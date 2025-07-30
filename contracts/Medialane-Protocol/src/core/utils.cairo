pub fn order_parameters_type_hash() -> felt252 {
    selector!(
        "\"OrderParameters\"(
            \"offerer\":\"ContractAddress\",
            \"offer\":\"OfferItem\",
            \"consideration\":\"ConsiderationItem\",
            \"start_time\":\"timestamp\",
            \"end_time\":\"timestamp\",
            \"salt\":\"felt\",
            \"nonce\":\"felt\"
        )
        \"ConsiderationItem\"(
            \"item_type\":\"felt\",
            \"token\":\"ContractAddress\",
            \"identifier_or_criteria\":\"u256\",
            \"start_amount\":\"u256\",
            \"end_amount\":\"u256\",
            \"recipient\":\"ContractAddress\"
        )
        \"OfferItem\"(
            \"item_type\":\"felt\",
            \"token\":\"ContractAddress\",
            \"identifier_or_criteria\":\"u256\",
            \"start_amount\":\"u256\",
            \"end_amount\":\"u256\"
        )
        \"u256\"(
            \"low\":\"u128\",
            \"high\":\"u128\"
        )",
    )
}

pub fn fulfillment_intent_type_hash() -> felt252 {
    selector!(
        "\"FulfillmentIntent\"(
            \"order_hash\":\"felt\",
            \"fulfiller\":\"ContractAddress\",
            \"nonce\":\"felt\",
        )",
    )
}

pub fn cancel_intent_type_hash() -> felt252 {
    selector!(
        "\"CancelIntent\"(
            \"order_hash\":\"felt\",
            \"offerer\":\"ContractAddress\",
            \"nonce\":\"felt\"
        )",
    )
}
