# Pseudo-Audit Round — Checklist-Driven (paste into a fresh chat)

> **Operator note (not part of the paste):** this drives the **local Trail-of-Bits-derived skill** at
> `.claude/skills/smart-contract-audit` (a 370-item, Solodit-anchored checklist). Round tag: **Checklist round**.
> Finding-ID prefix: **`CHK`**. It is one independent round of the v1.1.0 internal AI pseudo-audit. Copy everything
> below the line into the new session.

---

You are running one independent round of an internal, pre-external-audit **adversarial** security pass on the Intuition
`intuition-contracts-v2` public mirror, v1.1.0 core upgrade. Work from first principles. Produce a real report, not a
chat.

## 0. Read first, in this order — then stop and confirm scope before auditing

1. Read the master brief **in full**: `audits/handoffs/ai-pseudo-audit-handoff-v1.1.0.md`. It is the source of truth for
   the **mandate (§1)**, **out-of-scope list (§3)**, **per-agent protocol (§4)**, **invariants (§5)**, **attack
   clusters (§6)**, **curve framing (§7)**, **findings format (§8)**, **packaged-report house style (§8a)**, and
   **constraints (§10)**. Do not restate it; apply it.
2. **Independence guard — do NOT open any file under `audits/internal-audits/`.** Other rounds' findings live there;
   seeding yourself with them destroys the whole point of an independent round. You may open the reference PDFs in
   `audits/` (`Diligence-Audit-Report-1.pdf`, `Diligence-Audit-Report-2.pdf`, `CodeArena-audit-report-April-2026.pdf`)
   **only** to match the report layout for §8a.
3. Load the local skill and its checklist: `.claude/skills/smart-contract-audit/SKILL.md` and, per that skill's
   selection table, the relevant files under `.claude/skills/smart-contract-audit/references/` (start with
   `INDEX.md`, `attacker-s-mindset.md`, `basics.md`, `heuristics.md`, then load `defi.md`, `token.md`, `signature.md`,
   `low-level.md`, `external-call.md`, `centralization-risk.md`, `timelock.md` as the scope justifies).

## 1. Pin your own scope (do not trust paths from memory)

- Confirm you are on the PR #153 branch and record the commit **you actually review**:
  `git rev-parse HEAD` and `git rev-parse --abbrev-ref HEAD` (expected branch `feat/v1.1.0-core-upgrade`). Put that
  commit hash on every artifact you write.
- **The real source root is `src/`, not `contracts/core/src/`** — the master brief's §2 paths are the intended mirror
  layout, not this checkout. Map every in-scope contract to its real path, e.g. `src/protocol/MultiVault.sol`,
  `src/libraries/MultiVaultLib.sol`, `src/protocol/curves/`.
- **Scope reconciliation — verify presence at your commit before auditing a cluster.** At `b52557b` the fee-curve
  economy (**Cluster C**: `DynamicFeeFlatPriceCurve` + the standardized `IBaseCurve` quote/record fee hooks —
  `quoteDepositFee` / `recordDeposit` / `accFeePerShare`) **is not merged** — no `DynamicFeeFlatPriceCurve.sol` exists
  and `IBaseCurve` has no fee getters. Re-check with a symbol search
  (`grep -rl "quoteDepositFee\|recordDeposit\|accFeePerShare\|DynamicFeeFlatPriceCurve" src`). If still absent, mark
  Cluster C **"not present at this commit — not audited"** and audit everything else whole-contract. Do not hallucinate
  the curve. Clusters A, B, D, E, F, G, H are present.
- Honor §3 out-of-scope exactly (Trust Swap, bridge/MetaLayer transport leg, Base-chain components, parked rate-limiter,
  cross-curve counter-stake, migration mode, legacy `Trust`/`VotingEscrow`, trusted-admin centralization, held-out
  wallet delegation, mixed payable batching). Note the boundary if you touch them; do not file them.

## 2. Posture — override the skill's default "review this file" mode

Run the checklist skill, but under the master brief's **adversarial** mandate, not its stock advisory tone:

- Assume the in-scope set contains **at least one** fund-loss, mint/burn-imbalance, or trust-boundary bug (§1). Your job
  per property is a concrete exploit path **or** an evidenced refutation. **A `PASS` with no attempted refutation is a
  `FAIL`** (§4).
- This is **whole-contract**, not diff-only: audit every function of every in-scope contract, including the pre-existing
  functions the v1.1.0 changes sit beside.
- Anchor findings both to a checklist item id (`SOL-XX-YY-N`, never invented — the skill's guardrail) **and** to the
  master brief's invariant it breaks (§5.1–§5.6). Walk the loaded checklist files in order; do not silently skip items.
- For every **High/Critical** surface, attempt a Foundry PoC (or fully specify the attacker sequence) before accepting a
  PASS. Put PoCs under `tests/unit/security/v1.1.0/` extending the relevant `BaseTest`, with explicit revert selectors
  and before/after conservation assertions. Mutation-check any "this guard defends it" claim: the test must go red when
  the guard is removed.

## 3. Output — two files, our format, into `audits/internal-audits/`

Emit **both** deliverables the master brief requires, mapping the skill's native report onto them:

1. **Working found→fixed log** (master brief §8 format: summary table + per-finding blocks + negatives + cluster
   `VERDICT` lines) → write to **`audits/internal-audits/v1.1.0-checklist-round-findings-log.md`**.
2. **Packaged report** in the Diligence house style (§8a: cover/metadata with the reviewed commit hash, executive
   summary with severity counts, scope table + out-of-scope, Impact×Likelihood severity model using Critical/Major/
   Medium/Minor/Informational, findings highest-severity-first with Description/Code/PoC/Recommendation/Resolution, a
   "properties checked (negatives)" section, and an appendix with methodology + the pre-audit disclaimer) → write to
   **`audits/internal-audits/v1.1.0-checklist-round-report.md`**.

Do not overwrite the existing `v1.1.0-ai-pseudo-audit-*` or `v1.1.0-internal-audit-report.md` files — those are other
rounds.

## 4. Constraints (§10) — non-negotiable

- **Finding-ID prefix `CHK`** (e.g. `CHK-01`) so provenance survives triage. Map severities to the report labels:
  Critical→Critical, High→Major, Medium→Medium, Low→Minor, Informational→Informational.
- **Pre-audit artifact** — label it an internal AI pseudo-audit; it is not a formal audit, certification, or guarantee.
- **Mechanism-only, no attribution** in the shipped log/report: no model/vendor/person names, no internal ticket ids or
  call references. Describe the round neutrally as the **"checklist-driven (Solodit-anchored) round."** Full 40-hex
  `0x…` addresses in backticks where a literal is needed; resolve addresses from the deploy manifests by name; refer to
  the burn sink as `BURN_ADDRESS`.
- **Local only.** Never touch CI / `.github/**`. Do not move baseline fork blocks. Foundry `1.5.1`, Solidity `0.8.29`.

Close each cluster with `VERDICT: PASS` / `VERDICT: FAIL` and end the log with a headline severity count.
