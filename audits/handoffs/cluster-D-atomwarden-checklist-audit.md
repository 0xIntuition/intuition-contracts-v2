# Audit Report: AtomWarden (Cluster D — EIP-712 quorum + per-window claim cap)

**Date:** 2026-07-24
**Auditor:** Checklist-driven, Solodit-anchored review (Cyfrin/audit-checklist, 370 items / 13 categories)
**Method:** `smart-contract-audit` skill walk, run as **round-3 breadth backstop** for the v1.1.0 internal pre-audit (handoff `audits/handoffs/ai-pseudo-audit-handoff-v1.1.0.md`, cluster D).
**Target:** `src/protocol/wallet/AtomWarden.sol` (interface `src/interfaces/IAtomWarden.sol`)
**Toolchain confirmed:** Solidity `0.8.29`, `evm_version = "cancun"`, OpenZeppelin `5.4.0` (contracts + contracts-upgradeable), TransparentUpgradeableProxy.

> **Pre-audit artifact.** This is an internal, checklist-anchored review — **not** a formal audit, certification, or guarantee. It is directed breadth coverage that feeds the external audit. Every finding is anchored to a checklist item id so the reasoning is traceable to prior art; the checklist is a floor, not a ceiling.

---

## Scope

`AtomWarden` is the initial owner of every newly-created atom wallet and the contract that finalizes ownership claims. It exposes four claim paths — a permissionless self-claim for address atoms (`claimOwnershipOverAddressAtom`), an EIP-712 **multi-signer quorum** claim (`claimWithAuthorization`), a **creator-expiry fallback** (`claimAsCreatorAfterExpiry`), and operator grants (`grantAtomWalletOwnership` / `batchGrantAtomWalletOwnership`) — plus admin setters and a pause switch. It is `AccessControlUpgradeable` + `EIP712Upgradeable` + `PausableUpgradeable`, upgraded into v1.1.0 via `reinitializer(2)`.

The v1.1.0 delta under review: the EIP-712 quorum machinery (`CLAIM_AUTHORIZATION_TYPEHASH`, `signatureThreshold`, `signerCount` role-hook tracking, ascending-signer dedup), the new governable **per-window claim cap** (`maxClaimsPerWindow` / `claimCapWindow` / `currentClaimWindowId` / `claimsInWindow`), the `validAfter`/`validUntil` time-window caps, and the `reinitialize(2)` bootstrap. External systems touched: `MultiVault` / `MultiVaultCore` (atom + wallet resolution, creator/timestamp attribution, admin source) and `AtomWallet.completeClaim` — all first-party, protocol-deployed, deterministic addresses. No ERC20/4626, oracle, AMM, bridge messaging, merkle, or inline-assembly surface in this contract.

**Headline result:** no Critical or High issue was confirmed on this surface. The signature-quorum, nonce-replay, cross-chain domain-separation, and window-cap accounting are correctly implemented, and every High/Critical hypothesis in cluster D was refuted with a cited defense (see *Properties checked*). Findings are **2 Low + 5 Informational + 2 Open Questions**, plus one configuration risk worth a go-live decision.

## Checklist coverage

- **Categories walked (9):** Attacker's Mindset (25), Basics (135), Heuristics (17), Signature (5), Multi-chain/Cross-chain (13), External Call (14), Centralization Risk (7), Timelock (1), Low Level (5) — **222 items**.
- **Categories not loaded (4):** DeFi, Token, Integrations, Hash/Merkle — **not applicable** (no AMM/lending/oracle pricing; no custom ERC20/721/4626 handling; no Chainlink/Uniswap/LayerZero integration; no merkle proofs). This is a **partial walk by design** — the four skipped categories have no reachable surface in this contract.
- **Result:** 0 Critical, 0 High, 2 Low, 5 Informational, 2 Open Questions, 1 config-risk.

---

## Findings

### [Low] One-step `DEFAULT_ADMIN_ROLE` transfer (ref: SOL-CR-6, SOL-Basics-AC-4)

