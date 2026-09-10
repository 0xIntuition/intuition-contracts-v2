# Integrations

Possible vulnerabilities while integrating popular external protocols

Total items: 56

## AAVE / Compound

### SOL-Integrations-AC-1: Does the protocol use cETH token?
- **Risk:** The absence of the `underlying()` function in the cETH token contract can cause integration issues.
- **Fix:** Double check the protocol works as expected when integrating cETH token.

### SOL-Integrations-AC-2: What happens if the utilization rate is too high, and collateral cannot be retrieved?
- **Risk:** A high utilization rate can potentially mean that there aren't enough assets in the pool to allow users to withdraw their collateral.
- **Fix:** Ensure that there are mechanisms to handle user withdrawal when the utilization rate is high.

### SOL-Integrations-AC-3: What happens if the protocol is paused?
- **Risk:** If the AAVE protocol is paused, the protocol can not interact with it.
- **Fix:** Ensure the protocol behaves as expected when the AAVE protocol is paused.

### SOL-Integrations-AC-4: What happens if the pool becomes deprecated?
- **Risk:** Pools can be deprecated.
- **Fix:** Ensure the protocol behaves as expected when the Pools are paused.

### SOL-Integrations-AC-5: What happens if assets you lend/borrow are within the same eMode category?
- **Risk:** Lending and borrowing assets within the same eMode category might have rules or limitations.
- **Fix:** Ensure the protocol behaves as expected when interacting with assets in the same eMode category.

### SOL-Integrations-AC-6: Do flash loans on Aave inflate the pool index?
- **Risk:** Flash loans can influence the pool index (a maximum of 180 flashloans can be performed within a block).
- **Fix:** Implement mechanisms to manage the effects of flash loans on the pool index.

### SOL-Integrations-AC-7: Does the protocol properly implement AAVE/COMP reward claims?
- **Risk:** Misimplementation of reward claims can lead to users not receiving their correct rewards.
- **Fix:** Ensure a proper and tested implementation of AAVE/COMP reward claims.

### SOL-Integrations-AC-8: On AAVE, what happens if a user reaches the maximum debt on an isolated asset?
- **Risk:** Reaching the maximum debt on an isolated asset can result in denial-of-service or other limitations on user actions.
- **Fix:** Ensure that the protocol works as expected when a user reaches the maximum debt.

### SOL-Integrations-AC-9: Does borrowing an AAVE siloed asset restrict borrowing other assets?
- **Risk:** Borrowing a siloed asset on Aave will prohibit users from borrowing other assets.
- **Fix:** Make use of `getSiloedBorrowing(address asset)` to prevent unexpected problems.
- **Refs:** 1 case(s)
  - https://docs.aave.com/developers/whats-new/siloed-borrowing

## Balancer

### SOL-Integrations-Balancer-1: Does the protocol use the Balancer's flashloan?
- **Risk:** Balancer vault does not charge any fees for flash loans at the moment. However, it is possible Balancer implements fees for flash loans in the future.
- **Fix:** Ensure the protocol repays the fee together with the original debt on repayment in the `receiveFlashLoan` function.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/receiveflashloan-does-not-account-for-fees-trailofbits-none-lindy-labs-sandclock-pdf

### SOL-Integrations-Balancer-2: Does the protocol use Balancer's Oracle? (getTimeWeightedAverage)
- **Risk:** The price will only be updated whenever a transaction (e.g. swap) within the Balancer pool is triggered. Due to the lack of updates, the price provided by Balancer Oracle will not reflect the true value of the assets.
- **Fix:** Do not use the Balancer's oracle for any pricing.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-13-rely-on-balancer-oracle-which-is-not-updated-frequently-sherlock-notional-notional-git

### SOL-Integrations-Balancer-3: Does the protocol use Balancer's Boosted Pool?
- **Risk:** Balancer's Boosted Pool uses Phantom BPT where all pool tokens are minted at the time of pool creation and are held by the pool itself. Therefore, virtualSupply should be used instead of totalSupply to determine the amount of BPT supply in circulation.
- **Fix:** Ensure the protocol uses the correct function to get the total BPT supply in circulation.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/h-7-totalbptsupply-will-be-excessively-inflated-sherlock-notional-notional-update-git

### SOL-Integrations-Balancer-4: Does the protocol use Balancer vault pool liquidity status for any pricing?
- **Risk:** Balancer vault does not charge any fees for flash loans at the moment. However, it is possible Balancer implements fees for flash loans in the future.
- **Fix:** Balancer pools are susceptible to manipulation of their external queries, and all integrations must now take an extra step of precaution when consuming data. Via readonly reentrancy, an attacker can force token balances and BPT supply to be out of sync, creating very inaccurate BPT prices.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/h-13-balancerpairoracle-can-be-manipulated-using-read-only-reentrancy-sherlock-none-blueberry-update-git

