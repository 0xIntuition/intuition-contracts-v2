# Attacker's Mindset

General check items for main attack types.

Total items: 25

## Denial-Of-Service(DOS) Attack

### SOL-AM-DOSA-1: Is the withdrawal pattern followed to prevent denial of service?
- **Risk:** To prevent denial of service attacks during withdrawals, it's critical to follow the withdrawal pattern best practices - pull based approach.
- **Fix:** Implement withdrawal pattern best practices to ensure that contract behavior remains predictable and robust against denial of service attacks.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-06-denial-of-service-contract-owner-could-block-users-from-withdrawing-their-strike-code4rena-putty-putty-contest-git

### SOL-AM-DOSA-2: Is there a minimum transaction amount enforced?
- **Risk:** Enforcing a minimum transaction amount can prevent attackers from clogging the network with zero amount or dust transactions.
- **Fix:** Disallow transactions below a certain threshold to maintain efficiency and prevent denial of service through dust spamming.
- **Refs:** 2 case(s)
  - https://solodit.xyz/issues/h-02-denial-of-service-code4rena-hubble-hubble-contest-git
  - https://solodit.cyfrin.io/issues/m-16-users-can-be-griefed-due-to-lack-of-minimum-size-within-the-loan-and-offer-sherlock-debita-finance-v3-git

### SOL-AM-DOSA-3: How does the protocol handle tokens with blacklisting functionality?
- **Risk:** Tokens with blacklisting capabilities, such as USDC, can pose unique risks and challenges to protocols.
- **Fix:** Account for the possibility of blacklisting within token protocols to ensure continued functionality even if certain addresses are blacklisted.
- **Refs:** 1 case(s)
  - https://solodit.cyfrin.io/issues/m-4-blacklisted-creditor-can-block-all-repayment-besides-emergency-closure-sherlock-real-wagmi-2-git

### SOL-AM-DOSA-4: Can forcing the protocol to process a queue lead to DOS?
- **Risk:** Forcing protocols to process queues, like a queue of dust withdrawals, can be exploited to cause a denial of service.
- **Fix:** Design queue processing in a manner that is resilient to spam and cannot be exploited to cause denial of service.
- **Refs:** 2 case(s)
  - https://solodit.cyfrin.io/?b=false&f=&fc=gte&ff=&fn=1&i=HIGH%2CMEDIUM&p=1&pc=&r=all&s=gas+griefing&t=
  - https://solodit.cyfrin.io/issues/denial-of-slashing-ottersec-none-ethos-evm-pdf

### SOL-AM-DOSA-5: What happens with low decimal tokens that might cause DOS?
- **Risk:** Tokens with low decimals can present issues where the transaction process fails due to rounding to zero amounts.
- **Fix:** Implement logic to handle low decimal tokens in a way that prevents the transaction process from breaking due to insufficient token amounts.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/potential-funds-locked-due-low-token-decimal-and-long-stream-duration-spearbit-locke-pdf

### SOL-AM-DOSA-6: Does the protocol handle external contract interactions safely?
- **Risk:** Protocols must handle interactions with external contracts in a way that does not compromise their functionality if external dependencies fail.
- **Fix:** Ensure robust handling of external contract interactions to maintain protocol integrity regardless of external contract performance.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-09-unhandled-chainlink-revert-would-lock-all-price-oracle-access-code4rena-juicebox-juicebox-v2-contest-git

## Donation Attack

### SOL-AM-DA-1: Does the protocol rely on `balance` or `balanceOf` instead of internal accounting?
- **Risk:** Attackers can manipulate the accounting by donating tokens.
- **Fix:** Implement internal accounting instead of relying on `balanceOf` natively.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/h-02-first-depositor-can-break-minting-of-shares-code4rena-prepo-prepo-contest-git

## Front-running Attack

