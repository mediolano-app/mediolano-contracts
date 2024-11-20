'use client'

import { useState } from 'react'
import Link from 'next/link'
import { ArrowLeft, Lightbulb, FileText, Globe, Shield, DollarSign, Award, Zap, BarChart, Lock, Search, Microscope, Cog, Atom, Cpu, PowerIcon as Energy, Droplet, Leaf } from 'lucide-react'

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"

export default function PatentsRegistrationPage() {
  const [formData, setFormData] = useState({
    title: '',
    inventor: '',
    patentType: '',
    filingDate: '',
    patentNumber: '',
    status: '',
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
    alert('Patent registration submitted successfully!')
  }

  return (
    <div className="container mx-auto px-4 py-10 mb-20">
      <div className="flex items-center justify-between mb-8">
        <h1 className="text-3xl font-bold">Patent Registration</h1>
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
            <CardTitle>Patent Details</CardTitle>
            <CardDescription>Please provide information about your patent.</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="title">Patent Title</Label>
                <Input
                  id="title"
                  name="title"
                  value={formData.title}
                  onChange={handleChange}
                  placeholder="Enter the title of your patent"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="inventor">Inventor(s)</Label>
                <Input
                  id="inventor"
                  name="inventor"
                  value={formData.inventor}
                  onChange={handleChange}
                  placeholder="Enter the name(s) of the inventor(s)"
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="patentType">Patent Type</Label>
                <Select onValueChange={(value) => handleSelectChange('patentType', value)} value={formData.patentType}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select a patent type" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="utility">Utility Patent</SelectItem>
                    <SelectItem value="design">Design Patent</SelectItem>
                    <SelectItem value="plant">Plant Patent</SelectItem>
                    <SelectItem value="software">Software Patent</SelectItem>
                    <SelectItem value="business">Business Method Patent</SelectItem>
                    <SelectItem value="other">Other</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label htmlFor="filingDate">Filing Date</Label>
                <Input
                  id="filingDate"
                  name="filingDate"
                  type="date"
                  value={formData.filingDate}
                  onChange={handleChange}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="patentNumber">Patent Number (if granted)</Label>
                <Input
                  id="patentNumber"
                  name="patentNumber"
                  value={formData.patentNumber}
                  onChange={handleChange}
                  placeholder="Enter the patent number if granted"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="status">Patent Status</Label>
                <Select onValueChange={(value) => handleSelectChange('status', value)} value={formData.status}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select the patent status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="pending">Pending</SelectItem>
                    <SelectItem value="granted">Granted</SelectItem>
                    <SelectItem value="expired">Expired</SelectItem>
                    <SelectItem value="abandoned">Abandoned</SelectItem>
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
                  placeholder="Provide a brief description of your patent"
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
                <Label htmlFor="patentFile">Upload Patent Document</Label>
                <Input
                  id="patentFile"
                  type="file"
                  accept=".pdf,.doc,.docx"
                  onChange={(e) => {
                    const file = e.target.files?.[0]
                    if (file) setFile(file)
                  }}
                  required
                />
              </div>

              <Button type="submit" className="w-full">Register Patent</Button>
            </form>
          </CardContent>
        </Card>

        <div className="space-y-8">
          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground'>
            <CardHeader>
              <CardTitle>Why Register Your Patent?</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="space-y-4">
                <li className="flex items-center">
                  <Globe className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Global exposure to potential licensees and investors</span>
                </li>
                <li className="flex items-center">
                  <Shield className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Enhance protection of your intellectual property</span>
                </li>
                <li className="flex items-center">
                  <DollarSign className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Monetize your inventions through licensing or sale</span>
                </li>
                <li className="flex items-center">
                  <Award className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Gain recognition in your field of innovation</span>
                </li>
                <li className="flex items-center">
                  <Zap className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Increase visibility to potential partners or acquirers</span>
                </li>
                <li className="flex items-center">
                  <BarChart className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Track patent performance and market interest</span>
                </li>
                <li className="flex items-center">
                  <Lock className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Secure blockchain-based proof of ownership</span>
                </li>
              </ul>
            </CardContent>
          </Card>

          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground'>
            <CardHeader>
              <CardTitle>Accepted Patent Types</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="grid grid-cols-2 gap-4">
                <li className="flex items-center">
                  <Lightbulb className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Utility Patents</span>
                </li>
                <li className="flex items-center">
                  <FileText className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Design Patents</span>
                </li>
                <li className="flex items-center">
                  <Leaf className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Plant Patents</span>
                </li>
                <li className="flex items-center">
                  <Cpu className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Software Patents</span>
                </li>
                <li className="flex items-center">
                  <Cog className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Business Method Patents</span>
                </li>
                <li className="flex items-center">
                  <Microscope className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Biotechnology Patents</span>
                </li>
                <li className="flex items-center">
                  <Atom className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Chemical Patents</span>
                </li>
                <li className="flex items-center">
                  <Energy className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Energy Patents</span>
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
                  <span>Advanced patent search and discovery</span>
                </li>
                <li className="flex items-center">
                  <BarChart className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Patent performance and market interest analytics</span>
                </li>
                <li className="flex items-center">
                  <Lock className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Secure blockchain-based proof of ownership</span>
                </li>
                <li className="flex items-center">
                  <DollarSign className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Integrated licensing and transaction management</span>
                </li>
                <li className="flex items-center">
                  <Globe className="h-5 w-5 text-primary mr-2 flex-shrink-0" />
                  <span>Global patent marketplace access</span>
                </li>
              </ul>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}