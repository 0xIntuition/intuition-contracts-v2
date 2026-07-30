# v1.1.0 core upgrade — execution order

**Chain:** Intuition Mainnet (1155). This release is Intuition-chain-only; there is no Base component.

**Signing Safe:** `0xbeA18ab4c83a12be25f8AA8A10D8747A07Cdc6eb` — Gnosis Safe v1.3.0, 4-of-8.

This is the canonical order. Every dependency below is an on-chain constraint, not a preference — executing out of order
either reverts or breaks the chain. Read the whole document before signing anything.

---

## 0. What you are about to do, in one paragraph

Six live implementations are swapped in a single atomic timelock operation, and then two reinitializers and a small
number of role grants are executed directly by the Admin Safe. The upgrade touches contracts holding user funds. The
single most important property is that **all six upgrades move together**: the new MultiVault probes fee-hook getters on
every registered curve on every deposit and redeem, and the live curve implementations predate those selectors. A
MultiVault swapped without its curves makes **every deposit and redeem on the chain revert**.

## 1. One Safe, two instruments — read this before looking for a second Safe

The upgrades go through the Upgrades TimelockController; the reinitializers and role grants are sent directly. That is a
separation of **roles**, not of **addresses**. On this chain `0xbeA18ab4c83a12be25f8AA8A10D8747A07Cdc6eb` holds all of
them:

| Role                                               | On                                                                                                                  |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `PROPOSER_ROLE`, `EXECUTOR_ROLE`, `CANCELLER_ROLE` | Upgrades Timelock `0x321e5d4b20158648dFd1f360A79CAFc97190bAd1`                                                      |
| `DEFAULT_ADMIN_ROLE`                               | MultiVault `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e` and AtomWarden `0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165` |
| `owner()`                                          | BondingCurveRegistry `0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930`                                                   |

There is no second Safe. Every batch in this folder is imported into and signed by that one Safe.

## 1a. Two contracts in this release are NOT upgrades

`FeeProxy` and `DynamicFeeFlatPriceCurve` both ship with v1.1.0, and neither has an existing proxy behind it. They are
fresh deployments, so nothing about them belongs in the timelock operation — their absence from the upgrade batch is
correct, not an omission.

| Contract                   | How it ships                                                                 | Safe transactions                                                                                                                                      |
| -------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `FeeProxy`                 | `forge` broadcast of `script/intuition/FeeProxyDeploy.s.sol`                 | **None.** Its admin, treasury, MultiVault target and proxy admin are all set by the atomic `initialize`, and no core contract holds a reference to it. |
| `DynamicFeeFlatPriceCurve` | `forge` broadcast of `script/intuition/DeployDynamicFeeFlatPriceCurve.s.sol` | **One** — step 08 below, `BondingCurveRegistry.addBondingCurve`.                                                                                       |

Both are independent of the upgrade's timing: they can be deployed before or after it. Record each in the
deployed-contracts table in `README.md` once its address exists — there is a "Pending v1.1.0 additions" section there
listing exactly this.

## 2. Why the reinitializers are separate transactions

They cannot be embedded in `upgradeAndCall`. A proxy executes embedded initialization calldata via `delegatecall` with
`msg.sender == ProxyAdmin`, and the ProxyAdmin holds neither `DEFAULT_ADMIN_ROLE` nor the AtomWarden admin identity — so
it reverts. Per proxy the sequence is therefore: timelock → `upgradeAndCall(proxy, impl, "")` with **empty** calldata,
then Admin Safe → `reinitialize(...)` as its own transaction.

## 3. Pre-flight — run these before importing anything

Read-only, public RPC, no keys required.