## Chainlink / CCIP

### SOL-Integrations-Chainlink-CCIP-1: Does the receiver contract's `_ccipReceive` function properly validate the `sourceChainSelector` and `sender` address against an allowlist?
- **Risk:** Receiver contracts might process messages from unintended source chains or senders if they don't validate the origin.
- **Fix:** Implement checks within `_ccipReceive` to verify the `any2EvmMessage.sourceChainSelector` and decoded `any2EvmMessage.sender` against administratively controlled allowlists.

### SOL-Integrations-Chainlink-CCIP-2: Does the sender contract validate the `destinationChainSelector` against an allowlist before calling `ccipSend`?
- **Risk:** Sender contracts might accidentally send messages and tokens to unintended or unsupported destination chains.
- **Fix:** Implement checks in the sending function to ensure the `destinationChainSelector` corresponds to an explicitly allowlisted chain.

### SOL-Integrations-Chainlink-CCIP-3: Does the receiver contract properly decode data (`any2EvmMessage.data`) ?
- **Risk:** The encoding on the source chain and decoding on the destination chain must maintain precise structural consistency. 
- **Fix:** Standardize both contracts to use identical ABI encoding/decoding patterns with explicit type declarations and thorough parameter validation to ensure cross-chain message integrity.

### SOL-Integrations-Chainlink-CCIP-4: Does the application logic account for the potential latency introduced by waiting for source chain finality as defined by CCIP?
- **Risk:** Applications assuming immediate cross-chain execution might behave unexpectedly due to varying finality times across blockchains which CCIP respects.
- **Fix:** Design application logic to be aware of and tolerant to CCIP execution latencies, which depend on the source chain's finality mechanism (finality tag or block depth).
- **Refs:** 1 case(s)
  - https://docs.chain.link/ccip/concepts/ccip-execution-latency#finality-by-blockchain

### SOL-Integrations-Chainlink-CCIP-5: Are the correct types of token pools (e.g., `BurnMintTokenPool`, `LockReleaseTokenPool`) deployed on the source and destination chains consistent with the desired token handling mechanism?
- **Risk:** Deploying mismatched pool types (e.g., expecting Lock & Mint but deploying Burn & Mint on the destination) will lead to failed transfers or incorrect token handling.
- **Fix:** Verify that the deployed token pool contracts on each chain match the intended cross-chain mechanism (Burn & Mint requires BurnMint pools; Lock & Mint requires LockRelease on source, BurnMint on destination, etc.).
- **Refs:** 1 case(s)
  - https://docs.chain.link/ccip/concepts/cross-chain-tokens#token-handling-mechanisms-and-token-pool-deployment

### SOL-Integrations-Chainlink-CCIP-6: Is proper router address verification implemented in the ccipReceive method?
- **Risk:** Without proper router validation, any address can spoof messages, potentially compromising contract security and asset integrity.
- **Fix:** Implement a router address verification check that validates msg.sender against a trusted router address.
- **Refs:** 1 case(s)
  - https://docs.chain.link/ccip/best-practices#verify-router-addresses

### SOL-Integrations-Chainlink-CCIP-7: Are extraArgs parameters hardcoded instead of mutable in cross-chain message configurations?
- **Risk:** Hardcoded extraArgs parameters prevent adaptation to future CCIP protocol upgrades and gas requirement changes, potentially causing cross-chain transactions to fail or become incompatible with network upgrades.
- **Fix:** Implement extraArgs as mutable parameters that can be configured off-chain or via updateable contract variables rather than hardcoding them directly in the contract logic.
- **Refs:** 1 case(s)
  - https://docs.chain.link/ccip/best-practices#using-extraargs

### SOL-Integrations-Chainlink-CCIP-8: Is there a proper failure handling mechanism for CCIP messages to prevent blocking after Smart Execution window expiration?
- **Risk:** When a CCIP message fails and the Smart Execution time window (8 hours) expires, all subsequent messages from the same sender will be blocked until the failed message succeeds, potentially causing permanent denial of service if the message cannot be fixed.
- **Fix:** Implement robust error handling in CCIPReceiver implementation with try/catch blocks and recovery mechanisms to ensure messages can be successfully processed even under unexpected conditions.
- **Refs:** 1 case(s)
  - https://solodit.cyfrin.io/issues/m-04-price-updating-mechanism-can-break-code4rena-renzo-renzo-git

## Chainlink / VRF

