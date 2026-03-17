# CCIP Self-Serve Tokens

This repository contains a collection of Foundry scripts designed to simplify interactions with CCIP 1.6 contracts.

Find a list of available tutorials on the Chainlink documentation: [Cross-Chain Token (CCT) Tutorials](http://docs.chain.link/ccip/tutorials/cross-chain-tokens#overview).

## Table of Contents

1. [Setup](#setup)
2. [rwaUSD Token (Upgradeable)](#rwausd-token-upgradeable)
3. [Testing](#testing)
4. [AcceptAdminRole](#acceptadminrole)
5. [AddRemotePool](#addremotepool)
6. [ApplyChainUpdates](#applychainupdates)
7. [ClaimAdmin](#claimadmin)
8. [DeployBurnMintTokenPool](#deployburnminttokenpool)
9. [DeployLockReleaseTokenPool](#deploylockreleasetokenpool)
10. [DeployToken](#deploytoken)
11. [GetCurrentRateLimits](#getcurrentratelimits)
12. [GetPoolConfig](#getpoolconfig)
13. [MintTokens](#minttokens)
14. [RemoveRemotePool](#removeremotepool)
15. [SetPool](#setpool)
16. [SetRateLimitAdmin](#setratelimitadmin)
17. [TransferTokenAdminRole](#transfertokenadminrole)
18. [TransferTokens](#transfertokens)
19. [UpdateAllowList](#updateallowlist)
20. [UpdateRateLimiters](#updateratelimiters)

---

## 1. Setup

### Prerequisites

#### 1. Node.js

Make sure you have Node.js v22.10.0 or above installed. Optionally, you can use [nvm](https://github.com/nvm-sh/nvm) to manage Node.js versions:

```bash
nvm use 22 # if you are using nvm
```

Verify the correct version is installed:

```bash
node -v
```

Example output:

```bash
$ node -v
v22.15.0
```

#### 2. Foundry

If you haven't already, install Foundry by following the [Foundry documentation](https://book.getfoundry.sh/getting-started/installation).

---

### Installation

#### 1. Clone the repository

Clone the repository and navigate to the project directory:

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
PRIVATE_KEY=<your_private_key>
RPC_URL_ETHEREUM_MAINNET=<your_rpc_url_ethereum_mainnet>
RPC_URL_BASE_MAINNET=<your_rpc_url_base_mainnet>
ETHERSCAN_API_KEY=<your_etherscan_api_key>
```

| Variable                   | Description                                                                                                                                                                                                                                                                 |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PRIVATE_KEY`              | The private key for your wallet. If you use MetaMask, follow [this guide](https://support.metamask.io/managing-my-wallet/secret-recovery-phrase-and-private-keys/how-to-export-an-accounts-private-key/) to export your private key. **Required for signing transactions.** |
| `RPC_URL_ETHEREUM_MAINNET` | The RPC URL for Ethereum Mainnet. Obtain one from [Alchemy](https://www.alchemy.com/) or [Infura](https://infura.io/).                                                                                                                                                      |
| `RPC_URL_BASE_MAINNET`     | The RPC URL for Base Mainnet. Obtain one from [Alchemy](https://www.alchemy.com/) or [Infura](https://infura.io/).                                                                                                                                                          |
| `ETHERSCAN_API_KEY`        | An API key from Etherscan to verify your contracts. Obtain one from [Etherscan](https://docs.etherscan.io/getting-started/viewing-api-usage-statistics).                                                                                                                    |

#### 3. Load environment variables

Load the environment variables into your terminal session:

```bash
source .env
```

#### 4. Install dependencies

```bash
forge install && npm install
```

#### 5. Compile the contracts

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
    "maxSupply": 0, //Unlimited supply
    "preMint": 0,
    "ccipAdminAddress": "0x928786CD018d7615738dBA48462Be6B57384ddd4"
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

A separate `testnet.config.json` file is provided for running scripts against testnet environments (Avalanche Fuji and Ethereum Sepolia).

By default, all scripts load `mainnet.config.json` (mainnet). To use the testnet config, pass the `CONFIG_PATH` environment variable when invoking any script:

```bash
CONFIG_PATH="./script/testnet.config.json" forge script script/<ScriptName>.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

For example, to deploy the token on Ethereum Sepolia using the testnet config:

```bash
CONFIG_PATH="./script/testnet.config.json" forge script script/DeployToken.s.sol \
  --rpc-url $RPC_URL_SEPOLIA \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

---

### Running Tests

The following npm scripts are available for running the test suite:

| Script     | Command                                          | Description                            |
| ---------- | ------------------------------------------------ | -------------------------------------- |
| `test`     | `forge clean && forge build && forge test -vvvv` | Full rebuild with verbose test output. |
| `test:min` | `forge clean && forge build && forge test`       | Full rebuild with minimal test output. |

Run a test script using:

```bash
npm run test
```

or for minimal output:

```bash
npm run test:min
```

---

## 2. rwaUSD Token (Upgradeable)

### Overview

This repository extends the standard Chainlink CCT setup with a custom upgradeable token contract — `rwaUSD` — designed for USD-pegged real-world assets on CCIP-enabled chains.

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
forge script script/DeployToken.s.sol \
  --rpc-url $RPC_URL_ETHEREUM_MAINNET \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

The deploy script reads configuration from `mainnet.config.json`:

```json
{
  "rwaUSDToken": {
    "admin": "0xYourAdminAddress"
  }
}
```

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

## 4. AcceptAdminRole

### Description

Accepts the admin role for a deployed token via the `TokenAdminRegistry` contract. This script reads the token address from a JSON file and uses the `TokenAdminRegistry` contract to accept the admin role if the signer is the pending administrator for the token.

### Usage

```bash
forge script script/AcceptAdminRole.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Config Parameters

- **Deployed Token Address**: Read from the output file corresponding to the current chain (e.g., `deployedToken_base_mainnet.json`).
- **TokenAdminRegistry Address**: Retrieved based on the network settings in `HelperConfig.s.sol`.

### Examples

```bash
forge script script/AcceptAdminRole.s.sol --rpc-url $RPC_URL_ETHEREUM_MAINNET --private-key $PRIVATE_KEY --broadcast
```

This will:

- Retrieve the deployed token address from the JSON file for the Ethereum Mainnet network.
- Check if the current signer is the pending administrator.
- Accept the admin role for the token if the signer is the pending administrator.

### Notes

- **Config-based Execution**: Ensure the token is deployed before running this script.
- **Pending Administrator Check**: Only the pending administrator can accept the admin role.
- **Chain Name**: The script automatically determines the current chain based on `block.chainid`.

---

## 5. AddRemotePool

### Description

Adds a remote pool to a local token pool's configuration, enabling cross-chain interactions with the specified remote pool.

### Usage

```bash
forge script script/AddRemotePool.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast \
  --sig "run(address,uint256,address)" -- <POOL_ADDRESS> <REMOTE_CHAIN_ID> <REMOTE_POOL_ADDRESS>
```

### Parameters

- **poolAddress**: The address of the local `TokenPool` contract.
- **remoteChainId**: The chain ID of the remote blockchain.
- **remotePoolAddress**: The address of the remote pool contract.

### Examples

```bash
forge script script/AddRemotePool.s.sol --rpc-url $RPC_URL_ETHEREUM_MAINNET --private-key $PRIVATE_KEY --broadcast \
  --sig "run(address,uint256,address)" -- \
  0xYourLocalPoolAddress \
  8453 \
  0xYourRemotePoolAddressOnBaseMainnet
```

### Notes

- **Network Configuration**: The script uses `HelperConfig.s.sol` and `HelperUtils.s.sol` to map `remoteChainId` to a `remoteChainSelector`.
- **Permissions**: The account executing the script must have the necessary permissions to call `addRemotePool`.

---

## 6. ApplyChainUpdates

### Description

Configures cross-chain parameters for a token pool, including remote pool addresses and rate limiting settings for token transfers between chains.

### Usage

```bash
forge script script/ApplyChainUpdates.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Config Parameters

- **Deployed Local Pool Address**: Read from the output file for the current chain.
- **Deployed Remote Pool Address**: Read from the JSON file for the remote chain.
- **Deployed Remote Token Address**: Read from the JSON file for the remote chain.
- **Remote Chain Selector**: Fetched from `HelperConfig.s.sol`.
- **Rate Limiter Configuration**: Disabled by default.

### Examples

```bash
forge script script/ApplyChainUpdates.s.sol --rpc-url $RPC_URL_ETHEREUM_MAINNET --private-key $PRIVATE_KEY --broadcast
```

### Notes

- **Config-based Execution**: Ensure both the local and remote pools/tokens are deployed before running this script.
- **Rate Limiting**: Disabled by default but can be enabled by modifying the script's rate limiter configurations.

---

## 7. ClaimAdmin

### Description

Claims the admin role for a deployed token contract using the `CCIP admin` function.

### Usage

```bash
forge script script/ClaimAdmin.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Config Parameters

- **Deployed Token Address**: Read from the output file for the current chain.
- **Admin Address**: Read from the `mainnet.config.json` file (`ccipAdminAddress` field).

### Examples

```bash
forge script script/ClaimAdmin.s.sol --rpc-url $RPC_URL_ETHEREUM_MAINNET --private-key $PRIVATE_KEY --broadcast
```

### Notes

- Ensure the `ccipAdminAddress` field is correctly set in `mainnet.config.json` before running this script.

---

## 8. DeployBurnMintTokenPool

### Description

Deploys a new `BurnMintTokenPool` contract and associates it with an already deployed token. Assigns mint and burn roles to the pool on the token contract.

### Usage

```bash
forge script script/DeployBurnMintTokenPool.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

### Config Parameters

- **Deployed Token Address**: Read from the output file for the current chain.
- **Router and RMN Proxy**: Retrieved from `HelperConfig.s.sol`.

### Examples

```bash
forge script script/DeployBurnMintTokenPool.s.sol --rpc-url $RPC_URL_ETHEREUM_MAINNET --private-key $PRIVATE_KEY --broadcast --verify
```

### Notes

- **Grant Mint & Burn Roles**: After deploying the token pool, mint and burn roles are automatically granted to the pool.

---

## 9. DeployLockReleaseTokenPool

### Description

Deploys a new `LockReleaseTokenPool` contract and associates it with an already deployed token.

### Usage

```bash
forge script script/DeployLockReleaseTokenPool.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

### Config Parameters

- **Deployed Token Address**: Read from the output file for the current chain.
- **Router and RMN Proxy**: Retrieved from `HelperConfig.s.sol`.

### Examples

```bash
forge script script/DeployLockReleaseTokenPool.s.sol --rpc-url $RPC_URL_ETHEREUM_MAINNET --private-key $PRIVATE_KEY --broadcast --verify
```

---

## 10. DeployToken

### Description

Deploys the `rwaUSD` upgradeable token contract via a UUPS proxy. Reads the admin address from `mainnet.config.json` and deploys both the implementation and proxy in a single script.

### Usage

```bash
forge script script/DeployToken.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Config Parameters

The script reads from `mainnet.config.json`:

```json
{
  "rwaUSDToken": {
    "admin": "0xYourAdminAddress"
  }
}
```

- **`admin`**: The address granted `DEFAULT_ADMIN_ROLE` and set as the CCIP admin. The deployer never holds admin rights.

### Examples

```bash
forge script script/DeployToken.s.sol \
  --rpc-url $RPC_URL_ETHEREUM_MAINNET \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Notes

- **Upgradeable Deployment**: The script deploys a UUPS proxy pointing to the `rwaUSD` implementation using the OZ Foundry upgrades plugin.
- **Chain Name**: The deployed proxy address is saved to `script/output/deployedToken_<chainName>.json`.

---

## 11. GetCurrentRateLimits

### Description

Retrieves and displays the current inbound and outbound rate limiter states for a given `TokenPool` contract and a specified remote chain.

### Usage

```bash
forge script script/GetCurrentRateLimits.s.sol:GetCurrentRateLimits --rpc-url $RPC_URL --sig "run(address,uint256)" -- <POOL_ADDRESS> <REMOTE_CHAIN_ID>
```

### Parameters

- **poolAddress**: The address of the `TokenPool` contract.
- **remoteChainId**: The chain ID of the remote chain.

### Examples

```bash
forge script script/GetCurrentRateLimits.s.sol:GetCurrentRateLimits \
  --rpc-url $RPC_URL_ETHEREUM_MAINNET \
  --sig "run(address,uint256)" -- \
  0xYourPoolAddressOnEthereumMainnet \
  8453
```

---

## 12. GetPoolConfig

### Description

Retrieves and displays the current configuration for a deployed token pool, including remote pool addresses, rate limiter settings, and allow list information.

### Usage

```bash
forge script script/GetPoolConfig.s.sol:GetPoolConfig --rpc-url $RPC_URL --sig "run(address)" -- <POOL_ADDRESS>
```

### Parameters

- **poolAddress**: The address of the token pool.

### Examples

```bash
forge script script/GetPoolConfig.s.sol:GetPoolConfig \
  --rpc-url $RPC_URL_ETHEREUM_MAINNET \
  --sig "run(address)" -- \
  0xYourPoolAddressOnEthereumMainnet
```

### Notes

- **No Transactions**: This script only reads data and does not broadcast any transactions.

---

## 13. MintTokens

### Description

Mints a specified amount of tokens to the sender's address. The amount is pulled from `mainnet.config.json`.

### Usage

```bash
forge script script/MintTokens.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Config Parameters

- **Deployed Token Address**: Read from the output file for the current chain.
- **Mint Amount**: Read from `mainnet.config.json` (`tokenAmountToMint` field).

### Examples

```bash
forge script script/MintTokens.s.sol --rpc-url $RPC_URL_ETHEREUM_MAINNET --private-key $PRIVATE_KEY --broadcast
```

---

## 14. RemoveRemotePool

### Description

Removes a remote pool from a local `TokenPool` contract's configuration, disabling cross-chain interactions with the specified remote pool.

> **Warning**: Removing a remote pool will reject all inflight transactions from that pool.

### Usage

```bash
forge script script/RemoveRemotePool.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast \
  --sig "run(address,uint256,address)" -- <POOL_ADDRESS> <REMOTE_CHAIN_ID> <REMOTE_POOL_ADDRESS>
```

### Parameters

- **poolAddress**: The address of the local `TokenPool` contract.
- **remoteChainId**: The chain ID of the remote blockchain.
- **remotePoolAddress**: The address of the remote pool to remove.

### Examples

```bash
forge script script/RemoveRemotePool.s.sol --rpc-url $RPC_URL_ETHEREUM_MAINNET --private-key $PRIVATE_KEY --broadcast \
  --sig "run(address,uint256,address)" -- \
  0xYourLocalPoolAddress \
  8453 \
  0xYourRemotePoolAddressOnBaseMainnet
```

---

## 15. SetPool

### Description

Sets the pool for a deployed token in the `TokenAdminRegistry` contract.

### Usage

```bash
forge script script/SetPool.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Config Parameters

- **Deployed Token Address**: Read from the output file for the current chain.
- **Deployed Pool Address**: Read from the output file for the current chain.
- **TokenAdminRegistry Address**: Retrieved from `HelperConfig.s.sol`.

### Examples

```bash
forge script script/SetPool.s.sol --rpc-url $RPC_URL_ETHEREUM_MAINNET --private-key $PRIVATE_KEY --broadcast
```

---

## 16. SetRateLimitAdmin

### Description

Sets the rate limit administrator for a specified `TokenPool` contract.

### Usage

```bash
forge script script/SetRateLimitAdmin.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast \
  --sig "run(address,address)" -- <POOL_ADDRESS> <ADMIN_ADDRESS>
```

### Parameters

- **poolAddress**: The address of the `TokenPool` contract.
- **adminAddress**: The address to assign as the new rate limit administrator.

### Examples

```bash
forge script script/SetRateLimitAdmin.s.sol --rpc-url $RPC_URL_ETHEREUM_MAINNET --private-key $PRIVATE_KEY --broadcast \
  --sig "run(address,address)" -- \
  0xYourPoolAddress \
  0xNewAdminAddress
```

---

## 17. TransferTokenAdminRole

### Description

Initiates the transfer of the admin role for a specified token to a new administrator via the `TokenAdminRegistry` contract. The new admin must call `acceptAdminRole` to complete the transfer.

### Usage

```bash
forge script script/TransferTokenAdminRole.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast \
  --sig "run(address,address)" -- <TOKEN_ADDRESS> <NEW_ADMIN_ADDRESS>
```

### Parameters

- **tokenAddress**: The address of the token.
- **newAdmin**: The address of the new administrator.

### Examples

```bash
forge script script/TransferTokenAdminRole.s.sol --rpc-url $RPC_URL_ETHEREUM_MAINNET --private-key $PRIVATE_KEY --broadcast \
  --sig "run(address,address)" -- \
  0xYourTokenAddress \
  0xNewAdminAddress
```

### Notes

- **Two-Step Process**:
  1. The current admin calls `transferAdminRole` to propose the new admin.
  2. The new admin calls `acceptAdminRole` to accept the role.

---

## 18. TransferTokens

### Description

Facilitates cross-chain token transfers using Chainlink's CCIP. Reads the token address and amount from `mainnet.config.json` and handles fee payment in either native tokens or LINK.

### Usage

```bash
forge script script/TransferTokens.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Config Parameters

- **Deployed Token Address**: Read from the output file for the current chain.
- **Transfer Amount**: Read from `mainnet.config.json` (`tokenAmountToTransfer` field).
- **Fee Type**: Specified in `mainnet.config.json` as `"native"` or `"link"`.
- **Destination Chain**: Determined from the `remoteChains` field in `mainnet.config.json`.

### Examples

```bash
forge script script/TransferTokens.s.sol --rpc-url $RPC_URL_ETHEREUM_MAINNET --private-key $PRIVATE_KEY --broadcast
```

---

## 19. UpdateAllowList

### Description

Updates the allow list for a specified `TokenPool` contract by adding and/or removing addresses.

### Usage

```bash
forge script script/UpdateAllowList.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast \
  --sig "run(address,address[],address[])" -- <POOL_ADDRESS> [<ADDRESSES_TO_ADD>] [<ADDRESSES_TO_REMOVE>]
```

### Parameters

- **poolAddress**: The address of the `TokenPool` contract.
- **addressesToAdd**: An array of addresses to add to the allow list.
- **addressesToRemove**: An array of addresses to remove from the allow list.

### Examples

```bash
forge script script/UpdateAllowList.s.sol --rpc-url $RPC_URL_ETHEREUM_MAINNET --private-key $PRIVATE_KEY --broadcast \
  --sig "run(address,address[],address[])" -- \
  0xYourPoolAddress \
  '[0xAddressToAdd1,0xAddressToAdd2]' \
  '[0xAddressToRemove]'
```

### Notes

- **Allow List Must Be Enabled**: The pool must have been deployed with allow list functionality enabled.
- Pass an empty array `'[]'` for either parameter if no addresses need to be added or removed.

---

## 20. UpdateRateLimiters

### Description

Modifies the rate limiter settings for inbound and outbound transfers for a deployed token pool.

### Usage

```bash
forge script script/UpdateRateLimiters.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast \
  --sig "run(address,uint256,uint8,bool,uint128,uint128,bool,uint128,uint128)" -- \
  <POOL_ADDRESS> \
  <REMOTE_CHAIN_ID> \
  <RATE_LIMITER_TO_UPDATE> \
  <OUTBOUND_RATE_LIMIT_ENABLED> \
  <OUTBOUND_RATE_LIMIT_CAPACITY> \
  <OUTBOUND_RATE_LIMIT_RATE> \
  <INBOUND_RATE_LIMIT_ENABLED> \
  <INBOUND_RATE_LIMIT_CAPACITY> \
  <INBOUND_RATE_LIMIT_RATE>
```

### Parameters

- **poolAddress**: The address of the token pool.
- **remoteChainId**: The chain ID of the remote blockchain.
- **rateLimiterToUpdate**: `0` for outbound, `1` for inbound, `2` for both.
- **outboundRateLimitEnabled**: Boolean to enable or disable outbound rate limits.
- **outboundRateLimitCapacity**: Maximum token capacity for the outbound rate limiter (in wei).
- **outboundRateLimitRate**: Refill rate for the outbound rate limiter (in wei per second).
- **inboundRateLimitEnabled**: Boolean to enable or disable inbound rate limits.
- **inboundRateLimitCapacity**: Maximum token capacity for the inbound rate limiter (in wei).
- **inboundRateLimitRate**: Refill rate for the inbound rate limiter (in wei per second).

### Examples

Update both inbound and outbound rate limiters:

```bash
forge script script/UpdateRateLimiters.s.sol --rpc-url $RPC_URL_ETHEREUM_MAINNET --private-key $PRIVATE_KEY --broadcast \
  --sig "run(address,uint256,uint8,bool,uint128,uint128,bool,uint128,uint128)" -- \
  <POOL_ADDRESS> \
  8453 \
  2 \
  true \
  10000000000000000000 \
  100000000000000000 \
  true \
  20000000000000000000 \
  100000000000000000
```

Update only the outbound rate limiter:

```bash
forge script script/UpdateRateLimiters.s.sol --rpc-url $RPC_URL_ETHEREUM_MAINNET --private-key $PRIVATE_KEY --broadcast \
  --sig "run(address,uint256,uint8,bool,uint128,uint128,bool,uint128,uint128)" -- \
  <POOL_ADDRESS> \
  8453 \
  0 \
  true \
  10000000000000000000 \
  100000000000000000 \
  false \
  0 \
  0
```

### Notes

- **Capacity and Rate**: Capacity is the maximum token bucket size; rate is the refill speed in tokens per second.
- **Units**: All values are in the smallest token unit (wei).
- **Permissions**: The account must have the necessary permissions (owner or rate limit admin) to call `setChainRateLimiterConfig`.
