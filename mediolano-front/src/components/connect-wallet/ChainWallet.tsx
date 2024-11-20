"use client";

import { useStoreWallet } from "./walletContext";;
import { GetFriendlyChainName } from '@/utils/utils';
import { useEffect } from "react";

export default function ChainWallet() {

    const accountAddress = useStoreWallet((state) => state.address);
    const chainId = useStoreWallet(state => state.chainId);
    const publicProvider = useStoreWallet(state => state.publicProvider);

    return (
        <>
            {
                <>
                    <div>
                        <p>{GetFriendlyChainName(chainId)}</p>
                    </div>
                </>

            }
        </>

    )
}