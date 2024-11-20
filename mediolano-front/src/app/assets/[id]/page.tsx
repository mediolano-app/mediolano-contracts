"use client";

import type { NextPage } from "next";
import { useAccount } from "@starknet-react/core";
import { useState } from "react";

import Image from 'next/image'
import Link from 'next/link'
import { ArrowLeft, Plus, LinkIcon, ArrowRight, DollarSign, Shield, Globe, Clock, File, Users, Activity } from 'lucide-react'

const mockIP = {
  id: 1,
  name: 'Intellectual Property Title',
  type: 'Copyright',
  description: 'Intellectual property description.',
  thumbnailUrl: '/background.jpg',
  filingDate: '2024-09-15',
  grantDate: '2024-09-20',
  expirationDate: '2025-09-20',
  owner: 'Stark',
  tags: ['Review', 'Art'],
  patentNumber: 'US 12345678',
  status: 'Active',
  licenses: [
    { id: 1, name: 'EV Manufacturing License', licensee: 'ElectroCar Corp', value: 1000000, currency: 'USD', type: 'Exclusive' },
    { id: 2, name: 'Grid Storage License', licensee: 'PowerGrid Solutions', value: 750000, currency: 'USD', type: 'Non-exclusive' },
  ],
  activity: [
    { date: '2023-08-15', action: 'License granted to ElectroCar Corp' },
    { date: '2023-09-01', action: 'License granted to PowerGrid Solutions' },
    { date: '2023-10-10', action: 'Maintenance fee paid' },
    { date: '2023-11-05', action: 'Citation by new patent application' },
  ]
}



const viewIP: NextPage = () => {
  const { address: connectedAddress, isConnected, isConnecting } = useAccount();
  

  return (
    <>
     
     
     <div className="min-h-screen py-10 mb-20 px-4 sm:px-6 lg:px-8">

          <div className="max-w-6xl mx-auto">
            
            <div className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground rounded-lg overflow-hidden">
              <div className="md:flex">
                <div className="md:flex-shrink-0">
                  <Image
                    src={mockIP.thumbnailUrl}
                    alt={mockIP.name}
                    width={600}
                    height={400}
                    className="h-48 w-full object-cover md:h-full "
                  />
                </div>
                <div className="p-8">
                  <div className="uppercase tracking-wide text-sm text-blue-500 font-semibold">{mockIP.type}</div>
                  <h1 className="mt-1 text-3xl font-bold">{mockIP.name}</h1>
                  <p className="mt-2  ">{mockIP.description}</p>
                </div>
              </div>
    
              <div className="border-t border-gray-200 dark:border-gray-700">
                <dl>
                  <div className="  px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium  ">License Number</dt>
                    <dd className="mt-1 text-sm  sm:mt-0 sm:col-span-2">{mockIP.patentNumber}</dd>
                  </div>
                  <div className="bg-base-100  px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium  ">Status</dt>
                    <dd className="mt-1 text-sm  sm:mt-0 sm:col-span-2">{mockIP.status}</dd>
                  </div>
                  <div className="  px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium  ">Owner</dt>
                    <dd className="mt-1 text-sm  sm:mt-0 sm:col-span-2">{mockIP.owner}</dd>
                  </div>
                  <div className="bg-base-100  px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium  ">tags</dt>
                    <dd className="mt-1 text-sm  sm:mt-0 sm:col-span-2">{mockIP.tags.join(', ')}</dd>
                  </div>
                  <div className="  px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium  ">Filing Date</dt>
                    <dd className="mt-1 text-sm  sm:mt-0 sm:col-span-2">{mockIP.filingDate}</dd>
                  </div>
                  <div className="bg-base-100  px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium  ">Grant Date</dt>
                    <dd className="mt-1 text-sm  sm:mt-0 sm:col-span-2">{mockIP.grantDate}</dd>
                  </div>
                  <div className="  px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium  ">Expiration Date</dt>
                    <dd className="mt-1 text-sm  sm:mt-0 sm:col-span-2">{mockIP.expirationDate}</dd>
                  </div>
                </dl>
              </div>
            </div>
    
            <div className="mt-8 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground rounded-lg overflow-hidden">
              <div className="px-4 py-5 sm:px-6">
                <h2 className="text-lg font-medium ">Licenses</h2>
                <p className="mt-1 max-w-2xl text-sm  ">Details of current licenses for this intellectual property.</p>
              </div>
              <div className="border-t border-gray-200 dark:border-gray-700">
                <ul role="list" className="divide-y divide-gray-200 dark:divide-gray-700">
                  {mockIP.licenses.map((license) => (
                    <li key={license.id} className="px-4 py-4 sm:px-6">
                      <div className="flex items-center justify-between">
                        <p className="text-sm font-medium text-blue-600 truncate">{license.name}</p>
                        <div className="ml-2 flex-shrink-0 flex">
                          <p className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                            {license.type}
                          </p>
                        </div>
                      </div>
                      <div className="mt-2 sm:flex sm:justify-between">
                        <div className="sm:flex">
                          <p className="flex items-center text-sm  ">
                            <Users className="flex-shrink-0 mr-1.5 h-5 w-5 text-gray-400" aria-hidden="true" />
                            {license.licensee}
                          </p>
                        </div>
                        <div className="mt-2 flex items-center text-sm   sm:mt-0">
                          <DollarSign className="flex-shrink-0 mr-1.5 h-5 w-5 text-gray-400" aria-hidden="true" />
                          <p>
                            {license.value.toLocaleString()} {license.currency}
                          </p>
                        </div>
                      </div>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
    
            <div className="mt-8 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground rounded-lg overflow-hidden">
              <div className="px-4 py-5 sm:px-6">
                <h2 className="text-lg font-medium ">Activity</h2>
                <p className="mt-1 max-w-2xl text-sm  ">Recent activity related to this intellectual property.</p>
              </div>
              <div className="border-t border-gray-200 dark:border-gray-700">
                <ul role="list" className="divide-y divide-gray-200 dark:divide-gray-700">
                  {mockIP.activity.map((item, index) => (
                    <li key={index} className="px-4 py-4 sm:px-6">
                      <div className="flex items-center">
                        <Activity className="flex-shrink-0 mr-3 h-5 w-5 text-gray-400" aria-hidden="true" />
                        <p className="text-sm ">{item.action}</p>
                      </div>
                      <div className="mt-2 flex items-center text-sm  ">
                        <Clock className="flex-shrink-0 mr-1.5 h-5 w-5 text-gray-400" aria-hidden="true" />
                        <p>{item.date}</p>
                      </div>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
    
            {/* 
            <div className="mt-8 flex flex-wrap gap-4">
              <Link href={`/ip/${mockIP.id}/new-license`} className="flex items-center px-4 py-2 bg-green-500 text-white rounded-full hover:bg-green-600 transition duration-300">
                <Plus className="w-5 h-5 mr-2" />
                New License
              </Link>
              <Link href={`/ip/${mockIP.id}/licenses`} className="flex items-center px-4 py-2 bg-blue-500 text-white rounded-full hover:bg-blue-600 transition duration-300">
                <LinkIcon className="w-5 h-5 mr-2" />
                All Licenses
              </Link>
              <Link href={`/ip/${mockIP.id}/transfer`} className="flex items-center px-4 py-2 bg-orange-500 text-white rounded-full hover:bg-orange-600 transition duration-300">
                <ArrowRight className="w-5 h-5 mr-2" />
                Transfer IP
              </Link>
            </div>
              */}
          </div>

    </div>  
    </>
  );
};

export default viewIP;
