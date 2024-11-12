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

const MyIPs: NextPage = () => {
  const { address: connectedAddress, isConnected, isConnecting } = useAccount();
  const contractAddress = '0x07e39e39ddee958c8a9221d82f639aa9112d6789259ccf09f2a7eb8e021c051c';
  const accountAddress = '0x04d9e99204dbfe644fc5ed7529d983ed809b7a356bf0c84daade57bcbb9c0c77';

  const [tokenIds, setTokenIds] = useState<BigInt[]>([]);

  const { contract } = useContract({ 
    abi: abi as Abi, 
    address: contractAddress, 
  }); 

  async function getBalance(){
    try {
      const testBalance = await contract.balance_of(accountAddress);
      console.log(testBalance);
    }
    catch(e) {
      console.log(e);
    }
  };
  getBalance();

  const { data: myTotalBalance, error: balanceError } = useReadContract({
    abi: abi as Abi,
    functionName: 'balance_of',
    address: contractAddress as `0x${string}`,
    args: [connectedAddress],
    watch: false,   
  });

  console.log(myTotalBalance);

  const { data: tokenUris, error: ownedError } = useCall({
    abi: abi as Abi,
    functionName: 'token_uris',
    address: contractAddress as `0x${string}`,
    watch: false,
  });

  console.log(tokenUris);

  const { data: test, error: testError } = useReadContract({
    abi: abi as Abi, 
    functionName: 'token_of_owner_by_index',
    address: contractAddress as `0x${string}`,
    args: [connectedAddress, 0],
    watch: false,
  });
  console.log(test);

  const totalBalance = myTotalBalance ? parseInt(myTotalBalance.toString()) : 0;

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

  useEffect(() => {
    if (totalBalance > 0) {
      // const fetchTokenIds = async () => {
        let fetchedTokenIds: BigInt[] = [];
        for (let tokenIndex = 0; tokenIndex < totalBalance; tokenIndex++) {
          try {
            const { data: tokenId } = useReadContract({
              abi: abi as Abi,
              functionName: 'token_of_owner_by_index',
              address: contractAddress as `0x${string}`,
              args: [connectedAddress, BigInt(tokenIndex)],
              watch: false,
            });
            if (tokenId) {
              fetchedTokenIds.push(tokenId);  // store tokenId in the array
              console.log(tokenId);
            }
          } catch (e) {
            console.error("Error fetching tokenId:", e);
          }
        }
        setTokenIds(fetchedTokenIds);  // update state with the fetched tokenIds
      // };

      // fetchTokenIds();
    }
  }, [totalBalance, connectedAddress]);

  // contract address 0x07d4dc2bf13ede97b9e458dc401d4ff6dd386a02049de879ebe637af8299f91d
  // https://starkscan.co/nft-contract/0x07d4dc2bf13ede97b9e458dc401d4ff6dd386a02049de879ebe637af8299f91d#overview
  // const { tokenURIs, isLoading, error, reload } = useTokenURILoader(contractAddress);

  
  return (
    <div>
      aaaaaaaa
      {tokenIds.map((tokenId, index) => ( 
        <MyIPCard key={index} contractAddress={contractAddress} tokenId={tokenId} />
      ))}
    </div>
  );
};
export default MyIPs;