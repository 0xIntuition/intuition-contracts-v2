# Defi



Total items: 63

## AMM/Swap

### SOL-Defi-AS-1: Is hardcoded slippage used?
- **Risk:** Using hardcoded slippage can lead to poor trades and freezing user funds during times of high volatility.
- **Fix:** Allow users to specify the slippage parameter in the actual asset amount which was calculated off-chain.
- **Refs:** 1 case(s)
  - https://dacian.me/defi-slippage-attacks#heading-on-chain-slippage-calculation-can-be-manipulated

### SOL-Defi-AS-2: Is there a deadline protection?
- **Risk:** Without deadline protection, user transactions are vulnerable to sandwich attacks.
- **Fix:** Allow a user specify the deadline of the swap.
- **Refs:** 1 case(s)
  - https://defihacklabs.substack.com/p/solidity-security-lesson-6-defi-slippage?utm_source=profile&utm_medium=reader2

### SOL-Defi-AS-3: Is there a validation check for protocol reserves?
- **Risk:** Protocols may face risks if reserves are not validated and can be lent out, affecting the system's solvency.
- **Fix:** Ensure reserve validation logic is in place to safeguard the protocol's liquidity and overall health.
- **Refs:** 1 case(s)
  - https://github.com/sherlock-audit/2022-08-sentiment-judging/blob/main/122-M/1-report.md

### SOL-Defi-AS-4: Does the AMM utilize forked code?
- **Risk:** Using forked code, especially from known projects like Uniswap, can introduce known vulnerabilities if not updated or audited properly.
- **Fix:** Review the differences. Utilize tools such as contract-diff.xyz to compare and identify the origin of code snippets.

### SOL-Defi-AS-5: Are there rounding issues in product constant formulas?
- **Risk:** Rounding issues in the formulas can lead to inaccuracies or imbalances in token swaps and liquidity provisions.
- **Fix:** Review the mathematical operations in the AMM's formulas, ensuring they handle rounding appropriately without introducing vulnerabilities.

### SOL-Defi-AS-6: Can arbitrary calls be made from user input?
- **Risk:** Allowing arbitrary calls based on user input can expose the contract to various vulnerabilities.
- **Fix:** Validate and sanitize user inputs. Avoid executing arbitrary calls based solely on input data.

### SOL-Defi-AS-7: Is there a mechanism in place to protect against excessive slippage?
- **Risk:** Without slippage protection, traders might experience unexpected losses due to large price deviations during a trade.
- **Fix:** Incorporate a slippage parameter that users can set to limit their maximum acceptable slippage.

### SOL-Defi-AS-8: Does the AMM properly handle tokens of varying decimal configurations and token types?
- **Risk:** If the AMM doesn't support tokens with varying decimals or types, it might lead to incorrect calculations and potential losses.
- **Fix:** Ensure compatibility with tokens of varying decimal places and validate token types before processing them.

### SOL-Defi-AS-9: Does the AMM support the fee-on-transfer tokens?
- **Risk:** Fee-on-transfer tokens can cause problems because the sending amount and the received amount do not match.
- **Fix:** Ensure the fee-on-transfer tokens are handled correctly if they are supposed to be supported.

### SOL-Defi-AS-10: Does the AMM support the rebasing tokens?
- **Risk:** Rebasing tokens can change the actual balance.
- **Fix:** Ensure the rebasing tokens are handled correctly if they are supposed to be supported.

### SOL-Defi-AS-11: Does the protocol calculate `minAmountOut` before a token swap?
- **Risk:** Protocols integrating AMMs should determine the `minAmountOut` prior to swaps to avoid unfavorable rates. The source of the rates and potential for manipulation should also be considered.
- **Fix:** Ensure that the protocol calculates `minAmountOut` before executing swaps. If external oracles are used, validate their trustworthiness and consider potential vulnerabilities like sandwich attacks.
- **Refs:** 1 case(s)
  - https://blog.chain.link/guide-to-sandwich-attacks/

