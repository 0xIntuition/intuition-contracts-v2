# Template 2 — Pre-Audit Mirroring & Master-Report Runbook

**Purpose.** The operational counterpart to Template 1 (`./pre-audit-round-handoff-template.md`). It covers (a) **when**
to run a pre-audit round, (b) the **round composition** and minimums, (c) how to **mirror** the reports between the
public-mirror PR repo and the internal working repository within the standard folder structure, and (d) how to **build
the master consolidated report** and drive the post-master found→fixed loop.

**When to run.** Every time a **mirrored public-repo PR** is opened for an upcoming external audit (e.g. the v1.1.0 core
upgrade in PR #153). The pre-audit round is the internal breadth+adversarial pass that front-runs the paid audit.

---

## 1. Round composition (the minimums)

A round is **multiple independent reviewers**, each producing exactly one labeled report (Template 1), then consolidated
into one master. Independence is the value — never seed one reviewer with another's findings before triage.

- **Vanilla agent reports — minimum 2.** Frontier + cross-model, ideally different model families (e.g. Opus/Fable
  frontier + GPT cross-model). Their strength is deep, unconstrained first-principles reasoning.
- **Skill-driven reports — minimum 3.** Packaged audit skills, each a different methodology. Examples used to date: the
  local `smart-contract-audit` checklist skill in single-reviewer ("ToB") and 10-agent-per-contract ("Cyfrin") modes,
  HumanPages.ai `audit-contract`, Pashov `solidity-auditor`. (Deferred example: One Dollar Audit, the $1 autonomous pass
  — scaffolding under the team-internal working area, run when a Base wallet is funded.) Their strength is breadth and
  cross-checking; a finding several skills reach independently is high-signal.
- **Commit discipline.** All reviewers pin the **same** commit (the SHA you provide, or the latest PR HEAD). Diff basis
  is `git diff main...<COMMIT>`; each records it with `git rev-parse HEAD` and stamps it on every artifact. A reviewer
  on a different checkout (as the demoted breadth pass was, on `b768364`) is **supporting only**, not a numbered report.

---

## 2. Folder structure (identical in both repos)

Reports live in `audits/` in **both** repos. Everything that drives or backs a round — handoffs, templates, skill-native
artifacts — is **team-internal**.

```
audits/                                       # both repos
├─ <external audit PDFs at the root>          # canonical third-party engagements
└─ internal-audits/
   ├─ instructions/                           # these two templates + process README (internal only)
   └─ <VERSION>/                              # e.g. v1.1.0/ — version once, so filenames stay clean
      ├─ README.md                            # index (internal only)
      ├─ round-0/                             # optional: original single-report round predating the expansion
      └─ round-<n>/
         ├─ README.md                         # round index + provenance table (internal only)
         ├─ MASTER-consolidated-report.md     # the deliverable — build per §4
         ├─ vanilla-<model>.md                # ≥2
         └─ skill-<tool>.md                   # ≥3
                                              # no per-round working logs — the report is the only deliverable

private/                                      # internal only, gitignored
├─ templates/                                 # working copies of these two templates
├─ docs/handoffs/                             # master brief + per-reviewer handoffs (+ oda/ scaffolding)
└─ internal-audits/<VERSION>-round-<n>/       # retained skill-native artifacts, if any
```

---

## 3. Mirroring runbook (public mirror ⇄ internal working repository)

The reports are authored against the **public-mirror PR checkout** (where the code under review lives) but the
**internal working repository is the canonical home** for internal audit history. Keep both in sync **within the
identical structure above**.

**Define once (fill in):** `<PUBLIC_MIRROR>` = path to the public-mirror clone (has the PR branch); `<INTERNAL_REPO>` =
path to the internal working repository's mirror of the same `audits/` tree.

**A. Snapshot before any reorg.** Always back up the current `audits/` tree to a gitignored location first (e.g.
`private/audits-snapshot-<timestamp>/`) so nothing is lost — the reorg is then reversible.

**B. Public-mirror → internal working repository (the usual direction).** After a round completes in `<PUBLIC_MIRROR>`:

```
rsync -a --delete \
  "<PUBLIC_MIRROR>/audits/internal-audits/<VERSION>/round-<n>/" \
  "<INTERNAL_REPO>/audits/internal-audits/<VERSION>/round-<n>/"
```

Copy the driving handoffs too (the team-internal working area) so the internal working repository records how each round
was produced.

**C. Internal working repository → public mirror (only if a report is meant to ship publicly).** The internal round
reports **name models / skills / vendors** for the team's tracking. Before pushing any of them to the public mirror,
**neutralize**: strip model/vendor/person names to method descriptors and keep only the id-prefix provenance (handoff
§10). In practice:

- **Do publish** (neutralized): the `MASTER-consolidated-report.md` if the team decides external auditors get it — it is
  written to travel (professional prose, id-prefix provenance, disclaimer).
- **Keep internal** by default: the per-round `vanilla-*` / `skill-*` files, plus any retained skill-native artifacts
  under `private/internal-audits/<VERSION>-round-<n>/`. If they must go public, run the neutralization pass first.
- Never push `private/**` or any snapshot backup.

**D. Verify the mirror.** `diff -rq` the two `round-<n>/` trees (or `git status` in each) and confirm the file set +
labels match; both READMEs should list the same reports.

---

## 4. Build the master consolidated report

The master is the release-level, Diligence-style view and the go/no-go gate. Build it **after** all round reports exist.

**4.1 Collect.** Read every round's **report** — each opens with a machine-mergeable summary table (Template 1 §2), so
there is no separate per-round log to merge. Extract each finding as
`(id, severity, confidence, cluster, title, file:line, status)`.

**4.2 De-duplicate by _content_, not by id.** Group findings that describe the same underlying mechanism across rounds
(e.g. the ERC-1271 raw-digest replay reached by 3 rounds → one consolidated `MED-01` listing
`Fable-E-01 = TOB-01 = LC-E-02`). Assign a consolidated id per severity band (`MA-…`, `MED-…`, `MIN-…`, `INFO-…`) and
**list the contributing per-round ids** so provenance survives. Record **rounds-reached** as a signal proxy.

**4.3 Severity policy.**

- Take the **highest severity a credible path reaches** across rounds (e.g. the zero-epoch DoS was Medium in one round,
  Low in three → carry it **Medium**). Where rounds genuinely disagree on a design question, carry the higher severity
  and **state the disagreement** (see the pause-forfeiture example).
- **Inclusion:** every **Medium and above** goes in the master in full. Include only **meaningful** Minor/Informational
  — the load-bearing tail (real init-safety, config footguns, corroborated malleability), not per-contract hygiene
  noise. The full raw sets stay in the per-round reports.
- Map to Diligence labels: Critical / **Major** (=High) / Medium / **Minor** (=Low) / Informational.

**4.4 Sections (Diligence house style).** Cover/metadata (commit, rounds/models merged, date) → executive summary with a
severity-count table and the headline result → scope + out-of-scope + any absent-surface caveat → severity model →
load-bearing invariants → **consolidated findings highest-first** (each with provenance + rounds-reached + PoC +
recommendation + gate) → **properties checked (negatives)** with which rounds confirmed → a **cross-round agreement
matrix** (findings × rounds) → **remediation status** (note any uncommitted on-branch fixes, unverified) → **go/no-go
gate** (what to close before the external audit) → appendix (methodology, provenance table, publish-neutralization note,
pre-audit disclaimer).

**4.5 Honesty rules.** Do **not** mark anything `Fixed` you have not verified. If the working tree shows remediation in
progress, say exactly that ("uncommitted changes consistent with a fix; unverified here") and keep the finding at
as-found status.

---

## 5. Post-master: fix the pre-audit findings after deeper review

The master is the input to remediation, not the end. For each Medium-and-above (and any Minor the team elects to fix):

1. **Deeper review of the finding** — confirm the mechanism and reachability beyond the round's write-up (e.g. resolve
   an open question like an on-chain census before deciding a Major is live).
