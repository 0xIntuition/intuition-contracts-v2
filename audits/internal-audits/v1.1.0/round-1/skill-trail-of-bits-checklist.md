# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 1

## Report 3 of 6 — Trail of Bits skill (`smart-contract-audit`, single-reviewer checklist)

> **How this report was produced:** one independent reviewer ran the local `smart-contract-audit` skill — a 370-item
> Solodit/Cyfrin-derived checklist across 13 categories — as a **single pass** over the whole in-scope set, anchoring
> every finding to a checklist item id and scoring against the §5 invariants with refutation attempts. In this batch it
> is labeled the **"Trail of Bits skill"** round: the checklist skill in single-reviewer mode. Its 10-agent-per-contract
> sibling is the **"Cyfrin skill"** report
> ([`skill-cyfrin-checklist-multiagent.md`](skill-cyfrin-checklist-multiagent.md)). Provenance ID prefix: `TOB-`. This
> is one of six independent round reports; the consolidated, de-duplicated view is
> [`MASTER-consolidated-report.md`](MASTER-consolidated-report.md).

---

**Report type:** Internal AI pseudo-audit — pre-external-audit adversarial security pass. **This is not a formal audit,
certification, warranty, or guarantee of safety.** It is an internal, first-party review conducted before the external
audit and is intended to feed that engagement.

|                     |                                                                                                                                                                                                      |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Project**         | Intuition — `intuition-contracts-v2` (public mirror), v1.1.0 core upgrade                                                                                                                            |
| **Reviewed commit** | `b52557bc5d1e87537e621fc13917240d40044c24`                                                                                                                                                           |
| **Branch**          | `feat/v1.1.0-core-upgrade`                                                                                                                                                                           |
| **Round**           | Checklist-driven (Solodit-anchored) — single independent reviewer pass                                                                                                                               |
| **Date**            | 2026-07-24                                                                                                                                                                                           |
| **Target networks** | Intuition Mainnet (chain id `1155`), Intuition Testnet (chain id `13579`) — Intuition-chain only                                                                                                     |
| **Toolchain**       | Foundry `1.5.1`, Solidity `0.8.29`, TransparentUpgradeableProxy                                                                                                                                      |
| **Method**          | Whole-contract adversarial review anchored to a 370-item Solodit-derived checklist, scored against the round's invariants and cluster hypotheses; storage layout cross-checked with `forge inspect`. |

---

## 1. Executive summary

This round performed a whole-contract adversarial review of the v1.1.0 in-scope set — the payable-multicall
value-virtualization machinery, the extracted write-path library, the bonding-curve dispatch, the ERC-4337/P-256 atom
wallet stack, the EIP-712 quorum warden with its new per-window claim cap, the ve-style bonding/emissions contracts, and
the native-value fee-routing periphery — not merely the v1.1.0 delta. The review adopted the mandated posture that at
least one fund-loss, mint/burn-imbalance, or trust-boundary bug exists, and for each load-bearing property either
produced an exploit path or an evidenced refutation.

**No Critical or Major issues were identified.** The core value-conservation, solvency, curve-ledger, flat-price-par,
storage-layout, and `msg.value`-replay properties all held under adversarial pressure, with the refutation attempts
recorded in §7. Two **Medium** issues were found: a raw-digest ERC-1271 validation path on the atom wallet that pushes
cross-account/cross-chain signature binding entirely onto integrators (TOB-01), and a reward-forfeiture interaction
where pausing across a full epoch permanently burns the prior epoch's claimable rewards (TOB-02). The remaining issues
are Minor (input validation, deploy-time invariants, self-inflicted DoS/stranding) and Informational (hygiene,
consistency, spec-vs-behavior).

One scope note materially shapes this report: **Cluster C (`DynamicFeeFlatPriceCurve` and the standardized `IBaseCurve`
quote/record fee hooks) is not present at the reviewed commit** and was therefore not audited (see §3).

### Findings by severity

| Severity      | Count  |
| ------------- | ------ |
| Critical      | 0      |
| Major         | 0      |
| Medium        | 2      |
| Minor         | 6      |
| Informational | 7      |
| **Total**     | **15** |

---

## 2. Scope

Real source root is `src/`. The in-scope set (whole-contract, per the round mandate):

