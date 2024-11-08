'use client'

import React, { useState } from 'react'
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Badge } from "@/components/ui/badge"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Eye, DollarSign, Send, MoreHorizontal, Search, Grid, List, FileText, Zap } from "lucide-react"
import Image from "next/image"

// Mock data for user's NFTs
const userNFTs = [
  { id: 1, title: "Dune 2 Movie Critic", category: "Copyright", price: 2.5, image: "/background.jpg", status: "Article" },
  { id: 2, title: "Blockchain Security Trademark", category: "Trademark", price: 1.8, image: "/background.jpg", status: "Not Listed" },
  { id: 3, title: "Quantum Encryption Method", category: "Patent", price: 3.2, image: "/background.jpg", status: "Licensed" },
  { id: 4, title: "Sustainable Energy Logo", category: "Trademark", price: 1.5, image: "/background.jpg", status: "Listed" },
  { id: 5, title: "Novel Drug Formulation", category: "Patent", price: 4.0, image: "/background.jpg", status: "Not Listed" },
  { id: 6, title: "AI-Powered Trading Algorithm", category: "Copyright", price: 2.7, image: "/background.jpg", status: "Listed" },
]

export default function MyIPsList() {
  const [searchTerm, setSearchTerm] = useState('')
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid')

  const filteredNFTs = userNFTs.filter(nft => 
    nft.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
    nft.category.toLowerCase().includes(searchTerm.toLowerCase())
  )

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