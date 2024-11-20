'use client'

import { useRouter } from 'next/navigation'
import { User, Copyright, Award, Settings, Briefcase, HelpCircle } from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

const userMenuItems = [
  { title: 'My Account', href: '/account', icon: User },
  { title: 'My IP\'s', href: '/portfolio', icon: Copyright },
  { title: 'Rewards', href: '/rewards', icon: Award },
  { title: 'Settings', href: '/settings', icon: Settings },
  { title: 'Support', href: '/support', icon: HelpCircle },
  { title: 'Business', href: '/business', icon: Briefcase },
]

export function AccountDropdown() {
  const router = useRouter()

  const handleNavigation = (href: string) => {
    router.push(href)
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon">
          <User className="h-5 w-5" />
          <span className="sr-only">User menu</span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-56">
        {userMenuItems.map((item) => (
          <DropdownMenuItem key={item.href} onClick={() => handleNavigation(item.href)}>
            <item.icon className="mr-2 h-4 w-4" />
            {item.title}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}