```bash
export RPC=https://rpc.intuition.systems/http
export TIMELOCK=0x321e5d4b20158648dFd1f360A79CAFc97190bAd1
export SAFE=0xbeA18ab4c83a12be25f8AA8A10D8747A07Cdc6eb
export MULTIVAULT=0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e
export REGISTRY=0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930

# Timelock delay. The generator hardcodes 604800; if this differs, step 01 reverts.
cast call $TIMELOCK 'getMinDelay()(uint256)' -r $RPC              # expect 604800

# The Safe still holds every role the runbook assumes.
cast call $TIMELOCK 'hasRole(bytes32,address)(bool)' \
  0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1 $SAFE -r $RPC  # PROPOSER
cast call $TIMELOCK 'hasRole(bytes32,address)(bool)' \
  0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63 $SAFE -r $RPC  # EXECUTOR
cast call $TIMELOCK 'hasRole(bytes32,address)(bool)' \
  0xfd643c72710c63c0180259aba6b2d05451e3591a24e58b62239378085726f783 $SAFE -r $RPC  # CANCELLER

# The Admin Safe is still the MultiVault admin and the registry owner.
cast call $MULTIVAULT 'generalConfig()(address,address,uint256,uint256,uint256,uint256,uint256,uint256)' -r $RPC | head -1
cast call $REGISTRY 'owner()(address)' -r $RPC

# THE CRITICAL ONE. Every registered curve must be covered by the upgrade batch.
# If count() is greater than the number of curves the batch upgrades, STOP.
cast call $REGISTRY 'count()(uint256)' -r $RPC                    # expect 2
cast call $REGISTRY 'curveAddresses(uint256)(address)' 1 -r $RPC  # expect 0xc3eFD5471dc63d74639725f381f9686e3F264366
cast call $REGISTRY 'curveAddresses(uint256)(address)' 2 -r $RPC  # expect 0x23afF95153aa88D28B9B97Ba97629E05D5fD335d
```

Also confirm, off-chain:

- The six implementation addresses in the batches match the addresses the deploy script printed, and each is verified on
  the explorer.
- The MultiVault implementation is verified **together with its `MultiVaultLib` library**. It is linked, and Foundry
  auto-deploys the library as the first broadcast transaction; its address is in
  `broadcast/DeployCoreUpgradeImplementations.s.sol/1155/run-latest.json`. A linked contract verified without its
  library is only half verified — `--verify` does not necessarily handle this for you.
- `forge test --match-contract SafeBatchCalldataParity` passes against the committed batches.

---

## 4. The order

| Step | File                                           | Signer acts as    | Gate                      |
| ---- | ---------------------------------------------- | ----------------- | ------------------------- |
| 01   | `01-…-upgrades-timelock-schedule.json`         | Timelock proposer | none — execute now        |
| 02   | `02-…-upgrades-timelock-execute.json`          | Timelock executor | step 01 + 7 days          |
| 03   | `03-…-multivault-reinitialize.json`            | MultiVault admin  | step 02 verified          |
| 04   | `04-…-atomwarden-reinitialize.json`            | AtomWarden admin  | step 02 verified          |
| 05   | `05-…-atomwarden-grant-signer-role.json`       | AtomWarden admin  | step 04                   |
| 06   | `06-…-atomwarden-set-signature-threshold.json` | AtomWarden admin  | **step 05 confirmed**     |
| 07   | `07-…-multivault-grant-pauser-role.json`       | MultiVault admin  | step 03                   |
| 08   | `08-…-register-dynamic-fee-curve.json`         | Registry owner    | upgrade confirmed healthy |

Steps 05–08 are emitted only when their constants are filled in. If a file is missing, the generator printed a `WARNING`
explaining what was skipped and what stays broken — go read it rather than assuming the step is unnecessary.

---

### Step 01 — schedule the upgrade

Import and execute `01-…-upgrades-timelock-schedule.json`.

This one transaction calls `scheduleBatch` with all six upgrades. It is `scheduleBatch` rather than six separate
`schedule` calls on purpose: six singular timelock operations could each be executed alone, and executing the MultiVault
upgrade without the curve upgrades is exactly the failure this release must not permit. `executeBatch` succeeds or
reverts as a unit.

**Scheduling changes nothing.** It only starts the clock. Nothing is upgraded until step 02.

Before signing, decode the transaction in the Safe UI and check:

- `targets` has **six** entries, in the order listed in the batch description.
- Entries 5 and 6 are the LinearCurve and OffsetProgressiveCurve ProxyAdmins. **If either curve is missing, do not
  sign.** That is the chain-breaking mistake.
- Every `payloads` entry ends in a run of zero bytes representing empty `bytes` — no reinitializer calldata is embedded.
- `predecessor` is zero and `delay` is `604800`.

After execution, record the operation id (printed by the generator and quoted in the batch description) and confirm the
timelock accepted it:

```bash
cast call $TIMELOCK 'isOperation(bytes32)(bool)' <OPERATION_ID> -r $RPC          # true
cast call $TIMELOCK 'getTimestamp(bytes32)(uint256)' <OPERATION_ID> -r $RPC      # ready-at
```

### Wait — 7 days

`604800` seconds. During the wait, nothing has changed on-chain.

