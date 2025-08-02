import { createConsiderationItem, createOfferItem } from "./utils";

export const offerer_address =
  "0x040204472aef47d0aa8d68316e773f09a6f7d8d10ff6d30363b353ef3f2d1305";
export const offerer_publickey =
  "0x05c9bc4f9800eef3186980708ecedee4f056a4542abd7a24713b07680eda4346";
export const offerer_pk =
  "0x00000000000000000000000000000000132869a604812ac7bd9cb0ec552265bd";

export const fulfiller_address =
  "0x01d0c57c28e34bf6407c2fbfadbda7ae59d39ff9c8f9ac4ec3fa32ec784fb549";
export const fulfiller_pk =
  "0x000000000000000000000000000000006ef5e89c9de81186a9a127b22cd5ba86";
export const fulfiller_publickey =
  "0x0349afcb9441c4a8ab36d0d04e671479f78c5df5812ec8e5ddec4742d2bb2bec";

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