| Contract                       | Path                                                      | v1.1.0 surface reviewed                                                                                                                                                                                               |
| ------------------------------ | --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MultiVault`                   | `src/protocol/MultiVault.sol`                             | Payable multicall with transient per-leg value virtualization + selector allowlist; on-behalf-of creates; atom-creation attribution; system-utilization rollover; `PAUSER_ROLE` + timelock setters; `reinitialize(2)` |
| `MultiVaultCore`               | `src/protocol/MultiVaultCore.sol`                         | Core storage/config + term/vault primitives                                                                                                                                                                           |
| `MultiVaultLib`                | `src/libraries/MultiVaultLib.sol`                         | Extracted create/deposit/redeem write-path bodies (delegatecall); storage-slot mirror of `MultiVault`                                                                                                                 |
| `BondingCurveRegistry`         | `src/protocol/curves/BondingCurveRegistry.sol`            | Curve resolution by id/address                                                                                                                                                                                        |
| `BaseCurve`                    | `src/protocol/curves/BaseCurve.sol`                       | Abstract base (no fee hooks present at this commit)                                                                                                                                                                   |
| `LinearCurve`                  | `src/protocol/curves/LinearCurve.sol`                     | Pro-rata pricing (1:1 at par)                                                                                                                                                                                         |
| `AtomWallet`                   | `src/protocol/wallet/AtomWallet.sol`                      | ERC-4337 + P-256/WebAuthn, MultiOwnable, `completeClaim`, `validateUserOp` / `isValidSignature`                                                                                                                       |
| `AtomWalletFactory`            | `src/protocol/wallet/AtomWalletFactory.sol`               | Deterministic CREATE2/beacon deployment                                                                                                                                                                               |
| `AtomWarden`                   | `src/protocol/wallet/AtomWarden.sol`                      | EIP-712 quorum claims + new governable per-window claim cap                                                                                                                                                           |
| `TrustBonding`                 | `src/protocol/emissions/TrustBonding.sol`                 | Extended pause gating; epoch reward + utilization accounting                                                                                                                                                          |
| `CoreEmissionsController`      | `src/protocol/emissions/CoreEmissionsController.sol`      | Emission-schedule math                                                                                                                                                                                                |
| `SatelliteEmissionsController` | `src/protocol/emissions/SatelliteEmissionsController.sol` | Intuition-side TRUST-transfer accounting (dispatch leg out of scope)                                                                                                                                                  |
| `FeeProxy`                     | `src/periphery/FeeProxy.sol`                              | Fee math, approval gating, push+pull refund ledger, global + per-affiliate pause                                                                                                                                      |
| `CoinbaseSmartWalletLib`       | `src/libraries/CoinbaseSmartWalletLib.sol`                | P-256/WebAuthn + MultiOwnable primitives folded into `AtomWallet`                                                                                                                                                     |

**Out of scope (honored):** Trust Swap and swap periphery; the bridge router / MetaLayer cross-chain messaging
(`MetaERC20Dispatcher` transport leg, `IMetaLayer`); `BaseEmissionsController` and all Base-chain components; the TVL
exit circuit breaker / rate limiter (deliberately parked); cross-curve counter-stake aggregation (rejected on
principle); `MultiVaultMigrationMode` (`MIGRATOR_ROLE`, revoked post-migration); `ProgressiveCurve` /
`OffsetProgressiveCurve` / `ProgressiveCurveMathLib` pricing math (in scope only for hook-default conformance, which is
trivially met — no hooks exist); legacy `Trust` / `TrustToken` / `WrappedTrust` / `VotingEscrow` internals;
trusted-admin centralization (4-of-8 Safe through two `TimelockController`s, parameters 3-day / upgrades 7-day) — an
accepted trust assumption; the held-out `executeFromExecutor` delegation framework; whole-surface mixed
payable/non-payable `multicallPayable` batching.

---

## 3. Scope reconciliation at `b52557b` — Cluster C not present

Cluster C (`DynamicFeeFlatPriceCurve` plus the standardized `IBaseCurve`
`quoteDepositFee`/`quoteRedeemFee`/`recordDeposit`/`recordRedeem` hooks and the MasterChef fee accumulator) **is not
merged at the reviewed commit.**

Evidence: `grep -rl "quoteDepositFee\|recordDeposit\|accFeePerShare\|DynamicFeeFlatPriceCurve" src` returns nothing;
there is no `src/protocol/curves/DynamicFeeFlatPriceCurve.sol` and no `IDynamicFeeFlatPriceCurve`; `BaseCurve` and
`IBaseCurve` expose no fee-hook getters and no quote/record hooks. The curve surface at this commit is the pre-upgrade
pricing set. Cluster C is therefore marked **not present — not audited**, and no finding in this report references the
tiered fee economy. The handoff's "a curve without hooks must be byte-identical to pre-upgrade" property is trivially
satisfied because there are no hooks.

---

## 4. Severity classification

Impact × Likelihood, using the Diligence-style labels. The round's working severities map onto the report labels as:
Critical→Critical, High→Major, Medium→Medium, Low→Minor, Informational→Informational.

| Label             | Meaning                                                                                                                                                      |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Critical**      | Permissionless or realistically reachable path to direct theft, permanent loss, insolvency, unrestricted mint/withdraw, or capture of upgrade/admin control. |
| **Major**         | A core invariant or authorization boundary breaks with severe (not total) impact, or an upgrade path corrupts critical state.                                |
| **Medium**        | Bounded loss, temporary stuck funds, realistic griefing/DoS of a funds path, an admin footgun, or a spec regression materially affecting users/operators.    |
| **Minor**         | Limited impact, weak validation blocked by another guard, confusing behavior, or a monitoring/integration weakness.                                          |
| **Informational** | Documentation, hygiene, NatSpec-vs-behavior mismatch, or a missing non-critical test.                                                                        |

Permissionless exploitability is separated from trusted-admin misuse throughout; centralization is an accepted trust
assumption and is not filed as a finding.

---

## 5. Findings

Highest severity first. Round/model provenance is preserved on each id; all ids carry the `TOB-` prefix.

### 5.1 TOB-01 · Medium · ERC-1271 raw-digest validation enables cross-account / cross-chain signature replay

**Cluster E.** `src/protocol/wallet/AtomWallet.sol:341-346`. Checklist anchors: SOL-Signature-1, SOL-AM-ReplayAttack-2,
SOL-Heuristics-9.

**Description.** `isValidSignature(bytes32 hash, bytes calldata signature)` forwards the **raw** `hash` directly into
`CoinbaseSmartWalletLib.isValidSignature` with no per-account or per-chain binding. The library ports upstream
Coinbase's `replaySafeHash` / `domainSeparator` (which wrap the digest in an EIP-712 hash including
`verifyingContract = address(this)` and `block.chainid`) at `src/libraries/CoinbaseSmartWalletLib.sol:303-321,398`, but
those helpers have **zero call sites** — they are never invoked. Consequently a signature is validated against the raw
digest only, so a signature accepted by one atom wallet is accepted by any other atom wallet (or the same address on
another chain) that shares the signing key. Multiple atom wallets sharing one owner key is the expected case: one person
claiming several atoms with a single EOA or passkey.

**Code.**

```solidity
// AtomWallet.sol:341
function isValidSignature(bytes32 hash, bytes calldata signature) external view override returns (bytes4) {
    if (CoinbaseSmartWalletLib.isValidSignature(hash, signature)) {   // <-- raw hash, no replaySafeHash
        return ERC1271_MAGIC_VALUE;
    }
    return ERC1271_INVALID_SIGNATURE;
}
```

The NatSpec at `:333-334` states this is intentional ("Compatible with EIP-712 integrations … that pass the final
typed-data digest"). The 4337 path is unaffected: `_validateSignature` (`:498-499`) prefixes `userOpHash`, which the
EntryPoint already binds to `sender` + `chainId`.

**Proof of concept.**

1. Key `K` is a MultiOwnable owner on `AtomWallet_A` (atom A) and `AtomWallet_B` (atom B).
2. A dApp obtains an ERC-1271 signature from `K` over digest `H` intended for wallet A;
   `AtomWallet_A.isValidSignature(H, sig) == 0x1626ba7e`.
3. A relayer submits the identical `(H, sig)` to `AtomWallet_B.isValidSignature(H, sig)` → also `0x1626ba7e`,
   authorizing an action attributed to B. The same `(H, sig)` also validates on a second chain for an equal wallet
   address.

**Impact.** Bounded to integrations whose signed digest does not itself embed the exact validating account. Permit2 and
Seaport embed `owner`/`offerer` and are safe; generic message-signing, login/session, and some order-book flows keyed on
the ERC-1271 signer are exposed to cross-account action forgery. No direct theft of vault principal.

**Recommendation.** Wrap the digest in the already-present
`CoinbaseSmartWalletLib.replaySafeHash(hash, "AtomWallet", version)` before validation (restoring `verifyingContract` +
`chainId` binding), or publish a hard integration requirement that every ERC-1271 digest must bind this account address
and `chainId`.

**Resolution / Status.** Open — confirm whether the raw-digest design intends to accept the integrator-binding burden;
the robust fix already sits unused in the library. Net-new regression tests:
`test_isValidSignature_rejectsCrossWalletReplay`, `test_isValidSignature_bindsChainId` (no `AtomWallet` tests currently
exist).

### 5.2 TOB-02 · Medium · `claimRewards` pause across a full epoch permanently forfeits prior-epoch rewards

**Cluster F.** `src/protocol/emissions/TrustBonding.sol:383` and `:396`; NatSpec `:28-29`,
`src/interfaces/ITrustBonding.sol:270-274`. Checklist anchors: SOL-CR-2, SOL-AM-GA-1, SOL-Heuristics-16.

**Description.** `claimRewards` is `whenNotPaused` and can only ever claim `prevEpoch = currentEpoch() - 1`; by design
(NatSpec), rewards for epoch `n` are claimable **only** during epoch `n+1` and are otherwise forfeited. There is no
alternate claim path and no admin catch-up. If the contract is paused for the entire duration of an epoch (production
epoch ≈ 14 days), every user's rewards for the preceding epoch become permanently unclaimable — this is collateral to
any sustained good-faith emergency pause, not merely a malicious-pauser scenario. The pause asymmetry is safe for
**principal** (`withdraw` and `checkpoint` remain callable while paused, so funds are never trapped and accounting is
not stale), but not for reward claims.

**Code.**

```solidity
// TrustBonding.sol:383
function claimRewards(address recipient) external whenNotPaused nonReentrant {
    ...
    uint256 prevEpoch = currentEpochLocal - 1;              // :396 — only-ever-claimable epoch
    uint256 rawUserRewards = _userEligibleRewardsForEpoch(msg.sender, prevEpoch);
    ...
}
```

**Proof of concept.**

1. Epoch `n`: users A, B hold veTRUST; the epoch-end snapshot fixes eligibility.
2. Start of epoch `n+1`: `pause()` (incident response or malicious pauser).
3. Pause persists past `epochTimestampEnd(n+1)` (≥ one epoch).
4. Epoch `n+2`: `unpause()`. `claimRewards` now exposes only `prevEpoch = n+1`; epoch `n` is unreachable. A and B
   permanently lose epoch `n` rewards, which are then treated as "unclaimed" and bridged back / burned.

**Impact.** Irreversible loss of a full epoch's rewards for every eligible user whenever a pause spans a claim window.
Bounded to one epoch's emissions; no theft, no attacker profit.

**Recommendation.** Either make `claimRewards` callable while paused (it is `nonReentrant` and reads settled historical
state), or add a post-unpause grace window that re-opens any epoch whose claim window elapsed entirely under pause.

**Resolution / Status.** Open. Regression test:
`test_claimRewards_pausedAcrossEpochBoundary_forfeitsPreviousEpochRewards`.

### 5.3 TOB-03 · Minor · Global per-window claim cap can starve honest claimants at `signatureThreshold == 1`

**Cluster D.** `src/protocol/wallet/AtomWarden.sol:750-768`, `:118`. Anchors: SOL-AM-GA-1, SOL-AM-SybilAttack-1.

**Description.** The per-window claim cap is a single global counter (`claimsInWindow`), not per-claimant or per-signer.
At `signatureThreshold == 1`, a compromised signer can consume the entire window budget (`maxClaimsPerWindow`) against
attacker-controlled claimants, after which every legitimate `claimWithAuthorization` reverts
`AtomWarden_ClaimCapExceeded` for the rest of the window. The cap is consumed only after `_verifyQuorum` succeeds
(`:309`→`:311`), so invalid attempts never burn budget, and the other claim paths are unaffected. No fund loss.

**Proof of concept.** With `threshold == 1` and cap `C`, the compromised signer submits `C` valid claims (each a fresh
`claimant`/`nonce == 0`) in one window; `claimsInWindow` hits `C`; honest signed claims then revert until the window
rolls.

**Recommendation.** Add a per-claimant (or per-signer) sub-cap, or document the starvation as an accepted tradeoff and
require production `signatureThreshold ≥ 2`.

**Resolution / Status.** Open. Regression test: `test_claimCap_globalStarvationAtThresholdOne`.

### 5.4 TOB-04 · Minor · `MINTIME ≥ reward epoch length` is a deploy assumption unenforced on-chain

**Cluster F.** `src/protocol/emissions/TrustBonding.sol:202-235,137`; `src/external/curve/VotingEscrow.sol:110`;
`src/protocol/emissions/CoreEmissionsController.sol:61`. Anchors: SOL-Basics-Function-1, SOL-CR-7,
SOL-Basics-Initialization-1.

**Description.** The epoch-end snapshot's anti-sniping guarantee relies on `MINTIME ≥ EPOCH_LENGTH`, but `MINTIME` (from
TrustBonding's `_epochLength`, passed to `__VotingEscrow_init`) is only required to be `≥ 2*WEEK`, while the reward
epoch length is a separate immutable in `CoreEmissionsController` with no cross-check. If the deployer sets
`_epochLength` below the reward epoch length, a user can create a `MINTIME` lock just before an epoch boundary, be
counted at near-undecayed weight in the snapshot, then `withdraw` before the reward is claimable while remaining fully
eligible (eligibility reads the frozen snapshot). Boundary weight-sniping redistributes rewards; the per-epoch budget
cap still prevents over-emission.

**Recommendation.** Add an `initialize` guard tying `_epochLength` to the emissions-controller epoch length (`==` or
`≥`), or a deploy-time assertion documented as a hard invariant.

**Resolution / Status.** Open. Regression tests: `test_initialize_revertsWhenMinTimeBelowSecEpochLength`,
`testFuzz_snapshotSnipe_boundedByMintime`.

### 5.5 TOB-05 · Minor · MultiOwnable owner management accepts degenerate (zero) keys

**Cluster E.** `src/protocol/wallet/AtomWallet.sol:389-399` → `src/libraries/CoinbaseSmartWalletLib.sol:192-194`.
Anchors: SOL-Basics-Function-1, SOL-Heuristics-11.

**Description.** `addOwnerAddress` has no zero-address check and `addOwnerPublicKey` accepts `(0,0)`. A zero owner is
inert for validation (short-circuits in `SignatureCheckerLib` / off-curve for P-256) but consumes an owner index,
inflates `ownerCount`, and can desync off-chain indexers. `completeClaim` already guards `newOwner == 0` and `== warden`
(`:289-298`), so the signer-management surface has an inconsistent hygiene gap.

**Recommendation.** Reject `address(0)` / `(0,0)` in the add-owner functions, matching `completeClaim`.

**Resolution / Status.** Open. Regression test: `test_addOwnerAddress_zeroIsInertForValidation`.

### 5.6 TOB-06 · Minor · `feeRecipient` settable to the proxy / MultiVault silently strands affiliate fees

**Cluster G.** `src/periphery/FeeProxy.sol:181,250,755,550-554`. Anchors: SOL-Heuristics-9, SOL-Basics-Function-1.

**Description.** `registerAffiliate` / `updateFeeRecipient` reject only `address(0)`. Setting
`feeRecipient = address(feeProxy)` (or `= multiVault`) causes `_payAffiliate`'s `Address.sendValue` to land the
affiliate fee back in the proxy via its self-accepting `receive()`, with no ledger entry and no sweep — stranded
forever. Only the affiliate's own fees are lost (self-harm); native conservation is not violated (value is stranded, not
overpaid), but the call succeeds silently instead of reverting.

**Recommendation.** Reject `feeRecipient ∈ {address(this), address(multiVault)}` on register/update.

**Resolution / Status.** Open. Regression test: `test_updateFeeRecipient_revertsWhenRecipientIsProxyOrVault`.

### 5.7 TOB-07 · Minor · FeeProxy batch leg proportional-rounding-to-zero reverts the whole batch

**Cluster G.** `src/periphery/FeeProxy.sol:803`. Anchors: SOL-Basics-Math-5, SOL-AM-DOSA-4, SOL-Heuristics-10.

**Description.** For non-last legs, `piece = (assets[i] * totalForwarded) / totalGross`. With a large fixed fee (so
`totalForwarded < totalGross`) plus a tiny leg beside a large one, an early leg can floor to `0`; the forwarded `0` is
rejected by MultiVault's `_validatePayment` / min-deposit checks, reverting the entire batch. Self-DoS / UX for skewed
batches; not exploitable against third parties (the caller owns all legs); no fund loss.

**Recommendation.** Assign the rounding remainder to a non-zero leg, or validate each `piece > 0` with a clear error
before forwarding.

**Resolution / Status.** Open. Regression test: `testFuzz_depositBatchVia_smallLegRoundingRevertsWholeBatch`.

### 5.8 TOB-08 · Minor · `CoreEmissionsController` epoch length unvalidated; zero irreversibly bricks epoch math

**Cluster H.** `src/protocol/emissions/CoreEmissionsController.sol:61` (divisor at `:217,160,201`; no setter). Anchors:
SOL-Basics-Math-6, SOL-Basics-Function-1, SOL-Basics-Initialization-1.

**Description.** Four of five schedule params are validated at init, but `_EPOCH_LENGTH = emissionsLength` has no
zero-check. A zero value passes init (the `block.timestamp < _START_TIMESTAMP` guard masks the division early), then
once the schedule starts, `_calculateTotalEpochsToTimestamp` divides by zero → panic `0x12` across `_currentEpoch`,
`getEmissionsAtTimestamp`, and `getCurrentEpochEmissions`, propagating into `TrustBonding.currentEpoch()` and bricking
`claimRewards`, unclaimed accounting, and the reclaim/bridge paths. No setter → recovery requires a full upgrade. This
is a misconfiguration (trusted init param), capping severity at Minor, but the silent-at-init / brick-at-start /
irreversible profile warrants a guard.

**Recommendation.** Add an `emissionsLength != 0` validator alongside the existing four checks.

**Resolution / Status.** Open. Regression test: `test_init_revertsWhenEpochLengthZero`.

### 5.9 Informational

| ID     | Cluster | Location                                      | Note                                                                                                                                                                                                                                                                                                                                                    |
| ------ | ------- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| TOB-09 | E       | `AtomWallet.sol:252-274`                      | `transferOwnership` omits `completeClaim`'s `newOwner != warden` guard. A co-owner can set the primary owner to the warden, leaving `owner()` = warden while `isClaimed` stays true. Consistent with the equal-trust MultiOwnable model (a co-owner can already `execute`), so not privilege escalation — a latent guard asymmetry (SOL-Heuristics-16). |
| TOB-10 | E       | `AtomWallet.sol:341` (Solady ECDSA path)      | High-`s` malleability tolerated on the ERC-1271 path. Irrelevant to 4337 (nonce) and WebAuthn/P-256 (low-`s` enforced, `P256.sol:108`); matters only to integrators deduping on raw signature bytes, and only combined with TOB-01 (SOL-Signature-2).                                                                                                   |
| TOB-11 | H       | `SatelliteEmissionsController.sol:216-257`    | `bridgeUnclaimedEmissions` omits `nonReentrant` while sibling fund movers have it. Not exploitable — state write precedes both external calls (CEI) and `_reclaimedEmissions[epoch] > 0` blocks same-epoch re-entry. Add for consistency (SOL-AM-ReentrancyAttack-2, SOL-Heuristics-4).                                                                 |
| TOB-12 | G       | `FeeProxy.sol:550-554`                        | No admin rescue path for stranded native. `receive()` restricts inbound to `multiVault`/self, but combined with TOB-06 stranded value is unrecoverable. Consider a `DEFAULT_ADMIN_ROLE` sweep of `balance − Σ pendingRefund` (SOL-CR-3).                                                                                                                |
| TOB-13 | D       | `AtomWarden.sol:657-675,756-760`              | (a) `maxValidAfter == 0` NatSpec says `validAfter` must equal `block.timestamp`, but the code accepts any `validAfter ≤ block.timestamp` (no security impact). (b) Fixed-window limiter permits ≤ 2× `maxClaimsPerWindow` across a boundary (documented); size the cap accordingly (SOL-Heuristics-6, SOL-AM-MA-1).                                     |
| TOB-14 | H       | `CoreEmissionsController.sol:166-172,212-218` | `getCurrentEpoch()` returns 0 both before start and for the first epoch, so integrators cannot distinguish the two; no financial impact (claims gate on `currentEpoch ≥ 1`) (SOL-Heuristics-11).                                                                                                                                                        |
| TOB-15 | F       | `TrustBonding.sol:214,230,581`                | Current-epoch reward views snapshot a future `epochTimestampEnd(currentEpoch)` and in-progress utilization; view-only and forward-decayed (not inflated), never used by `claimRewards` (SOL-AM-ReentrancyAttack-1).                                                                                                                                     |

---

## 6. Properties checked — what held and how we tried to break it

Negatives are deliverables: for each load-bearing property the team relies on, this round recorded a refutation attempt.
A "PASS with no attempted refutation" was treated as incomplete.

### Cluster A — payable multicall + value accounting (§5.6, §5.1) — VERDICT: PASS

- **No `msg.value`-replay in `multicallPayable`.** Tried nested, revert-recovery, and re-entrant sequences to credit the
  same wei twice. Defended: `Σ values == msg.value` enforced up front (`MultiVault.sol:599`); `_inMulticall` transient
  guard rejects nested multicalls (`:514,579`); all six allowlisted legs are `nonReentrant`, so an external re-entry
  during a leg reverts on the active guard; `_virtualMsgValue`/`_inMulticall` are EIP-1153 transient, reset on the
  normal exit and rolled back on revert. No `try/catch` in the value path.
- **Canonical `multicall` cannot claim phantom value.** It forces `_virtualMsgValue = 0` (`:516`), so a payable leg
  composed inside sees `_effectiveMsgValue() == 0` and reverts through its own payment validation.
- **No leg strands or double-counts value.** Every value-bearing leg self-validates that its allocation equals what it
  consumes (`MultiVaultLib.sol:173,188,209,230,267,1315`); `Σ values == msg.value` ⇒ credited == received. The library
  never reads `msg.value` in logic (grep: comments only).

### Cluster B — `MultiVaultLib` storage-mirror integrity (§5.5) — VERDICT: PASS

- **Byte-exact mirror.** Reproduced `forge inspect src/protocol/MultiVault.sol:MultiVault storage-layout` and matched it
  slot-for-slot against `MultiVaultLib.Storage`: slots 0–37 (`totalTermsCreated`@0, `generalConfig`@1–8,
  `atomConfig`@9–10, `tripleConfig`@11–12, `walletConfig`@13–16, `vaultFees`@17–19, `bondingCurveConfig`@20–21, mappings
  22–33, `timelock`@34, `atomCreators`@35, `atomCreatedAt`@36, `lastSystemUtilizationEpoch`@37), `__gap`@38. The OZ
  upgradeable bases use ERC-7201 namespaced storage and occupy no sequential slots. Append-only tail; no
  reorder/retype/overlap; no leftover dynamic-fee tail slot (Cluster C absent). `reinitializer(2)` only sets `timelock`,
  grants `PAUSER_ROLE`, and seeds `lastSystemUtilizationEpoch` — no slot moved.

### Cluster C — `DynamicFeeFlatPriceCurve` — VERDICT: N/A (not present; not audited)

### Curve pricing (§5.4, §5.1, §5.2) — VERDICT: PASS

- **Flat-price par.** `LinearCurve` is pro-rata (`fullMulDiv`, rounding down both directions,
  `LinearCurve.sol:180-205`); round-trips lose at most fees; exit fees added to `totalAssets` without minting shares are
  a real redeemable redistribution (pricing is by the `A/S` ratio).
- **First-depositor / donation inflation blocked.** Ghost shares to `BURN_ADDRESS` =
  `0x000000000000000000000000000000000000dEaD`; internal `totalAssets` accounting (donations don't move it); zero-share
  deposits revert.
- **Conservation** on create/deposit/redeem traced by hand (native inflows split fully across
  protocol/atom-wallet/ghost/user backing; redeem `totalAssets` change = `+exitFee − rawAssetsBeforeFees`, no underflow
  since `rawAssetsBeforeFees ≤ totalAssets`); `atomDepositFraction/3` dust (≤ 2 wei) is a positive unattributed balance
  — accepted.

### Cluster D — AtomWarden quorum + per-window cap — VERDICT: PASS (Minor TOB-03; Info TOB-13)

- Quorum requires ≥ threshold distinct authorized signers (strict ascending recovered-address order + per-signer
  `hasRole`); no replay across atoms/chains/nonces/domain-version (EIP-712 struct + `chainId`/`verifyingContract`; nonce
  burned before the external call); no ERC-1271 signers in the quorum (EOA-only `ecrecover`); the per-window cap
  preserves the in-window count on retune and safely handles `cap == 0`. Refutations attempted and defeated as detailed
  in the working log.

### Cluster E — AtomWallet ERC-4337 / P-256 auth — VERDICT: FAIL (Medium TOB-01; Minor TOB-05; Info TOB-09/TOB-10)

- Only a current owner / EntryPoint+valid-owner-sig can execute; `_validateSignature` returns correct `0 == valid`
  semantics; malleable-`s`, `r=0`, wrong/empty index, `address(0)` owner, and malformed `SignatureWrapper` all rejected.
  `completeClaim` is `onlyAtomWarden`; pre-claim wallets validate nothing; factory deployment is deterministic (winning
  the deploy race grants nothing). The cluster fails only on TOB-01's ERC-1271 replay-binding gap. No
  `AtomWallet`/factory unit tests exist.

### Cluster F — TrustBonding emissions + pause — VERDICT: FAIL (Medium TOB-02; Minor TOB-04; Info TOB-15)

- Total claimed ≤ per-epoch budget (down-rounded eligibility, `≤ 1×` utilization ratio, hard `remainingBudget` clamp);
  rollover cannot double-claim or over-claim (per-epoch claimed flag, CEI, per-epoch `maxEmissions` ceiling); veTRUST
  balance respects decay. Pause asymmetry is principal-safe (`withdraw`/`checkpoint` open) but reward-unsafe (TOB-02).

### Cluster G — FeeProxy refund ledger + approval gating — VERDICT: PASS (Minor TOB-06/TOB-07; Info TOB-12)

- Native conservation (`fee + forwarded = grossAssets ≤ msg.value`, exact refund); refund ledger integrity
  (zero-before-send + `nonReentrant`, push-XOR-claimable, `msg.sender`-keyed, self-refund rejected); routing requires
  MultiVault approvals and binds `creator = msg.sender`; global/per-affiliate pause + atomic routed batch + validated
  fee caps.

### Cluster H — emissions controllers (Intuition side) — VERDICT: PASS (Minor TOB-08; Info TOB-11/TOB-14)

- Schedule arithmetic monotonic and non-overlapping; retention factor exact and non-increasing; role-gated mutators with
  immutable schedule params; satellite Intuition-side accounting bounded by the upstream per-epoch cap and the once-only
  `_reclaimedEmissions` guard; bridge refund bounded by the operator's own `msg.value`. The only division-by-zero is the
  unvalidated epoch length (TOB-08).

---

## 7. Appendix

### 7.1 Methodology

This is one independent round in a multi-round internal pseudo-audit run before the external audit. It re-derived from
the source and the round's invariants rather than seeding from any other round. The review was checklist-anchored (a
370-item Solodit-derived checklist spanning attack patterns, DeFi, tokens, signatures, external calls, low-level, and
centralization), whole-contract (every in-scope function, not the diff), and adversarial (each load-bearing property was
assigned a concrete break hypothesis before a PASS was accepted). Storage-layout integrity was verified with
`forge inspect` against the library's mirror struct. The two Medium findings were re-confirmed against source directly
rather than from intermediate notes. Foundry proof-of-concept construction was reserved for Major/Critical surfaces;
none were reached, so the Mediums are documented as fully specified attacker sequences with proposed regression tests.
Guard/refutation claims were reasoned to the defending `file:line`.

### 7.2 Existing test surface observed

A v1.1.0 security suite exists at `tests/unit/security/v1.1.0/` (including `MulticallPayableValueAccounting.t.sol`,
`TransientReentry.t.sol`, `StorageMirrorIntegrity.t.sol`, `FeeProxyConservation.t.sol`, `DepositRedeemExtraction.t.sol`,
`CrossCurveRedeemBound.t.sol`, `AtomWardenQuorumSoundness.t.sol`, `TrustBondingEpoch.t.sol`,
`EmissionBudgetConservation.t.sol`), plus storage-layout regression tests under `tests/unit/upgrades/v1.1.0/`. No
`AtomWallet` / `AtomWalletFactory` unit tests were found; the TOB-01/TOB-05/TOB-09 regression tests would be net-new
coverage.

### 7.3 Constraints and disclaimer

Local-only review; CI and `.github/**` untouched; the v1.0.2 baseline fork blocks were not moved. Addresses are
referenced by name and resolved from the deploy manifests; the only literal used is the ghost-share sink `BURN_ADDRESS`
= `0x000000000000000000000000000000000000dEaD`. Issues are described by mechanism only. **This document is a pre-audit
artifact — not a formal audit, certification, or guarantee of safety.** Findings remain internal until remediated and
are intended to feed the external audit.
