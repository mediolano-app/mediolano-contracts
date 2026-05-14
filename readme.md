# Programmable IP for the Integrity Web

Cairo smart contracts for Mediolano, the intellectual property provider of the integrity web, powered on Starknet.


Quick links:
<br>
<a href="https://ip.mediolano.app">Mediolano IP Creator</a>
<br>
<a href="https://t.me/integrityweb">Telegram</a> | <a href="https://x.com/mediolanoapp">X / Twitter</a>
<br>



## Mediolano

Mediolano empowers creators, artists and organizations to make money from their content, without requiring them to know anything about crypto.

With permissionless services for Programmable Intellectual Property (IP), leveraging Starknet’s high-speed, low-cost transactions and zero-knowledge proofs, Mediolano provides a comprehensive suite of solutions to tokenize and monetize assets efficiently, transparently and with sovereignty.

With zero fees, Mediolano’s open-source protocol and dapp ensures immediate tokenization and protection under the Berne Convention for the Protection of Literary and Artistic Works (1886), covering 181 countries. This framework guarantees global recognition of authorship, providing verifiable proof of ownership for 50 to 70 years, depending on jurisdiction.

The platform also introduces advanced monetization, enabling diverse approaches to licensing, royalties, and financing creators economies. These tools are designed to offer integrations with various ecosystems, including communities, games, and AI agents, unlocking the true power of Programmable IP for the Integrity Web.



## Roadmap

- [x] Starknet Ignition **24.9**

- [x] MIP Protocol @ Starknet Sepolia **24.11**

- [x] Mediolano Dapp @ Starknet Sepolia **24.11**

- [x] Programmable IP Contracts **25.02**

- [x] MIP Dapp @ Starknet Sepolia **25.06**

- [X] MIP Protocol @ Starknet Mainnet **25.07**

- [X] MIP Collections Protocol @ Starknet Sepolia **25.07**

- [X] MIP Dapp @ Starknet Mainnet **25.08**

- [X] MIP Collections Protocol @ Starknet Mainnet **25.08**

- [X] MIP Mobile @ Android Google Play **25.09**

- [X] MIP Mobile @ iPhone iOS App Store **25.12**

- [X] Mediolano IP Creator Dapp @ Starknet Mainnet **26.01**

- [X] Security Audit and Review: IP Collections erc-721 Protocol +  IP Collections erc-1155 Protocol **26.04**

- [X] Immutable Architecture Refactor: MIP Collections ERC-721 Protocol **26.05**


## MIP Collections ERC-721

`contracts/MIP-Collections-ERC721` contains the immutable ERC-721 collection registry for Mediolano IP. The design separates permanent provenance from operational stewardship:

- `IPCollection` is an immutable registry and factory.
- Each collection deploys its own immutable `IPNft` ERC-721 contract.
- There is no global admin owner, upgrade function, mutable NFT class hash, or collection pause switch.
- Collection ownership can be transferred atomically by the current collection owner.
- Ownership transfer only changes future mint authority; already minted token records remain unchanged.
- Token legal records store immutable `metadata_uri`, `original_creator`, and `registered_at` fields.
- Token archive preserves the on-chain legal record instead of burning it.
- Active ERC-721 tokens keep standard direct transfer behavior for wallet and marketplace composability.
- Transfers routed through `IPCollection` additionally update protocol transfer stats and emit protocol transfer events.

This architecture is designed for creator sovereignty and social-login wallet handoff flows. For example, a creator can initialize a collection through an embedded wallet and later transfer collection stewardship to a regular wallet without changing historical authorship records.

Build the contract:

```bash
cd contracts/MIP-Collections-ERC721
scarb build
```

Run tests:

```bash
cd contracts/MIP-Collections-ERC721
scarb test
```

Mainnet deployment flow:

```bash
cd contracts/MIP-Collections-ERC721

# Build Sierra/CASM artifacts
scarb build

# Declare IPNft first
starkli declare target/dev/ip_collection_erc_721_IPNft.contract_class.json --network mainnet

# Declare IPCollection
starkli declare target/dev/ip_collection_erc_721_IPCollection.contract_class.json --network mainnet

# Deploy IPCollection with the declared IPNft class hash as constructor calldata
starkli deploy <IPCollection_CLASS_HASH> <IPNFT_CLASS_HASH> --network mainnet
```

See `contracts/MIP-Collections-ERC721/README.md` for the full contract-specific interface, storage, events, and deployment notes.


## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have the following requirements:

