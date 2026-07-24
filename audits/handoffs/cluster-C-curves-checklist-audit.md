# Audit Report: Curves (Cluster C — BondingCurveRegistry + BaseCurve + LinearCurve)

**Date:** 2026-07-24
**Auditor:** Checklist-driven, Solodit-anchored review (Cyfrin/audit-checklist, 370 items / 13 categories)
**Method:** `smart-contract-audit` skill walk, run as **round-3 breadth backstop** for the v1.1.0 internal pre-audit (handoff `audits/handoffs/ai-pseudo-audit-handoff-v1.1.0.md`, cluster C).
**Target:** `src/protocol/curves/BondingCurveRegistry.sol`, `src/protocol/curves/BaseCurve.sol`, `src/protocol/curves/LinearCurve.sol` (interfaces `src/interfaces/IBaseCurve.sol`, `src/interfaces/IBondingCurveRegistry.sol`).
**Reviewed commit:** `b52557bc5d1e87537e621fc13917240d40044c24` (branch `feat/v1.1.0-core-upgrade`).
**Toolchain confirmed:** Solidity `0.8.29`, `evm_version = "cancun"`, OpenZeppelin `5.4.0` (contracts + contracts-upgradeable), Solady `FixedPointMathLib`, TransparentUpgradeableProxy.

> **Pre-audit artifact.** This is an internal, checklist-anchored review — **not** a formal audit, certification, or guarantee. It is directed breadth coverage that feeds the external audit. Every finding is anchored to a checklist item id so the reasoning is traceable to prior art; the checklist is a floor, not a ceiling. This round is **independent** of the frontier/cross-model rounds — the walk below was re-derived from source, then cross-checked against the frontier log only to mark duplicates (none overlap; cluster C was `N/A` in the frontier round because the fee-economy surface is absent — see Scope).

---

## Scope

The cluster-C curves are the pure-math pricing layer the `MultiVault` consults through a registry. **None of the three contracts custody funds or hold economic state** — they compute share/asset conversions from `(totalAssets, totalShares)` supplied by the caller (`MultiVaultLib`), which owns the real accounting.

- **`BaseCurve.sol`** — abstract base. Holds one storage var (`name`), the `__BaseCurve_init` name-setter, `virtual` declarations of the eight `IBaseCurve` math functions, and the internal domain/bound guards (`_checkWithdraw`, `_checkRedeem`, `_checkDepositBounds`, `_checkDepositOut`, `_checkMintBounds`, `_checkMintOut`, `_checkCurveDomains`).
- **`LinearCurve.sol`** — concrete flat/proportional curve. `MAX_SHARES = MAX_ASSETS = type(uint256).max`, `ONE_SHARE = 1e18`. Pricing is pro-rata (`shares = assets * totalShares / totalAssets`), i.e. ERC-4626-style share math with the standard safe rounding directions (deposit/redeem round **down**, mint/withdraw round **up**), executed via Solady `fullMulDiv` / `fullMulDivUp`.
- **`BondingCurveRegistry.sol`** — `Ownable2StepUpgradeable` registry. `addBondingCurve` (`onlyOwner`) assigns an incrementing id (starting at 1; id 0 reserved), enforces non-zero address / non-empty name / name-uniqueness, and stores forward+reverse lookups. Eight view dispatchers forward to the resolved curve behind an `onlyValidCurveId` gate.

**`DynamicFeeFlatPriceCurve.sol` is ABSENT at this commit.** The handoff §2/§6.C/§7 and the standardized `IBaseCurve` **fee-hook** surface (`quoteDepositFee` / `quoteRedeemFee` / `recordDeposit` / `recordRedeem` / `accFeePerShare`) describe a future/fuller v1.1.0. Confirmed by symbol search: no `DynamicFeeFlatPriceCurve` in `src/`, and `IBaseCurve` carries **no** quote/record hooks and **no** fee-hook getters (verified against `src/interfaces/IBaseCurve.sol` — only `name/maxShares/maxAssets/previewDeposit/previewRedeem/previewWithdraw/previewMint/convertToShares/convertToAssets/currentPrice`). The task's "confirm the fee-hook defaults are safe no-op" question is therefore **moot at this commit**: there is no hook surface to default, so "a curve without hooks is byte-identical to pre-upgrade" holds vacuously. This matches the frontier round's scope reconciliation (cluster C = `N/A`, "§7 is moot at this commit").

