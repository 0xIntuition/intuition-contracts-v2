# Trust

## Overview

The **Trust** contract is the native ERC20 token of the Intuition Protocol V2, serving as the base asset for all vault operations and the reward token for emissions. Originally deployed as `TrustToken` with a 1 billion token maximum supply and dual-minter model, it has been upgraded to version 2 (V2) with integrated emissions control via the `BaseEmissionsController`.

### Purpose and Role in Protocol

- **Base Vault Asset**: All deposits into atoms and triples use TRUST as the underlying asset
- **Emissions Token**: Distributed as inflationary rewards to participants who lock TRUST in TrustBonding
- **Protocol Currency**: The universal medium of exchange within the Intuition ecosystem
- **Governance Potential**: Can be locked to obtain veTRUST (vote-escrowed TRUST) for governance weight

### Key Responsibilities

1. **Token Minting**: Controlled minting through BaseEmissionsController for epoch-based emissions
2. **Token Burning**: Allows users to burn their own tokens and enables admin-controlled burning
3. **Supply Management**: Maintains fixed maximum supply (1 billion tokens) with inflationary emissions
4. **Access Control**: Role-based permissions for admin operations and minting authority

## Contract Information

- **Location**: `src/Trust.sol`
- **Inherits**:
  - `ITrust` (interface)
  - `TrustToken` (legacy ERC20 implementation)
  - `AccessControlUpgradeable` (OpenZeppelin role-based access control)
- **Interface**: `ITrust` (`src/interfaces/ITrust.sol`)
- **Upgradeable**: Yes (UUPS proxy pattern)

### Network Deployments