### SOL-Integrations-Chainlink-VRF-1: Are all parameters properly verified when Chainlink VRF is called?
- **Risk:** If the parameters are not thoroughly verified when Chainlink VRF is called, the `fullfillRandomWord` function will not revert but return an incorrect value.
- **Fix:** Ensure that all parameters passed to Chainlink VRF are verified to ensure the correct operation of `fullfillRandomWord`.

### SOL-Integrations-Chainlink-VRF-2: Is it guaranteed that the operator holds sufficient LINK in the subscription?
- **Risk:** Chainlink VRF can go into a pending state if there's insufficient LINK in the subscription. Once the subscription is refilled, the transaction can potentially be frontrun, introducing vulnerabilities.
- **Fix:** Ensure the pending subscription does not affect the protocol's functionality.

### SOL-Integrations-Chainlink-VRF-3: Is a sufficiently high request confirmation number chosen considering chain re-orgs?
- **Risk:** Not choosing a high enough request confirmation number can pose risks, especially in the context of chain re-orgs.
- **Fix:** Evaluate the chain's vulnerability to re-orgs and adjust the request confirmation number accordingly.
- **Refs:** 1 case(s)
  - https://github.com/pashov/audits/blob/master/solo/NFTLoots-security-review.md#c-01-polygon-chain-reorgs-will-often-change-game-results

### SOL-Integrations-Chainlink-VRF-4: Are measures in place to prevent VRF calls from being frontrun?
- **Risk:** VRF calls can be frontrun and it's crucial to ensure that the user interactions are closed before the VRF call to prevent this.
- **Fix:** Ensure the implementation closes the user interaction phase before initiating the VRF call.

## Gnosis Safe

### SOL-Integrations-GS-1: Do your modules execute the Guard's hooks?
- **Risk:** Failing to execute the Guard's hooks  (`checkTransaction()`, `checkAfterExecution()`) can bypass critical security checks implemented in those hooks.
- **Fix:** Ensure that all modules correctly execute the Guard's hooks as intended.

### SOL-Integrations-GS-2: Does the `execTransactionFromModule()` function increment the nonce?
- **Risk:** If the nonce is not incremented in `execTransactionFromModule()`, it can cause issues when relying on it for signatures.
- **Fix:** Ensure increase nonce inside the function `execTransactionFromModule()`.

## LayerZero

### SOL-Integrations-LayerZero-1: Does the `_debitFrom` function in ONFT properly validate token ownership and transfer permissions?
- **Risk:** It's crucial that the `_debitFrom` function verifies whether the specified owner is the actual owner of the tokenId and if the sender has the correct permissions to transfer the token.
- **Fix:** Ensure thorough checks and validations are performed in the `_debitFrom` function to maintain token security.
- **Refs:** 1 case(s)
  - https://composable-security.com/blog/secure-integration-with-layer-zero/

### SOL-Integrations-LayerZero-2: Which type of mechanism are utilized? Blocking or non-blocking?
- **Risk:** Using blocking mechanism can potentially lead to a Denial-of-Service (DoS) attack.
- **Fix:** Consider using non-blocking mechanism to prevent potential DoS attacks.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/h-06-attacker-can-block-layerzero-channel-code4rena-velodrome-finance-velodrome-finance-contest-git

### SOL-Integrations-LayerZero-3: Is gas estimated accurately for cross-chain messages?
- **Risk:** Inaccurate gas estimation can result in cross-chain message failures.
- **Fix:** Implement mechanisms to estimate gas accurately.

### SOL-Integrations-LayerZero-4: Is the `_lzSend` function correctly utilized when inheriting LzApp?
- **Risk:** When inheriting LzApp, direct calls to `lzEndpoint.send` can introduce vulnerabilities. Using `_lzSend` is the recommended approach.
- **Fix:** Ensure that the `_lzSend` function is used instead of making direct calls to `lzEndpoint.send`.

### SOL-Integrations-LayerZero-5: Is the `ILayerZeroUserApplicationConfig` interface correctly implemented?
- **Risk:** The User Application should include the `forceResumeReceive` function to handle unexpected scenarios and unblock the message queue when needed.
- **Fix:** Implement the `ILayerZeroUserApplicationConfig` interface and ensure that the `forceResumeReceive` function is present and functional.

### SOL-Integrations-LayerZero-6: Are default contracts used?
- **Risk:** Default configuration contracts are upgradeable by the LayerZero team.
- **Fix:** Configure the applications uniquely and avoid using default settings.

