# Multi-chain/Cross-chain



Total items: 13

## (general)

### SOL-McCc-1: Are there assumption of consistency in the `block.number` or `block.timestamp` across chains?
- **Risk:** Block time can vary across different chains, leading to potential timing discrepancies.
- **Fix:** Avoid comparing timestamp or block numbers for different chains.
- **Refs:** 1 case(s)
  - https://solodit.cyfrin.io/issues/m-06-l1xrenzobridge-and-l2xrenzobridge-uses-the-blocktimestamp-as-dependency-which-can-cause-issues-code4rena-renzo-renzo-git

### SOL-McCc-2: Has the protocol been checked for the target chain differences?
- **Risk:** Understanding the differences between chains is vital for ensuring compatibility and preventing unexpected behaviors.
- **Fix:** Regularly check for chain differences and update the protocol accordingly.
- **Refs:** 2 case(s)
  - https://www.evmdiff.com/diff?base=1&target=10
  - https://github.com/0xJuancito/multichain-auditor#differences-from-ethereum

### SOL-McCc-3: Are the EVM opcodes and operations used by the protocol compatible across all targeted chains?
- **Risk:** Incompatibility can arise when the protocol uses EVM operations not supported on certain chains.
- **Fix:** Review and ensure compatibility for chains like Arbitrum and Optimism.
- **Refs:** 2 case(s)
  - https://docs.arbitrum.io/solidity-support
  - https://community.optimism.io/docs/developers/build/differences/#transaction-costs

### SOL-McCc-4: Does the expected behavior of `tx.origin` and `msg.sender` remain consistent across all deployment chains?
- **Risk:** Different chains might interpret these values differently, leading to unexpected behaviors.
- **Fix:** Test and verify the behavior on all targeted chains.
- **Refs:** 1 case(s)
  - https://community.optimism.io/docs/developers/build/differences/#opcode-differences

### SOL-McCc-5: Is there any possibility of exploiting low gas fees to execute many transactions?
- **Risk:** Some attacks become viable with low gas costs or when a large number of transactions can be processed.
- **Fix:** Evaluate and mitigate potential attack vectors associated with gas fees.
- **Refs:** 1 case(s)
  - https://github.com/0xJuancito/multichain-auditor#gas-fees

### SOL-McCc-6: Is there consistency in ERC20 decimals across chains?
- **Risk:** Decimals in ERC20 tokens can differ across chains.
- **Fix:** Ensure consistent ERC20 decimals or implement chain-specific adjustments.
- **Refs:** 1 case(s)
  - https://github.com/0xJuancito/multichain-auditor#erc20-decimals

### SOL-McCc-7: Have contract upgradability implications been evaluated on different chains?
- **Risk:** Contracts may have different upgradability properties depending on the chain, like USDT being upgradable on Polygon but not on Ethereum.
- **Fix:** Verify and document upgradability characteristics for each chain.

### SOL-McCc-8: Have cross-chain messaging implementations been thoroughly reviewed for permissions and functionality?
- **Risk:** Cross-chain messaging requires robust security checks to ensure the correct permissions and intended functionality.
- **Fix:** Double check the access control over cross-chain messaging components.

### SOL-McCc-9: Is there a whitelist of compatible chains?
- **Risk:** Allowing messages from an unsupported chain can lead to unpredictable results.
- **Fix:** Implement a whitelist to prevent messages from unsupported chains.

### SOL-McCc-10: Have contracts been checked for compatibility when deployed to the zkSync Era?
- **Risk:** zkSync Era might have specific requirements or differences when compared to standard Ethereum deployments.
- **Fix:** Review and ensure compatibility before deploying contracts to zkSync Era.
- **Refs:** 1 case(s)
  - https://era.zksync.io/docs/reference/architecture/differences-with-ethereum.html

### SOL-McCc-11: Is block production consistency ensured?
- **Risk:** Inconsistent block production can lead to unexpected application behaviors.
- **Fix:** Develop with the assumption that block production may not always be consistent.

### SOL-McCc-12: Is `PUSH0` opcode supported for Solidity version `>=0.8.20`?
- **Risk:** `PUSH0` might not be supported on all chains, leading to potential incompatibility issues.
- **Fix:** Ensure if `PUSH0` is supported in the target chain.
- **Refs:** 1 case(s)
  - https://github.com/0xJuancito/multichain-auditor#support-for-the-push0-opcode

### SOL-McCc-13: Are there any attributes attached to the bridged assets?
- **Risk:** When assets (e.g. tokens) are bridged across chains, the relevant attributes (e.g. approval) must be bridged or reset accordingly.
- **Fix:** Ensure accounting all the relevant attributes when assets are bridged.
- **Refs:** 1 case(s)
  - https://solodit.cyfrin.io/issues/not-update-rewards-in-handleincomingupdate-function-of-sdlpoolprimary-leads-to-incorrect-reward-calculations-codehawks-stakelink-git