**Headline result:** no Critical, High, or Medium issue confirmed. The flat-price par invariant (§5.4), value-conservation (§5.1), argument-order integrity registry↔curve and `MultiVaultLib`↔registry, access control, and curve-injection resistance were each probed with a cited refutation (see *Properties checked*). Findings are **3 Low + 6 Informational + 1 configuration risk + 2 open questions**, all contingent on trust-model or deploy hygiene, none permissionlessly exploitable.

## Checklist coverage

- **Categories walked (6):** Attacker's Mindset (25), Heuristics (17), DeFi (63), External Call (14), Centralization Risk (7) — plus the relevant Basics items on initialization / storage-upgrade / access control / arithmetic reached during the walk. **~130 items materially applied.**
- **Categories not loaded (7):** Token, Integrations, Hash/Merkle, Signature, Multi-chain/Cross-chain, Low-Level, Timelock — **no reachable surface** in these three files (no custom ERC20/4626 transfer logic; no Chainlink/Uniswap/LayerZero; no merkle/signature/assembly/bridge). Partial walk **by design** for a stateless pure-math + registry cluster.
- **Result:** 0 Critical, 0 High, 0 Medium, 3 Low, 6 Informational, 1 config-risk, 2 open questions.

---

## Findings

### [Low, trust-assumption] `supply == 0` branch mints 1:1 while ignoring existing `totalAssets` — par (§5.4) rests on the vault's ghost-share seed (ref: SOL-Defi-General-4, SOL-AM-DA-1, SOL-Heuristics-11)

- **Location:** `LinearCurve.sol:180-191` (`_convertToShares`, `supply == 0 ? assets : …`), reachable via `previewDeposit` (`:66-80`) / `convertToShares` (`:132-146`); symmetric read in `_convertToAssets` (`:194-205`).
- **Impact:** In the degenerate state `(totalAssets > 0, totalShares == 0)`, `previewDeposit(assets, totalAssets, 0)` returns `assets` **1:1, ignoring the assets already in the pool**. A depositor of `d` into a `(A>0, 0)` pool receives `d` shares; the pool becomes `(A+d, d)` at price `(A+d)/d > 1`; an immediate `previewRedeem(d, d, A+d)` returns `A+d`, i.e. the pre-existing `A` is extractable as profit — a direct §5.4 par break **if the state is reachable**.
- **Exploit path / refutation:** Reachability requires the `MultiVault` to present `(totalAssets > 0, totalShares == 0)` to the curve. It does not: every vault is seeded with `minShare` ghost shares (`_minAssetsForCurve` via `previewMint(minShare, 0, 0)` = `minShare` assets, `MultiVaultLib.sol:1439`) that are burned to `BURN_ADDRESS` and never redeemed, so `totalShares >= minShare > 0` for the entire life of any live vault. The classic empty-vault / first-depositor inflation state is thus unreachable through the intended integration. Confirmed empirically (throwaway unit test): `previewDeposit(5e18, 100e18, 0) == 5e18` and `previewRedeem(5e18, 5e18, 105e18) == 105e18` both hold — the mechanism is real; only the *state* is gated off by the seed.
- **Why Low, not higher:** not permissionlessly reachable under the deployed `MultiVault`; it is a **curve↔caller trust assumption** that the caller never presents a zero-share / non-zero-asset pool. Filed because the curve does not defend the assumption itself and a *future* curve consumer (or a `MultiVault` change that drops the seed) would resurrect a fund-loss path.
- **Recommendation:** either document the invariant "callers MUST maintain `totalShares > 0` once `totalAssets > 0`" on `IBaseCurve`, or make `_convertToShares` revert (rather than silently mint 1:1) when `totalShares == 0 && totalAssets > 0`. No change needed if the ghost-share seed is treated as load-bearing and pinned by a regression test (see OQ-2).
- **Status:** Open (likely Risk-accepted — defended at the `MultiVault` integration layer).

