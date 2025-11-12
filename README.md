# Intuition V2 Smart Contracts

The Intuition V2 smart contracts for the Intuition protocol, built using [Foundry](https://book.getfoundry.sh/).

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

forge test --match-path 'tests/unit/CoreEmissionsController/*.sol'

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


## License

This project is licensed under BUSL-1.1

## Utility Scripts

### Trust V2 Reinitialize Call Data 

Generates the **encoded calldata** for the `reinitialize()` function for the TRUST token upgrade.

```bash
npx tsx script/upgrades/generate-trust-v2-upgrade-calldata.ts <ADMIN_ADDRESS> <BASE_EMISSIONS_CONTROLLER_ADDRESS>
```


### Trust Proxy V2 Upgrade 

Generates the **encoded calldata** for the Trust `ProxyAdmin.upgradeAndCall()` execution.

```bash
npx tsx script/upgrades/generate-trust-proxy-upgrade-and-call-calldata.ts "0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3" <IMPLEMENTATION_ADDRESS> <REINITIALIZE_CALLDATA_OR_0x>
```

---

### Timelock Update Delay

Prepares the **`TimelockController` schedule parameters** for updating the minimum delay within the `TimelockController` contract.

```bash
npx tsx script/upgrades/generate-timelock-update-delay-calldata.ts <RPC_URL> <NEW_DELAY_IN_SECONDS>
```

Example:

```bash
npx tsx script/upgrades/generate-timelock-update-delay-calldata.ts "https://mainnet.base.org" 259200
```


### Timelock Upgrade and Call

Builds the **`TimelockController` schedule parameters** for a `ProxyAdmin.upgradeAndCall()` execution.

```bash
npx tsx script/upgrades/generate-timelock-upgrade-and-call-calldata.ts <RPC_URL> <PROXY_ADDRESS> <IMPLEMENTATION_ADDRESS> <REINITIALIZE_CALLDATA_OR_0x>
```

Example:

```bash
npx tsx script/upgrades/generate-timelock-upgrade-and-call-calldata.ts "https://mainnet.base.org" "0x000000000000000000000000000000000000dEaD" "0x000000000000000000000000000000000000dEaD" "0x"
```

# Deployed Contracts

## Mainnet

### Base Mainnet

| Contract Name               | Address                                    | ProxyAdmin                                 |
|-----------------------------|--------------------------------------------|--------------------------------------------|
| Trust                       | 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3 | 0x857552ab95E6cC389b977d5fEf971DEde8683e8e |
| Upgrades TimelockController | 0x1E442BbB08c98100b18fa830a88E8A57b5dF9157 | /                                          |
| BaseEmissionsController     | 0x7745bDEe668501E5eeF7e9605C746f9cDfb60667 | 0x58dCdf3b6F5D03835CF6556EdC798bfd690B251a |
| EmissionsAutomationAdapter  | 0xb1ce9Ac324B5C3928736Ec33b5Fd741cb04a2F2d | /                                          |

### Intuition Mainnet

| Contract Name                 | Address                                    | ProxyAdmin                                  |
|-------------------------------|--------------------------------------------|---------------------------------------------|
| WrappedTrust                  | 0x81cFb09cb44f7184Ad934C09F82000701A4bF672 | /                                           |
| Upgrades TimelockController   | 0x321e5d4b20158648dFd1f360A79CAFc97190bAd1 | /                                           |
| Parameters TimelockController | 0x71b0F1ABebC2DaA0b7B5C3f9b72FAa1cd9F35FEA | /                                           |
| MultiVault                    | 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e | 0x1999faD6477e4fa9aA0FF20DaafC32F7B90005C8  |
| AtomWalletFactory             | 0x33827373a7D1c7C78a01094071C2f6CE74253B9B | 0x68667f67986650B8C86A87612c556dc0dC07F9a7  |
| AtomWalletBeacon              | 0xC23cD55CF924b3FE4b97deAA0EAF222a5082A1FF | /                                           |
| AtomWarden                    | 0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165 | 0xf548dbDd7a18Ee9d91106b3b6967770b504aeE2A  |
| SatelliteEmissionsController  | 0x73B8819f9b157BE42172E3866fB0Ba0d5fA0A5c6 | 0xdF60D18E86F3454309aD7734055843F7ee5f30a3  |
| TrustBonding                  | 0x635bBD1367B66E7B16a21D6E5A63C812fFC00617 | 0xF10FEE90B3C633c4fCd49aA557Ec7d51E5AEef62  |
| BondingCurveRegistry          | 0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930 | 0x678c7D3d759611b554A1293295007f2b202C2302  |
| LinearCurve                   | 0xc3eFD5471dc63d74639725f381f9686e3F264366 | 0x6365D6eD0caf54d6290D866d56C043d3fCDc3B8c  |
| OffsetProgressiveCurve        | 0x23afF95153aa88D28B9B97Ba97629E05D5fD335d | 0xe58B117aDfB0a141dC1CC22b98297294F6E2c5E7  |
| Multicall3                    | 0xcA11bde05977b3631167028862bE2a173976CA11 | /                                           |
| EntryPoint                    | 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108 | /                                           |
| SafeSingletonFactory          | 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7 | /                                           |

## Testnet

### Base Sepolia

| Contract Name               | Address                                    | ProxyAdmin                                 |
|-----------------------------|--------------------------------------------|--------------------------------------------|
| TestTrust                   | 0xA54b4E6e356b963Ee00d1C947f478d9194a1a210 | /                                          |
| Upgrades TimelockController | 0x9099BC9fd63B01F94528B60CEEB336C679eb6d52 | /                                          |
| BaseEmissionsController     | 0xC14773Aae24aA60CB8F261995405C28f6D742DCf | 0x0b954b1CbAAf8972845BC5D31a8B748f0F8849fc |

### Intuition Testnet

| Contract Name                 | Address                                    | ProxyAdmin                                  |
|-------------------------------|--------------------------------------------|---------------------------------------------|
| WrappedTrust                  | 0xDE80b6EE63f7D809427CA350e30093F436A0fe35 | /                                           |
| Upgrades TimelockController   | 0x59B7EaB1cFA47F8E61606aDf79a6b7B5bBF1aF26 | /                                           |
| Parameters TimelockController | 0xcCB113bfFf493d80F32Fb799Dca23686a04302A7 | /                                           |
| MultiVault                    | 0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91 | 0x840d79645824C43227573305BBFCd162504BBB6e  |
| AtomWalletFactory             | 0x70f2227ae95E574898b5D78C30D1145A2289Fc81 | 0x83e13aD14714236b5d9eca851FE6561Cfc9220c9  |
| AtomWalletBeacon              | 0x575aA51cd6709fe81546E84A77B873bDE00Ce62C | /                                           |
| AtomWarden                    | 0xd52645aa134318a152817947B33655D93cb30703 | 0xabBf8147d33e76251383A81c81189077C505B51A  |
| SatelliteEmissionsController  | 0x850b461acbACf86e5253288a4B8Dcd1D4864De6b | 0x5ec513714f57f7b984875719Bd8Ef00d05487524  |
| TrustBonding                  | 0x75dD32b522c89566265eA32ecb50b4Fc4d00ADc7 | 0x214D3833114e25262bb8e4E9B5A99F062bFb93D4  |
| BondingCurveRegistry          | 0x419fdC0D56c3Fc27592Bf887B5Be3184EffdFA73 | 0x0C5AeAba37b1E92064f0af684D65476d24F52a9A  |
| LinearCurve                   | 0x006C022b854022C1646dA5094F1D77A17D3897AB | 0x34D65193EE2e1449FE6CB8eca1EE046FcC21669e  |
| OffsetProgressiveCurve        | 0x778f87476f266817f1D715fC172E51C4B85FBb16 | 0x6A65336598d4783d0673DD238418248909C71F26  |
| Multicall3                    | 0xcA11bde05977b3631167028862bE2a173976CA11 | /                                           |
| EntryPoint                    | 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108 | /                                           |