### SOL-Integrations-LayerZero-7: Is the correct number of confirmations chosen for the chain?
- **Risk:** Choosing an inappropriate number of confirmations can introduce risks, especially considering past reorg events on the chain.
- **Fix:** Evaluate the chain's history and potential vulnerabilities to determine the optimal number of confirmations.

## LSD / cbETH

### SOL-Integrations-LSD-cbETH-1: How is the control over the `cbETH`/`ETH` rate determined? Are there specific addresses with this capability due to the `onlyOracle` modifier?
- **Risk:** The rate between `cbETH` and `ETH` being controllable by a few addresses can introduce centralization risks and potential manipulations.
- **Fix:** Any address with `onlyOracle` permissions should be scrutinized and their actions should be transparent to the community.

### SOL-Integrations-LSD-cbETH-2: How does the system handle potential decreases in the `cbETH`/`ETH` rate?
- **Risk:** The rate of `cbETH` to `ETH` can decrease, which can impact users who hold or interact with `cbETH`.
- **Fix:** Implement mechanisms to inform users about the current `cbETH`/`ETH` rate. Consider providing alerts or notifications for significant rate changes. Ensure there's a mechanism to handle or rectify situations where the rate decreases dramatically.

## LSD / rETH

### SOL-Integrations-LSD-rETH-1: Does the application account for potential penalties or slashes?
- **Risk:** Validators on the Ethereum 2.0 Beacon Chain can be penalized or slashed for misbehavior. This can affect the value of `rETH`.
- **Fix:** Implement mechanisms to account for potential penalties or slashes that can impact the value of `rETH`.

### SOL-Integrations-LSD-rETH-2: How does the system manage rewards accrued from staking?
- **Risk:** Staking on the Ethereum 2.0 Beacon Chain accrues rewards. The system should account for these rewards when dealing with `rETH`.
- **Fix:** Ensure proper distribution or accumulation of rewards in the system's `rETH` management.

### SOL-Integrations-LSD-rETH-3: Does the application handle potential reverts in the `burn()` function when there's insufficient ether in the `RocketDepositPool`?
- **Risk:** If there's not enough ether in the `RocketDepositPool` contract, the `burn()` function can fail. It's important for the system to handle these failures gracefully.
- **Fix:** Ensure there's a mechanism to either prevent calls to `burn()` when there's insufficient ether or handle the revert gracefully, informing the user appropriately.

### SOL-Integrations-LSD-rETH-4: What measures are in place to counteract potential consensus attacks on RPL nodes?
- **Risk:** There's a risk of consensus attacks on RPL nodes where malicious nodes may submit incorrect exchange rate data, leading to discrepancies.
- **Fix:** Implement a system in place to quickly rectify incorrect data submissions by nodes.

### SOL-Integrations-LSD-rETH-5: How does the system handle the conversion between `ETH` and `rETH`?
- **Risk:** The conversion rate between `ETH` and `rETH` might change over time based on the rewards accrued from staking. Ensure this dynamic is properly captured.
- **Fix:** Integrate accurate conversion mechanisms that consider the ever-changing staking rewards when converting between `ETH` and `rETH`.

## LSD / sfrxETH

### SOL-Integrations-LSD-sfrxETH-1: How does the system handle potential detachment of `sfrxETH` from `frxETH` during reward transfers?
- **Risk:** If `sfrxETH` detaches from `frxETH` during reward transfers, it could cause discrepancies in expected and actual values, especially if these transfers are controlled by a centralized entity like the Frax team's multi-sig contract.
- **Fix:** Ensure there's transparency around the actions of the Frax team's multi-sig contract. Consider mechanisms to alert users or stakeholders about discrepancies between `sfrxETH` and `frxETH`.

### SOL-Integrations-LSD-sfrxETH-2: Is the stability of the `sfrxETH`/`ETH` rate guaranteed or can it decrease in the future?
- **Risk:** While the `sfrxETH`/`ETH` rate might be stable now, changes in the future could impact users and stakeholders, especially if they're not forewarned.
- **Fix:** Provide clear documentation and alerts about potential changes to the `sfrxETH`/`ETH` rate. Ensure users are informed well in advance about any planned changes that could affect the rate.

## LSD / stETH

### SOL-Integrations-LSD-stETH-1: Is the application aware that `stETH` is a rebasing token?
- **Risk:** `stETH` rebases, which can introduce complexities when integrated with DeFi platforms. Using `wstETH` can simplify integrations as it is non-rebasing.
- **Fix:** Consider using `wstETH` for simpler DeFi integrations and to avoid complexities associated with rebasing tokens.

