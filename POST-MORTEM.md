# TrustBonding VotingEscrow Underflow Post-Mortem

## Summary

- **Date:** 2025-11-18
- **Contract:** TrustBonding (`0x635bBD1367B66E7B16a21D6E5A63C812fFC00617`)
- **Status:** [PR #126](https://github.com/0xIntuition/intuition-contracts-v2/pull/126) prepared

A critical arithmetic underflow vulnerability in VotingEscrow's `_supply_at` function caused all reward claiming
operations to fail after the first VotingEscrow checkpoint was created post-epoch boundary. The bug manifested when
`_totalSupply()` queried historical timestamps that preceded the latest checkpoint, causing an unsigned subtraction to
underflow with `Panic(0x11)`.

## Timeline of Events

### Incident Chronology

| Timestamp (UTC)      | Phase              | Event                | Details                                                    |
| -------------------- | ------------------ | -------------------- | ---------------------------------------------------------- |
| 2025-11-18 15:00:00  | Trigger            | Epoch 0 ends         | `epochTimestampEnd(0) = 1763478000`                        |
| 2025-11-18 15:00:42  | User Operation     | Successful claim     | User `0xc260...6d629` claims 20.21 TRUST                   |
| 2025-11-18 15:01:31  | **Incident Start** | Breaking transaction | Checkpoint #11907 created with `ts > epochTimestampEnd(0)` |
| 2025-11-18 15:01:31+ | Impact             | All claims fail      | Every `claimRewards` reverts with `Panic(0x11)`            |

### Root Cause Identification

#### Breaking Transaction

[`0xd239a60b0d3f24b4384657184cd8256ae9d15fbf6c3e7bc450dd19d232f3b5f6`](https://explorer.intuition.systems/tx/0xd239a60b0d3f24b4384657184cd8256ae9d15fbf6c3e7bc450dd19d232f3b5f6)

- Block: 115261
- Caller: `0x30B8...CF99`
- Function: `increase_amount(50e18)` (50 TRUST)
- Effect: Created VotingEscrow checkpoint #11907 with `ts = 1763478091`

#### Checkpoint State Comparison

| Checkpoint  | Timestamp  | Relation to Epoch End |
| ----------- | ---------- | --------------------- |
| #11906      | 1763477974 | 26s BEFORE            |
| Epoch 0 End | 1763478000 | -                     |
| #11907      | 1763478091 | 91s AFTER             |

#### Breakdown

1. `increase_amount(50e18)` routes to `_deposit_for` (`VotingEscrow.sol:352-370`), which credits the caller's
   `locked_balance` and always runs `_checkpoint`
2. `_checkpoint` increments `epoch` and writes `point_history[++epoch]` with the current block timestamp (lines 420-470)
3. Before the tx: epoch 11906 had `ts = 1763477974` (26s before `epochTimestampEnd(0) = 1763478000`)
4. After the tx: epoch 11907 recorded `ts = 1763478091` (91s after the epoch boundary)
5. `_totalSupply` selects `last_point = point_history[epoch]`, so every query for epoch 0 now starts from checkpoint
   11907
6. Claims request `t_i = _epochTimestampEnd(epoch)`, feeding `_totalSupply(1763478000)` while
   `last_point.ts = 1763478091`
7. The critical line `last_point.bias -= last_point.slope * int128(int256(t_i - last_point.ts));` computes
   `1763478000 - 1763478091`, which underflows in unchecked uint arithmetic
8. The underflow triggers `Panic(0x11)` before any per-user logic runs
9. Every subsequent `claimRewards` call reverts via: `claimRewards → totalBondedBalanceAtEpochEnd → _totalSupply`
10. Earlier claims succeeded because checkpoint 11906 had `ts ≤ t_i`, avoiding the underflow

## Technical Details

### Vulnerability Location

`src/external/curve/VotingEscrow.sol:628`

```solidity
last_point.bias -= last_point.slope * int128(int256(t_i - last_point.ts));
//                                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//                                           Unsigned subtraction underflows
//                                           when t_i < last_point.ts
```

### Incident Replay

1. User calls `increase_amount(50e18)` at block 115261
2. `increase_amount` → `_deposit_for` → `_checkpoint()`
3. New checkpoint #11907 created with `ts = 1763478091`
4. `_totalSupply()` always used `point_history[epoch]` (latest checkpoint)
5. Any query for `_totalSupply(1763478000)` attempts: `1763478000 - 1763478091`
6. Unsigned subtraction underflows → `Panic(0x11)`

### Affected Functions

All three view functions fail with identical root cause:

- `getUserCurrentClaimableRewards(address)`
- `getUserRewardsForEpoch(address, uint256)`
- `userEligibleRewardsForEpoch(address, uint256)`

#### Call Stack

```
claimRewards(account)
  → getUserCurrentClaimableRewards(account)
    → _userEligibleRewardsForEpoch(account, prevEpoch)
      → totalBondedBalanceAtEpochEnd(prevEpoch)
        → _totalSupply(_epochTimestampEnd(prevEpoch))
          → _supply_at(point_history[epoch], t)
            → line 628: t_i - last_point.ts → UNDERFLOW
```

## Impact Assessment

### Quantified Impact

| Metric                               | Value                                  |
| ------------------------------------ | -------------------------------------- |
| Duration of outage                   | From 15:01:31 UTC until fix deployment |
| Claim window before failure          | 49 seconds                             |
| Blocks between epoch end and failure | 54 blocks (115207 → 115261)            |

### Verified Successful Claim

User `0xc26094c5c0b5465bae76a317414ef25466e6d629`:

- Transaction:
  [`0x40188012068faa9cf908afb7fcd1b99980ccd51b7c6af6bdd6a0057a343621ac`](https://explorer.intuition.systems/tx/0x40188012068faa9cf908afb7fcd1b99980ccd51b7c6af6bdd6a0057a343621ac)
- Block: 115207 (54 blocks before breaking tx)
- Amount claimed: `20210027815795264758479` wei (~20.21 TRUST)
- Verification: `userClaimedRewardsForEpoch[user][0]` matches claimed amount

## Resolution

### Immediate Fix (PR #126)

#### Approach

Historical checkpoint selection via binary search

```solidity
function _totalSupply(uint256 t) internal view returns (uint256) {
    uint256 _epoch = epoch;
    if (_epoch == 0) return 0;
    if (t < point_history[0].ts) return 0;

    uint256 target_epoch = _find_timestamp_epoch(t, _epoch);
    Point memory point = point_history[target_epoch];
    return _supply_at(point, t);
}
```

#### Key Changes

1. `_find_timestamp_epoch` - Binary search for global checkpoint where `ts ≤ t`
2. `_find_user_timestamp_epoch` - Binary search for user checkpoint
3. Guard clauses for edge cases (no checkpoints, pre-deployment queries)
4. Updated `_balanceOf` with timestamp-based epoch lookup

#### Defense-in-Depth

The fix ensures:

- `_supply_at` always receives checkpoints where `point.ts ≤ t`
- Historical queries return correct values (not fabricated)
- Both `_totalSupply` and `_balanceOf` protected

## Lessons Learned

The code assumed `_totalSupply(t)` would always query timestamps `≥` the latest checkpoint, but historical queries
(epoch end timestamps) can precede recent checkpoints.

## Conclusion

This incident resulted from a temporal invariant violation in VotingEscrow's historical supply calculation. The
vulnerability was latent until the first checkpoint after an epoch boundary created a timestamp gap that triggered
unsigned arithmetic underflow.

The fix (PR #126) correctly addresses the root cause by selecting the appropriate historical checkpoint via binary
search, ensuring `_supply_at` always operates in its intended forward-marching mode. This approach preserves semantic
correctness while preventing the panic.
