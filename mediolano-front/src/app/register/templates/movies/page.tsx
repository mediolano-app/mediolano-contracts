'use client'

import { useState } from 'react'
import Link from 'next/link'
import { ArrowLeft, Film, Video, Tv, Globe, Shield, DollarSign, Award, Zap, BarChart, Lock, Search, Clapperboard, Camera, Music } from 'lucide-react'

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"

export default function FilmsRegistrationPage() {
  const [formData, setFormData] = useState({
    title: '',
    director: '',
    filmType: '',
    releaseDate: '',
    duration: '',
    genre: '',
    description: '',
    price: '',
  })

  const [file, setFile] = useState<File | null>(null)

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target
    setFormData(prev => ({ ...prev, [name]: value }))
  }

  const handleSelectChange = (name: string, value: string) => {
    setFormData(prev => ({ ...prev, [name]: value }))
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    console.log(formData)
    console.log(file)
    alert('Film registration submitted successfully!')
  }

  return (
    <div className="container mx-auto px-4 py-10 mb-20">
      <div className="flex items-center justify-between mb-8">
        <h1 className="text-3xl font-bold">Movie Registration</h1>
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
            <CardTitle>Film Details</CardTitle>
            <CardDescription>Please provide information about your film.</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="title">Film Title</Label>
                <Input
                  id="title"
                  name="title"
                  value={formData.title}
                  onChange={handleChange}
                  placeholder="Enter the title of your film"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="director">Director</Label>
                <Input
                  id="director"
                  name="director"
                  value={formData.director}
                  onChange={handleChange}
                  placeholder="Enter the director's name"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="filmType">Film Type</Label>
                <Select onValueChange={(value) => handleSelectChange('filmType', value)} value={formData.filmType}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select a film type" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="feature">Feature Film</SelectItem>
                    <SelectItem value="short">Short Film</SelectItem>
                    <SelectItem value="documentary">Documentary</SelectItem>
                    <SelectItem value="animation">Animation</SelectItem>
                    <SelectItem value="series">TV Series</SelectItem>
                    <SelectItem value="other">Other</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label htmlFor="releaseDate">Release Date</Label>
                <Input
                  id="releaseDate"
                  name="releaseDate"
                  type="date"
                  value={formData.releaseDate}
                  onChange={handleChange}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="duration">Duration (minutes)</Label>
                <Input
                  id="duration"
                  name="duration"
                  type="number"
                  value={formData.duration}
                  onChange={handleChange}
                  min={1}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="genre">Genre</Label>
                <Select onValueChange={(value) => handleSelectChange('genre', value)} value={formData.genre}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select a genre" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="action">Action</SelectItem>
                    <SelectItem value="comedy">Comedy</SelectItem>
                    <SelectItem value="drama">Drama</SelectItem>
                    <SelectItem value="scifi">Science Fiction</SelectItem>
                    <SelectItem value="horror">Horror</SelectItem>
                    <SelectItem value="romance">Romance</SelectItem>
                    <SelectItem value="thriller">Thriller</SelectItem>
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
                  placeholder="Provide a brief description of your film"
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
                <Label htmlFor="filmFile">Upload Film File or Trailer</Label>
                <Input
                  id="filmFile"
                  type="file"
                  accept="video/*"
                  onChange={(e) => {
                    const file = e.target.files?.[0]
                    if (file) setFile(file)
                  }}
                  required
                />
              </div>

              <Button type="submit" className="w-full">Register Film</Button>
            </form>
          </CardContent>
        </Card>

        <div className="space-y-8">
          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 text-foreground'>
            <CardHeader>
              <CardTitle>Why Register Your Film?</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="space-y-4">
                <li className="flex items-center">
                  <Globe className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Global exposure to audiences and distributors</span>
                </li>
                <li className="flex items-center">
                  <Shield className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Protect your intellectual property</span>
                </li>
                <li className="flex items-center">
                  <DollarSign className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Monetize your cinematic creations</span>
                </li>
                <li className="flex items-center">
                  <Award className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Gain recognition in the film industry</span>
                </li>
                <li className="flex items-center">
                  <Zap className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Increase visibility and discoverability</span>
                </li>
                <li className="flex items-center">
                  <BarChart className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Track viewership and revenue analytics</span>
                </li>
                <li className="flex items-center">
                  <Lock className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Secure blockchain-based copyright protection</span>
                </li>
              </ul>
            </CardContent>
          </Card>

          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 text-foreground'>
            <CardHeader>
              <CardTitle>Accepted Film Types</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="grid grid-cols-2 gap-4">
                <li className="flex items-center">
                  <Film className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Feature Films</span>
                </li>
                <li className="flex items-center">
                  <Video className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Short Films</span>
                </li>
                <li className="flex items-center">
                  <Clapperboard className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Documentaries</span>
                </li>
                <li className="flex items-center">
                  <Tv className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>TV Series</span>
                </li>
                <li className="flex items-center">
                  <Camera className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Animations</span>
                </li>
                <li className="flex items-center">
                  <Music className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Music Videos</span>
                </li>
                <li className="flex items-center">
                  <Video className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Web Series</span>
                </li>
                <li className="flex items-center">
                  <Clapperboard className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Experimental Films</span>
                </li>
              </ul>
            </CardContent>
          </Card>

          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 text-foreground'>
            <CardHeader>
              <CardTitle>App Features</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="space-y-4">
                <li className="flex items-center">
                  <Search className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Advanced film search and discovery</span>
                </li>
                <li className="flex items-center">
                  <BarChart className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Viewership and revenue analytics</span>
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