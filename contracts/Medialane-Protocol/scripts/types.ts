import { type BigNumberish } from "starknet";

export type u256 = {
  low: BigNumberish;
  high: BigNumberish;
};

export type OfferItem = {
  item_type: BigNumberish;
  token: string;
  identifier_or_criteria: u256;
  start_amount: u256;
  end_amount: u256;
};

export type ConsiderationItem = {
  item_type: BigNumberish;
  token: string;
  identifier_or_criteria: u256;
  start_amount: u256;
  end_amount: u256;
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
