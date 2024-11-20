"use client";
import { InjectedConnector, useAccount, useConnect } from '@starknet-react/core'

export function ConnectWallet() {
  const { account } = useAccount();
  const { connect, connectors } = useConnect();

  const truncateAddr = (s:string) => {
    return s.substring(0,4) + '..' + s.substring(s.length-3,s.length)
  }

  if (account) {
    return <p>{truncateAddr(account.address)}</p>
  }

  return <div>
    <button
      className="ml-2 rounded-md w-32 px-2 py-1 bg-slate-700 text-white"
      onClick={() => connect({connector: connectors.at(0)})}>Connect</button>
  </div>
}