# Pseudo-Audit Round — Parallel Specialist Agents (paste into a fresh chat)

> **Operator note (not part of the paste):** this drives the **Pashov `solidity-auditor` skill**
> (`github.com/pashov/skills`, `solidity-auditor/`) — 12 parallel specialist agents, dedup + judging gates. Round tag:
> **Parallel-agent round**. Finding-ID prefix: **`PAR`**. Independent round of the v1.1.0 internal AI pseudo-audit.
>
> **Safety (verified before use):** the only network egress is **read-only GET**s to the skill's own public repo — an
> unconditional version check `curl -sf https://raw.githubusercontent.com/pashov/skills/main/solidity-auditor/VERSION`
> plus fetches of its own guideline/reference docs. **No source code is uploaded off-machine;** the 12 agents are local
> Claude Code Agent-tool subagents (same Anthropic infra as your session, not a third-party audit backend). It works in
> a self-made temp dir (`mktemp -d ./.audit-XXXXXX`) and cleans it up (it only `rm`s its own bundle). **Residual risk:**
> it loads instruction/reference text from GitHub at runtime — a supply-chain / prompt-injection surface if that repo
> were tampered with. **Mitigation: vendor a reviewed copy and pin the commit (below).** The v1.1.0 mirror is a public
> repo, so source confidentiality is largely moot regardless. Copy everything below the line into the new session.

---

You are running one independent round of an internal, pre-external-audit **adversarial** security pass on the Intuition
`intuition-contracts-v2` public mirror, v1.1.0 core upgrade. Work from first principles. Produce a real report, not a
chat.

## 0. Read first, in this order — then stop and confirm scope before auditing

1. Read the master brief **in full**: `audits/handoffs/ai-pseudo-audit-handoff-v1.1.0.md` — source of truth for the
   **mandate (§1)**, **out-of-scope (§3)**, **protocol (§4)**, **invariants (§5)**, **clusters (§6)**, **curve framing
   (§7)**, **findings format (§8)**, **house style (§8a)**, and **constraints (§10)**. Apply it; don't restate it.
2. **Independence guard — do NOT open any file under `audits/internal-audits/`.** Those are other rounds' findings;
   reading them defeats the independence this round exists to provide. The PDFs in `audits/` may be opened **only** to
   match the §8a layout.

## 1. Make the skill available (review + pin before you run it)

The `solidity-auditor` skill is **not** installed here. Vendor it deliberately:

- Clone `https://github.com/pashov/skills` **at a pinned commit** (not `HEAD`), and copy `solidity-auditor/` into
  `.claude/skills/`. **Read `solidity-auditor/SKILL.md` and its reference/guideline files (agent prompts, `judging.md`,
  `report-formatting.md`) end-to-end first** — you are the review gate; it fetches instruction text from the network, so
  confirm what you're about to execute.
- Be aware it will `curl` the repo's `VERSION` file and may warn if you're not on latest — that is expected and benign;
  ignore the upgrade nag and keep your pinned copy for reproducibility.
- If it prompts (Claude Code) to pick the agents' model, choose the strongest available (Opus-class) for this
  funds-touching surface.

## 2. Pin your own scope (do not trust paths from memory)

- Record the commit you review: `git rev-parse HEAD` (expected branch `feat/v1.1.0-core-upgrade`). Put that hash on
  every artifact.
- **Real source root is `src/`, not `contracts/core/src/`.** The skill's discovery step globs in-scope `.sol` (excluding
  test/mock/lib) — point it at `src/` and confirm it did not pull in `lib/`, `tests/`, `out/`, `legacy/`, or `external/`.
- **Scope reconciliation.** At `b52557b`, **Cluster C** (`DynamicFeeFlatPriceCurve` + standardized `IBaseCurve` quote/
  record fee hooks) **is not merged.** Verify at your commit
  (`grep -rl "quoteDepositFee\|recordDeposit\|accFeePerShare\|DynamicFeeFlatPriceCurve" src`); if absent, mark Cluster C
  **"not present at this commit — not audited"** and do not let any agent hallucinate it. Clusters A, B, D, E, F, G, H
  are present.
- Honor §3 out-of-scope exactly (bridge/MetaLayer transport, Base-chain, parked rate-limiter, cross-curve counter-stake,
  migration mode, legacy `Trust`/`VotingEscrow`, trusted-admin centralization, held-out wallet delegation, mixed payable
  batching). Note the boundary if an agent wanders in; do not file it.

## 3. Run the skill — under the master brief's mandate

- Run the full 12-agent sweep on the in-scope `src/` set; let its dedup + four judging gates + PoC validation run. Its
  built-in gates (75+ confidence / multi-agent consensus to promote a lead) are good — **but do not let a gate suppress a
  refutation record.**
- **Overlay the master brief's discipline:**
  - Assume ≥1 fund-loss / mint-burn-imbalance / trust-boundary bug exists (§1): concrete exploit path **or** evidenced
    refutation per property; **a `PASS` with no refutation attempt is a `FAIL`** (§4).
  - **Whole-contract**, not diff-only. Tie every promoted finding to the specific §5 invariant it breaks, on top of the
    skill's own agent attribution.
  - For High/Critical, land a Foundry PoC under `tests/unit/security/v1.1.0/` (extend the relevant `BaseTest`, explicit
    revert selectors, before/after conservation assertions); mutation-check guard claims (red when the guard is removed).
  - Variant sweep (§4.5) every confirmed break: single / batch / on-behalf-of / preview / router (FeeProxy) /
    upgrade-initializer.

## 4. Output — two files, our format, into `audits/internal-audits/`

Translate the skill's grouped-by-severity report into **both** master-brief deliverables:

1. **Working found→fixed log** (§8: summary table + per-finding blocks + negatives + per-cluster `VERDICT`) →
   **`audits/internal-audits/v1.1.0-parallel-round-findings-log.md`**.
2. **Packaged report** (§8a house style: cover/metadata with reviewed commit, executive summary with severity counts,
   scope + out-of-scope, Impact×Likelihood model with Critical/Major/Medium/Minor/Informational, findings highest-first
   with Description/Code/PoC/Recommendation/Resolution, negatives section, methodology appendix + pre-audit disclaimer) →
   **`audits/internal-audits/v1.1.0-parallel-round-report.md`**.

Map the skill's severities onto ours (Critical→Critical, High→Major, Medium→Medium, Low→Minor, Informational→
Informational). Do not overwrite any existing file in that directory. Delete the `./.audit-XXXXXX` temp bundle when done.

## 5. Constraints (§10) — non-negotiable

- **Finding-ID prefix `PAR`** (e.g. `PAR-01`). Preserve it through triage.
- **Pre-audit artifact**, internal AI pseudo-audit — not a formal audit/certification/guarantee.
- **Mechanism-only, no attribution** in shipped output: no model/vendor/person names (describe the round neutrally as the
  **"parallel specialist-agent round"** — not by the tool author's name), no ticket ids or call references. Full 40-hex
  `0x…` addresses in backticks where needed; resolve from manifests by name; burn sink = `BURN_ADDRESS`.
- **Local only.** Never touch CI / `.github/**`. Foundry `1.5.1`, Solidity `0.8.29`.

Close each cluster with `VERDICT: PASS` / `VERDICT: FAIL`; end the log with a headline severity count.
