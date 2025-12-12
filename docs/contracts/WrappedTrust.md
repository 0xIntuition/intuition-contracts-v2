# WrappedTrust

## Overview

The **WrappedTrust** contract is a wrapped version of the native ETH token on the Intuition Protocol's native chain, implementing the canonical WETH (Wrapped Ether) pattern. It enables users to convert native ETH into an ERC20-compliant token (WTRUST) for use in DeFi applications, smart contracts, and protocols that require ERC20 token standards.

### Purpose and Role in Protocol

- **DeFi Compatibility**: Enables ETH to be used in protocols that exclusively support ERC20 tokens
- **Smart Contract Integration**: Allows ETH to be easily integrated into complex smart contract interactions
- **Liquidity Provision**: Facilitates the creation of liquidity pools with native ETH wrapped as WTRUST
- **Standardized Interface**: Provides a consistent ERC20 interface for native ETH transactions

### Key Responsibilities

1. **Wrapping Native ETH**: Accept ETH deposits and mint equivalent WTRUST tokens
2. **Unwrapping to ETH**: Burn WTRUST tokens and return equivalent ETH to users
3. **ERC20 Functionality**: Full ERC20 token implementation (transfer, approve, transferFrom)
4. **1:1 Peg Maintenance**: Ensure WTRUST always maintains exact 1:1 parity with deposited ETH

## Contract Information

- **Location**: `src/WrappedTrust.sol`
- **Inherits**: None (standalone implementation)
- **Interface**: ERC20 standard (no formal interface file)
- **Upgradeable**: No (immutable contract)
- **License**: GPL-3.0 (originally from Dapphub WETH9)

### Network Deployments

