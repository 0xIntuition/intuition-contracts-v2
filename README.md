# Intuition V2 Smart Contracts

The Intuition V2 smart contracts for the Intuition protocol, built using [Foundry](https://book.getfoundry.sh/).

## Installation

The contracts, ABIs, and creation bytecode are published to npm as
[`@0xintuition/contracts-v2`](https://www.npmjs.com/package/@0xintuition/contracts-v2):

```sh
npm install @0xintuition/contracts-v2
# or
bun add @0xintuition/contracts-v2
```

### Using the ABIs and bytecode (TypeScript / JavaScript)

The ABIs are exported `as const`, so they work out of the box with viem's type inference, and equally with ethers:

```ts
import { MultiVaultAbi, TrustBondingAbi } from "@0xintuition/contracts-v2/abis";
import { MultiVaultBytecode } from "@0xintuition/contracts-v2/bytecodes";
// or everything from the package root:
import { MultiVaultAbi, MultiVaultBytecode } from "@0xintuition/contracts-v2";

const vault = getContract({ address, abi: MultiVaultAbi, client });
```

`MultiVault` and `MultiVaultMigrationMode` link the external library `MultiVaultLib`, so their bytecode contains
`__$…$__` placeholders. To deploy them, first deploy `MultiVaultLib`, then substitute its address using the exported
link references:

```ts
import { MultiVaultBytecode, MultiVaultLibBytecode, MultiVaultLinkReferences } from "@0xintuition/contracts-v2/bytecodes";

const libAddress = await deploy({ bytecode: MultiVaultLibBytecode }); // deploy the library first
const placeholder = MultiVaultLinkReferences["src/libraries/MultiVaultLib.sol:MultiVaultLib"];
const linkedBytecode = MultiVaultBytecode.replaceAll(placeholder, libAddress.slice(2).toLowerCase());
```

Both ESM and CommonJS are supported, with full TypeScript declarations.

### Using the Solidity sources

The `.sol` sources are shipped under `src/`, and all Solidity dependencies (OpenZeppelin v5 and v4, solady, PRB Math,
account-abstraction) are installed automatically as npm dependencies, so you can import and inherit the contracts
directly:

```solidity
import { MultiVault } from "@0xintuition/contracts-v2/src/protocol/MultiVault.sol";
import { IMultiVault } from "@0xintuition/contracts-v2/src/interfaces/IMultiVault.sol";
```

Every import path in the sources matches the npm layout of its dependency, so:

**Hardhat** resolves everything through `node_modules` with no extra configuration.

**Foundry** users need remappings pointing each prefix into `node_modules` (e.g. in `remappings.txt`):

```text
@0xintuition/contracts-v2/=node_modules/@0xintuition/contracts-v2/
@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/
@openzeppelin/contracts-upgradeable/=node_modules/@openzeppelin/contracts-upgradeable/
@openzeppelin-v4/contracts-upgradeable/=node_modules/@openzeppelin-v4/contracts-upgradeable/
solady/=node_modules/solady/
@prb/math/=node_modules/@prb/math/
@account-abstraction/contracts/=node_modules/@account-abstraction/contracts/
```

(The `@openzeppelin-v4` remapping is only needed if you compile the legacy `Trust`/`TrustToken` contracts.)

The contracts are compiled with Solidity `0.8.29`, optimizer enabled at 10,000 runs, EVM version `cancun`.

## What's Inside

- [Forge](https://github.com/foundry-rs/foundry/blob/master/forge): compile, test, fuzz, format, and deploy smart
  contracts
- [Bun]: Foundry defaults to git submodules, but this template also uses Node.js packages for managing dependencies
- [Forge Std](https://github.com/foundry-rs/forge-std): collection of helpful contracts and utilities for testing
- [Prettier](https://github.com/prettier/prettier): code formatter for non-Solidity files
- [Solhint](https://github.com/protofire/solhint): linter for Solidity code

## Deploy Smart Contracts on Intuition Testnet

1. Execute script/base/BaseEmissionsControllerDeploy.s.sol
   - Update the `BASE_SEPOLIA_BASE_EMISSIONS_CONTROLLER` in .env
2. Execute script/intuition/MultiVaultMigrationModeDeploy.s.sol
   - Update the `INTUITION_SEPOLIA_MULTIVAULT_MIGRATION_MODE_IMPLEMENTATION` in .env
3. Execute script/intuition/IntuitionDeployAndSetup.s.sol
   - Update the `INTUITION_SEPOLIA_MULTI_VAULT_MIGRATION_MODE_PROXY` in .env
   - Update the `INTUITION_SEPOLIA_SATELLITE_EMISSIONS_CONTROLLER` in .env
4. Execute script/base/BaseEmissionsControllerSetup.s.sol

## Upgrade MultiVaultMigrationMode to MultiVault contract post-migration

1. Make sure to set `INTUITION_SEPOLIA_PROXY_ADMIN` in .env
2. Execute MultiVaultMigrationModeUpgrade.s.sol

## Testing

forge test --match-path 'tests/unit/CoreEmissionsController/\*.sol'

## Usage

This is a list of the most frequently needed commands.

### Build

Build the contracts:

```sh
$ forge build
```

### Clean

Delete the build artifacts and cache directories:

```sh
$ forge clean
```

### Compile

Compile the contracts:

```sh
$ forge build
```

### Coverage

Get a test coverage report:

```sh
$ forge coverage
```

### Deploy

Deploy to Anvil:

```sh
$ forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545
```

For this script to work, you need to have a `MNEMONIC` environment variable set to a valid
[BIP39 mnemonic](https://iancoleman.io/bip39/).

For instructions on how to deploy to a testnet or mainnet, check out the
[Solidity Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting.html) tutorial.

### Format

Format the contracts:

```sh
$ forge fmt
```

### Gas Usage

Get a gas report:

```sh
$ forge test --gas-report
```

### Lint

Lint the contracts:

```sh
$ bun run lint
```

### Test

Run the tests:

```sh
$ forge test
```

### Test Coverage

Generate test coverage and output result to the terminal:

```sh
$ bun run test:coverage
```

### Test Coverage Report

Generate test coverage with lcov report (you'll have to open the `./coverage/index.html` file in your browser, to do so
simply copy paste the path):

```sh
$ bun run test:coverage:report
```

> [!NOTE]
>
> This command requires you to have [`lcov`](https://github.com/linux-test-project/lcov) installed on your machine. On
> macOS, you can install it with Homebrew: `brew install lcov`.

## Claude Slash Commands (Shared)

This repo includes team-shared Claude slash commands in `.claude/commands`.

Use `/help` in Claude Code to see them, then run:

- `/audit-solidity [codebase-path] [spec-document-optional]`
- `/audit-context [codebase-path] [--focus <module>]`
- `/audit-entry-points [directory-path]`
- `/audit-static-analysis [codebase-path]`
- `/audit-spec-compliance <spec-document> [codebase-path]`
- `/audit-variants [vulnerability-description]`

Generated reports are written to `audits/automated-reports/`.

## License

This project is licensed under BUSL-1.1

## Utility Scripts

### Trust V2 Reinitialize Call Data

Generates the **encoded calldata** for the `reinitialize()` function for the TRUST token upgrade.

```bash
npx tsx script/base/upgrades/generate-trust-v2-upgrade-calldata.ts <ADMIN_ADDRESS> <BASE_EMISSIONS_CONTROLLER_ADDRESS>
```

### Trust Proxy V2 Upgrade

Generates the **encoded calldata** for the Trust `ProxyAdmin.upgradeAndCall()` execution.

```bash
npx tsx script/base/upgrades/generate-trust-proxy-upgrade-and-call-calldata.ts "0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3" <IMPLEMENTATION_ADDRESS> <REINITIALIZE_CALLDATA_OR_0x>
```

---

### Timelock Update Delay

Prepares the **`TimelockController` schedule parameters** for updating the minimum delay within the `TimelockController`
contract.

```bash
npx tsx script/base/upgrades/generate-timelock-update-delay-calldata.ts <RPC_URL> <NEW_DELAY_IN_SECONDS>
```

Example:

```bash
npx tsx script/base/upgrades/generate-timelock-update-delay-calldata.ts "https://mainnet.base.org" 259200
```

### Timelock Upgrade and Call

Builds the **`TimelockController` schedule parameters** for a `ProxyAdmin.upgradeAndCall()` execution.

```bash
npx tsx script/base/upgrades/generate-timelock-upgrade-and-call-calldata.ts <RPC_URL> <PROXY_ADDRESS> <IMPLEMENTATION_ADDRESS> <REINITIALIZE_CALLDATA_OR_0x>
```

Example:

```bash
npx tsx script/base/upgrades/generate-timelock-upgrade-and-call-calldata.ts "https://mainnet.base.org" "0x000000000000000000000000000000000000dEaD" "0x000000000000000000000000000000000000dEaD" "0x"
```

# Deployed Contracts

## Mainnet

### Base Mainnet

| Contract Name               | Address                                    | ProxyAdmin                                 |
| --------------------------- | ------------------------------------------ | ------------------------------------------ |
| Trust                       | 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3 | 0x857552ab95E6cC389b977d5fEf971DEde8683e8e |
| Upgrades TimelockController | 0x1E442BbB08c98100b18fa830a88E8A57b5dF9157 | /                                          |
| BaseEmissionsController     | 0x7745bDEe668501E5eeF7e9605C746f9cDfb60667 | 0x58dCdf3b6F5D03835CF6556EdC798bfd690B251a |
| EmissionsAutomationAdapter  | 0xb1ce9Ac324B5C3928736Ec33b5Fd741cb04a2F2d | /                                          |

### Intuition Mainnet

| Contract Name                 | Address                                    | ProxyAdmin                                 |
| ----------------------------- | ------------------------------------------ | ------------------------------------------ |
| WrappedTrust                  | 0x81cFb09cb44f7184Ad934C09F82000701A4bF672 | /                                          |
| Upgrades TimelockController   | 0x321e5d4b20158648dFd1f360A79CAFc97190bAd1 | /                                          |
| Parameters TimelockController | 0x71b0F1ABebC2DaA0b7B5C3f9b72FAa1cd9F35FEA | /                                          |
| MultiVault                    | 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e | 0x1999faD6477e4fa9aA0FF20DaafC32F7B90005C8 |
| AtomWalletFactory             | 0x33827373a7D1c7C78a01094071C2f6CE74253B9B | 0x68667f67986650B8C86A87612c556dc0dC07F9a7 |
| AtomWalletBeacon              | 0xC23cD55CF924b3FE4b97deAA0EAF222a5082A1FF | /                                          |
| AtomWarden                    | 0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165 | 0xf548dbDd7a18Ee9d91106b3b6967770b504aeE2A |
| SatelliteEmissionsController  | 0x73B8819f9b157BE42172E3866fB0Ba0d5fA0A5c6 | 0xdF60D18E86F3454309aD7734055843F7ee5f30a3 |
| TrustBonding                  | 0x635bBD1367B66E7B16a21D6E5A63C812fFC00617 | 0xF10FEE90B3C633c4fCd49aA557Ec7d51E5AEef62 |
| BondingCurveRegistry          | 0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930 | 0x678c7D3d759611b554A1293295007f2b202C2302 |
| LinearCurve                   | 0xc3eFD5471dc63d74639725f381f9686e3F264366 | 0x6365D6eD0caf54d6290D866d56C043d3fCDc3B8c |
| OffsetProgressiveCurve        | 0x23afF95153aa88D28B9B97Ba97629E05D5fD335d | 0xe58B117aDfB0a141dC1CC22b98297294F6E2c5E7 |
| Multicall3                    | 0xcA11bde05977b3631167028862bE2a173976CA11 | /                                          |
| EntryPoint                    | 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108 | /                                          |
| SafeSingletonFactory          | 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7 | /                                          |

## Testnet

### Base Sepolia

| Contract Name               | Address                                    | ProxyAdmin                                 |
| --------------------------- | ------------------------------------------ | ------------------------------------------ |
| TestTrust                   | 0xA54b4E6e356b963Ee00d1C947f478d9194a1a210 | /                                          |
| Upgrades TimelockController | 0xE16E8e10664d399D36D2220fFA763e9367980507 | /                                          |
| BaseEmissionsController     | 0x6B96fB3867b666A7957fa589866627ea902ec2C6 | 0x369e4C2ED9BF272CbA61Ac75ab26E8309672e344 |

### Intuition Testnet

| Contract Name                 | Address                                    | ProxyAdmin                                 |
| ----------------------------- | ------------------------------------------ | ------------------------------------------ |
| WrappedTrust                  | 0xDE80b6EE63f7D809427CA350e30093F436A0fe35 | /                                          |
| Upgrades TimelockController   | 0xc7721c865ba0bDf760073594922434Edc0C2d200 | /                                          |
| Parameters TimelockController | 0x50B874C22e4D54db9ACeE181bF2D5a0663D2D70A | /                                          |
| MultiVault                    | 0xF76d6976DeBFbB012ebc53e925BC4AEFCaA7C6c6 | 0x8D4e6d81dF3d1bc5F67A7c52d73Ac2a8fA799861 |
| AtomWalletFactory             | 0x900cff1007055c850FB48695a3CB121290d6f17b | 0x1916673334Ed719902Cfcfd4d2Df1Dbe7dcf0455 |
| AtomWalletBeacon              | 0x16deCCF5484bE9FFb5c8a2d800E0fdf27b876012 | /                                          |
| AtomWarden                    | 0xf3f875E0d390C9bA8Aa21881E983baDe91866A38 | 0xb2aEdA82040F7A42a550092b656739221aC00E19 |
| SatelliteEmissionsController  | 0x2f4ef00b05f5AA9976154125Cc46D47CAB75B1b7 | 0x36Cf9Ad9C957864bc65855B4D3bbA663c0b74fD8 |
| TrustBonding                  | 0x9E79446fE4B1683eF1678654554535a9c90B1C3D | 0x94C1506F0C50b960c435ad3E77f1B84be356cA04 |
| BondingCurveRegistry          | 0xb3bfd62d259E07d623844fC7bDB7D54F74Ff9052 | 0xFC34EaAa7c44Ea6E7B3191250deC4976a777498A |
| LinearCurve                   | 0x7499bFa918DBc73Ace4A05D6194a5Cd343AE32Dd | 0x2dA7d4Cb31a2e3329BaCe291b8D5b8F38d595553 |
| OffsetProgressiveCurve        | 0x96bb9020ba4D027E42C29eCB3CEcc2471E505E6C | 0x76c92E3A7A83dD893BF4056D2d37258e8d7BD05b |
| Multicall3                    | 0xcA11bde05977b3631167028862bE2a173976CA11 | /                                          |
| EntryPoint                    | 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108 | /                                          |
