# rwaUSD Token — CCIP

This repository contains the `rwaUSD` upgradeable token contract and its associated token pool contracts for CCIP 1.6.

> **Scripts have moved.** All deployment and interaction scripts are now maintained in a separate repository: [multipli-finance/rwausd-token-scripts](https://github.com/multipli-finance/rwausd-token-scripts).

## Table of Contents

1. [Setup](#setup)
2. [rwaUSD Token (Upgradeable)](#rwausd-token-upgradeable)
3. [Testing](#testing)
4. [Scripts](#scripts)

---

## 1. Setup

### Prerequisites

#### 1. Node.js

Make sure you have Node.js v24.16.0 or above installed. The repository includes an [`.nvmrc`](.nvmrc) file, so if you use [nvm](https://github.com/nvm-sh/nvm) you can run:

```bash
nvm use # automatically picks up .nvmrc
```

Verify the correct version is installed:

```bash
node -v
```

Example output:

```bash
$ node -v
v24.16.0
```

#### 2. Foundry

If you haven't already, install Foundry by following the [Foundry documentation](https://book.getfoundry.sh/getting-started/installation).

---

### Installation

#### 1. Clone the repository

```bash
git clone https://github.com/multipli-finance/rwausd-token-ccip
cd rwausd-token-ccip
```

#### 2. Set up environment variables

Create a `.env` file by copying the provided example:

```bash
cp .env.example .env
```

Open the `.env` file and fill in the required values:

```bash
RPC_URL_ETHEREUM_MAINNET=<your_rpc_url_ethereum_mainnet>
RPC_URL_ETHEREUM_TESTNET=<your_rpc_url_ethereum_sepolia>
ETHERSCAN_API_KEY=<your_etherscan_api_key>
ETHERSCAN_MAINNET_VERIFIER_URL=<your_etherscan_mainnet_verifier_url>
ETHERSCAN_TESTNET_VERIFIER_URL=<your_etherscan_testnet_verifier_url>
```

These variables are referenced by `foundry.toml` under `[rpc_endpoints]` and `[etherscan]`, which exposes them as the named aliases `eth_mainnet` and `eth_testnet` used directly in scripts.

| Variable                         | Description                                                                                                                                              |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `RPC_URL_ETHEREUM_MAINNET`       | The RPC URL for Ethereum Mainnet. Obtain one from [Alchemy](https://www.alchemy.com/) or [Infura](https://infura.io/).                                   |
| `RPC_URL_ETHEREUM_TESTNET`       | The RPC URL for Ethereum Sepolia testnet. Obtain one from [Alchemy](https://www.alchemy.com/) or [Infura](https://infura.io/).                           |
| `ETHERSCAN_API_KEY`              | An API key from Etherscan to verify your contracts. Obtain one from [Etherscan](https://docs.etherscan.io/getting-started/viewing-api-usage-statistics). |
| `ETHERSCAN_MAINNET_VERIFIER_URL` | The Etherscan verifier URL for Ethereum Mainnet (e.g. `https://api.etherscan.io/api`).                                                                   |
| `ETHERSCAN_TESTNET_VERIFIER_URL` | The Etherscan verifier URL for Sepolia testnet (e.g. `https://api-sepolia.etherscan.io/api`).                                                            |

#### 3. Load environment variables

Load the environment variables into your terminal session:

```bash
source .env
```

#### 4. Install dependencies

```bash
forge install && npm install
```

#### 5. Set up wallet accounts

Use `cast wallet` to store encrypted keystores. Create a keystore for each deployer account you intend to use:

```bash
cast wallet import deployer --interactive
```

The command prompts for a private key and a password to encrypt the keystore. Verify your accounts with:

```bash
cast wallet list
```

#### 6. Compile the contracts

```bash
forge compile
```

---

### Config File Overview

The `mainnet.config.json` file within the `script` directory defines the key parameters used by all scripts for **mainnet deployments**. You can customize the token name, symbol, maximum supply, and cross-chain settings, among other fields.

A separate `testnet.config.json` is also provided for testnet deployments. See the [Testnet Configuration](#testnet-configuration) section below for details.

Example `mainnet.config.json` file:

```json
{
  "rwaUSDToken": {
    "name": "Real World Asset USD",
    "symbol": "rwaUSD",
    "decimals": 18,
    "maxSupply": 0,
    "preMint": 0,
    "ccipAdminAddress": "0x8cFee31bf3A57EC2C86D9e0f476Bd36aCA611Fa5"
  },
  "tokenAmountToMint": 1000000000000000000000,
  "tokenAmountToTransfer": 100000000000000000000,
  "feeType": "native",
  "remoteChains": {
    "1": 8453,
    "8453": 1
  }
}
```

The `mainnet.config.json` file contains the following parameters:

| Field                   | Description                                                                                                                                                                                                                    |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `name`                  | The name of the token you are going to deploy.                                                                                                                                                                                 |
| `symbol`                | The symbol of the token.                                                                                                                                                                                                       |
| `decimals`              | The number of decimals for the token (usually `18` for standard ERC tokens).                                                                                                                                                   |
| `maxSupply`             | The maximum supply of tokens (in the smallest unit, according to `decimals`). When `maxSupply` is 0, the supply is unlimited.                                                                                                  |
| `preMint`               | The amount of tokens to be minted to the owner at the time of deployment (in the smallest unit, according to `decimals`). When `preMint` is 0, no tokens will be minted during deployment.                                     |
| `ccipAdminAddress`      | The address of the CCIP admin.                                                                                                                                                                                                 |
| `tokenAmountToMint`     | The amount of tokens to mint when running the minting script (in wei).                                                                                                                                                         |
| `tokenAmountToTransfer` | The amount of tokens to transfer when running the token transfer script.                                                                                                                                                       |
| `feeType`               | Defines the fee type for transferring tokens across chains. Options are `"link"` or `"native"`.                                                                                                                                |
| `remoteChains`          | Defines the relationship between source and remote (destination) chain IDs. Example: `"8453": 1` means that if you're running a script on Base Mainnet (chain ID `8453`), the remote chain is Ethereum Mainnet (chain ID `1`). |

---

### Testnet Configuration

A separate `testnet.config.json` file is provided for running scripts against testnet environments.

By default, all scripts load `mainnet.config.json`. To use the testnet config, pass the `CONFIG_PATH` environment variable when invoking any script:

```bash
CONFIG_PATH="./script/testnet.config.json" forge script script/<ScriptName>.s.sol:<ContractName> \
  --rpc-url eth_testnet \
  --account deployer \
  --sender <YOUR_DEPLOYER_ADDRESS> \
  --broadcast
```

For example, to deploy the token on Ethereum Sepolia using the testnet config:

```bash
CONFIG_PATH="./script/testnet.config.json" forge script script/deployment/DeployToken.s.sol:DeployToken \
  --rpc-url eth_testnet \
  --account deployer \
  --sender <YOUR_DEPLOYER_ADDRESS> \
  --broadcast
```

To verify the deployed contracts on Etherscan:

```bash
CONFIG_PATH="./script/testnet.config.json" forge script script/deployment/DeployToken.s.sol:DeployToken \
  --rpc-url eth_testnet \
  --account deployer \
  --sender <YOUR_DEPLOYER_ADDRESS> \
  --verify \
  --resume
```

---

## 2. rwaUSD Token (Upgradeable)

### Overview

This repository implements `rwaUSD` — a custom upgradeable token contract designed for USD-pegged real-world assets on CCIP-enabled chains.

Instead of deploying the standard `BurnMintERC20`, we implemented `rwaUSD` as a self-contained UUPS-upgradeable token. It is based on Chainlink's [`BurnMintERC20UUPS`](https://github.com/smartcontractkit/chainlink-evm/blob/develop/contracts/src/v0.8/shared/token/ERC20/upgradeable/BurnMintERC20UUPS.sol) and [`BurnMintERC20PausableUUPS`](https://github.com/smartcontractkit/chainlink-evm/blob/develop/contracts/src/v0.8/shared/token/ERC20/upgradeable/BurnMintERC20PausableUUPS.sol) contracts from the Chainlink EVM repository, but rather than inheriting from these as separate base contracts, all functionality is merged directly into `rwaUSD` as a single self-contained implementation.

---

### rwaUSD

`rwaUSD` combines the mint/burn functionality of `BurnMintERC20UUPS` and the pausable functionality of `BurnMintERC20PausableUUPS` into a single contract, without inheriting from either. It uses OpenZeppelin v5.x upgradeable contracts and follows the UUPS proxy pattern.

#### Key changes from the upstream Chainlink contracts

**1. Self-contained implementation**

In the upstream Chainlink repository, pausable functionality is split across two contracts — `BurnMintERC20UUPS` provides the core mint/burn/role logic, and `BurnMintERC20PausableUUPS` extends it with pause/unpause support. `rwaUSD` merges both into a single file without inheritance from either, making the full implementation self-contained and easier to audit.

**2. Renamed storage struct and namespaced slot**

The upstream `BurnMintERC20UUPS` uses the following storage namespace:

```solidity
// keccak256(abi.encode(uint256(keccak256("chainlink.storage.BurnMintERC20UUPS")) - 1)) & ~bytes32(uint256(0xff));
bytes32 private constant BURN_MINT_ERC20_UUPS_STORAGE_LOCATION = ...;
```

`rwaUSD` uses a project-specific namespace:

```solidity
// keccak256(abi.encode(uint256(keccak256("multipli.storage.rwaUSD")) - 1)) & ~bytes32(uint256(0xff));
bytes32 private constant RWAUSD_STORAGE_LOCATION = ...;
```

The storage struct has also been renamed from `BurnMintERC20UUPSStorage` to `RwaUsdStorage`:

```solidity
struct RwaUsdStorage {
    address ccipAdmin;
    uint8 decimals;
    uint256 maxSupply;
}
```

#### Deployment

```bash
forge script script/deployment/DeployToken.s.sol:DeployToken \
  --rpc-url eth_mainnet \
  --account deployer \
  --sender <YOUR_DEPLOYER_ADDRESS> \
  --broadcast
```

To verify the deployed contracts on Etherscan:

```bash
forge script script/deployment/DeployToken.s.sol:DeployToken \
  --rpc-url eth_mainnet \
  --account deployer \
  --sender <YOUR_DEPLOYER_ADDRESS> \
  --verify \
  --resume
```

The deploy script reads configuration from `mainnet.config.json`:

```json
{
  "rwaUSDToken": {
    "admin": "0xYourAdminAddress"
  }
}
```

- **`admin`**: The address granted `DEFAULT_ADMIN_ROLE` and set as the CCIP admin. The deployer never holds admin rights.

#### Upgrading

To upgrade the proxy to a new implementation, deploy a new contract that extends `rwaUSD` and call `upgradeToAndCall` via the admin:

```solidity
token.upgradeToAndCall(newImplementation, "");
```

Only the address holding `UPGRADER_ROLE` can authorize upgrades.

---

## 3. Testing

### Overview

The test suite covers `rwaUSD` initialization, access control, UUPS upgradeability, and ERC-7201 namespaced storage integrity. All tests run with Foundry and require no live network connection.

### Prerequisites

Install dependencies before running tests:

```bash
npm install
forge install
```

### Running the full test suite

```bash
forge test
```

For verbose output showing each test name and any revert reasons:

```bash
forge test -vvv
```

The following npm scripts are also available:

| Script     | Command                                          | Description                            |
| ---------- | ------------------------------------------------ | -------------------------------------- |
| `test`     | `forge clean && forge build && forge test -vvvv` | Full rebuild with verbose test output. |
| `test:min` | `forge clean && forge build && forge test`       | Full rebuild with minimal test output. |

```bash
npm run test
```

or for minimal output:

```bash
npm run test:min
```

---

## 4. Scripts

All deployment and interaction scripts (deploy token, deploy pools, claim admin, configure cross-chain settings, transfer tokens, etc.) have been moved to a dedicated repository:

**[https://github.com/multipli-finance/rwausd-token-scripts](https://github.com/multipli-finance/rwausd-token-scripts)**

Refer to that repository's README for setup instructions, config file structure, and usage examples for each script.
