import { useState } from 'react'
import { Search, FileText, DollarSign, Calendar, Info } from 'lucide-react'

import IPLicensingForm from '@/components/IPLicensingForm'


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

export default function License() {

  
  const [selectedIP, setSelectedIP] = useState<IPItem | null>(null)
  const [searchTerm, setSearchTerm] = useState('')
  const [formData, setFormData] = useState({
    licenseeCompany: '',
    licenseeEmail: '',
    licenseType: 'exclusive',
    duration: '',
    terms: '',
  })

  const filteredItems = ipItems.filter(item =>
    item.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
    item.owner.toLowerCase().includes(searchTerm.toLowerCase())
  )

  

  return (
      <div className="max-w-6xl mx-auto">
        <h1 className="text-3xl font-bold mb-6">License Intellectual Property</h1>
        <div className="bg-blue-100 dark:bg-blue-900 border-l-4 border-blue-400 p-4 mb-6">
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
            <h4 className="text-xl font-semibold mb-4">Select Intellectual Property</h4>
            <div className="mb-4">
              <div className="relative">
                <input
                  type="text"
                  placeholder="Search IP..."
                  className="w-full pl-10 pr-4 py-2 rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
                <Search className="absolute left-3 top-2.5" />
              </div>
            </div>
            <div className="space-y-4">
              {filteredItems.map(item => (
                <div
                  key={item.id}
                  className={`p-4 shadow bg-white dark:bg-black rounded-md cursor-pointer transition-colors duration-300 ${
                    selectedIP?.id === item.id ? 'text-primary' : 'hover:bg-secondary'
                  }`}
                  onClick={() => setSelectedIP(item)}
                >
                  <h3 className="font-semibold">{item.title}</h3>
                  <p className="text-sm">{item.type} - {item.owner}</p>
                </div>
              ))}
            </div>
          </div>
          <div className='bg-med shadow rounded p-5 bg-white dark:bg-black'>
            <h2 className="text-xl font-semibold mb-4">License Details</h2>
            

            <IPLicensingForm/>


          </div>
        </div>
      </div>
  )
}