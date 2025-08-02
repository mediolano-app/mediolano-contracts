import {
  type TypedData,
  Account,
  BigNumberish,
  constants,
  ec,
  RpcProvider,
  Signature,
  typedData,
  TypedDataRevision,
  WeierstrassSignatureType,
  stark,
} from "starknet";
import {
  OrderParameters,
  OrderCancellation,
  OrderFulfillment,
  ConsiderationItem,
  OfferItem,
  TradeType,
} from "./types";
import {
  offerer_address,
  offerer_pk,
  fulfiller_address,
  fulfiller_pk,
  erc721OfferItem,
  erc20ConsiderationItem,
  erc20OfferItem,
  erc721ConsiderationItem,
  offerer_publickey,
} from "./constants";

export function getOrderParametersTypedData(
  message: OrderParameters
): TypedData {
  return {
    domain: {
      name: "Medialane",
      chainId: constants.StarknetChainId.SN_SEPOLIA,
      version: "1",
      revision: TypedDataRevision.ACTIVE,
    },
    primaryType: "OrderParameters",
    types: {
      StarknetDomain: [
        {
          name: "name",
          type: "shortstring",
        },
        {
          name: "version",
          type: "shortstring",
        },
        {
          name: "chainId",
          type: "shortstring",
        },
        {
          name: "revision",
          type: "shortstring",
        },
      ],
      OrderParameters: [
        {
          name: "offerer",
          type: "ContractAddress",
        },
        {
          name: "offer",
          type: "OfferItem",
        },
        {
          name: "consideration",
          type: "ConsiderationItem",
        },
        {
          name: "start_time",
          type: "felt",
        },
        {
          name: "end_time",
          type: "felt",
        },
        {
          name: "salt",
          type: "felt",
        },
        {
          name: "nonce",
          type: "felt",
        },
      ],
      ConsiderationItem: [
        {
          name: "item_type",
          type: "shortstring",
        },
        {
          name: "token",
          type: "ContractAddress",
        },
        {
          name: "identifier_or_criteria",
          type: "felt",
        },
        {
          name: "start_amount",
          type: "felt",
        },
        {
          name: "end_amount",
          type: "felt",
        },
        {
          name: "recipient",
          type: "ContractAddress",
        },
      ],
      OfferItem: [
        {
          name: "item_type",
          type: "shortstring",
        },
        {
          name: "token",
          type: "ContractAddress",
        },
        {
          name: "identifier_or_criteria",
          type: "felt",
        },
        {
          name: "start_amount",
          type: "felt",
        },
        {
          name: "end_amount",
          type: "felt",
        },
      ],
    },
    message,
  };
}

export function getOrderCancellationTypedData(
  message: OrderCancellation
): TypedData {
  return {
    domain: {
      name: "Medialane",
      chainId: constants.StarknetChainId.SN_SEPOLIA,
      version: "1",
      revision: TypedDataRevision.ACTIVE,
    },
    primaryType: "OrderCancellation",
    types: {
      StarknetDomain: [
        {
          name: "name",
          type: "shortstring",
        },
        {
          name: "version",
          type: "shortstring",
        },
        {
          name: "chainId",
          type: "shortstring",
        },
        {
          name: "revision",
          type: "shortstring",
        },
      ],
      OrderCancellation: [
        {
          name: "order_hash",
          type: "felt",
        },
        {
          name: "offerer",
          type: "ContractAddress",
        },
        {
          name: "nonce",
          type: "felt",
        },
      ],
    },
    message,
  };
}

export function getOrderFulfillmentTypedData(
  message: OrderFulfillment
): TypedData {
  return {
    domain: {
      name: "Medialane",
      chainId: constants.StarknetChainId.SN_SEPOLIA,
      version: "1",
      revision: TypedDataRevision.ACTIVE,
    },
    primaryType: "OrderFulfillment",
    types: {
      StarknetDomain: [
        {
          name: "name",
          type: "shortstring",
        },
        {
          name: "version",
          type: "shortstring",
        },
        {
          name: "chainId",
          type: "shortstring",
        },
        {
          name: "revision",
          type: "shortstring",
        },
      ],
      OrderFulfillment: [
        {
          name: "order_hash",
          type: "felt",
        },
        {
          name: "fulfiller",
          type: "ContractAddress",
        },
        {
          name: "nonce",
          type: "felt",
        },
      ],
    },
    message,
  };
}

export function createOrderParameters(
  nonce: BigNumberish,
  offer: OfferItem,
  consideration: ConsiderationItem
): OrderParameters {
  return {
    offerer: offerer_address,
    offer: offer,
    consideration: consideration,
    start_time: 1000000000,
    end_time: 1000003600,
    salt: 0,
    nonce,
  };
}

