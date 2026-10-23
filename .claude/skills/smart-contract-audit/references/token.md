# Token



Total items: 24

## Fungible : ERC20

### SOL-Token-FE-1: Are safe transfer functions used throughout the contract?
- **Risk:** Not all ERC20 tokens are compliant to the EIP20 standard. Some do not return boolean flag, some do not revert on failure.
- **Fix:** Use OpenZeppelin's SafeERC20 where the safeTransfer and safeTransferFrom functions handle the return value check as well as non-standard-compliant tokens.

### SOL-Token-FE-2: Is there potential for a race condition for approvals?
- **Risk:** Race condition for approvals can cause an unexpected loss of funds to the signer.
- **Fix:** Use OpenZeppelin's safeIncreaseAllowance and safeDecreaseAllowance functions.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m01-approval-process-can-be-front-run-openzeppelin-notional-governance-contracts-v2-audit-markdown

### SOL-Token-FE-3: Could a difference in decimals between ERC20 tokens cause issues?
- **Risk:** Different decimals in ERC20 tokens can cause incorrect calculations or interpretations.
- **Fix:** Always check and handle the decimals of ERC20 tokens to prevent potential issues.

### SOL-Token-FE-4: Does the token implement any form of address whitelisting, blacklisting, or checks?
- **Risk:** Tokens that have address checks can lead to various problems.
- **Fix:** Ensure the token's own blacklisting mechanism does not affect the protocol's functionality.

### SOL-Token-FE-5: Could the use of multiple addresses for a single token lead to complications?
- **Risk:** Some tokens have multiple addresses and this can introduce vulnerabilities.
- **Fix:** Do not rely on the token address in the accounting.

### SOL-Token-FE-6: Does the token charge fee on transfer?
- **Risk:** Some tokens charge fee on transfer and the receiver gets less amount than specified.
- **Fix:** If the protocol intends to support this kind of token, ensure the accounting logic is correct.

### SOL-Token-FE-7: Can the token be ERC777?
- **Risk:** ERC777 tokens have hooks that execute code before and after transfers, which might lead to reentrancy.
- **Fix:** Be cautious when integrating with ERC777 and be aware of the hook implications.

### SOL-Token-FE-8: Does the protocol use Solmate's `ERC20.safeTransferLib`?
- **Risk:** Solmate `ERC20.safeTransferLib` do not check the contract existence and this opens up a possibility for a honeypot attack.
- **Fix:** Use OpenZeppelin's SafeERC20.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-02-solmates-erc20-does-not-check-for-token-contracts-existence-which-opens-up-possibility-for-a-honeypot-attack-code4rena-size-size-contest-git

### SOL-Token-FE-9: Is there a flash-mint functionality?
- **Risk:** Flash mints can drastically increase token supply temporarily, leading to potential abuse.
- **Fix:** Implement strict controls and checks around any flash mint functionality.

### SOL-Token-FE-10: What happens on zero amount transfer?
- **Risk:** Some tokens revert on transfer of zero amount and can cause issues in certain integrations and operations.
- **Fix:** Transfer only when the amount is positive.

### SOL-Token-FE-11: Is the token an ERC2612 implementation?
- **Risk:** Missing `DOMAIN_SEPARATOR()` can lead to vulnerabilities in the ERC2612 permit functionality.
- **Fix:** Ensure complete and correct implementation of ERC2612, including the `DOMAIN_SEPARATOR()` function.

### SOL-Token-FE-12: Can the token be sent to any address?
- **Risk:** Certain addresses might be blocked or restricted to receive tokens (e.g. LUSD).
- **Fix:** Ensure the receiver blacklisting does not affect the protocol's functionality.

### SOL-Token-FE-13: Is there a direct approval to a non-zero value?
- **Risk:** Some ERC20 tokens do not work when changing the allowance from an existing non-zero allowance value. For example Tether (USDT)'s approve() function will revert if the current approval is not zero, to protect against front-running changes of approvals.
- **Fix:** Set the allowance to zero before increasing the allowance and use safeApprove/safeIncreaseAllowance.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-17-did-not-approve-to-zero-first-sherlock-notional-notional-git

### SOL-Token-FE-14: Is there a max approval used?
- **Risk:** Some tokens don't support approve `type(uint256).max` amount and revert.
- **Fix:** Avoid approval of `type(uint256).max`.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-3-universalapprovemax-will-not-work-for-some-tokens-that-dont-support-approve-typeuint256max-amount-sherlock-dodo-dodo-git

### SOL-Token-FE-15: Can the token be paused?
- **Risk:** Some ERC20 tokens can be paused by the contract owner.
- **Fix:** Ensure the protocol is not affected when the token is paused.