### SOL-Defi-AS-12: Does the integrating contract verify the caller address in its callback functions?
- **Risk:** Callback functions can be manipulated if they don't validate the calling contract's address. This is especially crucial for functions like `swap()` that involve tokens or assets.
- **Fix:** Implement checks in the callback functions to validate the address of the calling contract. Additionally, review the logic for any potential bypasses to this check.

### SOL-Defi-AS-13: Is the slippage calculated on-chain?
- **Risk:** ON-chain slippage calculation can be manipulated.
- **Fix:** Allow users to specify the slippage parameter in the actual asset amount which was calculated off-chain.
- **Refs:** 1 case(s)
  - https://dacian.me/defi-slippage-attacks#heading-on-chain-slippage-calculation-can-be-manipulated

### SOL-Defi-AS-14: Is the slippage parameter enforced at the last step before transferring funds to users?
- **Risk:** Enforcing slippage parameters for intermediate swaps but not the final step can result in users receiving less tokens than their specified minimum
- **Fix:** Enforce slippage parameter as the last step before transferring funds to users
- **Refs:** 1 case(s)
  - https://dacian.me/defi-slippage-attacks#heading-mintokensout-for-intermediate-not-final-amount

## FlashLoan

### SOL-Defi-FlashLoan-1: Is withdraw disabled in the same block to prevent flashloan attacks?
- **Risk:** Allowing withdrawals within the same block as other interactions may enable attackers to exploit flashloan vulnerabilities.
- **Fix:** Implement a delay or disable withdrawals within the same block where a deposit or loan action took place to mitigate such risks.

### SOL-Defi-FlashLoan-2: Can ERC4626 be manipulated through flashloans?
- **Risk:** ERC4626, the tokenized vault standard, could be susceptible to flashloan attacks if the underlying mechanisms do not adequately account for such threats.
- **Fix:** Ensure that ERC4626-related operations have in-built protections against rapid, in-block actions that could be leveraged by flashloans.
- **Refs:** 1 case(s)
  - https://github.com/code-423n4/2022-01-behodler-findings/issues/304

## General

### SOL-Defi-General-1: Can the protocol handle ERC20 tokens with decimals other than 18?
- **Risk:** Not all ERC20 tokens use 18 decimals. Overlooking this can lead to computation errors.
- **Fix:** Always check and adjust for the decimal count of the ERC20 tokens being handled.

### SOL-Defi-General-2: Are there unexpected rewards accruing for user deposited assets?
- **Risk:** Some protocols or platforms may provide additional rewards for staked or deposited assets. If these rewards are not properly accounted for or managed, it could lead to discrepancies in the user's expected vs actual returns.
- **Fix:** The protocol should have mechanisms in place to track all potential rewards for user deposited assets. Users should be provided with clear interfaces or methods to claim any unexpected rewards to ensure fairness and transparency.

### SOL-Defi-General-3: Could direct transfers of funds introduce vulnerabilities?
- **Risk:** Direct transfers of assets without using the protocol's logic can lead to various problems in accounting especially if the accounting relies on `balanceOf` (or `address.balance`).
- **Fix:** Implement the internal accounting so that it is not be affected by direct transfers.

### SOL-Defi-General-4: Could the initial deposit introduce any issues?
- **Risk:** The first deposit can set certain parameters or conditions that subsequent deposits rely on.
- **Fix:** Test and ensure that the first deposit initializes and sets all necessary parameters correctly.

### SOL-Defi-General-5: Are the protocol token pegged to any other asset?
- **Risk:** The target tokens can be depegged.
- **Fix:** Ensure the protocol behave as expected during the depeg.

### SOL-Defi-General-6: Does the protocol revert on maximum approval to prevent over-allowance?
- **Risk:** Setting high allowances can make funds vulnerable to abuse; protocols sometimes set max to prevent this risk.
- **Fix:** Consider implementing a revert on approval functions when an unnecessarily high allowance is set.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-3-universalapprovemax-will-not-work-for-some-tokens-that-dont-support-approve-typeuint256max-amount-sherlock-dodo-dodo-git

