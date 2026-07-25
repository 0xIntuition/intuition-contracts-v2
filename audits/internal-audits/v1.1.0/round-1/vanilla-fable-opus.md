# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 1

## Report 1 of 6 — Vanilla Frontier Reasoner (Opus 4.8 / Fable), no audit skill

> **How this report was produced:** a single frontier reasoning model (vanilla — no external audit skill or checklist),
> run as seven independent per-cluster reviewers (clusters A, B, D, E, F, G, H) over the whole in-scope set, each
> re-deriving from the pre-audit handoff brief and the source and scoring against the §5 invariants with PoC-backed
> refutation attempts. Provenance ID prefix: `CLD-`. This is one of six independent round reports; the consolidated,
> de-duplicated view is [`MASTER-consolidated-report.md`](MASTER-consolidated-report.md).

**Artifact type:** Internal AI pseudo-audit. This is a **pre-audit artifact — not a formal audit, certification,
warranty, or guarantee of safety.** It is an internal, multi-reviewer adversarial pass run before the external audit,
packaged in the house style of the existing professional reports for reviewer continuity. Findings are internal until
remediated, then handed to the external auditors alongside the found → fixed log.

|                     |                                                                                                                                                                                                   |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Reviewed commit** | `b52557bc5d1e87537e621fc13917240d40044c24`                                                                                                                                                        |
| **Branch**          | `feat/v1.1.0-core-upgrade`                                                                                                                                                                        |
| **Toolchain**       | Solidity `0.8.29`, Foundry, EVM `cancun` (EIP-1153)                                                                                                                                               |
| **Target networks** | Intuition Mainnet (chain id `1155`), Intuition Testnet (chain id `13579`) — Intuition-chain only                                                                                                  |
| **Method**          | One frontier round; 7 independent per-cluster reviewers (A, B, D, E, F, G, H), each re-deriving from the brief + source and scoring against the §5 invariants with PoC-backed refutation attempts |
| **Date**            | 2026-07-24                                                                                                                                                                                        |
| **Burn sink**       | `BURN_ADDRESS` = `0x000000000000000000000000000000000000dEaD` (`MultiVaultLib.sol:81`, re-exported `MultiVault.sol:66`)                                                                           |

---

## 1. Executive summary

The v1.1.0 core upgrade was reviewed whole-contract (not diff-scoped) across seven attack clusters spanning the
payable-multicall value accounting, the `MultiVaultLib` delegatecall storage mirror, the `AtomWarden` quorum + new
per-window claim cap, the `AtomWallet` ERC-4337/P-256 wallet, `TrustBonding` emissions and its extended pause gating,
the `FeeProxy` refund ledger, and the Intuition-side emissions controllers. Each reviewer operated under a standing
mandate to assume a fund-loss, mint/burn-imbalance, or trust-boundary bug exists and to produce either a concrete
exploit path or an evidenced refutation.

**Headline result: no Critical or Major issue was found.** One **Medium** and three **Minor** issues were confirmed,
alongside ten Informational observations. The six load-bearing invariants (value conservation, solvency, ledger-mirror
integrity, flat-price par, storage-layout upgrade-safety, and the `multicallPayable` no-replay property) were each
probed with a cited refutation attempt; the negatives are recorded in §6 as coverage evidence.

The single Medium (INT-01) is a cross-account signature-replay in the wallet's ERC-1271 path: the port drops the
upstream `replaySafeHash` wrapper and verifies the raw digest, so a signature validates on every AtomWallet that shares
the signer's key. It is exploitable under owner-unbound EIP-712 integrations (Permit2 `SignatureTransfer`), which the
wallet's own NatSpec advertises support for. It is the one item worth resolving — by fix or explicit risk-acceptance —
before the external audit.

### Findings by severity

| Severity      | Count | IDs                    |
| ------------- | ----- | ---------------------- |
| Critical      | 0     | —                      |
| Major         | 0     | —                      |
| Medium        | 1     | INT-01                 |
| Minor         | 3     | INT-02, INT-03, INT-04 |
| Informational | 10    | INT-05 … INT-14        |

### Scope caveat (material)

