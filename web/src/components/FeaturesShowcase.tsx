import { Shield, Zap, DollarSign, Globe, Lock, Layers } from 'lucide-react'

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

export default function FeatureShowcase() {
  return (
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
  )
}