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
  console.log("Creating erc20 for erc721 order parameters...");
  const {
    orderParams: erc20_for_erc721_order,
    typedData: erc20_for_erc721_order_typedData,
    orderHash: erc20_for_erc721_order_hash,
    signature: erc20_for_erc721_offer_signature,
  } = await handleOrderParameters(offerer, TradeType.ERC20_FOR_ERC721);

  // === Order Fulfillment ===
  console.log("Creating erc20 for erc721 order fulfillment...");

  const {
    fulfillment: erc20_for_erc721_fulfillment,
    typedData: erc20_for_erc721_fulfillment_typedData,
    fulfillmentHash: erc20_for_erc721_fulfillment_hash,
    signature: erc20_for_erc721_fulfillment_signature,
  } = await handleOrderFulfillment(fulfiller, erc20_for_erc721_order_hash);

  // // === Order Cancellation ===
  console.log("Creating erc20 for erc721 order cancellation intent...");
  const {
    cancellation: erc20_for_erc721_cancellation,
    typedData: erc20_for_erc721_cancellation_typedData,
    signature: erc2_for_erc721_cancellation_signature,
    cancellationHash: erc20_for_erc721_cancellation_hash,
  } = await handleOrderCancellation(offerer, erc20_for_erc721_order_hash);

  console.log("writing logs");

  const logs = {
    erc20_for_erc721_order_params: stringifyBigInts(erc20_for_erc721_order),
    erc20_for_erc721_order_hash: erc20_for_erc721_order_hash,
    erc20_for_erc721_order_typedData: stringifyBigInts(
      erc20_for_erc721_order_typedData
    ),
    erc20_for_erc721_offer_signature: stringifyBigInts(
      erc20_for_erc721_offer_signature
    ),
    erc20_for_erc721_fulfillment: stringifyBigInts(
      erc20_for_erc721_fulfillment
    ),
    erc20_for_erc721_fulfillment_typedData: stringifyBigInts(
      erc20_for_erc721_fulfillment_typedData
    ),
    erc20_for_erc721_fulfillment_hash: erc20_for_erc721_fulfillment_hash,
    erc20_for_erc721_fulfillment_signature: stringifyBigInts(
      erc20_for_erc721_fulfillment_signature
    ),
    erc20_for_erc721_cancellation: stringifyBigInts(
      erc20_for_erc721_cancellation
    ),
    erc20_for_erc721_cancellation_typedData: stringifyBigInts(
      erc20_for_erc721_cancellation_typedData
    ),
    erc20_for_erc721_cancellation_hash: erc20_for_erc721_cancellation_hash,
    erc2_for_erc721_cancellation_signature: stringifyBigInts(
      erc2_for_erc721_cancellation_signature
    ),
  };

  fs.writeFileSync(
    "./scripts/out/erc20_for_erc721_order_logs.json",
    JSON.stringify(logs, null, 2)
  );
  console.log("Logs written to ./scripts/out/erc20_for_erc721_order_logs.json");
}
