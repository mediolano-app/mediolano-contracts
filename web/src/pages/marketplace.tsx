import { useState } from 'react'
import { Search, Filter, Tag, DollarSign, Clock, User, MessageSquare, Info } from 'lucide-react'

type IPItem = {
  id: string;
  title: string;
  type: string;
  owner: string;
  price: number;
  description: string;
  createdAt: string;
}

const ipItems: IPItem[] = [
  { id: '1', title: 'Revolutionary AI Algorithm', type: 'Patent', owner: 'Tech Innovations Inc.', price: 100000, description: 'A groundbreaking AI algorithm that improves machine learning efficiency by 50%.', createdAt: '2023-05-15' },
  { id: '2', title: 'Eco-Friendly Packaging Design', type: 'Trademark', owner: 'Green Solutions Ltd.', price: 50000, description: 'Innovative packaging design that reduces plastic waste by 75%.', createdAt: '2023-06-01' },
  { id: '3', title: 'Bestselling Novel "The Future is Now"', type: 'Copyright', owner: 'Jane Doe', price: 75000, description: 'Rights to a critically acclaimed sci-fi novel with movie adaptation potential.', createdAt: '2023-04-22' },
  { id: '4', title: 'Smart Home Energy Management System', type: 'Patent', owner: 'EcoTech Innovations', price: 150000, description: 'An IoT-based system that optimizes home energy consumption, reducing bills by up to 30%.', createdAt: '2023-05-30' },
  { id: '5', title: 'Organic Superfood Blend', type: 'Trademark', owner: 'NutriLife Inc.', price: 80000, description: 'A unique blend of organic superfoods, backed by nutritional research.', createdAt: '2023-06-10' },
  { id: '6', title: 'Virtual Reality Fitness Program', type: 'Copyright', owner: 'FitTech Solutions', price: 120000, description: 'An immersive VR fitness program that has gained popularity among tech-savvy health enthusiasts.', createdAt: '2023-05-05' },
]

export default function Marketplace() {
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedType, setSelectedType] = useState('All')
  const [selectedItem, setSelectedItem] = useState<IPItem | null>(null)
  const [isModalOpen, setIsModalOpen] = useState(false)

  const filteredItems = ipItems.filter(item => 
    (item.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
    item.description.toLowerCase().includes(searchTerm.toLowerCase())) &&
    (selectedType === 'All' || item.type === selectedType)
  )

  const handleExpressInterest = (item: IPItem) => {
    setSelectedItem(item)
    setIsModalOpen(true)
  }

  return (
      <div className="max-w-6xl mx-auto">
        <h1 className="text-3xl font-bold mb-6">IP Marketplace</h1>
        <div className="bg-blue-50 border-l-4 border-blue-400 p-4 mb-6">
          <div className="flex">
            <div className="flex-shrink-0">
              <Info className="h-5 w-5 text-blue-400" />
            </div>
            <div className="ml-3">
              <p className="text-sm text-blue-700">
                Our blockchain-powered marketplace ensures secure and transparent transactions. Each listing is verified and backed by immutable blockchain records, providing confidence to both buyers and sellers.
              </p>
            </div>
          </div>
        </div>
        <div className="mb-8 flex flex-col sm:flex-row gap-4">
          <div className="relative flex-grow">
            <input
              type="text"
              placeholder="Search IP..."
              className="w-full pl-10 pr-4 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
            <Search className="absolute left-3 top-2.5 text-gray-400" />
          </div>
          <div className="relative">
            <select
              className="appearance-none w-full pl-10 pr-8 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
              value={selectedType}
              onChange={(e) => setSelectedType(e.target.value)}
            >
              <option>All</option>
              <option>Patent</option>
              <option>Trademark</option>
              <option>Copyright</option>
            </select>
            <Filter className="absolute left-3 top-2.5 text-gray-400" />
          </div>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredItems.map(item => (
            <div key={item.id} className="border rounded-lg p-6 shadow-md hover:shadow-lg transition-shadow duration-300">
              <h2 className="text-xl font-semibold mb-2">{item.title}</h2>
              <p className="text-gray-600 mb-4">{item.description}</p>
              <div className="flex items-center mb-2">
                <Tag className="w-4 h-4 mr-2 text-primary" />
                <span className="text-sm font-medium text-gray-600">{item.type}</span>
              </div>
              <div className="flex items-center mb-2">
                <User className="w-4 h-4 mr-2 text-primary" />
                <span className="text-sm text-gray-600">{item.owner}</span>
              </div>
              <div className="flex items-center mb-2">
                <DollarSign className="w-4 h-4 mr-2 text-primary" />
                <span className="text-lg font-bold text-primary">${item.price.toLocaleString()}</span>
              </div>
              <div className="flex items-center mb-4">
                <Clock className="w-4 h-4 mr-2 text-primary" />
                <span className="text-sm text-gray-600">Listed on {new Date(item.createdAt).toLocaleDateString()}</span>
              </div>
              <button
                onClick={() => handleExpressInterest(item)}
                className="w-full bg-primary text-white px-4 py-2 rounded-md hover:bg-primary-dark transition-colors duration-300"
              >
                Express Interest
              </button>
            </div>
          ))}
        </div>
      </div>
      {isModalOpen && selectedItem && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-6 max-w-md w-full">
            <h2 className="text-2xl font-bold mb-4">Express Interest</h2>
            <p className="mb-4">You are expressing interest in:</p>
            <p className="font-semibold mb-2">{selectedItem.title}</p>
            <p className="text-gray-600 mb-4">{selectedItem.description}</p>
            <form className="space-y-4">
              <div>
                <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-1">Your Name</label>
                <input type="text" id="name" name="name" className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary" required />
              </div>
              <div>
                <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">Your Email</label>
                <input type="email" id="email" name="email" className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary" required />
              </div>
              <div>
                <label htmlFor="message" className="block text-sm font-medium text-gray-700 mb-1">Message</label>
                <textarea id="message" name="message" rows={3} className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary" required></textarea>
              </div>
              <div className="flex justify-end space-x-4">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 border rounded-md hover:bg-gray-100 transition-colors duration-300"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-primary text-white rounded-md hover:bg-primary-dark transition-colors duration-300"
                >
                  Send
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
  )
}