# Basics



Total items: 135

## Access Control

### SOL-Basics-AC-1: Did you clarify all the actors and their allowed interactions in the protocol?
- **Risk:** This is a general check item. Having a clear understanding of all relevant actors and interactions in the protocol is critical for security.
- **Fix:** List down all the actors and interactions and draw a diagram.

### SOL-Basics-AC-2: Are there functions lacking proper access controls?
- **Risk:** Access controls determine who can use certain functions of a contract. If these are missing or improperly implemented, it can expose the contract to unauthorized changes or withdrawals.
- **Fix:** Implement and rigorously test access controls like `onlyOwner` or role-based permissions to ensure only authorized users can access certain functions.

### SOL-Basics-AC-3: Do certain addresses require whitelisting?
- **Risk:** Whitelisting allows only a specific set of addresses to interact with the contract, offering an additional layer of security against malicious actors.
- **Fix:** Establish a whitelisting mechanism and ensure that only trusted addresses can execute sensitive or restricted operations.

### SOL-Basics-AC-4: Does the protocol allow transfer of privileges?
- **Risk:** Transfer of critical privileges must be done in two-step process. A two-step transfer process, usually involving a request followed by a confirmation, adds an extra layer of security against unintentional or malicious owner changes.
- **Fix:** Implement a two-step transfer mechanism that requires the new actor to accept the transfer, ensuring better security and intentional ownership changes.

### SOL-Basics-AC-5: What happens during the transfer of privileges?
- **Risk:** The protocol needs to work consistently and reasonably even during the transfer of privileges.
- **Fix:** Double check how the protocol works during the transfer of privileges.

### SOL-Basics-AC-6: Does the contract inherit others?
- **Risk:** If you do not override a parent contract's function explicitly, the parent's one will be exposed with its visibility and probably a wrong accessibiliy.
- **Fix:** Make sure you check the accessibility to the parent's external/public functions.

### SOL-Basics-AC-7: Does the contract use `tx.origin` in validation?
- **Risk:** Use of `tx.origin` for authorization may be abused by a malicious contract forwarding calls from the legitimate user. Use `msg.sender` instead. `require( tx.origin == msg.sender)` is a useful check to ensure that the `msg.sender` is an EOA(externally owned account).
- **Fix:** Make sure you know the difference of `tx.origin` and `msg.sender` and use properly.
- **Refs:** 1 case(s)
  - https://swcregistry.io/docs/SWC-115

## Array / Loop

### SOL-Basics-AL-1: What happens on the first and the last cycle of the iteration?
- **Risk:** Sometimes the first and last cycles have a different logic from others and there can be problems.
- **Fix:** Ensure the logic is correct for the first and the last cycles.

### SOL-Basics-AL-4: How does the protocol remove an item from an array?
- **Risk:** `delete` does not rearrange the array but just resets the element.
- **Fix:** Copy the last element to the index of the element to be removed and decrease the length of an array.

### SOL-Basics-AL-5: Does any function get an index of an array as an argument?
- **Risk:** If an array is supposed to be updated (removal in the middle), the indexes will change.
- **Fix:** Do not use an index of an array that is supposed to be updated as a parameter of a function.

### SOL-Basics-AL-6: Is the summing of variables done accurately compared to separate calculations?
- **Risk:** Direct calculation against a sum may yield different results than the sum of individual calculations, leading to precision issues.
- **Fix:** Ensure that summation logic is thoroughly tested and verified, especially when dealing with financial calculations to maintain accuracy.
- **Refs:** 1 case(s)
  - https://github.com/sherlock-audit/2022-11-isomorph-judging/issues/174

### SOL-Basics-AL-7: Is it fine to have duplicate items in the array?
- **Risk:** In most cases, an array (especially an input array by users) is supposed to be unique.
- **Fix:** Add a validation to check the array is unique.
- **Refs:** 1 case(s)
  - https://solodit.cyfrin.io/issues/duplicate-interactions-mixbytes-none-liquorice-markdown

### SOL-Basics-AL-8: Is there any issue with the first and the last iteration?
- **Risk:** The first and the last iteration in loops can sometimes have edge cases that differ from other iterations, possibly leading to vulnerabilities.
- **Fix:** Always test the initial and the last iteration separately and ensure consistent behavior throughout all iterations.

### SOL-Basics-AL-9: Is there possibility of iteration of a huge array?
- **Risk:** Due to the block gas limit, there is a clear limitation in the amount of operation that can be handled in a transaction.
- **Fix:** Ensure the number of iterations is properly bounded.
- **Refs:** 1 case(s)
  - https://solodit.cyfrin.io/issues/m-5-users-buying-too-many-tickets-will-dos-them-and-the-protocol-if-they-are-the-winner-due-to-oog-sherlock-winnables-raffles-git

### SOL-Basics-AL-10: Is there a potential for a Denial-of-Service (DoS) attack in the loop?
- **Risk:** Loops that contain external calls or are dependent on user-controlled input can be exploited to halt the contract's functions. (e.g. sending ETH to multiple users)
- **Fix:** Ensure a failure of a single iteration does not revert the whole operation.

### SOL-Basics-AL-11: Is `msg.value` used within a loop?
- **Risk:** `msg.value` is consistent for the whole transaction. If it is used in the for loop, it is likely there is a mistake in accounting.
- **Fix:** Avoid using `msg.value` inside loops. Refer to multi-call vulnerability.

### SOL-Basics-AL-12: Is there a loop to handle batch fund transfer?
- **Risk:** If there is a mechanism to transfer funds out based on some kind of shares, it is likely that there is a problem of 'dust' funds not handled correctly.
- **Fix:** Make sure the last transfer handles all residual.

### SOL-Basics-AL-13: Is there a break or continue inside a loop?
- **Risk:** Sometimes developers overlook the edge cases that can happened due to the break or continue in the middle of the loop.
- **Fix:** Make sure the break or continue inside a loop does not lead to unexpected behaviors.

## Block Reorganization

