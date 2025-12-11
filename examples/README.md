# Intuition Protocol V2 - Code Examples

This directory contains production-quality, runnable code examples for integrating with Intuition Protocol V2.

## Overview

All examples are:
- **Complete and runnable** - Include all imports, setup, and configuration
- **Heavily commented** - Explain each step in detail
- **Error-handled** - Demonstrate proper error handling patterns
- **Production-ready** - Can be copied and adapted for real applications

## Directory Structure

```
examples/
├── typescript/     # 8 TypeScript examples using ethers.js v6
├── python/         # 6 Python examples using web3.py
├── solidity/       # 3 Solidity integration examples
└── README.md       # This file
```

## TypeScript Examples (ethers.js v6)

Located in `typescript/` directory.

| File | Description | Key Features |
|------|-------------|--------------|
| `create-atom.ts` | Create an atom vault with initial deposit | Atom creation, WTRUST approval, event parsing |
| `create-triple.ts` | Create a triple vault (S-P-O) | Triple creation, atom validation, multi-deposit |
| `deposit-vault.ts` | Deposit into existing vault | Preview deposits, slippage protection |
| `redeem-shares.ts` | Redeem shares for assets | Preview redemptions, fee calculations |
| `claim-rewards.ts` | Claim TRUST rewards from bonding | Epoch management, APY queries, utilization |
| `batch-operations.ts` | Batch deposits and redemptions | Gas optimization, array operations |
| `event-listener.ts` | Real-time event monitoring | WebSocket connections, event parsing |
| `sdk-wrapper.ts` | Production SDK wrapper class | Type-safe API, error handling, utilities |

### Running TypeScript Examples

```bash
# Install dependencies
npm install ethers@6

# Set environment variable
export PRIVATE_KEY="your_private_key_here"

# Run example
npx ts-node examples/typescript/create-atom.ts
```

## Python Examples (web3.py)

Located in `python/` directory.

| File | Description | Key Features |
|------|-------------|--------------|
| `create-atom.py` | Create an atom vault | Full transaction flow, event parsing |
| `create-triple.py` | Create a triple vault | Atom validation, triple creation |
| `deposit-vault.py` | Deposit into vault | Preview, slippage protection |
| `redeem-shares.py` | Redeem vault shares | Preview, balance tracking |
| `claim-rewards.py` | Claim TRUST rewards | Epoch management, reward calculations |
| `event-indexer.py` | Index and monitor events | Historical queries, real-time monitoring |

### Running Python Examples

```bash
# Install dependencies
pip install web3

# Set environment variable
export PRIVATE_KEY="your_private_key_here"

# Run example
python examples/python/create-atom.py
```

## Solidity Examples

Located in `solidity/` directory.

| File | Description | Key Features |
|------|-------------|--------------|
| `IntegrationContract.sol` | Smart contract integration | Create atoms/triples, manage deposits, track users |
| `CustomCurve.sol` | Custom bonding curve | Implement IBaseCurve, exponential pricing |
| `UtilizationTracker.sol` | Utilization analysis | Read protocol data, calculate rewards, recommendations |

### Using Solidity Examples

These contracts can be:
1. **Deployed** directly to interact with Intuition Protocol
2. **Adapted** for your specific use case
3. **Studied** to understand integration patterns

```solidity
// Example: Deploy IntegrationContract
IntegrationContract integration = new IntegrationContract(
    0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e,  // MultiVault
    0x81cFb09cb44f7184Ad934C09F82000701A4bF672   // WTRUST
);

// Create an atom
bytes32 atomId = integration.createAtomAndDeposit("My Atom", 10 ether);
```

## Contract Addresses

### Intuition Mainnet

```
MultiVault:     0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e
WTRUST:         0x81cFb09cb44f7184Ad934C09F82000701A4bF672
TrustBonding:   0x635bBD1367B66E7B16a21D6E5A63C812fFC00617
AtomWarden:     0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165
```

### Intuition Testnet

```
MultiVault:     0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91
WTRUST:         0xDE80b6EE63f7D809427CA350e30093F436A0fe35
TrustBonding:   0x75dD32b522c89566265eA32ecb50b4Fc4d00ADc7
AtomWarden:     0x040B7760EFDEd7e933CFf419224b57DFB9Eb4488
```

See [deployment-addresses.md](../docs/getting-started/deployment-addresses.md) for complete list.

## Configuration

All examples require configuration:

