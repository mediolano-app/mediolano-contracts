"use client";
import type { NextPage } from "next";
import { useAccount } from "@starknet-react/core";
import { useState } from "react";
import { useReadContract } from "@starknet-react/core";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "../components/ui/card"
// import useTokenURILoader from '~~/hooks/useTokenURILoader'
import MyIPCard from '../components/MyIPCard';
const MyIPs: NextPage = () => {
  const { address: connectedAddress, isConnected, isConnecting } = useAccount();
  const [status, setStatus] = useState("Mint NFT");
  // contract address 0x07d4dc2bf13ede97b9e458dc401d4ff6dd386a02049de879ebe637af8299f91d
  // https://starkscan.co/nft-contract/0x07d4dc2bf13ede97b9e458dc401d4ff6dd386a02049de879ebe637af8299f91d#overview
  const contractAddress = '0x06bc665e25b8ee792447d19a2f19f8f9806b66fbd9d2924c7582a857338356e2';
  // const { tokenURIs, isLoading, error, reload } = useTokenURILoader(contractAddress);
  return (
    <div>
      <MyIPCard contractAddress={contractAddress} index={1} />
      <MyIPCard contractAddress={contractAddress} index={2} />
      <MyIPCard contractAddress={contractAddress} index={200} />
      {/* Add more cards as needed */}
    </div>
  );
  // const { writeAsync: mintItem } = useScaffoldWriteContract({
  //   contractName: "YourCollectible",
  //   functionName: "mint_item",
  //   args: [connectedAddress, ""],
  // });
  // const { data: tokenIdCounter, refetch } = useScaffoldReadContract({
  //   contractName: "YourCollectible",
  //   functionName: "current",
  //   watch: false,
  // });
  // const handleMintItem = async () => {
  //   setStatus("Minting NFT");
  //   // circle back to the zero item if we've reached the end of the array
  //   if (tokenIdCounter === undefined) {
  //     setStatus("Mint NFT");
  //     return;
  //   }
  //   const tokenIdCounterNumber = Number(tokenIdCounter);
  //   const currentTokenMetaData =
  //     nftsMetadata[tokenIdCounterNumber % nftsMetadata.length];
  //   const notificationId = notification.loading("Uploading to IPFS");
  //   try {
  //     const uploadedItem = await addToIPFS(currentTokenMetaData);
  //     // First remove previous loading notification and then show success notification
  //     notification.remove(notificationId);
  //     notification.success("Metadata uploaded to IPFS");
  //     await mintItem({
  //       args: [connectedAddress, uploadedItem.path],
  //     });
  //     setStatus("Updating IP List");
  //     refetch();
  //   } catch (error) {
  //     notification.remove(notificationId);
  //     console.error(error);
  //     setStatus("Mint NFT");
  //   }
  // };
  // return (
  //   <>
  //     <div className="flex items-center flex-col pt-10">
  //       <div className="px-5">
  //         <h1 className="text-center mb-8">
  //           <span className="block text-4xl font-bold">My IPs</span>
  //         </h1>
  //       </div>
  //     </div>
  //     <MyHoldings setStatus={setStatus} />
  //     <div className="flex items-center flex-col pt-10">
  //       <Card className="bg-main border-accent/50 rounded-full" >
  //         <CardHeader>
  //           <CardTitle>Mint Your Digital Asset</CardTitle>
  //           <CardDescription>Secure your intellectual property on the blockchain in NFT format. Fill out the form below to register your IP.</CardDescription>
  //         </CardHeader>
  //         <CardContent>
  //           <div className="flex justify-center">
  //             <a className="btn btn-secondary text-white" href="/ipfsUpload">
  //               Upload Metadata
  //             </a>
  //             &nbsp;&nbsp;
  //             {!isConnected || isConnecting ? (
  //               <CustomConnectButton />
  //             ) : (
  //               <></>
  //               // <button
  //               //   className="btn btn-secondary text-white"
  //               //   disabled={status !== "Mint NFT"}
  //               //   onClick={handleMintItem}
  //               // >
  //               //   {status !== "Mint NFT" && (
  //               //     <span className="loading loading-spinner loading-xs"></span>
  //               //   )}
  //               //   {status}
  //               // </button>
  //             )}
  //           </div>
  //         </CardContent>
  //         <CardFooter className="flex justify-between">
  //         </CardFooter>
  //       </Card>
  //     </div>
  //   </>
  // );
};
export default MyIPs;