'use client'

import { useState } from 'react'
import Link from 'next/link'
import { ArrowLeft, PaintbrushIcon as PaintBrush, Camera, ImageIcon, CuboidIcon as Cube, DollarSign, Shield, Award, Globe, Palette, Feather, Aperture, Scissors, Shapes, Layers, Zap, Search, BarChart, Lock } from 'lucide-react'

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"

export default function ArtRegistrationPage() {
  const [formData, setFormData] = useState({
    title: '',
    artistName: '',
    medium: '',
    dimensions: '',
    yearCreated: new Date().getFullYear(),
    description: '',
    price: '',
  })

  const [file, setFile] = useState<File | null>(null)

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target
    setFormData(prev => ({ ...prev, [name]: value }))
  }

  const handleSelectChange = (value: string) => {
    setFormData(prev => ({ ...prev, medium: value }))
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    console.log(formData)
    console.log(file)
    alert('Art registration submitted successfully!')
  }

  return (
    <div className="container mx-auto px-4 py-10">
      <div className="flex items-center justify-between mb-8">
        <h1 className="text-3xl font-bold">Art Registration</h1>
        <Link
          href="/register/templates"
          className="flex items-center text-sm font-medium text-muted-foreground hover:underline"
        >
          <ArrowLeft className="mr-2 h-4 w-4" />
          Back to Templates
        </Link>
      </div>

      <div className="grid gap-8 lg:grid-cols-2 mb-20">
        <Card className="w-full max-w-2xl mx-auto lg:max-w-none">
          <CardHeader>
            <CardTitle>Artwork Details</CardTitle>
            <CardDescription>Please provide information about your artwork.</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="title">Artwork Title</Label>
                <Input
                  id="title"
                  name="title"
                  value={formData.title}
                  onChange={handleChange}
                  placeholder="Enter the title of your artwork"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="artistName">Artist Name</Label>
                <Input
                  id="artistName"
                  name="artistName"
                  value={formData.artistName}
                  onChange={handleChange}
                  placeholder="Enter your name or pseudonym"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="medium">Medium</Label>
                <Select onValueChange={handleSelectChange} value={formData.medium}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select a medium" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="oil">Oil Painting</SelectItem>
                    <SelectItem value="acrylic">Acrylic Painting</SelectItem>
                    <SelectItem value="watercolor">Watercolor</SelectItem>
                    <SelectItem value="digital">Digital Art</SelectItem>
                    <SelectItem value="sculpture">Sculpture</SelectItem>
                    <SelectItem value="photography">Photography</SelectItem>
                    <SelectItem value="mixed">Mixed Media</SelectItem>
                    <SelectItem value="other">Other</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label htmlFor="dimensions">Dimensions</Label>
                <Input
                  id="dimensions"
                  name="dimensions"
                  value={formData.dimensions}
                  onChange={handleChange}
                  placeholder="e.g., 24 x 36 inches"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="yearCreated">Year Created</Label>
                <Input
                  id="yearCreated"
                  name="yearCreated"
                  type="number"
                  value={formData.yearCreated}
                  onChange={handleChange}
                  min={1800}
                  max={new Date().getFullYear()}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="description">Description</Label>
                <Textarea
                  id="description"
                  name="description"
                  value={formData.description}
                  onChange={handleChange}
                  placeholder="Describe your artwork"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="price">Price (USD)</Label>
                <Input
                  id="price"
                  name="price"
                  type="number"
                  value={formData.price}
                  onChange={handleChange}
                  min={0}
                  step={0.01}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="artworkImage">Artwork Image</Label>
                <Input
                  id="artworkImage"
                  type="file"
                  accept="image/*"
                  onChange={(e) => {
                    const file = e.target.files?.[0]
                    if (file) setFile(file)
                  }}
                  required
                />
              </div>

              <Button type="submit" className="w-full">Register Artwork</Button>
            </form>
          </CardContent>
        </Card>

        <div className="space-y-8">
          <Card>
            <CardHeader>
              <CardTitle>Why Register Your Art?</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="space-y-4">
                <li className="flex items-center">
                  <Globe className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Global exposure to art collectors</span>
                </li>
                <li className="flex items-center">
                  <Shield className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Protect your intellectual property</span>
                </li>
                <li className="flex items-center">
                  <DollarSign className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Monetize your creations</span>
                </li>
                <li className="flex items-center">
                  <Award className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Gain recognition in the art world</span>
                </li>
                <li className="flex items-center">
                  <Zap className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Increase visibility and discoverability</span>
                </li>
                <li className="flex items-center">
                  <BarChart className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Track sales and analytics</span>
                </li>
                <li className="flex items-center">
                  <Lock className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Secure blockchain-based ownership records</span>
                </li>
              </ul>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Accepted Art Types</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="grid grid-cols-2 gap-4">
                <li className="flex items-center">
                  <PaintBrush className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Paintings</span>
                </li>
                <li className="flex items-center">
                  <Camera className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Photography</span>
                </li>
                <li className="flex items-center">
                  <ImageIcon className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Digital Art</span>
                </li>
                <li className="flex items-center">
                  <Cube className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Sculptures</span>
                </li>
                <li className="flex items-center">
                  <Palette className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Mixed Media</span>
                </li>
                <li className="flex items-center">
                  <Feather className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Illustrations</span>
                </li>
                <li className="flex items-center">
                  <Aperture className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Prints</span>
                </li>
                <li className="flex items-center">
                  <Scissors className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Collages</span>
                </li>
                <li className="flex items-center">
                  <Shapes className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Installations</span>
                </li>
                <li className="flex items-center">
                  <Layers className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Textile Art</span>
                </li>
              </ul>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>App Features</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="space-y-4">
                <li className="flex items-center">
                  <Search className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Advanced artwork search and discovery</span>
                </li>
                <li className="flex items-center">
                  <BarChart className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Sales analytics and performance tracking</span>
                </li>
                <li className="flex items-center">
                  <Lock className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Secure blockchain-based ownership records</span>
                </li>
                <li className="flex items-center">
                  <DollarSign className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Integrated payment processing</span>
                </li>
                <li className="flex items-center">
                  <Globe className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Global marketplace access</span>
                </li>
              </ul>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}