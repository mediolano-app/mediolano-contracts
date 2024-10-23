'use client';
import Link from 'next/link';
import { FC, useState } from 'react';
import { Menu, X } from 'lucide-react';

const navItems = [
  { href: '/start', label: 'Start' },
  { href: '/register', label: 'Register' },
  { href: '/license', label: 'License' },
  { href: '/listing', label: 'Listing' },
  { href: '/marketplace', label: 'Marketplace' },
  { href: '/monetize', label: 'Monetize' },
  { href: '/settings', label: 'Settings' },
  { href: '/support', label: 'Support' },
]

export default function Header() {
  const [isMenuOpen, setIsMenuOpen] = useState(false)

  return (
    <header className="shadow-md">
      <div className="container mx-auto px-4 py-4 flex justify-between items-center">
        <Link href="/" className="text-2xl font-bold text-primary">
          Mediolano
        </Link>
        <nav className="hidden md:block">
          <ul className="flex space-x-4">
            {navItems.map((item) => (
              <li key={item.href}>
                <Link href={item.href} className="text-primary hover:text-primary">
                  {item.label}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
        <button
          className="md:hidden"
          onClick={() => setIsMenuOpen(!isMenuOpen)}
        >
          {isMenuOpen ? <X size={24} /> : <Menu size={24} />}
        </button>
      </div>
      {isMenuOpen && (
        <nav className="md:hidden">
          <ul className="flex flex-col space-y-2 p-4">
            {navItems.map((item) => (
              <li key={item.href}>
                <Link
                  href={item.href}
                  className="block text-gray-700 hover:text-primary"
                  onClick={() => setIsMenuOpen(false)}
                >
                  {item.label}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
      )}

    

    </header>
  )
}