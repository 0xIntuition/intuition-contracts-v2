# Contributing

Guidelines for contributing to Intuition Protocol V2 documentation and codebase.

## Overview

We welcome contributions from the community! This guide covers how to contribute to:
- Documentation
- Smart contracts
- Tests
- Examples
- Tools and scripts

## Getting Started

### Prerequisites

**Required:**
- Git
- Node.js 18+ or Bun
- Foundry (for smart contract development)
- A GitHub account

**Recommended:**
- VS Code with Solidity extension
- Docker (for running local nodes)

### Setting Up Development Environment

```bash
# 1. Fork the repository on GitHub

# 2. Clone your fork
git clone https://github.com/YOUR_USERNAME/intuition-contracts-v2.git
cd intuition-contracts-v2

# 3. Add upstream remote
git remote add upstream https://github.com/0xIntuition/intuition-contracts-v2.git

# 4. Install dependencies
bun install

# 5. Install Foundry dependencies
forge install

# 6. Build contracts
forge build

# 7. Run tests
forge test
```

## Contributing to Documentation

### Documentation Structure

```
docs/
├── README.md                    # Documentation hub
├── GLOSSARY.md                  # Protocol terminology
├── getting-started/             # Introductory guides
├── concepts/                    # Core concepts
├── contracts/                   # Contract reference
├── guides/                      # Integration guides
├── integration/                 # SDK patterns
├── examples/                    # Code examples
├── reference/                   # Technical reference
├── advanced/                    # Advanced topics
└── appendix/                    # Supplementary content
```

### Writing Style Guidelines

**Voice and Tone:**
- Use active voice
- Be clear and concise
- Write for developers (assume technical knowledge)
- Explain "why" not just "what"

**Formatting:**
- Use Markdown for all documentation
- Include code examples for all operations
- Use mermaid diagrams for flows and architecture
- Link to related documents

**Code Examples:**
- Include complete, runnable examples
- Show imports and setup
- Include error handling
- Add comments explaining each step
- Provide examples in multiple languages where applicable

### Documentation Templates

**For Concept Documents:**
```markdown
# [Concept Name]

Brief one-sentence description.

## Overview

What is this concept and why does it matter?

## Key Principles

1. Principle 1
2. Principle 2

## How It Works

Detailed explanation with diagrams.

## Use Cases

When to use this pattern.

## Examples

Code examples showing the concept.

## See Also

- Related concept docs
- Implementation guides
```

**For Integration Guides:**
```markdown
# [Operation Name]

## Overview

What this guide covers.

## Prerequisites

- Required knowledge
- Required tools/contracts

## Step-by-Step Guide

### Step 1: [First Step]

Clear instructions with code.

### Step 2: [Second Step]

Continue for all steps.

## Complete Example

Full, runnable code example.

## Common Issues

Troubleshooting tips.

## See Also

Links to related guides.
```

### Submitting Documentation Changes

```bash
# 1. Create a branch
git checkout -b docs/improve-concept-guide

# 2. Make your changes
# Edit files in docs/

# 3. Preview changes locally
# Open .md files in VS Code or use a markdown previewer

# 4. Commit with clear message
git add docs/
git commit -m "docs: improve bonding curves explanation with diagrams"

# 5. Push to your fork
git push origin docs/improve-concept-guide

# 6. Open Pull Request on GitHub
# Go to github.com/0xIntuition/intuition-contracts-v2
# Click "Pull Request" and select your branch
```

**Commit Message Format:**
```
type: subject

body (optional)

footer (optional)
```

**Types:**
- `docs`: Documentation changes
- `feat`: New feature
- `fix`: Bug fix
- `test`: Test changes
- `chore`: Maintenance

**Examples:**
- `docs: add troubleshooting guide for common errors`
- `docs: improve code examples in deposit guide`
- `docs: fix typos in glossary`

## Contributing to Smart Contracts

### Before You Start

- Discuss major changes in GitHub Issues or Discord first
- Follow existing code style and patterns
- Write comprehensive tests
- Update documentation

### Code Style

