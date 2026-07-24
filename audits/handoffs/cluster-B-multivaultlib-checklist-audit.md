# Audit Report: MultiVaultLib (Cluster B — extracted delegatecall write-path library + storage mirror)

**Date:** 2026-07-24
**Auditor:** Checklist-driven, Solodit-anchored review (Cyfrin/audit-checklist, 370 items / 13 categories)
**Method:** `smart-contract-audit` skill walk, run as **round-3 breadth backstop** for the v1.1.0 internal pre-audit (handoff `audits/handoffs/ai-pseudo-audit-handoff-v1.1.0.md`, cluster B). Independent of the frontier round; duplicates are cross-marked.
**Target:** `src/libraries/MultiVaultLib.sol` (~1,080 nSLOC — the largest single unit). Consumers read: `src/protocol/MultiVault.sol`, `src/protocol/MultiVaultCore.sol`; struct sources `src/interfaces/IMultiVault.sol`, `src/interfaces/IMultiVaultCore.sol`.
**Reviewed commit:** `b52557b` (branch `feat/v1.1.0-core-upgrade`).
**Toolchain confirmed:** Solidity `0.8.29`, `evm_version = "cancun"`, `optimizer_runs = 10_000`, Foundry `1.5.1`, OpenZeppelin upgradeable `5.x` (ERC-7201 **namespaced** base storage — load-bearing, see §Findings), solady `FixedPointMathLib`, TransparentUpgradeableProxy.

> **Pre-audit artifact.** Internal, checklist-anchored review — **not** a formal audit, certification, or guarantee. Directed breadth coverage that feeds the external audit. Every finding is anchored to a checklist item id so the reasoning is traceable to prior art; the checklist is a floor, not a ceiling.

---

## Scope

`MultiVaultLib` is the stateless logic library that holds the migrated write-path bodies of `MultiVault` — `createAtoms`, `createTriples`, `createAtomsFor`, `createTriplesFor`, `deposit`, `depositBatch`, `redeem`, `redeemBatch` — plus the full transitive call graph (payment validation, fee accounting, min-share seeding, utilization tracking, vault mutation, event emission) and the view/preview helpers. It has **no state variables of its own**. Each call from `MultiVault` compiles to a single `DELEGATECALL`; the library executes in `MultiVault`'s storage context and reaches storage through one `Storage` struct anchored at slot 0 (`_s()` sets `s.slot := 0`) whose field order must mirror `MultiVault`'s declared layout **byte-exactly**. Errors/events stay declared on `MultiVault`/`MultiVaultCore`/`IMultiVault` and are re-thrown/emitted by the library, preserving selectors and emitter identity.

The load-bearing risk surface for cluster B (handoff §6.B, invariants §5.1/§5.3/§5.5): (1) **storage-mirror integrity** — a slot the library writes must be the slot the vault reads, including the newer fields (`timelock`, `atomCreators`, `atomCreatedAt`, `lastSystemUtilizationEpoch`); (2) **conservation** on create/deposit/redeem (every credit has a matching debit; min-share seed is funded from the user's own value; fees have a home); (3) **rounding direction** (fees in the protocol's favor); (4) the forwarded-`payment` design that keeps the library from ever reading raw `msg.value`. External systems touched are all first-party: `IBondingCurveRegistry` (price/preview/limits), `IAtomWalletFactory` (deterministic wallet addr), `ITrustBonding` (current epoch). No ERC20 transfer path (native TRUST via `Address.sendValue`), no oracle, no AMM, no bridge, no signatures, no merkle, and the only inline assembly is the one-line slot-0 resolver.

**Headline result:** **no Critical/High/Medium** confirmed on this surface. `forge inspect` proves the `MultiVaultLib.Storage` mirror is **byte-exact with `MultiVault`'s layout across slots 0–37** (append-only, `__gap[47]` at slot 38). All conservation, rounding, min-share/BURN-sink, and `_validatePayment`-per-leg hypotheses were attempted and refuted with cited defenses. Findings are **3 Informational** (one a confirmed duplicate of the frontier round) plus one config-risk note and two open questions.

