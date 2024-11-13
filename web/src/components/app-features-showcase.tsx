import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Shield, Zap, DollarSign, Users, Globe, Lock } from "lucide-react"

export function AppFeaturesShowcase() {
  const features = [
    {
      icon: <Shield className="w-10 h-10 " />,
      title: "Secure Blockchain Technology",
      description: "Protect your intellectual property with cutting-edge blockchain security."
    },
    {
      icon: <Zap className="w-10 h-10 " />,
      title: "Fast Transactions",
      description: "Experience lightning-fast IP transfers and licensing agreements."
    },
    {
      icon: <DollarSign className="w-10 h-10 " />,
      title: "Monetize Your IP",
      description: "Unlock the full potential of your intellectual property through various monetization options."
    },
    {
      icon: <Users className="w-10 h-10 " />,
      title: "Global Marketplace",
      description: "Connect with a worldwide network of IP buyers, sellers, and collaborators."
    },
    {
      icon: <Globe className="w-10 h-10 " />,
      title: "Cross-border Transactions",
      description: "Seamlessly conduct IP transactions across international borders."
    },
    {
      icon: <Lock className="w-10 h-10 " />,
      title: "Smart Contracts",
      description: "Automate and enforce IP agreements with blockchain-powered smart contracts."
    }
  ]

  return (
    <section className="py-10">
      <div className="container mx-auto">
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {features.map((feature, index) => (
            <Card key={index} className=" bg-base-100">
              <CardHeader>
                <CardTitle className="flex items-center">
                  {feature.icon}
                  <span className="ml-4">{feature.title}</span>
                </CardTitle>
              </CardHeader>
              <CardContent>
                <CardDescription>{feature.description}</CardDescription>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  )
}