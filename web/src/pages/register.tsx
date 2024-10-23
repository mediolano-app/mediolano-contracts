import Layout from '../components/layout'
import { useState } from 'react'
import { FileText, Upload, Check, AlertTriangle, Info } from 'lucide-react'

export default function Register() {
  const [step, setStep] = useState(1)
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    type: 'patent',
    ownerName: '',
    ownerEmail: '',
    files: [],
  })
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [submitStatus, setSubmitStatus] = useState<'success' | 'error' | null>(null)

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { name, value } = e.target
    setFormData(prevData => ({ ...prevData, [name]: value }))
  }

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      setFormData(prevData => ({ ...prevData, files: [...prevData.files, ...e.target.files!] }))
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsSubmitting(true)
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 2000))
    setIsSubmitting(false)
    setSubmitStatus('success')
    // Here you would typically send the data to your backend
    console.log('Form submitted:', formData)
  }

  const renderStepContent = () => {
    switch (step) {
      case 1:
        return (
          <>
            <div className="mb-4">
              <label htmlFor="title" className="block text-sm font-medium text-gray-700 mb-1">Title of Intellectual Property</label>
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
            <div className="mb-4">
              <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-1">Description</label>
              <textarea
                id="description"
                name="description"
                value={formData.description}
                onChange={handleChange}
                className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
                rows={4}
                required
              ></textarea>
            </div>
            <div className="mb-4">
              <label htmlFor="type" className="block text-sm font-medium text-gray-700 mb-1">Type of Intellectual Property</label>
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
          </>
        )
      case 2:
        return (
          <>
            <div className="mb-4">
              <label htmlFor="ownerName" className="block text-sm font-medium text-gray-700 mb-1">Owner Name</label>
              <input
                type="text"
                id="ownerName"
                name="ownerName"
                value={formData.ownerName}
                onChange={handleChange}
                className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
                required
              />
            </div>
            <div className="mb-4">
              <label htmlFor="ownerEmail" className="block text-sm font-medium text-gray-700 mb-1">Owner Email</label>
              <input
                type="email"
                id="ownerEmail"
                name="ownerEmail"
                value={formData.ownerEmail}
                onChange={handleChange}
                className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
                required
              />
            </div>
            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-1">Supporting Documents</label>
              <div className="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md">
                <div className="space-y-1 text-center">
                  <Upload className="mx-auto h-12 w-12 text-gray-400" />
                  <div className="flex text-sm text-gray-600">
                    <label htmlFor="file-upload" className="relative cursor-pointer bg-white rounded-md font-medium text-primary hover:text-primary-dark focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-primary">
                      <span>Upload a file</span>
                      <input id="file-upload" name="file-upload" type="file" className="sr-only" onChange={handleFileChange} multiple />
                    </label>
                    <p className="pl-1">or drag and drop</p>
                  </div>
                  <p className="text-xs text-gray-500">PNG, JPG, PDF up to 10MB</p>
                </div>
              </div>
            </div>
            {formData.files.length > 0 && (
              <div className="mt-4">
                <h4 className="text-sm font-medium text-gray-700 mb-2">Uploaded Files:</h4>
                <ul className="list-disc pl-5">
                  {formData.files.map((file, index) => (
                    <li key={index} className="text-sm text-gray-600">{file.name}</li>
                  ))}
                </ul>
              </div>
            )}
          </>
        )
      default:
        return null
    }
  }

  return (
    <Layout>
      <div className="max-w-2xl mx-auto">
        <h1 className="text-3xl font-bold mb-6">Register Your Intellectual Property</h1>
        <div className="bg-blue-50 border-l-4 border-blue-400 p-4 mb-6">
          <div className="flex">
            <div className="flex-shrink-0">
              <Info className="h-5 w-5 text-blue-400" />
            </div>
            <div className="ml-3">
              <p className="text-sm text-blue-700">
                Registering your IP with our blockchain-based system provides immutable proof of ownership and timestamp. This can be crucial in legal disputes or licensing negotiations.
              </p>
            </div>
          </div>
        </div>
        <div className="mb-8">
          <div className="flex items-center">
            <div className={`flex items-center justify-center w-10 h-10 rounded-full ${step >= 1 ? 'bg-primary text-white' : 'bg-gray-200 text-gray-600'}`}>
              1
            </div>
            <div className={`flex-1 h-1 mx-2 ${step >= 2 ? 'bg-primary' : 'bg-gray-200'}`}></div>
            <div className={`flex items-center justify-center w-10 h-10 rounded-full ${step >= 2 ? 'bg-primary text-white' : 'bg-gray-200 text-gray-600'}`}>
              2
            </div>
          </div>
          <div className="flex justify-between mt-2">
            <span className="text-sm font-medium">IP Details</span>
            <span className="text-sm font-medium">Owner Information</span>
          </div>
        </div>
        <form onSubmit={handleSubmit} className="bg-white shadow-md rounded-lg p-6">
          {renderStepContent()}
          <div className="flex justify-between mt-6">
            {step > 1 && (
              <button
                type="button"
                onClick={() => setStep(step - 1)}
                className="bg-gray-200 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-300 transition-colors duration-300"
              >
                Previous
              </button>
            )}
            {step < 2 ? (
              <button
                type="button"
                onClick={() => setStep(step + 1)}
                className="bg-primary text-white px-4 py-2 rounded-md hover:bg-primary-dark transition-colors duration-300 ml-auto"
              >
                Next
              </button>
            ) : (
              <button
                type="submit"
                disabled={isSubmitting}
                className="bg-primary text-white px-4 py-2 rounded-md hover:bg-primary-dark transition-colors duration-300 ml-auto disabled:opacity-50"
              >
                {isSubmitting ? 'Submitting...' : 'Register IP'}
              </button>
            )}
          </div>
        </form>
        {submitStatus && (
          <div className={`mt-4 p-4 rounded-md ${submitStatus === 'success' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
            {submitStatus === 'success' ? (
              <div className="flex items-center">
                <Check className="w-5 h-5 mr-2" />
                <span>Your intellectual property has been successfully registered on the blockchain!</span>
              </div>
            ) : (
              <div className="flex items-center">
                <AlertTriangle className="w-5 h-5 mr-2" />
                <span>An error occurred while registering your intellectual property. Please try again.</span>
              </div>
            )}
          </div>
        )}
      </div>
    </Layout>
  )
}