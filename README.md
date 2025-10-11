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
