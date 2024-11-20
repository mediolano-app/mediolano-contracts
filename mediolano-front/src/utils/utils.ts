import { constants as SNconstants } from "starknet";

export enum ChainName {
    MAINNET = "MAINNET",
    SEPOLIA = "SEPOLIA",
    LOCALHOST = "LOCALHOST"
}

/**
 * Get the expected chain id in function of the current environment
 * @returns The expected chain id in function of the current environment
 */
export const GetExpectedChainNameWithEnv = () => {
    if (process.env.NODE_ENV === "production") {
        return ChainName.SEPOLIA;
    } else {

        // TODO: Cannot interact with extension wallet on Devnet/localhost
        return ChainName.SEPOLIA;
        //return ChainName.LOCALHOST;
    }
};

/**
 * Get RPC Prvider in function of the current environment
 * @returns The RPC Provider in function of the current environment
 */
export const GetRPCProviderWithEnv = () => {
    if (process.env.NODE_ENV === "production") {
        return process.env.NEXT_PUBLIC_PROVIDER_SEPOLIA_RPC;
    } else {

        // TODO: Cannot interact with extension wallet on Devnet/localhost
        return process.env.NEXT_PUBLIC_PROVIDER_SEPOLIA_RPC;
        //return process.env.NEXT_PUBLIC_PROVIDER_LOCAL_RPC;
    }
};


/**
 * 
 * @param address 
 * @returns 
 */
export const ToShortAddress = (address: string) => {
    return address.substring(0, 5) + "..." + address.substring(address.length - 4);
};

/**
 * Get friendly enum to manage chain with all extension wallet
 * @param chainId chain ID from extension wallet (SN_SEPOLIA from ArgentX, "0x0x534e5f5345504f4c4941" from Braavos/Metamask)
 * @returns one simple enum
 */
export const GetFriendlyChainName = (chainId: string) => {

    if (chainId === SNconstants.NetworkName.SN_MAIN || chainId === SNconstants.StarknetChainId.SN_MAIN) {
        return ChainName.MAINNET;
    }
    else if (chainId === SNconstants.NetworkName.SN_SEPOLIA || chainId === SNconstants.StarknetChainId.SN_SEPOLIA) {
        return ChainName.SEPOLIA;
    }
    else {
        return "Unknown";
    }
};

export const GetChainIdFromName = (chainName: ChainName) => {

    if (chainName === ChainName.MAINNET) {
        return SNconstants.StarknetChainId.SN_MAIN;
    }
    else if (chainName === ChainName.SEPOLIA) {
        return SNconstants.StarknetChainId.SN_SEPOLIA;
    }
    else {
        return "Unknown";
    }
};