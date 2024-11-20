'use client'

import { useState } from 'react'
import Link from 'next/link'
import { ArrowLeft, FileText, User, Calendar, Tag, Globe, Copyright, FileType, Lock } from 'lucide-react'

const mockData = [
  { id: 1, title: 'Annual Financial Report 2023', author: 'Finance Department', date: '2023-12-31', type: 'Financial', accessLevel: 'Confidential' },
  { id: 2, title: 'Employee Handbook v2.1', author: 'HR Department', date: '2023-06-15', type: 'Policy', accessLevel: 'Internal' },
  { id: 3, title: 'Product Roadmap Q3 2023', author: 'Product Team', date: '2023-07-01', type: 'Strategy', accessLevel: 'Restricted' },
  { id: 4, title: 'Notes: Music Gear', author: 'Me', date: '2024-11-01', type: 'Personal', accessLevel: 'Internal' },
]

export default function DocumentRegistration() {
  const [formData, setFormData] = useState({
    title: '',
    author: '',
    date: '',
    documentType: '',
    description: '',
    version: '',
    department: '',
    accessLevel: '',
    fileUrl: '',
    tags: '',
    relatedDocuments: '',
    expirationDate: '',
    language: '',
    reviewStatus: '',
    approvedBy: '',
    lastModified: '',
    fileFormat: '',
    fileSize: '',
    copyright: '',
  })

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value })
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    console.log('Form submitted:', formData)
    alert('Document registration successful!')
    setFormData({
      title: '',
      author: '',
      date: '',
      documentType: '',
      description: '',
      version: '',
      department: '',
      accessLevel: '',
      fileUrl: '',
      tags: '',
      relatedDocuments: '',
      expirationDate: '',
      language: '',
      reviewStatus: '',
      approvedBy: '',
      lastModified: '',
      fileFormat: '',
      fileSize: '',
      copyright: '',
    })
  }

  return (
    <div className="min-h-screen py-10 mb-20 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <Link href="/register/templates" className="inline-flex items-center text-indigo-600 hover:text-indigo-800 mb-8">
          <ArrowLeft className="h-5 w-5 mr-2" />
          Back to Templates
        </Link>
        <h1 className="text-3xl font-extrabold text-gray-900 mb-8">Document Registration</h1>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div className="bg-white shadow-md rounded-lg p-6">
            <h2 className="text-xl font-semibold mb-4">Register New Document</h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label htmlFor="title" className="block text-sm font-medium text-gray-700">Document Title</label>
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
                <label htmlFor="author" className="block text-sm font-medium text-gray-700">Author/Creator</label>
                <input
                  type="text"
                  id="author"
                  name="author"
                  value={formData.author}
                  onChange={handleChange}
                  required
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="date" className="block text-sm font-medium text-gray-700">Creation Date</label>
                <input
                  type="date"
                  id="date"
                  name="date"
                  value={formData.date}
                  onChange={handleChange}
                  required
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="documentType" className="block text-sm font-medium text-gray-700">Document Type</label>
                <input
                  type="text"
                  id="documentType"
                  name="documentType"
                  value={formData.documentType}
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
                <label htmlFor="version" className="block text-sm font-medium text-gray-700">Version</label>
                <input
                  type="text"
                  id="version"
                  name="version"
                  value={formData.version}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="department" className="block text-sm font-medium text-gray-700">Department</label>
                <input
                  type="text"
                  id="department"
                  name="department"
                  value={formData.department}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="accessLevel" className="block text-sm font-medium text-gray-700">Access Level</label>
                <select
                  id="accessLevel"
                  name="accessLevel"
                  value={formData.accessLevel}
                  onChange={handleChange}
                  required
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                >
                  <option value="">Select Access Level</option>
                  <option value="Public">Public</option>
                  <option value="Internal">Internal</option>
                  <option value="Confidential">Confidential</option>
                  <option value="Restricted">Restricted</option>
                </select>
              </div>
              <div>
                <label htmlFor="fileUrl" className="block text-sm font-medium text-gray-700">File URL</label>
                <input
                  type="url"
                  id="fileUrl"
                  name="fileUrl"
                  value={formData.fileUrl}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="tags" className="block text-sm font-medium text-gray-700">Tags</label>
                <input
                  type="text"
                  id="tags"
                  name="tags"
                  value={formData.tags}
                  onChange={handleChange}
                  placeholder="Comma-separated tags"
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="relatedDocuments" className="block text-sm font-medium text-gray-700">Related Documents</label>
                <input
                  type="text"
                  id="relatedDocuments"
                  name="relatedDocuments"
                  value={formData.relatedDocuments}
                  onChange={handleChange}
                  placeholder="Comma-separated document IDs"
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="expirationDate" className="block text-sm font-medium text-gray-700">Expiration Date</label>
                <input
                  type="date"
                  id="expirationDate"
                  name="expirationDate"
                  value={formData.expirationDate}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="language" className="block text-sm font-medium text-gray-700">Language</label>
                <input
                  type="text"
                  id="language"
                  name="language"
                  value={formData.language}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="reviewStatus" className="block text-sm font-medium text-gray-700">Review Status</label>
                <select
                  id="reviewStatus"
                  name="reviewStatus"
                  value={formData.reviewStatus}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                >
                  <option value="">Select Review Status</option>
                  <option value="Draft">Draft</option>
                  <option value="Under Review">Under Review</option>
                  <option value="Approved">Approved</option>
                  <option value="Rejected">Rejected</option>
                </select>
              </div>
              <div>
                <label htmlFor="approvedBy" className="block text-sm font-medium text-gray-700">Approved By</label>
                <input
                  type="text"
                  id="approvedBy"
                  name="approvedBy"
                  value={formData.approvedBy}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="lastModified" className="block text-sm font-medium text-gray-700">Last Modified</label>
                <input
                  type="date"
                  id="lastModified"
                  name="lastModified"
                  value={formData.lastModified}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="fileFormat" className="block text-sm font-medium text-gray-700">File Format</label>
                <input
                  type="text"
                  id="fileFormat"
                  name="fileFormat"
                  value={formData.fileFormat}
                  onChange={handleChange}
                  placeholder="e.g., PDF, DOCX, XLSX"
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="fileSize" className="block text-sm font-medium text-gray-700">File Size</label>
                <input
                  type="text"
                  id="fileSize"
                  name="fileSize"
                  value={formData.fileSize}
                  onChange={handleChange}
                  placeholder="e.g., 2.5 MB"
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
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
              <button
                type="submit"
                className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                Register Document
              </button>
            </form>
          </div>

          <div className="bg-white shadow-md rounded-lg p-6">
            <h2 className="text-xl font-semibold mb-10">Your Registered Documents</h2>
            <ul className="space-y-4">
              {mockData.map((item) => (
                <li key={item.id} className="border-b pb-4 last:border-b-0 last:pb-0">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center">
                      <FileText className="h-5 w-5 text-indigo-500 mr-2" />
                      <span className="font-medium">{item.title}</span>
                    </div>
                    <span className="text-sm text-gray-500">{item.type}</span>
                  </div>
                  <div className="mt-2 flex items-center text-sm text-gray-500">
                    <User className="h-4 w-4 mr-1" />
                    <span>{item.author}</span>
                    <Calendar className="h-4 w-4 ml-4 mr-1" />
                    <span>{item.date}</span>
                  </div>
                  <div className="mt-1 flex items-center text-sm text-gray-500">
                    <Lock className="h-4 w-4 mr-1" />
                    <span>{item.accessLevel}</span>
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