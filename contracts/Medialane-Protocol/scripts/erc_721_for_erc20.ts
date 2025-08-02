import { TradeType } from "./types";
import {
  initializeAccountsAndProvider,
  handleOrderParameters,
  handleOrderFulfillment,
  handleOrderCancellation,
  stringifyBigInts,
} from "./utils";

import * as fs from "fs";

export async function run() {
  // === Initialization ===
  const { offerer, fulfiller } = initializeAccountsAndProvider();
  console.log("✅ offerer and fulfiller connected.");

  // === Order Parameters ===
  console.log("Creating erc721 for erc20 order parameters...");
  const {
    orderParams: erc721_for_erc20_order,
    typedData: erc721_for_erc20_order_typedData,
    orderHash: erc721_for_erc20_order_hash,
    signature: erc721_for_erc20_offer_signature,
  } = await handleOrderParameters(offerer, TradeType.ERC721_FOR_ERC20);

  // === Order Fulfillment ===
  console.log("Creating erc721 for erc20 order fulfillment...");
  const {
    fulfillment: erc721_for_erc20_fulfillment,
    typedData: erc721_for_erc20_fulfillment_typedData,
    fulfillmentHash: erc721_for_erc20_fulfillment_hash,
    signature: erc721_for_erc20_fulfillment_signature,
  } = await handleOrderFulfillment(fulfiller, erc721_for_erc20_order_hash);

  // === Order Cancellation ===
  console.log("Creating erc721 for erc20 order cancellation intent...");
  const {
    cancellation: erc721_for_erc20_cancellation,
    typedData: erc721_for_erc20_cancellation_typedData,
    signature: erc721_for_erc20_cancellation_signature,
    cancellationHash: erc721_for_erc20_cancellation_hash,
  } = await handleOrderCancellation(offerer, erc721_for_erc20_order_hash);

  console.log("writing logs");

  const logs = {
    erc721_for_erc20_order_params: stringifyBigInts(erc721_for_erc20_order),
    erc721_for_erc20_order_hash: erc721_for_erc20_order_hash,
    erc721_for_erc20_order_typedData: stringifyBigInts(
      erc721_for_erc20_order_typedData
    ),
    erc721_for_erc20_offer_signature: stringifyBigInts(
      erc721_for_erc20_offer_signature
    ),
    erc721_for_erc20_fulfillment: stringifyBigInts(
      erc721_for_erc20_fulfillment
    ),
    erc721_for_erc20_fulfillment_typedData: stringifyBigInts(
      erc721_for_erc20_fulfillment_typedData
    ),
    erc721_for_erc20_fulfillment_hash: erc721_for_erc20_fulfillment_hash,
    erc721_for_erc20_fulfillment_signature: stringifyBigInts(
      erc721_for_erc20_fulfillment_signature
    ),
    erc721_for_erc20_cancellation: stringifyBigInts(
      erc721_for_erc20_cancellation
    ),
    erc721_for_erc20_cancellation_typedData: stringifyBigInts(
      erc721_for_erc20_cancellation_typedData
    ),
    erc721_for_erc20_cancellation_hash: erc721_for_erc20_cancellation_hash,
    erc721_for_erc20_cancellation_signature: stringifyBigInts(
      erc721_for_erc20_cancellation_signature
    ),
  };

  fs.writeFileSync(
    "./scripts/out/erc721_for_erc20_order_logs.json",
    JSON.stringify(logs, null, 2)
  );
  console.log("Logs written to ./scripts/out/erc721_for_erc20_order_logs.json");
}