The handoff brief anticipated a fee-curve economy (a new `DynamicFeeFlatPriceCurve` plus a standardized `IBaseCurve`
quote/record fee-hook interface and MasterChef-style redistribution) as the central cluster C and the subject of the
brief's §7. **That surface does not exist at the reviewed commit** — there is no `DynamicFeeFlatPriceCurve.sol` anywhere
in `src/`, and `IBaseCurve` carries no fee-hook getters. Cluster C was therefore not audited (no code to attack) and
must be re-run once that surface is merged. All other clusters were reviewed in full.

---

## 2. Scope

### In scope (reviewed at `b52557b`)

| Contract                       | Path (`src/…`)                                                     | Cluster            |
| ------------------------------ | ------------------------------------------------------------------ | ------------------ |
| `MultiVault`                   | `protocol/MultiVault.sol`                                          | A                  |
| `MultiVaultCore`               | `protocol/MultiVaultCore.sol`                                      | B                  |
| `MultiVaultLib`                | `libraries/MultiVaultLib.sol`                                      | A, B               |
| `BondingCurveRegistry`         | `protocol/curves/BondingCurveRegistry.sol`                         | (C — hooks absent) |
| `BaseCurve` / `LinearCurve`    | `protocol/curves/BaseCurve.sol`, `protocol/curves/LinearCurve.sol` | (C — hooks absent) |
| `AtomWallet`                   | `protocol/wallet/AtomWallet.sol`                                   | E                  |
| `AtomWalletFactory`            | `protocol/wallet/AtomWalletFactory.sol`                            | E                  |
| `AtomWarden`                   | `protocol/wallet/AtomWarden.sol`                                   | D                  |
| `TrustBonding`                 | `protocol/emissions/TrustBonding.sol`                              | F                  |
| `CoreEmissionsController`      | `protocol/emissions/CoreEmissionsController.sol`                   | H                  |
| `SatelliteEmissionsController` | `protocol/emissions/SatelliteEmissionsController.sol`              | H                  |
| `FeeProxy`                     | `periphery/FeeProxy.sol`                                           | G                  |
| `CoinbaseSmartWalletLib`       | `libraries/CoinbaseSmartWalletLib.sol`                             | E                  |

**Not present at commit (not audited):** `DynamicFeeFlatPriceCurve`, `IDynamicFeeFlatPriceCurve`, and the `IBaseCurve`
fee-hook (`quoteDepositFee`/`quoteRedeemFee`/`recordDeposit`/`recordRedeem`/`accFeePerShare`) dispatch — the entire
cluster C / §7 fee economy.

### Out of scope (per handoff §3)

Trust Swap and swap periphery; the bridge router / MetaLayer cross-chain messaging (`MetaERC20Dispatcher` transport leg,
`IMetaLayer`); `BaseEmissionsController` and all Base-chain components; the TVL exit circuit-breaker / rate-limiter
(deliberately parked); unbounded cross-curve counter-stake aggregation (rejected on principle);
`MultiVaultMigrationMode` (migrator-gated one-shot); `ProgressiveCurve` / `OffsetProgressiveCurve` /
`ProgressiveCurveMathLib`; legacy `Trust` / `TrustToken` / `WrappedTrust` / `VotingEscrow` vendored code; trusted-admin
centralization (4-of-8 Safe through two `TimelockController`s, parameters 3-day / upgrades 7-day — an accepted trust
assumption); the `AtomWallet` delegation framework (`executeFromExecutor`, held out of merge); and whole-surface mixed
payable+non-payable multicall batching.

---

## 3. Severity classification

Severity is Impact × Likelihood under the intended deployment and trust model, using the labels of the existing external
reports (ConsenSys Diligence: Critical / Major / Medium / Minor, plus Informational). Permissionless exploitability is
separated from trusted-admin misuse (privileged setters gated by the 4-of-8 Safe + timelocks are an accepted trust
assumption, not a finding).

| Label             | Meaning                                                                                                                                                   |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Critical**      | Permissionless/realistic path to direct theft, permanent loss, insolvency, unrestricted mint/withdraw, or admin/upgrade capture.                          |
| **Major**         | A core invariant or authorization boundary breaks with severe (not total) impact, or an upgrade path corrupts critical state.                             |
| **Medium**        | Bounded loss, temporary stuck funds, realistic griefing/DoS of a funds path, admin footgun, or a spec regression that materially affects users/operators. |
| **Minor**         | Limited impact, weak validation blocked by another guard, or confusing behaviour.                                                                         |
| **Informational** | Docs, hygiene, NatSpec-vs-behaviour mismatch, or a missing non-critical test.                                                                             |

