"use client";

import type { NextPage } from "next";
import { useAccount } from "@starknet-react/core";
import { useState } from "react";

import Link from 'next/link'
import { ArrowLeft, Edit, ArrowRight, Copy, ExternalLink, DollarSign, Calendar, Globe } from 'lucide-react'



const mockLicense = {
  id: 1,
  name: 'License 1',
  ipName: 'Patent A',
  ipId: 1,
  licensee: 'Company X',
  value: 10000,
  currency: 'USD',
  startDate: '2023-08-01',
  endDate: '2028-07-31',
  territory: 'Worldwide',
  type: 'Non-exclusive',
  terms: 'This license grants the right to manufacture and sell products based on Patent A...',
}




const viewLicense: NextPage = () => {
  const { address: connectedAddress, isConnected, isConnecting } = useAccount();
  

  return (
    <>
     
     
     <div className="min-h-screen py-12 px-4 sm:px-6 lg:px-8">



          <div className="max-w-4xl mx-auto">
        <Link href="/licensing" className="inline-flex items-center btn mb-6">
          <ArrowLeft className="w-4 h-4 mr-2" />
          Back to Licensing
        </Link>

        <div className="shadow-lg rounded-lg overflow-hidden bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/75 text-foreground">
          <div className="p-6">
            <h1 className="text-3xl font-bold mb-4">{mockLicense.name}</h1>
            <Link href={`/ip/${mockLicense.ipId}`} className="text-lg text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300 mb-4 inline-block">
              {mockLicense.ipName}
            </Link>

            <div className="grid grid-cols-2 gap-4 mb-6">
              <div>
                <p className="text-sm ">Licensee</p>
                <p className="font-semibold">{mockLicense.licensee}</p>
              </div>
              <div>
                <p className="text-sm ">Value</p>
                <p className="font-semibold">{mockLicense.value} {mockLicense.currency}</p>
              </div>
              <div>
                <p className="text-sm ">Start Date</p>
                <p className="font-semibold">{mockLicense.startDate}</p>
              </div>
              <div>
                <p className="text-sm ">End Date</p>
                <p className="font-semibold">{mockLicense.endDate}</p>
              </div>
              <div>
                <p className="text-sm ">Territory</p>
                <p className="font-semibold">{mockLicense.territory}</p>
              </div>
              <div>
                <p className="text-sm ">Type</p>
                <p className="font-semibold">{mockLicense.type}</p>
              </div>
            </div>

            <h2 className="text-2xl font-semibold mb-4">License Terms</h2>
            <p className="mb-6">{mockLicense.terms}</p>

            <div className="flex flex-wrap gap-4 pt-10">
              <button className="flex items-center px-4 py-2 rounded-full hover:bg-blue-600 transition duration-300">
                <Edit className="w-5 h-5 mr-2" />
                Edit License
              </button>
              <button className="flex items-center px-4 py-2 rounded-full hover:bg-blue-600 transition duration-300">
                <ArrowRight className="w-5 h-5 mr-2" />
                Transfer License
              </button>
              <button className="flex items-center px-4 py-2 rounded-full hover:bg-blue-600 transition duration-300">
                <Copy className="w-5 h-5 mr-2" />
                Duplicate License
              </button>
              <button className="flex items-center px-4 py-2 rounded-full hover:bg-blue-600 transition duration-300">
                <ExternalLink className="w-5 h-5 mr-2" />
                List on Marketplace
              </button>
            </div>
          </div>
        </div>

        
      </div>


    </div>  
    </>
  );
};

export default viewLicense;
