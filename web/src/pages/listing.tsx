import Layout from '../components/layout'
import { useState } from 'react'
import { Upload, DollarSign, Info } from 'lucide-react'

export default function Listing() {
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    type: 'patent',
    price: '',
    images: [],
  })

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { name, value } = e.target
    setFormData(prevData => ({ ...prevData, [name]: value }))
  }

  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      setFormData(prevData => ({ ...prevData, images: [...prevData.images, ...e.target.files!] }))
    }
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    // Here you would typically send the data to your backend
    console.log('Listing form submitted:', formData)
    // Reset form or show success message
  }

  return (
    <Layout>
      <div className="max-w-2xl mx-auto">
        <h1 className="text-3xl font-bold mb-6">List Your Intellectual Property</h1>
        <div className="bg-blue-50 border-l-4 border-blue-400 p-4 mb-6">
          <div className="flex">
            <div className="flex-shrink-0">
              <Info className="h-5 w-5 text-blue-400" />
            </div>
            <div className="ml-3">
              <p className="text-sm text-blue-700">
                Listing your IP on our blockchain-powered marketplace increases its visibility to potential buyers and licensees worldwide. Our smart contract system ensures secure and transparent transactions.
              </p>
            </div>
          </div>
        </div>
        <form onSubmit={handleSubmit} className="space-y-6 bg-white shadow-md rounded-lg p-6">
          <div>
            <label htmlFor="title" className="block text-sm font-medium text-gray-700 mb-1">Title</label>
            <input
              type="text"
              id="title"
              name="title"
              value={formData.title}
              onChange={handleChange}
              className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
              required
            />
          </div>
          <div>
            <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-1">Description</label>
            <textarea
              id="description"
              name="description"
              value={formData.description}
              onChange={handleChange}
              rows={4}
              className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
              required
            ></textarea>
          </div>
          <div>
            <label htmlFor="type" className="block text-sm font-medium text-gray-700 mb-1">Type of IP</label>
            <select
              id="type"
              name="type"
              value={formData.type}
              onChange={handleChange}
              className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
              required
            >
              <option value="patent">Patent</option>
              <option value="trademark">Trademark</option>
              <option value="copyright">Copyright</option>
              <option value="trade_secret">Trade Secret</option>
            </select>
          </div>
          <div>
            <label htmlFor="price" className="block text-sm font-medium text-gray-700 mb-1">Price (USD)</label>
            <div className="relative">
              <DollarSign className="absolute left-3 top-2.5 text-gray-400" />
              <input
                type="number"
                id="price"
                name="price"
                value={formData.price}
                onChange={handleChange}
                className="w-full pl-10 pr-4 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
                required
              />
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Images</label>
            <div className="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md">
              <div className="space-y-1 text-center">
                <Upload className="mx-auto h-12 w-12 text-gray-400" />
                <div className="flex text-sm text-gray-600">
                  <label htmlFor="file-upload" className="relative cursor-pointer bg-white rounded-md font-medium text-primary hover:text-primary-dark focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-primary">
                    <span>Upload images</span>
                    <input id="file-upload" name="file-upload" type="file" className="sr-only" onChange={handleImageUpload} multiple accept="image/*" />
                  </label>
                  <p className="pl-1">or drag and drop</p>
                </div>
                <p className="text-xs text-gray-500">PNG, JPG, GIF up to 10MB</p>
              </div>
            </div>
          </div>
          {formData.images.length > 0 && (
            <div>
              <h4 className="text-sm font-medium text-gray-700 mb-2">Uploaded Images:</h4>
              <ul className="list-disc pl-5">
                {Array.from(formData.images).map((file, index) => (
                  <li key={index} className="text-sm text-gray-600">{file.name}</li>
                ))}
              </ul>
            </div>
          )}
          <button
            type="submit"
            className="w-full bg-primary text-white px-4 py-2 rounded-md hover:bg-primary-dark transition-colors duration-300"
          >
            List IP
          </button>
        </form>
      </div>
    </Layout>
  )
}