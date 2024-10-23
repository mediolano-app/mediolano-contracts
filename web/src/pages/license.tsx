import Layout from '../components/layout'
import { useState } from 'react'
import { Search, FileText, DollarSign, Calendar, Info } from 'lucide-react'

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

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { name, value } = e.target
    setFormData(prevData => ({ ...prevData, [name]: value }))
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    // Here you would typically send the data to your backend
    console.log('License form submitted:', { ...formData, selectedIP })
    // Reset form or show success message
  }

  return (
    <Layout>
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold mb-6">License Intellectual Property</h1>
        <div className="bg-blue-50 border-l-4 border-blue-400 p-4 mb-6">
          <div className="flex">
            <div className="flex-shrink-0">
              <Info className="h-5 w-5 text-blue-400" />
            </div>
            <div className="ml-3">
              <p className="text-sm text-blue-700">
                Our blockchain-based licensing system ensures transparent and immutable record-keeping. Smart contracts can be used to automate royalty payments and enforce license terms.
              </p>
            </div>
          </div>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div>
            <h2 className="text-xl font-semibold mb-4">Select Intellectual Property</h2>
            <div className="mb-4">
              <div className="relative">
                <input
                  type="text"
                  placeholder="Search IP..."
                  className="w-full pl-10 pr-4 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
                <Search className="absolute left-3 top-2.5 text-gray-400" />
              </div>
            </div>
            <div className="space-y-4">
              {filteredItems.map(item => (
                <div
                  key={item.id}
                  className={`p-4 border rounded-md cursor-pointer transition-colors duration-300 ${
                    selectedIP?.id === item.id ? 'bg-primary text-white' : 'bg-white hover:bg-gray-50'
                  }`}
                  onClick={() => setSelectedIP(item)}
                >
                  <h3 className="font-semibold">{item.title}</h3>
                  <p className="text-sm">{item.type} - {item.owner}</p>
                </div>
              ))}
            </div>
          </div>
          <div>
            <h2 className="text-xl font-semibold mb-4">License Details</h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label htmlFor="licenseeCompany" className="block text-sm font-medium text-gray-700 mb-1">Licensee Company</label>
                <input
                  type="text"
                  id="licenseeCompany"
                  name="licenseeCompany"
                  value={formData.licenseeCompany}
                  onChange={handleChange}
                  className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
                  required
                />
              </div>
              <div>
                <label htmlFor="licenseeEmail" className="block text-sm font-medium text-gray-700 mb-1">Licensee Email</label>
                <input
                  type="email"
                  id="licenseeEmail"
                  name="licenseeEmail"
                  value={formData.licenseeEmail}
                  onChange={handleChange}
                  className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
                  required
                />
              </div>
              <div>
                <label htmlFor="licenseType" className="block text-sm font-medium text-gray-700 mb-1">License Type</label>
                <select
                  id="licenseType"
                  name="licenseType"
                  value={formData.licenseType}
                  onChange={handleChange}
                  className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
                  required
                >
                  <option value="exclusive">Exclusive</option>
                  <option value="non-exclusive">Non-Exclusive</option>
                  <option value="sole">Sole</option>
                </select>
              </div>
              <div>
                <label htmlFor="duration" className="block text-sm font-medium text-gray-700 mb-1">Duration (in months)</label>
                <input
                  type="number"
                  id="duration"
                  name="duration"
                  value={formData.duration}
                  onChange={handleChange}
                  className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
                  required
                />
              </div>
              <div>
                <label htmlFor="terms" className="block text-sm font-medium text-gray-700 mb-1">Additional Terms</label>
                <textarea
                  id="terms"
                  name="terms"
                  value={formData.terms}
                  onChange={handleChange}
                  rows={4}
                  className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
                ></textarea>
              </div>
              <button
                type="submit"
                disabled={!selectedIP}
                className="w-full bg-primary text-white px-4 py-2 rounded-md hover:bg-primary-dark transition-colors duration-300 disabled:opacity-50"
              >
                Submit License Request
              </button>
            </form>
          </div>
        </div>
      </div>
    </Layout>
  )
}