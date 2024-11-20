'use client'

import { useState } from 'react'
import Link from 'next/link'
import { ArrowLeft, Building, Car, Briefcase, Globe, Shield, DollarSign, BarChartIcon as ChartBar, Zap, BarChart, Lock, Search, PieChart, Landmark, TreePine, Gem } from 'lucide-react'

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"

export default function RWARegistrationPage() {
  const [formData, setFormData] = useState({
    assetName: '',
    assetType: '',
    location: '',
    valuation: '',
    ownershipStructure: '',
    description: '',
    tokenSymbol: '',
    totalSupply: '',
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
    alert('RWA registration submitted successfully!')
  }

  return (
    <div className="container mx-auto px-4 py-10 mb-20">
      <div className="flex items-center justify-between mb-8">
        <h1 className="text-3xl font-bold">Real World Asset (RWA) Registration</h1>
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
            <CardTitle>RWA Details</CardTitle>
            <CardDescription>Please provide information about your Real World Asset.</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="assetName">Asset Name</Label>
                <Input
                  id="assetName"
                  name="assetName"
                  value={formData.assetName}
                  onChange={handleChange}
                  placeholder="Enter the name of your asset"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="assetType">Asset Type</Label>
                <Select onValueChange={(value) => handleSelectChange('assetType', value)} value={formData.assetType}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select an asset type" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="realEstate">Real Estate</SelectItem>
                    <SelectItem value="vehicle">Vehicle</SelectItem>
                    <SelectItem value="equipment">Equipment</SelectItem>
                    <SelectItem value="commodity">Commodity</SelectItem>
                    <SelectItem value="artwork">Artwork</SelectItem>
                    <SelectItem value="other">Other</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label htmlFor="location">Asset Location</Label>
                <Input
                  id="location"
                  name="location"
                  value={formData.location}
                  onChange={handleChange}
                  placeholder="Enter the location of the asset"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="valuation">Asset Valuation (USD)</Label>
                <Input
                  id="valuation"
                  name="valuation"
                  type="number"
                  value={formData.valuation}
                  onChange={handleChange}
                  placeholder="Enter the current valuation of the asset"
                  min={0}
                  step={0.01}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="ownershipStructure">Ownership Structure</Label>
                <Select onValueChange={(value) => handleSelectChange('ownershipStructure', value)} value={formData.ownershipStructure}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select ownership structure" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="soleProprietorship">Sole Proprietorship</SelectItem>
                    <SelectItem value="partnership">Partnership</SelectItem>
                    <SelectItem value="llc">LLC</SelectItem>
                    <SelectItem value="corporation">Corporation</SelectItem>
                    <SelectItem value="trust">Trust</SelectItem>
                    <SelectItem value="other">Other</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label htmlFor="description">Asset Description</Label>
                <Textarea
                  id="description"
                  name="description"
                  value={formData.description}
                  onChange={handleChange}
                  placeholder="Provide a detailed description of the asset"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="tokenSymbol">Token Symbol</Label>
                <Input
                  id="tokenSymbol"
                  name="tokenSymbol"
                  value={formData.tokenSymbol}
                  onChange={handleChange}
                  placeholder="Enter a symbol for your token (e.g., REAL, VHCL)"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="totalSupply">Total Token Supply</Label>
                <Input
                  id="totalSupply"
                  name="totalSupply"
                  type="number"
                  value={formData.totalSupply}
                  onChange={handleChange}
                  placeholder="Enter the total number of tokens"
                  min={1}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="assetDocumentation">Asset Documentation</Label>
                <Input
                  id="assetDocumentation"
                  type="file"
                  onChange={handleFileChange}
                  accept=".pdf,.doc,.docx,.jpg,.jpeg,.png"
                  required
                />
              </div>

              <Button type="submit" className="w-full">Register RWA</Button>
            </form>
          </CardContent>
        </Card>

        <div className="space-y-8">
          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground'>
            <CardHeader>
              <CardTitle>Benefits of RWA Tokenization</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="space-y-4">
                <li className="flex items-center">
                  <Globe className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Global access to real-world asset investments</span>
                </li>
                <li className="flex items-center">
                  <Shield className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Enhanced security and transparency</span>
                </li>
                <li className="flex items-center">
                  <DollarSign className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Increased liquidity for traditionally illiquid assets</span>
                </li>
                <li className="flex items-center">
                  <ChartBar className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Fractional ownership opportunities</span>
                </li>
                <li className="flex items-center">
                  <Zap className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Streamlined asset management and transfer</span>
                </li>
                <li className="flex items-center">
                  <Lock className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Programmable compliance and automated distributions</span>
                </li>
              </ul>
            </CardContent>
          </Card>

          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground'>
            <CardHeader>
              <CardTitle>Popular RWA Categories</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="grid grid-cols-2 gap-4">
                <li className="flex items-center">
                  <Building className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Real Estate</span>
                </li>
                <li className="flex items-center">
                  <Car className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Vehicles</span>
                </li>
                <li className="flex items-center">
                  <Briefcase className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Equipment</span>
                </li>
                <li className="flex items-center">
                  <Gem className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Precious Metals</span>
                </li>
                <li className="flex items-center">
                  <TreePine className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Natural Resources</span>
                </li>
                <li className="flex items-center">
                  <PieChart className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Private Equity</span>
                </li>
                <li className="flex items-center">
                  <Landmark className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Infrastructure</span>
                </li>
                <li className="flex items-center">
                  <Gem className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Fine Art</span>
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
                  <span>Comprehensive RWA search and discovery</span>
                </li>
                <li className="flex items-center">
                  <BarChart className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Real-time valuation and performance tracking</span>
                </li>
                <li className="flex items-center">
                  <Lock className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Secure digital asset custody solutions</span>
                </li>
                <li className="flex items-center">
                  <DollarSign className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Automated compliance and dividend distribution</span>
                </li>
                <li className="flex items-center">
                  <Globe className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Global marketplace for tokenized RWAs</span>
                </li>
              </ul>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}