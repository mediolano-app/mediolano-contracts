import { useConnect, useDisconnect, useAccount } from '@starknet-react/core';
import { LogOut, LogOutIcon, LucideLogOut, Wallet } from 'lucide-react';

const WalletBar: React.FC = () => {
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  const { address } = useAccount();

  return (
    <div className="flex flex-col items-center space-y-4 bg-blue/15">
      {!address ? (
        <div className="flex flex-wrap justify-center gap-2">
          {connectors.map((connector) => (
            <button
              key={connector.id}
              onClick={() => connect({ connector })}
              className="rounded shadow text-sm py-2 px-4 hover:bg-blue/10"
            >
              Connect {/*connector.id*/}
            </button>
          ))}
        </div>
      ) : (
        <div className="flex flex-col items-center">
          <div className="text-sm px-4 rounded">
            
            <button
            onClick={() => disconnect()}
            className="py-2 px-2 flex items-center justify-center"
          >
            {address.slice(0, 6)}...{address.slice(-4)} &nbsp; <LucideLogOut className='h-4 w-4'/>
          </button>
          </div>
          
        </div>
      )}
    </div>
  );
};

export default WalletBar;
