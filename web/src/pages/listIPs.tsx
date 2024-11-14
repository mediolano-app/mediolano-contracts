'use client'

import React, { useState, useEffect } from 'react'
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Badge } from "@/components/ui/badge"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Eye, DollarSign, Send, MoreHorizontal, Search, Grid, List, FileText, Zap } from "lucide-react"
import Image from "next/image"
import { useReadContract, useContract, useAccount, useCall } from "@starknet-react/core"
import { abi } from '@/abis/abi'
import { type Abi } from 'starknet'

// Mock data for user's NFTs
const userNFTs = [
  { id: 1, title: "Dune 2 Movie Critic", category: "Copyright", price: 2.5, image: "/background.jpg", status: "Movie Critic" },
  { id: 2, title: "Blockchain Trademark", category: "Trademark", price: 1.8, image: "/background.jpg", status: "Not Listed" },
  { id: 3, title: "Ainda Estou Aqui trata da angustiante incerteza", category: "Copyright", price: 0.02, image: "/background.jpg", status: "Movie Critic" },
  { id: 4, title: "Sustainable Energy Logo", category: "Trademark", price: 1.5, image: "/background.jpg", status: "Graphic Design" },
  { id: 5, title: "Music for Gaming", category: "Creative Commons", price: 0.0, image: "/background.jpg", status: "Not Listed" },
  { id: 6, title: "AI-Powered Trading Algorithm", category: "Copyright", price: 2.7, image: "/background.jpg", status: "Listed" },
]

export default function MyIPsList() {
  const [searchTerm, setSearchTerm] = useState('')
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid')

  const filteredNFTs = userNFTs.filter(nft => 
    nft.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
    nft.category.toLowerCase().includes(searchTerm.toLowerCase())
  )

  const { address: connectedAddress, isConnected, isConnecting } = useAccount();
  const contractAddress = '0x07e39e39ddee958c8a9221d82f639aa9112d6789259ccf09f2a7eb8e021c051c';
  const accountAddress = '0x04d9e99204dbfe644fc5ed7529d983ed809b7a356bf0c84daade57bcbb9c0c77';

  const [tokenIds, setTokenIds] = useState<BigInt[]>([]);

  const { contract } = useContract({
    abi: abi as Abi,
    address: contractAddress,
  });

  const { data: myTotalBalance, error: balanceError } = useReadContract({
    abi: abi as Abi,
    functionName: 'balance_of',
    address: contractAddress as `0x${string}`,
    args: [connectedAddress],
    watch: false,   
  });
  console.log(myTotalBalance);
  const totalBalance = myTotalBalance ? parseInt(myTotalBalance.toString()) : 0;

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
  };
  
  useEffect(() => {
    if (totalBalance > 0) {
      const fetchTokenIds = async () => {
        const fetchedTokenIds: number[] = []; 
  
        const tokenIdPromises = Array.from({ length: totalBalance }, (_, tokenIndex) => 
          getTokenId(tokenIndex)
        );
  
        try {
          const resolvedTokenIds = await Promise.all(tokenIdPromises);
          
          resolvedTokenIds.forEach((tokenId) => {
            if (typeof tokenId === "bigint") {
              fetchedTokenIds.push(tokenId);  
            } else {
              console.warn("Unexpected tokenId type:", typeof tokenId);
            }
          });
  
          setTokenIds(fetchedTokenIds);  
        } catch (e) {
          console.error("Error fetching token IDs:", e);
        }
      };
  
      fetchTokenIds(); 
    }
  }, [totalBalance, connectedAddress]);

  const NFTCard = ({ nft }: { nft: typeof userNFTs[0] }) => (
    <Card className="overflow-hidden">
      <CardHeader className="p-0">
        <Image
          src={nft.image}
          alt={nft.title}
          width={400}
          height={400}
          className="w-full h-48 object-cover"
        />
      </CardHeader>
      <CardContent className="p-4">
        <CardTitle className="line-clamp-1 mb-2">{nft.title}</CardTitle>
        <div className="flex justify-between items-center mb-2">
          <Badge variant="secondary">{nft.category}</Badge>
          <span className="font-semibold">{nft.price} ETH</span>
        </div>
        <Badge variant={nft.status === 'Listed' ? 'default' : nft.status === 'Licensed' ? 'secondary' : 'outline'}>
          {nft.status}
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

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-4">My IP NFTs</h1>

      <div className="mb-6 flex flex-col sm:flex-row justify-between items-center gap-4">
        <div className="relative w-full sm:w-auto">
          <Search className="absolute left-2 top-1/2 transform -translate-y-1/2 text-muted-foreground" />
          <Input
            className="pl-8 w-full sm:w-[300px]"
            placeholder="Search your NFTs..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <Tabs value={viewMode} onValueChange={(value) => setViewMode(value as 'grid' | 'list')}>
          <TabsList>
            <TabsTrigger value="grid"><Grid className="h-4 w-4 mr-2" />Grid</TabsTrigger>
            <TabsTrigger value="list"><List className="h-4 w-4 mr-2" />List</TabsTrigger>
          </TabsList>
        </Tabs>
      </div>

      {viewMode === 'grid' ? (
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {filteredNFTs.map((nft) => (
            <NFTCard key={nft.id} nft={nft} />
          ))}
        </div>
      ) : (
        <div className="space-y-4">
          {filteredNFTs.map((nft) => (
            <Card key={nft.id}>
              <div className="flex items-center p-4">
                <Image
                  src={nft.image}
                  alt={nft.title}
                  width={80}
                  height={80}
                  className="rounded-md object-cover mr-4"
                />
                <div className="flex-grow">
                  <h3 className="font-semibold mb-1">{nft.title}</h3>
                  <div className="flex items-center gap-2 mb-1">
                    <Badge variant="secondary">{nft.category}</Badge>
                    <span className="text-sm text-muted-foreground">{nft.price} ETH</span>
                  </div>
                  <Badge variant={nft.status === 'Listed' ? 'default' : nft.status === 'Licensed' ? 'secondary' : 'outline'}>
                    {nft.status}
                  </Badge>
                </div>
                <div className="flex gap-2">
                  <Button variant="outline" size="sm">
                    <Eye className="h-4 w-4" />
                  </Button>
                  <Button variant="outline" size="sm">
                    <FileText className="h-4 w-4" />
                  </Button>
                  <Button variant="outline" size="sm">
                    <DollarSign className="h-4 w-4" />
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
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}

      {filteredNFTs.length === 0 && (
        <p className="text-center text-muted-foreground mt-8">No NFTs found matching your search.</p>
      )}
    </div>
  )
}