* **Node.js** (version 18 or later) and npm installed. Download them from the official Node [website](https://nodejs.org/en/download/).
* **Basic understanding** of Starknet Foundry to deploy your own contract instance
* **Cairo** and **Scarb** for smart contract development

### System Requirements

- **Npm + Git**
- **ASDF + Scarb**
- **Starknet CLI**
- **Starknet Foundry**
- **Operating System**: macOS, Windows (including WSL), and Linux are supported

### Installation

1. **Clone the repository** to your local machine:

```bash
git clone https://github.com/mediolano-app/mediolano-contracts.git
cd mediolano-contracts
```

2. **Install dependencies**:

```bash
# Install Scarb (Cairo package manager)
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh

# Install Starknet Foundry
curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh
```

3. **Build contracts**:

```bash
# Build all contracts
scarb build

# Or build specific contract
cd contracts/MIP-Collections-ERC721
scarb build
```

4. **Run tests**:

```bash
# Run all tests
scarb test

# Run tests for specific contract
cd contracts/MIP-Collections-ERC721
scarb test
```

## 🔧 Development

### Project Structure

```
mediolano-contracts/
├── contracts/
│   ├── Medialane-Protocol/         # Core marketplace
│   ├── User-Achievements/          # Gamification system
│   ├── IP-Club/                    # Community management
│   ├── MIP-Collections-ERC721/      # Immutable ERC-721 IP collections
│   ├── IP-Revenue-Share/           # Revenue distribution
│   ├── IP-License-Agreement/       # Licensing contracts
│   ├── IP-Collective-Agreement/    # Multi-party agreements
│   └── ...                         # Additional contracts
├── scripts/                        # Deployment scripts
├── tests/                          # Integration tests
└── docs/                          # Documentation
```

### Building and Testing

Each contract directory contains its own `Scarb.toml` configuration file. You can build and test contracts individually:

```bash
# Navigate to specific contract
cd contracts/MIP-Collections-ERC721

# Build the contract
scarb build

# Run contract tests
scarb test

# Format code
scarb fmt
```

### Deployment

Deploy contracts to Starknet networks:

```bash
# Deploy to Sepolia testnet
starkli deploy ./target/dev/contract_name.contract_class.json \
  --network sepolia \
  --keystore ./keystore.json

# Deploy to mainnet
starkli deploy ./target/dev/contract_name.contract_class.json \
  --network mainnet \
  --keystore ./keystore.json
```

## 🛡️ Security

### Security Measures

- **Contract-Specific Authorization**: Permissions are scoped per contract; MIP Collections ERC-721 uses immutable registry and collection-owner checks instead of a global admin.
- **Immutable IP Collections**: MIP Collections ERC-721 has no global admin owner, no upgrade entrypoint, no mutable class hash, and no pause switch.
- **Permanent Provenance**: IP collection tokens preserve immutable metadata URI, original creator, and registration timestamp.
- **Transferable Stewardship**: Collection ownership can move atomically to another wallet for future mint authority without changing historical token records.
- **Composable ERC-721 Transfers**: Active MIP collection tokens support direct ERC-721 transfers; the registry transfer path remains available for protocol stats/events.
- **Reentrancy Protection**: Guards against reentrancy attacks
- **Input Validation**: Comprehensive validation of all user inputs
- **Overflow Protection**: Safe math operations throughout

## 🤝 Contributing

We are building open-source Integrity Web with the amazing **OnlyDust** platform. Check our [website](https://app.onlydust.com/p/mediolano) for more information.

We also have a [Telegram](https://t.me/mediolanoapp) group focused to support development.

Contributions are **greatly appreciated**. If you have a feature or suggestion that would make our platform better, please fork the repo and create a pull request with the tag "enhancement".

### How to Contribute

1. **Fork the Project**
2. **Create your Feature Branch** (`git checkout -b feature/Feature`)
3. **Commit your Changes** (`git commit -m 'Add some Feature'`)
4. **Push to the Branch** (`git push origin feature/YourFeature`)
5. **Open a Pull Request**

### Development Guidelines

- Follow Cairo best practices and coding standards
- Write comprehensive tests for new features
- Update documentation for any API changes
- Ensure all tests pass before submitting a pull request
- Use descriptive commit messages

### Issue Reporting

When reporting issues, please include:

- **Environment details** (OS, Cairo version, Scarb version)
- **Steps to reproduce** the issue
- **Expected vs actual behavior**
- **Error messages or logs**
- **Minimal code example** if applicable

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🌟 Acknowledgments

- **Starknet Foundation** for the amazing ZK-rollup technology
- **OpenZeppelin** for secure smart contract components
- **OnlyDust** for supporting open-source development
- **Community Contributors** who make this project possible

## 📞 Support

- **Documentation**: Check individual contract READMEs for specific guidance
- **Community**: Join our [Telegram](https://t.me/mediolanoapp) for discussions
- **Issues**: Report bugs and feature requests on GitHub

---

**Built with ❤️ for the Integrity Web on Starknet**
