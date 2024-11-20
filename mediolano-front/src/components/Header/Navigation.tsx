'use client'

import * as React from 'react'
import { useRouter } from 'next/navigation'
import { ChevronDown, Copyright, FileText, Banknote, BookOpen, Users, Phone, Grid2X2, List, GalleryVerticalEnd, ScrollText, ArrowLeftRight, BriefcaseBusiness, Globe, LayoutGrid } from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

const navigationItems = [
  {
    title: 'Register',
    items: [
      { title: 'Register', href: '/register', icon: Copyright },
      { title: 'Templates', href: '/register/templates', icon: FileText },
      { title: 'FAQ', href: '/faq', icon: BookOpen },
    ],
  },
  {
    title: 'Manage',
    items: [
      { title: 'Portfolio', href: '/portfolio', icon: GalleryVerticalEnd },
      { title: 'Licensing', href: '/licensing', icon: ScrollText },
      { title: 'Listing', href: '/listing', icon: Globe },
      { title: 'Transfers', href: '/transfers', icon: ArrowLeftRight },
    ],
  },
  {
    title: 'Monetize',
    items: [
      { title: 'Monetize', href: '/monetize', icon: Banknote },
      { title: 'Marketplace', href: '/marketplace', icon: LayoutGrid },
      { title: 'Sell', href: '/sell', icon: ArrowLeftRight },
      { title: 'Business', href: '/business', icon: BriefcaseBusiness },
    ],
  },
  
]

export function Navigation() {
  const router = useRouter()

  const handleNavigation = (href: string) => {
    router.push(href)
  }

  return (
    <nav className="hidden md:flex md:flex-1 md:items-center md:justify-center space-x-1">
      {navigationItems.map((item) => (
        <DropdownMenu key={item.title}>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" className="h-10">
              {item.title}
              <ChevronDown className="ml-1 h-4 w-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent>
            {item.items.map((subItem) => (
              <DropdownMenuItem key={subItem.href} onClick={() => handleNavigation(subItem.href)}>
                <subItem.icon className="mr-2 h-4 w-4" />
                {subItem.title}
              </DropdownMenuItem>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
      ))}
    </nav>
  )
}