#### Intuition Mainnet
- **Address**: [`0x81cFb09cb44f7184Ad934C09F82000701A4bF672`](https://explorer.intuit.network/address/0x81cFb09cb44f7184Ad934C09F82000701A4bF672)
- **Type**: Non-upgradeable
- **Network**: Intuition L2

#### Intuition Testnet
- **Address**: [`0xDE80b6EE63f7D809427CA350e30093F436A0fe35`](https://explorer.testnet.intuit.network/address/0xDE80b6EE63f7D809427CA350e30093F436A0fe35)
- **Type**: Non-upgradeable
- **Network**: Intuition L2 Testnet

## Key Concepts

### WETH Pattern

WrappedTrust implements the canonical WETH9 pattern originally developed by Dapphub. This pattern has become the industry standard for wrapping native blockchain currencies into ERC20 tokens.

**Key Characteristics**:
- **1:1 Backing**: Every WTRUST token is backed by exactly 1 wei of ETH held in the contract
- **Permissionless**: Anyone can wrap/unwrap at any time without restrictions
- **No Fees**: Wrapping and unwrapping are free (only gas costs apply)
- **Transparent**: Total supply equals contract's ETH balance

### Wrapping Mechanics

**Deposit Process**:
1. User sends ETH to the contract (via `deposit()` or `receive()`)
2. Contract increments user's WTRUST balance by the deposited amount
3. `Deposit` event is emitted
4. ETH is held in the contract as collateral

**Withdrawal Process**:
1. User calls `withdraw(amount)` with desired amount
2. Contract checks user has sufficient WTRUST balance
3. User's WTRUST balance is decremented
4. `Withdrawal` event is emitted
5. Equivalent ETH is sent back to the user

### Infinite Approval Pattern

The contract implements an optimization where `type(uint256).max` allowance is treated as infinite:

```solidity
if (from != msg.sender && allowance[from][msg.sender] != type(uint256).max) {
    require(allowance[from][msg.sender] >= amount);
    allowance[from][msg.sender] -= amount;
}
```

This means if an allowance is set to the maximum uint256 value, it will never be decremented, saving gas on subsequent transfers.

### Comparison to Standard WETH

| Feature | WrappedTrust | Standard WETH9 |
|---------|--------------|----------------|
| Wrapping Mechanism | Identical | Identical |
| ERC20 Implementation | Identical | Identical |
| Infinite Approval | Yes | Yes |
| Deposit via receive() | Yes | Yes |
| Token Name | "Wrapped TRUST" | "Wrapped Ether" |
| Token Symbol | WTRUST | WETH |
| License | GPL-3.0 | GPL-3.0 |

## State Variables

### Public Variables

#### `name`
```solidity
string public name = "Wrapped TRUST";
```
The human-readable name of the token.

---

#### `symbol`
```solidity
string public symbol = "WTRUST";
```
The token symbol/ticker used on exchanges and interfaces.

---

#### `decimals`
```solidity
uint8 public decimals = 18;
```
Number of decimal places for token amounts (matches ETH's 18 decimals).

---

### Storage Mappings

#### `balanceOf`
```solidity
mapping(address account => uint256) public balanceOf;
```
Tracks the WTRUST token balance for each address.

**Key Points**:
- Balance increases when ETH is deposited
- Balance decreases when WTRUST is withdrawn
- Balance changes via `transfer()` and `transferFrom()`

---

#### `allowance`
```solidity
mapping(address account => mapping(address spender => uint256)) public allowance;
```
Tracks approval amounts for third-party token transfers.

**Key Points**:
- Set via `approve()` function
- Consumed during `transferFrom()` calls
- Special case: `type(uint256).max` is never decremented

---

## Functions

### Deposit Functions

#### `deposit`
```solidity
function deposit() public payable
```
Converts sent ETH into WTRUST tokens credited to the caller.

**Parameters**: None (ETH amount sent via `msg.value`)

**Effects**:
- Increases caller's `balanceOf` by `msg.value`
- Emits `Deposit(msg.sender, msg.value)`

**Requirements**:
- ETH must be sent with the transaction

**Example**:
```solidity
// Send 1 ETH, receive 1 WTRUST
wrappedTrust.deposit{value: 1 ether}();
```

---

#### `receive`
```solidity
receive() external payable
```
Fallback function that automatically wraps ETH sent directly to the contract.

**Behavior**:
- Automatically calls `deposit()` when ETH is sent without data
- Enables simple ETH transfers to wrap tokens

**Example**:
```solidity
// Simple transfer wraps automatically
(bool success, ) = address(wrappedTrust).call{value: 1 ether}("");
```

---

### Withdrawal Functions

#### `withdraw`
```solidity
function withdraw(uint256 amount) public
```
Burns WTRUST tokens and returns equivalent ETH to the caller.

**Parameters**:
- `amount`: Amount of WTRUST to burn and ETH to withdraw (in wei)

**Effects**:
- Decreases caller's `balanceOf` by `amount`
- Emits `Withdrawal(msg.sender, amount)`
- Sends `amount` of ETH to caller

**Requirements**:
- Caller must have sufficient WTRUST balance

**Reverts**:
- Reverts without message if `balanceOf[msg.sender] < amount`
- May revert if ETH transfer fails (e.g., recipient reverts)

**Example**:
```solidity
// Unwrap 0.5 WTRUST to receive 0.5 ETH
wrappedTrust.withdraw(0.5 ether);
```

---

### ERC20 Standard Functions

#### `totalSupply`
```solidity
function totalSupply() public view returns (uint256)
```
Returns the total supply of WTRUST tokens.

**Returns**: Total WTRUST in circulation (equals contract's ETH balance)

**Implementation Detail**:
```solidity
return address(this).balance;
```

**Note**: This is a calculated value, not stored state. It always equals the exact amount of ETH held by the contract.

---

#### `approve`
```solidity
function approve(address spender, uint256 amount) public returns (bool)
```
Approves a spender to transfer tokens on behalf of the caller.

**Parameters**:
- `spender`: Address authorized to spend tokens
- `amount`: Maximum amount the spender can transfer

**Effects**:
- Sets `allowance[msg.sender][spender] = amount`
- Emits `Approval(msg.sender, spender, amount)`

**Returns**: Always returns `true`

**Best Practice**: Set to `0` before changing to a new non-zero value to prevent race conditions (or use `type(uint256).max` for infinite approval).

**Example**:
```solidity
// Approve DEX router to spend WTRUST
wrappedTrust.approve(routerAddress, type(uint256).max);
```

---

#### `transfer`
```solidity
function transfer(address to, uint256 amount) public returns (bool)
```
Transfers WTRUST tokens from caller to another address.

**Parameters**:
- `to`: Recipient address
- `amount`: Amount of WTRUST to transfer

**Effects**:
- Decreases `balanceOf[msg.sender]` by `amount`
- Increases `balanceOf[to]` by `amount`
- Emits `Transfer(msg.sender, to, amount)`

**Returns**: Always returns `true` (or reverts)

**Requirements**:
- Caller must have sufficient balance

**Implementation**: Internally calls `transferFrom(msg.sender, to, amount)`

---

#### `transferFrom`
```solidity
function transferFrom(address from, address to, uint256 amount) public returns (bool)
```
Transfers tokens from one address to another using the allowance mechanism.

**Parameters**:
- `from`: Address to transfer tokens from
- `to`: Recipient address
- `amount`: Amount of WTRUST to transfer

**Effects**:
- Decreases `balanceOf[from]` by `amount`
- Increases `balanceOf[to]` by `amount`
- Decreases `allowance[from][msg.sender]` by `amount` (unless allowance is `type(uint256).max`)
- Emits `Transfer(from, to, amount)`

**Returns**: Always returns `true` (or reverts)

**Requirements**:
- `from` must have sufficient balance
- If `msg.sender != from`, then `allowance[from][msg.sender]` must be sufficient (unless set to max uint256)

**Reverts**:
- Reverts without message if balance or allowance is insufficient

**Special Case**: If allowance equals `type(uint256).max`, it is not decremented (infinite approval pattern).

---

## Events

### `Deposit`
```solidity
event Deposit(address indexed account, uint256 amount);
```

**Emitted When**: ETH is wrapped into WTRUST tokens

**Parameters**:
- `account`: Address that deposited ETH and received WTRUST
- `amount`: Amount of ETH deposited (and WTRUST minted)

**Use Cases**:
- Track wrapping activity
- Monitor contract deposits
- Update UI balances in real-time

**Example Listener** (TypeScript):
```typescript
wrappedTrust.on('Deposit', (account, amount, event) => {
  console.log(`${account} wrapped ${formatEther(amount)} ETH`);
});
```

---

### `Withdrawal`
```solidity
event Withdrawal(address indexed account, uint256 amount);
```

**Emitted When**: WTRUST is unwrapped back to ETH

**Parameters**:
- `account`: Address that withdrew ETH by burning WTRUST
- `amount`: Amount of WTRUST burned (and ETH returned)

**Use Cases**:
- Track unwrapping activity
- Monitor contract withdrawals
- Update UI balances in real-time

---

### `Transfer`
```solidity
event Transfer(address indexed from, address indexed to, uint256 amount);
```

**Emitted When**:
- WTRUST tokens are transferred between addresses
- Tokens are wrapped (from = `address(0)`)
- Tokens are unwrapped (to = `address(0)`)

**Parameters**:
- `from`: Source address (or `address(0)` for minting via deposit)
- `to`: Destination address
- `amount`: Amount transferred

**Standard**: Part of ERC20 specification

---

### `Approval`
```solidity
event Approval(address indexed owner, address indexed spender, uint256 amount);
```

**Emitted When**: An approval is set via `approve()`

**Parameters**:
- `owner`: Address that owns the tokens
- `spender`: Address authorized to spend the tokens
- `amount`: Maximum amount the spender can transfer

**Standard**: Part of ERC20 specification

---

## Errors

### Implicit Reverts

WrappedTrust uses `require` statements without custom error messages. This means reverts will occur without descriptive error messages in the following cases:

#### Insufficient Balance
```solidity
require(balanceOf[msg.sender] >= amount);
```
**Occurs When**:
- Attempting to withdraw more WTRUST than owned
- Attempting to transfer more WTRUST than owned

**Recovery**: Check balance before calling `withdraw()` or `transfer()`

---

#### Insufficient Allowance
```solidity
require(allowance[from][msg.sender] >= amount);
```
**Occurs When**:
- Attempting to `transferFrom()` more than the approved allowance

**Recovery**: Request owner to increase allowance via `approve()`

---

#### ETH Transfer Failure

The contract uses OpenZeppelin's `Address.sendValue()` for ETH transfers:

```solidity
Address.sendValue(payable(msg.sender), amount);
```

**May Revert When**:
- Recipient is a contract that reverts on receive
- Recipient's fallback/receive function runs out of gas
- Recipient's fallback/receive function reverts

**Recovery**:
- If recipient is a contract, ensure it can receive ETH
- Use a regular wallet address if contract cannot receive
- Consider implementing pull-over-push pattern in recipient contract

---

## Access Control

### Permissionless Design

WrappedTrust has **no access control restrictions**. All functions are publicly callable:

- **No admin functions**: No privileged operations
- **No pause mechanism**: Cannot be stopped or frozen
- **No blacklist**: All addresses can interact freely
- **No upgrade authority**: Contract is immutable

This design maximizes decentralization and censorship resistance.

### Security Considerations

**Benefits**:
- No single point of failure from admin keys
- Transparent and predictable behavior
- Cannot be manipulated by any party

**Implications**:
- Cannot recover tokens sent to contract address
- Cannot pause in case of discovered vulnerabilities
- Cannot upgrade to fix bugs or add features

---

## Usage Examples

### TypeScript (viem)

```typescript
import { createPublicClient, createWalletClient, http, parseEther, formatEther } from 'viem';
import { intuition } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';

// Contract ABI (only the functions we need)
const wrappedTrustAbi = [
  {
    name: 'deposit',
    type: 'function',
    stateMutability: 'payable',
    inputs: [],
    outputs: []
  },
  {
    name: 'withdraw',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'amount', type: 'uint256' }],
    outputs: []
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'approve',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' }
    ],
    outputs: [{ name: '', type: 'bool' }]
  },
  {
    name: 'transfer',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'amount', type: 'uint256' }
    ],
    outputs: [{ name: '', type: 'bool' }]
  },
  {
    name: 'totalSupply',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }]
  }
] as const;

const WRAPPED_TRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672';

// Initialize clients
const publicClient = createPublicClient({
  chain: intuition,
  transport: http()
});

const account = privateKeyToAccount('0x...');
const walletClient = createWalletClient({
  account,
  chain: intuition,
  transport: http()
});

async function main() {
  try {
    // 1. Check current balance
    const balance = await publicClient.readContract({
      address: WRAPPED_TRUST_ADDRESS,
      abi: wrappedTrustAbi,
      functionName: 'balanceOf',
      args: [account.address]
    });
    console.log(`Current WTRUST balance: ${formatEther(balance)}`);

    // 2. Wrap 1 ETH into WTRUST
    console.log('Wrapping 1 ETH...');
    const depositHash = await walletClient.writeContract({
      address: WRAPPED_TRUST_ADDRESS,
      abi: wrappedTrustAbi,
      functionName: 'deposit',
      value: parseEther('1.0')
    });

    await publicClient.waitForTransactionReceipt({ hash: depositHash });
    console.log(`Wrapped 1 ETH. Transaction: ${depositHash}`);

    // 3. Check new balance
    const newBalance = await publicClient.readContract({
      address: WRAPPED_TRUST_ADDRESS,
      abi: wrappedTrustAbi,
      functionName: 'balanceOf',
      args: [account.address]
    });
    console.log(`New WTRUST balance: ${formatEther(newBalance)}`);

    // 4. Approve a spender (e.g., DEX router)
    const spenderAddress = '0x...'; // DEX router address
    console.log('Approving spender...');

    const approveHash = await walletClient.writeContract({
      address: WRAPPED_TRUST_ADDRESS,
      abi: wrappedTrustAbi,
      functionName: 'approve',
      args: [spenderAddress, parseEther('0.5')]
    });

    await publicClient.waitForTransactionReceipt({ hash: approveHash });
    console.log(`Approved ${spenderAddress} to spend 0.5 WTRUST`);

    // 5. Transfer WTRUST to another address
    const recipientAddress = '0x...';
    console.log('Transferring WTRUST...');

    const transferHash = await walletClient.writeContract({
      address: WRAPPED_TRUST_ADDRESS,
      abi: wrappedTrustAbi,
      functionName: 'transfer',
      args: [recipientAddress, parseEther('0.1')]
    });

    await publicClient.waitForTransactionReceipt({ hash: transferHash });
    console.log(`Transferred 0.1 WTRUST to ${recipientAddress}`);

    // 6. Unwrap 0.5 WTRUST back to ETH
    console.log('Unwrapping 0.5 WTRUST...');

    const withdrawHash = await walletClient.writeContract({
      address: WRAPPED_TRUST_ADDRESS,
      abi: wrappedTrustAbi,
      functionName: 'withdraw',
      args: [parseEther('0.5')]
    });

    await publicClient.waitForTransactionReceipt({ hash: withdrawHash });
    console.log(`Unwrapped 0.5 WTRUST to ETH. Transaction: ${withdrawHash}`);

    // 7. Check total supply
    const totalSupply = await publicClient.readContract({
      address: WRAPPED_TRUST_ADDRESS,
      abi: wrappedTrustAbi,
      functionName: 'totalSupply'
    });
    console.log(`Total WTRUST supply: ${formatEther(totalSupply)}`);

  } catch (error) {
    console.error('Error:', error);
  }
}

main();
```

---

### TypeScript (Event Monitoring)

```typescript
import { createPublicClient, http, parseAbiItem } from 'viem';
import { intuition } from 'viem/chains';

const WRAPPED_TRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672';

const publicClient = createPublicClient({
  chain: intuition,
  transport: http()
});

async function monitorWrappingActivity() {
  console.log('Monitoring wrapping/unwrapping activity...\n');

  // Watch for Deposit events (wrapping)
  const depositUnwatch = publicClient.watchEvent({
    address: WRAPPED_TRUST_ADDRESS,
    event: parseAbiItem('event Deposit(address indexed account, uint256 amount)'),
    onLogs: (logs) => {
      logs.forEach((log) => {
        const { account, amount } = log.args;
        console.log(`🔵 WRAP: ${account} deposited ${formatEther(amount)} ETH`);
      });
    }
  });

  // Watch for Withdrawal events (unwrapping)
  const withdrawalUnwatch = publicClient.watchEvent({
    address: WRAPPED_TRUST_ADDRESS,
    event: parseAbiItem('event Withdrawal(address indexed account, uint256 amount)'),
    onLogs: (logs) => {
      logs.forEach((log) => {
        const { account, amount } = log.args;
        console.log(`🔴 UNWRAP: ${account} withdrew ${formatEther(amount)} ETH`);
      });
    }
  });

  // Watch for Transfer events
  const transferUnwatch = publicClient.watchEvent({
    address: WRAPPED_TRUST_ADDRESS,
    event: parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 amount)'),
    onLogs: (logs) => {
      logs.forEach((log) => {
        const { from, to, amount } = log.args;
        if (from === '0x0000000000000000000000000000000000000000') {
          // Minting (from deposit)
          console.log(`✅ MINT: ${to} received ${formatEther(amount)} WTRUST`);
        } else if (to === '0x0000000000000000000000000000000000000000') {
          // Burning (from withdrawal) - note: this won't emit in WTRUST
          console.log(`❌ BURN: ${from} burned ${formatEther(amount)} WTRUST`);
        } else {
          // Regular transfer
          console.log(`↔️  TRANSFER: ${from} → ${to}: ${formatEther(amount)} WTRUST`);
        }
      });
    }
  });

  // Keep process alive
  process.on('SIGINT', () => {
    depositUnwatch();
    withdrawalUnwatch();
    transferUnwatch();
    process.exit();
  });
}

monitorWrappingActivity();
```

---

### Python (web3.py)

```python
from web3 import Web3
from eth_account import Account
from decimal import Decimal
from typing import Optional

# Contract ABI (minimal)
WRAPPED_TRUST_ABI = [
    {
        "name": "deposit",
        "type": "function",
        "stateMutability": "payable",
        "inputs": [],
        "outputs": []
    },
    {
        "name": "withdraw",
        "type": "function",
        "stateMutability": "nonpayable",
        "inputs": [{"name": "amount", "type": "uint256"}],
        "outputs": []
    },
    {
        "name": "balanceOf",
        "type": "function",
        "stateMutability": "view",
        "inputs": [{"name": "account", "type": "address"}],
        "outputs": [{"name": "", "type": "uint256"}]
    },
    {
        "name": "approve",
        "type": "function",
        "stateMutability": "nonpayable",
        "inputs": [
            {"name": "spender", "type": "address"},
            {"name": "amount", "type": "uint256"}
        ],
        "outputs": [{"name": "", "type": "bool"}]
    },
    {
        "name": "transfer",
        "type": "function",
        "stateMutability": "nonpayable",
        "inputs": [
            {"name": "to", "type": "address"},
            {"name": "amount", "type": "uint256"}
        ],
        "outputs": [{"name": "", "type": "bool"}]
    },
    {
        "name": "totalSupply",
        "type": "function",
        "stateMutability": "view",
        "inputs": [],
        "outputs": [{"name": "", "type": "uint256"}]
    },
    {
        "name": "Deposit",
        "type": "event",
        "inputs": [
            {"name": "account", "type": "address", "indexed": True},
            {"name": "amount", "type": "uint256", "indexed": False}
        ]
    },
    {
        "name": "Withdrawal",
        "type": "event",
        "inputs": [
            {"name": "account", "type": "address", "indexed": True},
            {"name": "amount", "type": "uint256", "indexed": False}
        ]
    }
]

WRAPPED_TRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672'

class WrappedTrustClient:
    """Client for interacting with WrappedTrust contract."""

    def __init__(self, rpc_url: str, private_key: str):
        """
        Initialize the WrappedTrust client.

        Args:
            rpc_url: RPC endpoint URL
            private_key: Private key for signing transactions
        """
        self.w3 = Web3(Web3.HTTPProvider(rpc_url))
        self.account = Account.from_key(private_key)
        self.contract = self.w3.eth.contract(
            address=WRAPPED_TRUST_ADDRESS,
            abi=WRAPPED_TRUST_ABI
        )

    def to_wei(self, amount: float) -> int:
        """Convert ETH amount to wei."""
        return self.w3.to_wei(Decimal(str(amount)), 'ether')

    def from_wei(self, amount: int) -> float:
        """Convert wei to ETH amount."""
        return float(self.w3.from_wei(amount, 'ether'))

    def get_balance(self, address: Optional[str] = None) -> float:
        """
        Get WTRUST balance for an address.

        Args:
            address: Address to check (defaults to client's address)

        Returns:
            WTRUST balance in ETH units
        """
        addr = address or self.account.address
        balance = self.contract.functions.balanceOf(addr).call()
        return self.from_wei(balance)

    def get_total_supply(self) -> float:
        """
        Get total WTRUST supply.

        Returns:
            Total supply in ETH units
        """
        supply = self.contract.functions.totalSupply().call()
        return self.from_wei(supply)

    def deposit(self, amount: float) -> str:
        """
        Wrap ETH into WTRUST.

        Args:
            amount: Amount of ETH to wrap

        Returns:
            Transaction hash
        """
        amount_wei = self.to_wei(amount)

        # Build transaction
        tx = self.contract.functions.deposit().build_transaction({
            'from': self.account.address,
            'value': amount_wei,
            'nonce': self.w3.eth.get_transaction_count(self.account.address),
            'gas': 50000,
            'maxFeePerGas': self.w3.eth.gas_price,
            'maxPriorityFeePerGas': self.w3.to_wei(1, 'gwei')
        })

        # Sign and send
        signed_tx = self.w3.eth.account.sign_transaction(tx, self.account.key)
        tx_hash = self.w3.eth.send_raw_transaction(signed_tx.raw_transaction)

        # Wait for confirmation
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)

        if receipt['status'] == 1:
            print(f"✅ Wrapped {amount} ETH → WTRUST")
            print(f"   Transaction: {tx_hash.hex()}")
        else:
            print(f"❌ Transaction failed: {tx_hash.hex()}")

        return tx_hash.hex()

    def withdraw(self, amount: float) -> str:
        """
        Unwrap WTRUST into ETH.

        Args:
            amount: Amount of WTRUST to unwrap

        Returns:
            Transaction hash
        """
        amount_wei = self.to_wei(amount)

        # Build transaction
        tx = self.contract.functions.withdraw(amount_wei).build_transaction({
            'from': self.account.address,
            'nonce': self.w3.eth.get_transaction_count(self.account.address),
            'gas': 50000,
            'maxFeePerGas': self.w3.eth.gas_price,
            'maxPriorityFeePerGas': self.w3.to_wei(1, 'gwei')
        })

        # Sign and send
        signed_tx = self.w3.eth.account.sign_transaction(tx, self.account.key)
        tx_hash = self.w3.eth.send_raw_transaction(signed_tx.raw_transaction)

        # Wait for confirmation
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)

        if receipt['status'] == 1:
            print(f"✅ Unwrapped {amount} WTRUST → ETH")
            print(f"   Transaction: {tx_hash.hex()}")
        else:
            print(f"❌ Transaction failed: {tx_hash.hex()}")

        return tx_hash.hex()

    def approve(self, spender: str, amount: float) -> str:
        """
        Approve a spender to transfer WTRUST.

        Args:
            spender: Address to approve
            amount: Amount to approve

        Returns:
            Transaction hash
        """
        amount_wei = self.to_wei(amount)

        # Build transaction
        tx = self.contract.functions.approve(spender, amount_wei).build_transaction({
            'from': self.account.address,
            'nonce': self.w3.eth.get_transaction_count(self.account.address),
            'gas': 50000,
            'maxFeePerGas': self.w3.eth.gas_price,
            'maxPriorityFeePerGas': self.w3.to_wei(1, 'gwei')
        })

        # Sign and send
        signed_tx = self.w3.eth.account.sign_transaction(tx, self.account.key)
        tx_hash = self.w3.eth.send_raw_transaction(signed_tx.raw_transaction)

        # Wait for confirmation
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)

        if receipt['status'] == 1:
            print(f"✅ Approved {spender} to spend {amount} WTRUST")
            print(f"   Transaction: {tx_hash.hex()}")
        else:
            print(f"❌ Transaction failed: {tx_hash.hex()}")

        return tx_hash.hex()

    def transfer(self, to: str, amount: float) -> str:
        """
        Transfer WTRUST to another address.

        Args:
            to: Recipient address
            amount: Amount to transfer

        Returns:
            Transaction hash
        """
        amount_wei = self.to_wei(amount)

        # Build transaction
        tx = self.contract.functions.transfer(to, amount_wei).build_transaction({
            'from': self.account.address,
            'nonce': self.w3.eth.get_transaction_count(self.account.address),
            'gas': 60000,
            'maxFeePerGas': self.w3.eth.gas_price,
            'maxPriorityFeePerGas': self.w3.to_wei(1, 'gwei')
        })

        # Sign and send
        signed_tx = self.w3.eth.account.sign_transaction(tx, self.account.key)
        tx_hash = self.w3.eth.send_raw_transaction(signed_tx.raw_transaction)

        # Wait for confirmation
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)

        if receipt['status'] == 1:
            print(f"✅ Transferred {amount} WTRUST to {to}")
            print(f"   Transaction: {tx_hash.hex()}")
        else:
            print(f"❌ Transaction failed: {tx_hash.hex()}")

        return tx_hash.hex()


def main():
    """Example usage of WrappedTrust client."""
    # Initialize client
    client = WrappedTrustClient(
        rpc_url='https://your-intuition-rpc-url',
        private_key='0x...'
    )

    # Check initial balance
    balance = client.get_balance()
    print(f"Current WTRUST balance: {balance} WTRUST\n")

    # Wrap 1 ETH
    client.deposit(1.0)

    # Check new balance
    new_balance = client.get_balance()
    print(f"New WTRUST balance: {new_balance} WTRUST\n")

    # Transfer 0.1 WTRUST
    recipient = '0x...'
    client.transfer(recipient, 0.1)

    # Unwrap 0.5 WTRUST
    client.withdraw(0.5)

    # Check final balance
    final_balance = client.get_balance()
    print(f"Final WTRUST balance: {final_balance} WTRUST")

    # Check total supply
    total_supply = client.get_total_supply()
    print(f"Total WTRUST supply: {total_supply} WTRUST")


if __name__ == '__main__':
    main()
```

---

### Solidity Integration

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IWrappedTrust
 * @notice Minimal interface for WrappedTrust contract
 */
interface IWrappedTrust {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint256);
}

/**
 * @title WrappedTrustIntegration
 * @notice Example contract demonstrating WrappedTrust integration patterns
 * @dev Shows common use cases: wrapping, unwrapping, and DeFi interactions
 */
contract WrappedTrustIntegration {
    IWrappedTrust public immutable wrappedTrust;

    // Events
    event EthWrapped(address indexed user, uint256 amount);
    event WtrustUnwrapped(address indexed user, uint256 amount);
    event WtrustTransferred(address indexed from, address indexed to, uint256 amount);

    /**
     * @notice Initialize with WrappedTrust address
     * @param _wrappedTrust Address of the WrappedTrust contract
     */
    constructor(address _wrappedTrust) {
        require(_wrappedTrust != address(0), "Invalid address");
        wrappedTrust = IWrappedTrust(_wrappedTrust);
    }

    /**
     * @notice Wrap ETH on behalf of user
     * @dev User sends ETH to this contract, which wraps it and transfers WTRUST to user
     */
    function wrapEthForUser() external payable {
        require(msg.value > 0, "Must send ETH");

        // Wrap ETH into WTRUST
        wrappedTrust.deposit{value: msg.value}();

        // Transfer WTRUST to user
        require(
            wrappedTrust.transfer(msg.sender, msg.value),
            "Transfer failed"
        );

        emit EthWrapped(msg.sender, msg.value);
    }

    /**
     * @notice Unwrap WTRUST on behalf of user
     * @dev User must approve this contract to spend their WTRUST
     * @param amount Amount of WTRUST to unwrap
     */
    function unwrapWtrustForUser(uint256 amount) external {
        require(amount > 0, "Amount must be positive");

        // Transfer WTRUST from user to this contract
        require(
            wrappedTrust.transferFrom(msg.sender, address(this), amount),
            "TransferFrom failed"
        );

        // Unwrap WTRUST to ETH
        wrappedTrust.withdraw(amount);

        // Send ETH to user
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");

        emit WtrustUnwrapped(msg.sender, amount);
    }

    /**
     * @notice Batch wrap multiple amounts for multiple users
     * @dev Useful for airdrops or batch operations
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to wrap for each recipient
     */
    function batchWrapForUsers(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external payable {
        require(recipients.length == amounts.length, "Array length mismatch");

        uint256 totalAmount;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        require(msg.value == totalAmount, "Incorrect ETH amount");

        // Wrap all ETH at once
        wrappedTrust.deposit{value: msg.value}();

        // Distribute WTRUST to recipients
        for (uint256 i = 0; i < recipients.length; i++) {
            require(
                wrappedTrust.transfer(recipients[i], amounts[i]),
                "Transfer failed"
            );
            emit EthWrapped(recipients[i], amounts[i]);
        }
    }

    /**
     * @notice Example: Wrap ETH and use in DeFi protocol
     * @dev Demonstrates wrapping and immediate use in another protocol
     * @param dexRouter Address of DEX router
     * @param minOutput Minimum output tokens expected
     */
    function wrapAndSwap(
        address dexRouter,
        uint256 minOutput
    ) external payable returns (uint256) {
        require(msg.value > 0, "Must send ETH");
        require(dexRouter != address(0), "Invalid router");

        // 1. Wrap ETH
        wrappedTrust.deposit{value: msg.value}();

        // 2. Approve DEX router
        require(
            wrappedTrust.approve(dexRouter, msg.value),
            "Approval failed"
        );

        // 3. Call DEX swap function (pseudo-code, actual interface varies)
        // IDexRouter(dexRouter).swapExactTokensForTokens(...)

        emit EthWrapped(msg.sender, msg.value);

        return msg.value;
    }

    /**
     * @notice Emergency unwrap - convert all contract's WTRUST to ETH
     * @dev Only for demonstration - production contracts need access control
     */
    function emergencyUnwrapAll() external {
        uint256 balance = wrappedTrust.balanceOf(address(this));
        if (balance > 0) {
            wrappedTrust.withdraw(balance);
        }
    }

    /**
     * @notice Check contract's WTRUST balance
     * @return Current WTRUST balance
     */
    function getWtrustBalance() external view returns (uint256) {
        return wrappedTrust.balanceOf(address(this));
    }

    /**
     * @notice Receive ETH (from WTRUST unwrapping)
     */
    receive() external payable {
        // Accept ETH from WrappedTrust withdrawals
    }
}

/**
 * @title SimpleWtrustVault
 * @notice Example vault that accepts WTRUST deposits
 */
contract SimpleWtrustVault {
    IWrappedTrust public immutable wrappedTrust;

    mapping(address => uint256) public deposits;
    uint256 public totalDeposits;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(address _wrappedTrust) {
        wrappedTrust = IWrappedTrust(_wrappedTrust);
    }

    /**
     * @notice Deposit WTRUST into vault
     * @dev User must approve vault before calling
     * @param amount Amount of WTRUST to deposit
     */
    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be positive");

        // Transfer WTRUST from user
        require(
            wrappedTrust.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        deposits[msg.sender] += amount;
        totalDeposits += amount;

        emit Deposited(msg.sender, amount);
    }

    /**
     * @notice Withdraw WTRUST from vault
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be positive");
        require(deposits[msg.sender] >= amount, "Insufficient balance");

        deposits[msg.sender] -= amount;
        totalDeposits -= amount;

        require(
            wrappedTrust.transfer(msg.sender, amount),
            "Transfer failed"
        );

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Get user's vault balance
     * @param user User address
     * @return User's deposited amount
     */
    function balanceOf(address user) external view returns (uint256) {
        return deposits[user];
    }
}
```

---

## Integration Notes

### DeFi Protocol Integration

**Liquidity Pools**:
- WTRUST can be paired with any ERC20 token in AMM pools
- Common pairs: WTRUST/USDC, WTRUST/TRUST
- 1:1 peg with ETH makes pricing straightforward

**Lending Protocols**:
- Use WTRUST as collateral for borrowing
- Lend WTRUST to earn interest
- Easier than handling native ETH in lending contracts

**DEX Integration**:
- Approve DEX router to spend WTRUST
- Swap WTRUST like any ERC20 token
- No special handling needed compared to other tokens

---

### Smart Contract Best Practices

**Receiving ETH from Unwrapping**:
```solidity
// Always implement receive() or fallback() to accept ETH from withdrawals
receive() external payable {}
```

**Checking Balances Before Operations**:
```solidity
uint256 balance = wrappedTrust.balanceOf(address(this));
require(balance >= amount, "Insufficient WTRUST");
```

**Infinite Approval Pattern**:
```solidity
// Use max uint256 for approval to save gas on future operations
wrappedTrust.approve(spender, type(uint256).max);
```

**Batch Operations**:
```solidity
// Wrap once, distribute to multiple addresses
wrappedTrust.deposit{value: totalAmount}();
for (uint i = 0; i < recipients.length; i++) {
    wrappedTrust.transfer(recipients[i], amounts[i]);
}
```

---

### Common Patterns

#### Wrap-and-Use Pattern
```solidity
// 1. Wrap ETH
wrappedTrust.deposit{value: amount}();

// 2. Approve protocol
wrappedTrust.approve(protocol, amount);

// 3. Use in protocol
protocol.someFunction(amount);
```

#### Use-and-Unwrap Pattern
```solidity
// 1. Receive WTRUST from protocol
protocol.withdraw(amount);

// 2. Unwrap to ETH
wrappedTrust.withdraw(amount);

// 3. Use native ETH
recipient.call{value: amount}("");
```

---

### Edge Cases and Gotchas

**1. Self-Transfers**:
- Transferring to yourself works but is a no-op
- Still emits Transfer event
- Still consumes gas

**2. Zero-Amount Operations**:
- `deposit()` with 0 value is allowed (does nothing)
- `withdraw(0)` is allowed (does nothing)
- `transfer(addr, 0)` is allowed

**3. Contract Recipients**:
- Contracts must implement `receive()` or `fallback()` to receive ETH from `withdraw()`
- Will revert if contract doesn't accept ETH

**4. Reentracy**:
- `withdraw()` uses OpenZeppelin's `sendValue()` which is reentrancy-safe
- Balance is decremented before ETH transfer
- No reentrancy vulnerability

**5. Total Supply Calculation**:
- `totalSupply()` reads `address(this).balance`
- Can be manipulated by self-destructing a contract and forcing ETH to the address
- However, this only affects the view function, not actual token balances

---

## Gas Considerations

### Gas Costs (Approximate)

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| `deposit()` | ~46,000 | First deposit costs more (cold storage) |
| `deposit()` (subsequent) | ~29,000 | Warm storage access |
| `withdraw()` | ~30,000 | Includes ETH transfer |
| `approve()` | ~46,000 | First approval to spender |
| `approve()` (update) | ~29,000 | Updating existing approval |
| `transfer()` | ~51,000 | Between two addresses |
| `transferFrom()` | ~54,000 | With allowance deduction |
| `transferFrom()` (infinite) | ~51,000 | No allowance deduction |
| `balanceOf()` | ~2,300 | View function (read-only) |
| `totalSupply()` | ~2,100 | View function (read-only) |

**Note**: Gas costs vary with network conditions and are approximate. Always test on testnets.

---

### Gas Optimization Tips

**1. Use Infinite Approval**:
```solidity
// Instead of approving exact amounts each time:
wrappedTrust.approve(spender, exactAmount); // Costs ~46k gas each time

// Approve once with max value:
wrappedTrust.approve(spender, type(uint256).max); // ~46k gas once
// Future transfers cost ~3k less gas
```

**2. Batch Wrapping**:
```solidity
// Instead of multiple small deposits:
for (uint i = 0; i < 10; i++) {
    wrappedTrust.deposit{value: 0.1 ether}(); // 10 * ~46k = ~460k gas
}

// Wrap once and transfer:
wrappedTrust.deposit{value: 1 ether}(); // ~46k gas
for (uint i = 0; i < 10; i++) {
    wrappedTrust.transfer(recipients[i], 0.1 ether); // ~51k each
}
// Total: ~46k + (10 * ~51k) = ~556k gas (similar but better for distribution)
```

**3. Avoid Unnecessary Unwrapping**:
```solidity
// If you need to pay someone, prefer WTRUST transfer over unwrap+send ETH:

// More expensive:
wrappedTrust.withdraw(amount);        // ~30k gas
recipient.call{value: amount}("");    // ~21k gas
// Total: ~51k gas

// Less expensive:
wrappedTrust.transfer(recipient, amount); // ~51k gas (similar, but keeps wrapped)
```

**4. Combine Operations**:
```solidity
// Some protocols support direct ETH wrapping in the same transaction
// Check if your protocol supports multicall or similar patterns
```

---

### Gas Comparison: WTRUST vs Native ETH

| Operation | Native ETH | WTRUST | Difference |
|-----------|------------|---------|------------|
| Simple transfer | ~21,000 | ~51,000 | +30k (WTRUST) |
| Approve for spending | N/A | ~46,000 | N/A |
| Approved transfer | N/A | ~54,000 | N/A |
| Smart contract acceptance | Requires receive() | Standard ERC20 | WTRUST simpler |

**When to use WTRUST**:
- Interacting with DeFi protocols (DEXs, lending, etc.)
- Smart contracts that only accept ERC20
- Need approval/allowance mechanism
- Batch operations with multiple tokens

**When to use Native ETH**:
- Simple peer-to-peer transfers
- Minimal gas cost needed
- Recipient accepts ETH directly
- No smart contract interaction required

---

## Related Contracts

### TRUST Token
- **Documentation**: [Trust.md](./core/Trust.md)
- **Relationship**: Different token entirely
  - TRUST is the protocol's ERC20 utility token
  - WTRUST wraps native ETH on Intuition's L2
  - No direct conversion between TRUST and WTRUST
  - Both can exist in the same ecosystem

---

### MultiVault
- **Documentation**: [MultiVault.md](./core/MultiVault.md)
- **Potential Integration**:
  - MultiVault uses TRUST as the base asset
  - WTRUST could potentially be integrated for ETH-denominated vaults
  - Currently separate systems

---

### Standard WETH9
- **Contract**: Canonical Wrapped Ether
- **Similarity**: WrappedTrust is a direct adaptation of WETH9
- **Differences**:
  - Different token name/symbol
  - Different blockchain (Intuition L2 vs Ethereum mainnet)
  - Same core functionality

---

## Comparison to WETH Pattern

### Similarities with WETH9

WrappedTrust closely follows the WETH9 standard:

| Feature | WETH9 | WrappedTrust | Match |
|---------|-------|--------------|-------|
| 1:1 backing | Yes | Yes | ✅ |
| Deposit function | Yes | Yes | ✅ |
| Withdraw function | Yes | Yes | ✅ |
| Receive fallback | Yes | Yes | ✅ |
| Full ERC20 | Yes | Yes | ✅ |
| Infinite approval | Yes | Yes | ✅ |
| No admin functions | Yes | Yes | ✅ |
| No fees | Yes | Yes | ✅ |
| Same code structure | Yes | Yes | ✅ |

---

### Differences from WETH9

| Aspect | WETH9 | WrappedTrust |
|--------|-------|--------------|
| Name | "Wrapped Ether" | "Wrapped TRUST" |
| Symbol | WETH | WTRUST |
| Chain | Ethereum Mainnet | Intuition L2 |
| License | GPL-3.0 (2015-2017) | GPL-3.0 (2024) |
| Import statements | None | OpenZeppelin Address |

**Note on OpenZeppelin Import**:
WrappedTrust uses OpenZeppelin's `Address.sendValue()` for ETH transfers, while WETH9 uses inline assembly. Both achieve the same result, but WrappedTrust's approach is more modern and audited.

---

### Why the WETH Pattern?

**Proven Design**:
- Battle-tested across millions of transactions
- Used in major DeFi protocols (Uniswap, Aave, Compound)
- Well-understood by developers and auditors

**Security**:
- Simple code reduces attack surface
- No complex logic means fewer bugs
- Permissionless design eliminates admin risks

**Compatibility**:
- Standard ERC20 interface
- Works with all DeFi protocols expecting ERC20
- Familiar pattern for developers

---

### When to Use Each

**Use WTRUST When**:
- Building on Intuition L2
- Need ERC20 wrapper for native ETH on Intuition chain
- Creating liquidity pools with ETH on Intuition
- Integrating with Intuition-native DeFi protocols

**Use Standard WETH When**:
- Building on Ethereum mainnet
- Building on other L2s (Arbitrum, Optimism have their own WETH)
- Need maximum liquidity and adoption

---

## Security Considerations

### Audits

**Original WETH9 Audits**:
- Extensively audited since 2017
- No critical vulnerabilities found
- De facto standard for wrapped ETH

**WrappedTrust Specific**:
- Uses OpenZeppelin's audited `Address.sendValue()`
- Minimal modifications from WETH9 standard
- Code is simple and transparent

---

### Known Limitations

**1. No Pause Mechanism**:
- Cannot be stopped if vulnerability discovered
- Mitigation: Code simplicity reduces vulnerability surface

**2. No Upgrade Path**:
- Contract is immutable
- Cannot add features or fix bugs
- Mitigation: Deploy new version if needed, migrate liquidity

**3. ETH Transfer Risks**:
- Withdrawals can fail if recipient reverts
- Mitigation: Users should ensure recipient can receive ETH

**4. Forced ETH**:
- `selfdestruct` can force ETH to contract
- This inflates `totalSupply()` view function
- Does not affect individual balances or contract operation
- Only cosmetic issue with supply calculation

---

### Best Practices for Integrators

**1. Check Balance Before Operations**:
```solidity
require(wrappedTrust.balanceOf(user) >= amount, "Insufficient balance");
```

**2. Handle Transfer Failures**:
```solidity
require(wrappedTrust.transfer(recipient, amount), "Transfer failed");
```

**3. Verify Allowance**:
```solidity
uint256 allowance = wrappedTrust.allowance(owner, spender);
require(allowance >= amount, "Insufficient allowance");
```

**4. Implement Receive Function**:
```solidity
receive() external payable {
    // Accept ETH from WTRUST withdrawals
}
```

**5. Consider Reentrancy**:
Although WrappedTrust is reentrancy-safe, your integration should still follow checks-effects-interactions:
```solidity
// Update state first
userBalance -= amount;

// Then interact with WTRUST
wrappedTrust.withdraw(amount);
```

---

## Frequently Asked Questions

### General Questions

**Q: Is WTRUST the same as TRUST?**

A: No. WTRUST is wrapped ETH on the Intuition L2 chain, while TRUST is the protocol's native utility token. They are separate tokens with different purposes:
- WTRUST: 1:1 backed by ETH, used for DeFi on Intuition L2
- TRUST: Protocol utility token, used in MultiVault and emissions

---

**Q: Can I convert WTRUST to TRUST or vice versa?**

A: Not directly. WTRUST wraps ETH, not TRUST. To convert:
- WTRUST → ETH: Call `withdraw()`
- ETH → WTRUST: Call `deposit()` or send ETH to contract
- For TRUST ↔ ETH conversions, use DEX pools or other trading venues

---

**Q: Why wrap ETH instead of using it directly?**

A: Many DeFi protocols and smart contracts only support ERC20 tokens. Wrapping ETH into WTRUST allows it to be used in:
- DEX liquidity pools
- Lending/borrowing protocols
- Yield farming contracts
- Any protocol requiring ERC20 tokens

---

**Q: Are there any fees for wrapping/unwrapping?**

A: No. WrappedTrust charges no fees. You only pay network gas fees for the transactions.

---

**Q: What happens if I send ETH directly to the contract address?**

A: It automatically wraps into WTRUST via the `receive()` fallback function. Your address will receive the equivalent WTRUST balance.

---

### Technical Questions

**Q: How is the 1:1 peg maintained?**

A: The peg is maintained by the contract's design:
- Every WTRUST is backed by exactly 1 wei of ETH held in the contract
- Depositing X ETH mints X WTRUST
- Withdrawing X WTRUST burns it and returns X ETH
- No external price feeds or arbitrage needed

---

**Q: Can the contract run out of ETH?**

A: No. The contract can only return ETH that was previously deposited. `totalSupply()` always equals `address(this).balance`.

---

**Q: What if I send WTRUST to the contract address?**

A: The tokens will be stuck. WrappedTrust has no function to recover mistakenly sent tokens. Always use `withdraw()` to convert back to ETH.

---

**Q: Is there a risk of the contract being upgraded or modified?**

A: No. WrappedTrust is a non-upgradeable contract. The code is immutable and cannot be changed.

---

**Q: How do I check if I have enough allowance?**

A:
```solidity
uint256 allowance = wrappedTrust.allowance(owner, spender);
```

---

### Integration Questions

**Q: Should I use infinite approval for my DeFi integration?**

A: It depends on your trust model:
- **Infinite approval (`type(uint256).max`)**: Saves gas on future operations, common in DeFi
- **Exact approval**: More conservative, requires approval before each transfer
- Consider your users' preferences and security requirements

---

**Q: Can I batch multiple wrap/unwrap operations?**

A: The contract doesn't have native batching, but you can:
- Create a wrapper contract that batches operations
- Use multicall patterns
- Single `deposit()` and multiple `transfer()` calls for distribution

---

**Q: How do I handle failed ETH transfers during withdrawal?**

A: The `withdraw()` function will revert if the ETH transfer fails. Ensure:
- Recipient contract implements `receive()` or `fallback()`
- Recipient doesn't revert on ETH receipt
- Recipient has enough gas to process the receipt

---

## See Also

### Documentation
- [Protocol Overview](../getting-started/overview.md) - Understanding the Intuition ecosystem
- [Deployment Addresses](../getting-started/deployment-addresses.md) - All contract addresses
- [Trust Token](./core/Trust.md) - The TRUST utility token

### Guides
- [Depositing Assets](../guides/depositing-assets.md) - Working with protocol assets
- [Integration Patterns](../integration/sdk-design-patterns.md) - Best practices for integration

### External Resources
- [WETH9 Contract](https://etherscan.io/address/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2#code) - Original Wrapped Ether
- [ERC20 Standard](https://eips.ethereum.org/EIPS/eip-20) - Token standard specification
- [Intuition Explorer](https://explorer.intuit.network) - Block explorer for deployed contract

---

**Last Updated**: December 2025
**Version**: 1.0
**License**: GPL-3.0