## Checklist coverage

- **Categories walked (6):** Attacker's Mindset (25), Basics (135), Heuristics (17), Low Level (5), External Call (14) — plus targeted items from the others where a surface appeared. **~196 items** reviewed against the library.
- **Categories not loaded (7):** DeFi, Token, Integrations, Signature, Hash/Merkle, Multi-chain, Centralization/Timelock (as standalone) — **not applicable** to a stateless logic library (no custom ERC20/4626 handling reachable here, no oracle pricing owned here, no LayerZero/Uniswap integration, no signed messages, no merkle proofs, no cross-chain, and privileged setters live on `MultiVault`, reviewed in cluster A/D). This is a **partial walk by design** — the skipped categories have no reachable surface *inside the library*.
- **Result:** 0 Critical, 0 High, 0 Medium, 3 Informational, 1 config-risk, 2 open questions.

---

## Storage-layout slot map (headline deliverable)

`forge inspect src/protocol/MultiVault.sol:MultiVault storage-layout` (authoritative) vs. the `MultiVaultLib.Storage` struct (`MultiVaultLib.sol:96–146`). **Every slot matches — no reorder, no retype, no overlap.** The linchpin: the OZ upgradeable bases (`AccessControlUpgradeable`, `ReentrancyGuardUpgradeable`, `PausableUpgradeable`, `MulticallUpgradeable`, `Initializable`) use **ERC-7201 namespaced storage** in OZ v5, so they contribute **zero** sequential slots — the sequential layout is `MultiVaultCore`'s fields followed by `MultiVault`'s own, exactly as the library mirror assumes (`forge inspect` confirms slot 0 = `totalTermsCreated`, i.e. no base-contract slots precede it).

| Slot | `MultiVault` (forge inspect) | Bytes | `MultiVaultLib.Storage` field | Match |
|---|---|---|---|---|
| 0 | `totalTermsCreated` (uint256) | 32 | `totalTermsCreated` | ✅ |
| 1–8 | `generalConfig` (GeneralConfig) | 256 | `generalConfig` | ✅ |
| 9–10 | `atomConfig` (AtomConfig) | 64 | `atomConfig` | ✅ |
| 11–12 | `tripleConfig` (TripleConfig) | 64 | `tripleConfig` | ✅ |
| 13–16 | `walletConfig` (WalletConfig) | 128 | `walletConfig` | ✅ |
| 17–19 | `vaultFees` (VaultFees) | 96 | `vaultFees` | ✅ |
| 20–21 | `bondingCurveConfig` (BondingCurveConfig) | 64 | `bondingCurveConfig` | ✅ |
| 22 | `_atoms` mapping(bytes32=>bytes) | 32 | `atoms` | ✅ |
| 23 | `_triples` mapping(bytes32=>bytes32[3]) | 32 | `triples` | ✅ |
| 24 | `_isTriple` mapping(bytes32=>bool) | 32 | `isTriple` | ✅ |
| 25 | `_tripleIdFromCounterId` mapping(bytes32=>bytes32) | 32 | `tripleIdFromCounterId` | ✅ |
| 26 | `approvals` mapping(address=>mapping(address=>uint8)) | 32 | `approvals` | ✅ |
| 27 | `_vaults` mapping(bytes32=>mapping(uint256=>VaultState)) | 32 | `vaults` | ✅ |
| 28 | `accumulatedProtocolFees` mapping(uint256=>uint256) | 32 | `accumulatedProtocolFees` | ✅ |
| 29 | `accumulatedAtomWalletDepositFees` mapping(address=>uint256) | 32 | `accumulatedAtomWalletDepositFees` | ✅ |
| 30 | `totalUtilization` mapping(uint256=>int256) | 32 | `totalUtilization` | ✅ |
| 31 | `personalUtilization` mapping(address=>mapping(uint256=>int256)) | 32 | `personalUtilization` | ✅ |
| 32 | `userEpochHistory` mapping(address=>uint256[3]) | 32 | `userEpochHistory` | ✅ |
| 33 | `hasRolledOverSystemUtilization` mapping(uint256=>bool) | 32 | `hasRolledOverSystemUtilization` | ✅ |
| 34 | `timelock` (address) | 20 | `timelock` | ✅ |
| 35 | `atomCreators` mapping(bytes32=>address) | 32 | `atomCreators` | ✅ |
| 36 | `atomCreatedAt` mapping(bytes32=>uint48) | 32 | `atomCreatedAt` | ✅ |
| 37 | `lastSystemUtilizationEpoch` (uint256) | 32 | `lastSystemUtilizationEpoch` | ✅ |
| 38–84 | `__gap` (uint256[47]) | 1504 | (n/a — library appends nothing) | ✅ |