### SOL-Basics-BR-1: Does the protocol implement a factory pattern using the CREATE opcode?
- **Risk:** Contracts created with the CREATE opcode will be eliminated if a block reorg happens.
- **Fix:** Use CREATE2 instead of CREATE.
- **Refs:** 5 case(s)
  - https://solodit.xyz/issues/m-08-factorycreate-is-vulnerable-to-reorg-attacks-code4rena-abracadabra-money-abracadabra-money-git
  - https://solodit.xyz/issues/m-02-reorg-attack-on-users-vault-deployment-and-deposit-may-lead-to-theft-of-funds-code4rena-amphora-protocol-amphora-protocol-git
  - https://solodit.xyz/issues/m-4-loss-of-bond-amounts-on-re-org-attacks-sherlock-optimism-fault-proofs-git

## Event

### SOL-Basics-Event-1: Does the protocol emit events on important state changes?
- **Risk:** Emitting events properly is important especially if the change is critical.
- **Fix:** Ensure to emit events in all important functions.

## Function

### SOL-Basics-Function-1: Are the inputs validated?
- **Risk:** Inputs to functions should be validated to prevent unexpected behavior.
- **Fix:** Ensure thorough validation. E.g. min/max for numeric values, start/end for dates, ownership of positions.
- **Refs:** 3 case(s)
  - https://solodit.xyz/issues/missing-owner-check-on-from-when-transferring-tokens-spearbit-clober-pdf
  - https://solodit.xyz/issues/m-13-bondbasesdasetdefaults-doesnt-validate-inputs-sherlock-bond-bond-protocol-git
  - https://solodit.xyz/issues/h-16-user-supplied-amm-pools-and-no-input-validation-allows-stealing-of-steth-protocol-fees-sherlock-swivel-illuminate-git

### SOL-Basics-Function-2: Are the outputs validated?
- **Risk:** Outputs of functions should be validated to prevent unexpected behavior.
- **Fix:** Ensure the outputs are valid.

### SOL-Basics-Function-3: Can the function be front-run?
- **Risk:** Front-running can allow attackers to prioritize their transactions over others.
- **Fix:** Make sure there is no unexpected risk even if attackers front-run.
- **Refs:** 3 case(s)
  - https://solodit.xyz/issues/m-08-borrower-can-cause-a-dos-by-frontrunning-a-liquidation-and-repaying-as-low-as-1-wei-of-the-current-debt-code4rena-venus-protocol-venus-protocol-isolated-pools-git
  - https://solodit.xyz/issues/m-01-new-proposals-can-be-dosd-by-frontrunning-zachobront-none-optimismgovernormd-markdown_
  - https://solodit.xyz/issues/h-01-challenges-can-be-frontrun-with-de-leveraging-to-cause-lossses-for-challengers-code4rena-frankencoin-frankencoin-git

### SOL-Basics-Function-4: Are the code comments coherent with the implementation?
- **Risk:** Misleading or outdated comments can result in misunderstood function behaviors.
- **Fix:** Keep comments updated and ensure they accurately describe the function logic.
- **Refs:** 2 case(s)
  - https://solodit.xyz/issues/m-08-wrong-comment-in-getfee-code4rena-yeti-finance-yeti-finance-contest-git
  - https://solodit.xyz/issues/m-8-wrong-change_collateral_delay-in-collateralbook-sherlock-isomorph-isomorph-git

### SOL-Basics-Function-5: Can edge case inputs (0, max) result in unexpected behavior?
- **Risk:** Edge input values can lead to unexpected behavior.
- **Fix:** Make sure the function works as expected for the edge values.
- **Refs:** 2 case(s)
  - https://solodit.xyz/issues/lack-of-validation-openzeppelin-bancor-compounding-rewards-audit-markdown
  - https://solodit.xyz/issues/p1-m07-lack-of-input-validation-openzeppelin-eco-contracts-audit-markdown

### SOL-Basics-Function-6: Does the function allow arbitrary user input?
- **Risk:** Implementing a function that accepts arbitrary user input and makes low-level calls based on this data introduces a significant security risk. Low-level calls in Solidity, such as call(), are powerful and can lead to unintended contract behavior if not used cautiously. With the ability for users to supply arbitrary data, they can potentially trigger unexpected paths in the contract logic, exploit reentrancy vulnerabilities, or even interact with other contracts in a malicious manner.
- **Fix:** Restrict the usage of low-level calls, especially when combined with arbitrary user input. Ensure that any data used in these calls is thoroughly validated and sanitized.

### SOL-Basics-Function-7: Should it be `external`/`public`?
- **Risk:** Ensure the visibility modifier is appropriate for the function's use, preventing unnecessary exposure.
- **Fix:** Limit function visibility to the strictest level possible (`private` or `internal`).

### SOL-Basics-Function-8: Does this function need to be called by only EOA or only contracts?
- **Risk:** There are several edge cases regarding the caller checking mechanism, both for EOA and contracts.
- **Fix:** Ensure the correct access control is implemented according to the protocol's context. (read all the references)
- **Refs:** 2 case(s)
  - https://solodit.xyz/issues/m-15-onlyeoaex-modifier-that-ensures-call-is-from-eoa-might-not-hold-true-in-the-future-sherlock-blueberry-blueberry-git
  - https://solodit.xyz/issues/m-17-addressiscontract-is-not-a-reliable-way-of-checking-if-the-input-is-an-eoa-code4rena-stakehouse-protocol-lsd-network-stakehouse-contest-git

### SOL-Basics-Function-9: Does this function need to be restricted for specific callers?
- **Risk:** Ensure that functions modifying contract state or accessing sensitive operations are access-controlled.
- **Fix:** Implement access control mechanisms like `onlyOwner` or custom modifiers.
- **Refs:** 3 case(s)
  - https://solodit.xyz/issues/h-8-lack-of-access-control-for-mintrebalancer-and-burnrebalancer-sherlock-none-ussd-autonomous-secure-dollar-git
  - https://solodit.xyz/issues/h-02-anyone-can-change-approvaldisapproval-threshold-for-any-action-using-llamarelativequorum-strategy-code4rena-llama-llama-git
  - https://solodit.xyz/issues/anyone-can-take-a-loan-out-on-behalf-of-any-collateral-holder-at-any-terms-spearbit-astaria-pdf

## Inheritance