### SOL-AM-FrA-1: Are "get-or-create" patterns protected against front-running attacks?
- **Risk:** Functions combining resource creation and interaction (like getOrCreateAndUse) are vulnerable to front-running attacks where attackers can create the resource with different parameters before the victim, potentially manipulating prices or conditions.
- **Fix:** Separate creation and interaction into distinct transactions or implement robust protections (parameter validation, relative references instead of absolute values) to ensure safe operation regardless of creation timing.
- **Refs:** 2 case(s)
  - https://solodit.cyfrin.io/issues/h-03-fillorder-executor-can-be-front-run-by-the-order-creator-by-changing-orders-limitprice_e36-the-executors-assets-can-be-stolen-code4rena-init-capital-init-capital-git
  - https://solodit.cyfrin.io/issues/m-01-routergetorcreatepoolandaddliquidity-can-be-frontrunned-which-leads-to-price-manipulation-code4rena-maverick-maverick-git

### SOL-AM-FrA-2: Are two-transaction actions designed to be safe from frontrunning?
- **Risk:** Actions that require two separate transactions may be at risk of frontrunning, where an attacker can intervene between the two calls.
- **Fix:** Ensure critical actions that are split across multiple transactions cannot be interfered with by attackers. This can involve checks or locks between the transactions.
- **Refs:** 1 case(s)
  - https://github.com/sherlock-audit/2022-11-isomorph-judging/issues/47

### SOL-AM-FrA-3: Can users maliciously cause others' transactions to revert by preempting with dust?
- **Risk:** Attackers may cause legitimate transactions to fail by front-running with transactions of negligible amounts.
- **Fix:** Implement checks to prevent transactions with non-material amounts from affecting the contract's state or execution flow.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-12-attacker-can-grift-syndicate-staking-by-staking-a-small-amount-code4rena-stakehouse-protocol-lsd-network-stakehouse-contest-git

### SOL-AM-FrA-4: Is the protocol using a properly user-bound commit-reveal scheme?
- **Risk:** Sensitive on-chain actions can be exposed in the mempool, enabling frontrunning and information exploitation. Effective commit-reveal schemes must bind commitments to specific users and transactions.
- **Fix:** Implement a two-phase process where users first commit a hash containing their address and all transaction parameters, then reveal actual actions after the commitment phase ends, preventing frontrunning and information leakage.
- **Refs:** 2 case(s)
  - https://solodit.cyfrin.io/issues/h01-votes-can-be-duplicated-openzeppelin-uma-audit-phase-1-markdown
  - https://solodit.cyfrin.io/issues/ethregistrarcontrollerregister-is-vulnerable-to-front-running-fixed-consensys-ens-permanent-registrar-markdown

## Griefing Attack

### SOL-AM-GA-1: Is there an external function that relies on states that can be changed by others?
- **Risk:** Malicious actors can prevent regular user transactions by making a slight change to the on-chain states.
- **Fix:** Ensure normal user actions especially important actions like withdrawal and repayment are not disturbed by other actors.
- **Refs:** 3 case(s)
  - https://solodit.xyz/issues/m-10-griefing-attack-to-block-withdraws-code4rena-mochi-mochi-contest-git
  - https://solodit.cyfrin.io/issues/griefing-attack-in-group-ip-management-via-license-token-minting-halborn-story-proof-of-creativity-protocol-markdown
  - https://solodit.cyfrin.io/issues/h-6-loss-of-rewards-due-to-continuous-griefing-attacks-on-l2-environment-sherlock-notional-leveraged-vaults-pendle-pt-and-vault-incentives-git

### SOL-AM-GA-2: Can the contract operations be manipulated with precise gas limit specifications?
- **Risk:** Attackers can supply carefully calculated gas amounts to force specific execution paths in the contract, manipulating its behavior in unexpected ways.
- **Fix:** Implement explicit gas checks before critical operations.
- **Refs:** 3 case(s)
  - https://solodit.cyfrin.io/issues/19573
  - https://solodit.cyfrin.io/issues/2786
  - https://scsfg.io/hackers/griefing/

## Miner Attack

