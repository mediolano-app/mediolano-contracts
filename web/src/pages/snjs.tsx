"use client";
import type { NextPage } from "next";
import { useAccount, useCall } from "@starknet-react/core";
import { useState } from "react";
import { useReadContract, useContract} from "@starknet-react/core";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "../components/ui/card"
import { type Abi } from "starknet";
import { abi } from '@/abis/abi';
import MyIPCard from '../components/MyIPCard';
import { useEffect } from "react";

import { Account, RpcProvider, Contract, json, ec } from 'starknet';

// import fs from 'fs';

// import * as dotenv from 'dotenv';
// dotenv.config();


const MyIPs: NextPage = () => {
  const provider = new RpcProvider({
    // nodeUrl: 'https://starknet-sepolia.infura.io/v3/' + process.env.INFURA_API_KEY,
    nodeUrl: 'https://starknet-sepolia.public.blastapi.io/rpc/v0_7'
  });

  const resp = provider.getBlockNumber();
  console.log(resp);

  const accountAddress = '0x071e83e00e1957a1b1dd30964de54a44739c5ea83142edbe63c6c4188bef5200';
  const contractAddress = '0x07e39e39ddee958c8a9221d82f639aa9112d6789259ccf09f2a7eb8e021c051c';
  const privateKey = process.env.PRIVATE_KEY;


  const account = new Account(provider, accountAddress, privateKey);

  // const compiledContract = json.parse(
  //   fs.readFileSync('/home/pedrorosalba/Mediolano/mediolano-dapp/snfoundry/contracts/target/dev/contracts_YourCollectible.contract_class.json').toString('ascii')
  // );
  // const myContract = new Contract(compiledContract.abi, contractAddress, provider);
  
  // const {abi: myAbi} = await provider.getClassAt(contractAddress);

  // if (myAbi == undefined) {
  //   throw new Error ('no abi');
  // }
  // const myContract = new Contract(myAbi, contractAddress, provider)
  
  const myContract = new Contract(abi, contractAddress, provider);
  console.log(myContract);
  
  async function getBalance(){
    try {
      const totalBalance = await myContract.balance_of(accountAddress);
      console.log(totalBalance);
      const myTotalBalance = parseInt(totalBalance.toString());
      console.log(myTotalBalance);
    }
    catch(e) {
      console.log(e);
    }
  };
  getBalance();


  // const totalBalance = myContract.balance_of(accountAddress);
    // console.log(totalBalance);

  const { address: connectedAddress, isConnected, isConnecting } = useAccount();

//   const [tokenIds, setTokenIds] = useState<BigInt[]>([]);

  const { contract } = useContract({ 
    abi: abi as Abi, 
    address: contractAddress, 
  }); 
  const { data: testBalance, error: balanceError } = useReadContract({
    abi: abi as Abi,
    functionName: 'balance_of',
    address: contractAddress as `0x${string}`,
    args: [connectedAddress],
    watch: false, 
  });
  console.log(testBalance);

//   const { data: tokenUris, error: ownedError } = useCall({
//     abi: abi as Abi,
//     functionName: 'token_uris',
//     address: contractAddress as `0x${string}`,
//     watch: false,
//   });

//   console.log(tokenUris);

//   const { data: test, error: testError } = useReadContract({
//     abi: abi as Abi, 
//     functionName: 'token_of_owner_by_index',
//     address: contractAddress as `0x${string}`,
//     args: [connectedAddress, 0],
//     watch: false,
//   });
//   console.log(test);

//   const totalBalance = myTotalBalance ? parseInt(myTotalBalance.toString()) : 0;

// for(let tokenIndex=0; tokenIndex < totalBalance; tokenIndex++){
//   try {
//     const tokenId = useReadContract({
//       abi: abi as Abi,
//       functionName: 'token_of_owner_by_index',
//       address: contractAddress as `0x${string}`,
//       args: [connectedAddress, BigInt(tokenIndex)],
//       watch: false,
//     });

//   }
//   catch (e){
//     console.log(e);
//   }
// }

//   useEffect(() => {
//     if (totalBalance > 0) {
//       // const fetchTokenIds = async () => {
//         let fetchedTokenIds: BigInt[] = [];
//         for (let tokenIndex = 0; tokenIndex < totalBalance; tokenIndex++) {
//           try {
//             const { data: tokenId } = useReadContract({
//               abi: abi as Abi,
//               functionName: 'token_of_owner_by_index',
//               address: contractAddress as `0x${string}`,
//               args: [connectedAddress, BigInt(tokenIndex)],
//               watch: false,
//             });
//             if (tokenId) {
//               fetchedTokenIds.push(tokenId);  // store tokenId in the array
//               console.log(tokenId);
//             }
//           } catch (e) {
//             console.error("Error fetching tokenId:", e);
//           }
//         }
//         setTokenIds(fetchedTokenIds);  // update state with the fetched tokenIds
//       // };

//       // fetchTokenIds();
//     }
//   }, [totalBalance, connectedAddress]);

// contract address 0x07d4dc2bf13ede97b9e458dc401d4ff6dd386a02049de879ebe637af8299f91d
// https://starkscan.co/nft-contract/0x07d4dc2bf13ede97b9e458dc401d4ff6dd386a02049de879ebe637af8299f91d#overview
// const { tokenURIs, isLoading, error, reload } = useTokenURILoader(contractAddress);

  
  return (
    <div>
      aaaaaaaa
      {/* {tokenIds.map((tokenId, index) => ( 
        <MyIPCard key={index} contractAddress={contractAddress} tokenId={tokenId} />
      ))} */}
    </div>
  );
};
export default MyIPs;