### SOL-Basics-Inheritance-1: Is it necessary to limit visibility of parent contract's public functions?
- **Risk:** External/Public functions of all parent contracts will be exposed with the same visibility as long as they are not overridden.
- **Fix:** Make sure to expose only relevant functions from parent contracts.

### SOL-Basics-Inheritance-2: Were all necessary functions implemented to fulfill inheritance purpose?
- **Risk:** Parent contracts often assume the inheriting contracts to implement public functions to utilize the parent's functionality. Sometimes developers miss implementing them and it makes the inheritance useless.
- **Fix:** Make sure to expose relevant functions from parent contracts.
- **Refs:** 2 case(s)
  - https://solodit.xyz/issues/m-02-pauseunpause-functionalities-not-implemented-in-many-pausable-contracts-code4rena-stader-labs-stader-labs-git
  - https://twitter.com/bytes032/status/1736065591536935366

### SOL-Basics-Inheritance-3: Has the contract implemented an interface?
- **Risk:** Interfaces are used by other protocols to interact with the protocol. Missing implementation will lead to unexpected cases.
- **Fix:** Make sure to implement all functions specified in the interface.

### SOL-Basics-Inheritance-4: Does the inheritance order matter?
- **Risk:** Inheriting contracts in the wrong order can lead to unexpected behavior, e.g. storage allocation.
- **Fix:** Verify the inheritance chain is ordered from 'most base-like' to 'most derived' to prevent issues like incorrect variable initialization.

## Initialization

### SOL-Basics-Initialization-1: Are important state variables initialized properly?
- **Risk:** Overlooking explicit initialization of state variables can lead to critical issues.
- **Fix:** Make sure to initialize all state variables correctly.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/h-01-mintersolstartinflation-can-be-bypassed-code4rena-backd-backd-tokenomics-contest-git

### SOL-Basics-Initialization-2: Has the contract inherited OpenZeppelin's Initializable?
- **Risk:** If the contract is supposed to be inherited by other contracts, `onlyInitializing` modifier MUST be used instead of `initializer`.
- **Fix:** Make sure to use the correct modifier for the initializer function.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/h-03-wrong-implementation-of-eip712metatransaction-code4rena-rolla-rolla-contest-git

### SOL-Basics-Initialization-3: Does the contract have a separate initializer function other than a constructor?
- **Risk:** Initializer function can be front-run right after the deployment. The impact is critical if the initializer sets the access controls.
- **Fix:** Use the factory pattern to allow only the factory to call the initializer or ensure it is not front-runnable in the deploy script.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/initialization-functions-can-be-front-run-trailofbits-advanced-blockchain-pdf

## Map

### SOL-Basics-Map-1: Is there need to delete the existing item from a map?
- **Risk:** If a variable of nested structure is deleted, only the top-level fields are reset by default values (zero) and the nested level fields are not reset.
- **Fix:** Always ensure that inner fields are deleted before the outer fields of the structure.

## Math

### SOL-Basics-Math-1: Is the mathematical calculation accurate?
- **Risk:** Ensure that the logic behind any mathematical operation is correctly implemented.
- **Fix:** Verify calculations against established mathematical rules in the document or the comments.

### SOL-Basics-Math-2: Is there any loss of precision in time calculations?
- **Risk:** Loss of precision can lead to significant errors over time or frequent calculations.
- **Fix:** Use appropriate data types and ensure rounding methods are correctly applied.

### SOL-Basics-Math-3: Are you aware that expressions like `1 day` are cast to `uint24`, potentially causing overflows?
- **Risk:** Operations with certain expressions might lead to unintended data type conversions.
- **Fix:** Always be explicit with data types and avoid relying on implicit type conversions.

### SOL-Basics-Math-4: Is there any case where dividing is done before multiplication?
- **Risk:** Multiplying before division is generally better to keep the precision.
- **Fix:** To avoid loss of precision, always multiply first and then divide.

### SOL-Basics-Math-5: Does the rounding direction matter?
- **Risk:** Rounding direction often matters when the accounting relies on user's shares.
- **Fix:** Use the proper rounding direction in favor of the protocol

### SOL-Basics-Math-6: Is there a possibility of division by zero?
- **Risk:** Division by zero will revert the transaction.
- **Fix:** Always check denominators before division.

### SOL-Basics-Math-7: Even in versions like `>0.8.0`, have you ensured variables won't underflow or overflow leading to reverts?
- **Risk:** Variables can sometimes exceed their bounds, causing reverts.
- **Fix:** Use checks to prevent variable underflows and overflows.

### SOL-Basics-Math-8: Are you aware that assigning a negative value to an unsigned integer causes a revert?
- **Risk:** Unsigned integers cannot hold negative values.
- **Fix:** Always ensure that only non-negative values are assigned to unsigned integers.

### SOL-Basics-Math-9: Have you properly reviewed all usages of `unchecked{}`?
- **Risk:** Arithmetics do not overflow inside the `unchecked{}` block.
- **Fix:** Use `unchecked{}` only when it is strictly guaranteed that no overflow/underflow happens.

### SOL-Basics-Math-10: In comparisons using < or >, should you instead be using ≤ or ≥?
- **Risk:** Usage of incorrect inequality can cause unexpected behavior for the edge values.
- **Fix:** Review the logic and ensure the appropriate comparison operators are used.

### SOL-Basics-Math-11: Have you taken into consideration mathematical operations in inline assembly?
- **Risk:** Inline assembly can behave differently than high-level language constructs. (division by zero, overflow/underflow do not revert!)
- **Fix:** Ensure mathematical operations in inline assembly are properly tested and verified.

### SOL-Basics-Math-12: What happens for the minimum/maximum values included in the calculation?
- **Risk:** If the calculation includes numerous terms, you need to confirm all edge cases where each term has the possible min/max values.
- **Fix:** Ensure the edge cases do not lead to unexpected outcome.

## Payment

### SOL-Basics-Payment-1: Is it possible for the receiver to revert?
- **Risk:** There are cases where a receiver contract can deny the transaction. For example, a malicious receiver can have a fallback to revert. If a caller tried to send funds using `transfer` or `send`, the whole transaction will revert. (Meanwhile, `call()` does not revert but returns a boolean)
- **Fix:** Make sure that the receiver can not deny the payment or add a backup handler with a try-catch.