---

## 4. Findings

### INT-01 — ERC-1271 `isValidSignature` verifies the raw digest with no wallet binding · `Medium`

**Description.** `AtomWallet.isValidSignature` verifies the raw digest against the MultiOwnable registry with no
`address(this)` / chainId binding. Upstream Coinbase Smart Wallet wraps the input in `replaySafeHash(hash)` (an EIP-712
domain over chainId + `address(this)`) before verifying, precisely to stop same-owner cross-wallet replay. This port
drops the wrap and verifies the bare `hash`; acceptance depends only on `(ownerKey, hash)`, not on which wallet is
asked. A user's key/passkey routinely owns many AtomWallets (one EOA claims many atoms), so one signature over an
account-unbound digest is accepted by all of them. The wallet still ships `replaySafeHash`/`domainSeparator` but never
calls them.

**Code.**

- `src/protocol/wallet/AtomWallet.sol:341-346` — `isValidSignature` calls the library with the raw `hash`; NatSpec at
  `:333-334` claims "Compatible with EIP-712 integrations (Permit2, Seaport, etc.)".
- `src/libraries/CoinbaseSmartWalletLib.sol:146` — EOA path
  `SignatureCheckerLib.isValidSignatureNow(ownerAddr, hash, signatureData)` on the raw hash.
- `src/libraries/CoinbaseSmartWalletLib.sol:157` — passkey path `WebAuthn.verify({challenge: abi.encode(hash), …})` on
  the raw hash.
- `src/libraries/CoinbaseSmartWalletLib.sol:303,311` — `replaySafeHash` / `domainSeparator` implemented but unused by
  `isValidSignature`.

**Proof of concept.**

1. Alice's key owns `walletA` and `walletB`; both hold token T and approve Permit2.
2. Alice signs one Permit2 `SignatureTransfer` permit intending `walletA`; the signed digest `H` binds
   token/amount/spender/nonce/deadline + the Permit2 domain, but **not** the owner account.
3. `walletA.isValidSignature(H, sig) == 0x1626ba7e` — intended.
4. The same `sig` returns `0x1626ba7e` from `walletB.isValidSignature(H, sig)` — a wallet Alice never targeted, so the
   Permit2 transfer replays on `walletB`. (Confirmed by a two-wallet, one-signature PoC during review; independently
   confirmed by source inspection of the raw-digest path.)

The UserOp path is unaffected — `userOpHash` binds `sender` + chainId + nonce. Seaport binds the offerer and is
unaffected; Permit2 `SignatureTransfer` / AllowanceTransfer are not owner-bound and are the exploitable integration.

**Recommendation.** Verify against `CoinbaseSmartWalletLib.replaySafeHash(hash, name, version)` (already implemented in
the same library) rather than the raw `hash`, or otherwise mix `address(this)` + chainId into the challenge for all
three owner types (EOA, passkey, ERC-1271). If raw-digest verification must be kept for a specific integration, remove
the Permit2 compatibility claim from the NatSpec and document the cross-wallet replay assumption. Gate the fix with a
two-wallet/one-signature regression test that goes red if the wrap is removed.

**Resolution / Status.** Open. Recommend fix or explicit risk-acceptance before the external audit.

---

### INT-02 — Idle-window `setClaimCapWindow` retune over-throttles honest claimants · `Minor`

**Description.** The per-window claim cap keys on `block.timestamp / claimCapWindow`. When a full window elapses with no
claims (so no claim ran the rollover-reset), the stale spent count remains anchored to the expired window. An admin
`setClaimCapWindow` during that idle window re-anchors `currentClaimWindowId` but preserves `claimsInWindow`, binding
the expired count to the current window and rejecting otherwise-valid claims until the next rollover. The defect is
strictly in the safe direction (denial, not bypass) and self-heals; there is no fund loss and no fresh-budget mint
(verified in both retune directions).

**Code.** `src/protocol/wallet/AtomWarden.sol:728-736` (`_setClaimCapWindow`) vs `:750-768` (`_consumeClaimCapBudget`,
which resets on `windowId != currentClaimWindowId`).

