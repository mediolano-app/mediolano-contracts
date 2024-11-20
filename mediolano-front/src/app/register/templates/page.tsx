  "use client";

import { useRouter } from "next/navigation";
import type { NextPage } from "next";
import { useAccount } from "@starknet-react/core";
import { useState, FormEvent, useRef} from "react";
import { FilePlus, Lock, FileText, Coins, Shield, Globe, BarChart, Book, Music, Film, FileCode, Palette, File, ScrollText, Clock, ArrowRightLeft, ShieldCheck, Banknote, Globe2, FileLock } from 'lucide-react'
import Link from 'next/link'

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Select } from "@/components/ui/select"


export type IPType = "" | "patent" | "trademark" | "copyright" | "trade_secret";

export interface IP{
  title: string,
  description: string,
  authors: string[],
  ipType: IPType,
  uploadFile?: File,
}


const templatesIP = () => {

  const router = useRouter();
  const { address: connectedAddress, isConnected, isConnecting } = useAccount();

  const templates = [
    { name: 'Art', icon: Palette, href: '/register/templates/art', description: 'Tokenize your artwork' },
    { name: 'Documents', icon: File, href: '/register/templates/document', description: 'Preserve documents on-chain' },  
    { name: 'Movies', icon: Film, href: '/register/templates/movies', description: 'Protect your cinematic creations' }, 
    { name: 'Music', icon: Music, href: '/register/templates/music', description: 'Copyright compositions' },
    { name: 'NFT', icon: FileLock, href: '/register/templates/nft', description: 'NFT oriented design' },
    { name: 'Patents', icon: ScrollText, href: '/register/templates/patents', description: 'Secure inventions and innovations' },
    { name: 'Publications', icon: Book, href: '/register/templates/publication', description: 'Protect your written works' },
    { name: 'RWA', icon: Globe2, href: '/register/templates/rwa', description: 'Tokenize Real World Assets' },
    { name: 'Software', icon: FileCode, href: '/register/templates/software', description: 'Safeguard your code' },
  ]


  
  return (
    <>

    <div className="container mx-auto px-4 py-8 mb-20">
      <main>


    <h1 className="text-4xl font-bold text-center mb-8">IP Templates</h1>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">

        <div className="">

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
              <div className="relative rounded-lg overflow-hidden shadow-md hover:shadow-xl transition-shadow duration-300 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/75 text-foreground p-6 ">
                <div className="flex items-center mb-4">
                  <template.icon className="h-8 w-8 mr-3" />
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


        
      <div className="text-card-foreground rounded-lg">

      <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
        <CardHeader>
          <CardTitle>Blockchain IP Registration Features</CardTitle>
          <CardDescription>Secure, transparent, and efficient. Easy register your intellectual property with templates.</CardDescription>
        </CardHeader>
        <CardContent>
      <div>
        
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
      
      </CardContent>
        <CardFooter className="flex justify-between">
          <Button variant="ghost">Need help?</Button>
        </CardFooter>
      </Card>


      
    </div>

    </div>


    </main>
    </div>
      
    </>
  );
};

export default templatesIP;