# 🏗 Scaffold-ETH 2

<h4 align="center">
  <a href="https://docs.scaffoldeth.io">Documentation</a> |
  <a href="https://scaffoldeth.io">Website</a>
</h4>

🧪 An open-source, up-to-date toolkit for building decentralized applications (dapps) on the Ethereum blockchain. It's designed to make it easier for developers to create and deploy smart contracts and build user interfaces that interact with those contracts.

⚙️ Built using NextJS, RainbowKit, Foundry/Hardhat, Wagmi, Viem, and Typescript.

- ✅ **Contract Hot Reload**: Your frontend auto-adapts to your smart contract as you edit it.
- 🪝 **[Custom hooks](https://docs.scaffoldeth.io/hooks/)**: Collection of React hooks wrapper around [wagmi](https://wagmi.sh/) to simplify interactions with smart contracts with typescript autocompletion.
- 🧱 [**Components**](https://docs.scaffoldeth.io/components/): Collection of common web3 components to quickly build your frontend.
- 🔥 **Burner Wallet & Local Faucet**: Quickly test your application with a burner wallet and local faucet.
- 🔐 **Integration with Wallet Providers**: Connect to different wallet providers and interact with the Ethereum network.

![Debug Contracts tab](https://github.com/scaffold-eth/scaffold-eth-2/assets/55535804/b237af0c-5027-4849-a5c1-2e31495cccb1)

## Requirements

Before you begin, you need to install the following tools:

- [Node (>= v20.18.3)](https://nodejs.org/en/download/)
- Yarn ([v1](https://classic.yarnpkg.com/en/docs/install/) or [v2+](https://yarnpkg.com/getting-started/install))
- [Git](https://git-scm.com/downloads)

## Quick Start for OpenSea QC

OpenSea QC has been enhanced with separate scripts to start the blockchain network and UI independently. This allows you to restart only the component that may have encountered issues, rather than restarting the entire environment.

### Installing Dependencies

Before running any scripts, make sure to install all the necessary dependencies:

```bash
# Navigate to the project directory
cd opensea-qc

# Install root dependencies
yarn install

# Install hardhat package dependencies
cd packages/hardhat
yarn install
cd ../..

# Install nextjs package dependencies
cd packages/nextjs
yarn install
cd ../..

# Install component dependencies
cd components/seaport
yarn install
cd ../..

cd components/erc721
yarn install
cd ../..

cd components/erc1155
yarn install
cd ../..

cd components/operator-filter
yarn install
cd ../..
```

### Starting Docker Services

The OpenSea QC testing environment requires several supporting services that run in Docker containers:

```bash
# Navigate to the project directory
cd opensea-qc

# Start all Docker services
./scripts/start-docker-services.sh
```

This script will:
1. Stop and remove any existing OpenSea QC Docker containers
2. Free up any ports that might be in use (27017, 5432, 6379, 9200, 4001, 5001, 8080)
3. Start the following services:
   - MongoDB (accessible at mongodb://localhost:27017)
   - PostgreSQL (accessible at postgresql://opensea:yourpassword@localhost:5432/opensea_db)
   - Redis (accessible at localhost:6379)
   - Elasticsearch (accessible at http://localhost:9200)
   - IPFS (accessible at http://localhost:5001)

> Note: Docker and Docker Compose must be installed on your system for this to work.

### Starting the Blockchain Network

To start the local blockchain network with all necessary contracts deployed:

```bash
# Navigate to the project directory
cd opensea-qc

# Start the blockchain network
./scripts/start-blockchain-network.sh
```

This script will:
1. Clear any existing blockchain processes
2. Start a local Hardhat blockchain network
3. Deploy and build all required smart contracts:
   - Seaport protocol
   - ERC721 contracts
   - ERC1155 contracts
   - Operator Filter Registry
   - Main project contracts

The blockchain will be accessible at http://localhost:8545.

### Starting the UI

Once the blockchain network is running, you can start the UI in a separate terminal:

```bash
# Navigate to the project directory (if not already there)
cd opensea-qc

# Start the UI
./scripts/start-ui.sh
```

This script will:
1. Check if the blockchain network is accessible
2. Start the NextJS frontend application

The UI will be accessible at http://localhost:3000.

### Full Start Sequence

For a complete environment setup, follow these steps in order:

1. Install dependencies (see Installing Dependencies section)
2. Start Docker services: `./scripts/start-docker-services.sh`
3. Start blockchain network: `./scripts/start-blockchain-network.sh`
4. Start UI: `./scripts/start-ui.sh`

### Restarting Components

If you encounter issues with either component:

- To restart the blockchain network: Press Ctrl+C in the terminal running `start-blockchain-network.sh` and run it again
- To restart the UI: Press Ctrl+C in the terminal running `start-ui.sh` and run it again

### Logs

Both scripts save logs that can be useful for troubleshooting:
- Blockchain logs: `/scripts/logs/blockchain.log`
- Frontend logs: `/scripts/logs/frontend.log`

## Original Scaffold-ETH 2 Documentation

Visit our [docs](https://docs.scaffoldeth.io) to learn all the technical details and guides of Scaffold-ETH 2.

To know more about its features, check out our [website](https://scaffoldeth.io).

## Contributing to Scaffold-ETH 2

We welcome contributions to Scaffold-ETH 2!

Please see [CONTRIBUTING.MD](https://github.com/scaffold-eth/scaffold-eth-2/blob/main/CONTRIBUTING.md) for more information and guidelines for contributing to Scaffold-ETH 2.