**Proof of concept.** cap=2, window=1d; two claims in window W; warp `+WINDOW+1` (no claim, so state stays anchored to
W); admin `setClaimCapWindow(12h)`; the next honest `claimWithAuthorization` reverts `AtomWarden_ClaimCapExceeded`. A
control run without the retune succeeds.

**Recommendation.** Settle the pending rollover under the old divisor before re-anchoring — fold the
`windowId != currentClaimWindowId ⇒ claimsInWindow = 0` reset into `_setClaimCapWindow`.

**Resolution / Status.** Open.

---

### INT-03 — `transferOwnership` evicts the primary owner, bypassing the removal guard · `Minor`

**Description.** `removeOwnerAtIndex` refuses to remove the primary `owner()` (`AtomWallet_OwnerCannotBeRemoved`), but
`transferOwnership` calls `removeOwnerByAddress(oldOwner)` unconditionally, so any registered co-owner can evict the
primary and take the primary slot. In the flat MultiOwnable trust model a co-owner is already fully privileged, so this
is not a privilege escalation — but the advertised "primary owner cannot be removed" guarantee is not a real boundary,
which can mislead operators who add convenience co-signers.

**Code.** `src/protocol/wallet/AtomWallet.sol:252-274` (`transferOwnership`, `removeOwnerByAddress` at `:268`) vs the
guard at `:407-412`.

**Proof of concept.** Primary claims `walletA` (index 0) and adds `coSigner` (index 1). `coSigner` calls
`transferOwnership(coSigner)`; internally the primary is removed and `_claimant` becomes `coSigner`:
`owner() == coSigner`, `isOwnerAddress(primary) == false`.

**Recommendation.** Either make `transferOwnership` refuse to remove the current primary when `msg.sender != owner()`,
or drop the misleading `removeOwnerAtIndex` guard and document the flat trust model. Consistency matters more than the
specific choice.

**Resolution / Status.** Open.

---

### INT-04 — `emissionsLength` accepted without a non-zero validator → protocol-wide DoS on misconfig · `Minor`

**Description.** `CoreEmissionsController` validates `emissionsPerEpoch`, `startTimestamp`, `emissionsReductionCliff`,
and `emissionsReductionBasisPoints` at init, but assigns `_EPOCH_LENGTH = emissionsLength` with no validator. A zero
value makes `_calculateTotalEpochsToTimestamp` divide by zero, so every epoch query reverts; because `TrustBonding`
routes all epoch math through the satellite, the whole bonding/claim system is bricked with no recovery short of a proxy
upgrade (no post-deploy schedule setter). Trusted-admin-only (initializer, 4-of-8 Safe) — a footgun, not an attacker
path — but the blast radius and the absence of a cheap validator warrant a fix.

**Code.** `src/protocol/emissions/CoreEmissionsController.sol:46-64` (assignment at `:61`, sibling validators at
`:130,136,142,148`); consumed at `:217`.

**Recommendation.** Add `if (emissionsLength == 0) revert CoreEmissionsController_InvalidEmissionsLength();` (optionally
an upper bound) alongside the other validators.

**Resolution / Status.** Open.

---

### INT-05 … INT-14 — Informational

