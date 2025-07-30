import { u256, OfferItem, ConsiderationItem } from "./types";

export const dummyIdentifier: u256 = {
  low: 1,
  high: 0,
};

export const dummyU256: u256 = {
  low: 10000,
  high: 0,
};

export const dummyOfferItem: OfferItem = {
  item_type: 0,
  token: "0xWSTRK",
  identifier_or_criteria: dummyIdentifier,
  start_amount: dummyU256,
  end_amount: dummyU256,
};

export const dummyConsiderationItem: ConsiderationItem = {
  item_type: 1,
  token: "0xNFT",
  identifier_or_criteria: dummyIdentifier,
  start_amount: dummyU256,
  end_amount: dummyU256,
  recipient: "0x2001",
};
