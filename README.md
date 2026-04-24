# CCIP Self-Serve Tokens

This repository contains the `rwaUSD` upgradeable token contract and its associated token pool contracts for CCIP 1.6.

> **Scripts have moved.** All deployment and interaction scripts are now maintained in a separate repository: [multipli-finance/rwausd-token-scripts](https://github.com/multipli-finance/rwausd-token-scripts).

Find a list of available tutorials on the Chainlink documentation: [Cross-Chain Token (CCT) Tutorials](http://docs.chain.link/ccip/tutorials/cross-chain-tokens#overview).

## Table of Contents

1. [Setup](#setup)
2. [rwaUSD Token (Upgradeable)](#rwausd-token-upgradeable)
3. [Testing](#testing)
4. [Scripts](#scripts)

---

## 1. Setup

### Prerequisites

#### 1. Foundry

If you haven't already, install Foundry by following the [Foundry documentation](https://book.getfoundry.sh/getting-started/installation).

---

### Installation

#### 1. Clone the repository

```bash
git clone https://github.com/multipli-finance/rwausd-token-ccip
cd rwausd-token-ccip
```

#### 2. Install dependencies

```bash
forge install && npm install
```

#### 3. Compile the contracts

```bash
forge compile
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

---

## 4. Scripts

All deployment and interaction scripts (deploy token, deploy pools, claim admin, configure cross-chain settings, transfer tokens, etc.) have been moved to a dedicated repository:

**[https://github.com/multipli-finance/rwausd-token-scripts](https://github.com/multipli-finance/rwausd-token-scripts)**

Refer to that repository's README for setup instructions, config file structure, and usage examples for each script.
