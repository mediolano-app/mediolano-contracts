import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
  } from '@/components/ui/dropdown-menu'

  import {
    cn
  } from "@/lib/utils"
  import {
    Button
  } from "@/components/ui/button"

  import Link from 'next/link';

import { ModeToggle } from '@/components/theme-switch';
import Image from "next/image";

import * as React from 'react'
import { useTheme } from 'next-themes'

  import { FC, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import dynamic from 'next/dynamic';
import { useAccount, useBalance, useBlockNumber, useContract, useReadContract, useSendTransaction, useTransactionReceipt } from '@starknet-react/core';
import { BlockNumber, Contract, RpcProvider } from "starknet";
import { mockedAbi } from "@/abis/mockedAbi";
import { type Abi } from "starknet";
import { formatAmount, shortenAddress } from '@/lib/utils';
  
import { Moon, Sun, Menu, X, User, ChevronDown, Wallet } from 'lucide-react'


export default function WalletDropdown() {

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

)
}