'use client'

import React, { useState, useEffect } from 'react'
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { Eye, DollarSign, Send, MoreHorizontal, Search, Grid, List, FileText, Zap } from "lucide-react"
import Image from "next/image"
import {abi} from "../../src/abis/abi"
import {type Abi} from "starknet"
import { useReadContract } from "@starknet-react/core";
import { pinataClient } from '@/utils/pinataClient'
import {IP} from "../pages/registerIP"

interface NFTCardProps {
    key: number,
    tokenId: BigInt,
    status: string,
}


const NFTCard: React.FC<NFTCardProps> = ({key, tokenId, status}) => {

    const contract = '0x07e39e39ddee958c8a9221d82f639aa9112d6789259ccf09f2a7eb8e021c051c';
    const [tokenURI, setTokenURI] = useState<string | null>(null);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [metadata, setMetadata] = useState<IP | null>(null);

    const { data, isLoading: isContractLoading, error: contractError } = useReadContract({
      abi: abi as Abi,
      functionName: 'tokenURI',
      address: contract as `0x${string}`,
      args: [Number(tokenId)],
      watch: false, 
    });

    console.log('AAAAAA', {data});
    
    useEffect(() => {
      if (isContractLoading) {
        setIsLoading(true);
      } else if (contractError) {
        setIsLoading(false);
        setError("Failed to fetch tokenURI");
      } else if (data) {
        setIsLoading(false);
        setTokenURI(data as string);    
      }
    }, [data, isContractLoading, contractError]);
    
    useEffect(() => {
        const fetchMetadata = async () => {
          if (tokenURI) {
          console.log("caralhinho de asa", tokenURI)
            try {
                const response = await pinataClient.gateways.get(tokenURI);

                // Parse the response if it's a string
                const data = typeof response.data === "string" ? JSON.parse(response.data) : response.data;
      
                // Type guard to ensure data matches IP interface
                if (data && typeof data === "object" && "title" in data && "description" in data && "ipType" in data) {
                  setMetadata(data as IP); // Cast data to IP
                } else {
                  setError("Data format mismatch");
                }
                
            } catch (err) {
              setError("Failed to fetch metadata")
            }
          }
        }
  
        fetchMetadata()
      }, [tokenURI]);

    useEffect(() => {
        console.log(metadata)
    }, [metadata]);
    if (isLoading) {
      return <p>Loading...</p>;
    }

    if (error) {
        return <p>{error}</p>;
    }

    if (!metadata) {
        return null; // or a placeholder if you prefer
    }
    return (
        <Card className="overflow-hidden">
        <CardHeader className="p-0">
          <Image
            src={"/background.jpg"}
            alt={metadata.title}
            width={400}
            height={400}
            className="w-full h-48 object-cover"
          />
        </CardHeader>
        <CardContent className="p-4">
          <CardTitle className="line-clamp-1 mb-2">{metadata.title}</CardTitle>
          <div className="flex justify-between items-center mb-2">
            <Badge variant="secondary">{"nft.category"}</Badge>
            <span className="font-semibold">{"nft.price"} ETH</span>
          </div>
          <Badge variant={status === 'Listed' ? 'default' : status === 'Licensed' ? 'secondary' : 'outline'}>
            {status}
          </Badge>
        </CardContent>
        <CardFooter className="p-4 pt-0 flex flex-wrap gap-2">
          <Button variant="outline" size="sm">
            <Eye className="h-4 w-4 mr-2" />
            View Details
          </Button>
          <Button variant="outline" size="sm">
            <FileText className="h-4 w-4 mr-2" />
            License IP
          </Button>
          <Button variant="outline" size="sm">
            <DollarSign className="h-4 w-4 mr-2" />
            Monetize
          </Button>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" size="sm">
                <MoreHorizontal className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent>
              <DropdownMenuLabel>More Actions</DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuItem>
                <Send className="h-4 w-4 mr-2" />
                Transfer
              </DropdownMenuItem>
              <DropdownMenuItem>
                <Zap className="h-4 w-4 mr-2" />
                Promote
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </CardFooter>
      </Card>
    )
};

export default NFTCard;