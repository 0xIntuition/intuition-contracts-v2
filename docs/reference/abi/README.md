# Contract ABIs

Contract ABI (Application Binary Interface) JSON files for Intuition Protocol V2.

## Overview

This directory contains ABI JSON files extracted from compiled contracts. These ABIs are used for:

- SDK development
- Direct contract interaction via viem, web3.py, etc.
- Frontend integration
- Testing and development tools

## Available ABIs

### Core Contracts

- **MultiVault.json** - Central vault management contract
- **Trust.json** - TRUST ERC20 token
- **TrustBonding.json** - Rewards and emissions distribution

### Bonding Curves

- **BondingCurveRegistry.json** - Curve registry
- **LinearCurve.json** - Linear 1:1 pricing curve
- **ProgressiveCurve.json** - Quadratic pricing curve
- **OffsetProgressiveCurve.json** - Offset quadratic curve

### Emissions System

- **BaseEmissionsController.json** - Base chain emissions (mints TRUST)
- **SatelliteEmissionsController.json** - Satellite chain emissions
- **CoreEmissionsController.json** - Shared emission logic

### Wallet System

- **AtomWallet.json** - ERC-4337 atom wallet
- **AtomWalletFactory.json** - Wallet deployment factory
- **AtomWarden.json** - Wallet registry and ownership

## Generating ABIs

ABIs are automatically generated during compilation:

```bash
# Compile contracts with Foundry
forge build

# ABIs are output to out/{Contract}.sol/{Contract}.json
```

## Extracting ABIs

To extract just the ABI from compiled artifacts:

```bash
# Extract ABI for a specific contract
jq '.abi' out/MultiVault.sol/MultiVault.json > docs/reference/abi/MultiVault.json

# Extract multiple contracts
for contract in MultiVault Trust TrustBonding; do
  jq '.abi' out/${contract}.sol/${contract}.json > docs/reference/abi/${contract}.json
done
```

## Using ABIs

### TypeScript/JavaScript (viem)

```typescript
import { createPublicClient, createWalletClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { intuition } from 'viem/chains';
import MultiVaultABI from './abi/MultiVault.json';

const publicClient = createPublicClient({
  chain: intuition,
  transport: http('RPC_URL'),
});

// Read functions
const [totalAssets, totalShares] = await publicClient.readContract({
  address: '0x...', // Contract address
  abi: MultiVaultABI,
  functionName: 'getVault',
  args: [termId, curveId],
});

// Write functions (requires wallet)
const account = privateKeyToAccount('0x...');
const walletClient = createWalletClient({
  account,
  chain: intuition,
  transport: http('RPC_URL'),
});

const hash = await walletClient.writeContract({
  address: '0x...',
  abi: MultiVaultABI,
  functionName: 'deposit',
  args: [receiver, termId, curveId, assets, minShares],
});

const receipt = await publicClient.waitForTransactionReceipt({ hash });
```

### TypeScript with Type Generation

Generate TypeScript types from ABIs using wagmi CLI:

```bash
# Install wagmi CLI
npm install --save-dev @wagmi/cli

# Configure wagmi.config.ts
import { defineConfig } from '@wagmi/cli';
import { foundry } from '@wagmi/cli/plugins';

export default defineConfig({
  out: 'src/generated.ts',
  plugins: [
    foundry({
      project: '.',
      include: ['MultiVault.json', 'Trust.json'],
    }),
  ],
});

# Generate types
npx wagmi generate
```

Usage with generated types:

```typescript
import { publicClient } from './client';
import { multiVaultAbi } from './generated';

// Full type safety!
const vault = await publicClient.readContract({
  address: '0x...',
  abi: multiVaultAbi,
  functionName: 'getVault',
  args: [termId, curveId],
});
// vault is typed as { totalAssets: bigint; totalShares: bigint }
```

### Python (web3.py)

```python
from web3 import Web3
import json

# Load ABI
with open('abi/MultiVault.json') as f:
    multivault_abi = json.load(f)

# Connect to provider
w3 = Web3(Web3.HTTPProvider('RPC_URL'))

# Create contract instance
multivault = w3.eth.contract(
    address='0x...',
    abi=multivault_abi
)

# Call functions
total_assets, total_shares = multivault.functions.getVault(
    term_id,
    curve_id
).call()

# Send transactions
tx_hash = multivault.functions.deposit(
    receiver,
    term_id,
    curve_id,
    assets,
    min_shares
).transact({
    'from': sender_address,
    'gas': 200000
})

receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
```