### SOL-AM-MA-1: Is block.timestamp used for time-sensitive operations?
- **Risk:** Miners can manipulate block.timestamp by several seconds, potentially affecting time-dependent contract logic.
- **Fix:** Use block.number instead of timestamps for critical timing operations or ensure manipulation tolerance is acceptable.

### SOL-AM-MA-2: Is the contract using block properties like timestamp or difficulty for randomness generation?
- **Risk:** Block properties (timestamp, difficulty) and other predictable values should not be used for randomness as they can be influenced or predicted by miners.
- **Fix:** Use a secure randomness source like Chainlink VRF, commit-reveal schemes, or a provably fair randomization mechanism instead.
- **Refs:** 1 case(s)
  - https://solodit.cyfrin.io/issues/m-01-randomindex-is-not-truly-random-possibility-of-predictably-minting-a-specific-token-id-code4rena-larvalabs-meebits-larvalabs-meebits-contest-git

### SOL-AM-MA-3: Is contract logic sensitive to transaction ordering?
- **Risk:** Miners control transaction ordering and can exploit this for front-running, back-running, or sandwich attacks.
- **Fix:** Implement protection by allowing users to specify acceptable results that revert transactions when breached.
- **Refs:** 1 case(s)
  - https://solodit.cyfrin.io/issues/20754

## Price Manipulation Attack

### SOL-AM-PMA-1: Is the price calculated by the ratio of token balances?
- **Risk:** Price can be manipulated via flash loans or donations if it is derived from the ratio of token balances.
- **Fix:** Use the Chainlink oracles for the asset prices.
- **Refs:** 3 case(s)
  - https://solodit.xyz/issues/h-05-flash-loan-price-manipulation-in-purchasepyroflan-code4rena-behodler-behodler-contest-git
  - https://solodit.xyz/issues/h-05-underlying-assets-stealing-in-autopxgmx-and-autopxglp-via-share-price-manipulation-code4rena-redacted-cartel-redacted-cartel-contest-git
  - https://solodit.xyz/issues/h-02-use-of-slot0-to-get-sqrtpricelimitx96-can-lead-to-price-manipulation-code4rena-maia-dao-ecosystem-maia-dao-ecosystem-git

### SOL-AM-PMA-2: Is the price calculated from DEX liquidity pool spot prices?
- **Risk:** Spot price readings derived directly from DEX liquidity pools are vulnerable to manipulation through flash loans that can temporarily drain the pools.
- **Fix:** Use TWAP (time-weighted average price) with appropriate time windows based on asset volatility and liquidity, or use reliable oracle solutions.
- **Refs:** 2 case(s)
  - https://solodit.cyfrin.io/issues/h-08-omooracle-getliquidityamounts-uses-spot-price-making-it-manipulatable-pashov-audit-group-none-omo_2025-01-25-markdown
  - https://solodit.cyfrin.io/issues/h-03-the-use-of-spot-price-by-coresaltyfeed-can-lead-to-price-manipulation-and-undesired-liquidations-code4rena-saltyio-saltyio-git

## Reentrancy Attack

### SOL-AM-ReentrancyAttack-1: Is there a view function that can return a stale value during interactions?
- **Risk:** Read-only reentrancy. The read-only reentrancy is a reentrancy scenario where a view function is reentered, which in most cases is unguarded as it does not modify the contract's state. However, if the state is inconsistent, wrong values could be reported. Other protocols relying on a return value can be tricked into reading the wrong state to perform unwanted actions.
- **Fix:** Extend the reentrancy guard to the view functions as well.
- **Refs:** 3 case(s)
  - https://medium.com/@zokyo.io/read-only-reentrancy-attacks-understanding-the-threat-to-your-smart-contracts-99444c0a7334
  - https://solodit.xyz/issues/m-03-read-only-reentrancy-is-possible-code4rena-angle-protocol-angle-protocol-invitational-git
  - https://solodit.xyz/issues/h-13-balancerpairoracle-can-be-manipulated-using-read-only-reentrancy-sherlock-none-blueberry-update-git