**Solidity:**
```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Interface} from "./interfaces/Interface.sol";

/**
 * @title ContractName
 * @author 0xIntuition
 * @notice Brief description
 * @dev Detailed implementation notes
 */
contract ContractName is Interface {
    /* =================================================== */
    /*                       CONSTANTS                     */
    /* =================================================== */

    uint256 public constant MAX_VALUE = 100;

    /* =================================================== */
    /*                       STATE                         */
    /* =================================================== */

    uint256 public value;

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    error ContractName_InvalidValue();

    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    event ValueUpdated(uint256 oldValue, uint256 newValue);

    /* =================================================== */
    /*                       FUNCTIONS                     */
    /* =================================================== */

    /**
     * @notice Updates the value
     * @param newValue The new value to set
     */
    function updateValue(uint256 newValue) external {
        if (newValue > MAX_VALUE) revert ContractName_InvalidValue();

        uint256 oldValue = value;
        value = newValue;

        emit ValueUpdated(oldValue, newValue);
    }
}
```

**Key Points:**
- Use NatSpec for all public/external functions
- Group related code with section headers
- Use custom errors, not `require` strings
- Emit events for state changes
- Follow naming conventions (CamelCase for contracts, camelCase for functions)

### Testing Requirements

All code contributions must include tests:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {ContractName} from "src/ContractName.sol";

contract ContractNameTest is Test {
    ContractName public contractName;

    function setUp() public {
        contractName = new ContractName();
    }

    function testUpdateValue() public {
        uint256 newValue = 50;

        vm.expectEmit(true, true, true, true);
        emit ValueUpdated(0, newValue);

        contractName.updateValue(newValue);

        assertEq(contractName.value(), newValue);
    }

    function testCannotSetInvalidValue() public {
        vm.expectRevert(ContractName.ContractName_InvalidValue.selector);
        contractName.updateValue(101);
    }

    function testFuzz_UpdateValue(uint256 value) public {
        vm.assume(value <= contractName.MAX_VALUE());

        contractName.updateValue(value);

        assertEq(contractName.value(), value);
    }
}
```

**Test Coverage Requirements:**
- Unit tests for all functions
- Edge case testing
- Fuzz testing for numeric inputs
- Integration tests for multi-contract flows
- Minimum 90% coverage

**Running Tests:**
```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path tests/unit/ContractName.t.sol

# Run with verbosity
forge test -vvv

# Run with gas reporting
forge test --gas-report

# Run with coverage
forge coverage
```

### Submitting Code Changes

```bash
# 1. Create feature branch
git checkout -b feat/add-new-curve

# 2. Implement changes
# - Write code
# - Write tests
# - Update documentation

# 3. Run tests
forge test
forge coverage

# 4. Run formatter
forge fmt

# 5. Run linter
bun run lint

# 6. Commit changes
git add .
git commit -m "feat: add exponential bonding curve implementation"

# 7. Push and create PR
git push origin feat/add-new-curve
```

## Contributing Examples

### Code Example Standards

**TypeScript Examples:**
```typescript
/**
 * Example: Depositing into a vault
 *
 * This example shows how to deposit TRUST tokens into a vault
 * and receive shares in return.
 */

import { createWalletClient, createPublicClient, http, parseEther, formatEther } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base } from 'viem/chains';

// Setup clients
const account = privateKeyToAccount('0xPRIVATE_KEY');

const publicClient = createPublicClient({
  chain: base,
  transport: http('https://rpc.example.com')
});

const walletClient = createWalletClient({
  account,
  chain: base,
  transport: http('https://rpc.example.com')
});

async function depositExample() {
  try {
    // Parameters
    const termId = '0x...';
    const curveId = 1;
    const assets = parseEther('10');
    const receiver = account.address;

    // 1. Approve TRUST
    console.log('Approving TRUST...');
    const approveHash = await walletClient.writeContract({
      address: TRUST_ADDRESS,
      abi: TRUST_ABI,
      functionName: 'approve',
      args: [MULTIVAULT_ADDRESS, assets]
    });
    await publicClient.waitForTransactionReceipt({ hash: approveHash });

    // 2. Deposit
    console.log('Depositing...');
    const depositHash = await walletClient.writeContract({
      address: MULTIVAULT_ADDRESS,
      abi: MULTIVAULT_ABI,
      functionName: 'deposit',
      args: [termId, curveId, assets, receiver]
    });
    const receipt = await publicClient.waitForTransactionReceipt({ hash: depositHash });

    console.log('Deposit successful!');
    console.log('Transaction hash:', receipt.transactionHash);

    // 3. Check balance
    const balance = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: MULTIVAULT_ABI,
      functionName: 'balanceOf',
      args: [receiver, termId, curveId]
    });
    console.log('New balance:', formatEther(balance), 'shares');
  } catch (error) {
    console.error('Deposit failed:', error.message);
  }
}

