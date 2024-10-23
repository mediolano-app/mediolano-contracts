import Layout from '../components/layout'
import Link from 'next/link'
import { ArrowRight, Shield, Zap, DollarSign, Globe, Lock, Layers } from 'lucide-react'

const features = [
  {
    icon: Shield,
    title: 'Secure Protection',
    description: 'Blockchain technology ensures tamper-proof records of your intellectual property.'
  },
  {
    icon: Zap,
    title: 'Instant Verification',
    description: 'Quick and easy verification of IP ownership and licensing status.'
  },
  {
    icon: DollarSign,
    title: 'Monetization Opportunities',
    description: 'Access a global marketplace to license or sell your intellectual property.'
  },
  {
    icon: Globe,
    title: 'Global Accessibility',
    description: 'Manage and track your IP portfolio from anywhere in the world, 24/7.'
  },
  {
    icon: Lock,
    title: 'Smart Contracts',
    description: 'Automate licensing agreements and royalty payments with blockchain-based smart contracts.'
  },
  {
    icon: Layers,
    title: 'Comprehensive Management',
    description: 'All-in-one platform for registering, protecting, and monetizing your intellectual property.'
  }
]

export default function Home() {
  return (
    <Layout>
      <div className="text-center mb-16">
        <h1 className="text-4xl font-extrabold tracking-tight text-gray-900 sm:text-5xl md:text-6xl">
          <span className="block">Secure and Monetize</span>
          <span className="block text-primary">Your Intellectual Property</span>
        </h1>
        <p className="mt-3 max-w-md mx-auto text-base text-gray-500 sm:text-lg md:mt-5 md:text-xl md:max-w-3xl">
          Revolutionize the way you protect, manage, and monetize your ideas with our blockchain-powered IP registry.
        </p>
        <div className="mt-5 max-w-md mx-auto sm:flex sm:justify-center md:mt-8">
          <div className="rounded-md shadow">
            <Link href="/register" className="w-full flex items-center justify-center px-8 py-3 border border-transparent text-base font-medium rounded-md text-white bg-primary hover:bg-primary-dark md:py-4 md:text-lg md:px-10">
              Register IP
              <ArrowRight className="ml-2 -mr-1 w-5 h-5" />
            </Link>
          </div>
          <div className="mt-3 rounded-md shadow sm:mt-0 sm:ml-3">
            <Link href="/marketplace" className="w-full flex items-center justify-center px-8 py-3 border border-transparent text-base font-medium rounded-md text-primary bg-white hover:bg-gray-50 md:py-4 md:text-lg md:px-10">
              Explore Marketplace
            </Link>
          </div>
        </div>
      </div>

      <div className="bg-gradient-to-br from-primary/5 to-secondary/5 py-16 px-4 sm:px-6 lg:px-8 rounded-xl shadow-inner">
        <div className="max-w-7xl mx-auto">
          <h2 className="text-3xl font-extrabold text-gray-900 text-center mb-12">
            Revolutionize Your IP Management
          </h2>
          <div className="grid grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-3">
            {features.map((feature) => (
              <div key={feature.title} className="bg-white rounded-lg shadow-md p-6 transition-all duration-300 hover:shadow-lg hover:-translate-y-1">
                <div className="flex items-center justify-center w-12 h-12 bg-primary/10 text-primary rounded-full mb-4">
                  <feature.icon className="w-6 h-6" />
                </div>
                <h3 className="text-xl font-semibold text-gray-900 mb-2">{feature.title}</h3>
                <p className="text-gray-600">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="mt-16 bg-white rounded-xl shadow-md overflow-hidden lg:grid lg:grid-cols-2 lg:gap-4">
        <div className="pt-10 pb-12 px-6 sm:pt-16 sm:px-16 lg:py-16 lg:pr-0 xl:py-20 xl:px-20">
          <div className="lg:self-center">
            <h2 className="text-3xl font-extrabold text-gray-900 sm:text-4xl">
              <span className="block">Ready to secure your ideas?</span>
              <span className="block text-primary">Start using our platform today.</span>
            </h2>
            <p className="mt-4 text-lg leading-6 text-gray-500">
              Join thousands of innovators who are already protecting and monetizing their intellectual property with our cutting-edge blockchain technology.
            </p>
            <Link href="/register" className="mt-8 bg-primary border border-transparent rounded-md shadow px-5 py-3 inline-flex items-center text-base font-medium text-white hover:bg-primary-dark">
              Get started
              <ArrowRight className="ml-2 -mr-1 w-5 h-5" />
            </Link>
          </div>
        </div>
        <div className="relative -mt-6 aspect-w-5 aspect-h-3 md:aspect-w-2 md:aspect-h-1">
          <img
            className="transform translate-x-6 translate-y-6 rounded-md object-cover object-left-top sm:translate-x-16 lg:translate-y-20"
            src="/placeholder.svg?height=400&width=600"
            alt="App screenshot"
          />
        </div>
      </div>
    </Layout>
  )
}