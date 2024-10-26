'use client';

import Link from 'next/link';
import { FC, useState } from 'react';
import { ModeToggle } from '@/components/theme-switch';
import Image from "next/image";

import * as React from 'react'
import { useTheme } from 'next-themes'
import { Moon, Sun, Menu, X, User, ChevronDown, Wallet } from 'lucide-react'

import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import {
  NavigationMenu,
  NavigationMenuContent,
  NavigationMenuItem,
  NavigationMenuLink,
  NavigationMenuList,
  NavigationMenuTrigger,
} from '@/components/ui/navigation-menu'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from '@/components/ui/sheet'

const navItems = [
  { href: '/start', label: 'Start' },
  { href: '/registerIP', label: 'Register' },
  { href: '/license', label: 'License' },
  { href: '/listing', label: 'Listing' },
  { href: '/marketplace', label: 'Marketplace' },
  { href: '/monetize', label: 'Monetize' },
  { href: '/settings', label: 'Settings' },
  { href: '/support', label: 'Support' },
]

const ListItem = React.forwardRef<
  React.ElementRef<'a'>,
  React.ComponentPropsWithoutRef<'a'>
>(({ className, title, children, ...props }, ref) => {
  return (
    <li>
      <NavigationMenuLink asChild>
        <a
          ref={ref}
          className={`block select-none space-y-1 rounded-md p-3 leading-none no-underline outline-none transition-colors hover:bg-accent hover:text-accent-foreground focus:bg-accent focus:text-accent-foreground ${className}`}
          {...props}
        >
          <div className="text-sm font-medium leading-none">{title}</div>
          <p className="line-clamp-2 text-sm leading-snug text-muted-foreground">
            {children}
          </p>
        </a>
      </NavigationMenuLink>
    </li>
  )
})
ListItem.displayName = 'ListItem'