### SOL-Basics-Payment-2: Does the function gets the payment amount as a parameter?
- **Risk:** For ETH deposits, `msg.value` must be checked if it is not less than the amount specified.
- **Fix:** Require `msg.value==amount`.

### SOL-Basics-Payment-3: Are there vulnerabilities related to force-feeding?
- **Risk:** Certain actions like self-destruct, deterministic address feeding, and coinbase transactions can be used to force-feed contracts.
- **Fix:** Ensure the contract behaves as expected when receiving unexpected funds.
- **Refs:** 1 case(s)
  - https://scsfg.io/hackers/unexpected-ether/

### SOL-Basics-Payment-4: What is the minimum deposit/withdrawal amount?
- **Risk:** Dust deposit/withdrawal often can lead to various vulnerabilities, e.g. rounding issue in accounting or Denial-Of-Service.
- **Fix:** Add a threshold for the deposit/withdrawal amount.

### SOL-Basics-Payment-5: How is the withdrawal handled?
- **Risk:** The best practice in withdrawal process is to implement pull-based approach. Track the accounting and let users pull the payments instead of sending funds proactively.
- **Fix:** Implement pull-based approach in withdrawals.

### SOL-Basics-Payment-6: Is `transfer()` or `send()` used for sending ETH?
- **Risk:** The transfer() and send() functions forward a fixed amount of 2300 gas. Historically, it has often been recommended to use these functions for value transfers to guard against reentrancy attacks. However, the gas cost of EVM instructions may change significantly during hard forks which may break already deployed contract systems that make fixed assumptions about gas costs. For example. EIP 1884 broke several existing smart contracts due to a cost increase of the SLOAD instruction.
- **Fix:** Use `call()` to prevent potential gas issues.
- **Refs:** 3 case(s)
  - https://solodit.xyz/issues/use-call-instead-of-transfer-cyfrin-none-woosh-deposit-vault-markdown
  - https://solodit.xyz/issues/m-5-call-should-be-used-instead-of-transfer-on-an-address-payable-sherlock-dodo-dodo-git
  - https://solodit.xyz/issues/m-10-addresscallvaluex-should-be-used-instead-of-payabletransfer-code4rena-debt-dao-debt-dao-contest-git

### SOL-Basics-Payment-7: Is it possible for native ETH to be locked in the contract?
- **Risk:** If a `payable` function does not transfer all ETH passed in `msg.value` and the contract does not have a withdraw method, ETH will be locked in the contract
- **Fix:** Make sure either no ETH remains in the contract at the end of `payable` functions or make sure there is a `withdraw` function.
- **Refs:** 2 case(s)
  - https://solodit.xyz/issues/m-09-bathbuddy-locks-up-ether-it-receives-code4rena-rubicon-rubicon-contest-git
  - https://solodit.xyz/issues/m-22-eth-sent-when-calling-executeassmartwallet-function-can-be-lost-code4rena-stakehouse-protocol-lsd-network-stakehouse-contest-git

## Proxy/Upgradable

### SOL-Basics-PU-1: Is there a constructor in the proxied contract?
- **Risk:** Proxied contract can't have a constructor and it's common to move constructor logic to an external initializer function, usually called initialize
- **Fix:** Use initializer functions for initialization of proxied contracts.

### SOL-Basics-PU-2: Is the `initializer` modifier applied to the `initialization()` function?
- **Risk:** Without the `initializer` modifier, there is a risk that the initialization function can be called multiple times.
- **Fix:** Always use the `initializer` modifier for initialization functions in proxied contracts and ensure they're called once during deployment.

### SOL-Basics-PU-3: Is the upgradable version used for initialization?
- **Risk:** Upgradable contracts must use the upgradable versions of parent initializer functions. (e.g. Pausable vs PausableUpgradable)
- **Fix:** Use upgradable versions of parent initializer functions.

### SOL-Basics-PU-4: Is the `authorizeUpgrade()` function properly secured in a UUPS setup?
- **Risk:** Inadequate security on the `authorizeUpgrade()` function can allow unauthorized upgrades.
- **Fix:** Ensure proper access controls and checks are in place for the `authorizeUpgrade()` function.

### SOL-Basics-PU-5: Is the contract initialized?
- **Risk:** An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation contract, which may impact the proxy.
- **Fix:** To prevent the implementation contract from being used, invoke the `_disableInitializers` function in the constructor to automatically lock it when it is deployed.
- **Refs:** 1 case(s)
  - https://docs.openzeppelin.com/contracts/4.x/api/proxy#Initializable

### SOL-Basics-PU-6: Are `selfdestruct` and `delegatecall` used within the implementation contracts?
- **Risk:** Using `selfdestruct` and `delegatecall` in implementation contracts can introduce vulnerabilities and unexpected behavior in a proxy setup.
- **Fix:** Avoid using `selfdestruct` and `delegatecall` in implementation contracts to ensure contract stability and security.

### SOL-Basics-PU-7: Are values in immutable variables preserved between upgrades?
- **Risk:** Immutable variables are stored in the bytecode, not in the proxy storage. So using immutable variable is not recommended in proxy setup. If used, make sure all immutables stay consistent across implementations during upgrades.
- **Fix:** Avoid using immutable variables in upgradable contracts.

### SOL-Basics-PU-8: Has the contract inherited the correct branch of OpenZeppelin library?
- **Risk:** Sometimes developers overlook and use an incorrect branch of OZ library, e.g. use Ownable instead of OwnableUpgradeable.
- **Fix:** Make sure inherit the correct branch of OZ library according to the contract's upgradeability design.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/h-01-usage-of-an-incorrect-version-of-ownbale-library-can-potentially-malfunction-all-onlyowner-functions-code4rena-covalent-covalent-contest-git

### SOL-Basics-PU-9: Could an upgrade of the contract result in storage collision?
- **Risk:** Storage collisions can occur when storage layouts between contract versions conflict, leading to data corruption and unpredictable behavior.
- **Fix:** Maintain a consistent storage layout between upgrades, and when using inheritance, set storage gaps to avoid potential collisions.