**Nested-struct offsets checked:** `VaultState` = `totalAssets`(+0), `totalShares`(+1), `balanceOf` mapping(+2) — both contract and library import the identical `VaultState`/config structs, so sub-field offsets are compiler-identical (confirmed at runtime by `MultiVaultStorageLayout.t.sol::test_storageLayout_mirror_vaults` for +0/+1, and by every write/getter agreeing on `balanceOf`). Every library **write** was enumerated (`atoms`/`atomCreators`/`atomCreatedAt`/`totalTermsCreated`/`triples`/`isTriple`/`tripleIdFromCounterId`/`accumulatedProtocolFees`/`accumulatedAtomWalletDepositFees`/`totalUtilization`/`personalUtilization`/`userEpochHistory`/`hasRolledOverSystemUtilization`/`lastSystemUtilizationEpoch`/`vaults.*`) and each lands in the mapped slot above. **Verdict: mirror integrity PASS** (§5.5 upheld). This independently re-confirms the frontier round's cluster-B PASS.

---

## Findings

### [Informational] NatSpec claims a "storage-layout diff gate" that does not exist in CI — Confirmed (dup Fable-B-01) (ref: SOL-Basics-Function-4, SOL-Basics-PU-9/PU-10)

- **Location:** `MultiVaultLib.sol:93–95` ("The field order and packing must match `forge inspect MultiVault storage-layout` exactly — **verified by the storage-layout diff gate**").
- **Independent verification:** `.github/workflows/test.yml` runs only `forge build`, `forge test -vvv`, `bun run fmt`/`fmt:check`, and a gas snapshot — **there is no `forge inspect … storage-layout` golden-snapshot step and no committed golden file** (searched `.github/`, repo tree; none found). Mirror integrity therefore rests entirely on **runtime** `vm.load` tests — `tests/unit/upgrades/v1.1.0/MultiVaultStorageLayout.t.sol` (pins slots 0,1,26,27,28,30,31,34,35,36,37 and the gap 38–84) and `tests/unit/security/v1.1.0/StorageMirrorIntegrity.t.sol` (slots 0,35,36,37). These are strong but **enumerative, not categorical**: they pin the load-bearing slots they probe, not *every* packed field, so a future retype/reorder of an *un-probed* field (e.g. a later PR packing two sub-32-byte fields into one slot) could ship green.
- **Impact:** Documentation overstates the guarantee. No exploit at this commit — the mirror **is** byte-exact (proven above). The risk is future drift passing CI. This matches the frontier round's `Fable-B-01`; independently reproduced here.
- **Recommendation:** Either (a) add a CI step that diffs `forge inspect src/protocol/MultiVault.sol:MultiVault storage-layout` against a committed golden snapshot (fail on any delta) — the same gap the frontier round flags for the TrustBonding mirror — or (b) soften the NatSpec to "verified by the runtime storage-layout regression suite (`MultiVaultStorageLayout.t.sol` / `StorageMirrorIntegrity.t.sol`)" so the comment matches reality.
- **Status:** Open — Confirmed (dup Fable-B-01).

