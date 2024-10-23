import { Shield, Clock, Globe, Zap, Lock, Coins } from 'lucide-react'

const features = [
  { icon: Shield, title: 'Enhanced Security', description: 'Immutable records ensure your IP is protected against tampering and fraud.' },
  { icon: Clock, title: 'Faster Processing', description: 'Smart contracts automate licensing and reduce processing times significantly.' },
  { icon: Globe, title: 'Global Accessibility', description: 'Access and manage your IP rights from anywhere in the world, 24/7.' },
  { icon: Zap, title: 'Instant Verification', description: 'Quickly verify the authenticity and ownership of intellectual property.' },
  { icon: Lock, title: 'Decentralized Storage', description: 'Your IP data is stored across a network of computers, eliminating single points of failure.' },
  { icon: Coins, title: 'Tokenization', description: 'Easily tokenize and trade fractional ownership of your intellectual property.' },
]

export default function BlockchainShowcase() {
  return (
    <div className="bg-gradient-to-br from-primary/5 to-secondary/5 py-16 px-4 sm:px-6 lg:px-8 rounded-xl shadow-inner">
      <div className="max-w-7xl mx-auto">
        <h2 className="text-3xl font-extrabold text-gray-900 text-center mb-12">Benefits of Blockchain for IP Registry</h2>
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