#### Base Mainnet
- **Address**: [`0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3`](https://basescan.org/address/0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3)
- **ProxyAdmin**: `0x857552ab95E6cC389b977d5fEf971DEde8683e8e`

#### Base Sepolia (Testnet)
- **Address**: [`0xA54b4E6e356b963Ee00d1C947f478d9194a1a210`](https://sepolia.basescan.org/address/0xA54b4E6e356b963Ee00d1C947f478d9194a1a210)
- **Note**: This is TestTrust, a testnet-specific version

## Key Concepts

### Token Economics

**Maximum Supply**: 1,000,000,000 TRUST (1 billion tokens)

```solidity
uint256 public constant MAX_SUPPLY = 1e9 * 1e18; // 1 billion tokens with 18 decimals
```

**Supply Distribution** (Legacy V1 Model):
- **Minter A** (49%): `0xBc01aB3839bE8933f6B93163d129a823684f4CDF` - 490 million TRUST cap
- **Minter B** (51%): `0xA4Df56842887cF52C9ad59C97Ec0C058e96Af533` - 510 million TRUST cap

**V2 Minting Model**:
- All new minting controlled exclusively by `BaseEmissionsController`
- Epoch-based inflationary emissions with periodic reduction
- No individual minter caps - controlled by emissions schedule

### Migration from V1 to V2

The Trust contract underwent a significant upgrade:

**V1 (Legacy TrustToken)**:
- Dual minter system with hardcoded addresses
- Manual minting up to per-minter caps
- No emissions automation

**V2 (Current Trust)**:
- Single authorized minter: BaseEmissionsController
- Automated epoch-based emissions
- Access control via OpenZeppelin roles
- Integrated with cross-chain emissions infrastructure

**Reinitializer Version**: `2` (uses OpenZeppelin's `reinitializer(2)` for upgrade)

### Access Control

The contract uses OpenZeppelin's `AccessControlUpgradeable` with two key roles:

**`DEFAULT_ADMIN_ROLE`** (`bytes32(0)`):
- Update BaseEmissionsController address
- Grant/revoke roles
- Ultimate protocol control

**BaseEmissionsController** (custom modifier):
- Exclusive minting authority
- Called automatically by emissions controller during epoch transitions

## State Variables

### V2 State

```solidity
address public baseEmissionsController;
```
The address of the BaseEmissionsController contract that has exclusive minting authority.

### Legacy V1 State (Inherited from TrustToken)

```solidity
uint256 public constant MAX_SUPPLY = 1e9 * 1e18;
address public constant MINTER_A = 0xBc01aB3839bE8933f6B93163d129a823684f4CDF;
address public constant MINTER_B = 0xA4Df56842887cF52C9ad59C97Ec0C058e96Af533;
uint256 public totalMinted;
mapping(address => uint256) public minterAmountMinted;
```

**Note**: Legacy minter addresses are immutable constants but no longer have minting authority in V2.

### Storage Gap

```solidity
uint256[50] private __gap;
```
Reserved storage slots for future upgrades (50 slots = 1600 bytes).

## Functions

### ERC20 Standard Functions

As an ERC20 token, Trust implements all standard functions:

- `balanceOf(address account) → uint256`
- `transfer(address to, uint256 amount) → bool`
- `transferFrom(address from, address to, uint256 amount) → bool`
- `approve(address spender, uint256 amount) → bool`
- `allowance(address owner, address spender) → uint256`
- `totalSupply() → uint256`

### Token Metadata

#### `name`
```solidity
function name() public view virtual override returns (string memory)
```
Returns the name of the token.

**Returns**: `"Intuition"` (note: not "TRUST" or "Trust Token")

**Override**: Overrides ERC20Upgradeable's default implementation

---

#### `symbol`
```solidity
function symbol() public view returns (string memory)
```
Returns the token symbol.

**Returns**: `"TRUST"` (inherited from TrustToken)

---

#### `decimals`
```solidity
function decimals() public view returns (uint8)
```
Returns the number of decimals used for token amounts.

**Returns**: `18` (standard ERC20 decimals)

---

### Minting Functions

#### `mint`
```solidity
function mint(address to, uint256 amount) public override(ITrust, TrustToken) onlyBaseEmissionsController
```
Mints new TRUST tokens to a specified address.

**Parameters**:
- `to`: Address to receive the minted tokens
- `amount`: Amount of tokens to mint (in wei, 18 decimals)

**Access**: `onlyBaseEmissionsController` modifier

**Emits**: `Transfer(address(0), to, amount)` (standard ERC20 mint event)

**Requirements**:
- Caller must be the BaseEmissionsController contract
- Total supply after minting must not exceed MAX_SUPPLY

**Reverts**:
- `Trust_OnlyBaseEmissionsController` if called by non-controller address

---

### Burning Functions

#### `burn`
```solidity
function burn(uint256 amount) external
```
Burns TRUST tokens from the caller's balance.

**Parameters**:
- `amount`: Amount of tokens to burn (in wei, 18 decimals)

**Emits**: `Transfer(msg.sender, address(0), amount)` (standard ERC20 burn event)

**Requirements**:
- Caller must have sufficient balance to burn

**Reverts**:
- ERC20's `InsufficientBalance` if caller doesn't have enough tokens

**Use Cases**:
- Users voluntarily reducing circulating supply
- BaseEmissionsController burning unclaimed emissions
- Deflationary mechanisms

---

### Admin Functions

#### `setBaseEmissionsController`
```solidity
function setBaseEmissionsController(address newBaseEmissionsController) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Updates the BaseEmissionsController address that has minting authority.

**Parameters**:
- `newBaseEmissionsController`: New BaseEmissionsController contract address

**Emits**: `BaseEmissionsControllerSet(newBaseEmissionsController)`

**Access**: `DEFAULT_ADMIN_ROLE`

**Requirements**:
- `newBaseEmissionsController` must not be zero address

**Reverts**:
- `Trust_ZeroAddress` if provided address is zero

**Critical**: This function changes the exclusive minting authority. Use with extreme caution.

---

### Initializer

#### `reinitialize`
```solidity
function reinitialize(address _admin, address _baseEmissionsController) external reinitializer(2)
```
Reinitializes the Trust contract for V2 upgrade with AccessControl.

**Parameters**:
- `_admin`: Admin address (receives DEFAULT_ADMIN_ROLE)
- `_baseEmissionsController`: BaseEmissionsController address

**Effects**:
- Initializes OpenZeppelin AccessControl
- Grants DEFAULT_ADMIN_ROLE to admin
- Sets BaseEmissionsController

**Requirements**:
- Can only be called once during V1 → V2 upgrade
- Neither address can be zero

**Reverts**:
- `Trust_ZeroAddress` if either address is zero
- Initializer error if called more than once

---

## Events

### `BaseEmissionsControllerSet`
```solidity
event BaseEmissionsControllerSet(address indexed newBaseEmissionsController)
```
Emitted when the BaseEmissionsController address is updated.

**Parameters**:
- `newBaseEmissionsController`: New controller address

**Use Cases**:
- Monitor minting authority changes
- Track protocol upgrades
- Verify controller configuration

---

### Standard ERC20 Events

#### `Transfer`
```solidity
event Transfer(address indexed from, address indexed to, uint256 value)
```
Emitted on all token transfers, mints, and burns.

**Mint**: `from = address(0)`
**Burn**: `to = address(0)`
**Transfer**: Both addresses non-zero

---

#### `Approval`
```solidity
event Approval(address indexed owner, address indexed spender, uint256 value)
```
Emitted when allowance is set via `approve()`.

---

## Errors

### `Trust_ZeroAddress`
Thrown when attempting to set a zero address where a valid address is required.

**Contexts**:
- Setting BaseEmissionsController
- Reinitializer admin address

**Recovery**: Provide a valid non-zero address

---

### `Trust_OnlyBaseEmissionsController`
Thrown when a non-controller address attempts to mint tokens.

**Recovery**: Only the BaseEmissionsController can call `mint()`

---

## Access Control

### Roles

**`DEFAULT_ADMIN_ROLE`** (`bytes32(0)`):
- Can update BaseEmissionsController address
- Can grant/revoke all roles
- Typically held by protocol multisig

**Modifier: `onlyBaseEmissionsController`**:
- Not a standard role, but a custom modifier
- Checks `msg.sender == baseEmissionsController`
- Required for minting operations

### Permission Structure

```
DEFAULT_ADMIN_ROLE (Protocol Multisig)
    ├─ setBaseEmissionsController()
    └─ Standard OpenZeppelin AccessControl functions

BaseEmissionsController (Contract Address)
    └─ mint()
```

## Usage Examples

### TypeScript (ethers.js v6)

#### Checking Token Balance and Supply

```typescript
import { ethers } from 'ethers';

// Setup
const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');
const TRUST_ADDRESS = '0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3';

const trustABI = [
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function totalSupply() view returns (uint256)',
  'function balanceOf(address account) view returns (uint256)',
  'function MAX_SUPPLY() view returns (uint256)',
  'function totalMinted() view returns (uint256)',
  'function baseEmissionsController() view returns (address)'
];

const trust = new ethers.Contract(TRUST_ADDRESS, trustABI, provider);

async function getTokenInfo() {
  try {
    const [name, symbol, decimals, totalSupply, maxSupply, totalMinted, controller] =
      await Promise.all([
        trust.name(),
        trust.symbol(),
        trust.decimals(),
        trust.totalSupply(),
        trust.MAX_SUPPLY(),
        trust.totalMinted(),
        trust.baseEmissionsController()
      ]);

    console.log('Token Information:');
    console.log('Name:', name);
    console.log('Symbol:', symbol);
    console.log('Decimals:', decimals);
    console.log('Total Supply:', ethers.formatEther(totalSupply), 'TRUST');
    console.log('Max Supply:', ethers.formatEther(maxSupply), 'TRUST');
    console.log('Total Minted:', ethers.formatEther(totalMinted), 'TRUST');
    console.log('Supply Utilization:', (Number(totalSupply) / Number(maxSupply) * 100).toFixed(2), '%');
    console.log('BaseEmissionsController:', controller);

    return {
      name,
      symbol,
      decimals,
      totalSupply,
      maxSupply,
      totalMinted,
      controller
    };
  } catch (error) {
    console.error('Error:', error);
    throw error;
  }
}

// Get user balance
async function getUserBalance(userAddress: string) {
  try {
    const balance = await trust.balanceOf(userAddress);
    console.log(`Balance for ${userAddress}:`, ethers.formatEther(balance), 'TRUST');
    return balance;
  } catch (error) {
    console.error('Error:', error);
    throw error;
  }
}

// Run
getTokenInfo();
getUserBalance('0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb');
```

#### Transferring TRUST Tokens

```typescript
import { ethers } from 'ethers';

// Setup with signer
const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');
const signer = new ethers.Wallet('YOUR_PRIVATE_KEY', provider);

const TRUST_ADDRESS = '0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3';
const trustABI = [
  'function transfer(address to, uint256 amount) returns (bool)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function transferFrom(address from, address to, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function balanceOf(address account) view returns (uint256)'
];

const trust = new ethers.Contract(TRUST_ADDRESS, trustABI, signer);

async function transferTrust(recipientAddress: string, amount: bigint) {
  try {
    // Check balance
    const balance = await trust.balanceOf(signer.address);
    console.log('Sender balance:', ethers.formatEther(balance), 'TRUST');

    if (balance < amount) {
      throw new Error('Insufficient balance');
    }

    // Transfer
    console.log('Transferring', ethers.formatEther(amount), 'TRUST to', recipientAddress);
    const tx = await trust.transfer(recipientAddress, amount);
    console.log('Transaction hash:', tx.hash);

    const receipt = await tx.wait();
    console.log('Transfer successful!');
    console.log('Gas used:', receipt.gasUsed.toString());

    // Check new balances
    const newBalance = await trust.balanceOf(signer.address);
    const recipientBalance = await trust.balanceOf(recipientAddress);

    console.log('New sender balance:', ethers.formatEther(newBalance), 'TRUST');
    console.log('Recipient balance:', ethers.formatEther(recipientBalance), 'TRUST');

    return receipt;
  } catch (error) {
    console.error('Transfer error:', error);
    throw error;
  }
}

// Transfer 100 TRUST
const transferAmount = ethers.parseEther('100');
transferTrust('0xRecipientAddress...', transferAmount);
```

#### Burning TRUST Tokens

```typescript
async function burnTrust(amount: bigint) {
  try {
    const trustABI = [
      'function burn(uint256 amount)',
      'function balanceOf(address account) view returns (uint256)',
      'function totalSupply() view returns (uint256)'
    ];

    const trust = new ethers.Contract(TRUST_ADDRESS, trustABI, signer);

    // Check current state
    const balanceBefore = await trust.balanceOf(signer.address);
    const supplyBefore = await trust.totalSupply();

    console.log('Balance before:', ethers.formatEther(balanceBefore), 'TRUST');
    console.log('Total supply before:', ethers.formatEther(supplyBefore), 'TRUST');

    if (balanceBefore < amount) {
      throw new Error('Insufficient balance to burn');
    }

    // Burn tokens
    console.log('Burning', ethers.formatEther(amount), 'TRUST...');
    const tx = await trust.burn(amount);
    console.log('Transaction hash:', tx.hash);

    const receipt = await tx.wait();
    console.log('Burn successful!');
    console.log('Gas used:', receipt.gasUsed.toString());

    // Check new state
    const balanceAfter = await trust.balanceOf(signer.address);
    const supplyAfter = await trust.totalSupply();

    console.log('Balance after:', ethers.formatEther(balanceAfter), 'TRUST');
    console.log('Total supply after:', ethers.formatEther(supplyAfter), 'TRUST');
    console.log('Tokens burned:', ethers.formatEther(amount), 'TRUST');

    return receipt;
  } catch (error) {
    console.error('Burn error:', error);
    throw error;
  }
}

// Burn 10 TRUST
const burnAmount = ethers.parseEther('10');
burnTrust(burnAmount);
```

### Python (web3.py)

```python
from web3 import Web3
from typing import Dict, Any
import json

# Setup
w3 = Web3(Web3.HTTPProvider('https://mainnet.base.org'))
TRUST_ADDRESS = '0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3'

# Load ABI
with open('Trust.json') as f:
    trust_abi = json.load(f)['abi']

trust = w3.eth.contract(address=TRUST_ADDRESS, abi=trust_abi)

def get_token_info() -> Dict[str, Any]:
    """Get comprehensive token information"""
    try:
        name = trust.functions.name().call()
        symbol = trust.functions.symbol().call()
        decimals = trust.functions.decimals().call()
        total_supply = trust.functions.totalSupply().call()
        max_supply = trust.functions.MAX_SUPPLY().call()
        controller = trust.functions.baseEmissionsController().call()

        info = {
            'name': name,
            'symbol': symbol,
            'decimals': decimals,
            'total_supply': w3.from_wei(total_supply, 'ether'),
            'max_supply': w3.from_wei(max_supply, 'ether'),
            'supply_utilization': (total_supply / max_supply) * 100,
            'controller': controller
        }

        print(f'Token: {info["name"]} ({info["symbol"]})')
        print(f'Total Supply: {info["total_supply"]} TRUST')
        print(f'Max Supply: {info["max_supply"]} TRUST')
        print(f'Supply Utilization: {info["supply_utilization"]:.2f}%')
        print(f'BaseEmissionsController: {info["controller"]}')

        return info
    except Exception as e:
        print(f'Error: {e}')
        raise

def transfer_trust(from_account, to_address: str, amount: int):
    """Transfer TRUST tokens"""
    try:
        # Check balance
        balance = trust.functions.balanceOf(from_account.address).call()
        print(f'Balance: {w3.from_wei(balance, "ether")} TRUST')

        if balance < amount:
            raise ValueError('Insufficient balance')

        # Build transaction
        tx = trust.functions.transfer(to_address, amount).build_transaction({
            'from': from_account.address,
            'nonce': w3.eth.get_transaction_count(from_account.address),
            'gas': 100000,
            'gasPrice': w3.eth.gas_price
        })

        # Sign and send
        signed_tx = from_account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

        print(f'Transfer successful!')
        print(f'Transaction hash: {tx_hash.hex()}')
        print(f'Gas used: {receipt["gasUsed"]}')

        return receipt
    except Exception as e:
        print(f'Error: {e}')
        raise

def burn_trust(from_account, amount: int):
    """Burn TRUST tokens"""
    try:
        # Check balance
        balance = trust.functions.balanceOf(from_account.address).call()
        supply_before = trust.functions.totalSupply().call()

        print(f'Balance before: {w3.from_wei(balance, "ether")} TRUST')
        print(f'Supply before: {w3.from_wei(supply_before, "ether")} TRUST')

        if balance < amount:
            raise ValueError('Insufficient balance to burn')

        # Build transaction
        tx = trust.functions.burn(amount).build_transaction({
            'from': from_account.address,
            'nonce': w3.eth.get_transaction_count(from_account.address),
            'gas': 100000,
            'gasPrice': w3.eth.gas_price
        })

        # Sign and send
        signed_tx = from_account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

        # Check new state
        supply_after = trust.functions.totalSupply().call()

        print(f'Burn successful!')
        print(f'Transaction hash: {tx_hash.hex()}')
        print(f'Supply after: {w3.from_wei(supply_after, "ether")} TRUST')
        print(f'Tokens burned: {w3.from_wei(amount, "ether")} TRUST')

        return receipt
    except Exception as e:
        print(f'Error: {e}')
        raise

# Example usage
if __name__ == '__main__':
    get_token_info()
```

### Solidity

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TrustTokenIntegration
 * @notice Example contract showing how to integrate with TRUST token
 */
contract TrustTokenIntegration {
    IERC20 public immutable trust;

    event TrustReceived(address indexed from, uint256 amount);
    event TrustSent(address indexed to, uint256 amount);

    constructor(address _trust) {
        trust = IERC20(_trust);
    }

    /**
     * @notice Receive TRUST tokens from user
     * @param amount Amount of TRUST to receive
     */
    function receiveTrust(uint256 amount) external {
        require(amount > 0, "Amount must be positive");

        // Transfer TRUST from user to this contract
        bool success = trust.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        emit TrustReceived(msg.sender, amount);
    }

    /**
     * @notice Send TRUST tokens to user
     * @param to Recipient address
     * @param amount Amount of TRUST to send
     */
    function sendTrust(address to, uint256 amount) external {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be positive");
        require(trust.balanceOf(address(this)) >= amount, "Insufficient balance");

        // Transfer TRUST to recipient
        bool success = trust.transfer(to, amount);
        require(success, "Transfer failed");

        emit TrustSent(to, amount);
    }

    /**
     * @notice Get contract's TRUST balance
     * @return balance The TRUST balance of this contract
     */
    function getTrustBalance() external view returns (uint256 balance) {
        return trust.balanceOf(address(this));
    }

    /**
     * @notice Check if user has approved this contract to spend TRUST
     * @param user User address to check
     * @return allowance The amount this contract can spend on behalf of user
     */
    function checkAllowance(address user) external view returns (uint256 allowance) {
        return trust.allowance(user, address(this));
    }
}
```

## Integration Notes

### For SDK Builders

1. **Standard ERC20 Integration**: TRUST follows the ERC20 standard - use standard ERC20 SDK patterns
2. **Approval Pattern**: Always approve before transfers in smart contracts
3. **Decimal Handling**: Use 18 decimals for all amount calculations
4. **Supply Monitoring**: Track total supply vs max supply for circulating supply metrics
5. **Cross-Chain**: TRUST on Base is the canonical version; other chains may have wrapped versions

### Common Patterns

#### Checking Approval Before Operations

```typescript
// Check current allowance
const allowance = await trust.allowance(userAddress, spenderAddress);

if (allowance < requiredAmount) {
  // Request approval
  const approveTx = await trust.approve(spenderAddress, requiredAmount);
  await approveTx.wait();
}

// Now proceed with operation that requires approval
```

#### Supply Utilization Tracking

```typescript
const totalSupply = await trust.totalSupply();
const maxSupply = await trust.MAX_SUPPLY();
const circulatingPercentage = (Number(totalSupply) / Number(maxSupply)) * 100;

console.log(`${circulatingPercentage.toFixed(2)}% of max supply is in circulation`);
```

### Edge Cases

1. **Legacy Minters**: V1 minter addresses (MINTER_A, MINTER_B) are still in contract but have no permissions in V2
2. **Max Supply**: Contract enforces MAX_SUPPLY - minting will revert if total supply would exceed 1 billion
3. **Burn Mechanics**: Anyone can burn their own tokens, reducing circulating supply
4. **Controller Changes**: Admin can update BaseEmissionsController - monitor `BaseEmissionsControllerSet` events

## Gas Considerations

### Approximate Gas Costs

| Operation | Estimated Gas | Notes |
|-----------|--------------|-------|
| `transfer` | ~65,000 | Standard ERC20 transfer |
| `approve` | ~46,000 | Set approval allowance |
| `transferFrom` | ~70,000 | Transfer with approval |
| `burn` | ~55,000 | Burn own tokens |
| `mint` (controller only) | ~55,000 | Mint new tokens |
| Balance/supply queries | ~3,000 | View functions (free externally) |

### Optimization Tips

1. **Infinite Approvals**: Consider approving `type(uint256).max` for frequently used spenders to save gas
2. **Batch Operations**: Use multicall patterns for multiple transfers/approvals
3. **View Function Calls**: All read operations are free when called externally
4. **Off-Chain Balance Tracking**: Cache balances and subscribe to Transfer events for real-time updates

## Related Contracts

### Core Dependencies

- **[BaseEmissionsController](../emissions/BaseEmissionsController.md)**: Has exclusive minting authority
- **[MultiVault](./MultiVault.md)**: Uses TRUST as base asset for all vaults
- **[WrappedTrust](../WrappedTrust.md)**: Wrapped version on Intuition chain (native token)

### Supporting Contracts

- **[TrustBonding](../emissions/TrustBonding.md)**: Users lock TRUST to earn emissions
- **[SatelliteEmissionsController](../emissions/SatelliteEmissionsController.md)**: Receives TRUST for distribution on satellite chain

### Token Flow

```
BaseEmissionsController (Base Chain)
    ↓ (mints TRUST)
Trust Token Contract
    ↓ (bridges to)
SatelliteEmissionsController (Intuition Chain)
    ↓ (distributes to)
TrustBonding Contract
    ↓ (users claim)
Users → MultiVault (deposit into vaults)
```

## See Also

### Concept Documentation
- [Emissions System](../../concepts/emissions-system.md) - How TRUST emissions work
- [Bonding Curves](../../concepts/bonding-curves.md) - TRUST pricing in vaults

### Integration Guides
- [Depositing Assets](../../guides/depositing-assets.md) - Using TRUST in vaults
- [Claiming Rewards](../../guides/claiming-rewards.md) - Earning TRUST emissions

### API Reference
- [Events Reference](../../reference/events.md) - All TRUST events
- [ERC20 Standard](https://eips.ethereum.org/EIPS/eip-20) - Official ERC20 specification

---

**Last Updated**: December 2025
**Version**: V2.0
