"use client";

import type { NextPage } from "next";
import { useAccount } from "@starknet-react/core";
import { useState } from "react";
import Image from 'next/image'
import Link from 'next/link'
import { ArrowUpRight, ArrowDownRight, Filter, ChevronLeft, ChevronRight } from 'lucide-react'





const transfersIP: NextPage = () => {
  const { address: connectedAddress, isConnected, isConnecting } = useAccount();

  const [currentPage, setCurrentPage] = useState(1)
  const [filterType, setFilterType] = useState('all')
  const itemsPerPage = 10

  const allTransfers = [
    { id: 1, type: 'incoming', item: 'AI Algorithm', from: '0x1234...5678', to: '0xabcd...efgh', amount: 50, date: '2023-06-05' },
    { id: 2, type: 'outgoing', item: 'Batman Movie Critic', from: '0xabcd...efgh', to: '0x9876...5432', amount: 25, date: '2023-06-04' },
    { id: 3, type: 'incoming', item: 'Biotech Patent', from: '0x2468...1357', to: '0xabcd...efgh', amount: 100, date: '2023-06-03' },
    { id: 4, type: 'outgoing', item: 'Smart Home System', from: '0xabcd...efgh', to: '0x3698...7412', amount: 75, date: '2023-06-02' },
    { id: 5, type: 'incoming', item: 'Renewable Energy Tech', from: '0x9876...5432', to: '0xabcd...efgh', amount: 150, date: '2023-06-01' },
    { id: 6, type: 'outgoing', item: 'Eco-Packaging Design', from: '0xabcd...efgh', to: '0x9876...5432', amount: 25, date: '2023-06-04' },
  ]

  const filteredTransfers = allTransfers.filter(transfer => 
    filterType === 'all' || transfer.type === filterType
  )

  const totalPages = Math.ceil(filteredTransfers.length / itemsPerPage)
  const startIndex = (currentPage - 1) * itemsPerPage
  const endIndex = startIndex + itemsPerPage
  const currentTransfers = filteredTransfers.slice(startIndex, endIndex)

  

  return (
    <>
     
     
     <div className="py-10 mb-20 px-4 sm:px-6 lg:px-8">

     <h1 className="text-2xl font-bold mb-8">Recent IP Transfers</h1>

      <div className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/25 rounded text-foreground p-6">
      
      <div className="mb-4 flex justify-between items-center ">
        <div >
          <label htmlFor="filter" className="mr-2">Filter:</label>
          <select
            id="filter"
            value={filterType}
            onChange={(e) => setFilterType(e.target.value)}
            className="input rounded-md p-2 bg-base-300"
          >
            <option value="all">All</option>
            <option value="incoming">Incoming</option>
            <option value="outgoing">Outgoing</option>
          </select>
        </div>
        <button className="hover:bg-blue-600 py-2 px-4 rounded inline-flex items-center text-sm">
          <Filter className="mr-2" />
          Advanced Filters
        </button>
      </div>
      <div className="overflow-x-auto bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/75 rounded text-foreground">
        <table className="min-w-full bg-base-300">
          <thead>
            <tr className="  uppercase text-sm leading-normal">
              <th className="py-3 px-6 text-left">Type</th>
              <th className="py-3 px-6 text-left">Item</th>
              <th className="py-3 px-6 text-left">From</th>
              <th className="py-3 px-6 text-left">To</th>
              <th className="py-3 px-6 text-left">Value (ETH)</th>
              <th className="py-3 px-6 text-left">Date</th>
            </tr>
          </thead>
          <tbody className=" text-sm font-light">
            {currentTransfers.map((transfer) => (
              <tr key={transfer.id} className="border-b border-gray-200 hover:bg-gray-100">
                <td className="py-3 px-6 text-left whitespace-nowrap">
                  {transfer.type === 'incoming' ? (
                    <span className="text-green-500 flex items-center">
                      <ArrowDownRight className="mr-1" /> Incoming
                    </span>
                  ) : (
                    <span className="text-red-500 flex items-center">
                      <ArrowUpRight className="mr-1" /> Outgoing
                    </span>
                  )}
                </td>
                <td className="py-3 px-6 text-left">{transfer.item}</td>
                <td className="py-3 px-6 text-left">{transfer.from}</td>
                <td className="py-3 px-6 text-left">{transfer.to}</td>
                <td className="py-3 px-6 text-left">{transfer.amount}</td>
                <td className="py-3 px-6 text-left">{transfer.date}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="mt-4 flex justify-between items-center">
        <div>
          Showing {startIndex + 1} to {Math.min(endIndex, filteredTransfers.length)} of {filteredTransfers.length} entries
        </div>
        <div className="flex items-center space-x-2">
          <button
            onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
            disabled={currentPage === 1}
            className=" font-bold py-2 px-4 rounded inline-flex items-center"
          >
            <ChevronLeft className="mr-2" /> Previous
          </button>
          <span>{currentPage} of {totalPages}</span>
          <button
            onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
            disabled={currentPage === totalPages}
            className=" font-bold py-2 px-4 rounded inline-flex items-center"
          >
            Next <ChevronRight className="ml-2" />
          </button>
        </div>
      </div>
      
      </div>


    </div>  
    </>
  );
};

export default transfersIP;