### SOL-Integrations-LSD-stETH-2: Are you aware of the overhead when withdrawing `stETH`/`wstETH`?
- **Risk:** Withdrawing `stETH` or `wstETH` can introduce overheads, due to various problems like queue time, receipt of an NFT, and withdrawal amount limits.
- **Fix:** Ensure account for these overheads and constraints in the protocol logic.

### SOL-Integrations-LSD-stETH-3: Does the application handle conversions between `stETH` and `wstETH` correctly?
- **Risk:** Converting between `stETH` and `wstETH` can be tricky due to the rebasing nature of `stETH`. It's crucial to handle these conversions correctly to avoid potential issues.
- **Fix:** Ensure that the rebasing characteristics of `stETH` are properly managed when converting between `stETH` and `wstETH`.

## Uniswap

### SOL-Integrations-Uniswap-1: Is the slippage calculated on-chain?
- **Risk:** ON-chain slippage calculation can be manipulated.
- **Fix:** Allow users to specify the slippage parameter in the actual asset amount which was calculated off-chain.
- **Refs:** 1 case(s)
  - https://dacian.me/defi-slippage-attacks#heading-on-chain-slippage-calculation-can-be-manipulated

### SOL-Integrations-Uniswap-2: Are there refunds after swaps?
- **Risk:** In case of failed or partially filled orders, the protocol must issue refunds to the users.
- **Fix:** Implement a refund mechanism to handle failed or partially filled swaps.

### SOL-Integrations-Uniswap-3: Is the order of `token0` and `token1` consistent across chains?
- **Risk:** The order of `token0` and `token1` in AMM pools may vary depending on the chain, which can lead to inconsistencies.
- **Fix:** Always verify the order of tokens when interacting with different chains to avoid potential issues.

### SOL-Integrations-Uniswap-4: Are the pools that are being interacted with whitelisted?
- **Risk:** Missing verification on the interacting pools can introduce risks.
- **Fix:** Ensure pools are whitelisted or verify the pool's factory address before any interactions.

### SOL-Integrations-Uniswap-5: Is there a reliance on pool reserves?
- **Risk:** Relying on pool reserves can be risky, as they can be manipulated, especially using a flashloan.
- **Fix:** Implement alternative methods or checks without relying solely on pool reserves.

### SOL-Integrations-Uniswap-6: Is `pool.swap()` directly used?
- **Risk:** Directly using `pool.swap()` can bypass certain security mechanisms.
- **Fix:** Always use the Router contract to handle swaps, providing an added layer of security and standardization.

### SOL-Integrations-Uniswap-7: Is `unchecked` used properly with Uniswap's math libraries?
- **Risk:** Uniswap's TickMath and FullMath libraries require careful usage of `unchecked` due to solidity version specifics.
- **Fix:** Review and test the use of `unchecked` in contracts utilizing Uniswap's math libraries to ensure safety and correctness.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/use-unchecked-intickmathsol-andfullmathsol-spearbit-overlay-pdf

### SOL-Integrations-Uniswap-8: Is the slippage parameter enforced at the last step before transferring funds to users?
- **Risk:** Enforcing slippage parameters for intermediate swaps but not the final step can result in users receiving less tokens than their specified minimum
- **Fix:** Enforce slippage parameter as the last step before transferring funds to users
- **Refs:** 1 case(s)
  - https://dacian.me/defi-slippage-attacks#heading-mintokensout-for-intermediate-not-final-amount

### SOL-Integrations-Uniswap-9: Is `pool.slot0` being used to calculate sensitive information like current price and exchange rates?
- **Risk:** `pool.slot0` can be easily manipulated via flash loans to sandwich attack users.
- **Fix:** Use UniswapV3 TWAP or Chainlink Price Oracle.
- **Refs:** 3 case(s)
  - https://solodit.xyz/issues/h-4-no-slippage-protection-during-repayment-due-to-dynamic-slippage-params-and-easily-influenced-slot0-sherlock-real-wagmi-2-git
  - https://solodit.xyz/issues/h-02-use-of-slot0-to-get-sqrtpricelimitx96-can-lead-to-price-manipulation-code4rena-maia-dao-ecosystem-maia-dao-ecosystem-git
  - https://docs.uniswap.org/concepts/protocol/oracle

### SOL-Integrations-Uniswap-10: Is a hard-coded fee tier parameter being used?
- **Risk:** In UniswapV3 liquidity can be spread across multiple fee tiers. If a function which initiates a uni v3 swap hard-codes the fee tier parameter, this can have several negative effects.
- **Fix:** Functions allowing users to perform uni v3 swaps should allow users to pass in the fee tier parameter.
- **Refs:** 1 case(s)
  - https://dacian.me/defi-slippage-attacks#heading-hard-coded-fee-tier-in-uniswapv3-swap