### SOL-Basics-PU-10: Are the order and types of storage variables consistent between upgrades?
- **Risk:** Changing the order or type of storage variables between upgrades can lead to storage collisions.
- **Fix:** Maintain a consistent order and type for storage variables across contract versions to avoid storage collisions.

## Type

### SOL-Basics-Type-1: Is there a forced type casting?
- **Risk:** Explicit type casting does not revert on overflow/underflow.
- **Fix:** Avoid a forced type casting as much as possible and ensure values are in the range of type limit.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/risk-of-token-theft-due-to-unchecked-type-conversion-trailofbits-none-primitive-hyper-pdf

### SOL-Basics-Type-2: Does the protocol use time units like `days`?
- **Risk:** The time units are of `uint8` type and this can lead to unintended overflow.
- **Fix:** Double check the calculations including time units and ensure there is no overflow for reasonable values.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-05-expiration-calculation-overflows-if-call-option-duration-195-days-code4rena-cally-cally-contest-git

## Version Issues / EIP Adoption Issues

### SOL-Basics-VI-EAI-1: EIP-4758: Does the contract use `selfdestruct()`?
- **Risk:** `selfdestruct` will not be available after EIP-4758. This EIP will rename the SELFDESTRUCT opcode and replace its functionality.
- **Fix:** Do not use `selfdestruct` to ensure the contract works in the future.
- **Refs:** 3 case(s)
  - https://eips.ethereum.org/EIPS/eip-4758
  - https://solodit.xyz/issues/m-09-selfdestruct-will-not-be-available-after-eip-4758-code4rena-escher-escher-contest-git
  - https://solodit.xyz/issues/m-03-system-will-not-work-anymore-after-eip-4758-code4rena-axelar-network-axelar-network-git

## Version Issues / OpenZeppelin Version Issues

### SOL-Basics-VI-OVI-1: Does the contract use `ERC2771Context`? (version >=4.0.0 <4.9.3)
- **Risk:** `ERC2771Context._msgData()` reverts if `msg.data.length < 20`. The correct behavior is not specified in ERC-2771, but based on the specified behavior of `_msgSender` we assume the full `msg.data` should be returned in this case.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-2: Does the contract use OpenZeppelin's GovernorCompatibilityBravo? (version >=4.3.0 <4.8.3)
- **Risk:** GovernorCompatibilityBravo may trim proposal calldata. The proposal creation entrypoint (propose) in GovernorCompatibilityBravo allows the creation of proposals with a signatures array shorter than the calldatas array. This causes the additional elements of the latter to be ignored, and if the proposal succeeds the corresponding actions would eventually execute without any calldata. The ProposalCreated event correctly represents what will eventually execute, but the proposal parameters as queried through getActions appear to respect the original intended calldata.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-3: Does the contract use OpenZeppelin's ECDSA.recover or ECDSA.tryRecover? (version <4.7.3)
- **Risk:** ECDSA signature malleability. The functions ECDSA.recover and ECDSA.tryRecover are vulnerable to a kind of signature malleability due to accepting EIP-2098 compact signatures in addition to the traditional 65 byte signature format. This is only an issue for the functions that take a single bytes argument, and not the functions that take r, v, s or r, vs as separate arguments. The potentially affected contracts are those that implement signature reuse or replay protection by marking the signature itself as used rather than the signed message or a nonce included in it. A user may take a signature that has already been submitted, submit it again in a different form, and bypass this protection.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-4: Does the contract use OpenZeppelin's ERC777? (version <3.4.0-rc.0)
- **Risk:** Extending this contract with a custom _beforeTokenTransfer function could allow a reentrancy attack to happen. More specifically, when burning tokens, _beforeTokenTransfer is invoked before the send hook is externally called on the sender while token balances are adjusted afterwards. At the moment of the call to the sender, which can result in reentrancy, state managed by _beforeTokenTransfer may not correspond to the actual token balances or total supply.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-5: Does the contract use OpenZeppelin's `MerkleProof`? (version >=4.7.0 <4.9.2)
- **Risk:** When the `verifyMultiProof`, `verifyMultiProofCalldata`, `processMultiProof`, or `processMultiProofCalldata` functions are in use, it is possible to construct merkle trees that allow forging a valid multiproof for an arbitrary set of leaves.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-6: Does the contract use OpenZeppelin's Governor or GovernorCompatibilityBravo? (version >=4.3.0 <4.9.1)
- **Risk:** Governor proposal creation may be blocked by frontrunning. By frontrunning the creation of a proposal, an attacker can become the proposer and gain the ability to cancel it. The attacker can do this repeatedly to try to prevent a proposal from being proposed at all. This impacts the Governor contract in v4.9.0 only, and the GovernorCompatibilityBravo contract since v4.3.0.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-7: Does the contract use OpenZeppelin's TransparentUpgradeableProxy? (version >=3.2.0 <4.8.3)
- **Risk:** Transparency is broken in case of selector clash with non-decodable calldata. The TransparentUpgradeableProxy uses the ifAdmin modifier to achieve transparency. If a non-admin address calls the proxy the call should be frowarded transparently. This works well in most cases, but the forwarding of some functions can fail if there is a selector conflict and decoding issue.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-8: Does the contract use OpenZeppelin's ERC721Consecutive?(version >=4.8.0 <4.8.2)
- **Risk:** The ERC721Consecutive contract designed for minting NFTs in batches does not update balances when a batch has size 1 and consists of a single token. Subsequent transfers from the receiver of that token may overflow the balance as reported by balanceOf. The issue exclusively presents with batches of size 1.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-9: Does the contract use OpenZeppelin's ERC165Checker or ERC165CheckerUpgradeable? (version >=2.3.0 <4.7.2)
- **Risk:** Denial of Service (DoS) in the `supportsERC165InterfaceUnchecked()` function in `ERC165Checker.sol` and `ERC165CheckerUpgradeable.sol`, which can consume excessive resources when processing a large amount of data via an EIP-165 supportsInterface query.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-10: Does the contract use OpenZeppelin's LibArbitrumL2 or CrossChainEnabledArbitrumL2? (version >=4.6.0 <4.7.2)
- **Risk:** Incorrect resource transfer between spheres via contracts using the cross-chain utilities for Arbitrum L2: `CrossChainEnabledArbitrumL2` or `LibArbitrumL2`. Calls from EOAs would be classified as cross-chain calls. The vulnerability will classify direct interactions of externally owned accounts (EOAs) as cross-chain calls, even though they are not started on L1.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-11: Does the contract use OpenZeppelin's GovernorVotesQuorumFraction? (version >=4.3.0 <4.7.2)
- **Risk:** Checkpointing quorum was missing and past proposals that failed due to lack of quorum could pass later. It is necessary to avoid quorum changes making old, failed because of quorum, proposals suddenly successful.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-12: Does the contract use OpenZeppelin's SignatureChecker? (version >=4.1.0 <4.7.1)
- **Risk:** Since 0.8.0, abi.decode reverts if the bytes raw data overflow the target type. SignatureChecker.isValidSignatureNow is not expected to revert. However, an incorrect assumption about Solidity 0.8's abi.decode allows some cases to revert, given a target contract that doesn't implement EIP-1271 as expected. The contracts that may be affected are those that use SignatureChecker to check the validity of a signature and handle invalid signatures in a way other than reverting.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-13: Does the contract use OpenZeppelin's ERC165Checker? (version >=4.0.0 <4.7.1)
- **Risk:** Since 0.8.0, abi.decode reverts if the bytes raw data overflow the target type. ERC165Checker.supportsInterface is designed to always successfully return a boolean, and under no circumstance revert. However, an incorrect assumption about Solidity 0.8's abi.decode allows some cases to revert, given a target contract that doesn't implement EIP-165 as expected, specifically if it returns a value other than 0 or 1. The contracts that may be affected are those that use ERC165Checker to check for support for an interface and then handle the lack of support in a way other than reverting.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-14: Does the contract use OpenZeppelin's GovernorCompatibilityBravo? (version >=4.3.0 <4.4.2)
- **Risk:** GovernorCompatibilityBravo incorrect ABI encoding may lead to unexpected behavior
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-15: Does the contract use OpenZeppelin's Initializable? (version >=3.2.0 <4.4.1)
- **Risk:** It is possible for `initializer()`-protected functions to be executed twice, if this happens in the same transaction. For this to happen, either one call has to be a subcall the other, or both call have to be subcalls of a common initializer()-protected function. This can particularly be dangerous is the initialization is not part of the proxy construction, and reentrancy is possible by executing an external call to an untrusted address.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-16: Does the contract use OpenZeppelin's ERC1155? (version >=4.2.0 <4.3.3)
- **Risk:** Possible inconsistency in the value returned by totalSupply DURING a mint. If you mint a token, the receiver is a smart contract, and the receiver implements onERC1155Receive, then this receiver is called with the balance already updated, but with the totalsupply not yet updated.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-17: Does the contract use OpenZeppelin's UUPSUpgradeable? (version >=4.1.0 <4.3.2)
- **Risk:** Upgradeable contracts using UUPSUpgradeable may be vulnerable to an attack affecting uninitialized implementation contracts.
- **Fix:** Use the latest stable OpenZeppelin version