If something is discovered in this window, the same Safe holds `CANCELLER_ROLE` and can abort cleanly — nothing was ever
applied. Send a Safe transaction to the Upgrades Timelock calling `cancel(bytes32)` with the operation id. Build the
calldata with:

```bash
cast calldata 'cancel(bytes32)' <OPERATION_ID>
```

Confirm afterwards that `isOperation(<OPERATION_ID>)` returns false.

### Step 02 — execute the upgrade

**This is the upgrade.** Do not import until:

```bash
cast call $TIMELOCK 'isOperationReady(bytes32)(bool)' <OPERATION_ID> -r $RPC     # must be true
```

`isOperationReady` returns false until the delay has fully elapsed. The batch reuses the step-01 arguments byte for byte
— the timelock recomputes the operation id from them, so any divergence reverts rather than executing something
unintended.

**Immediately after execution, before doing anything else, verify the chain still works:**

```bash
# Implementation pointers moved (EIP-1967 slot).
for p in 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e \
         0x635bBD1367B66E7B16a21D6E5A63C812fFC00617 \
         0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165 \
         0xc3eFD5471dc63d74639725f381f9686e3F264366 \
         0x23afF95153aa88D28B9B97Ba97629E05D5fD335d; do
  cast storage $p 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc -r $RPC
done

# Beacon pointer moved.
cast call 0xC23cD55CF924b3FE4b97deAA0EAF222a5082A1FF 'implementation()(address)' -r $RPC

# THE ONE THAT MATTERS: the fee-hook getters resolve on both curves. If either of these
# reverts instead of returning false, deposits and redeems on that curve are bricked.
cast call 0xc3eFD5471dc63d74639725f381f9686e3F264366 'hasDepositFeeHook()(bool)' -r $RPC
cast call 0xc3eFD5471dc63d74639725f381f9686e3F264366 'hasRedeemFeeHook()(bool)' -r $RPC
cast call 0x23afF95153aa88D28B9B97Ba97629E05D5fD335d 'hasDepositFeeHook()(bool)' -r $RPC
cast call 0x23afF95153aa88D28B9B97Ba97629E05D5fD335d 'hasRedeemFeeHook()(bool)' -r $RPC
```

Then perform a **real small deposit and redeem on both curve ids**. The view calls above confirm the selectors exist;
only an actual deposit confirms the whole path. Do this before proceeding to step 03.

### Step 03 — `MultiVault.reinitialize`

Bootstraps `MultiVault.timelock` to the Parameters TimelockController `0x71b0F1ABebC2DaA0b7B5C3f9b72FAa1cd9F35FEA` and
grants `PAUSER_ROLE` to the admin.

Required — the upgrade is not complete without it. Verify afterwards:

```bash
cast call $MULTIVAULT 'timelock()(address)' -r $RPC   # 0x71b0F1ABebC2DaA0b7B5C3f9b72FAa1cd9F35FEA
cast call $MULTIVAULT 'hasRole(bytes32,address)(bool)' \
  0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a $SAFE -r $RPC   # true
```

### Step 04 — `AtomWarden.reinitialize`

Seeds the claim parameters. Note the per-window claim cap ships **armed** at 100 claims per 1-day window; the deploy
script's default of `0` would disable it, and launching a new safety control switched off is not the intent. The admin
can retune it later through the regular setter, without an upgrade.

Required. Verify afterwards:

```bash
export WARDEN=0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165
cast call $WARDEN 'signatureThreshold()(uint256)' -r $RPC     # 1
cast call $WARDEN 'maxClaimsPerWindow()(uint256)' -r $RPC     # 100 — NOT 0
cast call $WARDEN 'claimCapWindow()(uint256)' -r $RPC         # 86400
cast call $WARDEN 'signerCount()(uint256)' -r $RPC            # 0 — expected, see step 05
```

> **`signerCount` is 0 here and that is intentional.** Signed claims revert until step 05. The upgrade is technically
> applied but **not operationally finished**. Do not declare the rollout complete at this point.

### Step 05 — grant `SIGNER_ROLE`

Grants `SIGNER_ROLE` to each backend signer key. This is the step that makes `claimWithAuthorization` work again;
skipping it leaves wallet claims broken behind an otherwise-successful upgrade.

This is the one batch that contains more than one transaction, because they are the same call repeated per address.

```bash
cast call $WARDEN 'signerCount()(uint256)' -r $RPC   # must now equal the number of signers granted
```

