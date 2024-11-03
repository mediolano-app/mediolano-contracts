# Mediolano.app

<h4 align="center">
  <a href="https://mediolano.app">Website</a> | 
  <a href="https://mediolano.app">Dapp (Soon)</a>
</h4>

In today’s ever-evolving digital world, protecting and managing intellectual property (IP) has become a critical challenge. From journalists to art collectors, new technologies are making it safer and more efficient to tokenize IP, enabling licensing, trading, distributing royalties, and more.

Mediolano offers an innovative platform that empowers content creators, from authors to journalists and publishers, to participate in the global information marketplace. Our mission is to transform the industry by providing transparency, immutability, security, optimization, and a range of innovative features to build, manage, and monetize IP.

### Powered by Starknet


## Prerequisites

Before you begin, ensure you have met the following requirements:

* Node.js (version 14 or later) and npm installed. Download them [here](https://nodejs.org/en/download/).
* Basic understanding of Starknet Foundry (if you want to deploy your own contract instance).
* Familiarity with TypeScript and React.

## Getting Started

### Starknet Foundry

This project includes a Starknet Foundry repository with a smart contract used in the frontend web app.

To deploy your own instance, use `sncast` to [declare](https://foundry-rs.github.io/starknet-foundry/starknet/declare.html) changes and/or [deploy](https://foundry-rs.github.io/starknet-foundry/starknet/deploy.html) an instance.

### NextJS App

The `web` directory contains a Next.js app based on the [starknet-react](https://github.com/apibara/starknet-react) template. Recent updates include:

To get started:

1. Navigate to the `web` directory
2. Copy `.env.template` to `.env.local` and fill in the required values
3. Install dependencies:
   ```bash
   npm install
   # or yarn, pnpm, bun
   ```
4. Run the development server:
   ```bash
   npm run dev
   # or yarn dev, pnpm dev, bun dev
   ```
5. Open http://localhost:3000 in your browser
