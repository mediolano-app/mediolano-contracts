import { createConsiderationItem, createOfferItem } from "./utils";

export const offerer_address =
  "0x049c8ce76963bb0d4ae4888d373d223a1fd7c683daa9f959abe3c5cd68894f51";
export const fulfiller_address =
  "0x030545f9bc0a25a84d92fe8770f4f23639b960a364201df60536d34605e48538";
export const offerer_pk =
  "0x00000000000000000000000000000000d2fbf4eebcadc6998287ee8eed992cec";
export const fulfiller_pk =
  "0x00000000000000000000000000000000bf4f7a31fa458944fbe8816eb1c978cf";

const erc721_address =
  "0x01be0d1cd01de34f946a40e8cc305b67ebb13bca8472484b33e408be03de39fe";

const erc20_address =
  "0x0589edc6e13293530fec9cad58787ed8cff1fce35c3ef80342b7b00651e04d1f";

const erc1155_address =
  "0x07ca2d381f55b159ea4c80abf84d4343fde9989854a6be2f02585daae7d89d76";

export const erc721OfferItem = createOfferItem(
  "ERC721",
  erc721_address,
  1,
  1,
  0 // token_id
);

export const erc721ConsiderationItem = createConsiderationItem(
  "ERC721",
  erc721_address,
  1,
  1,
  0, // token_id
  offerer_address
);

export const nativeOfferItem = createOfferItem(
  "NATIVE",
  erc20_address,
  1000000,
  1000000,
  0
);

export const nativeConsiderationItem = createConsiderationItem(
  "NATIVE",
  erc20_address,
  1000000,
  1000000,
  0,
  offerer_address
);

export const erc20OfferItem = createOfferItem(
  "ERC20",
  erc20_address,
  1000000,
  1000000,
  0
);

export const erc20ConsiderationItem = createConsiderationItem(
  "ERC20",
  erc20_address,
  1000000,
  1000000,
  0,
  offerer_address
);

export const erc1155OfferItem = createOfferItem(
  "ERC1155",
  erc1155_address,
  1000,
  1000,
  0
);

export const erc1155ConsiderationItem = createConsiderationItem(
  "ERC1155",
  erc1155_address,
  1000,
  1000,
  0,
  offerer_address
);
