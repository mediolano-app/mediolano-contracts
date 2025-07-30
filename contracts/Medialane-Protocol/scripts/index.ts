import {
  Account,
  ec,
  hash,
  json,
  Contract,
  encode,
  shortString,
  WeierstrassSignatureType,
  ArraySignatureType,
  stark,
  RpcProvider,
  Signature,
  num,
  type TypedData,
  constants,
  TypedDataRevision,
  typedData,
} from "starknet";

import * as dotenv from "dotenv";
import fs from "fs";
import { getOrderParametersTypedData } from "./utils";

dotenv.config();

async function main() {
  //initialize Provider with DEVNET, reading .env file
  const provider = new RpcProvider({ nodeUrl: "http://127.0.0.1:5050/rpc" });
  console.log("Provider connected");

  const offerer = new Account(provider, "0x2001", "0x9776453623451351");
  const fulfiller = new Account(provider, "0x3001", "0x56453623451351");
  console.log("✅ offerer and fulfiller connected.");

  //   const signature2: Signature = (await account.signMessage(
  //     typedDataValidate
  // )) as WeierstrassSignatureType;
}