| ID     | Title                                                            | Location                                                  | Note                                                                                                    |
| ------ | ---------------------------------------------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| INT-05 | Single `deposit` leg skips `_validatePayment`                    | `MultiVaultLib.sol:235-252`                               | No divergence — whole-value semantics; `sum(values)==msg.value` enforced upstream. Optional comment.    |
| INT-06 | Canonical `multicall` doesn't re-zero `_virtualMsgValue` on exit | `MultiVault.sol:514-533`                                  | Provably 0 for the whole call; optional symmetry write at `:533`.                                       |
| INT-07 | NatSpec claims a storage-layout "diff gate" absent from CI       | `MultiVaultLib.sol:93`                                    | Add a `forge inspect … storage` golden-snapshot CI gate (same gap for the TrustBonding mirror).         |
| INT-08 | Fixed-window cap admits `2×cap` on a boundary straddle           | `AtomWarden.sol:750-768`                                  | Documented at `:743-746`; inherent to fixed windows — size the cap accordingly.                         |
| INT-09 | ERC-1271 ECDSA path accepts high-s (malleable) signatures        | `CoinbaseSmartWalletLib.sol:146`                          | Not an auth bypass; compounds INT-01 for byte-dedup integrators.                                        |
| INT-10 | UserOp validation uses a fixed `(0,0)` time window               | `AtomWallet.sol:500`                                      | Documented intentional; EntryPoint nonce prevents replay.                                               |
| INT-11 | Pause across an epoch boundary forfeits one epoch of rewards     | `TrustBonding.sol:383,396`                                | Tokens reclaimed/burned, not stolen; document the operational expectation or allow last-N-epoch claims. |
| INT-12 | `deposit_for` lets a third party force-extend a victim's lock    | `VotingEscrow.sol:367-389`                                | Inherited Curve semantics; cannot mint/double-claim rewards; mitigate with tight allowances.            |
| INT-13 | System vs personal utilization view-time asymmetry               | `TrustBonding.sol:660-661` vs `MultiVaultLib.sol:520-541` | Bounded to the 100% ceiling → funded `maxEmissions`; no solvency/conservation break.                    |
| INT-14 | Stray ETH in FeeProxy is locked, never stealable                 | `FeeProxy.sol:550-554`                                    | Can only under-pay, never over-pay; revisit if MultiVault later refunds callers.                        |

---

## 5. Cluster verdicts

| Cluster                                       | Verdict                        |
| --------------------------------------------- | ------------------------------ |
| A — payable multicall + value accounting      | PASS                           |
| B — MultiVaultLib storage mirror              | PASS                           |
| C — curve fee-hook + DynamicFeeFlatPriceCurve | N/A (feature absent at commit) |
| D — AtomWarden quorum + window cap            | PASS                           |
| E — AtomWallet 4337 / P-256                   | FAIL (INT-01 Medium)           |
| F — TrustBonding emissions + pause            | PASS                           |
| G — FeeProxy refund ledger + approval         | PASS                           |
| H — emissions controllers (Intuition side)    | PASS                           |

---

## 6. Properties checked (negatives — what held and how it was attacked)

Recorded as coverage evidence: each is a property a reviewer tried to break and could not, with the defending guard.

**Value conservation & the `multicallPayable` no-replay property (§5.1, §5.6).**

- `sum(values) == msg.value` enforced (`MultiVault.sol:594,599`); array-length mismatch (`:580`) and empty arrays
  rejected; every leg reads `_effectiveMsgValue()` — grep shows zero direct `msg.value` reads
  (`:650,666,681,699,715,732`).
- No re-entry credits the same wei twice: value legs make no call to attacker code (the only external call in the create
  path is the `computeAtomWalletAddr` view; native sinks `redeem`/`claim`/`sweep` are off the payable allowlist), all
  six legs are `nonReentrant`, and the `_inMulticall` guard blocks nested/re-entrant multicalls (`:514,579,585-592`).
- Caught-revert paths leak no transient value: reverts bubble via `assembly revert` and EIP-1153 writes roll back with
  the frame (covered by `MulticallPayableValueAccounting.t.sol` / `TransientReentry.t.sol`).
- Canonical `multicall` forces `_virtualMsgValue = 0` (`:516`); a composed `deposit` leg sees payment 0 and reverts.

**Storage-layout upgrade-safety & ledger-mirror integrity (§5.5).**

- `MultiVaultLib.Storage` is byte-exact with `forge inspect MultiVault storage` slots 0–37; shared aggregate types are
  imported from a single interface source, so divergent redeclaration is impossible; the only assembly is the
  `s.slot := 0` anchor (no raw `sstore`/`tstore` in 1,337 lines).
- v1.1.0 fields (creation attribution, rollover guard, timelock) are strictly appended over previously-unused zero slots
  (git baseline ended at slot 33); a fresh `__gap[47]` follows.
- Fork evidence confirms `reinitializer(2)` never executed on the live proxy
  `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e` (`timelock() == address(0)` pre-reinitialize, then a successful one-shot
  reinitialize), so the reshaped tail slots were never on-chain — the safest case. Runtime slot-mirror suite green
  (11/11).

**AtomWarden quorum + cap.**