### TypeScript/Python
```typescript
// Edit these constants in each file
const RPC_URL = "YOUR_INTUITION_RPC_URL";
const PRIVATE_KEY = process.env.PRIVATE_KEY;
```

### Environment Variables
```bash
# .env file (NEVER commit this!)
PRIVATE_KEY=0x1234567890abcdef...
INTUITION_RPC_URL=https://rpc.intuit.network
```

## Common Patterns

### 1. Approval Pattern
All WTRUST operations require approval:

```typescript
// TypeScript
await wTrust.approve(MULTIVAULT_ADDRESS, amount);

// Python
wtrust.functions.approve(multivault_address, amount).transact()

// Solidity
IERC20(wtrust).approve(multiVault, type(uint256).max);
```

### 2. Preview Before Execute
Always preview operations to estimate outputs:

```typescript
// Preview deposit to get expected shares
const [expectedShares, assetsAfterFees] = await multiVault.previewDeposit(
    termId, curveId, amount
);

// Calculate minimum shares with slippage tolerance
const minShares = expectedShares * 99n / 100n;

// Execute with slippage protection
await multiVault.deposit(receiver, termId, curveId, minShares);
```

### 3. Error Handling
Handle protocol-specific errors:

```typescript
try {
    await multiVault.createAtoms(datas, assets);
} catch (error) {
    if (error.message.includes('AtomDataMaxLengthExceeded')) {
        // Handle: Atom data too long
    } else if (error.message.includes('MinDepositRequired')) {
        // Handle: Deposit too small
    }
}
```

## Gas Optimization

### Batch Operations
Use batch functions to save gas:

```typescript
// ❌ Bad: Multiple transactions
await multiVault.deposit(receiver, termId1, curveId, minShares1);
await multiVault.deposit(receiver, termId2, curveId, minShares2);

// ✅ Good: Single batch transaction
await multiVault.depositBatch(
    receiver,
    [termId1, termId2],
    [curveId, curveId],
    [assets1, assets2],
    [minShares1, minShares2]
);
```

### Approval Strategy

```typescript
// ❌ Bad: Approve for each operation
await wTrust.approve(multiVault, amount1);
await multiVault.deposit(...);
await wTrust.approve(multiVault, amount2);
await multiVault.deposit(...);

// ✅ Good: Approve once for max
await wTrust.approve(multiVault, ethers.MaxUint256);
// Now all future operations work without re-approval
```

## Event Monitoring

### Historical Events
```typescript
// Query last 1000 blocks
const atomFilter = multiVault.filters.AtomCreated();
const events = await multiVault.queryFilter(atomFilter, fromBlock, toBlock);
```

### Real-time Events
```typescript
// WebSocket connection for live events
const provider = new ethers.WebSocketProvider(WS_RPC_URL);
const multiVault = new ethers.Contract(address, abi, provider);

multiVault.on('Deposited', (sender, receiver, termId, ...args) => {
    console.log(`New deposit: ${ethers.formatEther(args[2])} WTRUST`);
});
```

## Testing

All examples include example outputs in comments. To test:

1. **Use Testnet First**: Test with Intuition Testnet before mainnet
2. **Small Amounts**: Start with small deposit amounts
3. **Check Events**: Verify events are emitted correctly
4. **Monitor Gas**: Track gas usage for optimization

## Troubleshooting

### Common Issues

**"Insufficient WTRUST balance"**
- Solution: Get WTRUST tokens or use testnet faucet

**"AtomDataMaxLengthExceeded"**
- Solution: Reduce atom data size (check `atomDataMaxLength`)

**"MinDepositRequired"**
- Solution: Increase deposit amount above minimum

**"InsufficientShares" (slippage)**
- Solution: Increase slippage tolerance or reduce deposit

**"NoRewardsToClaim"**
- Solution: Wait for next epoch or increase utilization

### Getting Help

- **Documentation**: See [../docs/](../docs/) for detailed guides
- **Interfaces**: See [../src/interfaces/](../src/interfaces/) for ABIs
- **Deployment Addresses**: See [deployment-addresses.md](../docs/getting-started/deployment-addresses.md)

## License

MIT License - see [LICENSE](../LICENSE) file

## Contributing

Contributions welcome! Please:
1. Follow existing code style
2. Add heavy comments
3. Include example outputs
4. Test on testnet first

---

**Last Updated**: December 2025
**Protocol Version**: V2.0
**Examples Version**: 1.0
