"use client";
import { ReactNode } from "react";

import { sepolia } from "@starknet-react/chains";
import {
  StarknetConfig,
  argent,
  braavos,
  useInjectedConnectors,
  jsonRpcProvider,
  voyager,
  infuraProvider,
} from "@starknet-react/core";

export function Providers({ children }: { children: ReactNode }) {
  const apiKey = process.env.INFURA_API_KEY as string;
  const provider = infuraProvider({apiKey});
  const { connectors } = useInjectedConnectors({
    // Show these connectors if the user has no connector installed.
    recommended: [argent(), braavos()],
    // Hide recommended connectors if the user has any connector installed.
    includeRecommended: "onlyIfNoConnectors",
    // Randomize the order of the connectors.
    order: "random",
  });
  return (
    <StarknetConfig
      chains={[sepolia]}
      provider={ 
        provider
      }
      connectors={connectors}
      explorer={voyager}
    >
      {children}
    </StarknetConfig>
  );
}
