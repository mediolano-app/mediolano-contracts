'use client'

import { useState } from 'react'
import Link from 'next/link'
import { ArrowLeft, Book, Newspaper, Scroll, FileText, Globe, Shield, DollarSign, Award, Zap, BarChart, Lock, Search } from 'lucide-react'

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"

export default function PublicationsRegistrationPage() {
  const [formData, setFormData] = useState({
    title: '',
    author: '',
    publicationType: '',
    isbn: '',
    publicationDate: '',
    publisher: '',
    description: '',
    price: '',
  })

  const [file, setFile] = useState<File | null>(null)

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target
    setFormData(prev => ({ ...prev, [name]: value }))
  }

  const handleSelectChange = (value: string) => {
    setFormData(prev => ({ ...prev, publicationType: value }))
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    console.log(formData)
    console.log(file)
    alert('Publication registration submitted successfully!')
  }

  return (
    <div className="container mx-auto px-4 py-10 mb-20">
      <div className="flex items-center justify-between mb-8">
        <h1 className="text-3xl font-bold">Publication Registration</h1>
        <Link
          href="/register/templates"
          className="flex items-center text-sm font-medium text-muted-foreground hover:underline"
        >
          <ArrowLeft className="mr-2 h-4 w-4" />
          Back to Templates
        </Link>
      </div>

      <div className="grid gap-8 lg:grid-cols-2">
        <Card className="w-full max-w-2xl mx-auto lg:max-w-none">
          <CardHeader>
            <CardTitle>Publication Details</CardTitle>
            <CardDescription>Please provide information about your publication.</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="title">Publication Title</Label>
                <Input
                  id="title"
                  name="title"
                  value={formData.title}
                  onChange={handleChange}
                  placeholder="Enter the title of your publication"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="author">Author Name</Label>
                <Input
                  id="author"
                  name="author"
                  value={formData.author}
                  onChange={handleChange}
                  placeholder="Enter the author's name"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="publicationType">Publication Type</Label>
                <Select onValueChange={handleSelectChange} value={formData.publicationType}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select a publication type" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="book">Book</SelectItem>
                    <SelectItem value="ebook">E-Book</SelectItem>
                    <SelectItem value="article">Article</SelectItem>
                    <SelectItem value="journal">Journal</SelectItem>
                    <SelectItem value="magazine">Magazine</SelectItem>
                    <SelectItem value="newspaper">Newspaper</SelectItem>
                    <SelectItem value="other">Other</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label htmlFor="isbn">ISBN (if applicable)</Label>
                <Input
                  id="isbn"
                  name="isbn"
                  value={formData.isbn}
                  onChange={handleChange}
                  placeholder="Enter ISBN"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="publicationDate">Publication Date</Label>
                <Input
                  id="publicationDate"
                  name="publicationDate"
                  type="date"
                  value={formData.publicationDate}
                  onChange={handleChange}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="publisher">Publisher</Label>
                <Input
                  id="publisher"
                  name="publisher"
                  value={formData.publisher}
                  onChange={handleChange}
                  placeholder="Enter the publisher's name"
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
                  placeholder="Provide a brief description of your publication"
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
                <Label htmlFor="publicationFile">Upload Publication File</Label>
                <Input
                  id="publicationFile"
                  type="file"
                  accept=".pdf,.epub,.mobi,.doc,.docx"
                  onChange={(e) => {
                    const file = e.target.files?.[0]
                    if (file) setFile(file)
                  }}
                  required
                />
              </div>

              <Button type="submit" className="w-full">Register Publication</Button>
            </form>
          </CardContent>
        </Card>

        <div className="space-y-8">
          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground'>
            <CardHeader>
              <CardTitle>Why Register Your Publication?</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="space-y-4">
                <li className="flex items-center">
                  <Globe className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Global exposure to readers and publishers</span>
                </li>
                <li className="flex items-center">
                  <Shield className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Protect your intellectual property</span>
                </li>
                <li className="flex items-center">
                  <DollarSign className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Monetize your written works</span>
                </li>
                <li className="flex items-center">
                  <Award className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Gain recognition in the literary world</span>
                </li>
                <li className="flex items-center">
                  <Zap className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Increase visibility and discoverability</span>
                </li>
                <li className="flex items-center">
                  <BarChart className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Track sales and readership analytics</span>
                </li>
                <li className="flex items-center">
                  <Lock className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Secure blockchain-based copyright protection</span>
                </li>
              </ul>
            </CardContent>
          </Card>

          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground'>
            <CardHeader>
              <CardTitle>Accepted Publication Types</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="grid grid-cols-2 gap-4">
                <li className="flex items-center">
                  <Book className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Books</span>
                </li>
                <li className="flex items-center">
                  <FileText className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>E-Books</span>
                </li>
                <li className="flex items-center">
                  <Scroll className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Articles</span>
                </li>
                <li className="flex items-center">
                  <Book className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Journals</span>
                </li>
                <li className="flex items-center">
                  <Newspaper className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Magazines</span>
                </li>
                <li className="flex items-center">
                  <Newspaper className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Newspapers</span>
                </li>
                <li className="flex items-center">
                  <FileText className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Research Papers</span>
                </li>
                <li className="flex items-center">
                  <Scroll className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Manuscripts</span>
                </li>
              </ul>
            </CardContent>
          </Card>

          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground'>
            <CardHeader>
              <CardTitle>App Features</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="space-y-4">
                <li className="flex items-center">
                  <Search className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Advanced publication search and discovery</span>
                </li>
                <li className="flex items-center">
                  <BarChart className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Sales and readership analytics</span>
                </li>
                <li className="flex items-center">
                  <Lock className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Secure blockchain-based copyright protection</span>
                </li>
                <li className="flex items-center">
                  <DollarSign className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Integrated royalty management</span>
                </li>
                <li className="flex items-center">
                  <Globe className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Global distribution network</span>
                </li>
              </ul>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}