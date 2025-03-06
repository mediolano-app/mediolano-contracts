import { range } from "lodash";
import { StandardMerkleTree } from "@ericnordelo/strk-merkle-tree";

const values = [
  ["0x000000000000000000000000000000000000000000000000000000414c494345", "1"],
  ["0x0000000000000000000000000000000000000000000000000000000000424f42", "2"],
  ["0x00000000000000000000000000000000000000000000000000434841524c4945", "3"],
];

const tree = StandardMerkleTree.of(values, ["ContractAddress", "u32"]);

console.log(`const MERKLE_ROOT: felt252 = ${tree.root};`);

console.log(
  `const ALICE_PROOF: [felt252; ${tree.getProof(0).length}] = [${tree
    .getProof(0)
    .join(", ")}];`
);
console.log(`const ALICE_AMOUNT: u32 = ${values[0][1]};`);
console.log(
  `const ALICE_TOKEN_IDS: [u256; ALICE_AMOUNT] = [${range(
    1,
    Number(values[0][1]) + 1
  ).join(", ")}];`
);

console.log(
  `const BOB_PROOF: [felt252; ${tree.getProof(1).length}] = [${tree
    .getProof(1)
    .join(", ")}];`
);
console.log(`const BOB_AMOUNT: u32 = ${values[1][1]};`);
console.log(
  `const BOB_TOKEN_IDS: [u256; BOB_AMOUNT] = [${range(
    Number(values[0][1]) + 1,
    Number(values[1][1]) + Number(values[0][1]) + 1
  ).join(", ")}];`
);

console.log(
  `const CHARLIE_PROOF: [felt252; ${tree.getProof(2).length}] = [${tree
    .getProof(2)
    .join(", ")}];`
);
console.log(`const CHARLIE_AMOUNT: u32 = ${values[2][1]};`);
console.log(
  `const CHARLIE_TOKEN_IDS: [u256; CHARLIE_AMOUNT] = [${range(
    Number(values[0][1]) + Number(values[1][1]) + 1,
    Number(values[2][1]) + Number(values[0][1]) + Number(values[1][1]) + 1
  ).join(", ")}];`
);
