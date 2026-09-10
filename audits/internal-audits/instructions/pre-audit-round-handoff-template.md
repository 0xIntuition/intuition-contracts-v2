# Template 1 — Pre-Audit Round Handoff (per model / per skill)

**Purpose.** A fill-in-the-blanks template for writing the handoffs that drive an internal AI pseudo-audit round. One
handoff → one independent reviewer (a vanilla model or an audit skill) → **exactly one labeled report**. Use it so every
round is adversarial, first-principles, diff-aware, and lands in the right place with the right label — never again a
folder full of ambiguously-named files.

**When to use.** Whenever a **mirrored public-repo PR** exists for an upcoming external audit (e.g. the v1.1.0 core
upgrade in PR #153). Pair this with the master brief (the shared, model-agnostic scope/invariants document — for v1.1.0
that is the team-internal master brief) and with Template 2 (the mirroring + master runbook:
`./pre-audit-mirroring-and-master-runbook.md`).

---

## 0. Fill these in once (shared across the round)

| Field            | Value for this run                                                                                                                                                                                                |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `<VERSION>`      | e.g. `v1.1.0`                                                                                                                                                                                                     |
| `<REPO>`         | public mirror slug, e.g. `0xIntuition/intuition-contracts-v2`                                                                                                                                                     |
| `<PR#>`          | open PR carrying the upgrade, e.g. `153`                                                                                                                                                                          |
| `<BRANCH>`       | e.g. `feat/v1.1.0-core-upgrade`                                                                                                                                                                                   |
| `<COMMIT>`       | **the commit each reviewer pins.** Either the SHA you provide, or "latest PR HEAD" — the reviewer records it with `git rev-parse HEAD` and stamps it on every artifact. Diff basis is `git diff main...<COMMIT>`. |
| `<SOURCE_ROOT>`  | real source root, e.g. `src/` (state it explicitly — do not assume a default)                                                                                                                                     |
| `<IN_SCOPE_SET>` | the contract list (from the master brief §2), mapped to real paths at `<COMMIT>`                                                                                                                                  |
| `<OUT_OF_SCOPE>` | the denylist (master brief §3)                                                                                                                                                                                    |
| `<INVARIANTS>`   | the load-bearing properties (master brief §5)                                                                                                                                                                     |
| `<MASTER_BRIEF>` | path to the shared brief, e.g. the team-internal master brief                                                                                                                                                     |

**Non-negotiable clauses every handoff must carry:**

1. **Diff-aware but whole-contract.** Diff basis is `git diff main...<COMMIT>`; review each in-scope contract **in
   full** (new surface **and** the pre-existing functions around it — an upgrade can silently break a baseline
   invariant), not just the delta.
2. **Adversarial, first-principles.** Assume ≥1 fund-loss / mint-burn-imbalance / trust-boundary bug exists. Per
   property: a concrete exploit path **or** an evidenced refutation. **A `PASS` with no attempted refutation is a
   `FAIL`.** Do not defer to prior reviews or code comments.
3. **Independence.** Re-derive from `<MASTER_BRIEF>` + source. **Do not read other rounds' findings** before triage
   (`internal-audits/<VERSION>/round-<n>/` and its `working-logs/` are off-limits during the run).
4. **Pin & verify scope.** `git rev-parse HEAD`; confirm the branch; map every contract to its real path under
   `<SOURCE_ROOT>`; **symbol-search to confirm each cluster actually exists at `<COMMIT>`** before auditing it (features
   described in the brief may not be merged yet — mark absent ones "not present at this commit — not audited").
5. **One report out, correctly labeled and placed** — see §3.
6. **Tests are provenance-free (HARD RULE).** Reports and working logs carry the round/tool provenance; **tests never
   do.** Every test a round writes — PoC, regression, or otherwise — must be named for the **mechanism** it exercises,
   never for the round or tool. **Never** put an AI-round / finding-id prefix (`CLD-`, `GPT-`, `TOB-`, `CYF-`, `HMN-`,
   `PAS-`, `LC-`, `BR-`, `OG-`, `INT-…`), a round name (`FrontierRound`, `MultiAgentRound`, `ParallelRound`,
   `pseudo-audit`), or a vendor name (`Cyfrin`, `Pashov`, `HumanPages`, …) in a test **filename**, **contract / mock
   name**, or **comment**. Tests ship to the **public mirror**; provenance must stay in the team-internal working
   repository (report + working log). Example: name it `AtomWalletBeaconUpgradeRegression.t.sol` with a
   `LegacyOwnerBeaconUpgradeTest` contract — **not** `FrontierRound_WalletUpgrade.t.sol` with a
   `FrontierRoundLegacyAtomWallet` mock.