### [Informational] Fee setters unbounded → two-ceiling `assets − fees` underflow can revert a 1-wei-asset redeem (ref: SOL-Basics-Math-5, SOL-Basics-Math-7, SOL-AM-DOSA-5, SOL-Basics-Function-5)

- **Location:** `MultiVaultLib.sol:1045–1055` (`_calculateRedeem`: `assetsAfterFees = assets − protocolFee − exitFee`, both fees `mulDivUp` → round up) and `:942–969`/`:993–1026` (deposit calcs: `− protocolFee − entryFee − atomWalletDepositFee`). Fee params are set by `MultiVault.setVaultFees` / `setAtomConfig` / `setTripleConfig` (`MultiVault.sol:846,823,829`) with **no upper-bound validation**.
- **Mechanism:** `_feeOnRaw` is `amount.mulDivUp(fee, feeDenominator)` — correct rounding *direction* (protocol's favor). But two independent ceilings can each round a tiny base up to 1 wei: for `rawAssetsBeforeFees == 1` with any non-zero `protocolFee` and `exitFee` (e.g. the test config's 1%/1%), `protocolFee = ceil(1·100/10000) = 1` and `exitFee = 1`, so `1 − 1 − 1` **underflows and reverts**. For `rawAssets ≥ 2` under 1% fees the sum is ≤ base, so no revert. The **deposit** side is shielded by the `minDeposit` floor (`_validateMinDeposit`, config default `1e17`), so realistic deposits never reach the underflow band; **redeem has no analogous floor** (only `shares > 0`, `remainingShares ≥ minShare`, `expectedAssets ≥ minAssets`).
- **Impact:** A redemption that would return exactly **1 wei of assets** while the exit fee is active reverts (`arithmetic underflow`). This is **dust-only**, in the **safe direction** (revert, never over-payment), and trivially worked around by redeeming ≥ a few more shares. Not a fund-loss and not attacker-profitable. Escalation to a broader redeem DoS requires an admin to set the summed fee bps near/over `feeDenominator` — a trusted-timelock misconfiguration, which the handoff §3 treats as an accepted trust assumption, not an attacker path.
- **Recommendation:** Optionally add an aggregate upper bound in the fee setters (`protocolFee + entryFee + atomWalletDepositFee < feeDenominator`, `protocolFee + exitFee < feeDenominator`) to make the config footgun unrepresentable; and/or a `remainingAssets`/dust guard on redeem. Low priority given the safe direction and the dust magnitude.
- **Status:** Open (dust edge; config-contingent for anything larger).

### [Informational] Triple `atomDepositFraction` split drops 0–2 wei of integer-division dust as unattributed native (ref: SOL-Basics-Math-4, SOL-Basics-AL-6, SOL-Heuristics-10)

