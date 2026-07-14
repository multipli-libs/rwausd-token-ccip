# rwaUSD Token — CCIP

This repository contains the `rwaUSD` upgradeable token contract for CCIP 1.6. Cross-chain transfers use Chainlink's stock [`BurnMintTokenPool`](https://github.com/smartcontractkit/chainlink-ccip) contract from `@chainlink/contracts-ccip`.

> **Scripts have moved.** All deployment and interaction scripts are maintained in a separate repository: [multipli-finance/rwausd-token-scripts](https://github.com/multipli-finance/rwausd-token-scripts).

## Table of Contents

1. [Deployed Addresses](#deployed-addresses)
2. [Setup](#setup)
3. [rwaUSD Token (Upgradeable)](#rwausd-token-upgradeable)
4. [Testing](#testing)
5. [Scripts](#scripts)
6. [Version Bumping](#version-bumping)
7. [Pre-commit Hooks](#pre-commit-hooks)

---

## 1. Deployed Addresses

| Network  | rwaUSD Token                                 | BurnMintTokenPool                            |
| -------- | -------------------------------------------- | -------------------------------------------- |
| Ethereum | `0x8Fcd23142047A3073ed332a0Ed07d1e8D2BD5177` | `0x7f49a388c6884c0d1706f7774e9a5575d100aa63` |
| Base     | `0x272Ec977f4575df41cD47b1b254954E1C7972789` | `0x7Dc0496016d88c3EbA6d54D1514F24B3C9872894` |
| Ink      | `0x2A66Bb2dA3AD1c854E79307F64b862DECD860D4c` | `0xd74FB32112b1eF5b4C428Fead8dA8d85A0019009` |

**Bridges (CCIP lanes):**

- Ethereum &harr; Base
- Ethereum &harr; Ink

---

## 2. Setup

### Quick Setup

After cloning the repo, you can run the setup script instead of doing the steps below manually:

```bash
npm run setup
```

This runs [`bash_helpers/setup.sh`](bash_helpers/setup.sh), which:

- Runs `nvm use` to pick up the Node version from `.nvmrc` (if `nvm` is installed)
- Runs `forge install && npm install` to install dependencies
- Copies `.env.example` to `.env` if a `.env` doesn't already exist

You'll still need to set up your wallet accounts — see below.

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

#### 2. Install dependencies

```bash
forge install && npm install
```

#### 3. Set up wallet accounts

Use `cast wallet` to store encrypted keystores. Create a keystore for each deployer account you intend to use:

```bash
cast wallet import deployer --interactive
```

The command prompts for a private key and a password to encrypt the keystore. Verify your accounts with:

```bash
cast wallet list
```

#### 4. Compile the contracts

```bash
forge compile
```

---

## 3. rwaUSD Token (Upgradeable)

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

Deployment now happens via the [rwausd-token-scripts](https://github.com/multipli-finance/rwausd-token-scripts) repo — see its README for the deploy scripts and config file format.

#### Upgrading

To upgrade the proxy to a new implementation, deploy a new contract that extends `rwaUSD` and call `upgradeToAndCall` via the admin:

```solidity
token.upgradeToAndCall(newImplementation, "");
```

Only the address holding `UPGRADER_ROLE` can authorize upgrades.

---

## 4. Testing

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

## 5. Scripts

All deployment and interaction scripts (deploy token, deploy pools, claim admin, configure cross-chain settings, transfer tokens, etc.) have been moved to a dedicated repository:

**[https://github.com/multipli-finance/rwausd-token-scripts](https://github.com/multipli-finance/rwausd-token-scripts)**

Refer to that repository's README for setup instructions, config file structure, and usage examples for each script.

---

## 6. Version Bumping

Package version is bumped via [`bash_helpers/bump_version.sh`](bash_helpers/bump_version.sh), wrapped by npm scripts:

```bash
npm run bump:patch
npm run bump:minor
npm run bump:major
```

Each of these:

1. Runs `npm version <type>`, bumping `package.json` and creating a git commit + tag (message: `v<version>: <msg>`, defaults to `Version bump (<type>)`).
2. Pushes the current branch to `origin`.
3. Pushes the new tag to `origin`.

To use a custom commit message, call the script directly:

```bash
./bash_helpers/bump_version.sh --type=minor -m "Add Base bridging support"
```

> **Note:** This pushes to `origin` automatically — make sure you're on the intended branch before running it.

---

## 7. Pre-commit Hooks

This repo uses [pre-commit](https://pre-commit.com/) with shared hooks from [`multipli-smartcontract-hooks`](https://github.com/multipli-finance/multipli-smartcontract-hooks) (see [`.pre-commit-config.yaml`](.pre-commit-config.yaml)):

- `forge-fmt` — enforces Foundry formatting on staged Solidity files
- `slither` — runs static analysis on staged Solidity files

### Install

```bash
pip install pre-commit
pre-commit install
```

Once installed, the hooks run automatically on `git commit`. To run them manually against all files:

```bash
pre-commit run --all-files
```