### SOL-Defi-General-7: What would happen if only 1 wei remains in the pool?
- **Risk:** Leaving residual amounts can lead to discrepancies in accounting or locked funds.
- **Fix:** Implement logic to handle minimal residual amounts in the pool.

### SOL-Defi-General-8: Is it possible to withdraw in the same transaction of deposit?
- **Risk:** Protocols often provide various benefits to the depositors based on the deposit amount. This can lead to flashloan-deposit-harvest-withdraw attack cycle.
- **Fix:** Ensure the withdrawal is protected for some blocks after deposit.

### SOL-Defi-General-9: Does the protocol aim to support ALL kinds of ERC20 tokens?
- **Risk:** Not all ERC20 tokens are compliant to the ERC20 standard and there are several weird ERC20 tokens (e.g. Fee-On-Transfer tokens, rebasing tokens, tokens with blacklisting).
- **Fix:** Clarify what kind of tokens are supported and whitelist the ERC20 tokens that the protocol would accept.
- **Refs:** 1 case(s)
  - https://github.com/d-xo/weird-erc20

## Lending

### SOL-Defi-Lending-1: Will the liquidation process function effectively during rapid market downturns?
- **Risk:** Failure to liquidate positions during sharp price drops can result in substantial platform losses.
- **Fix:** Ensure robustness during extreme market conditions.

### SOL-Defi-Lending-2: Can a position be liquidated if the loan remains unpaid or if the collateral falls below the required threshold?
- **Risk:** If positions cannot be liquidated under these circumstances, it poses a risk to lenders who might not recover their funds.
- **Fix:** Ensure a reliable mechanism for liquidating under-collateralized or defaulting loans to safeguard lenders.

### SOL-Defi-Lending-3: Is it possible for a user to gain undue profit from self-liquidation?
- **Risk:** Self-liquidation profit loopholes can lead to potential system abuse and unintended financial consequences.
- **Fix:** Audit and test self-liquidation mechanisms to prevent any exploitative behaviors.

### SOL-Defi-Lending-4: If token transfers or collateral additions are temporarily paused, can a user still be liquidated, even if they intend to deposit more funds?
- **Risk:** Unexpected pauses can place users at risk of unwarranted liquidations, despite their willingness to increase collateral.
- **Fix:** Implement safeguards that protect users from liquidation during operational pauses or interruptions.

### SOL-Defi-Lending-5: If liquidations are temporarily suspended, what are the implications when they are resumed?
- **Risk:** Pausing liquidations can increase the solvency risk and lead to unpredictable behaviors upon resumption.
- **Fix:** Outline clear protocols for pausing and resuming liquidations, ensuring solvency is maintained.

### SOL-Defi-Lending-6: Is it possible for users to manipulate the system by front-running and slightly increasing their collateral to prevent liquidations?
- **Risk:** Lenders must be prevented from griefing via front-running the liquidation.
- **Fix:** Ensure it is not possible to prevent liquidators by any means.

### SOL-Defi-Lending-7: Are all positions, regardless of size, incentivized adequately for liquidation?
- **Risk:** Without proper incentives, small positions might be overlooked, leading to inefficiencies.
- **Fix:** Ensure a balanced incentive structure that motivates liquidators to address positions of all sizes.

### SOL-Defi-Lending-8: Is interest considered during Loan-to-Value (LTV) calculation?
- **Risk:** Omitting interest in LTV calculations can result in inaccurate credit assessments.
- **Fix:** Include accrued interest in LTV calculations to maintain accurate and fair credit evaluations.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/h-7-users-can-be-liquidated-prematurely-because-calculation-understates-value-of-underlying-position-sherlock-blueberry-blueberry-git