### [Low, deploy-hygiene] `initialize` on the registry and the curve is not access-gated — front-runnable on a fresh, non-atomic deploy (ref: SOL-Basics-Initialization, SOL-CR-6)

- **Location:** `BondingCurveRegistry.sol:76-78` (`initialize(address _admin)`, `initializer`, no caller gate → `__Ownable_init(_admin)`); `LinearCurve.sol:47-49` (`initialize(string)`).
- **Impact:** If a proxy is deployed and initialized in **separate** transactions, an observer can front-run `initialize`. On the registry this seizes `DEFAULT` ownership → the attacker can `addBondingCurve` arbitrary curve addresses; on the curve it front-sets `name` (griefs the deployer's atomic init, which then reverts `InvalidInitialization`). **Not applicable to the live path** if deployment is atomic (`new TransparentUpgradeableProxy(impl, admin, abi.encodeWithSelector(initialize.selector, …))`), which is the repo's stated convention and how the existing `LinearCurve.t.sol` deploys it.
- **Exploit path:** (fresh, non-atomic deploy only) deployer deploys TUP without an init payload → attacker calls `initialize(attacker)` on the registry proxy → attacker owns curve registration.
- **Recommendation:** confirm the registry/curve deploy scripts construct+initialize atomically; assert ownership == the governance Timelock in the deploy verification. No source change if already atomic. Mirror of cluster D I-2.
- **Status:** Open — verify against `script/**` for registry/curve deployment (OQ-1).

### [Low, design] No curve deregistration / disable path — a mistakenly-added or later-buggy curve is permanent (ref: SOL-Heuristics-16, SOL-CR-2)

- **Location:** `BondingCurveRegistry.sol:86-119` (`addBondingCurve` only; no `removeBondingCurve` / pause / enabled-flag anywhere in the contract).
- **Impact:** Registration is monotonic and irreversible: once an id maps to a curve address, `onlyValidCurveId` will keep routing to it forever (`_isCurveIdValid` = `id > 0 && id <= count`, `:298-300`). If a curve is added by mistake, or is later found to mis-price / revert on a math hook, there is no in-contract way to retire it — remediation requires a proxy upgrade or `MultiVault`-side avoidance of the id. This is the deposit/redeem-adjacent asymmetry the heuristics call out (an `add` with no matching `remove`).
- **Why Low:** adds are `onlyOwner` and gated behind the handoff's verify-before-register policy; curves are view-only math holding no funds, so a bad curve degrades new vaults on that id rather than draining existing ones. Impact is bounded but the missing lever is worth an operator note.
- **Recommendation:** consider an `enabled` flag (owner-toggle) or an explicit `removeBondingCurve` that blocks new routing while leaving historical ids resolvable, or document that curve retirement is an upgrade-only operation.
- **Status:** Open (design decision — immutable registry entries).

---

## Informational

| # | Location | Note (checklist ref) |
|---|---|---|
| I-1 | `BondingCurveRegistry.sol:96` | **External call before state writes in `addBondingCurve`.** `IBaseCurve(bondingCurve).name()` is invoked (an external call into a not-yet-fully-trusted contract) **before** `count`/`curveAddresses`/`curveIds`/`registeredCurveNames` are written (`:109-116`) — a CEI deviation (**SOL-EC-13, SOL-AM-Reentrancy-2**). Non-exploitable: `addBondingCurve` is `onlyOwner`, a reentrant call from the curve carries `msg.sender == registry != owner` so it reverts, and the contract holds no funds. A hostile `name()` returning vast data (**SOL-EC-9**) only wastes the owner's own gas. Consider caching `name()` into a memory var (already done) and moving it after the duplicate-address check, or documenting the trust boundary. |
| I-2 | `IBondingCurveRegistry.sol:19` | **`BondingCurveAdded` indexes a `string`.** `event BondingCurveAdded(uint256 indexed, address indexed, string indexed curveName)` — an indexed dynamic type is stored as the `keccak256` topic, not the readable value, so off-chain indexers cannot recover the curve name from the log (they must call `getCurveName`). Cosmetic/monitoring only (**SOL-CR-5**, SOL-Heuristics-6). Consider un-indexing `curveName`. |
| I-3 | `LinearCurve.sol:128,165-173,194-205` | **Degenerate `(totalAssets == 0, totalShares > 0)` state:** `currentPrice`/`convertToAssets`/`previewRedeem` return `0` (below par); `previewWithdraw` (`:128`) and `previewDeposit` divide by `totalAssets` and **revert** (Solady `MulDivFailed`). All unreachable given the ghost-share seed keeps `totalAssets >= minShare` too; the revert direction is safe (DoS, not extraction). Recorded per **SOL-Defi-General-7 / SOL-AM-DOSA-5** (residual-dust / rounding-to-zero). Same root as the Low above (curve trusts caller-supplied totals). |
| I-4 | `BaseCurve.sol:24`; `BondingCurveRegistry.sol:41-50` | **No `__gap` in the upgradeable base/registry.** `forge inspect` confirms self-consistent layouts (curve `name` at slot 0; registry `count`/`curveAddresses`/`curveIds`/`registeredCurveNames` at slots 0-3). Append-only upgrades stay safe **because OZ 5.x `Initializable`/`Ownable(2Step)Upgradeable` use ERC-7201 namespaced storage** (they do not occupy sequential slots), so future vars append at the next free slot without collision. Absence of an explicit `__gap` is a hygiene note, not a defect (**SOL-Basics-PU**). |
| I-5 | `LinearCurve.sol:24-27`, `BaseCurve.sol:180-211` | **`MAX_ASSETS = MAX_SHARES = type(uint256).max`** makes `_checkCurveDomains` a no-op and the `_checkDeposit*/Mint*` bounds pure `a+b`-overflow guards for `LinearCurve`. Safe: Solady `fullMulDiv`/`fullMulDivUp` revert on true 512-bit overflow, and the subtraction-form bound checks (`assets > cap - total`) avoid the additive overflow. Acknowledged as intentional headroom, not a defect. |
| I-6 | `LinearCurve.sol:66-80` vs `:132-146`, `:83-96` vs `:148-162` | **`previewDeposit` == `convertToShares` and `previewRedeem` == `convertToAssets`** (duplicated bodies, **SOL-Heuristics-1**). Intentional for a fee-less proportional curve — the two coincide when there is no curve-level fee — and rounding directions are consistent. Non-issue; noted so the duplication is not mistaken for drift. |

---

## Configuration risk (go-live decision)

### [Low, config-contingent] Registry owner is a fully-trusted curve gatekeeper with no on-chain conformance check (ref: SOL-AM-RP-1, SOL-CR-7, SOL-EC-5)

- **Location:** `BondingCurveRegistry.sol:86-119` (`addBondingCurve`) — the only validation on a new curve is non-zero address, unused id, non-empty `name()`, and name uniqueness. There is **no** verification that the address actually implements `IBaseCurve` correctly, prices at par, or is non-malicious.
- **Impact:** A registered curve can return arbitrary values for every dispatched view (`previewDeposit`/`currentPrice`/…). A malicious or buggy curve would mis-price deposits/redeems for any vault created on its id, and a curve that **reverts** on a math hook would DoS those vaults. This is entirely gated behind `onlyOwner`, and per handoff §3 the owner is a 4-of-8 Safe acting through a `TimelockController` that verifies curves before registration — an **accepted trust assumption**, not an attacker path. Surfaced so the "verify curve safety before `addBondingCurve`" step is an explicit go-live checklist item rather than tribal knowledge.
- **Recommendation:** keep the verify-before-register policy as a documented gate; optionally probe conformance on registration (e.g. a `currentPrice(0,0) == 1e18` sanity call, or an `ERC165`/selector check) to catch fat-finger address mistakes. Ownership must be the governance Timelock on mainnet (confirm in the deploy verification).
- **Status:** Open — parameterization/operational gate (trusted-admin, not a code defect).

---

## Open questions for the developer

- **OQ-1 — Registry lifecycle: fresh deploy vs. upgrade.** `BondingCurveRegistry` exposes only `initialize` (version 1), not a `reinitializer(2)`, so it appears to be a fresh deploy rather than an in-place v1.1.0 upgrade of an existing proxy. Confirm (a) it is deployed+initialized **atomically** (closes the Low front-run item), and (b) post-deploy `owner()` is the governance Timelock/Safe, not an EOA.
- **OQ-2 — Ghost-share seed is load-bearing for par (§5.4).** The LinearCurve par guarantee depends on the `MultiVault` never presenting `(totalAssets > 0, totalShares == 0)` — i.e. the `minShare` ghost-share seed must be minted (and never fully redeemed) before any user deposit/redeem routes to the curve. Confirm this holds on **every** term-creation path (atom, triple, on-behalf-of, migration) and that a storage/invariant test pins it. This is a cluster-B integration dependency but it is the pillar under LC-C-01.

---

## Acknowledged non-issues (properties checked and cleared)

Each line is a High/Critical-shaped hypothesis for this cluster that was **attempted and refuted**, with the defending guard cited.

- **PASS — §5.4 flat-price par: deposit→redeem is never net-positive.** Tried to extract net value on a single round trip against a fixed pool `(A, S)`. Defended algebraically: `s_out = floor(d·S/A) ⇒ s_out·A ≤ d·S`, hence `a_out = floor(s_out·(A+d)/(S+s_out)) ≤ d` — out ≤ in with equality only when exact. Rounding is the ERC-4626-safe set (deposit shares **down** `LinearCurve.sol:190`, redeem assets **down** `:204`, mint assets **up** `:111`, withdraw shares **up** `:128`). Corroborated by the existing `tests/unit/security/v1.1.0/CrossCurveRedeemBound.t.sol` (large-magnitude, accumulation, two-user, triple round trips all assert `out ≤ in`) and `LinearCurve.t.sol` fuzz.
- **PASS — §5.4 price never below par.** Tried to drive `currentPrice` (`= totalAssets/totalShares`, `LinearCurve.sol:172`) under `1e18`. Given the ghost-share seed's `A == S` start and round-down deposit/redeem, the ratio is monotone non-decreasing; `currentPrice(0,0) == 1e18` and stays `≥ 1e18` for reachable states. Below-par only in the seed-excluded `(A=0, S>0)` degenerate state (I-3).
- **PASS — §5.1 conservation.** The curves are stateless pure math holding no funds; they cannot mint/burn shares or move value — every credit/debit is booked by `MultiVaultLib`. No `balanceOf`/`address.balance` reliance (**SOL-AM-DA-1, SOL-Defi-General-3**): all inputs are caller-supplied totals.
- **PASS — Argument-order integrity, registry→curve.** Checked all eight dispatchers: registry forwards `(assets,totalAssets,totalShares)` / `(shares,totalShares,totalAssets)` in the exact order the curve declares (`BondingCurveRegistry.sol:142,162,182,202,222,242,260` vs `LinearCurve` signatures). No transposition of the asset/share axis.
- **PASS — Argument-order integrity, `MultiVaultLib`→registry.** `_convertToShares` → `previewDeposit(assets, totalAssets, totalShares, curveId)` (`MultiVaultLib.sol:1489-1491`), `_convertToAssets` → `previewRedeem(shares, totalShares, totalAssets, curveId)` (`:1497-1499`), new-vault seed `previewDeposit(assetsAfterFees, minAssets, minShare, curveId)` (`:1034-1040`), `currentPrice(curveId, totalShares, totalAssets)` (`:547-548`) — all match the interface order. A swap here would have broken §5.4 directly; none found.
- **PASS — Access control on registration/dispatch.** `addBondingCurve` is `onlyOwner` (`:86`); ownership uses **two-step** `Ownable2StepUpgradeable` (**SOL-CR-6**); every dispatcher is gated by `onlyValidCurveId` (**SOL-CR-7**); `__Ownable_init(address(0))` reverts `OwnableInvalidOwner` (verified in OZ 5.4.0), so a zero admin cannot slip through.
- **PASS — Malicious / unregistered curve injection.** Tried routing to an unregistered or zero curve. Defended: `_isCurveIdValid` rejects `id == 0` (reserved) and `id > count` (`:298-300`); `curveIds[bondingCurve] != 0` blocks re-registering an existing address (`:92`); there is no self-registration — only the owner adds. An unknown id reverts `BondingCurveRegistry_InvalidCurveId`.
- **PASS — Reentrancy / read-only reentrancy on the hot path** (**SOL-AM-Reentrancy-1, SOL-EC-1**). Every registry dispatcher is `view` and every `LinearCurve` math function is `pure`; no state is mutated during pricing, so there is no stale-value read-only-reentrancy surface. The only external call in a state-changing function is `name()` in `addBondingCurve` (I-1), owner-gated and fund-free.
- **PASS — Overflow / divide-by-zero.** Solady `fullMulDiv`/`fullMulDivUp` use the 512-bit path and revert on real overflow (`LinearCurve.t.sol` exercises `type(uint128).max` ratios); the `supply == 0` ternaries guard the intended zero-supply case; residual div-by-zero exists only in the seed-excluded `(A=0, S>0)` state and reverts safely (I-3).
- **PASS — BaseCurve "no-op fee-hook default" question is vacuous at this commit.** `IBaseCurve` carries **no** quote/record hooks and **no** fee-hook getters, and `DynamicFeeFlatPriceCurve.sol` is absent — so a curve "without hooks" is byte-identical to pre-upgrade because the hook surface does not exist. Nothing to exploit; re-audit when cluster C lands.
- **PASS — Sandwich / slippage / oracle manipulation** (**SOL-AM-PMA-1/2, SOL-AM-SandwichAttack-1, SOL-Defi-Oracle-***). N/A: price is derived from caller-supplied internal totals (not a DEX spot/oracle or `balanceOf` ratio), and these are `view` previews — slippage/deadline enforcement lives in `MultiVault`, out of this cluster.

---

## Appendix — methodology & provenance

- **Skill:** `smart-contract-audit` (project-local, `.claude/skills/smart-contract-audit`; checklist adapted from `Cyfrin/audit-checklist`, MIT).
- **Round:** 3 (low-cost breadth backstop) for the v1.1.0 internal pre-audit — **independent** of the frontier/cross-model rounds by construction. Its value is systematic category coverage over the three present curve files, not novel exploit discovery.
- **Verification performed:** full source read of `BaseCurve.sol` + `LinearCurve.sol` + `BondingCurveRegistry.sol` and both interfaces; algebraic proof of the par bound; a throwaway Foundry unit test confirming the `(A>0, S=0)` 1:1-ignore-assets mechanism (then removed — no `src/`/suite changes committed); cross-read of `tests/unit/curves/LinearCurve.t.sol` and `tests/unit/security/v1.1.0/CrossCurveRedeemBound.t.sol`; `forge inspect … storage-layout` on the registry and curve (slot maps in I-4); `MultiVaultLib`↔registry call-site argument-order check (`MultiVaultLib.sol:547,1034,1439,1489,1497`); OZ `5.4.0`, solc `0.8.29`, `evm_version = cancun` confirmed from `foundry.toml` and the OZ package manifest.
- **Not performed (recommended next):** an explicit regression test pinning the ghost-share seed (`totalShares >= minShare` before any curve-routed deposit/redeem) to convert LC-C-01's refutation into a CI-guarded invariant; a deploy-script check asserting atomic init + Timelock ownership of the registry (LC-C-02 / OQ-1); a conformance probe on `addBondingCurve` (config-risk).
- **Merge note:** map these into the found→fixed log with ids `LC-C-01 … LC-C-09`; severities map to the Diligence house scale as Low→Minor, Informational→Informational. No content overlap with the frontier findings (cluster C was `N/A` there).

**VERDICT: PASS** (cluster C — no High/Critical property failed; no unresolved Medium on a funds path). The flat-price par (§5.4) and conservation (§5.1) invariants hold on the present curve surface; all residual items are Low/Informational and contingent on the `MultiVault` ghost-share seed, deploy-time atomic init, and the trusted curve-registration gate — none permissionlessly exploitable at commit `b52557b`.
