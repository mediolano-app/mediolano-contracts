'use client';
import { useState } from 'react';
import { Search, Info, Book, Copyright, FileText, Image, Music, Video, DollarSign, Clock, Gavel, Users, Lock, Cpu, LinkIcon, MoreVertical, Eye, Copy, FileSignature } from 'lucide-react'

import IPLicensingForm from '@/components/IPLicensingForm'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { Button } from "@/components/ui/button"
import { useRouter } from 'next/navigation'

type IPItem = {
  id: string;
  title: string;
  type: string;
  owner: string;
}

const ipItems: IPItem[] = [
  { id: '1', title: 'Revolutionary AI Algorithm', type: 'Patent', owner: 'Tech Innovations Inc.' },
  { id: '2', title: 'Eco-Friendly Packaging Design', type: 'Trademark', owner: 'Green Solutions Ltd.' },
  { id: '3', title: 'Bestselling Novel "The Future is Now"', type: 'Copyright', owner: 'Jane Doe' },
]

// Mock data for previously registered IPs
const mockIPs = [
  { id: 1, name: "Novel: The Cosmic Journey", type: "Book", status: "Listed", price: "0.5 ETH", image: "/background.jpg" },
  { id: 2, name: "Song: Echoes of Tomorrow", type: "Music", status: "Pending", price: "0.2 ETH", image: "/background.jpg" },
  { id: 3, name: "Artwork: Nebula Dreams", type: "Image", status: "Listed", price: "1.5 ETH", image: "/background.jpg" },
  { id: 4, name: "Screenplay: The Last Frontier", type: "Text", status: "Draft", price: "N/A", image: "/background.jpg" },
  { id: 5, name: "Short Film: Beyond the Stars", type: "Video", status: "Listed", price: "3 ETH", image: "/background.jpg" },
]

const Licensing = () => {

  const [selectedIP, setSelectedIP] = useState<IPItem | null>(null)
  const [searchTerm, setSearchTerm] = useState('')
  const [formData, setFormData] = useState({
    licenseeCompany: '',
    licenseeEmail: '',
    licenseType: 'exclusive',
    duration: '',
    terms: '',
  })

  const filteredItems = mockIPs.filter(item =>
    item.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    item.type.toLowerCase().includes(searchTerm.toLowerCase())
  )


  const router = useRouter()

  const handleNavigation = (id: string) => {
    router.push('/licensing/view/1')
  }


  return (
    <>
    <div className="grid items-center justify-items-center min-h-screen p-4 py-10 mb-20 sm:p-10]">
    <main className="flex flex-col gap-8 row-start-2 items-center sm:items-start">
    
    <div className="max-w-6xl mx-auto">
        
        <h1 className="text-3xl font-bold mb-6">License Intellectual Property</h1>
        
        <div className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground rounded-lg p-6 mb-6">
          <div className="flex">
            <div className="flex-shrink-0">
              <Info className="h-5 w-5" />
            </div>
            <div className="ml-3">
              <p className="text-sm">
                Our blockchain-based licensing system ensures transparent and immutable record-keeping. Smart contracts can be used to automate royalty payments and enforce license terms.
              </p>


            </div>
          </div>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          
          
          <div>
            <h4 className="mb-4">Registered Intellectual Property</h4>
            
            
            <div className="space-y-4">
              {mockIPs.map((ip) => (
              <Card key={ip.id} className="hover:shadow-lg transition-shadow duration-300 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/75 text-foreground">
                <CardHeader className="flex flex-row items-center space-y-0 pb-2">
                  <CardTitle className="text-lg">{ip.name}</CardTitle>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button variant="ghost" className="h-8 w-8 p-0 ml-auto">
                        <span className="sr-only">Open menu</span>
                        <MoreVertical className="h-4 w-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem>
                        <Eye className="mr-2 h-4 w-4" />
                        <Button variant="ghost"  key={ip.id} onClick={() => handleNavigation(ip.id)}>View Details</Button>
                      </DropdownMenuItem>
                      <DropdownMenuItem>
                        <Copy className="mr-2 h-4 w-4" />
                        <span>Create New Listing</span>
                      </DropdownMenuItem>
                      <DropdownMenuItem>
                        <FileSignature className="mr-2 h-4 w-4" />
                        <span>Create License</span>
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </CardHeader>
                <CardContent>
                  <div className="flex items-center space-x-4">
                    <img src={ip.image} alt={ip.name} className="w-24 h-24 object-cover rounded-md" />
                    <div>
                      <p className="text-sm text-muted-foreground mb-1">{ip.type}</p>
                      <p className={`text-sm font-medium ${
                        ip.status === "Listed" ? "text-green-500" :
                        ip.status === "Pending" ? "text-yellow-500" :
                        "text-gray-500"
                      }`}>
                        Status: {ip.status}
                      </p>
                      <p className="text-sm font-semibold mt-1">{ip.price}</p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
            </div>
          </div>
          
          
          
          
          <div className='bg-med shadow rounded p-5 bg-card'>
            <h2 className="text-xl font-semibold mb-4">License Details</h2>
            

            <IPLicensingForm/>


          </div>
        </div>
      </div>
      </main>
      </div>
    </>
  );
};
export default Licensing;