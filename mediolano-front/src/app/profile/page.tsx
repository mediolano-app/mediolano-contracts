'use client';

import { useState } from 'react'
import { DollarSign, BarChart, Zap, Shield, Info } from 'lucide-react'

type IPItem = {
  id: string;
  title: string;
  type: string;
  revenue: number;
  licensees: number;
}

const ipItems: IPItem[] = [
  { id: '1', title: 'Revolutionary AI Algorithm', type: 'Patent', revenue: 50000, licensees: 3 },
  { id: '2', title: 'Eco-Friendly Packaging Design', type: 'Trademark', revenue: 25000, licensees: 5 },
  { id: '3', title: 'Bestselling Novel "The Future is Now"', type: 'Copyright', revenue: 100000, licensees: 2 },
]

export default function Profile() {
  const [selectedIP, setSelectedIP] = useState<IPItem | null>(null)

  const totalRevenue = ipItems.reduce((sum, item) => sum + item.revenue, 0)
  const totalLicensees = ipItems.reduce((sum, item) => sum + item.licensees, 0)

  return (
      <div className="max-w-6xl mx-auto mt-10 mb-20">
        <h1 className="text-3xl font-bold mb-6">Your Intellectual Property</h1>
        <div className="bg-blue-50 border-l-4 border-blue-400 p-4 mb-6">
          <div className="flex">
            <div className="flex-shrink-0">
              <Info className="h-5 w-5 text-blue-400" />
            </div>
            <div className="ml-3">
              <p className="text-sm text-blue-700">
                Our blockchain-based monetization system provides real-time tracking of your IP's performance. Smart contracts ensure automatic and transparent royalty distributions.
              </p>
            </div>
          </div>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
          <div className="bg-white p-6 rounded-lg shadow-md">
            <h2 className="text-xl font-semibold mb-4 flex items-center">
              <DollarSign className="w-6 h-6 mr-2 text-primary" />
              Total Revenue
            </h2>
            <p className="text-3xl font-bold text-primary">${totalRevenue.toLocaleString()}</p>
          </div>
          <div className="bg-white p-6 rounded-lg shadow-md">
            <h2 className="text-xl font-semibold mb-4 flex items-center">
              <BarChart className="w-6 h-6 mr-2 text-primary" />
              Total Licensees
            </h2>
            <p className="text-3xl font-bold text-primary">{totalLicensees}</p>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg shadow-md mb-8">
          <h2 className="text-xl font-semibold mb-4">Your Intellectual Property</h2>
          <div className="space-y-4">
            {ipItems.map(item => (
              <div
                key={item.id}
                className={`p-4 border rounded-md cursor-pointer transition-colors duration-300 ${
                  selectedIP?.id === item.id ? 'bg-primary text-white' : 'bg-white hover:bg-gray-50'
                }`}
                onClick={() => setSelectedIP(item)}
              >
                <h3 className="font-semibold">{item.title}</h3>
                <p className="text-sm">{item.type}</p>
                <div className="mt-2 flex justify-between">
                  <span>Revenue: ${item.revenue.toLocaleString()}</span>
                  <span>Licensees: {item.licensees}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
        {selectedIP && (
          <div className="bg-white p-6 rounded-lg shadow-md">
            <h2 className="text-xl font-semibold mb-4">Monetization Options for {selectedIP.title}</h2>
            <div className="space-y-4">
              <div className="flex items-start">
                <div className="flex-shrink-0">
                  <Zap className="h-6 w-6 text-primary" />
                </div>
                <div className="ml-3">
                  <h3 className="text-lg font-medium">Licensing</h3>
                  <p className="text-gray-600">Offer licenses to companies or individuals to use your IP for a fee or royalty.</p>
                </div>
              </div>
              <div className="flex items-start">
                <div className="flex-shrink-0">
                  <Shield className="h-6 w-6 text-primary" />
                </div>
                <div className="ml-3">
                  <h3 className="text-lg font-medium">Patent Pooling</h3>
                  <p className="text-gray-600">Join a patent pool to share your IP with others in exchange for access to their patents.</p>
                </div>
              </div>
              <div className="flex items-start">
                <div className="flex-shrink-0">
                  <DollarSign className="h-6 w-6 text-primary" />
                </div>
                <div className="ml-3">
                  <h3 className="text-lg font-medium">Direct Sales</h3>
                  <p className="text-gray-600">Sell your IP outright to interested parties for a lump sum payment.</p>
                </div>
              </div>
            </div>
            <button className="mt-6 w-full bg-primary text-white px-4 py-2 rounded-md hover:bg-primary-dark transition-colors duration-300">
              Explore Monetization Options
            </button>
          </div>
        )}
      </div>
  )
}