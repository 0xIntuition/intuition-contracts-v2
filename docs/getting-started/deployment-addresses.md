# Deployment Addresses

Complete list of deployed Intuition Protocol V2 contracts across all networks.

## Mainnet Deployments

### Base Mainnet

Base Mainnet hosts the base-layer contracts responsible for TRUST token minting and emissions control.

| Contract Name | Address | ProxyAdmin | Explorer |
|---------------|---------|------------|----------|
| Trust | `0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3` | `0x857552ab95E6cC389b977d5fEf971DEde8683e8e` | [View](https://basescan.org/address/0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3) |
| Upgrades TimelockController | `0x1E442BbB08c98100b18fa830a88E8A57b5dF9157` | / | [View](https://basescan.org/address/0x1E442BbB08c98100b18fa830a88E8A57b5dF9157) |
| BaseEmissionsController | `0x7745bDEe668501E5eeF7e9605C746f9cDfb60667` | `0x58dCdf3b6F5D03835CF6556EdC798bfd690B251a` | [View](https://basescan.org/address/0x7745bDEe668501E5eeF7e9605C746f9cDfb60667) |
| EmissionsAutomationAdapter | `0xb1ce9Ac324B5C3928736Ec33b5Fd741cb04a2F2d` | / | [View](https://basescan.org/address/0xb1ce9Ac324B5C3928736Ec33b5Fd741cb04a2F2d) |

#### Integration Points
- **RPC Endpoint**: `https://mainnet.base.org`
- **Chain ID**: `8453`
- **Native Token**: ETH

---

### Intuition Mainnet

Intuition Mainnet hosts the core protocol contracts for vault operations, emissions distribution, and atom wallets.

| Contract Name | Address | ProxyAdmin | Explorer |
|---------------|---------|------------|----------|
| WrappedTrust | `0x81cFb09cb44f7184Ad934C09F82000701A4bF672` | / | [View](https://explorer.intuit.network/address/0x81cFb09cb44f7184Ad934C09F82000701A4bF672) |
| Upgrades TimelockController | `0x321e5d4b20158648dFd1f360A79CAFc97190bAd1` | / | [View](https://explorer.intuit.network/address/0x321e5d4b20158648dFd1f360A79CAFc97190bAd1) |
| Parameters TimelockController | `0x71b0F1ABebC2DaA0b7B5C3f9b72FAa1cd9F35FEA` | / | [View](https://explorer.intuit.network/address/0x71b0F1ABebC2DaA0b7B5C3f9b72FAa1cd9F35FEA) |
| MultiVault | `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e` | `0x1999faD6477e4fa9aA0FF20DaafC32F7B90005C8` | [View](https://explorer.intuit.network/address/0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e) |
| AtomWalletFactory | `0x33827373a7D1c7C78a01094071C2f6CE74253B9B` | `0x68667f67986650B8C86A87612c556dc0dC07F9a7` | [View](https://explorer.intuit.network/address/0x33827373a7D1c7C78a01094071C2f6CE74253B9B) |
| AtomWalletBeacon | `0xC23cD55CF924b3FE4b97deAA0EAF222a5082A1FF` | / | [View](https://explorer.intuit.network/address/0xC23cD55CF924b3FE4b97deAA0EAF222a5082A1FF) |
| AtomWarden | `0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165` | `0xf548dbDd7a18Ee9d91106b3b6967770b504aeE2A` | [View](https://explorer.intuit.network/address/0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165) |
| SatelliteEmissionsController | `0x73B8819f9b157BE42172E3866fB0Ba0d5fA0A5c6` | `0xdF60D18E86F3454309aD7734055843F7ee5f30a3` | [View](https://explorer.intuit.network/address/0x73B8819f9b157BE42172E3866fB0Ba0d5fA0A5c6) |
| TrustBonding | `0x635bBD1367B66E7B16a21D6E5A63C812fFC00617` | `0xF10FEE90B3C633c4fCd49aA557Ec7d51E5AEef62` | [View](https://explorer.intuit.network/address/0x635bBD1367B66E7B16a21D6E5A63C812fFC00617) |
| BondingCurveRegistry | `0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930` | `0x678c7D3d759611b554A1293295007f2b202C2302` | [View](https://explorer.intuit.network/address/0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930) |
| LinearCurve | `0xc3eFD5471dc63d74639725f381f9686e3F264366` | `0x6365D6eD0caf54d6290D866d56C043d3fCDc3B8c` | [View](https://explorer.intuit.network/address/0xc3eFD5471dc63d74639725f381f9686e3F264366) |
| OffsetProgressiveCurve | `0x23afF95153aa88D28B9B97Ba97629E05D5fD335d` | `0xe58B117aDfB0a141dC1CC22b98297294F6E2c5E7` | [View](https://explorer.intuit.network/address/0x23afF95153aa88D28B9B97Ba97629E05D5fD335d) |
| Multicall3 | `0xcA11bde05977b3631167028862bE2a173976CA11` | / | [View](https://explorer.intuit.network/address/0xcA11bde05977b3631167028862bE2a173976CA11) |
| EntryPoint | `0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108` | / | [View](https://explorer.intuit.network/address/0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108) |
| SafeSingletonFactory | `0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7` | / | [View](https://explorer.intuit.network/address/0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7) |

#### Integration Points
- **RPC Endpoint**: [Contact team for RPC]
- **Chain ID**: [Check explorer]
- **Native Token**: ETH

---

## Testnet Deployments

### Base Sepolia

Base Sepolia hosts the testnet version of base-layer contracts for testing emissions and token minting.

| Contract Name | Address | ProxyAdmin | Explorer |
|---------------|---------|------------|----------|
| TestTrust | `0xA54b4E6e356b963Ee00d1C947f478d9194a1a210` | / | [View](https://sepolia.basescan.org/address/0xA54b4E6e356b963Ee00d1C947f478d9194a1a210) |
| Upgrades TimelockController | `0x9099BC9fd63B01F94528B60CEEB336C679eb6d52` | / | [View](https://sepolia.basescan.org/address/0x9099BC9fd63B01F94528B60CEEB336C679eb6d52) |
| BaseEmissionsController | `0xC14773Aae24aA60CB8F261995405C28f6D742DCf` | `0x0b954b1CbAAf8972845BC5D31a8B748f0F8849fc` | [View](https://sepolia.basescan.org/address/0xC14773Aae24aA60CB8F261995405C28f6D742DCf) |

#### Integration Points
- **RPC Endpoint**: `https://sepolia.base.org`
- **Chain ID**: `84532`
- **Native Token**: ETH
- **Faucet**: [Base Sepolia Faucet](https://www.coinbase.com/faucets/base-ethereum-goerli-faucet)

---

### Intuition Testnet

Intuition Testnet hosts the full protocol for testing all features before mainnet deployment.

| Contract Name | Address | ProxyAdmin | Explorer |
|---------------|---------|------------|----------|
| WrappedTrust | `0xDE80b6EE63f7D809427CA350e30093F436A0fe35` | / | [View](https://explorer.testnet.intuit.network/address/0xDE80b6EE63f7D809427CA350e30093F436A0fe35) |
| Upgrades TimelockController | `0x59B7EaB1cFA47F8E61606aDf79a6b7B5bBF1aF26` | / | [View](https://explorer.testnet.intuit.network/address/0x59B7EaB1cFA47F8E61606aDf79a6b7B5bBF1aF26) |
| Parameters TimelockController | `0xcCB113bfFf493d80F32Fb799Dca23686a04302A7` | / | [View](https://explorer.testnet.intuit.network/address/0xcCB113bfFf493d80F32Fb799Dca23686a04302A7) |
| MultiVault | `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91` | `0x840d79645824C43227573305BBFCd162504BBB6e` | [View](https://explorer.testnet.intuit.network/address/0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91) |
| AtomWalletFactory | `0xa4e96c6dB8Dd3314c64bF9d0E845A4905a8705d4` | `0x83e13aD14714236b5d9eca851FE6561Cfc9220c9` | [View](https://explorer.testnet.intuit.network/address/0xa4e96c6dB8Dd3314c64bF9d0E845A4905a8705d4) |
| AtomWalletBeacon | `0x4B0aC884843576dBA0B0fda925f202aB8b546E33` | / | [View](https://explorer.testnet.intuit.network/address/0x4B0aC884843576dBA0B0fda925f202aB8b546E33) |
| AtomWarden | `0x040B7760EFDEd7e933CFf419224b57DFB9Eb4488` | `0xabBf8147d33e76251383A81c81189077C505B51A` | [View](https://explorer.testnet.intuit.network/address/0x040B7760EFDEd7e933CFf419224b57DFB9Eb4488) |
| SatelliteEmissionsController | `0xD3be4d1E56866b98f30Ae6C326F14EF9c6ffBBDF` | `0x5ec513714f57f7b984875719Bd8Ef00d05487524` | [View](https://explorer.testnet.intuit.network/address/0xD3be4d1E56866b98f30Ae6C326F14EF9c6ffBBDF) |
| TrustBonding | `0x75dD32b522c89566265eA32ecb50b4Fc4d00ADc7` | `0x214D3833114e25262bb8e4E9B5A99F062bFb93D4` | [View](https://explorer.testnet.intuit.network/address/0x75dD32b522c89566265eA32ecb50b4Fc4d00ADc7) |
| BondingCurveRegistry | `0x2AFC4949Dd3664219AA2c20133771658E93892A1` | `0x0C5AeAba37b1E92064f0af684D65476d24F52a9A` | [View](https://explorer.testnet.intuit.network/address/0x2AFC4949Dd3664219AA2c20133771658E93892A1) |
| LinearCurve | `0x6df5eecd9B14E31C98A027b8634876E4805F71B0` | `0x34D65193EE2e1449FE6CB8eca1EE046FcC21669e` | [View](https://explorer.testnet.intuit.network/address/0x6df5eecd9B14E31C98A027b8634876E4805F71B0) |
| OffsetProgressiveCurve | `0xE65EcaAF5964aC0d94459A66A59A8B9eBCE42CbB` | `0x6A65336598d4783d0673DD238418248909C71F26` | [View](https://explorer.testnet.intuit.network/address/0xE65EcaAF5964aC0d94459A66A59A8B9eBCE42CbB) |
| Multicall3 | `0xcA11bde05977b3631167028862bE2a173976CA11` | / | [View](https://explorer.testnet.intuit.network/address/0xcA11bde05977b3631167028862bE2a173976CA11) |
| EntryPoint | `0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108` | / | [View](https://explorer.testnet.intuit.network/address/0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108) |

#### Integration Points
- **RPC Endpoint**: [Contact team for RPC]
- **Chain ID**: [Check explorer]
- **Native Token**: ETH
- **Faucet**: [Contact team for testnet tokens]

---

## Usage Examples

### TypeScript (viem)

```typescript
import { createPublicClient, http } from 'viem';
import { base } from 'viem/chains';

// Base Mainnet
const basePublicClient = createPublicClient({
  chain: base,
  transport: http('https://mainnet.base.org')
});
const trustAddress = '0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3';

// Read from Trust contract
const trustData = await basePublicClient.readContract({
  address: trustAddress,
  abi: TRUST_ABI,
  functionName: 'balanceOf',
  args: [userAddress]
});

// Intuition Mainnet (custom chain)
const intuitionPublicClient = createPublicClient({
  transport: http('YOUR_INTUITION_RPC')
});
const multiVaultAddress = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';

// Read from MultiVault contract
const vaultData = await intuitionPublicClient.readContract({
  address: multiVaultAddress,
  abi: MULTIVAULT_ABI,
  functionName: 'getVault',
  args: [termId, curveId]
});
```

### Python (web3.py)

```python
from web3 import Web3

# Base Mainnet
base_w3 = Web3(Web3.HTTPProvider('https://mainnet.base.org'))
trust_address = '0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3'
trust_contract = base_w3.eth.contract(address=trust_address, abi=TRUST_ABI)

# Intuition Mainnet
intuition_w3 = Web3(Web3.HTTPProvider('YOUR_INTUITION_RPC'))
multivault_address = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e'
multivault = intuition_w3.eth.contract(address=multivault_address, abi=MULTIVAULT_ABI)
```

### Solidity

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IMultiVault.sol";

contract MyIntegration {
    IMultiVault public multiVault = IMultiVault(0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e);

    function createAtom(bytes calldata atomData, uint256 deposit) external {
        bytes[] memory datas = new bytes[](1);
        datas[0] = atomData;

        uint256[] memory deposits = new uint256[](1);
        deposits[0] = deposit;

        bytes32[] memory atomIds = multiVault.createAtoms(datas, deposits);
    }
}
```

---

## Contract Verification

All mainnet contracts are verified on their respective block explorers:

- **Base Mainnet**: [BaseScan](https://basescan.org)
- **Intuition Mainnet**: [Intuition Explorer](https://explorer.intuit.network)
- **Base Sepolia**: [BaseScan Sepolia](https://sepolia.basescan.org)
- **Intuition Testnet**: [Intuition Testnet Explorer](https://explorer.testnet.intuit.network)

Click the "View" links in the tables above to see verified source code.

---

## Important Notes

### Proxy Contracts
Most contracts use proxy patterns for upgradeability. Always interact with the proxy address (listed in the tables above), not the implementation address.

### ProxyAdmin
ProxyAdmin contracts control upgrades. Only timelock controllers can execute upgrades through ProxyAdmin.

### Multicall3 & EntryPoint
These are canonical contracts with the same address across all EVM chains:
- **Multicall3**: `0xcA11bde05977b3631167028862bE2a173976CA11`
- **EntryPoint**: `0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108`

### Getting ABIs
ABIs for all contracts are available in the [reference/abi](../reference/abi/) directory or can be fetched from verified contracts on block explorers.

---

## Network Specifications

### Base Mainnet
- **Network Name**: Base
- **Chain ID**: 8453
- **Currency**: ETH
- **Block Explorer**: https://basescan.org
- **RPC**: https://mainnet.base.org

### Intuition Mainnet
- **Network Name**: Intuition
- **Chain ID**: [TBD]
- **Currency**: ETH
- **Block Explorer**: https://explorer.intuit.network
- **RPC**: [Contact team]

### Base Sepolia
- **Network Name**: Base Sepolia
- **Chain ID**: 84532
- **Currency**: ETH
- **Block Explorer**: https://sepolia.basescan.org
- **RPC**: https://sepolia.base.org

### Intuition Testnet
- **Network Name**: Intuition Testnet
- **Chain ID**: [TBD]
- **Currency**: ETH
- **Block Explorer**: https://explorer.testnet.intuit.network
- **RPC**: [Contact team]

---

## Changelog

### V2.0 (Current)
- Initial V2 deployment with multi-vault architecture
- Cross-chain emissions via MetaERC20
- ERC-4337 atom wallets
- Utilization-based rewards

---

**See Also**:
- [Protocol Overview](./overview.md)
- [Quick Start Guide](./quickstart-abi.md)
- [Contract Reference](../contracts/)

**Last Updated**: December 2025