### SOL-AM-ReentrancyAttack-2: Is there any state change after interaction to an external contract?
- **Risk:** Untrusted external contract calls could callback leading to unexpected results such as multiple withdrawals or out-of-order events.
- **Fix:** Use check-effects-interactions pattern or reentrancy guards.
- **Refs:** 3 case(s)
  - https://www.geeksforgeeks.org/reentrancy-attack-in-smart-contracts/
  - https://solodit.xyz/issues/m-09-malicious-royalty-recipient-can-steal-excess-eth-from-buy-orders-code4rena-caviar-caviar-private-pools-git
  - https://solodit.xyz/issues/h-01-re-entrancy-in-settleauction-allow-stealing-all-funds-code4rena-kuiper-kuiper-contest-git

## Replay Attack

### SOL-AM-ReplayAttack-1: Are there protections against replay attacks for failed transactions?
- **Risk:** Failed transactions can be susceptible to replay attacks if not properly protected.
- **Fix:** Implement nonce-based or other mechanisms to ensure that each transaction can only be executed once, preventing replay attacks.
- **Refs:** 1 case(s)
  - https://github.com/code-423n4/2022-03-rolla-findings/issues/45

### SOL-AM-ReplayAttack-2: Is there protection against replaying signatures on different chains?
- **Risk:** Signatures valid on one chain may be replayed on another, leading to potential security breaches.
- **Fix:** Use chain-specific parameters or domain separators to ensure signatures are only valid on the intended chain.
- **Refs:** 1 case(s)
  - https://github.com/sherlock-audit/2022-09-harpie-judging/blob/main/004-M/004-m.md

## Rug Pull

### SOL-AM-RP-1: Can the admin of the protocol pull assets from the protocol?
- **Risk:** Some protocols grant an admin with a privilege of pulling assets directly from the protocol. In general, if there is an actor that can affect the user funds directly it must be reported.
- **Fix:** Allow access to only the relevant parts of protocol funds, e.g. by tracking fees internally. Forcing a timelock on the admin actions can be another mitigation.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-06-centralisation-risk-admin-role-of-tokenmanagereth-can-rug-pull-all-eth-from-the-bridge-code4rena-skale-skale-contest-git

## Sandwich Attack

### SOL-AM-SandwichAttack-1: Does the protocol have an explicit slippage protection on user interactions?
- **Risk:** An attacker can monitor the mempool and puts two transactions before and after the user's transaction. For example, when an attacker spots a large trade, executes their own trade first to manipulate the price, and then profits by closing their position after the user's trade is executed.
- **Fix:** Allow users to specify the minimum output amount and revert the transaction if it is not satisfied.
- **Refs:** 2 case(s)
  - https://solodit.xyz/issues/h-12-sandwich-attack-to-accruepremiumandexpireprotections-sherlock-carapace-carapace-git
  - https://solodit.xyz/issues/h-1-adversary-can-sandwich-oracle-updates-to-exploit-vault-sherlock-olympus-olympus-update-git

## Sybil Attack

### SOL-AM-SybilAttack-1: Is there a mechanism depending on the number of users?
- **Risk:** It is very easy to trigger actions using a lot of alternative addresses on blockchain. Any quorum mechanism or utilization based rewarding system can be vulnerable to sybil attacks.
- **Fix:** Do not rely on the number of users in quorum design.
- **Refs:** 3 case(s)
  - https://solodit.xyz/issues/h-7-sybil-on-withdrawal-requests-can-allow-leverage-factor-manipulation-with-flashloans-sherlock-carapace-carapace-git
  - https://solodit.xyz/issues/routers-can-sybil-attack-the-sponsor-vault-to-drain-funds-spearbit-connext-pdf
  - https://solodit.xyz/issues/h-5-staker-rewards-can-be-gathered-with-maximal-multiplier-no-matter-how-borrowers-are-overdue-sherlock-union-finance-union-finance-git
