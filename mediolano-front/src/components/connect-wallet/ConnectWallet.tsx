"use client";

import { useEffect, useState } from 'react';
import { useStoreWallet } from './walletContext';

import { Button } from '../ui/button';
import { StarknetWindowObject, connect } from "get-starknet";
import { Account, encode, Provider, RpcProvider, constants as SNconstants } from "starknet";
import { ToShortAddress } from '@/utils/utils';
import BalanceWallet from './BalanceWallet';
import ChainWallet from './ChainWallet';

export default function ConnectWallet() {
    const addressAccount = useStoreWallet(state => state.address);
    const wallet = useStoreWallet(state => state.wallet);
    const isConnected = useStoreWallet(state => state.isConnected);
    const accountW = useStoreWallet(state => state.account);
    const [displayedAccountAddr, setdisplayedAccountAddr] = useState<string>("");
    const addrETH = "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7";
    const addrSTRK = "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d";

    let getWallet: StarknetWindowObject | null = null;

    useEffect(() => {
        setdisplayedAccountAddr(addressAccount);
    }, [displayedAccountAddr]);

    const handleAccountChanged = async (accounts: string[]) => {
        if (accounts[0]) {
            console.log(`Account changed to ${accounts[0]}`);
            setUseStoredWallet();
        }
    };

    const handleNetworkChanged = (network: string | undefined) => {
        if (network) {
            console.log(`Network changed to ${network}`);
            setUseStoredWallet();
        }
    }

    const setUseStoredWallet = () => {

        useStoreWallet.setState({ wallet: getWallet });
        useStoreWallet.setState({ walletProvider: getWallet?.provider });
        const addr = encode.addHexPrefix(encode.removeHexPrefix(getWallet?.selectedAddress ?? "0x").padStart(64, "0"));
        useStoreWallet.setState({ address: addr });
        setdisplayedAccountAddr(addr);
        useStoreWallet.setState({ isConnected: getWallet?.isConnected });
        if (getWallet?.account) {
            useStoreWallet.setState({ account: getWallet.account });
            !!(getWallet.chainId) ?
                useStoreWallet.setState({ chainId: getWallet.chainId }) :
                useStoreWallet.setState({ chainId: SNconstants.StarknetChainId.SN_SEPOLIA });
        }
        console.log("Stored Wallet:");
        console.log(useStoreWallet.getState());
    }
    const handleConnectClick = async () => {
        getWallet = await connect({ modalMode: "alwaysAsk", modalTheme: "dark" });
        await getWallet?.enable({ starknetVersion: "v5" } as any);
        setUseStoredWallet();
        getWallet?.off("accountsChanged", handleAccountChanged);
        getWallet?.off('networkChanged', handleAccountChanged);
        getWallet?.on("accountsChanged", handleAccountChanged);
        getWallet?.on("networkChanged", handleNetworkChanged);
    }
    return (

        <>
            {!isConnected ? (
                <>
                    <Button
                        
                        onClick={() => {
                            handleConnectClick();
                        }}
                    >
                        Connect Wallet
                    </Button>
                </>
            ) : (
                <div>

                    <ChainWallet></ChainWallet>

                    <BalanceWallet tokenAddress={addrETH} ></BalanceWallet>

                    <Button
                        onClick={() => {
                            useStoreWallet.setState({ isConnected: false });
                        }}
                    >
                        {displayedAccountAddr
                            ? `${ToShortAddress(displayedAccountAddr)}`
                            : "No Account"}
                    </Button>

                </div>
            )
            }
        </>

    )
}