### Solidity

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMultiVault} from "src/interfaces/IMultiVault.sol";
import {ITrustBonding} from "src/interfaces/ITrustBonding.sol";

contract MyContract {
    IMultiVault public immutable multiVault;
    ITrustBonding public immutable trustBonding;

    constructor(address _multiVault, address _trustBonding) {
        multiVault = IMultiVault(_multiVault);
        trustBonding = ITrustBonding(_trustBonding);
    }

    function depositToVault(
        bytes32 termId,
        uint256 curveId,
        uint256 assets
    ) external {
        multiVault.deposit(
            msg.sender,
            termId,
            curveId,
            assets,
            0 // minShares
        );
    }
}
```

### Rust (alloy-rs)

```rust
use alloy::prelude::*;
use alloy::providers::{Provider, ProviderBuilder};
use std::sync::Arc;

// Import generated bindings
sol!(
    #[sol(rpc)]
    MultiVault,
    "./abi/MultiVault.json"
);

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let provider = ProviderBuilder::new()
        .on_http("RPC_URL".parse()?);

    let multivault = MultiVault::new(
        "0x...".parse::<Address>()?,
        provider
    );

    let MultiVault::getVaultReturn { totalAssets, totalShares } = multivault
        .getVault(term_id, curve_id)
        .call()
        .await?;

    println!("Total Assets: {}", totalAssets);
    println!("Total Shares: {}", totalShares);

    Ok(())
}
```

### Go (go-ethereum)

```go
package main

import (
    "context"
    "fmt"
    "log"

    "github.com/ethereum/go-ethereum/accounts/abi/bind"
    "github.com/ethereum/go-ethereum/common"
    "github.com/ethereum/go-ethereum/ethclient"

    // Generated bindings
    "myapp/contracts"
)

func main() {
    client, err := ethclient.Dial("RPC_URL")
    if err != nil {
        log.Fatal(err)
    }

    address := common.HexToAddress("0x...")
    multivault, err := contracts.NewMultiVault(address, client)
    if err != nil {
        log.Fatal(err)
    }

    totalAssets, totalShares, err := multivault.GetVault(
        &bind.CallOpts{},
        termId,
        curveId,
    )
    if err != nil {
        log.Fatal(err)
    }

    fmt.Printf("Total Assets: %v\n", totalAssets)
    fmt.Printf("Total Shares: %v\n", totalShares)
}
```

## ABI Structure

Each ABI JSON file contains an array of function and event definitions:

```json
[
  {
    "type": "function",
    "name": "deposit",
    "inputs": [
      {
        "name": "receiver",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      ...
    ],
    "outputs": [...],
    "stateMutability": "payable"
  },
  {
    "type": "event",
    "name": "Deposited",
    "inputs": [
      {
        "name": "sender",
        "type": "address",
        "indexed": true
      },
      ...
    ],
    "anonymous": false
  }
]
```

### ABI Types

- **function**: Contract functions (read/write)
- **event**: Event definitions
- **error**: Custom error definitions
- **constructor**: Contract constructor
- **fallback**: Fallback function
- **receive**: Receive function

### State Mutability

- **view**: Read-only, doesn't modify state
- **pure**: Doesn't read or modify state
- **nonpayable**: Modifies state, doesn't accept ETH
- **payable**: Modifies state, accepts ETH

## Version Compatibility

These ABIs are compatible with:

- **Solidity**: 0.8.29+
- **viem**: v2.x
- **web3.js**: v4.x
- **web3.py**: v6.x+
- **alloy-rs**: Latest
- **go-ethereum**: v1.10+

## Updates

ABIs are regenerated with each contract deployment. Always use the ABI version matching your deployed contract version.

Check the contract deployment addresses in:
- [Deployment Addresses](../../getting-started/deployment-addresses.md)

## Verification

Verify ABI matches deployed contract:

```bash
# Using cast (Foundry)
cast interface <CONTRACT_ADDRESS> --chain <CHAIN_ID>

# Compare with local ABI
jq '.abi' out/MultiVault.sol/MultiVault.json
```

## See Also

- [Deployment Addresses](../../getting-started/deployment-addresses.md) - Contract addresses
- [Quickstart SDK](../../getting-started/quickstart-sdk.md) - SDK setup guide
- [Events Reference](../events.md) - Event catalog
- [Data Structures](../data-structures.md) - Struct definitions
