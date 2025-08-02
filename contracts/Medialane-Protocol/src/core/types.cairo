use core::hash::{HashStateExTrait, HashStateTrait};
use core::integer::u64;
use core::poseidon::PoseidonTrait;
use openzeppelin_utils::snip12::StructHash;
use starknet::ContractAddress;
use crate::core::utils::*;

#[derive(Debug, Drop, Copy, Serde, PartialEq, Hash, starknet::Store)]
pub enum ItemType {
    #[default]
    NATIVE, // STRK
    ERC20,
    ERC721,
    ERC1155,
}

impl ItemTypeIntoFelt252 of Into<ItemType, felt252> {
    fn into(self: ItemType) -> felt252 {
        match self {
            ItemType::NATIVE => 'NATIVE',
            ItemType::ERC20 => 'ERC20',
            ItemType::ERC721 => 'ERC721',
            ItemType::ERC1155 => 'ERC1155',
        }
    }
}

impl Felt252TryIntoItemType of TryInto<felt252, ItemType> {
    fn try_into(self: felt252) -> Option<ItemType> {
        if self == 'NATIVE' {
            Option::Some(ItemType::NATIVE)
        } else if self == 'ERC20' {
            Option::Some(ItemType::ERC20)
        } else if self == 'ERC721' {
            Option::Some(ItemType::ERC721)
        } else if self == 'ERC1155' {
            Option::Some(ItemType::ERC1155)
        } else {
            Option::None
        }
    }
}

#[derive(Debug, Drop, Copy, Serde, PartialEq, Hash, starknet::Store)]
pub struct OfferItem {
    pub item_type: felt252,
    pub token: ContractAddress, // Contract address of the token (0 for NATIVE STRK)    
    pub identifier_or_criteria: felt252, // Token ID for ERC721/ERC1155, 0 for NATIVE/ERC20
    pub start_amount: felt252, // Amount for NATIVE/ERC20/ERC1155, 1 for ERC721
    pub end_amount: felt252,
}

impl OfferItemHashImpl of StructHash<OfferItem> {
    fn hash_struct(self: @OfferItem) -> felt252 {
        let hash_state = PoseidonTrait::new();
        hash_state.update_with(OFFER_ITEM_TYPE_HASH).update_with(*self).finalize()
    }
}

#[derive(Debug, Drop, Copy, Serde, Hash, PartialEq, starknet::Store)]
pub struct ConsiderationItem {
    pub item_type: felt252,
    pub token: ContractAddress, // Contract address of the token (0 for NATIVE STRK)
    pub identifier_or_criteria: felt252, // Token ID for ERC721/ERC1155, 0 for NATIVE/ERC20
    pub start_amount: felt252, // Amount for NATIVE/ERC20/ERC1155, 1 for ERC721
    pub end_amount: felt252, // Usually same as start_amount for fixed price
    pub recipient: ContractAddress // Address that receives this consideration item
}

impl ConsiderationItemHashImpl of StructHash<ConsiderationItem> {
    fn hash_struct(self: @ConsiderationItem) -> felt252 {
        let hash_state = PoseidonTrait::new();
        hash_state.update_with(CONSIDERATION_ITEM_TYPE_HASH).update_with(*self).finalize()
    }
}

#[derive(Debug, Copy, Drop, Serde, starknet::Store)]
pub struct OrderDetails {
    pub offerer: ContractAddress,
    pub offer: OfferItem,
    pub consideration: ConsiderationItem,
    pub start_time: u64,
    pub end_time: u64,
    pub order_status: OrderStatus,
    pub fulfiller: Option<ContractAddress>,
}

#[derive(Debug, Drop, Clone, Copy, Serde, Hash)]
pub struct OrderParameters {
    pub offerer: ContractAddress,
    pub offer: OfferItem,
    pub consideration: ConsiderationItem,
    pub start_time: felt252,
    pub end_time: felt252,
    pub salt: felt252,
    pub nonce: felt252,
}

impl OrderParametersHashImpl of StructHash<OrderParameters> {
    fn hash_struct(self: @OrderParameters) -> felt252 {
        let mut hash_state = PoseidonTrait::new();
        hash_state = hash_state.update_with(ORDER_PARAMETERS_TYPE_HASH);
        hash_state = hash_state.update_with(*self.offerer);
        hash_state = hash_state.update_with(self.offer.hash_struct());
        hash_state = hash_state.update_with(self.consideration.hash_struct());
        hash_state = hash_state.update_with(*self.start_time);
        hash_state = hash_state.update_with(*self.end_time);
        hash_state = hash_state.update_with(*self.salt);
        hash_state = hash_state.update_with(*self.nonce);
        hash_state.finalize()
    }
}

#[derive(Drop, Clone, Copy, Serde, Hash)]
pub struct OrderFulfillment {
    pub order_hash: felt252,
    pub fulfiller: ContractAddress,
    pub nonce: felt252,
}

