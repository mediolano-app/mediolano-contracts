import { type TypedData, constants, TypedDataRevision } from "starknet";
import {
  OrderParameters,
  OrderCancellation,
  OrderFulfillment,
  ConsiderationItem,
  OfferItem,
  u256,
} from "./types";
import {
  dummyOfferItem,
  dummyConsiderationItem,
  dummyU256,
  dummyIdentifier,
} from "./constants";

export function getOrderParametersTypedData(
  message: OrderParameters,
  chainId = constants.StarknetChainId.SN_SEPOLIA
): TypedData {
  return {
    domain: {
      name: "Medialane",
      version: "1.0.0",
      chainId,
      revision: TypedDataRevision.ACTIVE,
    },
    primaryType: "OrderParameters",
    types: {
      StarknetDomain: [
        { name: "name", type: "shortstring" },
        { name: "version", type: "shortstring" },
        { name: "chainId", type: "shortstring" },
      ],
      u256: [
        { name: "low", type: "u128" },
        { name: "high", type: "u128" },
      ],
      OfferItem: [
        { name: "item_type", type: "felt" },
        { name: "token", type: "ContractAddress" },
        { name: "identifier_or_criteria", type: "u256" },
        { name: "start_amount", type: "u256" },
        { name: "end_amount", type: "u256" },
      ],
      ConsiderationItem: [
        { name: "item_type", type: "felt" },
        { name: "token", type: "ContractAddress" },
        { name: "identifier_or_criteria", type: "u256" },
        { name: "start_amount", type: "u256" },
        { name: "end_amount", type: "u256" },
        { name: "recipient", type: "ContractAddress" },
      ],
      OrderParameters: [
        { name: "offerer", type: "ContractAddress" },
        { name: "taker", type: "ContractAddress" },
        { name: "offer", type: "OfferItem" },
        { name: "consideration", type: "ConsiderationItem" },
        { name: "start_time", type: "timestamp" },
        { name: "end_time", type: "timestamp" },
        { name: "salt", type: "felt" },
        { name: "nonce", type: "felt" },
      ],
    },
    message,
  };
}

export function getOrderCancellationTypedData(
  message: OrderCancellation,
  chainId = constants.StarknetChainId.SN_SEPOLIA
): TypedData {
  return {
    domain: {
      name: "Medialane",
      version: "1.0.0",
      chainId,
      revision: TypedDataRevision.ACTIVE,
    },
    primaryType: "OrderCancellation",
    types: {
      StarknetDomain: [
        { name: "name", type: "shortstring" },
        { name: "version", type: "shortstring" },
        { name: "chainId", type: "shortstring" },
      ],
      OrderCancellation: [
        { name: "order_hash", type: "felt" },
        { name: "offerer", type: "ContractAddress" },
        { name: "nonce", type: "felt" },
      ],
    },
    message,
  };
}

export function getOrderFulfillmentTypedData(
  message: OrderFulfillment,
  chainId = constants.StarknetChainId.SN_SEPOLIA
): TypedData {
  return {
    domain: {
      name: "Medialane",
      version: "1.0.0",
      chainId,
      revision: TypedDataRevision.ACTIVE,
    },
    primaryType: "OrderFulfillment",
    types: {
      StarknetDomain: [
        { name: "name", type: "shortstring" },
        { name: "version", type: "shortstring" },
        { name: "chainId", type: "shortstring" },
      ],
      OrderFulfillment: [
        { name: "order_hash", type: "felt" },
        { name: "fulfiller", type: "ContractAddress" },
        { name: "nonce", type: "felt" },
      ],
    },
    message,
  };
}

export const createOrderParameters = (
  nonce: number,
  offerItem: OfferItem = dummyOfferItem,
  considerationItem: ConsiderationItem = dummyConsiderationItem
): OrderParameters => ({
  offerer: "0x2001",
  offer: offerItem,
  consideration: considerationItem,
  start_time: 1700000000,
  end_time: 1700003600,
  salt: 42,
  nonce,
});

export const createOrderFulfillment = (
  order_hash: string,
  fulfiller = "0x3001",
  nonce = 0
): OrderFulfillment => ({
  order_hash,
  fulfiller,
  nonce,
});

export const createOrderCancellation = (
  order_hash: string,
  offerer = "0x2001",
  nonce = 1
): OrderCancellation => ({
  order_hash,
  offerer,
  nonce,
});

export const createOfferItem = (
  item_type = 0,
  token = "0xWSTRK",
  start_amount: u256 = dummyU256,
  end_amount: u256 = dummyU256,
  identifier: u256 = dummyIdentifier
): OfferItem => ({
  item_type,
  token,
  identifier_or_criteria: identifier,
  start_amount: start_amount,
  end_amount: end_amount,
});

export const createConsiderationItem = (
  item_type = 0,
  token = "0xNFT",
  start_amount: u256 = dummyU256,
  end_amount: u256 = dummyU256,
  identifier: u256 = dummyIdentifier,
  recipient = "0x2001"
): ConsiderationItem => ({
  item_type,
  token,
  identifier_or_criteria: identifier,
  start_amount: start_amount,
  end_amount: end_amount,
  recipient,
});