// Run example
depositExample();
```

**Python Examples:**
```python
"""
Example: Depositing into a vault

This example shows how to deposit TRUST tokens into a vault
and receive shares in return.
"""

from web3 import Web3
from eth_account import Account

# Setup
w3 = Web3(Web3.HTTPProvider('https://rpc.example.com'))
account = Account.from_key('PRIVATE_KEY')

# Contract instances
trust = w3.eth.contract(address=TRUST_ADDRESS, abi=TRUST_ABI)
multi_vault = w3.eth.contract(address=MULTIVAULT_ADDRESS, abi=MULTIVAULT_ABI)

def deposit_example():
    try:
        # Parameters
        term_id = bytes.fromhex('...')
        curve_id = 1
        assets = w3.to_wei(10, 'ether')
        receiver = account.address

        # 1. Approve TRUST
        print('Approving TRUST...')
        approve_tx = trust.functions.approve(
            MULTIVAULT_ADDRESS,
            assets
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address)
        })

        signed_approve = account.sign_transaction(approve_tx)
        approve_hash = w3.eth.send_raw_transaction(signed_approve.rawTransaction)
        w3.eth.wait_for_transaction_receipt(approve_hash)

        # 2. Deposit
        print('Depositing...')
        deposit_tx = multi_vault.functions.deposit(
            term_id,
            curve_id,
            assets,
            receiver
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address)
        })

        signed_deposit = account.sign_transaction(deposit_tx)
        deposit_hash = w3.eth.send_raw_transaction(signed_deposit.rawTransaction)
        receipt = w3.eth.wait_for_transaction_receipt(deposit_hash)

        print(f'Deposit successful! Tx: {receipt.transactionHash.hex()}')

        # 3. Check balance
        balance = multi_vault.functions.balanceOf(receiver, term_id, curve_id).call()
        print(f'New balance: {w3.from_wei(balance, "ether")} shares')

    except Exception as e:
        print(f'Deposit failed: {str(e)}')

if __name__ == '__main__':
    deposit_example()
```

## Pull Request Process

### Before Submitting

- [ ] Code compiles without errors
- [ ] All tests pass
- [ ] Code coverage meets requirements (90%+)
- [ ] Code formatted (`forge fmt`)
- [ ] Linting passes (`bun run lint`)
- [ ] Documentation updated
- [ ] Examples added/updated if applicable
- [ ] CHANGELOG.md updated (for significant changes)

### PR Template

```markdown
## Description

Brief description of changes.

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Related Issues

Closes #123

## Testing

Describe testing performed.

## Checklist

- [ ] Tests pass
- [ ] Documentation updated
- [ ] Code formatted
- [ ] Lint passes
```

### Review Process

1. **Automated Checks**: CI runs tests, coverage, linting
2. **Code Review**: Maintainers review code quality and design
3. **Testing**: Reviewers may test changes locally
4. **Approval**: Requires approval from 1+ maintainers
5. **Merge**: Maintainer merges after approval

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards others

### Unacceptable Behavior

- Harassment or discriminatory comments
- Trolling or inflammatory comments
- Public or private harassment
- Publishing others' private information
- Other conduct inappropriate in a professional setting

### Enforcement

Violations may result in:
- Warning
- Temporary ban
- Permanent ban

Report violations to: conduct@intuition.systems

## Getting Help

### Resources

- **Documentation**: [docs.intuition.systems](https://docs.intuition.systems)
- **Discord**: [discord.gg/intuition](https://discord.gg/intuition) #dev-support
- **GitHub Discussions**: [github.com/0xIntuition/intuition-contracts-v2/discussions](https://github.com/0xIntuition/intuition-contracts-v2/discussions)

### Asking Questions

**Good Question:**
```
I'm trying to implement a custom bonding curve but getting a
revert when registering it. I've implemented IBaseCurve and
all required functions. Here's my code: [link]

Error: "BondingCurveRegistry_InvalidCurve"

What am I missing?
```

**What Makes It Good:**
- Clear description of goal
- Specific error message
- Code shared
- What you've already tried

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (BUSL-1.1).

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Mentioned in release notes (for significant contributions)
- Thanked in community channels

## Questions?

Have questions about contributing? Ask in:
- Discord: #dev-support channel
- GitHub Discussions

Thank you for contributing to Intuition Protocol!

---

**Last Updated**: December 2025
