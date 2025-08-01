# Mediolano Codebase

Cairo smart contracts for Mediolano, the intellectual property provider of the integrity web, powered on Starknet.


Quick links:
<br>
<a href="https://ip.mediolano.app">Mediolano Dapp (Sepolia)</a>
<br>
<a href="https://mediolano.xyz">Website mediolano.xyz</a>
<br>
<a href="https://t.me/MediolanoStarknet">Telegram</a> | <a href="https://www.youtube.com/@Mediolano-app">YouTube</a> | <a href="https://x.com/mediolanoapp">X / Twitter</a>
<br>

![medialane-screen](https://github.com/user-attachments/assets/2b4c1d1d-6322-4a0c-8bb8-67e735ae1761)

> [!IMPORTANT]
> Mediolano dapp is in constant development and the current version runs on Starknet's Sepolia devnet. Use for testing purposes only.

## Programmable IP for the Integrity Web

Mediolano empowers creators, artists and organizations to make money from their content, without requiring them to know anything about crypto.

With permissionless services for Programmable Intellectual Property (IP), leveraging Starknet’s high-speed, low-cost transactions and zero-knowledge proofs, Mediolano provides a comprehensive suite of solutions to tokenize and monetize assets efficiently, transparently and with sovereignty.

With zero fees, Mediolano’s open-source protocol and dapp ensures immediate tokenization and protection under the Berne Convention for the Protection of Literary and Artistic Works (1886), covering 181 countries. This framework guarantees global recognition of authorship, providing verifiable proof of ownership for 50 to 70 years, depending on jurisdiction.

The platform also introduces advanced monetization, enabling diverse approaches to licensing, royalties, and financing creators economies. These tools are designed to offer integrations with various ecosystems, including communities, games, and AI agents, unlocking the true power of Programmable IP for the Integrity Web.


## 🏗️ Architecture Overview

### Core Components

```
Mediolano Protocol
├── Medialane Protocol (Marketplace Core)
├── User Achievements System
├── IP Tokenization (ERC-721/ERC-1155)
├── Programmable Licensing
├── Revenue Sharing & Royalties
├── Community & Club Management
├── Franchise & Monetization
├── Escrow & Negotiations
├── Collective Agreements
├── Collaborative Storytelling
└── Partner Certification
```

### Key Features

- **🎯 Zero-Knowledge IP Protection**: Leverage Starknet's ZK-proofs for privacy-preserving IP validation
- **💰 Revenue Sharing**: Automated distribution of royalties to IP owners and collaborators
- **🤝 Collective Ownership**: Multi-party IP agreements with governance and voting mechanisms
- **🏪 Marketplace Integration**: Seamless trading and licensing of IP assets
- **🎮 Gamification**: Achievement system to reward creators and build reputation
- **🌐 Community Tools**: NFT-based clubs and communities for creators
- **📄 Smart Licensing**: Programmable licensing with customizable terms
- **🔒 Escrow Services**: Secure transaction handling for IP negotiations

## Roadmap

- [x] Starknet Ignition **24.9**

- [x] MIP Protocol @ Starknet Sepolia **24.11**

- [x] Mediolano Dapp @ Starknet Sepolia **24.11**

- [x] Programmable IP Contracts **25.02**

- [x] MIP Dapp @ Starknet Sepolia **25.06**

- [X] MIP Protocol @ Starknet Mainnet **25.07**

- [ ] MIP Collections Protocol @ Starknet Sepolia **25.07**

- [ ] MIP Dapp @ Starknet Mainnet **25.08**

- [ ] Mediolano Dapp @ Starknet Mainnet **25.08**

- [ ] MIP Collections Protocol @ Starknet Mainnet **25.08**

- [ ] Medialane Protocol @ Starknet Sepolia **25.08**

- [ ] Medialane Dapp @ Starknet Sepolia **25.09**

- [ ] Medialane Protocol @ Starknet Mainnet **25.11**

- [ ] Medialane Dapp @ Starknet Mainnet **25.11**

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
cd contracts/IP-Club
scarb build
```

4. **Run tests**:

```bash
# Run all tests
scarb test

# Run tests for specific contract
cd contracts/User-Achievements
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
cd contracts/IP-Club

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

- **Access Control**: Role-based permissions using OpenZeppelin components
- **Reentrancy Protection**: Guards against reentrancy attacks
- **Input Validation**: Comprehensive validation of all user inputs
- **Overflow Protection**: Safe math operations throughout
- **Pause Functionality**: Emergency pause capabilities for critical contracts

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
