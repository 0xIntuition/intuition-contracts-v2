# Protocol Errors Reference

Complete catalog of all custom errors in Intuition Protocol V2 contracts with descriptions and recovery strategies.

## Table of Contents

- [MultiVault Errors](#multivault-errors)
- [TrustBonding Errors](#trustbonding-errors)
- [Emissions Controller Errors](#emissions-controller-errors)
- [Bonding Curve Errors](#bonding-curve-errors)
- [Wallet System Errors](#wallet-system-errors)
- [Trust Token Errors](#trust-token-errors)

## MultiVault Errors

### MultiVault_ZeroAddress

**Description**: A zero address was provided where a valid address is required.

**Causes**:
- Passing `address(0)` as receiver or sender
- Invalid contract addresses in configuration

**Recovery**: Provide a valid non-zero address

---

### MultiVault_Paused

**Description**: The protocol is currently paused.

**Causes**:
- Emergency pause activated by PAUSER_ROLE
- Protocol maintenance in progress

**Recovery**: Wait for protocol to be unpaused or contact protocol administrators

---

### MultiVault_InvalidCurveId

**Description**: The specified bonding curve ID does not exist.

**Causes**:
- Using an unregistered curve ID
- Typo in curve ID parameter

**Recovery**: Use a valid curve ID from the BondingCurveRegistry

---

### MultiVault_AtomAlreadyExists

**Description**: Attempting to create an atom that already exists.

**Causes**:
- Duplicate atom creation with same data and salt
- Atom ID collision

**Recovery**: Use existing atom or create with different data/salt

```typescript
// Check if atom exists first
const exists = await multiVault.isTermCreated(atomId);
if (exists) {
  // Deposit to existing atom instead
  await multiVault.deposit(receiver, atomId, curveId, assets, minShares);
} else {
  // Create new atom
  await multiVault.createAtoms([atomData], [assets], curveId, receiver, minShares);
}
```

---

### MultiVault_TripleAlreadyExists

**Description**: Attempting to create a triple that already exists.

**Causes**:
- Duplicate triple creation with same subject, predicate, object
- Triple ID collision

**Recovery**: Use existing triple or create different relationship

---

### MultiVault_AtomNotFound

**Description**: Referenced atom does not exist.

**Causes**:
- Attempting to create triple with non-existent atoms
- Using invalid atom ID

**Recovery**: Create the atom first, then create the triple

---

### MultiVault_InvalidAtomData

**Description**: Atom data exceeds maximum allowed length.

**Causes**:
- Atom data > 256 bytes
- Invalid data encoding

**Recovery**: Reduce atom data size to ≤256 bytes

---

### MultiVault_InsufficientAssets

**Description**: Insufficient assets provided for deposit.

**Causes**:
- Deposit amount < minimum required
- Assets below atom/triple creation cost

**Recovery**: Increase deposit amount

---

### MultiVault_MinSharesError

**Description**: Shares minted below minimum threshold (slippage protection).

**Causes**:
- Price moved unfavorably between preview and execution
- Slippage tolerance too tight

**Recovery**: Increase slippage tolerance or retry with updated price

```typescript
// Increase slippage tolerance
const [expectedShares] = await multiVault.previewDeposit(termId, curveId, assets);
const minShares = expectedShares * 95n / 100n; // 5% slippage instead of 1%

await multiVault.deposit(receiver, termId, curveId, assets, minShares);
```

---

### MultiVault_VaultNotFound

**Description**: Vault for specified term and curve does not exist.

**Causes**:
- Invalid termId or curveId combination
- Vault not yet created

**Recovery**: Verify term and curve IDs, create vault if needed

---

### MultiVault_InsufficientShares

**Description**: Insufficient shares available for redemption.

**Causes**:
- Attempting to redeem more shares than owned
- Shares already redeemed

**Recovery**: Check available shares with `getShares()`, reduce redemption amount

---

### MultiVault_MinAssetsError

**Description**: Assets received below minimum threshold (slippage protection).

**Causes**:
- Price moved unfavorably
- Slippage tolerance too tight

**Recovery**: Increase slippage tolerance or retry

---

### MultiVault_NoSharesToBurn

**Description**: No shares available to burn.

**Causes**:
- Attempting redemption with zero shares
- User has no position in vault

**Recovery**: Verify share balance before redemption

---

### MultiVault_InvalidFeeAmount

**Description**: Fee amount exceeds maximum allowed.

**Causes**:
- Protocol fee > 100%
- Invalid fee configuration

**Recovery**: Contact protocol administrators (governance issue)

## TrustBonding Errors

### TrustBonding_ClaimableProtocolFeesExceedBalance

**Description**: Attempting to claim more protocol fees than available balance.

**Causes**:
- Accounting error
- Fees already claimed

**Recovery**: Contact protocol administrators

---

### TrustBonding_InvalidEpoch

**Description**: Invalid epoch number provided.

**Causes**:
- Future epoch number
- Epoch before contract deployment

**Recovery**: Use valid epoch number (0 to current epoch)

---

### TrustBonding_InvalidUtilizationLowerBound

**Description**: Utilization lower bound is invalid.

**Causes**:
- Lower bound > 1e18 (100%)
- Negative lower bound

**Recovery**: Set lower bound between 0 and 1e18

---

### TrustBonding_InvalidStartTimestamp

**Description**: Invalid start timestamp during initialization.

**Causes**:
- Start timestamp in the past
- Start timestamp too far in future

**Recovery**: Provide valid start timestamp

---

### TrustBonding_NoClaimingDuringFirstEpoch

**Description**: Cannot claim rewards during the first epoch.

**Causes**:
- Attempting to claim in epoch 0
- Contract just deployed

**Recovery**: Wait for epoch 1 to claim rewards

---

### TrustBonding_NoRewardsToClaim

**Description**: No rewards available to claim.

**Causes**:
- Zero bonded balance
- Zero utilization
- Rewards already claimed for the epoch

**Recovery**: Bond TRUST, use protocol, wait for next epoch

```typescript
// Check rewards before claiming
const userInfo = await trustBonding.getUserInfo(userAddress, previousEpoch);

if (userInfo.eligibleRewards > 0n) {
  await trustBonding.claimRewards(recipient);
} else {
  console.log('No rewards available');
}
```

---

### TrustBonding_OnlyTimelock

**Description**: Function can only be called by timelock contract.

**Causes**:
- Direct call to timelock-protected function
- Unauthorized caller

**Recovery**: Submit governance proposal through timelock

---

### TrustBonding_RewardsAlreadyClaimedForEpoch

**Description**: Rewards already claimed for this epoch.

**Causes**:
- Duplicate claim attempt
- Claim already processed

**Recovery**: Wait for next epoch to claim again

---

### TrustBonding_ZeroAddress

**Description**: Zero address provided where valid address required.

**Causes**:
- Invalid recipient address
- Invalid contract address

**Recovery**: Provide valid non-zero address

## Emissions Controller Errors

### BaseEmissionsController_InvalidAddress

**Description**: Invalid address provided.

**Causes**:
- Zero address
- Invalid contract address

**Recovery**: Provide valid address

---

### BaseEmissionsController_InvalidEpoch

**Description**: Invalid epoch number.

**Causes**:
- Future epoch
- Epoch before deployment

**Recovery**: Use valid epoch number

---

### BaseEmissionsController_InsufficientGasPayment

**Description**: Insufficient gas payment for cross-chain message.

**Causes**:
- Gas payment < required amount
- Bridge gas price increased

**Recovery**: Increase gas payment

---

### BaseEmissionsController_EpochMintingLimitExceeded

**Description**: Attempted to mint more than epoch limit.

**Causes**:
- Multiple mint calls in same epoch
- Exceeding emission schedule

**Recovery**: Wait for next epoch

---

### BaseEmissionsController_InsufficientBurnableBalance

**Description**: Insufficient balance to burn.

**Causes**:
- Attempting to burn more than available
- Balance already burned

**Recovery**: Verify balance before burning

---

### BaseEmissionsController_SatelliteEmissionsControllerNotSet

**Description**: Satellite emissions controller not configured.

**Causes**:
- Contract not initialized properly
- Configuration missing

**Recovery**: Set satellite emissions controller address

---

### SatelliteEmissionsController_InvalidAddress

**Description**: Invalid address provided.

**Recovery**: Provide valid non-zero address

---

### SatelliteEmissionsController_InvalidAmount

**Description**: Invalid amount specified.

**Causes**:
- Zero amount
- Negative amount

**Recovery**: Provide positive amount

---

### SatelliteEmissionsController_InvalidBridgeAmount

**Description**: Invalid bridge amount.

**Causes**:
- Amount exceeds available balance
- Zero amount

**Recovery**: Verify available balance, adjust amount

---

### SatelliteEmissionsController_PreviouslyBridgedUnclaimedEmissions

**Description**: Unclaimed emissions already bridged for this epoch.

**Causes**:
- Duplicate bridge attempt
- Already processed

**Recovery**: Skip, already completed

---

### SatelliteEmissionsController_InsufficientBalance

**Description**: Insufficient balance for operation.

**Recovery**: Ensure sufficient balance available

---

### SatelliteEmissionsController_InsufficientGasPayment

**Description**: Insufficient gas payment for cross-chain message.

**Recovery**: Increase gas payment

---

### SatelliteEmissionsController_InvalidWithdrawAmount

**Description**: Invalid withdrawal amount.

**Recovery**: Provide valid withdrawal amount

---

### SatelliteEmissionsController_TrustBondingNotSet

**Description**: TrustBonding contract not configured.

**Recovery**: Set TrustBonding address

## Bonding Curve Errors

### BaseCurve_EmptyStringNotAllowed

**Description**: Empty string provided for curve name.

**Recovery**: Provide non-empty curve name

---

### BaseCurve_AssetsExceedTotalAssets

**Description**: Specified assets exceed total vault assets.

**Causes**:
- Calculation error
- Invalid parameters

**Recovery**: Verify asset amounts

---

### BaseCurve_SharesExceedTotalShares

**Description**: Specified shares exceed total vault shares.

**Recovery**: Verify share amounts

---

### BaseCurve_AssetsOverflowMax

**Description**: Assets calculation would overflow uint256.

**Causes**:
- Extremely large deposit
- Overflow in curve math

**Recovery**: Reduce deposit amount

---

### BaseCurve_SharesOverflowMax

**Description**: Shares calculation would overflow uint256.

**Recovery**: Reduce deposit amount

---

### BaseCurve_DomainExceeded

**Description**: Operation exceeds curve's valid domain.

**Causes**:
- Assets/shares exceed curve limits
- Invalid curve parameters

**Recovery**: Use smaller amounts or different curve

## Wallet System Errors

### AtomWarden_InvalidAddress

**Description**: Invalid address provided.

**Recovery**: Provide valid non-zero address

---

### AtomWarden_AtomIdDoesNotExist

**Description**: Atom ID does not exist.

**Causes**:
- Invalid atom ID
- Atom not created yet

**Recovery**: Create atom first

---

### AtomWarden_ClaimOwnershipFailed

**Description**: Ownership claim failed.

**Causes**:
- Atom data doesn't match claimer's address
- Already claimed

**Recovery**: Verify atom data contains your address

---

### AtomWarden_AtomWalletNotDeployed

**Description**: Atom wallet not yet deployed.

**Recovery**: Deploy wallet first via `getAtomWallet()`

---

### AtomWarden_InvalidNewOwnerAddress

**Description**: Invalid new owner address.

**Recovery**: Provide valid address

## Trust Token Errors

### Trust_ZeroAddress

**Description**: Zero address provided.

**Recovery**: Provide valid address

---

### Trust_OnlyBaseEmissionsController

**Description**: Function can only be called by BaseEmissionsController.

**Causes**:
- Unauthorized mint/burn attempt

**Recovery**: Operations must go through BaseEmissionsController

## Error Handling Best Practices

1. **Pre-Flight Validation**: Check conditions before submitting transactions
2. **Simulation**: Use `staticCall` to detect errors before execution
3. **Slippage Protection**: Always use `minShares`/`minAssets` parameters
4. **Balance Checks**: Verify balances and allowances before operations
5. **Error Parsing**: Decode custom errors from transaction failures
6. **User Feedback**: Provide clear, actionable error messages to users
7. **Retry Logic**: Implement appropriate retry strategies for transient errors
8. **Logging**: Log errors with context for debugging

## See Also

- [Error Handling Guide](../integration/error-handling.md) - Comprehensive error handling patterns
- [Events Reference](./events.md) - Protocol events
- [Transaction Flows](../integration/transaction-flows.md) - Transaction patterns
