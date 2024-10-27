"use client"

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

import {
  toast
} from "sonner"
import {
  useForm
} from "react-hook-form"
import {
  zodResolver
} from "@hookform/resolvers/zod"
import * as z from "zod"
import {
  cn
} from "@/lib/utils"
import {
  Button
} from "@/components/ui/button"
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form"
import {
  Input
} from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  Textarea
} from "@/components/ui/textarea"
import {
  format
} from "date-fns"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"
import {
  Calendar
} from "@/components/ui/calendar"
import {
  Calendar as CalendarIcon
} from "lucide-react"

const formSchema = z.object({
  title: z.string(),
  type: z.string(),
  description: z.string(),
  author: z.string(),
  date: z.coerce.date().optional(),
  mediaurl: z.string().optional(),
  version: z.string().optional()
});

export default function IPRegister() {

  const form = useForm < z.infer < typeof formSchema >> ({
    resolver: zodResolver(formSchema),

  })

  function onSubmit(values: z.infer < typeof formSchema > ) {
    try {
      console.log(values);
      toast(
        <pre className="mt-2 w-[340px] rounded-md bg-slate-950 p-4">
          <code className="text-white">{JSON.stringify(values, null, 2)}</code>
        </pre>
      );
    } catch (error) {
      console.error("Form submission error", error);
      toast.error("Failed to submit the form. Please try again.");
    }
  }




  const templates = [
    { name: 'Art', icon: Palette, href: '/registerArt', description: 'Tokenize your Artwork' },
    { name: 'Documents', icon: File, href: '/registerDocument', description: 'Safeguard Documents On-Chain' },  
    { name: 'Films', icon: Film, href: '/registerFilm', description: 'Protect your cinematic creations' }, 
    { name: 'Music', icon: Music, href: '/registerMusic', description: 'Copyright Compositions' },
    { name: 'Patents', icon: ScrollText, href: '/registerPatent', description: 'Secure Inventions and Innovations' },
    { name: 'Publications', icon: Book, href: '/registerPublication', description: 'Protect your Written Works' },
    { name: 'RWA', icon: Globe2, href: '/registerRWA', description: 'Tokenize Real World Assets' },
    { name: 'Software', icon: FileCode, href: '/registerSoftware', description: 'Safeguard your Code' },
    { name: 'Custom', icon: Coins, href: '/registerIP', description: 'Edit Your Template' },
  ];



  return (

    <>
    
    <Layout>
      <div className="container mx-auto px-4 py-8">
        <h1 className="text-4xl font-bold text-center mb-8">Intellectual Property Registration</h1>


    <div className="grid grid-cols-1 md:grid-cols-2 gap-8">

    <div className="rounded-lg">
    <Card>
    <CardHeader>
      <CardTitle>Create new IP</CardTitle>
      <CardDescription>Register your intellectual property on Starknet blockchain.</CardDescription>
    </CardHeader>
    <CardContent>

    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-8 max-w-3xl mx-auto py-10">
        
        <FormField
          control={form.control}
          name="title"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Ttitle</FormLabel>
              <FormControl>
                <Input 
                placeholder="Title"
                
                type="text"
                {...field} />
              </FormControl>
              <FormDescription>The title of your intellectual property</FormDescription>
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
                    <SelectValue placeholder="Select the type of your IP" />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value="m@example.com">m@example.com</SelectItem>
                  <SelectItem value="m@google.com">m@google.com</SelectItem>
                  <SelectItem value="m@support.com">m@support.com</SelectItem>
                </SelectContent>
              </Select>
                <FormDescription>The type of your Intellectual Property</FormDescription>
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
                  placeholder="The Content of Your Intellectual Property"
                  className="resize-none"
                  {...field}
                />
              </FormControl>
              <FormDescription>Insert the content of your IP</FormDescription>
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
                <Input 
                placeholder="Author(s)"
                
                type=""
                {...field} />
              </FormControl>
              <FormDescription>Your IP public display author(s).</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
      <FormField
      control={form.control}
      name="date"
      render={({ field }) => (
        <FormItem className="flex flex-col">
          <FormLabel>Creation</FormLabel>
          <Popover>
            <PopoverTrigger asChild>
              <FormControl>
                <Button
                  variant={"outline"}
                  className={cn(
                    "w-[240px] pl-3 text-left font-normal",
                    !field.value && "text-muted-foreground"
                  )}
                >
                  {field.value ? (
                    format(field.value, "PPP")
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
                initialFocus
              />
            </PopoverContent>
          </Popover>
       <FormDescription>Public date of birth</FormDescription>
          <FormMessage />
        </FormItem>
      )}
    />
        
        <FormField
          control={form.control}
          name="mediaurl"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Media URL</FormLabel>
              <FormControl>
                <Input 
                placeholder="https://"
                
                type=""
                {...field} />
              </FormControl>
              <FormDescription>IP Media Thumbnail</FormDescription>
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
                <Input 
                placeholder=""
                
                type=""
                {...field} />
              </FormControl>
              <FormDescription>IP Version (optional)</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        <Button type="submit">Submit</Button>
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
    
    </>

  )
}