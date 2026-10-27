# External Call



Total items: 14

## (general)

### SOL-EC-1: What are the implications if the call reenters a different function?
- **Risk:** Reentrant calls to different functions can unpredictably alter contract states. Note that view functions should be checked as well to prevent the Readonly Reentrancy.
- **Fix:** Ensure the contract state is maintained reasonably during the external interactions.
- **Refs:** 2 case(s)
  - https://medium.com/@zokyo.io/read-only-reentrancy-attacks-understanding-the-threat-to-your-smart-contracts-99444c0a7334
  - https://solodit.xyz/issues/m-03-read-only-reentrancy-is-possible-code4rena-angle-protocol-angle-protocol-invitational-git

### SOL-EC-2: Is there a multi-call?
- **Risk:** Mismanagement of `msg.value` across multiple calls can lead to vulnerabilities.
- **Fix:** Do not use ETH in multicall.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-08-passing-multiple-eth-deposits-in-orders-array-will-use-the-same-msgvalue-many-times-code4rena-nested-finance-nested-finance-contest-git

### SOL-EC-3: What are the risks associated with using delegatecall in smart contracts?
- **Risk:** A delegatecall is a low-level function call that delegates the execution of a function in another contract while maintaining the original contract's context. It can lead to critical vulnerabilities if the destination address is not secure or can be altered by an unauthorized party.
- **Fix:** Use delegatecall only with trusted contracts, and ensure that the address to be delegated to is not changeable by unauthorized users. Implement strong access controls and audit the code for potential security issues before deployment.

### SOL-EC-4: Is the external contract call necessary?
- **Risk:** Unnecessary external calls can introduce vulnerabilities.
- **Fix:** Evaluate and eliminate non-essential external contract calls.

### SOL-EC-5: Has the called address been whitelisted?
- **Risk:** Calling untrusted addresses can lead to malicious actions.
- **Fix:** Ensure that only whitelisted or trusted contract addresses are called.
- **Refs:** 2 case(s)
  - https://solodit.xyz/issues/too-generic-calls-in-genericbridgefacet-allow-stealing-of-tokens-spearbit-lifi-pdf
  - https://solodit.xyz/issues/hardcode-or-whitelist-the-axelar-destinationaddress-spearbit-lifi-pdf

### SOL-EC-6: Is there suspicion when a fixed gas amount is specified?
- **Risk:** Specifying fixed gas amounts can lead to out-of-gas vulnerabilities.
- **Fix:** Use dynamic gas estimation or ensure sufficient gas is available before the call.
- **Refs:** 2 case(s)
  - https://solodit.xyz/issues/m-02-fixed-amount-of-gas-sent-in-call-may-be-insufficient-code4rena-joyn-joyn-contest-git
  - https://solodit.xyz/issues/a-malicious-fee-receiver-can-cause-a-denial-of-service-trailofbits-nftx-protocol-v2-pdf

### SOL-EC-7: What happens if the call consumes all provided gas?
- **Risk:** Calls that consume all available gas can halt subsequent actions.
- **Fix:** Ensure enough gas is reserved for post-call tasks or use dynamic gas estimation.
- **Refs:** 2 case(s)
  - https://solodit.xyz/issues/a-malicious-fee-receiver-can-cause-a-denial-of-service-trailofbits-nftx-protocol-v2-pdf
  - https://solodit.xyz/issues/poison-order-that-consumes-gas-can-block-market-trades-wont-fix-consensys-0x-v3-exchange-markdown

### SOL-EC-8: Is the contract passing large data to an unknown address?
- **Risk:** Large data passed to untrusted addresses may be exploited for griefing.
- **Fix:** Limit data passed or employ inline assembly to manage data transfer.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/h-2-malicious-user-can-use-an-excessively-large-_toaddress-in-oftcoresendfrom-to-break-layerzero-communication-sherlock-uxd-uxd-protocol-git

### SOL-EC-9: What happens if the call returns vast data?
- **Risk:** External calls returning vast data can deplete available gas.
- **Fix:** Limit or verify data size returned from external sources.
- **Refs:** 1 case(s)
  - https://solodit.cyfrin.io/?b=false&f=&fc=gte&ff=&fn=1&i=HIGH%2CMEDIUM&p=1&pc=&r=all&s=gas+griefing&t=

### SOL-EC-10: Are there any delegate calls to non-library contracts?
- **Risk:** Non-library delegate calls can alter the state of the calling contract.
- **Fix:** Thoroughly review and verify such delegate calls so that the delegate calls do not change the caller's state unexpectedly.

### SOL-EC-11: Is there a strict policy against delegate calls to untrusted contracts?
- **Risk:** Delegate calls grant the called contract the context of the caller, risking state alterations.
- **Fix:** Restrict delegate calls to only trusted, reviewed, and audited contracts.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-01-delegate-call-in-vault_execute-can-alter-vaults-ownership-code4rena-fractional-fractional-v2-contest-git

### SOL-EC-12: Is the address's existence verified?
- **Risk:** Calling non-existent addresses can lead to unintended behaviors. Low level calls (call, delegate call and static call) return success if the called contract doesn't exist (not deployed or destructed)
- **Fix:** Verify the existence of an address before making a call.
- **Refs:** 6 case(s)
  - https://solodit.xyz/issues/h-02-non-existing-revenue-contract-can-be-passed-to-claimrevenue-to-send-all-tokens-to-treasury-code4rena-debt-dao-debt-dao-contest-git
  - https://solodit.xyz/issues/m-10-call-to-non-existing-contracts-returns-success-code4rena-biconomy-biconomy-hyphen-20-contest-git
  - https://solodit.xyz/issues/lack-of-contract-existence-check-on-delegatecall-will-result-in-unexpected-behavior-trailofbits-degate-pdf

### SOL-EC-13: Is the check-effect-interaction pattern being utilized?
- **Risk:** The check-effect-interaction pattern prevents reentrancy attacks.
- **Fix:** Adhere to the CEI pattern and use `reentrancyGuard` judiciously.
- **Refs:** 3 case(s)
  - https://www.geeksforgeeks.org/reentrancy-attack-in-smart-contracts/
  - https://solodit.xyz/issues/m-09-malicious-royalty-recipient-can-steal-excess-eth-from-buy-orders-code4rena-caviar-caviar-private-pools-git
  - https://solodit.xyz/issues/h-01-re-entrancy-in-settleauction-allow-stealing-all-funds-code4rena-kuiper-kuiper-contest-git

### SOL-EC-14: How is the msg.sender handled?
- **Risk:** On interacting with external contracts, the caller becomes a new `msg.sender` instead of the original caller.
- **Fix:** Ensure the validation is in place to check the actor is handled correctly.
- **Refs:** 2 case(s)
  - https://solodit.xyz/issues/swapinternal-shouldnt-use-msgsender-spearbit-connext-pdf
  - https://solodit.xyz/issues/m-01-onlycentrifugechainorigin-cant-require-msgsender-equal-axelargateway-code4rena-centrifuge-centrifuge-git
