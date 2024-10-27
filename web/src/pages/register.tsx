'use client'


import Layout from '../components/layout'
import { useState } from 'react'
import { FilePlus, Lock, FileText, Coins, Shield, Globe, BarChart, Book, Music, Film, FileCode, Palette, File, ScrollText, Clock, ArrowRightLeft, ShieldCheck, Banknote, Globe2 } from 'lucide-react'
import Link from 'next/link'
import { pinataClient } from '@/utils/pinataClient'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { useRouter } from 'next/navigation'
import { useAccount, useNetwork, useContract, useSendTransaction } from '@starknet-react/core'
import { type Abi } from "starknet"
import { abi } from '@/abis/abi'


import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import * as z from 'zod'
import { format } from 'date-fns'
import { Calendar as CalendarIcon, Upload } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { Calendar } from '@/components/ui/calendar'
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form'
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover'
import { cn } from '@/lib/utils'

const formSchema = z.object({
  title: z.string().min(1, 'Title is required'),
  type: z.string().optional(),
  description: z.string().min(1, 'Description is required'),
  author: z.string().min(1, 'Author is required'),
  date: z.date({
    required_error: 'Date is required',
  }),
  tags: z.string().optional(),
  file: z.any().optional(),
  mediaUrl: z.string().url().optional().or(z.literal('')),
  version: z.string().optional(),
  standard: z.string({
    required_error: 'Standard is required',
  }),
  chain: z.string({
    required_error: 'Chain is required',
  }),
  dapp: z.string({
    required_error: 'Dapp is required',
  }),
})



export type IPType = "" | "patent" | "trademark" | "copyright" | "trade_secret";

export interface IP{
  title: string,
  description: string,
  authors: string[] | string,
  ipType: IPType,
  uploadFile?: File,
}


