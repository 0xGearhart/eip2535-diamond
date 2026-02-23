# EIP-2535 Diamond (Foundry)

**⚠️ This project is not audited. Do not use in production without a professional security review.**

## Table of Contents

- [EIP-2535 Diamond (Foundry)](#eip-2535-diamond-foundry)
  - [Table of Contents](#table-of-contents)
  - [About](#about)
  - [Implemented Standards](#implemented-standards)
  - [Architecture](#architecture)
    - [Core Components](#core-components)
  - [Repository Structure](#repository-structure)
  - [Getting Started](#getting-started)
    - [Requirements](#requirements)
    - [Install](#install)
    - [Environment Setup](#environment-setup)
  - [Usage](#usage)
    - [Build](#build)
    - [Run All Tests](#run-all-tests)
    - [Run Test Slices](#run-test-slices)
    - [Coverage](#coverage)
    - [Additional Make Targets](#additional-make-targets)
  - [Deployment](#deployment)
    - [Local (Anvil)](#local-anvil)
    - [Testnet / Mainnet](#testnet--mainnet)
  - [Testing Strategy](#testing-strategy)
  - [Security Notes](#security-notes)
  - [References](#references)
  - [License](#license)

## About

This repository implements an upgradeable **ERC-2535 Diamond** using Foundry, with:

- Diamond core (cut, loupe, fallback dispatch)
- Single-owner access control (`IERC173` style)
- ERC-20 facet (`name`, `symbol`, `decimals`, transfers, approvals)
- Owner `mint`, holder `burn`, and `burnFrom`
- One-time initializer for ERC-20 metadata and initial supply

The codebase follows a facet-first design where callable logic lives in facets and the `Diamond` contract stays as proxy plumbing.

## Implemented Standards

- ERC-2535 Diamond Standard
- IERC165 interface support
- IERC173 ownership interface
- ERC-20 (via OpenZeppelin interfaces)

## Architecture

```text
Users / EOAs
   |
   | call diamond address
   v
+---------------------+
|       Diamond       |
| (fallback/receive)  |
+----------+----------+
           |
           | delegatecall by selector
           v
+---------------------------+
|      Facets (modules)     |
| - DiamondCutFacet         |
| - DiamondLoupeFacet       |
| - OwnershipFacet          |
| - ERC20Facet              |
+---------------------------+
           |
           v
+---------------------------+
| Diamond Storage Libraries |
| - LibDiamond              |
| - LibERC20Storage         |
+---------------------------+
```

### Core Components

- `src/Diamond.sol`
  - Constructor wires the initial cut facet and interface support
  - `fallback()` routes calls by selector
  - `receive()` accepts ETH

- `src/libraries/LibDiamond.sol`
  - Selector table and facet address bookkeeping
  - Add/replace/remove logic for `diamondCut`
  - Ownership enforcement
  - Init delegatecall handling + revert wrapping

- `src/facets/DiamondCutFacet.sol`
  - Owner-gated external entrypoint for `diamondCut`

- `src/facets/DiamondLoupeFacet.sol`
  - Introspection (`facets`, `facetAddresses`, selector lookups)

- `src/facets/OwnershipFacet.sol`
  - `owner`, `transferOwnership`, `renounceOwnership`

- `src/facets/ERC20Facet.sol`
  - ERC-20 read/write functions
  - `mint` (owner), `burn`, `burnFrom`

- `src/upgradeInitializers/DiamondInit.sol`
  - One-time initialization guard
  - Sets ERC-20 metadata and optional initial mint

## Repository Structure

```text
.
├── src/
│   ├── Diamond.sol
│   ├── facets/
│   ├── interfaces/
│   ├── libraries/
│   └── upgradeInitializers/
├── script/
│   ├── DeployDiamond.s.sol
│   └── HelperConfig.s.sol
├── test/
│   ├── unit/
│   ├── integration/
│   ├── invariant/
│   │   ├── Handler.t.sol
│   │   └── InvariantsTest.t.sol
│   └── mocks/
├── foundry.toml
├── Makefile
└── README.md
```

## Getting Started

### Requirements

- `git`
- `foundry` (`forge`, `cast`, `anvil`)

### Install

```bash
git clone <your-repo-url>
cd eip2535-diamond
make
```

### Environment Setup

Create `.env` from `.env.example` and fill network RPC/API values:

```bash
cp .env.example .env
```

Important env vars used by scripts:

- `ETH_MAINNET_RPC_URL`
- `ETH_SEPOLIA_RPC_URL`
- `ARB_MAINNET_RPC_URL`
- `ARB_SEPOLIA_RPC_URL`
- `BASE_MAINNET_RPC_URL`
- `BASE_SEPOLIA_RPC_URL`
- `ETHERSCAN_API_KEY`
- `DEFAULT_KEY_ADDRESS`

`DEFAULT_KEY_ADDRESS` is expected by `HelperConfig` for supported non-local chains.

## Usage

### Build

```bash
make build
```

### Run All Tests

```bash
make test
```

### Run Test Slices

```bash
forge test --match-path test/unit/*
forge test --match-path test/integration/*
forge test --match-path test/invariant/InvariantsTest.t.sol
```

### Coverage

```bash
make coverage
make coverage-report
```

### Additional Make Targets

```bash
make reset
make clean
make snapshot
make gas-report
```

## Deployment

### Local (Anvil)

Terminal 1:

```bash
make anvil
```

Terminal 2:

```bash
make deploy
```

### Testnet / Mainnet

Use `make deploy` with network args:

```bash
make deploy ARGS="--network eth-sepolia"
make deploy ARGS="--network eth-MAINNET"
make deploy ARGS="--network arb-sepolia"
make deploy ARGS="--network arb-MAINNET"
make deploy ARGS="--network base-sepolia"
make deploy ARGS="--network base-MAINNET"
```

`HelperConfig` currently supports:

- Ethereum: Mainnet / Sepolia
- Arbitrum: Mainnet / Sepolia
- Base: Mainnet / Sepolia
- Local Anvil (`chainid 31337`)

If you need to bypass make targets, you can still run `forge script` directly.

## Testing Strategy

- `test/unit/`
  - Diamond core behavior, cut edge cases, loupe consistency, ownership
  - ERC-20 facet logic + fuzz tests
  - initializer guard/error paths

- `test/integration/`
  - End-to-end deployment flow using the deployment script
  - Address/code assertions and initial wiring checks

- `test/invariant/`
  - Handler-driven invariants under `fail_on_revert = true`
  - `sum(tracked balances) == totalSupply`
  - loupe table consistency (`facets` / `facetAddresses` / selector mapping)

## Security Notes

- This code is unaudited.
- Owner has upgrade authority via `diamondCut` and token mint authority.
- `renounceOwnership()` is supported and sets owner to `address(0)`.
- Initializer is one-time guarded (`DiamondInit__AlreadyInitialized`).
- Upgrade safety and selector bookkeeping are heavily tested, but audits are still required before production use.

## References

- EIP-2535: https://eips.ethereum.org/EIPS/eip-2535
- EIP-20: https://eips.ethereum.org/EIPS/eip-20
- Nick Mudge diamond reference implementations: https://github.com/mudgen/diamond
- Project reference list: `DiamondReferenceMaterial.md`

## License

MIT
