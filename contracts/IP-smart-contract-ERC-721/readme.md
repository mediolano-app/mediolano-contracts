![Mediolano.app](https://mediolano.app/wp-content/uploads/2024/09/mediolano-logo-dark-1.svg)

# Mediolano.app Cairo Contracts

Cairo smart contracts for Mediolano, a dapp designed to be the web3 intellectual property provider of the integrity web, built on Starknet.

<h4 align="center">
  <a href="https://ip.mediolano.app">Open Dapp</a> | 
  <a href="https://github.com/mediolano-app/mediolano-app">Dapp Repo</a> | 
  <a href="https://mediolano.app">Learn More</a>
</h4>

In today’s ever-evolving digital world, protecting and managing intellectual property (IP) has become a critical challenge. From journalists to art collectors, new technologies are making it safer and more efficient to tokenize IP, enabling licensing, trading, distributing royalties, and more.

Mediolano offers an innovative platform that empowers content creators, from authors to journalists and publishers, to participate in the global information marketplace. Our mission is to transform the industry by providing transparency, immutability, security, optimization, and a range of innovative features to build, manage, and monetize IP.

### Powered by Starknet

Mediolano leverages blockchain technology to create an immutable and transparent ledger for all your Intellectual Property. Each entry is securely encrypted, ensuring that your assets are protected.

> [!IMPORTANT]
> Mediolano dapp is in constant development and the current version runs on Starknet's Sepolia devnet. Use for testing purposes only. 

## Getting Started

Before you begin, ensure you have met the following requirements:

* Node.js (version 18 or later) and npm installed. Download them [here](https://nodejs.org/en/download/).
* Basic understanding of Starknet Foundry to deploy your own contract instance.

Requirements:

- Npm + Git
- ASDF + Scarb
- Starknet >= 2.2
- Starknet Foundry 
- macOS, Windows (including WSL), and Linux are supported.

Clone the repository to your local machine:

```bash
git clone https://github.com/mediolano-app/mediolano-contracts.git
```

### Starknet Foundry

This project includes a Starknet Foundry repository with smart contracts used in the frontend web app.

To deploy your own instance, use `sncast` to [declare](https://foundry-rs.github.io/starknet-foundry/starknet/declare.html) changes and/or [deploy](https://foundry-rs.github.io/starknet-foundry/starknet/deploy.html) an instance.
