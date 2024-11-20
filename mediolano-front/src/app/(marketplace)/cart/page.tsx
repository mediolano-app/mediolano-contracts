'use client'

import { useState } from 'react'
import Link from 'next/link'
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { ArrowLeft, Minus, Plus, Trash2 } from 'lucide-react'

const mockCartItems = [
  { id: 1, title: "Abstract Harmony", price: 0.5, currency: "ETH", quantity: 1, image: "/placeholder.svg?height=100&width=100" },
  { id: 2, title: "The Future of AI", price: 20, currency: "USD", quantity: 1, image: "/placeholder.svg?height=100&width=100" },
]

export default function CartPage() {
  const [cartItems, setCartItems] = useState(mockCartItems)

  const updateQuantity = (id: number, change: number) => {
    setCartItems(items =>
      items.map(item =>
        item.id === id ? { ...item, quantity: Math.max(0, item.quantity + change) } : item
      ).filter(item => item.quantity > 0)
    )
  }

  const total = cartItems.reduce((sum, item) => sum + item.price * item.quantity, 0)

  return (
    <div className="container mx-auto px-4 py-8">
      <Link href="/" className="flex items-center text-sm font-medium text-muted-foreground hover:underline mb-6">
        <ArrowLeft className="mr-2 h-4 w-4" />
        Continue Shopping
      </Link>
      
      <h1 className="text-4xl font-bold mb-8">Your Cart</h1>
      
      {cartItems.length === 0 ? (
        <p>Your cart is empty.</p>
      ) : (
        <>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Item</TableHead>
                <TableHead>Price</TableHead>
                <TableHead>Quantity</TableHead>
                <TableHead>Total</TableHead>
                <TableHead></TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {cartItems.map((item) => (
                <TableRow key={item.id}>
                  <TableCell>
                    <div className="flex items-center space-x-4">
                      <img src={item.image} alt={item.title} className="w-16 h-16 object-cover rounded" />
                      <span>{item.title}</span>
                    </div>
                  </TableCell>
                  <TableCell>{item.price} {item.currency}</TableCell>
                  <TableCell>
                    <div className="flex items-center space-x-2">
                      <Button size="sm" variant="outline" onClick={() => updateQuantity(item.id, -1)}><Minus className="h-4 w-4" /></Button>
                      <span>{item.quantity}</span>
                      <Button size="sm" variant="outline" onClick={() => updateQuantity(item.id, 1)}><Plus className="h-4 w-4" /></Button>
                    </div>
                  </TableCell>
                  <TableCell>{(item.price * item.quantity).toFixed(2)} {item.currency}</TableCell>
                  <TableCell>
                    <Button size="sm" variant="ghost" onClick={() => updateQuantity(item.id, -item.quantity)}><Trash2 className="h-4 w-4" /></Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
          
          <div className="mt-8 flex justify-between items-center">
            <div>
              <p className="text-2xl font-semibold">Total: {total.toFixed(2)} {cartItems[0].currency}</p>
              <p className="text-sm text-muted-foreground">Taxes and shipping calculated at checkout</p>
            </div>
            <Button size="lg" asChild>
              <Link href="/checkout">Proceed to Checkout</Link>
            </Button>
          </div>
        </>
      )}
    </div>
  )
}