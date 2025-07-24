# Intuition Protocol

Intuition is an Ethereum-based attestation protocol harnessing the wisdom of the crowds to create an open knowledge and reputation graph. Our infrastructure makes it easy for applications and their users to capture, explore, and curate verifiable data. We’ve prioritized making developer integrations easy and have implemented incentive structures that prioritize ‘useful’ data and discourage spam.

In bringing this new data layer to the decentralized web, we’re opening the flood gates to countless new use cases that we believe will kick off a consumer application boom.

The Intuition Knowledge Graph will be recognized as an organic flywheel, where the more developers that implement it, the more valuable the data it houses becomes.

## Getting Started

- [Intuition Protocol](#intuition-protocol)
  - [Getting Started](#getting-started)
  - [Documentation](#documentation)
    - [Known Nuances](#known-nuances)
  - [Building and Running Tests](#building-and-running-tests)
    - [Prerequisites](#prerequisites)
    - [Step by Step Guide](#step-by-step-guide)
      - [Install Dependencies](#install-dependencies)
      - [Build](#build)
      - [Run Tests](#run-tests)
      - [Run Fuzz Tests](#run-fuzz-tests)
    - [Deployment Process using OpenZeppelin Defender](#deployment-process-using-openzeppelin-defender)
      - [Run Manticore (Symbolic Execution)](#run-manticore-symbolic-execution)
    - [Deployment Process](#deployment-process)
    - [Deployment Verification](#deployment-verification)
    - [Upgrade Process](#upgrade-process)
    - [Bonding Curves](#bonding-curves)
  - [Deployed Contracts](#deployed-contracts)
    - [Base Mainnet](#base-mainnet)
    - [Base Sepolia](#base-sepolia)

## Documentation

To get a basic understanding of the Intuition protocol, please check out the following:

- [Official Website](https://intuition.systems)
- [Official Documentation](https://docs.intuition.systems)
- [Deep Dive into Our Smart Contracts](https://intuition.gitbook.io/intuition-or-beta-contracts)

### Known Nuances

- Share prices may get arbitrarily large as deposits/withdraws occur after Vault asset and share amounts approach 0 (i.e. if all users have withdrawn from the Vault), but this still elegantly achieves our desired functionality - which is, Users earn fee revenue when they are shareholders of a vault and deposit/redeem activities occur while they remain shareholders. This novel share price mechanism is used in lieu of a side-pocket reward pool for gas efficiency.
- The Admin can pause the contracts, though there is an emergency withdraw that allows users to withdraw from the contract even while paused. This emergency withdraw bypasses all fees, to reduce the surface area of attack.
- Exit fees are configurable, but have a maximum limit which they can be set to, preventing loss of user funds. Users also have the timelock window to withdraw from the contracts if they do not agree with a parameter change.

## Building and Running Tests

To build the project and run tests, follow these steps:

### Prerequisites

- [Node.js](https://nodejs.org/en/download/)
- [Foundry](https://getfoundry.sh)

### Step by Step Guide

#### Install Dependencies

```shell
$ npm i
$ forge install
```

#### Build

```shell
$ forge build
```

#### Run Tests

```shell
$ forge test -vvv
```

#### Run Fuzz Tests

- Make sure you have at least node 16 and python 3.6 installed on your local machine
- Add your FUZZ_AP_KEY to the .env file locally
- Run the following command to install the `diligence-fuzzing` package:

```shell
$ pip3 install diligence-fuzzing
```

- After the installation is completed, run the fuzzing CLI:

```shell
$ fuzz forge test
```

- Finally, check your Diligence Fuzzing dashboard to see the results of the fuzzing tests

- On newer versions of Python, you may receive this error:

```shell
ModuleNotFoundError: No module named 'distutils'
```

In this case, you just need to install setuptools because distutils was deprecated in Python 3.10:

```shell
$ pip3 install setuptools
```

### Deployment Process using OpenZeppelin Defender

- Install the `slither-analyzer` package:

```shell
  $ pip3 install slither-analyzer
```

- After the installation is completed, run the slither analysis bash script:

```shell
  $ npm run slither
```

#### Run Manticore (Symbolic Execution)

- Make sure you have [Docker](https://docker.com/products/docker-desktop) installed on your local machine

- Build the Docker image:

```shell
  $ docker build -t manticore-analysis .
```

- Run the Docker container:

```shell
  $ docker run --rm -v "$(pwd)":/app manticore-analysis
```

### Deployment Process

To deploy the Beta smart contract system on to a public testnet or mainnet, you’ll need the following:

- RPC URL of the network that you’re trying to deploy to (as for us, we’re targeting Base Sepolia testnet as our target chain for the testnet deployments)
- Export `PRIVATE_KEY` of a deployer account in the terminal, and fund it with some test ETH to be able to cover the gas fees for the smart contract deployments
- For Base Sepolia, there is a reliable [testnet faucet](https://alchemy.com/faucets/base-sepolia) deployed by Alchemy
- Deploy smart contracts using the following command:

```shell
$ forge script script/Deploy.s.sol --broadcast --rpc-url <your_rpc_url> --private-key $PRIVATE_KEY
```

### Deployment Verification

To verify the deployed smart contracts on Etherscan, you’ll need to export your Etherscan API key as `ETHERSCAN_API_KEY` in the terminal, and then run the following command:

```shell
$ forge verify-contract <0x_contract_address> ContractName --watch --chain-id <chain_id>
```

**Notes:**

- When verifying your smart contracts, you can use an optional parameter `--constructor-args` to pass the constructor arguments of the smart contract in the ABI-encoded format
- The chain ID for Base Sepolia is `84532`, whereas the chain ID for Base Mainnet is `8453`

### Upgrade Process

To upgrade the smart contract you need:

- Deploy a new version of contracts you want to upgrade, for example `MultiVault`. You need to add the directive `@custom:oz-upgrades-from` on the line before where you define the contract and set the version of the upgrade on the `init` function (e.g. `reinitializer(2)`)
- If using a multisig as an upgrade admin, schedule the upgrade for some time in the future (e.g. 2 days) using this script to generate the parameters that can be used in Safe Transaction Builder:

```shell
$ forge script script/TimelockController.s.sol
```

- After the delay passes (e.g. 2 days) you can call this again, just change the method on the target to `execute`

### Bonding Curves

Bonding curves have been added for the Atom / Triple vaults. When creating an Atom or a Triple, you must specify a Bonding Curve ID.

- If you are in doubt of which curve to use, select ID '1' for the Linear curve.
- Additional bonding curves will be added over time. Currently we have the Linear curve, the Logarithmic curve and the Stepped Logarithmic Curve
- A bonding curve is set upon creating the Atom / Triple and cannot be changed after.
- New bonding curves are registered with the BondingCurveRegistry contract, after they are deployed.
- All bonding curves implement the BaseCurve abstract contract.
- Different bonding curves create varying incentive mechanisms for users to stake.

Here is a visualization of the Logarithmic Bonding Curve, initialized with a scale of 2e18, an offset of 1, and a divisor of 1e18:
[__________________________________________________] 1.0 ether -> 0.802469135802469132 e18 shares
[_________________________________] 2.0 ether -> 1.333333333333333332 e18 shares
[_______________________] 3.0 ether -> 1.704 e18 shares
[________________] 4.0 ether -> 1.975308641975308636 e18 shares
[____________] 5.0 ether -> 2.181729834791059276 e18 shares
[__________] 6.0 ether -> 2.34375 e18 shares
[________] 7.0 ether -> 2.474165523548239592 e18 shares
[______] 8.0 ether -> 2.581333333333333332 e18 shares
[_____] 9.0 ether -> 2.670924117205108934 e18 shares
[____] 10.0 ether -> 2.746913580246913576 e18 shares
[____] 11.0 ether -> 2.812168108026096186 e18 shares
[___] 12.0 ether -> 2.868804664723032064 e18 shares
[___] 13.0 ether -> 2.918419753086419746 e18 shares
[__] 14.0 ether -> 2.962239583333333332 e18 shares
[__] 15.0 ether -> 3.001221249745572966 e18 shares
[__] 16.0 ether -> 3.036122542295381794 e18 shares
[_] 17.0 ether -> 3.067551149341497782 e18 shares
[_] 18.0 ether -> 3.096 e18 shares
[_] 19.0 ether -> 3.12187308785948241 e18 shares
[_] 20.0 ether -> 3.145504633107938886 e18 shares
[_] 21.0 ether -> 3.167173502095832986 e18 shares
[_] 22.0 ether -> 3.187114197530864192 e18 shares
[_] 23.0 ether -> 3.205525333333333332 e18 shares
[_] 24.0 ether -> 3.22257624032771961 e18 shares

The bars show the ratio of the assets staked to the total shares returned. The Scale can be changed to adjust this.

New curves can be visualized using `testVisualizeLogarithmicCurve` in the BondingCurveRegistry.t.sol test.

The Stepped Logarithmic Curve is still in development, but in it's current state is useful for scaling the logarithmic values by the desired ratio.

## Deployed Contracts

### Base Mainnet

ProxyAdmin: TBD

TimelockController (proxy admin owner): TBD

MultiVault (proxy address): TBD

Admin Safe: 0xa28d4AAcA48bE54824dA53a19b05121DE71Ef480

Trust: 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3

TrustBonding: TBD

TrustUnlockFactory: TBD

### Base Sepolia

ProxyAdmin: TBD

TimelockController (proxy admin owner): TBD

MultiVault (proxy address): TBD

Admin Safe: 0xEcAc3Da134C2e5f492B702546c8aaeD2793965BB

Trust: TBD

TrustBonding: TBD

TrustUnlockFactory: TBD