- **Location:** `AtomWarden.sol:23` (uses plain `AccessControlUpgradeable`, not `AccessControlDefaultAdminRules`), admin setters at `AtomWarden.sol:419-477`.
- **Impact:** Admin handoff is a single `grantRole(DEFAULT_ADMIN_ROLE, new)` + `revokeRole(old)`. A grant to a wrong/uncontrolled address, or a premature revoke, permanently strands admin control over every setter, the pause switch, and the quorum configuration. There is no accept-step to prove the new admin can transact.
- **Exploit path:** Not attacker-reachable — this is a privileged-operation footgun, not a permissionless exploit. Recorded per the checklist's two-step-transfer requirement.
- **Recommendation:** Adopt `AccessControlDefaultAdminRules` (two-step, time-delayed admin transfer) or drive all admin actions through the governance `TimelockController` (which the handoff §3 states is the case). If the timelock is the sole admin, note this as *mitigated at the governance layer* and close.
- **Status:** Open (likely Risk-accepted given the 4-of-8 Safe + TimelockController trust model in handoff §3).

### [Low] `initialize` is not access-gated — front-runnable on a *fresh* (non-upgrade) deployment (ref: SOL-Basics-Initialization-3, SOL-Basics-PU-5)

- **Location:** `AtomWarden.sol:158-193` (`initialize`, `initializer` modifier, no caller gate) vs. `AtomWarden.sol:214-250` (`reinitialize`, gated by `msg.sender == MultiVault admin`).
- **Impact:** On a brand-new proxy deployment (e.g. a fresh testnet instance), whoever calls `initialize` first sets `admin` and therefore owns `DEFAULT_ADMIN_ROLE`. If the proxy is deployed and initialized in **separate** transactions, an observer can front-run `initialize` and seize admin. **Not applicable to the live v1.1.0 upgrade path** — that proxy is already initialized (version 1), so `initialize` is spent and only the gated `reinitialize(2)` runs.
- **Exploit path (fresh deploy, non-atomic init):**
  1. Deployer deploys the TUP + implementation but does **not** initialize atomically.
  2. Attacker observes the un-initialized proxy in the mempool, calls `initialize(attacker, …)` with themselves as `admin`.
  3. Attacker holds `DEFAULT_ADMIN_ROLE` + `OPERATOR_ROLE`; can grant `SIGNER_ROLE`, set threshold, and claim/grant wallets at will.
- **Recommendation:** Confirm the deploy script performs **atomic** construction+initialization (`new TransparentUpgradeableProxy(impl, admin, abi.encodeWithSelector(AtomWarden.initialize.selector, …))`) — consistent with the project's own "prefer atomic initialization during proxy deployment" rule. This closes the window for every future fresh deployment. No source change required if the deploy script is already atomic; add a regression note either way.
- **Status:** Open — verify against `script/**` for AtomWarden deployment.

---

### Informational

