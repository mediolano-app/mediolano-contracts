'use client';
import { FC, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import dynamic from 'next/dynamic';
import { useAccount, useBalance, useBlockNumber, useContract, useReadContract, useSendTransaction, useTransactionReceipt } from '@starknet-react/core';
import { BlockNumber, Contract, RpcProvider } from "starknet";
import { ABI } from "../abis/abi";
import { type Abi } from "starknet";
import { formatAmount, shortenAddress } from '@/lib/utils';
import Link from "next/link"
import Image from "next/image";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ArrowRight, BookOpen, Download, HeartHandshake, List, MessageSquare, ShieldCheck } from 'lucide-react';

const WalletBar = dynamic(() => import('../components/WalletBar'), { ssr: false })
const Page: FC = () => {



  return (
   <div className="flex flex-col min-h-screen">
      
      <main className="flex-1">
        <section className="w-full py-12 md:py-24 lg:py-32 xl:py-48">
          <div className="container px-4 md:px-6">
            <div className="flex flex-col items-center space-y-4 text-center">
              <div className="space-y-2">
                <h1 className="text-3xl font-bold tracking-tighter sm:text-4xl md:text-5xl lg:text-6xl/none">
                Your gateway to own intellectual properties
                </h1>
                <br></br>
                <h3 className="text-3xl font-bold tracking-tighter sm:text-2xl md:text-3xl lg:text-4xl/none">
                Powered by Starknet 
                </h3>
                <p className="mx-auto max-w-[700px]">
                  Register, license, and market your ntellectual property with ease. Secure your ideas and innovations today.
                </p>
              </div>
              <div className="space-x-4">
                <Button >
                  <Link href="/register">Get Started</Link>
                </Button>
                <Button variant="outline" >
                  <Link href="/about">Learn More</Link>
                </Button>
              </div>
            </div>
          </div>
        </section>
        
        
        <section className="w-full py-12 md:py-24 lg:py-32">
          <div className="container px-4 md:px-6">
            <h2 className="text-3xl font-bold tracking-tighter sm:text-5xl text-center mb-12">Services</h2>
            <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              <Card className="bg-base-200">
                <CardHeader>
                  <BookOpen className="h-6 w-6 mb-2" />
                  <CardTitle>Registration</CardTitle>
                </CardHeader>
                <CardContent>
                  <p>Register your intellectual property quickly and securely.</p>
                  <Button className="mt-4" variant="outline" >
                    <Link href="/registerIP">Register Now <ArrowRight className="ml-2 h-4 w-4" /></Link>
                  </Button>
                </CardContent>
              </Card>
              <Card className="bg-base-200">
                <CardHeader>
                  <List className="h-6 w-6 mb-2" />
                  <CardTitle>Listing</CardTitle>
                </CardHeader>
                <CardContent>
                  <p>List your intellectual property for potential buyers or licensees.</p>
                  <Button className="mt-4" variant="outline" >
                    <Link href="/listingIP">List Property <ArrowRight className="ml-2 h-4 w-4" /></Link>
                  </Button>
                </CardContent>
              </Card>
              <Card className="bg-base-200">
                <CardHeader>
                  <HeartHandshake className="h-6 w-6 mb-2" />
                  <CardTitle>Licensing</CardTitle>
                </CardHeader>
                <CardContent>
                  <p>License your intellectual property to interested parties.</p>
                  <Button className="mt-4" variant="outline" >
                    <Link href="/licensingIP">License Now <ArrowRight className="ml-2 h-4 w-4" /></Link>
                  </Button>
                </CardContent>
              </Card>
              <Card className="bg-base-200">
                <CardHeader>
                  <HeartHandshake className="h-6 w-6 mb-2" />
                  <CardTitle>Monetize</CardTitle>
                </CardHeader>
                <CardContent>
                  <p>Trade or transfer your digital assets.</p>
                  <Button className="mt-4" variant="outline" >
                    <Link href="/monetizeIP">Open Trade <ArrowRight className="ml-2 h-4 w-4" /></Link>
                  </Button>
                </CardContent>
              </Card>
              <Card className="bg-base-200">
                <CardHeader>
                  <Download className="h-6 w-6 mb-2" />
                  <CardTitle>Resources</CardTitle>
                </CardHeader>
                <CardContent>
                  <p>Access and download important documents and resources.</p>
                  <Button className="mt-4" variant="outline" >
                    <Link href="https://docs.mediolano.app">Visit <ArrowRight className="ml-2 h-4 w-4" /></Link>
                  </Button>
                </CardContent>
              </Card>
              <Card className="bg-base-200">
                <CardHeader>
                  <MessageSquare className="h-6 w-6 mb-2" />
                  <CardTitle>Support</CardTitle>
                </CardHeader>
                <CardContent>
                  <p>Get help and support for all your IP-related queries.</p>
                  <Button className="mt-4" variant="outline" >
                    <Link href="/support">Get Support <ArrowRight className="ml-2 h-4 w-4" /></Link>
                  </Button>
                </CardContent>
              </Card>
            </div>
          </div>
        </section>



        
        <section className="container px-4 md:px-6">
        <h2 className="text-3xl font-bold mb-6">Mediolano Features</h2>
        <ul className="list-disc pl-6 space-y-4">
          <li>Unparalleled security through blockchain technology</li>
          <li>Streamlined registration and management processes</li>
          <li>Global accessibility and transparency</li>
          <li>Reduced costs compared to traditional IP registration methods</li>
          <li>Integrated marketplace for monetizing your intellectual property</li>
        </ul>
      </section>





      </main>
      
    </div>
  );
};

export default Page;