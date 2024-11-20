'use client'

import * as React from 'react'
import { Wallet } from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

export function WalletConnect() {
  const [isWalletConnected, setIsWalletConnected] = React.useState(false)

  const handleWalletConnect = () => {
    setIsWalletConnected(true)
  }

  const handleWalletDisconnect = () => {
    setIsWalletConnected(false)
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" size="sm" className="hidden sm:flex">
          <Wallet className="mr-2 h-4 w-4" />
          {isWalletConnected ? 'Connected' : 'Connect Wallet'}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {isWalletConnected ? (
          <DropdownMenuItem onClick={handleWalletDisconnect}>
            Disconnect
          </DropdownMenuItem>
        ) : (
          <>
            <DropdownMenuItem onClick={handleWalletConnect}>
              MetaMask
            </DropdownMenuItem>
            <DropdownMenuItem onClick={handleWalletConnect}>
              WalletConnect
            </DropdownMenuItem>
            <DropdownMenuItem onClick={handleWalletConnect}>
              Coinbase Wallet
            </DropdownMenuItem>
          </>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}