export default function Header() {
  const { theme, setTheme } = useTheme()
  const [isMenuOpen, setIsMenuOpen] = useState(false)

  const [isWalletConnected, setIsWalletConnected] = React.useState(false)

  const handleWalletConnect = () => {
    // Implement wallet connection logic here
    setIsWalletConnected(true)
  }

  const handleWalletDisconnect = () => {
    // Implement wallet disconnection logic here
    setIsWalletConnected(false)
  }

  return (
     <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="container flex h-14 items-center ml-4">
        <Link href="/" className="mr-6 flex items-center space-x-2">
        <svg width="30" height="30" viewBox="0 0 36 36" xmlns="http://www.w3.org/2000/svg" aria-hidden="true" className="iconify iconify--twemoji"><path fill="#3B88C3" d="M36 32a4 4 0 0 1-4 4H4a4 4 0 0 1-4-4V4a4 4 0 0 1 4-4h28a4 4 0 0 1 4 4z"/><path fill="#FFF" d="M8.174 9.125c.186-1.116 1.395-2.387 3.039-2.387 1.55 0 2.76 1.116 3.101 2.232l3.659 12.278h.062L21.692 8.97c.341-1.116 1.55-2.232 3.101-2.232 1.642 0 2.852 1.271 3.039 2.387l2.883 17.302c.031.186.031.372.031.526 0 1.365-.992 2.232-2.232 2.232-1.582 0-2.201-.713-2.418-2.17l-1.83-12.619h-.062l-3.721 12.991c-.217.744-.805 1.798-2.48 1.798s-2.263-1.054-2.48-1.798l-3.721-12.991h-.062l-1.83 12.62c-.217 1.457-.837 2.17-2.418 2.17-1.24 0-2.232-.867-2.232-2.232 0-.154 0-.341.031-.526z"/></svg>
          <span className="hidden font-bold sm:inline-block">
            Mediolano
          </span>
        </Link>

        <NavigationMenu className="hidden md:flex">
          <NavigationMenuList>
            <NavigationMenuItem>
              <NavigationMenuTrigger>Services</NavigationMenuTrigger>
              <NavigationMenuContent>
                <ul className="grid gap-3 p-6 md:w-[400px] lg:w-[500px] lg:grid-cols-[.75fr_1fr]">
                  <li className="row-span-3">
                    <NavigationMenuLink asChild>
                      <a
                        className="flex h-full w-full select-none flex-col justify-end rounded-md bg-gradient-to-b from-muted/50 to-muted p-6 no-underline outline-none focus:shadow-md"
                        href="/"
                      >
                        <div className="mb-2 mt-4 text-lg font-medium">
                          Intellectual Property
                        </div>
                        <p className="text-sm leading-tight text-muted-foreground">
                          On Chain Services
                        </p>
                      </a>
                    </NavigationMenuLink>
                  </li>
                  <ListItem href="/registerIP" title="Register">
                    Register and protect your IP
                  </ListItem>
                  <ListItem href="/license" title="Licensing">
                    License with Smart Contracts
                  </ListItem>
                  <ListItem href="/listing" title="Listing">
                    List IP on NFT Marketplaces
                  </ListItem>
                </ul>
              </NavigationMenuContent>
            </NavigationMenuItem>
            <NavigationMenuItem>
              <NavigationMenuTrigger>Monetize</NavigationMenuTrigger>
              <NavigationMenuContent>
                <ul className="grid w-[400px] gap-3 p-4 md:w-[500px] md:grid-cols-2 lg:w-[600px]">
                  <ListItem href="/listing" title="Listing">
                    List IP on NFT Marketplaces
                  </ListItem>
                  <ListItem href="/" title="Marketplace">
                    IP Marketplace @ Starknet
                  </ListItem>
                  <ListItem href="/" title="Opportunities">
                    Commission offers, royalties opportunities...
                  </ListItem>
                  <ListItem href="/" title="Sell">
                    Trade your IP
                  </ListItem>
                </ul>
              </NavigationMenuContent>
            </NavigationMenuItem>
            <NavigationMenuItem>
              <Link href="/" legacyBehavior passHref>
                <NavigationMenuLink className="font-medium">
                  Support
                </NavigationMenuLink>
              </Link>
            </NavigationMenuItem>
          </NavigationMenuList>
        </NavigationMenu>

        <div className="flex flex-1 items-center justify-end space-x-4">


        <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" size="sm">
                <Wallet className="mr-2 h-4 w-4" />
                {isWalletConnected ? 'Connected' : 'Connect Wallet'}
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              {isWalletConnected ? (
                <>
                  <DropdownMenuLabel>Wallet Connected</DropdownMenuLabel>
                  <DropdownMenuItem onClick={handleWalletDisconnect}>
                    Disconnect
                  </DropdownMenuItem>
                </>
              ) : (
                <>
                  <DropdownMenuLabel>Select your chain</DropdownMenuLabel>
                  <DropdownMenuItem onClick={handleWalletConnect}>
                    Starknet
                  </DropdownMenuItem>
                  <DropdownMenuItem onClick={handleWalletConnect}>
                    Ethereum
                  </DropdownMenuItem>
                  <DropdownMenuItem onClick={handleWalletConnect}>
                    Solana
                  </DropdownMenuItem>
                </>
              )}
            </DropdownMenuContent>
          </DropdownMenu>



          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon">
                <User className="h-5 w-5" />
                <span className="sr-only">User menu</span>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuLabel>My Account</DropdownMenuLabel>
              <DropdownMenuItem>Profile</DropdownMenuItem>
              <DropdownMenuItem>Settings</DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem>Log out</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon">
                <Sun className="h-5 w-5 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
                <Moon className="absolute h-5 w-5 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
                <span className="sr-only">Toggle theme</span>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onClick={() => setTheme("light")}>
                Light
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => setTheme("dark")}>
                Dark
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => setTheme("system")}>
                System
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>

          <Sheet>
            <SheetTrigger asChild>
              <Button variant="ghost" size="icon" className="md:hidden">
                <Menu className="h-5 w-5" />
                <span className="sr-only">Toggle menu</span>
              </Button>
            </SheetTrigger>
            <SheetContent side="right">
              <SheetHeader>
                <SheetTitle>Mediolano</SheetTitle>
                <SheetDescription>
                  @ Starknet
                </SheetDescription>
              </SheetHeader>
              <nav className="flex flex-col space-y-4 mt-4">
                <Link href="/registerIP" className="text-sm font-medium">
                  Register IP
                </Link>
                <Link href="/" className="text-sm font-medium">
                  Licensing
                </Link>
                <Link href="/" className="text-sm font-medium">
                  Monetize
                </Link>
                <Button
                  variant="outline"
                  size="sm"
                  className="justify-start"
                  onClick={isWalletConnected ? handleWalletDisconnect : handleWalletConnect}
                >
                  <Wallet className="mr-2 h-4 w-4" />
                  {isWalletConnected ? 'Disconnect Wallet' : 'Connect Wallet'}
                </Button>
              </nav>
            </SheetContent>
          </Sheet>
        </div>
      </div>
    </header>
  )
}