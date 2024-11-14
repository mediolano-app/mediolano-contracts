"use client";
import type { NextPage } from "next";
import { useAccount, useCall } from "@starknet-react/core";
import { useState } from "react";
import { useReadContract, useContract} from "@starknet-react/core";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "../components/ui/card"
import { type Abi } from "starknet";
import { abi } from '@/abis/abi';
import MyIPCard from '../components/MyIPCard';
import NFTCard from "@/components/NFTCard";
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

  // async function getBalance(){
  //   try {
  //     const testBalance = await contract.balance_of(accountAddress);
  //     console.log(testBalance);
  //   }
  //   catch(e) {
  //     console.log(e);
  //   }
  // };
  // getBalance();

  async function getTokenId(tokenIndex: number){
    try{
      const tokenId = await contract.token_of_owner_by_index(accountAddress, tokenIndex);
      console.log(tokenId);
      console.log(typeof tokenId);
      return tokenId; //acho que eh isso mas tem que testar
    }
    catch(e) {
      console.log(e);
    }
  }

  const { data: myTotalBalance, error: balanceError } = useReadContract({
    abi: abi as Abi,
    functionName: 'balance_of',
    address: contractAddress as `0x${string}`,
    args: [connectedAddress],
    watch: false,   
  });
  console.log(myTotalBalance);

  const { data: test, error: testError } = useReadContract({
    abi: abi as Abi, 
    functionName: 'token_of_owner_by_index',
    address: contractAddress as `0x${string}`,
    args: [connectedAddress, 0],
    watch: false,
  });
  console.log(test);

  // const { data: uri, isLoading: isUriLoading, error: UriError } = useReadContract({
  //   abi: abi as Abi,
  //   functionName: 'tokenURI',
  //   address: contractAddress as `0x${string}`,
  //   args: [8],
  //   watch: false,
  // });
  // console.log(uri); //ta puxando a uri, problema tá no tokenId que ta sendo passado
  // //no return da page

  // const { data: uri2, isLoading: isUri2Loading, error: Uri2Error } = useReadContract({
  //   abi: abi as Abi,
  //   functionName: 'tokenURI',
  //   address: contractAddress as `0x${string}`,
  //   args: [9],
  //   watch: false,
  // });
  // console.log(uri2); //ta puxando certo

  const totalBalance = myTotalBalance ? parseInt(myTotalBalance.toString()) : 0;
  useEffect(() => {
    if (totalBalance > 0) {
      const fetchTokenIds = async () => {
        const fetchedTokenIds: number[] = [];  // Changed type from BigInt[] to number[]
  
        // Use Promise.all to resolve all token ID promises concurrently
        const tokenIdPromises = Array.from({ length: totalBalance }, (_, tokenIndex) => 
          getTokenId(tokenIndex)  // Ensure getTokenId returns a promise resolving to a number
        );
  
        try {
          const resolvedTokenIds = await Promise.all(tokenIdPromises);
          
          resolvedTokenIds.forEach((tokenId) => {
            if (typeof tokenId === "bigint") {
              fetchedTokenIds.push(tokenId);  // only push if tokenId is a valid number
            } else {
              console.warn("Unexpected tokenId type:", typeof tokenId);
            }
          });
  
          setTokenIds(fetchedTokenIds);  // update state with the fetched token IDs
        } catch (e) {
          console.error("Error fetching token IDs:", e);
        }
      };
  
      fetchTokenIds(); // Execute the async function
    }
  }, [totalBalance, connectedAddress]);
  
  // useEffect(() => {
  //   if (totalBalance > 0) {
  //     // const fetchTokenIds = async () => {
  //       let fetchedTokenIds = [];
  //       for (let tokenIndex = 0; tokenIndex < totalBalance; tokenIndex++) {
  //         try {
  //           const tokenId = getTokenId(tokenIndex);
  //           console.log('ACARALHOOO');
  //             // console.log('this is the token Id', tokenId);
  //           console.log("this is the token index:", tokenIndex);
  //           if (tokenId) {
  //             fetchedTokenIds.push(tokenId);  // ta dando problema porque eh promise, resolver dps
  //             console.log(tokenId);
  //           }
  //         } catch (e) {
  //           console.error("Error fetching tokenId:", e);
  //         }
  //       }
  //       setTokenIds(fetchedTokenIds);  // update state with the fetched tokenIds
  //     // };

  //     // fetchTokenIds();
  //   }
  // }, [totalBalance, connectedAddress]);

  // contract address 0x07d4dc2bf13ede97b9e458dc401d4ff6dd386a02049de879ebe637af8299f91d
  // https://starkscan.co/nft-contract/0x07d4dc2bf13ede97b9e458dc401d4ff6dd386a02049de879ebe637af8299f91d#overview
  // const { tokenURIs, isLoading, error, reload } = useTokenURILoader(contractAddress);

  
  return (
    <div>
      aaaaaaaa
      {/* {tokenIds.map((tokenId, index) => ( 
        <MyIPCard key={index} contractAddress={contractAddress} tokenId={tokenId} />
      ))} */}
      <NFTCard key = {1} tokenId = {8n} status={"teste"} />
    </div>
  );
};
export default MyIPs;