7. **Write any test you need — but do NOT commit new test files (HARD RULE).** Write, run, and iterate on as many
   Foundry PoCs and probes as the review requires; that is how findings get evidenced. **They are scratch artifacts:
   delete them before you finish.** The deliverable of an audit round is the **report**, not tests. A new test file is
   committed **only** when it gates an actual fix we are shipping and we want to publish proof the issue is fixed — and
   that happens in the _remediation_ step, not the review step. Rationale: a round produces PoCs for findings that are
   later dispositioned by-design, not-applicable, or acknowledged; committing those leaves the public mirror carrying
   tests for non-issues, advertises internal review provenance, and creates suite churn that must be reverted later.
   Record the PoC **in the report** (setup → ordered calls → the assertion that fails, with before/after numbers) and
   name the **proposed** regression test — do not land it.

   **Where to put them: `tests/scratch/`.** That directory is gitignored, so scratch PoCs compile and run with the
   project's full context (same remappings, same `BaseTest`, warm build cache) but never appear in `git status` and
   cannot be committed by accident. Still delete them when done — the gitignore is a safety net, not a licence to
   litter. Do **not** scatter scratch tests through `tests/unit/**`; that is what produced the review noise and the
   stray files earlier rounds had to clean up.

---

## 1. Choose the reviewer flavor

- **Vanilla agent** (no skill) — a frontier or cross-model reasoner running the master brief directly. **Minimum 2 per
  round**, ideally different model families (e.g. an Opus/Fable frontier round + a GPT cross-model round). ID prefixes
  encode the model (`CLD-`, `GPT-`, …).
- **Skill-driven** — a packaged audit skill (local or vendored). **Minimum 3 per round.** Examples used to date: the
  local `smart-contract-audit` checklist skill (single-reviewer → "ToB", 10-agent-per-contract → "Cyfrin"),
  HumanPages.ai `audit-contract`, Pashov `solidity-auditor`, and the deferred One Dollar Audit ($1). ID prefixes encode
  the tool (`TOB-`, `CYF-`, `HMN-`, `PAS-`, …). For any externally-fetched skill: **vendor a reviewed copy and pin the
  commit** before running (supply-chain / prompt-injection surface), and disable web egress if you want zero data
  leaving the box.

---

## 2. Output contract (identical for every reviewer)

**Every reviewer produces exactly ONE deliverable: the report.** There is no per-reviewer working log — earlier rounds
emitted a separate found→fixed log per reviewer that duplicated ~90% of its own report in a second format. Found→fixed
**tracking is a master-level artifact** (the disposition register built in Template 2), not a per-round one.