impl OrderFulfillmentHashImpl of StructHash<OrderFulfillment> {
    fn hash_struct(self: @OrderFulfillment) -> felt252 {
        let hash_state = PoseidonTrait::new();
        hash_state.update_with(FULFILLMENT_TYPE_HASH).update_with(*self).finalize()
    }
}

#[derive(Debug, Drop, Clone, Copy, Serde, Hash)]
pub struct OrderCancellation {
    pub order_hash: felt252,
    pub offerer: ContractAddress,
    pub nonce: felt252,
}

impl OrderCancellationHashImpl of StructHash<OrderCancellation> {
    fn hash_struct(self: @OrderCancellation) -> felt252 {
        let hash_state = PoseidonTrait::new();
        hash_state.update_with(CANCELATION_TYPE_HASH).update_with(*self).finalize()
    }
}

#[derive(Drop, Serde)]
pub struct FulfillmentRequest {
    pub fulfillment: OrderFulfillment,
    pub signature: Array<felt252>,
}

#[derive(Drop, Serde)]
pub struct CancelRequest {
    pub cancelation: OrderCancellation,
    pub signature: Array<felt252>,
}

#[derive(Drop, Serde)]
pub struct Order {
    pub parameters: OrderParameters,
    pub signature: Array<felt252>,
}

// Status of an order hash
#[derive(Drop, Debug, Copy, Serde, starknet::Store, PartialEq)]
pub enum OrderStatus {
    #[default]
    None, // Order hasn't been seen before
    Created, // Order is registered and live
    Filled, // Order was successfully matched and filled
    Cancelled // Order was cancelled by the user or system
}


#[cfg(test)]
mod tests {
    use openzeppelin_utils::snip12::{OffchainMessageHash, SNIP12Metadata};
    use starknet::ContractAddress;
    use super::*;

    /// Required for hash computation.
    impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'Medialane'
        }
        fn version() -> felt252 {
            1
        }
    }

    pub fn OFFERER() -> ContractAddress {
        0x049c8ce76963bb0d4ae4888d373d223a1fd7c683daa9f959abe3c5cd68894f51.try_into().unwrap()
    }

    pub fn FULFILLER() -> ContractAddress {
        0x030545f9bc0a25a84d92fe8770f4f23639b960a364201df60536d34605e48538.try_into().unwrap()
    }

    pub fn TOKEN() -> ContractAddress {
        0x0589edc6e13293530fec9cad58787ed8cff1fce35c3ef80342b7b00651e04d1f.try_into().unwrap()
    }

    pub fn ERC721_TOKEN() -> ContractAddress {
        0x01be0d1cd01de34f946a40e8cc305b67ebb13bca8472484b33e408be03de39fe.try_into().unwrap()
    }

    pub fn FELT() -> felt252 {
        100_000_000_000_000_000_0000_000000000
    }

    #[test]
    fn test_valid_order_hash() {
        // This value was computed using StarknetJS
        let expected_hash = 0x75b5d71f4ccba6854dca5f11453406b4b01ffc074a301b2697f3070cf60d3d7;

        let offer = OfferItem {
            item_type: 'ERC721',
            token: ERC721_TOKEN(),
            identifier_or_criteria: 0,
            start_amount: 1,
            end_amount: 1,
        };

        let consideration = ConsiderationItem {
            item_type: 'ERC20',
            token: TOKEN(),
            identifier_or_criteria: 0,
            start_amount: 1000000,
            end_amount: 1000000,
            recipient: OFFERER(),
        };

        let order_params = OrderParameters {
            offerer: OFFERER(),
            offer,
            consideration,
            start_time: 1000000000,
            end_time: 1000003600,
            salt: 0,
            nonce: 0,
        };

        let actual_hash = order_params.get_message_hash(OFFERER());
        assert_eq!(actual_hash, expected_hash);
    }

    #[test]
    fn test_valid_fulfilment_hash() {
        // This value was computed using StarknetJS
        let expected_hash = 0x62ac39379fdbbf3441894654acdf7f22db94611599a107784297b7e52406a84;

        let cancelation = OrderFulfillment {
            order_hash: 0x75b5d71f4ccba6854dca5f11453406b4b01ffc074a301b2697f3070cf60d3d7
                .try_into()
                .unwrap(),
            fulfiller: FULFILLER(),
            nonce: 0,
        };
        let actual_hash = cancelation.get_message_hash(FULFILLER());
        assert_eq!(expected_hash, actual_hash)
    }

    #[test]
    fn test_valid_cancel_hash() {
        // This value was computed using StarknetJS
        let expected_hash = 0x3dea25b77af7b17894ffbd0b26e64bc2c6c1931d7f40f43d47e1866ab7e97cb;

        let cancelation = OrderCancellation {
            order_hash: 0x75b5d71f4ccba6854dca5f11453406b4b01ffc074a301b2697f3070cf60d3d7
                .try_into()
                .unwrap(),
            offerer: OFFERER(),
            nonce: 1,
        };
        let actual_hash = cancelation.get_message_hash(OFFERER());
        assert_eq!(expected_hash, actual_hash)
    }
}