### Step 06 — `setSignatureThreshold`

**Do not execute until step 05 has executed and `signerCount` has been confirmed.** `setSignatureThreshold` reverts when
`newThreshold > signerCount`. The 05→06 order is enforced by the contract, not by convention — running them the other
way round wastes a Safe execution on a guaranteed revert.

```bash
cast call $WARDEN 'signerCount()(uint256)' -r $RPC        # must be >= the new threshold
# ... execute step 06 ...
cast call $WARDEN 'signatureThreshold()(uint256)' -r $RPC # the new threshold
```

### Step 07 — grant `PAUSER_ROLE` to the pauser Safe

Additive and non-urgent: step 03 already granted `PAUSER_ROLE` to the admin, so the protocol is pausable without this.
It exists because the admin is a 4-of-8 Safe, which is a slow instrument for the one action whose entire value is being
fast.

### Step 08 — register the DynamicFeeFlatPriceCurve

**Only after the upgrade is confirmed live and healthy.** This is deliberately not bundled with the reinitializers: the
upgrade batch carries a hard atomicity requirement and stays exactly as large as that requires, and registering a curve
into a registry that the upgraded MultiVault has not yet been confirmed to read correctly inverts the verification
order.

**Registration is irreversible.** Curve ids are append-only. Before signing, verify:

```bash
export CURVE=<the DynamicFeeFlatPriceCurve proxy>

# (a) Wired to the production MultiVault. Its record hooks are onlyMultiVault; a miswired
#     curve makes every deposit and redeem on its id revert, permanently.
cast call $CURVE 'multiVault()(address)' -r $RPC     # must equal $MULTIVAULT

# (b) Ownership transferred off the deploying EOA. The deploy script sets owner = msg.sender.
cast call $CURVE 'owner()(address)' -r $RPC          # must be the intended governance address
```

And (c) fork-simulate this transaction followed by a deposit on the new curve id, and confirm the deposit succeeds.

After registration:

```bash
cast call $REGISTRY 'count()(uint256)' -r $RPC
cast call $REGISTRY 'curveIds(address)(uint256)' $CURVE -r $RPC   # the assigned id
```

### After step 08 — update the coverage guard

Registration takes `registry.count()` to 3, so the deliberate exact-count assertion in `_assertCurvesApplied` (in
`script/intuition/v1.1.0/DeployCoreUpgradeImplementations.s.sol`) **will start failing**. That is the intended signal,
not a defect — but it must be resolved properly, because the assertion only pins ids 1 and 2 today, so bumping the count
alone would silently widen the guard to accept an unchecked third curve.

Make all three changes together:

1. Increment `COVERED_CURVE_COUNT` to `3`.
2. Add an explicit id/address pin for the new curve, matching the existing ones:
   `registry.curveAddresses(<new id>) != <new curve proxy>` reverts. Use the id actually assigned by
   `registry.curveIds(<curve>)` — do not assume it is 3.
3. Add a fee-hook getter assertion for it, alongside the two existing curves, confirming `hasDepositFeeHook()` /
   `hasRedeemFeeHook()` resolve rather than revert.

Point 3 matters even though the curve was deployed on v1.1.0 code: the assertion's purpose is to prove the MultiVault's
per-deposit hook probe cannot revert on a missing selector, and that should be established for every registered curve
rather than assumed from its provenance.

If the guard ever needs to cover several curves, replace the exact count and the per-id pins with a loop over
`1..count()` checking each address against an explicit covered set — but keep it strict either way. Never relax it to a
lower bound to make a failure go away; a failure here means a live curve would be bricked by the next upgrade.

---

## 5. Rollback

There is no rollback for an executed upgrade. The realistic responses are:

- **Before step 02:** cancel the timelock operation. Nothing was applied.
- **After step 02:** pause via `PAUSER_ROLE`, then schedule a new timelock operation pointing the proxies back at the
  previous implementations. That is another 7-day wait, which is why the fork rehearsal and the post-step-02
  deposit/redeem check are not optional.

## 6. Regenerating these files

```bash
# from the repository root
bun script/intuition/v1.1.0/safe-txs/generate-v1.1.0-safe-batches.ts
```

The generator is offline and deterministic: same inputs produce byte-identical files, so a clean `git diff` after
regenerating is the proof that nothing drifted. It refuses to emit while any implementation address is still a
placeholder. Change a parameter by editing the constant at the top of the generator and regenerating — the diff is the
review.
