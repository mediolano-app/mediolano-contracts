'use client'

import { useState } from 'react'
import { MessageSquare, Phone, Mail, FileText, HelpCircle, Info } from 'lucide-react'

const faqs = [
  {
    question: "How does blockchain technology protect my intellectual property?",
    answer: "Blockchain technology creates an immutable, time-stamped record of your intellectual property registration. This provides strong evidence of ownership and can be crucial in legal disputes or licensing negotiations."
  },
  {
    question: "What types of intellectual property can I register on this platform?",
    answer: "Our platform supports registration for various types of intellectual property, including patents, trademarks, copyrights, and trade secrets."
  },
  {
    question: "How do smart contracts work for licensing my IP?",
    answer: "Smart contracts automate the licensing process by encoding the terms of the agreement on the blockchain. This ensures automatic execution of payments and other conditions, reducing the need for intermediaries and increasing transparency."
  },
  {
    question: "Is my intellectual property information kept confidential?",
    answer: "Yes, we use advanced encryption techniques to ensure the confidentiality of your intellectual property information. Only authorized parties can access the full details of your IP."
  },
  {
    question: "How can I monetize my intellectual property through this platform?",
    answer: "Our platform offers various monetization options, including licensing, patent pooling, and direct sales. You can also list your IP on our marketplace to reach potential buyers or licensees."
  }
]

export default function Support() {
  const [activeTab, setActiveTab] = useState('faq')
  const [expandedFaq, setExpandedFaq] = useState<number | null>(null)

  const renderTabContent = () => {
    switch (activeTab) {
      case 'faq':
        return (
          <div className="space-y-4">
            {faqs.map((faq, index) => (
              <div key={index} className="border rounded-md overflow-hidden">
                <button
                  className="w-full text-left p-4 flex justify-between items-center focus:outline-none"
                  onClick={() => setExpandedFaq(expandedFaq === index ? null : index)}
                >
                  <span className="font-medium">{faq.question}</span>
                  <HelpCircle className={`w-5 h-5 transform transition-transform ${expandedFaq === index ? 'rotate-180' : ''}`} />
                </button>
                {expandedFaq === index && (
                  <div className="p-4">
                    <p>{faq.answer}</p>
                  </div>
                )}
              </div>
            ))}
          </div>
        )
      case 'contact':
        return (
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
              <label htmlFor="subject" className="block text-sm font-medium text-gray-700 mb-1">Subject</label>
              <input type="text" id="subject" name="subject" className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary" required />
            </div>
            <div>
              <label htmlFor="message" className="block text-sm font-medium text-gray-700 mb-1">Message</label>
              <textarea id="message" name="message" rows={4} className="w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-primary" required></textarea>
            </div>
            <button type="submit" className=" px-4 py-2 rounded-md hover:bg-primary-dark transition-colors duration-300">
              Send Message
            </button>
          </form>
        )
      case 'documentation':
        return (
          <div className="space-y-4">
            <div className=" p-4 rounded-md shadow">
              <h3 className=" mb-2 flex items-center">
                <FileText className="w-5 h-5 mr-2 " />
                User Guide
              </h3>
              <p className=" mb-2">Comprehensive guide on how to use our platform</p>
              <a href="#" className=" hover:underline">Download PDF</a>
            </div>
            <div className=" p-4 rounded-md shadow">
              <h3 className=" mb-2 flex items-center">
                <FileText className="w-5 h-5 mr-2 " />
                API Documentation
              </h3>
              <p className=" mb-2">Technical documentation for integrating with our API</p>
              <a href="#" className=" hover:underline">View Documentation</a>
            </div>
            <div className=" p-4 rounded-md shadow">
              <h3 className=" mb-2 flex items-center">
                <FileText className="w-5 h-5 mr-2 " />
                Legal Information
              </h3>
              <p className=" mb-2">Terms of service, privacy policy, and legal disclaimers</p>
              <a href="#" className=" hover:underline">Read More</a>
            </div>
          </div>
        )
      default:
        return null
    }
  }

  return (
      <div className="max-w-4xl mx-auto mt-10 mb-20">
        <h1 className="text-3xl font-bold mb-6">Support Center</h1>
        <div className="shadow-md rounded-lg overflow-hidden shadow-md hover:shadow-xl transition-shadow duration-300 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground p-6 mb-6">
          <div className="flex">
            <div className="flex-shrink-0">
              <Info className="h-5 w-5 text-blue-400" />
            </div>
            <div className="ml-3">
              <p className="text-sm text-blue-700">
                Our support team is well-versed in blockchain technology and intellectual property matters. We're here to help you navigate the complexities of IP management and blockchain integration.
              </p>
            </div>
          </div>
        </div>
        <div className="shadow-md rounded-lg overflow-hidden shadow-md hover:shadow-xl transition-shadow duration-300 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground p-6">
          <div className="flex border-b">
            <button
              className={`flex-1 py-4 px-6 text-center ${activeTab === 'faq' ? '' : 'hover:bg-blue'}`}
              onClick={() => setActiveTab('faq')}
            >
              <MessageSquare className="w-5 h-5 mx-auto mb-1" />
              FAQ
            </button>
            <button
              className={`flex-1 py-4 px-6 text-center ${activeTab === 'contact' ? '' : 'hover:bg-blue'}`}
              onClick={() => setActiveTab('contact')}
            >
              <Mail className="w-5 h-5 mx-auto mb-1" />
              Contact Us
            </button>
            <button
              className={`flex-1 py-4 px-6 text-center ${activeTab === 'documentation' ? '' : 'hover:bg-blue'}`}
              onClick={() => setActiveTab('documentation')}
            >
              <FileText className="w-5 h-5 mx-auto mb-1" />
              Documentation
            </button>
          </div>
          <div className="p-6">
            {renderTabContent()}
          </div>
        </div>
        <div className="mt-8  p-6 shadow-md rounded-lg overflow-hidden shadow-md hover:shadow-xl transition-shadow duration-300 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
          <h2 className="text-xl  mb-4">Need Immediate Assistance?</h2>
          <div className="flex flex-col md:flex-row md:space-x-4">
            <div className="flex items-center mb-4 md:mb-0">
              <Phone className="w-5 h-5 mr-2 " />
              <span>Call us: +55 (21) 982851482</span>
            </div>
            <div className="flex items-center">
              <Mail className="w-5 h-5 mr-2 " />
              <span>Email: support@mediolano.app</span>
            </div>
          </div>
        </div>
      </div>
  )
}