
import { create } from "zustand";
import { ProviderInterface, AccountInterface, RpcProvider } from "starknet";
import { StarknetWindowObject } from "get-starknet";
import { GetRPCProviderWithEnv } from "@/utils/utils";

export interface WalletState {
    walletProvider: RpcProvider | undefined,
    publicProvider: RpcProvider,
    address: string,
    chainId: string,
    account: AccountInterface | undefined,
    isConnected: boolean,
    wallet: StarknetWindowObject | null,
}

export const useStoreWallet = create<WalletState>()((set) => ({
    walletProvider: undefined,
    publicProvider: new RpcProvider({ nodeUrl: GetRPCProviderWithEnv() }),
    address: "",
    chainId: "",
    account: undefined,
    isConnected: false,
    wallet: null,
}));