### SOL-Defi-Lending-9: Can liquidation and repaying be enabled or disabled simultaneously?
- **Risk:** Protocols might need to ensure that liquidation and repaying mechanisms are either both active or inactive to maintain consistency.
- **Fix:** Review protocol logic to allow or disallow liquidation and repaying functions collectively to avoid operational discrepancies.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-2-liquidations-are-enabled-when-repayments-are-disabled-causing-borrowers-to-lose-funds-without-a-chance-to-repay-sherlock-blueberry-blueberry-git

### SOL-Defi-Lending-10: Is it possible to lend and borrow the same token within a single transaction?
- **Risk:** Protocols that allow the same token to be lent and borrowed in a single transaction may be vulnerable to attacks that exploit rapid price inflation or flash loans to manipulate the system.
- **Fix:** Protocols should implement constraints to prohibit the same token from being used in a lend and borrow action within the same block or transaction, reducing the risk of flash-loan attacks and other manipulative practices.

### SOL-Defi-Lending-11: Is there a scenario where a liquidator might receive a lesser amount than anticipated?
- **Risk:** Discrepancies in liquidation returns can discourage liquidators and impact system stability.
- **Fix:** Ensure a clear and consistent calculation mechanism for liquidation rewards.

### SOL-Defi-Lending-12: Is it possible for a user to be in a condition where they cannot repay their loan?
- **Risk:** Certain scenarios or conditions might prevent a user from repaying their loan, causing them to be perpetually in debt. This can be due to factors such as excessive collateralization, high fees, fluctuating token values, or other unforeseen events.
- **Fix:** Review the lending protocol's logic to ensure there are no conditions that could trap a user in perpetual debt. Implement safeguards to notify or protect users from taking actions that may lead to irrecoverable financial situations.

## Liquid Staking Derivatives

### SOL-Defi-LSD-1: Can a malicious validator front-run setting withdrawal credentials?
- **Risk:** A malicious Ethereum validator can betray a liquid staking protocol by front-running to first call `DepositContract::deposit` sending 1 ETH and passing their own withdrawal credentials; after the protocol's subsequent call succeeds the withdrawal credentials are not overwritten since only the "initial deposit" sets the withdrawals credentials while the second deposit is treated as a "top-up deposit".  The malicious validator now controls 33 ether with 32 ether belonging to the protocol's users and has set their own withdrawal credentials instead of the protocol's withdrawal credentials.
- **Fix:** The function which calls `DepositContract::deposit` should take as input `DepositContract.get_deposit_root` then check that the input deposit root matches the current one. This works as the current deposit root changes with every deposit.

### SOL-Defi-LSD-2: Can the exchange rate repricing update be sandwich attacked to drain ETH from the protocol?
- **Risk:** Liquid staking protocols typically have their own liquid ERC20 token that accrues value against ETH as the protocol receives staking rewards; in the normal course of operations the exchange rate should continually be increasing as the protocol accrues rewards such that the protocol's ERC20 token can be exchanged for increasing amounts of ETH. If the protocol allows instant withdrawals, an attacker can perform a risk-free sandwich attack to drain ETH from the protocol by 1) front-running the exchange rate txn to deposit a large amount of ETH, 2) back-running to withdraw at the increased rate.
- **Fix:** Don't allow instant withdrawals but use a withdrawal queue and run the repricing transaction through flashbots.

### SOL-Defi-LSD-3: Can re-entrancy when ETH is sent during rewards/withdrawals or when NFTs are minted via `_safeMint` (to represent pending withdrawals) be used to drain the protocol's ETH?
- **Risk:** Re-entrancy vulnerabilties can often exist in the reward or withdrawal code of LSD protocols.
- **Fix:** Always follow the Checks-Effects-Interactions pattern; sending ETH or minting NFTs via `_safeMint` should always happen after storage updates.

### SOL-Defi-LSD-4: Can an arbitrary exchange rate be set when processing queued withdrawals?
- **Risk:** If an arbitrary exchange rate can be set when processing queued withdrawals this creates a subtle rug-pull vector of user withdrawals.
- **Fix:** When withdrawals are processed the current exchange rate should be retrieved in the same way as when withdrawals are created.

