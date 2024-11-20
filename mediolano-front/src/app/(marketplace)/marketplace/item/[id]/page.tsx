'use client'

import { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { useParams } from 'next/navigation'
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Separator } from "@/components/ui/separator"
import { ArrowLeft, Heart, Share2, Eye, Clock, BarChart2, ShieldCheck, DollarSign, Zap, Lock, Globe, Activity } from 'lucide-react'

const mockItem = {
  id: 1,
  title: "Intellectual Property Title",
  creator: "Author",
  creatorAvatar: "/background.jpg",
  price: 5,
  currency: "ETH",
  description: "Intellectual property description.",
  image: "/background.jpg",
  category: "Category",
  tokenId: "QC20230001",
  blockchain: "Starknet",
  createdAt: "2024-11-15T10:30:00Z",
  lastSale: {
    price: 4,
    currency: "ETH",
    date: "2024-11-01T14:45:00Z"
  },
  views: 120,
  favorites: 12,
  owners: 1,
  totalSupply: 1
}

const priceHistory = [
  { date: '2024-11-15', price: 40 },
  { date: '2024-11-16', price: 40 },
  { date: '2024-11-17', price: 40 },
  { date: '2024-11-18', price: 40 },
  { date: '2024-11-19', price: 40 },
  { date: '2024-11-20', price: 42 },
  { date: '2024-11-22', price: 45 },
  { date: '2024-11-23', price: 48 },
  { date: '2024-11-25', price: 50 },
]

const itemActivity = [
  { event: 'Listed', price: 50, from: 'Dr. Emily Quantum', to: '-', date: '2024-11-02T09:00:00Z' },
  { event: 'Sale', price: 45, from: 'PreviousOwner', to: 'Dr. Emily Quantum', date: '2024-11-01T14:45:00Z' },
  { event: 'Transfer', price: '-', from: 'QuantumLabs', to: 'PreviousOwner', date: '2024-11-20T11:30:00Z' },
  { event: 'Minted', price: '-', from: '-', to: 'QuantumLabs', date: '2024-11-15T10:30:00Z' },
]

