"use client";

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { Switch } from "@/components/ui/switch"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { Book, Copyright, FileText, Image, Music, Video, DollarSign, Clock, Gavel, Users, Lock, Cpu, LinkIcon, MoreVertical, Eye, Copy, FileSignature } from 'lucide-react'
import { useRouter } from 'next/navigation'

// Mock data for previously registered IPs
const mockIPs = [
  { id: 1, name: "Novel: The Cosmic Journey", type: "Book", status: "Listed", price: "0.5 ETH", image: "/background.jpg" },
  { id: 2, name: "Song: Echoes of Tomorrow", type: "Music", status: "Pending", price: "0.2 ETH", image: "/background.jpg" },
  { id: 3, name: "Artwork: Nebula Dreams", type: "Image", status: "Listed", price: "1.5 ETH", image: "/background.jpg" },
  { id: 4, name: "Screenplay: The Last Frontier", type: "Text", status: "Draft", price: "N/A", image: "/background.jpg" },
  { id: 5, name: "Short Film: Beyond the Stars", type: "Video", status: "Listed", price: "3 ETH", image: "/background.jpg" },
]

export default function ListingIP() {

  const router = useRouter()

  const handleNavigation = (id: string) => {
    router.push('/assets/1')
  }


  return (
    <div className="container mx-auto p-4 mt-10 mb-20">
      <h1 className="text-3xl font-bold mb-10 text-center">IP Listing</h1>
      <div className="grid lg:grid-cols-2 gap-8 mb-12">
        {/* Left column: List of previously registered IPs */}
        <div>
          <h2 className="text-1xl font-semibold mb-4">Your Intellectual Property Listings</h2>
          <div className="space-y-4">
            {mockIPs.map((ip) => (
              <Card key={ip.id} className="hover:shadow-lg transition-shadow duration-300 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/75 text-foreground">
                <CardHeader className="flex flex-row items-center space-y-0 pb-2">
                  <CardTitle className="text-lg">{ip.name}</CardTitle>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button variant="ghost" className="h-8 w-8 p-0 ml-auto">
                        <span className="sr-only">Open menu</span>
                        <MoreVertical className="h-4 w-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem>
                        <Eye className="mr-2 h-4 w-4" />
                        <Button  key={ip.id} onClick={() => handleNavigation(ip.id)}>View Details</Button>
                      </DropdownMenuItem>
                      <DropdownMenuItem>
                        <Copy className="mr-2 h-4 w-4" />
                        <span>Create New Listing</span>
                      </DropdownMenuItem>
                      <DropdownMenuItem>
                        <FileSignature className="mr-2 h-4 w-4" />
                        <span>Create License</span>
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </CardHeader>
                <CardContent>
                  <div className="flex items-center space-x-4">
                    <img src={ip.image} alt={ip.name} className="w-24 h-24 object-cover rounded-md" />
                    <div>
                      <p className="text-sm text-muted-foreground mb-1">{ip.type}</p>
                      <p className={`text-sm font-medium ${
                        ip.status === "Listed" ? "text-green-500" :
                        ip.status === "Pending" ? "text-yellow-500" :
                        "text-gray-500"
                      }`}>
                        Status: {ip.status}
                      </p>
                      <p className="text-sm font-semibold mt-1">{ip.price}</p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>

        {/* Right column: Form to register new IP */}
        <div>
          <h2 className="text-1xl font-semibold mb-4">Create New Listing</h2>
          <Card>
            <CardHeader>
              <CardTitle>Listing Details</CardTitle>
              <CardDescription>Enter the details of your intellectual property to create an NFT.</CardDescription>
            </CardHeader>
            <CardContent>
              <form>
                <div className="grid w-full items-center gap-4">
                <div className="flex flex-col space-y-1.5">
                    <Label htmlFor="ip">IP</Label>
                    <Select>
                      <SelectTrigger id="ip">
                        <SelectValue placeholder="Select Your IP" />
                      </SelectTrigger>
                      <SelectContent position="popper">
                        <SelectItem value="1">IP I</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="flex flex-col space-y-1.5">
                    <Label htmlFor="name">Name</Label>
                    <Input id="name" placeholder="Enter the name of your IP" />
                  </div>
                  <div className="flex flex-col space-y-1.5">
                    <Label htmlFor="type">Type</Label>
                    <Select>
                      <SelectTrigger id="type">
                        <SelectValue placeholder="Select IP type" />
                      </SelectTrigger>
                      <SelectContent position="popper">
                        <SelectItem value="book">Book</SelectItem>
                        <SelectItem value="music">Music</SelectItem>
                        <SelectItem value="image">Image</SelectItem>
                        <SelectItem value="text">Text</SelectItem>
                        <SelectItem value="video">Video</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="flex flex-col space-y-1.5">
                    <Label htmlFor="description">Description</Label>
                    <Textarea id="description" placeholder="Describe your intellectual property" />
                  </div>
                  <div className="flex flex-col space-y-1.5">
                    <Label htmlFor="file">Upload File</Label>
                    <Input id="file" type="file" />
                  </div>
                  <div className="flex flex-col space-y-1.5">
                    <Label htmlFor="price">Price</Label>
                    <Input id="price" type="number" placeholder="Enter price" />
                  </div>
                  <div className="flex flex-col space-y-1.5">
                    <Label htmlFor="currency">Currency</Label>
                    <Select>
                      <SelectTrigger id="currency">
                        <SelectValue placeholder="Select currency" />
                      </SelectTrigger>
                      <SelectContent position="popper">
                        <SelectItem value="eth">ETH</SelectItem>
                        <SelectItem value="usdc">USDC</SelectItem>
                        <SelectItem value="dai">DAI</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="flex flex-col space-y-1.5">
                    <Label htmlFor="duration">Duration</Label>
                    <Input id="duration" type="number" placeholder="Enter duration in days" />
                  </div>
                  <div className="flex flex-col space-y-1.5">
                    <Label htmlFor="saleMethod">Sale Method</Label>
                    <Select>
                      <SelectTrigger id="saleMethod">
                        <SelectValue placeholder="Select sale method" />
                      </SelectTrigger>
                      <SelectContent position="popper">
                        <SelectItem value="fixed">Fixed Price</SelectItem>
                        <SelectItem value="auction">Auction</SelectItem>
                        <SelectItem value="crowdfunding">Crowdfunding</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="flex items-center space-x-2">
                    <Switch id="privateSale" />
                    <Label htmlFor="privateSale">Private Sale</Label>
                  </div>
                  <div className="flex flex-col space-y-1.5">
                    <Label htmlFor="reserveAddress">Reserve for Specific Address</Label>
                    <Input id="reserveAddress" placeholder="Enter Ethereum address" />
                  </div>
                  <div className="flex flex-col space-y-1.5">
                    <Label htmlFor="tokenType">Token Type</Label>
                    <Select>
                      <SelectTrigger id="tokenType">
                        <SelectValue placeholder="Select token type" />
                      </SelectTrigger>
                      <SelectContent position="popper">
                        <SelectItem value="erc721">ERC721</SelectItem>
                        <SelectItem value="erc1155">ERC1155</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="flex flex-col space-y-1.5">
                    <Label htmlFor="blockchain">Blockchain</Label>
                    <Select>
                      <SelectTrigger id="blockchain">
                        <SelectValue placeholder="Select blockchain" />
                      </SelectTrigger>
                      <SelectContent position="popper">
                        <SelectItem value="starknet">Starknet</SelectItem>
                        <SelectItem value="ethereum">Ethereum</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>
              </form>
            </CardContent>
            <CardFooter className="flex justify-between">
              <Button variant="outline">Cancel</Button>
              <Button>Register NFT</Button>
            </CardFooter>
          </Card>
        </div>
      </div>

      {/* Showcase section */}
      <section className="mt-16">
        <h2 className="text-2xl font-bold mb-10 text-center">Why Tokenize Your Intellectual Property?</h2>
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
          <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 text-foreground">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Copyright className="h-6 w-6" />
                Protect Your Rights
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p>Secure and immutable proof of ownership on the blockchain, enhancing copyright protection.</p>
            </CardContent>
          </Card>
          <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 text-foreground">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <DollarSign className="h-6 w-6" />
                Monetize Your Work
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p>Create new revenue streams through NFT sales, licensing, and royalties.</p>
            </CardContent>
          </Card>
          <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 text-foreground">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Users className="h-6 w-6" />
                Expand Your Audience
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p>Reach a global market of collectors and enthusiasts in the growing NFT ecosystem.</p>
            </CardContent>
          </Card>
          <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 text-foreground">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Gavel className="h-6 w-6" />
                Flexible Sales Options
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p>Choose from various sale methods including fixed price, auctions, and crowdfunding.</p>
            </CardContent>
          </Card>
          <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 text-foreground">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Clock className="h-6 w-6" />
                Provenance Tracking
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p>Maintain a transparent and verifiable history of ownership and transactions.</p>
            </CardContent>
          </Card>
          <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 text-foreground">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <LinkIcon className="h-6 w-6" />
                Interoperability
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p>Leverage cross-platform compatibility and integration with various blockchain ecosystems.</p>
            </CardContent>
          </Card>
        </div>
      </section>
    </div>
  )
}