- Distinctness enforced by strictly-ascending recovered-signer order (`AtomWarden.sol:608`, `<=` rejects duplicates);
  high-s malleability rejected by `ECDSA.tryRecover` (`:603-607`); cross-atom/nonce replay blocked by `atomId` in the
  typehash + per-claimant `claimNonces` with CEI increment; cross-chain/version replay blocked by the EIP-712 domain
  (`name`, `version="2"`, chainId, `verifyingContract`); threshold and signer set read live at execution (not
  snapshotted at sign time); ERC-1271 contract signers cannot participate (pure ECDSA recovery, no external call to
  re-enter); the cap cannot be bypassed by reentrancy or a failed claim (increment precedes the external call and rolls
  back on revert).

**TrustBonding emissions + pause.**

- `Σ claims ≤ per-epoch budget ≤ funded max` doubly enforced (natural pro-rata + the explicit `remainingBudget` cap and
  `alreadyClaimed >= epochBudget` revert at `TrustBonding.sol:421-432`); past-epoch utilization frozen (`_rollover`
  writes only the current epoch); veTRUST snapshots respect decay and are immutable in the past; the pause asymmetry is
  exactly as specified — seven lock-taking paths are `whenNotPaused`, while `withdraw` and `checkpoint` stay open as the
  escape hatch / accounting keep-alive; `userClaimedRewardsForEpoch` is write-once; checkpoint self-healing is decay
  bookkeeping only and cannot mint phantom emissions.

**FeeProxy conservation & approval gating.**

- `out == msg.value` exactly (`fee + (gross-fee) + (msg.value-gross)`); `fee < gross` and `msg.value >= gross` enforced;
  the pull-fallback ledger is keyed strictly on `msg.sender` with checks-effects ordering (zero-before-send), so no
  double-claim, claim-after-push, or cross-user drain; all four value-moving routes are `nonReentrant` +
  `whenNotPaused` + dual-approval-gated (the refund-push reentrancy leg, untested in the committed suite, was closed and
  holds); composition with MultiVault is atomic (no try/catch), so a leg revert rolls back the fee push and stats.

**Emissions controllers (Intuition side).**

- Schedule math never over-emits (per-epoch emission ≤ base, retention factor ≤ 1e18, non-increasing; exactly one cliff
  reduction per boundary; each timestamp in exactly one epoch); reclaim (`withdraw`/`bridge`) replay blocked by the
  `_reclaimedEmissions[epoch]` CEI guard; claim and reclaim windows are disjoint so an epoch cannot be double-spent;
  TRUST transfers are `nonReentrant` (or CEI + role-gated); every state-changing function is role-gated and
  `CONTROLLER`/`OPERATOR` roles are not granted at init; the schedule is immutable absent a timelocked upgrade.

---

## 7. Appendix — methodology, tooling, disclaimer

**Method.** One frontier round. The in-scope set was decomposed into the seven present clusters (A, B, D, E, F, G, H);
each was reviewed by an independent reviewer that re-derived from the brief and the source, restated the target
invariant + attacker capability, attempted a Foundry PoC or a fully-specified attacker sequence, and — for each property
it could not break — recorded the refutation attempt and the defending guard at `file:line`. Confirmed findings were
variant-swept across single / batch / on-behalf-of / preview / router / upgrade-initializer paths where applicable. The
one Medium was additionally confirmed by direct source inspection during triage.

**Tooling.** Foundry (`forge build`, `forge test`, `forge inspect … storage`), the committed adversarial PoC suites
under `tests/unit/security/v1.1.0/`, and the invariant / storage-layout / fork upgrade-regression suites. Reviewer PoCs
were run locally and removed; the working tree is unmodified by this review. The committed security and storage suites
are green at the reviewed commit.

**Provenance.** Finding ids carry the round prefix in the companion found → fixed log (`CLD-<cluster>-<n>`); this
packaged report renumbers them `INT-<n>` by severity for readability while the log preserves round/model provenance for
the merge.

**Disclaimer.** This is an internal pre-audit artifact produced to front-run and focus the external audit. It is **not**
a formal audit, certification, warranty, or guarantee of safety, and confers no assurance of correctness or fitness. A
clean cluster verdict means the reviewed properties held against the attempted refutations at this commit — not that the
code is free of defects. Cluster C (the fee-curve economy) was not reviewed because it is absent at this commit and must
be audited when merged.
