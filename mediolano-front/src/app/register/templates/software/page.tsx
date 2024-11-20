'use client'

import { useState } from 'react'
import Link from 'next/link'
import { ArrowLeft, Code, User, Calendar, Tag, Globe, Copyright, FileCode, GitBranch, Package } from 'lucide-react'

const mockData = [
  { id: 1, title: 'AI-powered Image Recognition', developer: 'TechVision Inc.', releaseDate: '2023-07-15', version: '1.2.0', license: 'MIT' },
  { id: 2, title: 'Blockchain Voting System', developer: 'SecureVote LLC', releaseDate: '2023-06-20', version: '2.1.3', license: 'Apache 2.0' },
  { id: 3, title: 'Quantum Encryption Library', developer: 'QuantumSafe Solutions', releaseDate: '2023-08-10', version: '0.9.5', license: 'Proprietary' },
]

export default function SoftwareRegistration() {
  const [formData, setFormData] = useState({
    title: '',
    developer: '',
    releaseDate: '',
    version: '',
    description: '',
    programmingLanguage: '',
    operatingSystem: '',
    license: '',
    sourceCodeUrl: '',
    binaryUrl: '',
    documentation: '',
    dependencies: '',
    systemRequirements: '',
    features: '',
    knownIssues: '',
    copyright: '',
    trademark: '',
    patent: '',
  })

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value })
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    console.log('Form submitted:', formData)
    alert('Software registration successful!')
    setFormData({
      title: '',
      developer: '',
      releaseDate: '',
      version: '',
      description: '',
      programmingLanguage: '',
      operatingSystem: '',
      license: '',
      sourceCodeUrl: '',
      binaryUrl: '',
      documentation: '',
      dependencies: '',
      systemRequirements: '',
      features: '',
      knownIssues: '',
      copyright: '',
      trademark: '',
      patent: '',
    })
  }

  return (
    <div className="min-h-screen py-10 mb-20 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <Link href="/register/templates" className="inline-flex items-center text-indigo-600 hover:text-indigo-800 mb-8">
          <ArrowLeft className="h-5 w-5 mr-2" />
          Back to Templates
        </Link>
        <h1 className="text-3xl font-extrabold text-gray-900 mb-8">Software Registration</h1>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div className="bg-card shadow-md rounded-lg p-6">
            <h2 className="text-xl font-semibold mb-4">Register New Software</h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label htmlFor="title" className="block text-sm font-medium text-gray-700">Software Title</label>
                <input
                  type="text"
                  id="title"
                  name="title"
                  value={formData.title}
                  onChange={handleChange}
                  required
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="developer" className="block text-sm font-medium text-gray-700">Developer/Company</label>
                <input
                  type="text"
                  id="developer"
                  name="developer"
                  value={formData.developer}
                  onChange={handleChange}
                  required
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="releaseDate" className="block text-sm font-medium text-gray-700">Release Date</label>
                <input
                  type="date"
                  id="releaseDate"
                  name="releaseDate"
                  value={formData.releaseDate}
                  onChange={handleChange}
                  required
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="version" className="block text-sm font-medium text-gray-700">Version</label>
                <input
                  type="text"
                  id="version"
                  name="version"
                  value={formData.version}
                  onChange={handleChange}
                  required
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="description" className="block text-sm font-medium text-gray-700">Description</label>
                <textarea
                  id="description"
                  name="description"
                  value={formData.description}
                  onChange={handleChange}
                  rows={4}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                ></textarea>
              </div>
              <div>
                <label htmlFor="programmingLanguage" className="block text-sm font-medium text-gray-700">Programming Language(s)</label>
                <input
                  type="text"
                  id="programmingLanguage"
                  name="programmingLanguage"
                  value={formData.programmingLanguage}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="operatingSystem" className="block text-sm font-medium text-gray-700">Operating System(s)</label>
                <input
                  type="text"
                  id="operatingSystem"
                  name="operatingSystem"
                  value={formData.operatingSystem}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="license" className="block text-sm font-medium text-gray-700">License</label>
                <input
                  type="text"
                  id="license"
                  name="license"
                  value={formData.license}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="sourceCodeUrl" className="block text-sm font-medium text-gray-700">Source Code URL</label>
                <input
                  type="url"
                  id="sourceCodeUrl"
                  name="sourceCodeUrl"
                  value={formData.sourceCodeUrl}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="binaryUrl" className="block text-sm font-medium text-gray-700">Binary/Executable URL</label>
                <input
                  type="url"
                  id="binaryUrl"
                  name="binaryUrl"
                  value={formData.binaryUrl}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="documentation" className="block text-sm font-medium text-gray-700">Documentation URL</label>
                <input
                  type="url"
                  id="documentation"
                  name="documentation"
                  value={formData.documentation}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="dependencies" className="block text-sm font-medium text-gray-700">Dependencies</label>
                <textarea
                  id="dependencies"
                  name="dependencies"
                  value={formData.dependencies}
                  onChange={handleChange}
                  rows={3}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                ></textarea>
              </div>
              <div>
                <label htmlFor="systemRequirements" className="block text-sm font-medium text-gray-700">System Requirements</label>
                <textarea
                  id="systemRequirements"
                  name="systemRequirements"
                  value={formData.systemRequirements}
                  onChange={handleChange}
                  rows={3}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                ></textarea>
              </div>
              <div>
                <label htmlFor="features" className="block text-sm font-medium text-gray-700">Key Features</label>
                <textarea
                  id="features"
                  name="features"
                  value={formData.features}
                  onChange={handleChange}
                  rows={3}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                ></textarea>
              </div>
              <div>
                <label htmlFor="knownIssues" className="block text-sm font-medium text-gray-700">Known Issues</label>
                <textarea
                  id="knownIssues"
                  name="knownIssues"
                  value={formData.knownIssues}
                  onChange={handleChange}
                  rows={3}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                ></textarea>
              </div>
              <div>
                <label htmlFor="copyright" className="block text-sm font-medium text-gray-700">Copyright Information</label>
                <input
                  type="text"
                  id="copyright"
                  name="copyright"
                  value={formData.copyright}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="trademark" className="block text-sm font-medium text-gray-700">Trademark Information</label>
                <input
                  type="text"
                  id="trademark"
                  name="trademark"
                  value={formData.trademark}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="patent" className="block text-sm font-medium text-gray-700">Related Patents</label>
                <input
                  type="text"
                  id="patent"
                  name="patent"
                  value={formData.patent}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <button
                type="submit"
                className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                Register Software
              </button>
            </form>
          </div>

          <div className="rounded-lg p-6 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
            <h2 className="text-xl font-semibold mb-4">Your Registered Software</h2>
            <ul className="space-y-4">
              {mockData.map((item) => (
                <li key={item.id} className="border-b pb-4 last:border-b-0 last:pb-0">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center">
                      <Code className="h-5 w-5 text-indigo-500 mr-2" />
                      <span className="font-medium">{item.title}</span>
                    </div>
                    <span className="text-sm text-gray-500">{item.version}</span>
                  </div>
                  <div className="mt-2 flex items-center text-sm text-gray-500">
                    <User className="h-4 w-4 mr-1" />
                    <span>{item.developer}</span>
                    <Calendar className="h-4 w-4 ml-4 mr-1" />
                    <span>{item.releaseDate}</span>
                  </div>
                  <div className="mt-1 flex items-center text-sm text-gray-500">
                    <Tag className="h-4 w-4 mr-1" />
                    <span>{item.license}</span>
                  </div>
                
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </div>
  )
}