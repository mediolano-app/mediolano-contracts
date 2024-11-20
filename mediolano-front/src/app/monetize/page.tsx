"use client";

import type { NextPage } from "next";
import { useAccount } from "@starknet-react/core";
import { useState } from "react";
import { DollarSign, BarChart2, Users, Globe } from 'lucide-react'
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import Link from 'next/link'

const monetizeIP: NextPage = () => {
  const { address: connectedAddress, isConnected, isConnecting } = useAccount();



  const [activeTab, setActiveTab] = useState('opportunities')

  const dummyOpportunities = [
    { id: 1, title: 'AI Algorithm Licensing', type: 'Copyright', potential: 'High', industry: 'Technology' },
    { id: 2, title: 'New paper for Zero-Knowledge', type: 'Creative Commons', potential: 'Medium', industry: 'Technology' },
    { id: 3, title: 'New sci-fi series review', type: 'License', potential: 'Very High', industry: 'Arts' },
  ]

  const dummyRoyalties = [
    { id: 1, title: 'AI Algorithm License', licensee: 'Mediolano', amount: 50000, date: '2023-05-15', contract: '0x...' },
    { id: 2, title: 'The Batman movie critic', licensee: 'Ambrosia.com.br', amount: 25000, date: '2021-05-10', contract: '0x...' },
    { id: 3, title: 'MindWave Trademark Use', licensee: 'SmartHome Solutions', amount: 10000, date: '2020-05-05', contract: '0x...' },
  ]


      

  return (
    <>
      <div className="flex justify-center flex-col" >

        <div className="flex justify-center mb-10 mt-20">
           <h1 className="text-3xl font-bold mb-6">Monetize Your Intellectual Property</h1>
        </div>  


      <div className="max-w-6xl mx-auto">

      <div className="space-y-8">
      
      <div className="grid md:grid-cols-2 gap-6">
        <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
          <CardHeader>
            <CardTitle>Licensing</CardTitle>
            <CardDescription>Grant rights to use your IP</CardDescription>
          </CardHeader>
          <CardContent>
            <p className="mb-4">Create customized licensing agreements to allow others to use your intellectual property while maintaining ownership.</p>
            <Button variant="secondary" asChild>
              <Link href="/licensing">Create</Link>
            </Button>
          </CardContent>
        </Card>
        <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
          <CardHeader>
            <CardTitle>Selling</CardTitle>
            <CardDescription>Transfer ownership of your IP</CardDescription>
          </CardHeader>
          <CardContent>
            <p className="mb-4">Create a sale contract to another address.</p>
            <Button variant="secondary" asChild>
              <Link href="/sell">Sell IP</Link>
            </Button>
          </CardContent>
        </Card>
        {/*}
        <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
          <CardHeader>
            <CardTitle>Royalties</CardTitle>
            <CardDescription>Revenue opportunities</CardDescription>
          </CardHeader>
          <CardContent>
            <p className="mb-4">Find potential partners to develop or commercialize your intellectual property.</p>
            <Button variant="secondary" asChild>
              <Link href="/">Explore</Link>
            </Button>
          </CardContent>
        </Card>*/}
        
        <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
          <CardHeader>
            <CardTitle>Crowdfunding </CardTitle>
            <CardDescription>Raise funds for your IP</CardDescription>
          </CardHeader>
          <CardContent>
            <p className="mb-4">Launch a crowdfunding campaign to support the development or promotion of your intellectual property.</p>
            <Button variant="secondary" asChild>
              <Link href="/">Start</Link>
            </Button>
          </CardContent>
        </Card>
        
        <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
          <CardHeader>
            <CardTitle>Marketplace </CardTitle>
            <CardDescription>List your IP on our Marketplace</CardDescription>
          </CardHeader>
          <CardContent>
            <p className="mb-4">Showcase and license your intellectual property on blockchain.</p>
            <Button variant="secondary" asChild>
              <Link href="/marketplace">Enter</Link>
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>


      </div>














        

     <div> 

          
      <div className="flex items-center flex-col pt-10 mt-20">
        <div className="">
        <h2 className="text-3xl font-bold mb-6">Opportunities</h2>
        </div>
      </div>
        
        
        <div className="max-w-6xl mx-auto my-10 p-5 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
          <p className="mb-6">Maximize the value of your intellectual property through various monetization strategies.</p>
          
          <div className="mb-6">
            <div className="border-b border-gray-200">
              <nav className="-mb-px flex">
                <button
                  onClick={() => setActiveTab('opportunities')}
                  className={`py-2 px-4 text-center border-b-2 font-medium text-sm ${
                    activeTab === 'opportunities'
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  Licensing
                </button>
                <button
                  onClick={() => setActiveTab('royalties')}
                  className={`ml-8 py-2 px-4 text-center border-b-2 font-medium text-sm ${
                    activeTab === 'royalties'
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  Royalties
                </button>
              </nav>
            </div>
          </div>
    
          {activeTab === 'opportunities' && (
            <div>
              <h2 className="text-2xl font-semibold mb-4">Licensing Opportunities</h2>
              <div className="overflow-x-auto">
                <table className="min-w-full bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
                  <thead>
                    <tr className="">
                      <th className="py-2 px-4 border-b text-left">Title</th>
                      <th className="py-2 px-4 border-b text-left">Type</th>
                      <th className="py-2 px-4 border-b text-left">Potential</th>
                      <th className="py-2 px-4 border-b text-left">Industry</th>
                      <th className="py-2 px-4 border-b text-left">Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {dummyOpportunities.map((opportunity) => (
                      <tr key={opportunity.id}>
                        <td className="py-6 px-4 border-b">{opportunity.title}</td>
                        <td className="py-6 px-4 border-b">{opportunity.type}</td>
                        <td className="py-6 px-4 border-b">{opportunity.potential}</td>
                        <td className="py-6 px-4 border-b">{opportunity.industry}</td>
                        <td className="py-6 px-4 border-b">
                          <button className="bg-secondary px-3 py-1 rounded">
                            Explore
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
    
          {activeTab === 'royalties' && (
            <div>
              <h2 className="text-2xl font-semibold mb-4">Royalty Management</h2>
              <div className="overflow-x-auto">
                <table className="min-w-full bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
                  <thead>
                    <tr className="">
                      <th className="py-2 px-4 border-b text-left">Title</th>
                      <th className="py-2 px-4 border-b text-left">Licensee</th>
                      <th className="py-2 px-4 border-b text-left">Amount</th>
                      <th className="py-2 px-4 border-b text-left">Date</th>
                      <th className="py-2 px-4 border-b text-left">Contract</th>
                    </tr>
                  </thead>
                  <tbody>
                    {dummyRoyalties.map((royalty) => (
                      <tr key={royalty.id}>
                        <td className="py-6 px-4 border-b">{royalty.title}</td>
                        <td className="py-6 px-4 border-b">{royalty.licensee}</td>
                        <td className="py-6 px-4 border-b">${royalty.amount.toLocaleString()}</td>
                        <td className="py-6 px-4 border-b">{royalty.date}</td>
                        <td className="py-6 px-4 border-b"><a className="btn">{royalty.contract}</a></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
    
          
        </div>

          </div>

       

      <div className="flex items-center flex-col pt-10 mt-10">
        <div className="">
        <h2 className="text-3xl font-bold mb-6">Resources</h2>
        </div>
      </div> 
    

      <div className="max-w-6xl mx-auto mb-20">
        <div className="mt-8 grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground p-4 rounded">
              <h2 className="text-xl font-semibold mb-2 flex items-center">
                <DollarSign className="h-6 w-6 mr-2 text-blue-500" />
                Monetization Strategies
              </h2>
              <ul className="list-disc pl-5 space-y-2">
                <li>Licensing and royalties</li>
                <li>Strategic partnerships</li>
                <li>IP-backed financing</li>
                <li>Direct sales of IP rights</li>
              </ul>
            </div>
            <div className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground p-4 rounded">
              <h2 className="text-xl font-semibold mb-2 flex items-center">
                <BarChart2 className="h-6 w-6 mr-2 text-green-500" />
                Market Insights
              </h2>
              <ul className="list-disc pl-5 space-y-2">
                <li>Industry trend analysis</li>
                <li>Competitor IP portfolios</li>
                <li>Valuation services</li>
                <li>Market demand forecasts</li>
              </ul>
            </div>
          </div>
    
          <div className="mt-6 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground p-4 rounded">
            <h2 className="text-xl font-semibold mb-2 flex items-center">
              <Users className="h-6 w-6 mr-2 text-purple-500" />
              Expert Support
            </h2>
            <p>Our team of IP monetization experts is here to help you maximize the value of your intellectual property. Schedule a consultation to discuss your unique IP portfolio and explore tailored monetization strategies.</p>
            <button className="mt-4 bg-purple-500 text-white px-6 py-2 rounded hover:bg-purple-600">
              Contact our Team
            </button>
          </div>


        </div>












      </div>

      
    </>
  );
};

export default monetizeIP;