2. **Fix** in `src/`, with a **gating regression test** under `tests/unit/security/<VERSION>/`.
3. **Mutation-check** the fix: the gating test must go **red** when the guard is removed — a test green in both states
   proves nothing.
4. **Update the master's disposition register** (§5a): move the finding `Open → Closed — Fixed`, name the gating test,
   and re-verify severity. This register _is_ the found→fixed log — it lives at master level, not per round.
5. Re-run the master's §4.4 remediation-status + go/no-go sections so the packaged deliverable reflects reality.

What the external auditors receive is the **Diligence-style master report** — including its disposition register, which
serves as the found→fixed log — together with the go/no-go verdict, and the per-round reports behind it.

### 5a. Disposition register — how to close out every finding

**Every finding gets an explicit, recorded disposition — including the ones you are not fixing.** A finding left
implicitly "open" reads to an external auditor as unaddressed. The master report carries a **disposition register**: one
row per finding (ID · status · response/rationale), placed at the end of the findings section.

**Status vocabulary** (keep it to these — mechanical to merge and unambiguous to a reader):

| Status                      | Use when                                               | Must record                                                                 |
| --------------------------- | ------------------------------------------------------ | --------------------------------------------------------------------------- |
| **Closed — Fixed**          | A code change landed                                   | The gating regression test, mutation-checked                                |
| **Closed — Not applicable** | The precondition does not exist in the deployed system | The **verified fact** (on-chain read, config value) and how it was verified |
| **Closed — By design**      | The behavior is the intended design decision           | The test or doc that **asserts** the behavior as intended                   |
| **Closed — Acknowledged**   | Accepted as-is under the trust model / risk posture    | Why it is acceptable, plus any ops-runbook consequence                      |
| **Open**                    | Action still required                                  | The owner and what closes it                                                |

