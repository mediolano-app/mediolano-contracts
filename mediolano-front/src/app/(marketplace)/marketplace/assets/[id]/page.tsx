'use client'

import { useState } from 'react'
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import { AlertCircle, ArrowLeftRight, Clock, DollarSign, Heart, Share2, Shield } from "lucide-react"
import Image from "next/image"
import Link from "next/link"

// Mock data for the NFT
const nftData = {
  id: "12345",
  title: "Revolutionary AI Patent #42",
  description: "This groundbreaking AI patent represents a significant leap forward in machine learning technology. It covers novel algorithms for natural language processing that dramatically improve accuracy and efficiency.",
  image: "/placeholder.svg?height=600&width=600",
  creator: {
    name: "Dr. Ada Lovelace",
    avatar: "/placeholder.svg?height=40&width=40",
    verified: true
  },
  owner: {
    name: "Tech Innovations Inc.",
    avatar: "/placeholder.svg?height=40&width=40",
    verified: true
  },
  price: "5.5 ETH",
  highestBid: "5.2 ETH",
  endTime: "2023-12-31T23:59:59Z",
  category: "Patent",
  tags: ["AI", "Machine Learning", "NLP"],
  history: [
    { event: "Minted", date: "2023-06-01", price: "5.0 ETH" },
    { event: "Listed", date: "2023-06-15", price: "5.5 ETH" },
    { event: "Bid", date: "2023-06-20", price: "5.2 ETH" },
  ]
}

export default function AssetView() {
  const [bidAmount, setBidAmount] = useState('')

  const handleBid = () => {
    // Here you would handle the bidding logic
    console.log(`Placed bid for ${bidAmount} ETH`)
    // Reset bid amount
    setBidAmount('')
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <Link href="/marketplace" className="inline-flex items-center text-primary hover:underline mb-6">
        <ArrowLeftRight className="mr-2 h-4 w-4" />
        Back to Marketplace
      </Link>

      <div className="grid md:grid-cols-2 gap-8">
        <div>
          <Image
            src={nftData.image}
            alt={nftData.title}
            width={600}
            height={600}
            className="rounded-lg object-cover w-full"
          />
          <div className="mt-4 flex justify-between items-center">
            <Button variant="outline">
              <Heart className="mr-2 h-4 w-4" /> Add to Favorites
            </Button>
            <Button variant="outline">
              <Share2 className="mr-2 h-4 w-4" /> Share
            </Button>
          </div>
        </div>

        <div>
          <h1 className="text-3xl font-bold mb-2">{nftData.title}</h1>
          <div className="flex items-center mb-4">
            <Badge variant="secondary" className="mr-2">{nftData.category}</Badge>
            {nftData.tags.map(tag => (
              <Badge key={tag} variant="outline" className="mr-2">{tag}</Badge>
            ))}
          </div>
          <p className="text-muted-foreground mb-6">{nftData.description}</p>

          <Card className="mb-6">
            <CardHeader>
              <CardTitle>Ownership & Creation</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="flex justify-between items-center mb-4">
                <div className="flex items-center">
                  <Avatar className="mr-2">
                    <AvatarImage src={nftData.creator.avatar} alt={nftData.creator.name} />
                    <AvatarFallback>{nftData.creator.name[0]}</AvatarFallback>
                  </Avatar>
                  <div>
                    <p className="font-semibold">{nftData.creator.name}</p>
                    <p className="text-sm text-muted-foreground">Creator</p>
                  </div>
                </div>
                {nftData.creator.verified && <Shield className="h-5 w-5 text-primary" />}
              </div>
              <div className="flex justify-between items-center">
                <div className="flex items-center">
                  <Avatar className="mr-2">
                    <AvatarImage src={nftData.owner.avatar} alt={nftData.owner.name} />
                    <AvatarFallback>{nftData.owner.name[0]}</AvatarFallback>
                  </Avatar>
                  <div>
                    <p className="font-semibold">{nftData.owner.name}</p>
                    <p className="text-sm text-muted-foreground">Owner</p>
                  </div>
                </div>
                {nftData.owner.verified && <Shield className="h-5 w-5 text-primary" />}
              </div>
            </CardContent>
          </Card>

          <Card className="mb-6">
            <CardHeader>
              <CardTitle>Current Price</CardTitle>
              <CardDescription>Auction ends in <Clock className="inline h-4 w-4" /> 14d 6h 24m</CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold">{nftData.price}</p>
              <p className="text-muted-foreground">Highest bid: {nftData.highestBid}</p>
            </CardContent>
            <CardFooter className="flex flex-col items-stretch gap-4">
              <div className="flex gap-4">
                <Input
                  type="number"
                  placeholder="Enter bid amount"
                  value={bidAmount}
                  onChange={(e) => setBidAmount(e.target.value)}
                />
                <Button onClick={handleBid} disabled={!bidAmount}>
                  <DollarSign className="mr-2 h-4 w-4" /> Place Bid
                </Button>
              </div>
              <Button variant="outline">Buy Now for {nftData.price}</Button>
            </CardFooter>
          </Card>

          <Tabs defaultValue="details">
            <TabsList className="grid w-full grid-cols-3">
              <TabsTrigger value="details">Details</TabsTrigger>
              <TabsTrigger value="history">History</TabsTrigger>
              <TabsTrigger value="offers">Offers</TabsTrigger>
            </TabsList>
            <TabsContent value="details">
              <Card>
                <CardHeader>
                  <CardTitle>NFT Details</CardTitle>
                </CardHeader>
                <CardContent>
                  <p><strong>Token ID:</strong> {nftData.id}</p>
                  <p><strong>Contract Address:</strong> 0x1234...5678</p>
                  <p><strong>Token Standard:</strong> ERC-721</p>
                  <p><strong>Blockchain:</strong> Ethereum</p>
                </CardContent>
              </Card>
            </TabsContent>
            <TabsContent value="history">
              <Card>
                <CardHeader>
                  <CardTitle>Transaction History</CardTitle>
                </CardHeader>
                <CardContent>
                  <ul className="space-y-4">
                    {nftData.history.map((item, index) => (
                      <li key={index} className="flex justify-between items-center">
                        <div>
                          <p className="font-semibold">{item.event}</p>
                          <p className="text-sm text-muted-foreground">{item.date}</p>
                        </div>
                        <p className="font-semibold">{item.price}</p>
                      </li>
                    ))}
                  </ul>
                </CardContent>
              </Card>
            </TabsContent>
            <TabsContent value="offers">
              <Card>
                <CardHeader>
                  <CardTitle>Current Offers</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-muted-foreground">No offers available at this time.</p>
                </CardContent>
              </Card>
            </TabsContent>
          </Tabs>
        </div>
      </div>
    </div>
  )
}