- A **packaged report** (Diligence house style: cover/metadata with `<COMMIT>`, executive summary + severity counts,
  scope + out-of-scope, Impact×Likelihood severity model with **Critical / Major / Medium / Minor / Informational**,
  findings highest-first with Description / Code (`file:line`) / PoC / Recommendation / Status, a "properties checked
  (negatives)" section, per-cluster `VERDICT` lines, and an appendix with method + the pre-audit disclaimer).
- It **must** open with a machine-mergeable **summary table** —
  `ID · Severity · Confidence · Cluster · Title · Invariant broken · Status` — so Template 2 can de-duplicate
  mechanically without a second format.

If a skill emits **native artifacts** worth keeping (per-contract checklist files, agent bundles), retain them in the
team-internal working repository alongside the round; do not reformat them into a hand-written log.

Severity mapping: Critical→Critical, High→**Major**, Medium→Medium, Low→**Minor**, Informational→Informational. For
every **High/Major+** finding, actually build and run a Foundry PoC locally (extend the relevant `BaseTest`, explicit
revert selectors, before/after conservation asserts) and mutation-check guard claims — then **delete the scratch test
and carry the PoC into the report** as an ordered attacker sequence with before/after numbers, plus the _name_ of the
regression test that would gate the fix. Per §0.7, no new test file is committed by a review round.

---

## 3. Labeling & placement (this is what prevents the mess)

**Filename** (in `audits/internal-audits/<VERSION>/round-<n>/`), tool encoded, no version prefix (the folder carries
it):

- Vanilla: `vanilla-<model>.md` — e.g. `vanilla-fable-opus.md`, `vanilla-gpt-5.6.md`.
- Skill: `skill-<tool>[-<mode>].md` — e.g. `skill-trail-of-bits-checklist.md`, `skill-cyfrin-checklist-multiagent.md`,
  `skill-humanpages-multiagent.md`, `skill-pashov-parallel.md`.

**Title + subtitle + explainer** at the top of every report (so the file is self-describing even out of context):

```markdown
# Intuition <VERSION> Core Upgrade — Internal AI Pseudo-Audit — Round <n>

## Report <k> of <N> — <Tool/Model label> (<one-line what-it-is>)

> **How this report was produced:** <method — vanilla vs skill, how many reviewers, what angle, what verification>.
> Provenance ID prefix: `<PFX>-`. One of <N> independent round reports; consolidated view:
> [`MASTER-consolidated-report.md`](MASTER-consolidated-report.md).
```

**Placement targets:**

```
audits/internal-audits/<VERSION>/round-<n>/
├─ <the numbered report>.md              # one per reviewer — the ONLY per-round deliverable
└─ MASTER-consolidated-report.md         # built later, per Template 2
```

Skill-native artifacts worth retaining (per-contract checklist files, agent bundles) go to the team-internal working
repository under `private/internal-audits/<VERSION>-round-<n>/`, never to the public mirror.

---

## 4. Copy-paste skeletons

### 4a. Vanilla-agent handoff

```
You are running one independent, adversarial pre-audit round on <REPO>, <VERSION> (PR #<PR#>), as a vanilla reasoner
(no audit skill). Work from first principles; produce a report, not a chat.

0. Read <MASTER_BRIEF> in full (mandate, out-of-scope, invariants, clusters, findings format, constraints). Apply it.
   Do NOT open audits/internal-audits/<VERSION>/round-<n>/ — independence.
1. Pin scope: `git rev-parse HEAD` (expect <BRANCH>); real source root <SOURCE_ROOT>; diff basis `git diff main...HEAD`;
   symbol-search each cluster to confirm it exists at this commit (mark absent ones "not present — not audited").
2. Posture: assume ≥1 fund-loss / mint-burn / trust-boundary bug. Per property: exploit path OR evidenced refutation;
   PASS-without-refutation = FAIL. Whole-contract, not diff-only. High/Major: build and RUN a Foundry PoC locally;
   mutation-check guard claims. Variant-sweep every confirmed break. Write as many scratch tests as you need, then
   DELETE them — do not commit new test files (see Template 1 §0.7); the PoC goes in the report, not the suite.
3. Output ONE file into audits/internal-audits/<VERSION>/round-<n>/: the packaged report `vanilla-<model>.md`
   (Diligence style, severity labels Critical/Major/Medium/Minor/Informational), opening with a machine-mergeable
   summary table (ID · Severity · Confidence · Cluster · Title · Invariant · Status). No separate working log.
   Title/subtitle/explainer per Template 1 §3. ID prefix `<PFX>-`.
4. Constraints: pre-audit artifact; local only; never touch .github/**; full-length addresses; mechanism-only.
   Close each cluster with VERDICT: PASS/FAIL; end with a headline severity count.
```

### 4b. Skill handoff (add these to 4a)

```
1a. Make the skill available: vendor <tool> at a PINNED commit into .claude/skills/; read its SKILL.md + references
    end-to-end first (you are the review gate); disable web egress for zero data leaving the box if required.
2a. Run the skill on the <SOURCE_ROOT> in-scope set; overlay the master brief's mandate on its output (tie every finding
    to the specific invariant it breaks, on top of the skill's own attribution); let its false-positive / judging gates
    and PoC validation run, but do not let a gate suppress a recorded refutation.
3a. Filename `skill-<tool>[-<mode>].md`; ID prefix the tool (`<PFX>-`). Clean up any temp bundle the skill created.
```

---

## 5. Definition of done (per handoff)

- Every invariant and cluster assigned has a recorded `PASS`/`FAIL` with a cited refutation attempt.
- Every confirmed break has `file:line`, an attacker sequence / PoC outline, a severity, a variant sweep, a proposed
  regression test.
- Exactly one numbered report (no working log), labeled and placed per §3.
- Model/round provenance preserved on every finding id.