**Rules that keep the register honest:**

1. **Check whether the "fix" was already evaluated and rejected.** Before carrying a reviewer's recommendation forward,
   grep the tests and NatSpec for the behavior. AI rounds routinely flag a deliberate design as a bug; if a test asserts
   the behavior as intended, the disposition is **By design** and the reviewer's recommendation is _superseded_ — say so
   explicitly rather than leaving a recommendation that contradicts the shipped design.
2. **Quantify before accepting.** For anything accepted as bounded, measure it (a throwaway probe test is fine) and put
   the numbers in the register. "Bounded" without a number is an assertion, not a disposition.
3. **A "not applicable" that rests on a point-in-time fact becomes a pre-execution gate.** If a finding is closed by an
   on-chain fact _and_ the code-level mitigation was deliberately not built, that fact is load-bearing: record it as a
   **re-check immediately before the upgrade** in the go/no-go section, not as a one-time verification.
4. **Verify on-chain claims against chain, not against belief.** Reads like initializer version, epoch length, or a
   wallet census are cheap (`cast storage` / `cast call` against the public RPC) — do them and cite the chain id.
5. **Separate code changes from documentation changes** when reporting the outcome, so a reviewer knows what altered
   behavior versus what only altered a comment. Docs-only corrections (NatSpec that overstates a guarantee, stale
   references) are legitimate closures — label them as such.
6. **Findings about surfaces absent at the reviewed commit are scope for the next round**, not defects in this one. Mark
   them `Open — deferred to round N+1` and carry them into that round's brief.

Finally, re-run the master's remediation-status and go/no-go sections so they agree with the register — the register is
the source of truth once it exists.

---

## 6. Constraints (carry into every artifact)

- **Pre-audit artifact** — not a formal audit, certification, warranty, or guarantee of safety.
- **Local only** for the reviews; never touch CI / `.github/**`; do not modify `src/` as part of _reviewing_ (only as
  part of the explicit §5 remediation step).
- **Labeling** per Template 1 §3 (filename + title + subtitle + explainer + id-prefix). **Neutralize**
  model/vendor/person names before anything ships publicly.
- **Full-length `0x…` addresses**; resolve addresses from deploy manifests by name; describe issues **by mechanism**.
- Preserve **round/model provenance** on every finding id, even in the packaged master.
