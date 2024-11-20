'use client'

import React from 'react'
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Info, Grid, List, ExternalLink } from "lucide-react"
import Image from "next/image"
import Link from "next/link"

// Mock data for the NFT Collection
const collectionData = {
  id: "quantum-patents-2023",
  name: "Quantum Patents 2023",
  description: "A groundbreaking collection of quantum computing patents, representing the cutting edge of technological innovation in the field.",
  creator: {
    name: "Quantum Innovations Inc.",
    avatar: "/placeholder.svg?height=40&width=40"
  },
  stats: {
    items: 50,
    owners: 32,
    floorPrice: 1.5,
    volume: 250
  },
  nfts: [
    { id: 1, title: "Quantum Entanglement Processor", price: 2.5, image: "/placeholder.svg?height=400&width=400" },
    { id: 2, title: "Qubit Stabilization Method", price: 1.8, image: "/placeholder.svg?height=400&width=400" },
    { id: 3, title: "Quantum Error Correction Algorithm", price: 3.2, image: "/placeholder.svg?height=400&width=400" },
    { id: 4, title: "Quantum-Classical Hybrid Architecture", price: 2.0, image: "/placeholder.svg?height=400&width=400" },
    { id: 5, title: "Quantum Cryptography Protocol", price: 2.7, image: "/placeholder.svg?height=400&width=400" },
    { id: 6, title: "Quantum Machine Learning Framework", price: 3.5, image: "/placeholder.svg?height=400&width=400" },
    // Add more NFTs as needed
  ]
}

export default function CollectionPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-4xl font-bold mb-4">{collectionData.name}</h1>
        <div className="flex items-center space-x-4 mb-4">
          <Avatar>
            <AvatarImage src={collectionData.creator.avatar} alt={collectionData.creator.name} />
            <AvatarFallback>{collectionData.creator.name[0]}</AvatarFallback>
          </Avatar>
          <div>
            <p className="text-sm text-muted-foreground">Created by</p>
            <p className="font-semibold">{collectionData.creator.name}</p>
          </div>
        </div>
        <p className="text-muted-foreground">{collectionData.description}</p>
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-8">
        <Card>
          <CardHeader className="py-4">
            <CardTitle className="text-sm font-medium">Items</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{collectionData.stats.items}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="py-4">
            <CardTitle className="text-sm font-medium">Owners</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{collectionData.stats.owners}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="py-4">
            <CardTitle className="text-sm font-medium">Floor Price</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{collectionData.stats.floorPrice} ETH</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="py-4">
            <CardTitle className="text-sm font-medium">Volume Traded</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{collectionData.stats.volume} ETH</p>
          </CardContent>
        </Card>
      </div>

      <Tabs defaultValue="grid" className="mb-8">
        <div className="flex justify-between items-center mb-4">
          <TabsList>
            <TabsTrigger value="grid"><Grid className="h-4 w-4 mr-2" />Grid</TabsTrigger>
            <TabsTrigger value="list"><List className="h-4 w-4 mr-2" />List</TabsTrigger>
          </TabsList>
          <Button variant="outline">
            <Info className="h-4 w-4 mr-2" />
            Collection Info
          </Button>
        </div>
        <TabsContent value="grid">
          <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {collectionData.nfts.map((nft) => (
              <Card key={nft.id} className="overflow-hidden">
                <Link href={`/nft/${nft.id}`}>
                  <Image
                    src={nft.image}
                    alt={nft.title}
                    width={400}
                    height={400}
                    className="w-full h-48 object-cover"
                  />
                  <CardHeader>
                    <CardTitle className="line-clamp-1">{nft.title}</CardTitle>
                  </CardHeader>
                  <CardFooter className="flex justify-between">
                    <span className="font-bold">{nft.price} ETH</span>
                    <Button variant="outline" size="sm">View</Button>
                  </CardFooter>
                </Link>
              </Card>
            ))}
          </div>
        </TabsContent>
        <TabsContent value="list">
          <div className="space-y-4">
            {collectionData.nfts.map((nft) => (
              <Card key={nft.id}>
                <CardContent className="flex items-center p-4">
                  <Image
                    src={nft.image}
                    alt={nft.title}
                    width={80}
                    height={80}
                    className="rounded-md object-cover mr-4"
                  />
                  <div className="flex-grow">
                    <h3 className="font-semibold">{nft.title}</h3>
                    <p className="text-muted-foreground">{nft.price} ETH</p>
                  </div>
                  <Button variant="outline" size="sm">View</Button>
                </CardContent>
              </Card>
            ))}
          </div>
        </TabsContent>
      </Tabs>

      <div className="text-center">
        <Button>
          Load More
          <ExternalLink className="ml-2 h-4 w-4" />
        </Button>
      </div>
    </div>
  )
}