export default function ItemPage() {
  const params = useParams()
  const [item] = useState(mockItem)

  return (
    <div className="container mx-auto px-4 py-8">
      <Link href="/" className="flex items-center text-sm font-medium text-muted-foreground hover:underline mb-6">
        <ArrowLeft className="mr-2 h-4 w-4" />
        Back to Marketplace
      </Link>
      
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2">
          <div className="mb-4">
            
            <h1 className="text-3xl font-bold mb-2">{item.title}</h1>
            
            
            <div className="flex items-center space-x-4">
              <div className="flex items-center">
                
                <Avatar className="h-6 w-6 mr-2 mb-2">
                  <AvatarImage src={item.creatorAvatar} />
                  <AvatarFallback>ME</AvatarFallback>
                </Avatar>
                <Badge variant="outline" className="text-sm mb-2">
                <span className="text-sm">{item.creator}</span>
                </Badge>
              </div>
              <Badge variant="outline" className="text-sm mb-2">
                <Eye className="h-4 w-4 mr-1" />
                {item.views} views
              </Badge>
              <Badge variant="outline" className="text-sm mb-2">
                <Heart className="h-4 w-4 mr-1" />
                {item.favorites} favorites
                </Badge>
              <Badge variant="outline" className="text-sm mb-2">{item.category}</Badge>
            </div>
          </div>

          <div className="relative aspect-video rounded-lg overflow-hidden mb-6">
            <Image
              src={item.image}
              alt={item.title}
              layout="fill"
              objectFit="cover"
              className="transition-transform hover:scale-105"
            />
          </div>

          <Tabs defaultValue="description" className="mb-6 ">
            <TabsList className="grid w-full grid-cols-3 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
              <TabsTrigger value="description">Description</TabsTrigger>
              <TabsTrigger value="properties">Properties</TabsTrigger>
              <TabsTrigger value="details">Details</TabsTrigger>
            </TabsList>
            <TabsContent value="description">
              <Card>
                <CardContent className="pt-6">
                  <p>{item.description}</p>
                </CardContent>
              </Card>
            </TabsContent>
            <TabsContent value="properties">
              <Card>
                <CardContent className="pt-6">
                  <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                    <div className="bg-secondary p-3 rounded-lg text-center">
                      <p className="text-xs text-muted-foreground">QUBIT STABILITY</p>
                      <p className="font-medium">99.9%</p>
                    </div>
                    <div className="bg-secondary p-3 rounded-lg text-center">
                      <p className="text-xs text-muted-foreground">COHERENCE TIME</p>
                      <p className="font-medium">1000μs</p>
                    </div>
                    <div className="bg-secondary p-3 rounded-lg text-center">
                      <p className="text-xs text-muted-foreground">SCALABILITY</p>
                      <p className="font-medium">High</p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </TabsContent>
            <TabsContent value="details">
              <Card>
                <CardContent className="pt-6">
                  <dl className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
                    <div>
                      <dt className="font-medium text-muted-foreground">Contract Address</dt>
                      <dd className="break-all">0x1234...5678</dd>
                    </div>
                    <div>
                      <dt className="font-medium text-muted-foreground">Token ID</dt>
                      <dd>{item.tokenId}</dd>
                    </div>
                    <div>
                      <dt className="font-medium text-muted-foreground">Token Standard</dt>
                      <dd>ERC-721</dd>
                    </div>
                    <div>
                      <dt className="font-medium text-muted-foreground">Blockchain</dt>
                      <dd>{item.blockchain}</dd>
                    </div>
                    <div>
                      <dt className="font-medium text-muted-foreground">Creator Earnings</dt>
                      <dd>7.5%</dd>
                    </div>
                  </dl>
                </CardContent>
              </Card>
            </TabsContent>
          </Tabs>

          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground'>
            <CardHeader>
              <CardTitle>Item Activity</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {itemActivity.map((activity, index) => (
                  <div key={index} className="flex items-center justify-between text-sm">
                    <div className="flex items-center">
                      <Activity className="h-4 w-4 mr-2 text-primary" />
                      <span>{activity.event}</span>
                    </div>
                    <div className="flex items-center space-x-4">
                      <span>{activity.price !== '-' ? `${activity.price} ETH` : '-'}</span>
                      <span className="text-muted-foreground">
                        {new Date(activity.date).toLocaleDateString()}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </div>

        <div>
          <Card className="sticky top-4 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
            <CardContent className="pt-6">
              <div className="mb-4">
                <p className="text-sm text-muted-foreground">Current Price</p>
                <p className="text-3xl font-bold">{item.price} {item.currency}</p>
              </div>
              <Button size="lg" className="w-full mb-4 bg-blue-600">Buy Now</Button>
              <div className="flex items-center justify-between mb-4">
                <Button variant="outline" size="sm">
                  <Heart className="h-4 w-4 mr-2" />
                  Add to Favorites
                </Button>
                <Button variant="outline" size="sm">
                  <Share2 className="h-4 w-4 mr-2" />
                  Share
                </Button>
              </div>
              <Separator className="my-4" />
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">Last Sale Price</span>
                  <span>{item.lastSale.price} {item.lastSale.currency}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">Owners</span>
                  <span>{item.owners}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">Total Supply</span>
                  <span>{item.totalSupply}</span>
                </div>
              </div>
              <Separator className="my-4" />
              <div className="flex items-center text-sm text-muted-foreground">
                <Clock className="h-4 w-4 mr-2" />
                Sale ends June 15, 2023 at 9:00pm GMT+1
              </div>
            </CardContent>
          </Card>
        </div>
      </div>

      <div className="mt-12">
        <h2 className="text-2xl font-bold mb-4">Price History</h2>
        <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
          <CardContent className="pt-6">
            <div className="h-[200px] flex items-end justify-between">
              {priceHistory.map((point, index) => (
                <div key={index} className="flex flex-col items-center">
                  <div 
                    className="bg-blue-600 w-12 rounded-t-md" 
                    style={{height: `${(point.price / Math.max(...priceHistory.map(p => p.price))) * 150}px`}}
                  ></div>
                  <p className="text-xs mt-1">{point.date.split('-')[2]}</p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>

      <section className="mt-12 mt-20">
        <h2 className="text-2xl font-bold mb-4">Blockchain Benefits for Intellectual Property</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
            <CardContent className="pt-6">
              <ShieldCheck className="h-8 w-8 mb-2 text-primary" />
              <h3 className="font-semibold mb-2">Enhanced Security</h3>
              <p className="text-sm">Immutable records ensure your IP is securely stored and protected against tampering.</p>
            </CardContent>
          </Card>
          <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
            <CardContent className="pt-6">
              <DollarSign className="h-8 w-8 mb-2 text-primary" />
              <h3 className="font-semibold mb-2">Efficient Monetization</h3>
              <p className="text-sm">Smart contracts automate royalty payments, ensuring fair and timely compensation.</p>
            </CardContent>
          </Card>
          <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
            <CardContent className="pt-6">
              <Zap className="h-8 w-8 mb-2 text-primary" />
              <h3 className="font-semibold mb-2">Instant Verification</h3>
              <p className="text-sm">Quickly prove ownership and authenticity of your intellectual property.</p>
            </CardContent>
          </Card>
          <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
            <CardContent className="pt-6">
              <Globe className="h-8 w-8 mb-2 text-primary" />
              <h3 className="font-semibold mb-2">Global Accessibility</h3>
              <p className="text-sm">Access a worldwide market of potential buyers and collaborators for your IP.</p>
            </CardContent>
          </Card>
        </div>
      </section>

      <section className="mt-12 mb-20">
        <h2 className="text-2xl font-bold mb-4">IP Marketplace Features</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
            <CardContent className="pt-6">
              <Lock className="h-8 w-8 mb-2 text-primary" />
              <h3 className="font-semibold mb-2">Secure Transactions</h3>
              <p className="text-sm">Our platform ensures safe and transparent transactions for all IP trades.</p>
            </CardContent>
          </Card>
          <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
            <CardContent className="pt-6">
              <BarChart2 className="h-8 w-8 mb-2 text-primary" />
              <h3 className="font-semibold mb-2">Market Analytics</h3>
              <p className="text-sm">Access real-time market data and trends to make informed decisions.</p>
            </CardContent>
          </Card>
          <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
            <CardContent className="pt-6">
              <Share2 className="h-8 w-8 mb-2 text-primary" />
              <h3 className="font-semibold mb-2">Collaborative Tools</h3>
              <p className="text-sm">Connect with other creators and potential partners to expand your IP portfolio.</p>
            </CardContent>
          </Card>
        </div>
      </section>
    </div>
  )
}