export default function Register() {



  

  return (
    <Layout>
      <div className="container mx-auto px-4 py-8">


        <h1 className="text-4xl font-bold text-center mb-8">Intellectual Property Registration</h1>


    <div className="grid grid-cols-1 md:grid-cols-2 gap-8">

    <div className="bg-card bg-primary text-card-foreground rounded-lg shadow-lg">

    <Card>
    <CardHeader>
      <CardTitle>Create new IP</CardTitle>
      <CardDescription>Register your intellectual property on Starknet blockchain.</CardDescription>
    </CardHeader>
    <CardContent>
    
      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-8">
          <FormField
            control={form.control}
            name="title"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Title</FormLabel>
                <FormControl>
                  <Input placeholder="Enter title" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="type"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Type</FormLabel>
                <Select onValueChange={field.onChange} defaultValue={field.value}>
                  <FormControl>
                    <SelectTrigger>
                      <SelectValue placeholder="Select type" />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    <SelectItem value="Generic">Generic</SelectItem>
                    <SelectItem value="Patent">Patent</SelectItem>
                    <SelectItem value="Trademark">Trademark</SelectItem>
                    <SelectItem value="Copyright">Copyright</SelectItem>
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="description"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Description</FormLabel>
                <FormControl>
                  <Textarea
                    placeholder="Enter description"
                    className="resize-none"
                    {...field}
                  />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="author"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Author</FormLabel>
                <FormControl>
                  <Input placeholder="Enter author name" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="date"
            render={({ field }) => (
              <FormItem className="flex flex-col">
                <FormLabel>Date</FormLabel>
                <Popover>
                  <PopoverTrigger asChild>
                    <FormControl>
                      <Button
                        variant={'outline'}
                        className={cn(
                          'w-[240px] pl-3 text-left font-normal',
                          !field.value && 'text-muted-foreground'
                        )}
                      >
                        {field.value ? (
                          format(field.value, 'PPP')
                        ) : (
                          <span>Pick a date</span>
                        )}
                        <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                      </Button>
                    </FormControl>
                  </PopoverTrigger>
                  <PopoverContent className="w-auto p-0" align="start">
                    <Calendar
                      mode="single"
                      selected={field.value}
                      onSelect={field.onChange}
                      disabled={(date) =>
                        date > new Date() || date < new Date('1900-01-01')
                      }
                      initialFocus
                    />
                  </PopoverContent>
                </Popover>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="tags"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Tags</FormLabel>
                <FormControl>
                  <Input placeholder="Enter tags (comma-separated)" {...field} />
                </FormControl>
                <FormDescription>
                  Separate multiple tags with commas
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="file"
            render={({ field: { value, onChange, ...field } }) => (
              <FormItem>
                <FormLabel>File Upload</FormLabel>
                <FormControl>
                  <Input
                    type="file"
                    {...field}
                    onChange={(event) => {
                      const file = event.target.files?.[0]
                      onChange(file)
                    }}
                  />
                </FormControl>
                <FormDescription>Upload a file (optional)</FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="mediaUrl"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Media URL</FormLabel>
                <FormControl>
                  <Input placeholder="Enter media URL" {...field} />
                </FormControl>
                <FormDescription>Enter a URL for media (optional)</FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="version"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Version</FormLabel>
                <FormControl>
                  <Input placeholder="Enter version" {...field} />
                </FormControl>
                <FormDescription>Enter a version number (optional)</FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="standard"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Standard</FormLabel>
                <Select onValueChange={field.onChange} defaultValue={field.value}>
                  <FormControl>
                    <SelectTrigger>
                      <SelectValue placeholder="Select standard" />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    <SelectItem value="ERC-721">ERC-721</SelectItem>
                    <SelectItem value="ERC-1155">ERC-1155</SelectItem>
                    <SelectItem value="ERC-20">ERC-20</SelectItem>
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="chain"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Chain</FormLabel>
                <Select onValueChange={field.onChange} defaultValue={field.value}>
                  <FormControl>
                    <SelectTrigger>
                      <SelectValue placeholder="Select chain" />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    <SelectItem value="Starknet">Starknet</SelectItem>
                    <SelectItem value="Ethereum">Ethereum</SelectItem>
                    <SelectItem value="Polygon">Polygon</SelectItem>
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="dapp"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Dapp</FormLabel>
                <Select onValueChange={field.onChange} defaultValue={field.value}>
                  <FormControl>
                    <SelectTrigger>
                      <SelectValue placeholder="Select dapp" />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    <SelectItem value="Mediolano">Mediolano</SelectItem>
                    <SelectItem value="Other1">Other1</SelectItem>
                    <SelectItem value="Other2">Other2</SelectItem>
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )}
          />

          <Button type="submit">Register IP</Button>
        </form>
      </Form>
    
  
  </CardContent>
    <CardFooter className="flex justify-between">
    </CardFooter>
  </Card>
  </div>



  



    
    
    
  <div className="text-card-foreground rounded-lg">
  <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <h2 className="text-1xl mb-8">
      Register with a template:
    </h2>
    
    <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 mb-16">
      {templates.map((template) => (
        <Link
          key={template.name}
          href={template.href}
          className="block group"
        >
          <div className="relative rounded-lg overflow-hidden shadow-md hover:shadow-xl transition-shadow duration-300 p-6">
            <div className="flex items-center mb-4">
              <template.icon className="h-8 w-8 text-secondary mr-3" />
              <h3 className="text-xl font-semibold">{template.name}</h3>
            </div>
            <p className="">{template.description}</p>
            <div className="mt-4 flex items-center text-indigo-600 group-hover:text-indigo-500">
              <span className="text-sm font-medium">Open</span>
              <svg className="ml-2 w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </div>
          </div>
        </Link>
      ))}
    </div>

  </main>
</div>

</div>


<div className="grid grid-cols-1 md:grid-cols-2 gap-8 mt-10">

  <div className="text-card-foreground rounded-lg p-6">

    <div className="py-2">
      <h2 className="text-2xl font-semibold mb-2">Blockchain IP Registration Features</h2>
      <p className="text-muted-foreground mb-4">Secure, transparent, and efficient</p>
      </div>
    
      <ul className="space-y-6">
        <li className="flex items-start">
          <Lock className="w-6 h-6 mr-3 flex-shrink-0" />
          <div>
            <h3 className="font-semibold mb-1">Immutable Protection</h3>
            <p className="text-sm text-muted-foreground">Your IP is securely stored on the blockchain, providing tamper-proof evidence of ownership and creation date.</p>
          </div>
        </li>
        <li className="flex items-start">
          <FileText className="w-6 h-6 mr-3 flex-shrink-0" />
          <div>
            <h3 className="font-semibold mb-1">Smart Licensing</h3>
            <p className="text-sm text-muted-foreground">Utilize smart contracts for automated licensing agreements, ensuring proper attribution and compensation.</p>
          </div>
        </li>
        <li className="flex items-start">
          <Coins className="w-6 h-6 mr-3 flex-shrink-0" />
          <div>
            <h3 className="font-semibold mb-1">Tokenized Monetization</h3>
            <p className="text-sm text-muted-foreground">Transform your IP into digital assets, enabling fractional ownership and new revenue streams.</p>
          </div>
        </li>
        <li className="flex items-start">
          <Shield className="w-6 h-6 mr-3 flex-shrink-0" />
          <div>
            <h3 className="font-semibold mb-1">Enhanced Security</h3>
            <p className="text-sm text-muted-foreground">Benefit from blockchain's cryptographic security, protecting your IP from unauthorized access and tampering.</p>
          </div>
        </li>
        <li className="flex items-start">
          <Globe className="w-6 h-6 mr-3 flex-shrink-0" />
          <div>
            <h3 className="font-semibold mb-1">Global Accessibility</h3>
            <p className="text-sm text-muted-foreground">Access and manage your IP rights from anywhere in the world, facilitating international collaborations and licensing.</p>
          </div>
        </li>
        <li className="flex items-start">
          <BarChart className="w-6 h-6 mr-3 flex-shrink-0" />
          <div>
            <h3 className="font-semibold mb-1">Analytics and Insights</h3>
            <p className="text-sm text-muted-foreground">Gain valuable insights into your IP portfolio's performance and market trends through blockchain-powered analytics.</p>
          </div>
        </li>
      </ul>
    </div>


    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Why Use Blockchain for IP Transfers?</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center space-x-4">
            <ArrowRightLeft className="w-8 h-8 " />
            <div>
              <h3 className="font-semibold">Seamless Transfers</h3>
              <p>Quick and efficient ownership transfers with blockchain verification</p>
            </div>
          </div>
          <div className="flex items-center space-x-4">
            <ShieldCheck className="w-8 h-8 " />
            <div>
              <h3 className="font-semibold">Secure Transactions</h3>
              <p>Cryptographically secured transfers prevent fraud and disputes</p>
            </div>
          </div>
          <div className="flex items-center space-x-4">
            <Banknote className="w-8 h-8 " />
            <div>
              <h3 className="font-semibold">Transparent Pricing</h3>
              <p>Clear and immutable record of sale prices and terms</p>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Transfer/Sale Process</CardTitle>
        </CardHeader>
        <CardContent>
          <ol className="list-decimal list-inside space-y-2">
            <li>Select the IP you want to transfer or sell</li>
            <li>Choose the transaction type and set terms</li>
            <li>Enter the recipient's blockchain wallet address</li>
            <li>Set the price (for sales) or transfer conditions</li>
            <li>Confirm the transaction with your digital signature</li>
            <li>Buyer makes payment and claims digital assets</li>
            <li>Blockchain records the transfer of ownership</li>
          </ol>
        </CardContent>
      </Card>
    </div>



  </div>
</div>
    </Layout>
  )
}