### SOL-Basics-VI-OVI-18: Does the contract use OpenZeppelin's TimelockController? (version >=4.0.0-beta.0 <4.3.1\\n<3.4.2)
- **Risk:** A vulnerability in TimelockController allowed an actor with the executor role to take immediate control of the timelock, by resetting the delay to 0 and escalating privileges, thus gaining unrestricted access to assets held in the contract. Instances with the executor role set to 'open' allow anyone to use the executor role, thus leaving the timelock at risk of being taken over by an attacker.
- **Fix:** Use the latest stable OpenZeppelin version

## Version Issues / Solidity Version Issues

### SOL-Basics-VI-SVI-1: Does the contract encode storage structs or arrays with types under 32 bytes directly using experimental ABIEncoderV2? (version 0.5.0~0.5.6)
- **Risk:** Storage structs and arrays with types shorter than 32 bytes can cause data corruption if encoded directly from storage using the experimental ABIEncoderV2.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2019/03/26/solidity-optimizer-and-abiencoderv2-bug/

### SOL-Basics-VI-SVI-2: Are there any instances where empty strings are directly passed to function calls? (version ~0.4.11)
- **Risk:** If an empty string is used in a function call, the following function arguments will not be correctly passed to the function.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-3: Does the optimizer replace specific constants with alternative computations? (version ~0.4.10)
- **Risk:** In some situations, the optimizer replaces certain numbers in the code with routines that compute different numbers.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2017/05/03/solidity-optimizer-bug/

