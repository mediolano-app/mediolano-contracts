export const abi = [
  {
    type: "impl",
    name: "YourCollectibleImpl",
    interface_name: "IP::IYourCollectible"
  },
  // {
  //   type: "struct",
  //   name: "core::integer::u256",
  //   members: [
  //     { name: "low", type: "core::integer::u128" },
  //     { name: "high", type: "core::integer::u128" }
  //   ]
  // },
  {
    type: "interface",
    name: "IP::IYourCollectible",
    items: [
      {
        type: "function",
        name: "mint_item",
        inputs: [{ 
          name: "recipient",
          type: "core::starknet::contract_address::ContractAddress" 
        }, 
        {
          name: "uri", 
          type: "core::byte_array::ByteArray"
        }],
        outputs: [{
          name: "token_id",
          type: "core::integer::u128"
        }],
        state_mutability: "external"
      },
    ]
  },
  // { 
  //   type: "event",
  //   name: "workshop_frontend::HelloStarknet::BalanceIncreased",
  //   kind: "struct",
  //   members: [
  //     {
  //       name: "sender",
  //       type: "core::starknet::contract_address::ContractAddress",
  //       kind: "key"
  //     },
  //     { name: "amount", type: "core::integer::u256", kind: "data" },
  //     { name: "new_balance", type: "core::integer::u256", kind: "data" }
  //   ]
  // },
  // {
  //   type: "event",
  //   name: "workshop_frontend::HelloStarknet::Event",
  //   kind: "enum",
  //   variants: [
  //     {
  //       name: "BalanceIncreased",
  //       type: "workshop_frontend::HelloStarknet::BalanceIncreased",
  //       kind: "nested"
  //     }
  //   ]
  // }
] as const;