### SOL-Defi-LSD-5: Can paused states be bypassed to perform restricted actions even when they should be paused?
- **Risk:** LSD protocols often implement pausing of different functionality. Auditors should check if there are any gaps where for example one function is missing a pause check that other related functions contain.
- **Fix:** All related functions should contain the same related pause checks.

### SOL-Defi-LSD-6: Can inter-related storage be corrupted, especially storage related to operators and validators?
- **Risk:** To reduce the gas cost of reading from storage, protocols may use multiple inter-related data structures to store complex information like operator and validator information. Auditors should examine whether functions which update these inter-related data structures can be used to corrupt them by over-writing records which contain indexes into to another storage location.
- **Fix:** Protocols can use invariant fuzz testing with invariants which validate that relationships between inter-related data structures can't be broken by functions which update them.

### SOL-Defi-LSD-7: Does the protocol iterate over the entire set of operators or validators?
- **Risk:** LSD protocols may need to iterate over the entire set of operators or validators which can become exorbitantly expensive or lead to out of gas if the operator or validator set becomes large. In permissionless systems where anyone can create operators or validators this creates a denial of service attack vector.
- **Fix:** Refactor to avoid needing to iterate over the entire operator/validator set. Alternatively only use a small and trusted set of operators/validators.

### SOL-Defi-LSD-8: If using a Proof Of Reserves Oracle, does the protocol check for stale data?
- **Risk:** LSD protocols may use an external Proof of Reserves Oracle to fetch off-chain data for their current ETH reserves. If the protocol doesn't check how long ago the data was last updated it can process stale data as if it were fresh.
- **Fix:** Check the time data was last updated against the Oracle's heartbeat and revert if the data is too old.

### SOL-Defi-LSD-9: Does unnecessary precision loss occur in deposit, withdrawal or reward calculations?
- **Risk:** Mathematical calculations have to be performed in LSD protocol deposit, withdrawal and reward functions. Auditors should check for precision loss issues such as division before multiplication, rounding down to zero etc.
- **Fix:** Don't perform division before multiplication, be aware of rounding down to zero, rounding direction, unsafe casting etc.

## Oracle

### SOL-Defi-Oracle-1: Is the Oracle using deprecated Chainlink functions?
- **Risk:** Usage of deprecated Chainlink functions like latestRoundData() might return stale or incorrect data, affecting the integrity of smart contracts.
- **Fix:** Replace deprecated functions with the current recommended methods to ensure accurate data retrieval from oracles.
- **Refs:** 1 case(s)
  - https://github.com/code-423n4/2022-04-backd-findings/issues/17

### SOL-Defi-Oracle-2: Is the returned price validated to be non-zero?
- **Risk:** Price feed might return zero and this must be handled as invalid.
- **Fix:** Ensure the returned price is not zero.

### SOL-Defi-Oracle-3: Is the price update time validated?
- **Risk:** Price feeds might not be supported in the future. To ensure accurate price usage, it's vital to regularly check the last update timestamp against a predefined delay.
- **Fix:** Implement a mechanism to check the heartbeat of the price feed and compare it against a predefined maximum delay (`MAX_DELAY`). Adjust the `MAX_DELAY` variable based on the observed heartbeat.

### SOL-Defi-Oracle-4: Is there a validation to check if the rollup sequencer is running?
- **Risk:** The rollup sequencer can become offline, which can lead to potential vulnerabilities due to stale price.
- **Fix:** Utilize the sequencer uptime feed to confirm the sequencers are up.
- **Refs:** 1 case(s)
  - https://docs.chain.link/data-feeds/l2-sequencer-feeds

### SOL-Defi-Oracle-5: Is the Oracle's TWAP period appropriately set?
- **Risk:** An inadequately set TWAP (Time-Weighted Average Price) period could be exploited to manipulate prices.
- **Fix:** Adjust the TWAP period to a duration that mitigates the risk of manipulation while providing timely price updates.
- **Refs:** 1 case(s)
  - https://github.com/code-423n4/2022-06-canto-v2-findings/issues/124