export function createOrderFulfillment(
  order_hash: BigNumberish,
  fulfiller: string,
  nonce: BigNumberish
): OrderFulfillment {
  return {
    order_hash,
    fulfiller,
    nonce,
  };
}

export function createOrderCancellation(
  order_hash: BigNumberish,
  offerer: string,
  nonce: BigNumberish
): OrderCancellation {
  return {
    order_hash,
    offerer,
    nonce,
  };
}

export function createOfferItem(
  item_type: string,
  token: string,
  start_amount: BigNumberish,
  end_amount: BigNumberish,
  identifier_or_criteria: BigNumberish
): OfferItem {
  return {
    item_type,
    token,
    identifier_or_criteria,
    start_amount,
    end_amount,
  };
}

export function createConsiderationItem(
  item_type: string,
  token: string,
  start_amount: BigNumberish,
  end_amount: BigNumberish,
  identifier_or_criteria: BigNumberish,
  recipient: string
): ConsiderationItem {
  return {
    item_type,
    token,
    identifier_or_criteria: identifier_or_criteria,
    start_amount: start_amount,
    end_amount: end_amount,
    recipient,
  };
}

export function stringifyBigInts(obj: any): any {
  if (typeof obj === "bigint") {
    return obj.toString();
  } else if (Array.isArray(obj)) {
    return obj.map(stringifyBigInts);
  } else if (obj && typeof obj === "object") {
    const res: any = {};
    for (const key of Object.keys(obj)) {
      res[key] = stringifyBigInts(obj[key]);
    }
    return res;
  }
  return obj;
}

/**
 * Initializes Starknet accounts and provider.
 */
export function initializeAccountsAndProvider() {
  // Connect to local devnet RPC provider
  const provider = new RpcProvider({ nodeUrl: "http://127.0.0.1:5050/rpc" });
  // Create offerer and fulfiller accounts
  const offerer = new Account({
    provider,
    address: offerer_address,
    signer: offerer_pk,
  });

  const fulfiller = new Account({
    provider,
    address: fulfiller_address,
    signer: fulfiller_pk,
  });

  // const offerer = new Account(provider, offerer_address, offerer_pk);
  // const fulfiller = new Account(provider, fulfiller_address, fulfiller_pk);
  return { provider, offerer, fulfiller };
}

/**
 * Handles order parameter creation and signing.
 */
export async function handleOrderParameters(
  offerer: Account,
  trade_type: TradeType
) {
  // Create order parameters for ERC20 <-> ERC721 trade
  let offerItem: OfferItem;
  let considerationItem: ConsiderationItem;

  switch (trade_type) {
    case TradeType.ERC20_FOR_ERC721:
      offerItem = erc721OfferItem;
      considerationItem = erc20ConsiderationItem;
      break;
    case TradeType.ERC721_FOR_ERC20:
      offerItem = erc20OfferItem;
      considerationItem = erc721ConsiderationItem;
      break;
    default:
      throw new Error("Unsupported trade type");
  }

  const orderParams = createOrderParameters(0, offerItem, considerationItem);
  const TypedData = getOrderParametersTypedData(orderParams);

  const fullpubkey = stark.getFullPublicKey(offerer_pk);

  const orderHash = await offerer.hashMessage(TypedData);

  const signature: Signature = (await offerer.signMessage(
    TypedData
  )) as WeierstrassSignatureType;

  const isValid = typedData.verifyMessage(
    TypedData,
    signature,
    fullpubkey,
    offerer_address
  );

  const v = await offerer.verifyMessageInStarknet(
    TypedData,
    signature,
    offerer_address
  );

  if (!v) {
    throw new Error("Invalid signature");
  }

  return { orderParams, typedData: TypedData, orderHash, signature };
}

/**
 * Handles order fulfillment creation and signing.
 */
export async function handleOrderFulfillment(
  fulfiller: Account,
  orderHash: string
) {
  // Create fulfillment intent for the order
  const fulfillment = createOrderFulfillment(orderHash, fulfiller_address, 0);
  const typedData = getOrderFulfillmentTypedData(fulfillment);
  const fulfillmentHash = await fulfiller.hashMessage(typedData);
  const signature: Signature = (await fulfiller.signMessage(
    typedData
  )) as WeierstrassSignatureType;

  return { fulfillment, typedData, fulfillmentHash, signature };
}

/**
 * Handles order cancellation intent creation and signing.
 */
export async function handleOrderCancellation(
  offerer: Account,
  orderHash: string
) {
  // Create cancellation intent for the order
  const cancellation = createOrderCancellation(orderHash, offerer_address, 1);
  const typedData = getOrderCancellationTypedData(cancellation);
  const cancellationHash = await offerer.hashMessage(typedData);
  const signature: Signature = (await offerer.signMessage(
    typedData
  )) as WeierstrassSignatureType;

  return { cancellation, cancellationHash, typedData, signature };
}
