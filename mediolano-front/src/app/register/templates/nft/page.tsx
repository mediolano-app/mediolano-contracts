'use client'

import { useState } from 'react'
import Link from 'next/link'
import { ArrowLeft, Image, Music, Video, FileText, Globe, Shield, DollarSign, Zap, BarChart, Lock, Search, Palette, Camera, Headphones, Film, Code, Gamepad } from 'lucide-react'

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"

export default function NFTRegistrationPage() {
  const [formData, setFormData] = useState({
    title: '',
    creator: '',
    nftType: '',
    description: '',
    price: '',
    royaltyPercentage: '',
    blockchain: '',
  })

  const [file, setFile] = useState<File | null>(null)

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target
    setFormData(prev => ({ ...prev, [name]: value }))
  }

  const handleSelectChange = (name: string, value: string) => {
    setFormData(prev => ({ ...prev, [name]: value }))
  }

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) setFile(file)
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    console.log(formData)
    console.log(file)
    alert('NFT registration submitted successfully!')
  }

  return (
    <div className="container mx-auto px-4 py-10 mb-20">
      <div className="flex items-center justify-between mb-8">
        <h1 className="text-3xl font-bold">NFT Registration</h1>
        <Link
          href="/register/templates"
          className="flex items-center text-sm font-medium text-muted-foreground hover:underline"
        >
          <ArrowLeft className="mr-2 h-4 w-4" />
          Back to Marketplace
        </Link>
      </div>

      <div className="grid gap-8 lg:grid-cols-2">
        <Card className="w-full max-w-2xl mx-auto lg:max-w-none">
          <CardHeader>
            <CardTitle>NFT Details</CardTitle>
            <CardDescription>Please provide information about your NFT.</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="title">NFT Title</Label>
                <Input
                  id="title"
                  name="title"
                  value={formData.title}
                  onChange={handleChange}
                  placeholder="Enter the title of your NFT"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="creator">Creator Name</Label>
                <Input
                  id="creator"
                  name="creator"
                  value={formData.creator}
                  onChange={handleChange}
                  placeholder="Enter your name or pseudonym"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="nftType">NFT Type</Label>
                <Select onValueChange={(value) => handleSelectChange('nftType', value)} value={formData.nftType}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select an NFT type" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="image">Image</SelectItem>
                    <SelectItem value="audio">Audio</SelectItem>
                    <SelectItem value="video">Video</SelectItem>
                    <SelectItem value="3d">3D Model</SelectItem>
                    <SelectItem value="game">Game Asset</SelectItem>
                    <SelectItem value="document">Document</SelectItem>
                    <SelectItem value="other">Other</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label htmlFor="description">Description</Label>
                <Textarea
                  id="description"
                  name="description"
                  value={formData.description}
                  onChange={handleChange}
                  placeholder="Provide a description of your NFT"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="price">Price (ETH)</Label>
                <Input
                  id="price"
                  name="price"
                  type="number"
                  value={formData.price}
                  onChange={handleChange}
                  min={0}
                  step={0.001}
                  placeholder="Enter the price in ETH"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="royaltyPercentage">Royalty Percentage</Label>
                <Input
                  id="royaltyPercentage"
                  name="royaltyPercentage"
                  type="number"
                  value={formData.royaltyPercentage}
                  onChange={handleChange}
                  min={0}
                  max={100}
                  step={0.1}
                  placeholder="Enter royalty percentage (e.g., 2.5)"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="blockchain">Blockchain</Label>
                <Select onValueChange={(value) => handleSelectChange('blockchain', value)} value={formData.blockchain}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select a blockchain" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="ethereum">Ethereum</SelectItem>
                    <SelectItem value="polygon">Polygon</SelectItem>
                    <SelectItem value="solana">Solana</SelectItem>
                    <SelectItem value="binance">Binance Smart Chain</SelectItem>
                    <SelectItem value="other">Other</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label htmlFor="nftFile">Upload NFT File</Label>
                <Input
                  id="nftFile"
                  type="file"
                  onChange={handleFileChange}
                  required
                />
              </div>

              <Button type="submit" className="w-full">Register NFT</Button>
            </form>
          </CardContent>
        </Card>

        <div className="space-y-8">
          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground'>
            <CardHeader>
              <CardTitle>Why Create NFTs?</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="space-y-4">
                <li className="flex items-center">
                  <Globe className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Global exposure to collectors and enthusiasts</span>
                </li>
                <li className="flex items-center">
                  <Shield className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Verifiable ownership and authenticity</span>
                </li>
                <li className="flex items-center">
                  <DollarSign className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>New revenue streams through digital scarcity</span>
                </li>
                <li className="flex items-center">
                  <Zap className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Instant liquidity and transferability</span>
                </li>
                <li className="flex items-center">
                  <BarChart className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Ongoing royalties from secondary sales</span>
                </li>
                <li className="flex items-center">
                  <Lock className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Immutable proof of creation and provenance</span>
                </li>
              </ul>
            </CardContent>
          </Card>

          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground'>
            <CardHeader>
              <CardTitle>Popular NFT Categories</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="grid grid-cols-2 gap-4">
                <li className="flex items-center">
                  <Palette className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Digital Art</span>
                </li>
                <li className="flex items-center">
                  <Camera className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Photography</span>
                </li>
                <li className="flex items-center">
                  <Headphones className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Music</span>
                </li>
                <li className="flex items-center">
                  <Film className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Videos</span>
                </li>
                <li className="flex items-center">
                  <Gamepad className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Gaming Assets</span>
                </li>
                <li className="flex items-center">
                  <Code className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Virtual Real Estate</span>
                </li>
                <li className="flex items-center">
                  <FileText className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Literature</span>
                </li>
                <li className="flex items-center">
                  <Image className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Memes</span>
                </li>
              </ul>
            </CardContent>
          </Card>

          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground'>
            <CardHeader>
              <CardTitle>Platform Features</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="space-y-4">
                <li className="flex items-center">
                  <Search className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Advanced NFT discovery and curation</span>
                </li>
                <li className="flex items-center">
                  <BarChart className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Real-time market data and analytics</span>
                </li>
                <li className="flex items-center">
                  <Lock className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Secure wallet integration</span>
                </li>
                <li className="flex items-center">
                  <DollarSign className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Automated royalty distribution</span>
                </li>
                <li className="flex items-center">
                  <Globe className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Cross-chain NFT marketplace</span>
                </li>
              </ul>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}