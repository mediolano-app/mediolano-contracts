import { type BigNumberish } from "starknet";

export type OfferItem = {
  item_type: string;
  token: string;
  identifier_or_criteria: BigNumberish;
  start_amount: BigNumberish;
  end_amount: BigNumberish;
};

export type ConsiderationItem = {
  item_type: string;
  token: string;
  identifier_or_criteria: BigNumberish;
  start_amount: BigNumberish;
  end_amount: BigNumberish;
  recipient: string;
};

export type OrderParameters = {
  offerer: string;
  offer: OfferItem;
  consideration: ConsiderationItem;
  start_time: BigNumberish;
  end_time: BigNumberish;
  salt: BigNumberish;
  nonce: BigNumberish;
};

export type OrderFulfillment = {
  order_hash: BigNumberish;
  fulfiller: string;
  nonce: BigNumberish;
};

export type OrderCancellation = {
  order_hash: BigNumberish;
  offerer: string;
  nonce: BigNumberish;
};

export enum TradeType {
  ERC20_FOR_ERC721 = "ERC20_FOR_ERC721",
  ERC721_FOR_ERC20 = "ERC721_FOR_ERC20",
}
