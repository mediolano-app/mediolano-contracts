'use client'

import * as React from 'react'
import dynamic from 'next/dynamic';
import { useTheme } from 'next-themes'
import { Moon, Sun } from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Logo } from '@/components/Header/Logo'
import { Navigation } from '@/components/Header/Navigation'
import { AccountDropdown } from '@/components/Header/AccountDropdown'
import { MobileSidebar } from '@/components/Header/MobileSidebar'
import { ModeToggle } from '@/components/Header/ThemeSwitch'

const WalletBar = dynamic(() => import('@/components/Header/WalletBar'), { ssr: false })

export function Header() {
  const { theme, setTheme } = useTheme()

  return (
    <header className="sticky top-0 z-50 w-full shadow bg-background/55 backdrop-blur supports-[backdrop-filter]:bg-background/30">
      <div className="container flex h-16 items-center pl-5">
        <Logo />
        <Navigation />
        <div className="flex items-center space-x-2 ml-auto">
          <WalletBar />
          <AccountDropdown />
          <ModeToggle />
          <MobileSidebar />
        </div>
      </div>
    </header>
  )
}