### SOL-Basics-VI-SVI-4: Does the contract use `abi.encodePacked`, especially in hash generation? (version >= 0.8.17)
- **Risk:** If you use `keccak256(abi.encodePacked(a, b))` and both `a` and `b` are dynamic types, it is easy to craft collisions in the hash value by moving parts of `a` into `b` and vice-versa. More specifically, `abi.encodePacked(\'a\', \'bc\') == abi.encodePacked(\'ab\', \'c\').
- **Fix:** Use `abi.encode` instead of `abi.encodePacked`.
- **Refs:** 2 case(s)
  - https://solodit.xyz/issues/m-1-abiencodepacked-allows-hash-collision-sherlock-nftport-nftport-git
  - https://docs.soliditylang.org/en/v0.8.17/abi-spec.html?highlight=collisions#non-standard-packed-mode

### SOL-Basics-VI-SVI-5: BUILD: Is the contract optimized using sequences containing FullInliner with non-expression-split code? (version 0.6.7~0.8.20)
- **Risk:** Optimizer sequences containing FullInliner do not preserve the evaluation order of arguments of inlined function calls in code that is not in expression-split form.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2023/07/19/full-inliner-non-expression-split-argument-evaluation-order-bug/

### SOL-Basics-VI-SVI-6: Are there any functions that conditionally terminate inside an inline assembly? (version 0.8.13~0.8.16)
- **Risk:** Calling functions that conditionally terminate the external EVM call using the assembly statements ``return(...)`` or ``stop()`` may result in incorrect removals of prior storage writes.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2022/09/08/storage-write-removal-before-conditional-termination/

### SOL-Basics-VI-SVI-7: Are tuples containing a statically-sized calldata array at the end being ABI-encoded? (version 0.5.8~0.8.15)
- **Risk:** ABI-encoding a tuple with a statically-sized calldata array in the last component would corrupt 32 leading bytes of its first dynamically encoded component.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2022/08/08/calldata-tuple-reencoding-head-overflow-bug/

### SOL-Basics-VI-SVI-8: Does the contract have functions that copy `bytes` arrays from memory or calldata directly to storage? (version 0.0.1~0.8.14)
- **Risk:** Copying ``bytes`` arrays from memory or calldata to storage may result in dirty storage values.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2022/06/15/dirty-bytes-array-to-storage-bug/

### SOL-Basics-VI-SVI-9: Is there a function with multiple inline assembly blocks? (version 0.8.13~0.8.14)
- **Risk:** The Yul optimizer may incorrectly remove memory writes from inline assembly blocks, that do not access solidity variables.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2022/06/15/inline-assembly-memory-side-effects-bug/

### SOL-Basics-VI-SVI-10: Is a nested array being ABI-encoded or passed directly to an external function? (version 0.5.8~0.8.13)
- **Risk:** ABI-reencoding of nested dynamic calldata arrays did not always perform proper size checks against the size of calldata and could read beyond `calldatasize()`.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2022/05/17/calldata-reencode-size-check-bug/

### SOL-Basics-VI-SVI-11: Is `abi.encodeCall` used together with fixed-length bytes literals? (version 0.8.11~0.8.12)
- **Risk:** Literals used for a fixed length bytes parameter in ``abi.encodeCall`` were encoded incorrectly.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2022/03/16/encodecall-bug/

### SOL-Basics-VI-SVI-12: Is there any user defined types based on types shorter than 32 bytes? (version =0.8.8)
- **Risk:** User defined value types with underlying type shorter than 32 bytes used incorrect storage layout and wasted storage
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2021/09/29/user-defined-value-types-bug/

### SOL-Basics-VI-SVI-13: Is there an immutable variable of signed integer type shorter than 256 bits? (version 0.6.5~0.8.8)
- **Risk:** Immutable variables of signed integer type shorter than 256 bits can lead to values with invalid higher order bits if inline assembly is used.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2021/09/29/signed-immutables-bug/

### SOL-Basics-VI-SVI-14: Is there any use of `abi.encode` on memory with multi-dimensional array or structs? (version 0.4.16~0.8.3)
- **Risk:** If used on memory byte arrays, result of the function ``abi.decode`` can depend on the contents of memory outside of the actual byte array that is decoded.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2021/04/21/decoding-from-memory-bug/

### SOL-Basics-VI-SVI-15: Is there an inline assembly block with `keccak256` inside? (version ~0.8.2)
- **Risk:** The bytecode optimizer incorrectly re-used previously evaluated Keccak-256 hashes. You are unlikely to be affected if you do not compute Keccak-256 hashes in inline assembly.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2021/03/23/keccak-optimizer-bug/

### SOL-Basics-VI-SVI-16: Is there a copy of an empty `bytes` or `string` from `memory` or `calldata` to `storage`? (version ~0.7.3)
- **Risk:** Copying an empty byte array (or string) from memory or calldata to storage can result in data corruption if the target array's length is increased subsequently without storing new data.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2020/10/19/empty-byte-array-copy-bug/

### SOL-Basics-VI-SVI-17: Is there a dynamically-sized storage-array with types of size at most 16 bytes? (version ~0.7.2)
- **Risk:** When assigning a dynamically-sized array with types of size at most 16 bytes in storage causing the assigned array to shrink, some parts of deleted slots were not zeroed out.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2020/10/07/solidity-dynamic-array-cleanup-bug/

### SOL-Basics-VI-SVI-18: Does the library use contract types in events? (version 0.5.0~0.5.7)
- **Risk:** Contract types used in events in libraries cause an incorrect event signature hash
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-19: Does the contract use internal library functions with calldata parameters via `using for`? (version =0.6.9)
- **Risk:** Function calls to internal library functions with calldata parameters called via ``using for`` can result in invalid data being read.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-20: Are string literals with double backslashes passed directly to external or encoding functions with ABIEncoderV2 enabled? (version 0.5.14~0.6.7)
- **Risk:** String literals containing double backslash characters passed directly to external or encoding function calls can lead to a different string being used when ABIEncoderV2 is enabled.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-21: Does the contract access slices of dynamic arrays, especially multi-dimensional ones? (version 0.6.0~0.6.7)
- **Risk:** Accessing array slices of arrays with dynamically encoded base types (e.g. multi-dimensional arrays) can result in invalid data being read.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-22: Is there a contract with creation code, no constructor, but a base with a constructor that accepts non-zero values? (version 0.4.5~0.6.7)
- **Risk:** The creation code of a contract that does not define a constructor but has a base that does define a constructor did not revert for calls with non-zero value.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-23: Does the contract create extremely large memory arrays? (version 0.2.0~0.6.4)
- **Risk:** The creation of very large memory arrays can result in overlapping memory regions and thus memory corruption.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2020/04/06/memory-creation-overflow-bug/

### SOL-Basics-VI-SVI-24: Does the contract's inline assembly with Yul optimizer use assignments inside for loops combined with continue or break? (version =0.6.0)
- **Risk:** The Yul optimizer can remove essential assignments to variables declared inside for loops when Yul's continue or break statement is used. You are unlikely to be affected if you do not use inline assembly with for loops and continue and break statements.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-25: Does the contract allow private methods to be overridden by inheriting contracts? (version 0.3.0~0.5.16)
- **Risk:** Private methods can be overridden by inheriting contracts.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-26: Is there any Yul's continue or break statement inside the loop?? (version 0.5.8~0.5.15)
- **Risk:** The Yul optimizer can remove essential assignments to variables declared inside for loops when Yul's continue or break statement is used. You are unlikely to be affected if you do not use inline assembly with for loops and continue and break statements.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-27: Are both experimental ABIEncoderV2 and Yul optimizer activated? (version =0.5.14)
- **Risk:** If both the experimental ABIEncoderV2 and the experimental Yul optimizer are activated, one component of the Yul optimizer may reuse data in memory that has been changed in the meantime.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-28: Does the contract read from calldata structs with dynamic yet statically-sized members? (version 0.5.6~0.5.10)
- **Risk:** Reading from calldata structs that contain dynamically encoded, but statically-sized members can result in incorrect values.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-29: Does the contract assign arrays of signed integers to differently typed storage arrays? (version 0.4.7~0.5.9)
- **Risk:** Assigning an array of signed integers to a storage array of different type can lead to data corruption in that array.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2019/06/25/solidity-storage-array-bugs/

### SOL-Basics-VI-SVI-30: Does the contract directly encode storage arrays with structs or static arrays in external calls or abi.encode*? (version 0.4.16~0.5.9)
- **Risk:** Storage arrays containing structs or other statically-sized arrays are not read properly when directly encoded in external function calls or in abi.encode*.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2019/06/25/solidity-storage-array-bugs/

### SOL-Basics-VI-SVI-31: Does the contract's constructor accept structs or arrays with dynamic arrays? (version 0.4.16~0.5.8)
- **Risk:** A contract's constructor that takes structs or arrays that contain dynamically-sized arrays reverts or decodes to invalid data.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-32: Are uninitialized internal function pointers created in the constructor being called? (version 0.5.0~0.5.7)
- **Risk:** Calling uninitialized internal function pointers created in the constructor does not always revert and can cause unexpected behavior.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-33: Are uninitialized internal function pointers created in the constructor being called? (version 0.4.5~0.4.25)
- **Risk:** Calling uninitialized internal function pointers created in the constructor does not always revert and can cause unexpected behavior.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-34: Does the library use contract types in events? (version 0.3.0~0.4.25)
- **Risk:** Contract types used in events in libraries cause an incorrect event signature hash
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-35: Does the contract encode storage structs or arrays with types under 32 bytes directly using experimental ABIEncoderV2? (version 0.4.19~0.4.25)
- **Risk:** Storage structs and arrays with types shorter than 32 bytes can cause data corruption if encoded directly from storage using the experimental ABIEncoderV2.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2019/03/26/solidity-optimizer-and-abiencoderv2-bug/

### SOL-Basics-VI-SVI-36: Does the contract's optimizer handle byte opcodes with a second argument of 31 or an equivalent constant expression? (version 0.5.5~0.5.6)
- **Risk:** The optimizer incorrectly handles byte opcodes whose second argument is 31 or a constant expression that evaluates to 31. This can result in unexpected values.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2019/03/26/solidity-optimizer-and-abiencoderv2-bug/

### SOL-Basics-VI-SVI-37: Are there double bitwise shifts with large constants that might sum up to overflow 256 bits? (version =0.5.5)
- **Risk:** Double bitwise shifts by large constants whose sum overflows 256 bits can result in unexpected values.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2019/03/26/solidity-optimizer-and-abiencoderv2-bug/

### SOL-Basics-VI-SVI-38: Is the ** operator used with an exponent type shorter than 256 bits? (version ~0.4.24)
- **Risk:** Using the ** operator with an exponent of type shorter than 256 bits can result in unexpected values.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2018/09/13/solidity-bugfix-release/

### SOL-Basics-VI-SVI-39: Are structs used in the logged events? (version 0.4.17~0.4.24)
- **Risk:** Using structs in events logged wrong data.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2018/09/13/solidity-bugfix-release/

### SOL-Basics-VI-SVI-40: Are functions returning multi-dimensional fixed-size arrays called? (version 0.1.4~0.4.21)
- **Risk:** Calling functions that return multi-dimensional fixed-size arrays can result in memory corruption.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2018/09/13/solidity-bugfix-release/

### SOL-Basics-VI-SVI-41: Does the contract use both new-style and old-style constructors simultaneously? (version =0.4.22)
- **Risk:** If a contract has both a new-style constructor (using the constructor keyword) and an old-style constructor (a function with the same name as the contract) at the same time, one of them will be ignored.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-42: Is there a function name crafted to potentially override the fallback function execution? (version ~0.4.17)
- **Risk:** It is possible to craft the name of a function such that it is executed instead of the fallback function in very specific circumstances.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-43: Is the low-level .delegatecall() used without checking the actual execution outcome? (version 0.3.0~0.4.14)
- **Risk:** The low-level .delegatecall() does not return the execution outcome, but converts the value returned by the functioned called to a boolean instead.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-44: Is the ecrecover() function used without validating its input? (version ~0.4.13)
- **Risk:** The ecrecover() builtin can return garbage for malformed input.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-45: Is the `.selector` member accessed on complex expressions? (version 0.6.2~0.8.20)
- **Risk:** Accessing the ``.selector`` member on complex expressions leaves the expression unevaluated in the legacy code generation.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2023/07/19/missing-side-effects-on-selector-access-bug/

### SOL-Basics-VI-SVI-46: Is there any inconsistency (`memory` vs `calldata`) in the param type during inheritance? (version 0.6.9~0.8.13)
- **Risk:** It was possible to change the data location of the parameters or return variables from ``calldata`` to ``memory`` and vice-versa while overriding internal and public functions. This caused invalid code to be generated when calling such a function internally through virtual function calls.
- **Fix:** Use the latest Solidity version.
- **Refs:** 1 case(s)
  - https://blog.soliditylang.org/2022/05/17/data-location-inheritance-bug/

### SOL-Basics-VI-SVI-47: Are there any functions with the same name and parameter type inside the same contract? (version =0.7.1)
- **Risk:** The compiler does not flag an error when two or more free functions with the same name and parameter types are defined in a source unit or when an imported free function alias shadows another free function with a different name but identical parameter types.
- **Fix:** Use the latest Solidity version.

### SOL-Basics-VI-SVI-48: Does the contract use tuple assignments with multi-stack-slot components, like nested tuples or dynamic calldata references? (version 0.1.6~0.6.5)
- **Risk:** Tuple assignments with components that occupy several stack slots, i.e. nested tuples, pointers to external functions or references to dynamically sized calldata arrays, can result in invalid values.
- **Fix:** Use the latest Solidity version.