### SOL-Token-FE-16: Is the decrease allowance feature of transferFrom() handled correctly when the sender is the caller?
- **Risk:** Allowance should not be decreased in a transferFrom() call if the sender is the same as the caller, to prevent incorrect balance and allowance tracking.
- **Fix:** Ensure that the smart contract logic maintains correct allowance levels when transferFrom() involves the token owner themselves.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-2-transferfrom-uses-allowance-even-if-spender-from-sherlock-surge-surge-git

## Non-fungible : ERC721/1155

### SOL-Token-NfE1-1: How are the minting and transfer implemented?
- **Risk:** According to the ERC721 standard, a wallet/broker/auction application MUST implement the wallet interface if it will accept safe transfers. Use safe version of mint and transfer functions to prevent NFT being lost. (the similar applies to ERC1155)
- **Fix:** Use OpenZeppelin's safe mint/transfer functions for ERC721/1155.

### SOL-Token-NfE1-2: Is the contract safe from reentrancy attack?
- **Risk:** By standard, the token receiver contracts implement onERC721Received and onERC1155Received and this can potentially be a source of reentrancy attacks if not correctly handled.
- **Fix:** Double check the potential reentrancy attack.

### SOL-Token-NfE1-3: Is the OpenZeppelin implementation of ERC721 and ERC1155 safeguarded against reentrancy attacks, especially in the `safeTransferFrom` functions?
- **Risk:** The `safeTransferFrom` functions in OpenZeppelin's ERC721 and ERC1155 can expose the contract to reentrancy attacks due to external calls to user addresses.
- **Fix:** Use the checks-effects-interactions pattern and implement reentrancy guards to prevent potential reentrancy attacks when making external calls.

### SOL-Token-NfE1-4: Is it possible to steal NFT abusing his approval?
- **Risk:** Most of the time the `from` parameter of `transferFrom()` should be `msg.sender`. Otherwise an attacker can take advantage of other user's approvals and steal.
- **Fix:** Ensure that the contract verifies the `msg.sender` is actually the owner.

### SOL-Token-NfE1-5: Does the ERC721/1155 contract correctly implement supportsInterface?
- **Risk:** Contracts must properly implement the supportsInterface function to ensure they comply with ERC721/1155 standards and interoperate with other contracts correctly.
- **Fix:** Implement the supportsInterface function to return true for ERC721 and ERC1155 token types, ensuring accurate reporting of supported features.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-04-the-ferc1155sol-dont-respect-the-eip2981-code4rena-fractional-fractional-v2-contest-git

### SOL-Token-NfE1-6: Can the contract support both ERC721 and ERC1155 standards?
- **Risk:** To facilitate broader compatibility and usage in various applications, contracts may need to support both ERC721 and ERC1155 token standards.
- **Fix:** Use the supportsInterface method to check for and support interfaces of both ERC1155 and ERC721 within the same contract.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/h-06-some-real-world-nft-tokens-may-support-both-erc721-and-erc1155-standards-which-may-break-infinityexchange_transfernfts-code4rena-infinity-nft-marketplace-infinity-nft-marketplace-contest-git

### SOL-Token-NfE1-7: What happens to the airdrops that are engaged to specific NFT?
- **Risk:** For many NFT collections, a kind of privilege is provided in various ways, e.g. airdrop. The NFT owner must be able to claim the benefits while they lock in protocols.
- **Fix:** Ensure the NFT holders can claim all benefits.
- **Refs:** 1 case(s)
  - https://solodit.xyz/issues/m-04-its-possible-to-swap-nft-token-ids-without-fee-and-also-attacker-can-wrap-unwrap-all-the-nft-token-balance-of-the-pair-contract-and-steal-their-air-drops-for-those-token-ids-code4rena-caviar-caviar-contest-git

### SOL-Token-NfE1-8: How is the approval/transfer handled for CryptoPunks collection?
- **Risk:** CryptoPunks collections that do not support the `transferFrom()` function can present risks. The `offerPunkForSaleToAddress()` function in particular can be susceptible to front-running attacks, which can compromise the ownership and security of the token.
- **Fix:** Ensure validation is done properly to prevent malicious actors claiming the ownership.
- **Refs:** 2 case(s)
  - https://solodit.xyz/issues/h-3-cryptopunks-nfts-may-be-stolen-via-deposit-frontrunning-sherlock-ajna-ajna-git
  - https://solodit.xyz/issues/h-02-anyone-can-steal-cryptopunk-during-the-deposit-flow-to-wpunkgateway-code4rena-paraspace-paraspace-contest-git