### SOL-Defi-Oracle-6: Is the desired price feed pair supported across all deployed chains?
- **Risk:** In multi-chain deployments, it's crucial to ensure the desired price feed pair is available and consistent across all chains.
- **Fix:** Review the supported price feed pairs on all chains and ensure they are consistent.

### SOL-Defi-Oracle-7: Is the heartbeat of the price feed suitable for the use case?
- **Risk:** A price feed heartbeat that's too slow might not be suitable for some use cases.
- **Fix:** Assess the requirements of the use case and ensure the price feed heartbeat aligns with them.

### SOL-Defi-Oracle-8: Are there any inconsistencies with decimal precision when using different price feeds?
- **Risk:** Different price feeds might have varying decimal precisions, which can lead to inaccuracies.
- **Fix:** Ensure that the contract handles potential variations in decimal precision across different price feeds.

### SOL-Defi-Oracle-9: Is the price feed address hard-coded?
- **Risk:** Hard-coded price feed addresses can be problematic, especially if they become deprecated or if they're not accurate in the first place.
- **Fix:** Review and verify the hardcoded price feed addresses. Consider mechanisms to update the address if required in the future.

### SOL-Defi-Oracle-10: What happens if oracle price updates are front-run?
- **Risk:** Oracle price updates can be front-run and cause various problems.
- **Fix:** Ensure the protocol is not affected in the case where oracle price updates are front-run.
- **Refs:** 1 case(s)
  - https://blog.angle.money/angle-research-series-part-1-oracles-and-front-running-d75184abc67

### SOL-Defi-Oracle-11: How does the system handle potential oracle reverts?
- **Risk:** Unanticipated oracle reverts can lead to Denial-Of-Service.
- **Fix:** Implement try/catch blocks around oracle calls and have alternative strategies ready.

### SOL-Defi-Oracle-12: Are the price feeds appropriate for the underlying assets?
- **Risk:** Using an ETH price feed for stETH or a BTC price feed for WBTC can introduce risks associated with the underlying assets deviating from their pegs.
- **Fix:** Ensure that the price feeds accurately represent the underlying assets to address potential depeg risks.

### SOL-Defi-Oracle-13: Is the contract vulnerable to oracle manipulation, especially using spot prices from AMMs?
- **Risk:** Reliance on AMM spot prices as oracles can be manipulated via flashloan.
- **Fix:** Choose reliable and tamper-resistant oracle sources. Avoid using spot prices from AMMs directly without additional checks.

### SOL-Defi-Oracle-14: How does the system address potential inaccuracies during flash crashes?
- **Risk:** During flash crashes, oracles might return inaccurate prices.
- **Fix:** Implement checks to ensure that the price returned by the oracle lies within an expected range to guard against potential flash crash vulnerabilities.

## Staking

### SOL-Defi-Staking-1: Can a user amplify another user's time lock duration by stacking tokens on their behalf?
- **Risk:** If users can amplify time locks for others by stacking tokens, it may lead to unintended lock durations and potentially be exploited.
- **Fix:** Implement strict checks and controls to prevent users from influencing the time locks of other users through token stacking.

### SOL-Defi-Staking-2: Can the distribution of rewards be unduly delayed or prematurely claimed?
- **Risk:** Manipulation in the timing of reward distribution can adversely affect users and the protocol's intended incentives.
- **Fix:** Implement time controls and constraints on reward distributions to maintain the protocol's intended behavior.

### SOL-Defi-Staking-3: Are rewards up-to-date in all use-cases?
- **Risk:** The staking protocol often has a function to update the rewards (e.g. `updateRewards`) and sometimes it is used as a modifier. This update function MUST be called before all relevant operations.
- **Fix:** Ensure the update reward function is called properly in all places where the reward is relevant.
