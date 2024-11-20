import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Shield, Coins, List, Zap, Building, BarChart, Globe, Key, Lock, FileText, Briefcase, Layers, Cpu, PenTool, Rocket } from "lucide-react"

export default function BusinessPage() {
  return (
    <div className="flex flex-col min-h-screen">
      <main className="flex-1">
        <section className="w-full py-12 md:py-24 lg:py-32 xl:py-42">
          <div className="container px-4 md:px-6">
            <div className="flex flex-col items-center space-y-4 text-center">
              <div className="space-y-2">
                <h1 className="text-3xl font-bold tracking-tighter sm:text-4xl md:text-5xl lg:text-6xl/none">
                  Secure Your Intellectual Property with Blockchain
                </h1>
                <p className="mx-auto max-w-[700px] text-gray-500 md:text-xl dark:text-gray-400">
                  Register, license, monetize, and protect your intellectual property using cutting-edge blockchain technology.
                </p>
              </div>
              <div className="space-x-4">
                <Button size="lg">Get Started</Button>
                <Button size="lg" variant="outline">Learn More</Button>
              </div>
            </div>
          </div>
        </section>

        <section className="w-full py-12 md:py-24 lg:py-32">
          <div className="container px-4 md:px-6">
            <h2 className="text-3xl font-bold tracking-tighter sm:text-5xl text-center mb-12">Our Services</h2>
            <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              <Card>
                <CardHeader>
                  <Shield className="h-6 w-6 mb-2" />
                  <CardTitle>Register</CardTitle>
                  <CardDescription>Securely register your intellectual property on the blockchain.</CardDescription>
                </CardHeader>
                <CardContent>
                  <ul className="list-disc list-inside space-y-2 text-sm">
                    <li>Immutable proof of creation</li>
                    <li>Timestamped records</li>
                    <li>Global recognition</li>
                  </ul>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <Coins className="h-6 w-6 mb-2" />
                  <CardTitle>Monetize</CardTitle>
                  <CardDescription>Unlock new revenue streams from your intellectual assets.</CardDescription>
                </CardHeader>
                <CardContent>
                  <ul className="list-disc list-inside space-y-2 text-sm">
                    <li>Automated royalty payments</li>
                    <li>Fractional ownership</li>
                    <li>Secondary market support</li>
                  </ul>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <List className="h-6 w-6 mb-2" />
                  <CardTitle>Listing</CardTitle>
                  <CardDescription>List your IP assets on our decentralized marketplace.</CardDescription>
                </CardHeader>
                <CardContent>
                  <ul className="list-disc list-inside space-y-2 text-sm">
                    <li>Global visibility</li>
                    <li>Secure transactions</li>
                    <li>Transparent pricing</li>
                  </ul>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <Zap className="h-6 w-6 mb-2" />
                  <CardTitle>Licensing</CardTitle>
                  <CardDescription>Streamline licensing processes with smart contracts.</CardDescription>
                </CardHeader>
                <CardContent>
                  <ul className="list-disc list-inside space-y-2 text-sm">
                    <li>Automated compliance</li>
                    <li>Flexible terms</li>
                    <li>Real-time tracking</li>
                  </ul>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <BarChart className="h-6 w-6 mb-2" />
                  <CardTitle>Manage</CardTitle>
                  <CardDescription>Efficiently manage your IP portfolio on our platform.</CardDescription>
                </CardHeader>
                <CardContent>
                  <ul className="list-disc list-inside space-y-2 text-sm">
                    <li>Centralized dashboard</li>
                    <li>Analytics and reporting</li>
                    <li>Renewal reminders</li>
                  </ul>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <Lock className="h-6 w-6 mb-2" />
                  <CardTitle>Protect</CardTitle>
                  <CardDescription>Enhance protection of your intellectual property rights.</CardDescription>
                </CardHeader>
                <CardContent>
                  <ul className="list-disc list-inside space-y-2 text-sm">
                    <li>Blockchain verification</li>
                    <li>Infringement alerts</li>
                    <li>Dispute resolution support</li>
                  </ul>
                </CardContent>
              </Card>
            </div>
          </div>
        </section>

        <section className="w-full py-12 md:py-18 lg:py-26">
          <div className="container px-4 md:px-6">
            <h2 className="text-3xl font-bold tracking-tighter sm:text-5xl text-center mb-12">Custom Business Services</h2>
            <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
              <Card>
                <CardHeader>
                  <Building className="h-6 w-6 mb-2" />
                  <CardTitle>Asset Tokenization</CardTitle>
                  <CardDescription>Convert your intellectual property into tradable digital assets.</CardDescription>
                </CardHeader>
              </Card>
              <Card>
                <CardHeader>
                  <Coins className="h-6 w-6 mb-2" />
                  <CardTitle>IP Monetization Strategies</CardTitle>
                  <CardDescription>Develop custom strategies to maximize your IP's value.</CardDescription>
                </CardHeader>
              </Card>
              <Card>
                <CardHeader>
                  <Shield className="h-6 w-6 mb-2" />
                  <CardTitle>Blockchain Integration</CardTitle>
                  <CardDescription>Seamlessly integrate blockchain technology into your existing IP systems.</CardDescription>
                </CardHeader>
              </Card>
              <Card>
                <CardHeader>
                  <BarChart className="h-6 w-6 mb-2" />
                  <CardTitle>Analytics and Reporting</CardTitle>
                  <CardDescription>Gain insights into your IP portfolio's performance and market trends.</CardDescription>
                </CardHeader>
              </Card>
              <Card>
                <CardHeader>
                  <Globe className="h-6 w-6 mb-2" />
                  <CardTitle>Global IP Strategy</CardTitle>
                  <CardDescription>Develop and implement international IP protection and monetization strategies.</CardDescription>
                </CardHeader>
              </Card>
              <Card>
                <CardHeader>
                  <Key className="h-6 w-6 mb-2" />
                  <CardTitle>Smart Contract Development</CardTitle>
                  <CardDescription>Create custom smart contracts for complex IP agreements and licensing terms.</CardDescription>
                </CardHeader>
              </Card>
              <Card>
                <CardHeader>
                  <FileText className="h-6 w-6 mb-2" />
                  <CardTitle>IP Audits and Valuation</CardTitle>
                  <CardDescription>Comprehensive analysis and valuation of your intellectual property assets.</CardDescription>
                </CardHeader>
              </Card>
              <Card>
                <CardHeader>
                  <Briefcase className="h-6 w-6 mb-2" />
                  <CardTitle>IP Portfolio Optimization</CardTitle>
                  <CardDescription>Streamline and optimize your IP portfolio for maximum efficiency and value.</CardDescription>
                </CardHeader>
              </Card>
              <Card>
                <CardHeader>
                  <Layers className="h-6 w-6 mb-2" />
                  <CardTitle>Blockchain-based IP Exchange</CardTitle>
                  <CardDescription>Facilitate secure and transparent IP transactions on our decentralized exchange.</CardDescription>
                </CardHeader>
              </Card>
            </div>
          </div>
        </section>

        <section className="w-full py-12 md:py-18 lg:py-26">
          <div className="container px-4 md:px-6">
            <h2 className="text-3xl font-bold tracking-tighter sm:text-5xl text-center mb-12">Enterprise Solutions</h2>
            <p className="text-xl text-center mb-8 text-gray-600 dark:text-gray-300">
              Tailored for businesses managing large-scale intellectual property portfolios
            </p>
            <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
              <Card>
                <CardHeader>
                  <Cpu className="h-6 w-6 mb-2" />
                  <CardTitle>Bulk Registration</CardTitle>
                  <CardDescription>Efficiently register and protect large volumes of intellectual property assets.</CardDescription>
                </CardHeader>
                <CardContent>
                  <Badge className="mb-2">High Volume</Badge>
                  <ul className="list-disc list-inside space-y-2 text-sm">
                    <li>Automated batch processing</li>
                    <li>Customizable metadata</li>
                    <li>Scalable blockchain solutions</li>
                  </ul>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <Shield className="h-6 w-6 mb-2" />
                  <CardTitle>Enterprise IP Protection</CardTitle>
                  <CardDescription>Comprehensive protection strategies for large IP portfolios.</CardDescription>
                </CardHeader>
                <CardContent>
                  <Badge className="mb-2">Advanced Security</Badge>
                  <ul className="list-disc list-inside space-y-2 text-sm">
                    <li>Multi-layered security protocols</li>
                    <li>Real-time monitoring and alerts</li>
                    <li>Automated infringement detection</li>
                  </ul>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <Zap className="h-6 w-6 mb-2" />
                  <CardTitle>Mass Licensing Management</CardTitle>
                  <CardDescription>Streamline licensing for extensive IP catalogs.</CardDescription>
                </CardHeader>
                <CardContent>
                  <Badge className="mb-2">Efficiency</Badge>
                  <ul className="list-disc list-inside space-y-2 text-sm">
                    <li>Bulk license generation</li>
                    <li>Automated royalty calculations</li>
                    <li>Customizable licensing templates</li>
                  </ul>
                </CardContent>
              </Card>
            </div>
          </div>
        </section>

        <section className="w-full py-12 md:py-18 lg:py-26">
          <div className="container px-4 md:px-6">
            <h2 className="text-3xl font-bold tracking-tighter sm:text-5xl text-center mb-12">Digital Asset Management</h2>
            <p className="text-xl text-center mb-8 text-gray-600 dark:text-gray-300">
              Create, launch, and manage digital assets, including NFTs
            </p>
            <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
              <Card>
                <CardHeader>
                  <PenTool className="h-6 w-6 mb-2" />
                  <CardTitle>NFT Creation</CardTitle>
                  <CardDescription>Transform your IP into unique, verifiable digital assets.</CardDescription>
                </CardHeader>
                <CardContent>
                  <Badge className="mb-2">Creative</Badge>
                  <ul className="list-disc list-inside space-y-2 text-sm">
                    <li>Custom smart contract development</li>
                    <li>Metadata optimization</li>
                    <li>Multi-chain support</li>
                  </ul>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <Rocket className="h-6 w-6 mb-2" />
                  <CardTitle>NFT Launch Campaigns</CardTitle>
                  <CardDescription>Strategize and execute successful NFT launches.</CardDescription>
                </CardHeader>
                <CardContent>
                  <Badge className="mb-2">Marketing</Badge>
                  <ul className="list-disc list-inside space-y-2 text-sm">
                    <li>Community building</li>
                    <li>Whitelist management</li>
                    <li>Cross-platform promotion</li>
                  </ul>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <BarChart className="h-6 w-6 mb-2" />
                  <CardTitle>Digital Asset Analytics</CardTitle>
                  <CardDescription>Track and analyze the performance of your digital assets.</CardDescription>
                </CardHeader>
                <CardContent>
                  <Badge className="mb-2">Insights</Badge>
                  <ul className="list-disc list-inside space-y-2 text-sm">
                    <li>Real-time market data</li>
                    <li>Ownership and transfer tracking</li>
                    <li>Customizable performance metrics</li>
                  </ul>
                </CardContent>
              </Card>
            </div>
          </div>
        </section>

        <section className="w-full py-12 md:py-24 lg:py-32">
          <div className="container px-4 md:px-6">
            <div className="flex flex-col items-center space-y-4 text-center">
              <div className="space-y-2">
                <h2 className="text-3xl font-bold tracking-tighter sm:text-5xl">Ready to Secure Your Intellectual Property?</h2>
                <p className="mx-auto max-w-[700px] text-gray-500 md:text-xl dark:text-gray-400">
                  Join the future of IP management and protection. Get started with our blockchain-powered solutions today.
                </p>
              </div>
              <div className="space-x-4">
                <Button size="lg">Contact Sales</Button>
                <Button size="lg" variant="outline">Book a Demo</Button>
              </div>
            </div>
          </div>
        </section>
      </main>
    </div>
  )
}