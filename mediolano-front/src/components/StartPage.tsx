import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ArrowRight, BookOpen, Download, HeartHandshake, List, MessageSquare, ShieldCheck } from 'lucide-react';
import Link from "next/link";

export default function StartPage() {
  
    return (
        <>

<section className="w-full py-12 md:py-24 lg:py-32 xl:py-42">
          <div className="container px-4 md:px-6">
            <div className="flex flex-col items-center space-y-4 text-center">
              <div className="space-y-2">
                <h1 className="text-3xl tracking-tighter sm:text-4xl md:text-5xl lg:text-6xl/none">
                Your gateway to own intellectual properties
                </h1>
                <h3 className="text-2xl font-bold tracking-tighter sm:text-2xl md:text-3xl lg:text-4xl/none pb-10">
                Powered by Starknet 
                </h3>
                <p className="mx-auto max-w-[700px]">
                  Register, license, and market your ntellectual property with ease. Secure your ideas and innovations today.
                </p>
              </div>
              <div className="space-x-4">
                <Button >
                  <Link href="/register">Get Started</Link>
                </Button>
                <Button variant="outline" >
                  <Link href="/portfolio">Open Portfolio</Link>
                </Button>
              </div>
            </div>
          </div>
        </section>
        
        
        <section className="w-full py-12 md:py-24 lg:py-32">
          <div className="container px-4 md:px-6">
            <h2 className="text-3xl font-bold tracking-tighter sm:text-5xl text-center mb-12">Services</h2>
            <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
                <CardHeader>
                  <BookOpen className="h-6 w-6 mb-2" />
                  <CardTitle>Registration</CardTitle>
                </CardHeader>
                <CardContent>
                  <p>Register your intellectual property quickly and securely.</p>
                  <Button className="mt-4 rounded p-5" variant="outline" >
                    <Link href="/register">Register Now </Link>
                  </Button>
                </CardContent>
              </Card>
              <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
                <CardHeader>
                  <List className="h-6 w-6 mb-2" />
                  <CardTitle>Listing</CardTitle>
                </CardHeader>
                <CardContent>
                  <p>List your intellectual property for potential buyers or licensees.</p>
                  <Button className="mt-4 rounded p-5" variant="outline" >
                    <Link href="/listing">List Property </Link>
                  </Button>
                </CardContent>
              </Card>
              <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
                <CardHeader>
                  <HeartHandshake className="h-6 w-6 mb-2" />
                  <CardTitle>Licensing</CardTitle>
                </CardHeader>
                <CardContent>
                  <p>License your intellectual property to interested parties.</p>
                  <Button className="mt-4 rounded p-5" variant="outline" >
                    <Link href="/licensing">License Now </Link>
                  </Button>
                </CardContent>
              </Card>
              <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
                <CardHeader>
                  <HeartHandshake className="h-6 w-6 mb-2" />
                  <CardTitle>Monetize</CardTitle>
                </CardHeader>
                <CardContent>
                  <p>Sell, trade and other monetization options for your digital assets.</p>
                  <Button className="mt-4 rounded p-5" variant="outline" >
                    <Link href="/monetize">View</Link>
                  </Button>
                </CardContent>
              </Card>
              <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
                <CardHeader>
                  <Download className="h-6 w-6 mb-2" />
                  <CardTitle>Resources</CardTitle>
                </CardHeader>
                <CardContent>
                  <p>Access and download important documents and resources.</p>
                  <Button className="mt-4 rounded p-5" variant="outline" >
                    <Link href="https://docs.mediolano.app">Open</Link>
                  </Button>
                </CardContent>
              </Card>
              <Card className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
                <CardHeader>
                  <MessageSquare className="h-6 w-6 mb-2" />
                  <CardTitle>Learn More</CardTitle>
                </CardHeader>
                <CardContent>
                  <p>Intellectual property tokenization with blockchain technology.</p>
                  <Button className="mt-4 rounded p-5" variant="outline" >
                    <Link href="https://mediolano.app">Visit</Link>
                  </Button>
                </CardContent>
              </Card>
            </div>
          </div>
        </section>


        </>
          )
        }