- **Location:** `MultiVaultLib.sol:1061–1069` (`_increaseProRataVaultsAssets`: `amountPerTerm = amount / 3`, then three `_increaseProRataVaultAssets(...)` of `amountPerTerm`). Reached from `_createTriple` (`:708–712`) and triple `_processDeposit` (`:795–800`).
- **Mechanism:** `atomDepositFraction` is deducted in full from the user's `assetsAfterFees`, but only `3 · (amount/3)` is credited across the three underlying atom vaults. The remainder `amount % 3` (0, 1, or 2 wei) is neither credited to a vault nor to an accrual mapping — it remains as native TRUST held by `MultiVault` with no internal-accounting home.
- **Impact:** Per §5.1 the fee has no explicit "home" for that ≤2-wei residual, but the direction is **over-solvent** (`custody ≥ sum(redeemable)`), never a shortfall, and the amount is dust. `sweepAccumulatedProtocolFees` only sweeps the `accumulatedProtocolFees` mapping, so the residual is effectively unswept dust, not a loss to any user beyond ≤2 wei of their own deposit. No compounding into a solvency/conservation break was found. (Handoff §7's "accepted MasterChef dust" note is written for cluster C, which is absent at this commit; recorded here for the base triple split for completeness.)
- **Recommendation:** Optionally credit the `amount % 3` remainder to the last atom vault (or to `accumulatedProtocolFees`) so every wei has a home. Cosmetic.
- **Status:** Open (accepted dust).

---

## Informational table

| # | Location | Note (checklist ref) |
|---|---|---|
| I-1 | `MultiVaultLib.sol:249,585,670,291` etc. | **`int256(payment)` unchecked cast** in the utilization path. Harmless: native TRUST total supply on Intuition chain is far below `type(int256).max`, so `payment` can never wrap to negative. Recorded per **SOL-Basics-Type-1**; not exploitable. |
| I-2 | `MultiVaultLib.sol:610` | **`uint48(block.timestamp)` truncation** for `atomCreatedAt`. `uint48` overflows only ~year 8.9M; the runtime test asserts clean high bits. **SOL-Basics-Math-3/Type-1** — non-issue. |
| I-3 | `MultiVaultLib.sol:284–293` vs `:249–251` | **`depositBatch` adds utilization once (post-loop, for `_assetsSum`) while single `deposit` adds it pre-`_processDeposit`.** Order differs but no epoch boundary is crossed within a tx and `_processDeposit` never touches utilization, so the end state is identical. **SOL-Heuristics-1/13** — benign asymmetry. |
| I-4 | `MultiVaultLib.sol:235–252` | **Single `deposit` leg skips `_validatePayment`** (unlike create/`depositBatch`). No divergence: there is no `assets[]` to reconcile — `payment` *is* the whole deposit, and `multicallPayable` enforces `sum(values)==msg.value` upstream. Matches frontier **Fable-A-01** (cluster A). Optional: comment the deliberate asymmetry. |
| I-5 | `MultiVaultLib.sol:313,355` vs `:249,585` | **Utilization is asymmetric by fees:** deposit credits gross `payment`; redeem debits `rawAssetsBeforeFees` (backing net of skimmed deposit fees), so a deposit→full-redeem cycle leaves net-positive utilization equal to the fees paid. By design (fees represent "used" TRUST); no inflation of claimable beyond the funded budget. Adjacent to frontier **Fable-F-03**. |

---

## Configuration risk (go-live note)

### [Informational, config-contingent] Unbounded fee params can be driven to a redeem/deposit DoS (ref: SOL-CR-7, SOL-Basics-Function-1)

`setVaultFees`/`setAtomConfig`/`setTripleConfig` accept arbitrary bps with no `< feeDenominator` bound. At any realistic setting the fee math is correct and rounds in the protocol's favor; only a mis-set summed bps ≥ `feeDenominator` turns the Finding-LC-B-02 dust underflow into a broad redeem/deposit revert. Gated by the parameters `TimelockController` (handoff §3, 3-day delay) — an **accepted trust assumption**, surfaced so operators keep the invariant `protocolFee + max(entryFee+atomWalletDepositFee, exitFee) < feeDenominator` on their config checklist. No source change required if enforced operationally.

---

## Open questions for the developer

- **OQ-1 — CI golden-snapshot gate (LC-B-01).** Is the omission of a `forge inspect … storage-layout` CI diff intentional (relying on the runtime `vm.load` suite), or should the categorical gate be added before mainnet? The NatSpec at `MultiVaultLib.sol:93` currently asserts a gate that is not in `.github/workflows/test.yml`.
- **OQ-2 — Live-proxy tail-slot assumption (§5.5).** The handoff notes the previously never-released tail slots were reshaped **because `reinitializer(2)` had not executed on-chain**. That is an on-chain-state assumption I cannot verify locally (no fork RPC in this round). Confirm via the pinned upgrade-fork test that the live proxy is pre-`_initialized == 2` at the upgrade block, so slots 34–37 were genuinely virgin when appended.

---

## Acknowledged non-issues (properties checked and cleared)

Each line is a High/Critical hypothesis from cluster B/§5 that was **attempted and refuted**, with the defending guard cited.

- **PASS — Storage-mirror slot disagreement (silent corruption / mis-attribution)** (§5.5, SOL-Basics-PU-9/PU-10, SOL-LL-*). Tried to find a slot the library writes that the vault reads differently. Refuted: `forge inspect` byte-map (above) is identical to `MultiVaultLib.Storage` across slots 0–37; OZ v5 namespaced bases contribute no sequential slots (slot 0 = `totalTermsCreated` confirms this); every enumerated library write lands in the mapped slot; nested `VaultState`/config offsets are compiler-identical (shared struct imports) and runtime-pinned by `MultiVaultStorageLayout.t.sol`.
- **PASS — Create conservation** (§5.1). Tried to mint shares without matching backing. Refuted: `assets = atomCost + assetsAfterFixedFees`; `atomCreationProtocolFee` → `accumulatedProtocolFees` (`:582–583`), `minShare` funds the seed (`_minAssetsForCurve(defaultCurve,minShare)==minShare` on the linear default curve, added to `totalAssets` + minted to `BURN_ADDRESS`, `:1174–1184`), `protocolFee`/`atomWalletDepositFee` accrued (`:616–617`), `assetsAfterFees` → vault backing. Sum = `assets`. Triple path symmetric (2× seed from `tripleCost`, `:1594–1596`).
- **PASS — Deposit conservation incl. new-vault min-share carve-out** (§5.1, §5.3). Refuted: for a first non-default-curve deposit, the carved `minShareCost` (`:954–956,1009–1011`) is re-added as the seed in `_updateVaultOnCreation` (`:1177`), and `protocolFee+entryFee+atomWalletDepositFee+assetsAfterFees == assetsAfterMinSharesCost`; total accounted = full `assets`.
- **PASS — Redeem conservation & solvency** (§5.1, §5.2). Refuted: vault releases `rawAssetsBeforeFees` of backing; user receives `assetsAfterFees`, `protocolFee` accrued, `exitFee` redistributed back into the vault (`:843–848`), state updated **before** `Address.sendValue` (CEI). Released backing = `assetsAfterFees + protocolFee`; conserved.
- **PASS — Rounding direction in the protocol's favor** (§5.4, SOL-Basics-Math-5). Refuted: all fees via `mulDivUp` (round up); `assetsAfterFees` is a subtraction of rounded-up fees → user gets ≤ fair, protocol keeps the rounding. No path prices below par on the linear default curve.
- **PASS — Ghost/min-share seed & `BURN_ADDRESS` sink** (§5.1, SOL-AM-DA-1). Refuted: `minShare` is always minted to `0x…dEaD` with matching `_minAssetsForCurve` backing on both the primary and opposite-triple vault (`:1184,1251`); `_validateRedeem` forbids draining `totalShares` below `minShare` (`:1388–1391`), so the seed can never be redeemed out. No `balanceOf`/`balance` donation dependence (internal accounting only).
- **PASS — `_validatePayment` per-leg coverage & value forwarding** (§5.6, SOL-Basics-Payment-2, SOL-AM-FrA-*). Refuted: create/`depositBatch` legs each call `_validatePayment(assets, payment)` (sum==payment, bounded ≤ `MAX_BATCH_SIZE`); single `deposit` correctly omits it (no `assets[]`); the library **never reads raw `msg.value`** (grep-confirmed — every payable body takes an explicit `payment` arg threaded from `MultiVault._effectiveMsgValue()`), so multicall value-virtualization cannot be bypassed from inside the library.
- **PASS — Reentrancy on the native payout leg** (SOL-AM-ReentrancyAttack-2, SOL-EC-13). Refuted: `redeem`/`redeemBatch` are `nonReentrant` on `MultiVault`; the shared OZ guard blocks re-entry into every write path during `Address.sendValue`; state (shares burned, totals reduced) is committed before the send (CEI). `sweepAccumulatedProtocolFees` is un-guarded but only routes accrued fees to the trusted multisig — no attacker redirection.
- **PASS — delegatecall / low-level / assembly hazards** (SOL-EC-3/10/11, SOL-LL-1/2/3, SOL-Basics-PU-6). Refuted: the library issues **no** `call`/`delegatecall`/`selfdestruct`; the only assembly is the constant `s.slot := 0` resolver; it is itself the trusted, linker-resolved delegatecall *target* of `MultiVault` (address fixed at link time, not user-supplied).
- **PASS — `unchecked` blocks** (SOL-Basics-Math-9). Refuted: every `unchecked{}` is a loop `++i` (bounded by `MAX_BATCH_SIZE`) or the `_burn` `fromBalance - amount` after an explicit `fromBalance < amount` revert (`:1292–1300`) — no wrap reachable.
- **PASS — `mulDiv`/precision & division-by-zero** (SOL-Basics-Math-4/6, SOL-LL-5). Refuted: `_feeOnRaw` divides by `generalConfig.feeDenominator` (admin-set non-zero; a zero denominator reverts via solady, not silent). Multiply-before-divide preserved by `mulDivUp`. The only floor-division dust (`amount/3`) is Finding-LC-B-03 (≤2 wei, over-solvent).
- **PASS — `src==dst` / self-approval edges** (SOL-Heuristics-3). Refuted: `_isApprovedTo{Deposit,Redeem,Create}` short-circuit `sender==receiver`; depositing to `BURN_ADDRESS` only donates the caller's own shares (no corruption); `approve` self-set is blocked on `MultiVault`.
- **PASS — Array/loop bounds & length reconciliation** (SOL-Basics-AL-9, SOL-Basics-Function-1). Refuted: every batch entrypoint bounds length to `[1, MAX_BATCH_SIZE]` and reverts on mismatched companion arrays before iterating; `data.length` is forced `== assets.length` in `_createAtoms`, itself ≤150 via `_validatePayment`.

---

## Appendix — methodology & provenance

- **Skill:** `smart-contract-audit` (project-local, `.claude/skills/smart-contract-audit`; checklist adapted from `Cyfrin/audit-checklist`, MIT).
- **Round:** 3 (low-cost breadth backstop), **independent** of the frontier round — own checklist walk; the frontier cluster-B result (`v1.1.0-ai-pseudo-audit-findings-log.md`) was consulted only to cross-mark the one duplicate (`LC-B-01` = `Fable-B-01`) after independent verification.
- **Verification performed:** full source read of `MultiVaultLib.sol` + consumers `MultiVault.sol`/`MultiVaultCore.sol` + struct sources; **`forge inspect MultiVault storage-layout`** (authoritative slot map above); enumeration of every library storage write vs. the map; `forge build` clean (one benign `unsafe-typecast` lint on the `uint48` cast); read of the runtime mirror suites (`MultiVaultStorageLayout.t.sol`, `StorageMirrorIntegrity.t.sol`) and CI (`.github/workflows/test.yml`) to confirm the LC-B-01 gate gap; grep-confirmed the library issues no `msg.value`/`call`/`delegatecall`/`selfdestruct`; default fee config (`FEE_DENOMINATOR=10_000`, 1% fees, `MIN_DEPOSIT=1e17`, `MIN_SHARES=1e6`) read to bound the LC-B-02 dust edge.
- **Not performed (recommended next):** an on-chain fork read to close OQ-2 (live proxy `_initialized` state at the upgrade block) — no fork RPC used in this local round; a mutation-check writing a deliberately-desynced mirror field to confirm the runtime suite goes red on that specific field (the suite pins load-bearing slots but not every packed field — that is precisely LC-B-01).
- **Merge note:** map into the found→fixed log with ids `LC-B-01 … LC-B-03`; severities map to the Diligence house scale as Informational→Informational. `LC-B-01` de-dupes against `Fable-B-01`.

**VERDICT: PASS** (cluster B — no High/Critical/Medium property failed; the `MultiVaultLib` storage mirror is byte-exact with `MultiVault` across slots 0–37, conservation/rounding/min-share/BURN-sink all upheld). Residual items are 3 Informational (one a confirmed frontier duplicate) plus a fee-config bound worth adding operationally.
