'use client'

import { useState } from 'react'
import Link from 'next/link'
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { ArrowLeft } from 'lucide-react'

export default function CheckoutPage() {
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    address: '',
    city: '',
    country: '',
    zipCode: '',
  })

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target
    setFormData(prev => ({ ...prev, [name]: value }))
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    console.log('Order placed:', formData)
    // Here you would typically send the order to your backend
    alert('Order placed successfully!')
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <Link href="/cart" className="flex items-center text-sm font-medium text-muted-foreground hover:underline mb-6">
        <ArrowLeft className="mr-2 h-4 w-4" />
        Back to Cart
      </Link>
      
      <h1 className="text-4xl font-bold mb-8">Checkout</h1>
      
      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <Card>
          <CardHeader>
            <CardTitle>Shipping Information</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <Label htmlFor="name">Full Name</Label>
                <Input id="name" name="name" value={formData.name} onChange={handleChange} required />
              </div>
              <div>
                <Label htmlFor="email">Email</Label>
                <Input id="email" name="email" type="email" value={formData.email} onChange={handleChange} required />
              </div>
              <div>
                <Label htmlFor="address">Address</Label>
                <Input id="address" name="address" value={formData.address} onChange={handleChange} required />
              </div>
              <div>
                <Label htmlFor="city">City</Label>
                <Input id="city" name="city" value={formData.city} onChange={handleChange} required />
              </div>
              <div>
                <Label htmlFor="country">Country</Label>
                <Input id="country" name="country" value={formData.country} onChange={handleChange} required />
              </div>
              <div>
                <Label htmlFor="zipCode">Zip Code</Label>
                <Input id="zipCode" name="zipCode" value={formData.zipCode} onChange={handleChange} required />
              </div>
              <Button type="submit" className="w-full">Place Order</Button>
            </form>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader>
            <CardTitle>Order Summary</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span>Subtotal</span>
                <span>$100.00</span>
              </div>
              <div className="flex justify-between">
                <span>Shipping</span>
                <span>$10.00</span>
              </div>
              <div className="flex justify-between">
                <span>Taxes</span>
                <span>$5.00</span>
              </div>
              <div className="flex justify-between font-bold">
                <span>Total</span>
                <span>$115.00</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}