| # | Location | Note (checklist ref) |
|---|---|---|
| I-1 | `AtomWarden.sol:257,287,333` | **Pause blocks all three user claim paths** (`whenNotPaused`). No funds are trapped: the atom wallet still exists, the operator override (`grantAtomWalletOwnership`, ungated on pause by design, line 371) can finalize during an incident, and users can claim after `unpause()`. Deliberate and documented at `AtomWarden.sol:463-468`. Acknowledged — satisfies **SOL-CR-2** (pause doesn't strand user positions). |
| I-2 | `AtomWarden.sol:444-461,704-708` | **Admin config footguns.** `setMaxValidUntil(0)` makes every signed claim instantly expired (a fine-grained kill-switch for the quorum path); a mass `SIGNER_ROLE` revoke can drop `signerCount` below `signatureThreshold` and strand the quorum (no auto-clamp, by design — `AtomWarden.sol:496-509`). Both are admin-only and documented; surfaced per **SOL-CR-7 / SOL-Basics-Function-5** so operators are aware the values are load-bearing. |
| I-3 | `AtomWarden.sol:239,536-543` | **Role accumulation across upgrade.** `reinitialize` → `_bootstrapAdmin(admin)` **adds** `DEFAULT_ADMIN_ROLE`/`OPERATOR_ROLE` to the MultiVault-config admin but never revokes a pre-existing holder. If the live v1 proxy already granted those roles to a different address, both retain them post-upgrade. Verify the intended post-upgrade role set matches deployment expectations (**SOL-CR-6**-adjacent). Given the live predecessor is the Ownable-based v1.0 (no `DEFAULT_ADMIN_ROLE` grants), this is likely a non-issue in practice — confirm. |
| I-4 | `AtomWarden.sol:657-675` vs `IAtomWarden.sol:126-128` | **NatSpec/behavior mismatch.** Docs say `maxValidAfter == 0` forces `validAfter` to equal the current timestamp, but the code only enforces `validAfter <= block.timestamp` (a past `validAfter` is accepted). Harmless — a past `validAfter` is already-active and still bounded by the `validUntil` checks — but the comment overstates the constraint (**SOL-Basics-Function-4**). |
| I-5 | `AtomWarden.sol:120-123`; layout below | **Storage-layout append — verified, keep pinned.** `forge inspect` confirms the v1.1.0 layout is self-consistent (see table); the `uint48` pack at slot 6 is correct and `__gap` sits at slot 11 sized `[50]`. Upgrade-safety is **verified by an existing fork regression test** (`tests/unit/upgrades/v1.1.0/AtomWardenUpgradeRegression.t.sol`) that `vm.load`-triangulates the appended cap slots (7–10) on the live proxy and asserts `multiVault` (slot 0) survives the implementation switch. Residual (not a defect): ensure that test stays in CI pinned to the actual upgrade fork block, and that `reinitializer(2)` is relied on to enforce the live proxy is pre-v2 (it reverts if `_initialized >= 2`). Satisfies **SOL-Basics-PU-9 / PU-10**. |

**Confirmed v1.1.0 storage layout (`forge inspect AtomWarden storage-layout`):**

| Slot | Var | Type |
|---|---|---|
| 0 | `multiVault` | address |
| 1 | `claimNonces` | mapping(address=>uint256) |
| 2 | `claimWindow` | uint256 |
| 3 | `minFeeThreshold` | uint256 |
| 4 | `signatureThreshold` | uint256 |
| 5 | `signerCount` | uint256 |
| 6 | `maxValidAfter` (off 0) + `maxValidUntil` (off 6) | uint48 + uint48 packed |
| 7 | `maxClaimsPerWindow` | uint256 |
| 8 | `claimCapWindow` | uint256 |
| 9 | `currentClaimWindowId` | uint256 |
| 10 | `claimsInWindow` | uint256 |
| 11 | `__gap` | uint256[50] (slots 11–60) |

---

### Configuration risk (go-live decision)

### [Low, config-contingent] `signatureThreshold == 1` **and** a disabled cap makes single-key compromise unbounded (ref: SOL-AM-RP-1, SOL-AM-SybilAttack-1, SOL-Signature-4)

- **Location:** `AtomWarden.sol:172,191,230,248` (threshold defaults to the reinit arg; NatSpec at lines 66-68 notes it "Defaults to 1 … until the admin raises it") + `AtomWarden.sol:750-768` (`_consumeClaimCapBudget` is a no-op when `maxClaimsPerWindow == 0`). The upgrade regression test itself flags that "production defaults **may ship with the cap disabled**" (`AtomWardenUpgradeRegression.t.sol:85-86`).
- **Impact:** The new per-window cap is the *stated* mitigation for a signer-key compromise (`AtomWarden.sol:93-98`). If the contract ships with `signatureThreshold == 1` **and** `maxClaimsPerWindow == 0`, that mitigation is **inert**: a single compromised `SIGNER_ROLE` key can produce a valid one-signature quorum and take over an **unbounded** number of atom wallets in a single window. This is a trusted-key scenario (not permissionless), so it is not a code defect — but it is the exact intersection of two defaults that removes the defense-in-depth the feature was built to provide.
- **Attacker sequence (given one leaked signer key, threshold 1, cap disabled):**
  1. For each target `atomId` whose wallet is unclaimed, the attacker (as any `claimant` they control) signs a `ClaimAuthorization` with the compromised key over the correct EIP-712 digest.
  2. Calls `claimWithAuthorization(auth, sig)` — passes `_verifyQuorum` (1 valid signer ≥ threshold 1), `_consumeClaimCapBudget` returns immediately (cap 0), `completeClaim` transfers ownership.
  3. Repeat with no per-window ceiling.
- **Recommendation:** Ship production with **either** `signatureThreshold >= 2` **or** the cap armed (`maxClaimsPerWindow > 0`, `claimCapWindow > 0`) — ideally both. Make this an explicit go-live checklist item and assert it in the deployment/verification script. No source change needed; this is a parameterization decision.
- **Status:** Open — parameterization gate for mainnet.

---

### Open questions for the developer

- **OQ-1 — Creator-expiry fallback can hand an address-atom wallet to a third party (ref: SOL-Heuristics-9, SOL-AM-RP-1).** `claimAsCreatorAfterExpiry` (`AtomWarden.sol:333-364`) lets the recorded **creator** of an atom seize its wallet once `claimWindow` elapses and accrued fees exceed `minFeeThreshold`. For an **address atom** (whose "rightful" owner is the address subject, who would use `claimOwnershipOverAddressAtom`), this means a creator who is *not* the address subject can gain control of that subject's atom wallet if the subject never claims in time. It is time-gated, creator-gated, disable-able (`claimWindow == 0`), and the subject can pre-empt by claiming — so it reads as an intended economic fallback. Confirm this is acceptable for address-subject atoms specifically, and that `minFeeThreshold`/`claimWindow` are tuned so it cannot be used to cheaply grief a slow-to-claim address owner.
- **OQ-2 — `MAX_BATCH_SIZE` (150) vs. a large signer set (ref: SOL-Basics-AL-9).** `_verifyQuorum` caps the bundle at 150 segments (`AtomWarden.sol:638`). If `signerCount` and `signatureThreshold` ever exceed 150, no valid bundle can satisfy `segments >= threshold` and the quorum path bricks. Unrealistic at expected signer counts, but confirm the operational ceiling on the signer set stays well under 150.

---

## Acknowledged non-issues (properties checked and cleared)

Each line is a High/Critical hypothesis from cluster D that was **attempted and refuted**, with the defending guard cited — the "we looked here and it held" evidence.

- **PASS — Cross-chain / cross-contract signature replay** (SOL-AM-ReplayAttack-2, SOL-Signature-1). Tried replaying a `ClaimAuthorization` signature on another chain/contract. Defended by EIP-712 domain separation: `_hashTypedDataV4` (`AtomWarden.sol:598`) binds `chainId` **and** `verifyingContract` via `EIP712Upgradeable`, with domain version `"2"` (`AtomWarden.sol:179,237`) distinct from any v1 deployment.
- **PASS — Same-authorization replay** (SOL-AM-ReplayAttack-1, SOL-Heuristics-12). Tried re-submitting a used authorization. Defended by per-claimant nonce: `authorization.nonce != claimNonces[claimant]` reverts (`AtomWarden.sol:303`) and `++claimNonces[claimant]` burns it **before** the external `completeClaim` (`AtomWarden.sol:316-320`, CEI). `_requireWalletUnclaimed` (`AtomWarden.sol:301`) is a second gate.
- **PASS — Cross-atom / cross-claimant replay** (SOL-Signature-3/4). Tried reusing signatures for a different `atomId`/`claimant`. Defended: both fields are in the signed struct (`AtomWarden.sol:643-655`), and `msg.sender == authorization.claimant` is enforced (`AtomWarden.sol:294`); the nonce is keyed to `claimant`.
- **PASS — Signature malleability** (SOL-Basics-VI-OVI-3, SOL-Signature-2). OZ `5.4.0` `ECDSA.tryRecover` (`AtomWarden.sol:603-604`) rejects high-`s`/EIP-2098 malleable forms, and replay protection is nonce-based (not signature-hash-based), so malleability is doubly irrelevant. The `<4.7.3` malleability CVE does not apply.
- **PASS — Quorum signer distinctness / duplicate-count** (SOL-Basics-AL-7). Tried counting one signer twice to fake a quorum. Defended by the strictly-ascending recovered-address rule: `recovered <= previous` reverts (`AtomWarden.sol:608`), giving O(1) dedup; every segment must independently hold `SIGNER_ROLE` at claim time (`AtomWarden.sol:611`).
- **PASS — Signer-set / threshold change between sign and execute** (SOL-Basics-AC-5). Both `signatureThreshold` and each signer's `SIGNER_ROLE` are evaluated at **claim** time (`AtomWarden.sol:593,611`); revoking a signer or raising the threshold after signing fails the claim (safe direction), and `signerCount` is maintained by the `_grantRole`/`_revokeRole` overrides so `setSignatureThreshold`'s `<= signerCount` bound (`AtomWarden.sol:435`) cannot be set above the real signer set.
- **PASS — Per-window cap bypass / fresh budget on retune** (SOL-Heuristics-17, SOL-Basics-Math-6). Tried draining more than `maxClaimsPerWindow` per window and re-tuning `claimCapWindow` to reset the counter. Defended: fixed-window accounting resets only on genuine rollover (`AtomWarden.sol:756-760`); `_setClaimCapWindow` re-anchors `currentClaimWindowId` but **preserves** `claimsInWindow` (`AtomWarden.sol:728-736`); enabling the cap requires a nonzero window (`AtomWarden.sol:714-717`), so no division by zero.
- **PASS — Reentrancy via `completeClaim`** (SOL-AM-Reentrancy-2, SOL-EC-13). Nonce burn and cap consumption precede the single external call (`AtomWarden.sol:311-320`); a malicious wallet re-entering hits the incremented nonce and `isClaimed()`. No `nonReentrant` needed given strict CEI (dependency: `AtomWallet.completeClaim` must set `isClaimed` atomically — cluster E).
- **PASS — Non-deployed / wrong call target** (SOL-EC-12, SOL-LL-3, SOL-EC-5). `_getAtomWallet` reverts on `code.length == 0` (`AtomWarden.sol:551-556`); the target is the deterministic `computeAtomWalletAddr(atomId)` (trusted protocol address), not user-supplied.
- **PASS — `tx.origin`, delegatecall, inline-assembly, unbounded loops** (SOL-Basics-AC-7, SOL-EC-3/10/11, SOL-LL-*, SOL-Basics-AL-9). None used. Batch paths are bounded by `MAX_BATCH_SIZE` (`AtomWarden.sol:389,638`); the quorum loop is bounded by the same. No raw `call`/`delegatecall`/assembly in this contract.
- **PASS — Admin cannot pull user funds** (SOL-CR-3, SOL-AM-RP-1). AtomWarden custodies no user funds — it only transfers atom-wallet *ownership*. No asset-withdrawal path for the admin.

---

## Appendix — methodology & provenance

- **Skill:** `smart-contract-audit` (project-local, `.claude/skills/smart-contract-audit`, pinned to upstream `farrellh1/smart-contract-auditor-skill@89906fd`; checklist adapted from `Cyfrin/audit-checklist`, MIT).
- **Round:** 3 (low-cost breadth backstop) for the v1.1.0 internal pre-audit. This checklist-driven pass is intentionally a *different* method from the hypothesis-driven frontier/cross-model rounds — its value is systematic category coverage, not novel exploit discovery.
- **Verification performed:** full source read of `AtomWarden.sol` + `IAtomWarden.sol`; `forge inspect` storage-layout (authoritative slot map above); cross-read of the existing suites `tests/unit/security/v1.1.0/AtomWardenQuorum*.t.sol` and `tests/unit/upgrades/v1.1.0/AtomWardenUpgradeRegression.t.sol`; OZ version, `evm_version`, and solc pinned versions confirmed.
- **Not performed (recommended next):** writing a PoC test per finding is unnecessary here (no Critical/High), but the config-risk go-live gate and OQ-1 warrant an explicit unit test asserting the intended production parameterization. A `forge inspect` byte-diff against the **exact** predecessor implementation (beyond the fork test's slot triangulation) would fully close I-5.
- **Merge note:** map these into the handoff's found→fixed log with ids `LC-D-01 … LC-D-09`; severities map to the Diligence house scale as Low→Minor, Informational→Informational.

**VERDICT: PASS** (cluster D — no High/Critical property failed; no unresolved Medium on a funds path). Residual items are Low/Informational plus one parameterization gate (`signatureThreshold`/cap defaults) that should be enforced before mainnet.
