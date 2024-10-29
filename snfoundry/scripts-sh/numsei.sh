sncast --account ~/.starkli-wallets/deployer/account.json --keystore ~/.starkli-wallets/deployer/keystore.json  declare --contract-name YourCollectible --url https://starknet-sepolia.public.blastapi.io/rpc/v0_7 --fee-token eth

sncast account create --name deploy_dev --add-profile deploy_dev --url https://free-rpc.nethermind.io/sepolia-juno/
sncast account deploy --name deploy_dev --fee-token eth --url https://free-rpc.nethermind.io/sepolia-juno/
sncast --account deploy_dev declare --contract-name YourCollectible --url https://starknet-sepolia.public.blastapi.io/rpc/v0_7 --fee-token eth