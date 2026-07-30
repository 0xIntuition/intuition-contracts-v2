# Adversarial Agentic Pre-Audit Review — Templates & Process

> **Published copy.** These are the working process documents behind the internal pre-audit rounds whose reports sit
> alongside them, included so the method can be checked rather than taken on trust. Paths into the team's private
> working area have been removed; nothing else is altered. Model and skill names are retained deliberately — see the
> publishing note in any round's `MASTER-consolidated-report.md`.

A reusable, standardized process for the internal, multi-model / multi-tool **adversarial AI review** we run **before**
each external audit, on the mirrored public-repo PR. This folder holds the two templates that drive it and the overview
that ties them together.

## What it is

For a given upgrade (e.g. v1.1.0, PR #153) we run the whole in-scope contract set through **several independent AI
reviewers** — some **vanilla** frontier / cross-model reasoners, some **audit-skill-driven** — each re-deriving from one
shared brief and attacking the same invariants. Their findings are then de-duplicated into a single **master report**
that drives remediation and the go/no-go gate. Independence is the value: a finding several reviewers reach separately
is high-signal.

**Minimums per round:** ≥ 2 vanilla agents + ≥ 3 skills.

## The pieces

| Piece            | This folder                                                                                | Role                                                                                                                                                                                                                                    |
| ---------------- | ------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Template 1**   | [`pre-audit-round-handoff-template.md`](./pre-audit-round-handoff-template.md)             | A **meta-template for _writing_ the per-reviewer handoffs** (one per vanilla agent / per skill). You fill it in once per upgrade and use it to generate each reviewer's handoff — it is **not** a script to run literally in a session. |
| **Template 2**   | [`pre-audit-mirroring-and-master-runbook.md`](./pre-audit-mirroring-and-master-runbook.md) | The operational runbook you run **after** the rounds have executed and produced their reports: mirror reports between repos, build the de-duplicated master, drive the fix loop.                                                        |
| **Master brief** | team-internal working repository (team-internal)                                           | The shared, model-agnostic scope / invariants / out-of-scope / findings-format doc every reviewer re-derives from. Written per upgrade.                                                                                                 |

## The flow (in order)

```
master brief  ─►  Template 1  ─►  per-reviewer handoffs  ─►  each reviewer runs (independent)
(scope/invariants) (write handoffs)  (1 per vanilla / skill)   └─►  1 report + 1 working log each
                                                                        │
                                                                        ▼
                                                          Template 2 (run AFTER reports exist)
                                                          ├─ mirror  ├─ build MASTER  ├─ fix loop
```

1. Write / update the **master brief** for the upgrade.
2. Use **Template 1** to write one handoff per reviewer (≥ 2 vanilla, ≥ 3 skills).
3. Each reviewer runs **independently** (never seed one with another's findings) and emits **one report + one working
   log**.
4. Run **Template 2**: mirror, de-duplicate into the **master report**, then remediate (fix → mutation-check →
   found→fixed log) and set the go/no-go gate.

## Where the artifacts live

| Artifact                        | Location                                                    | Public?                                  |
| ------------------------------- | ----------------------------------------------------------- | ---------------------------------------- |
| External audit PDFs             | `audits/` (root)                                            | Yes (both repos)                         |
| Round **reports** + master      | `audits/internal-audits/<version>/round-<n>/`               | Yes (both repos)                         |
| These templates + this README   | `audits/internal-audits/instructions/`                      | Yes (both repos)                         |
| Per-version / per-round READMEs | `audits/internal-audits/<version>/…`                        | Internal only                            |
| Working logs (raw per-round)    | `private/internal-audits/<version>-round-<n>/working-logs/` | No — internal working repository private |
| Handoffs + master brief         | `private/docs/handoffs/`                                    | No — internal working repository private |

## Non-negotiable rules

- **Tests are provenance-free.** Any test a round writes ships to the public mirror, so it must be **mechanism-named** —
  never an AI-round / finding-id string (`CLD-`/`GPT-`/`TOB-`/`CYF-`/`HMN-`/`PAS-`/…), a round name (`FrontierRound`,
  …), `pseudo-audit`, or a vendor name in a filename, contract/mock name, or comment. Provenance lives in the report +
  working log. (Template 1 §0.6.)
- **Reports** may name the model / skill / vendor (that's the point of the labels) and are public; **handoffs and
  working logs are team-internal.**
- **No AI attribution** in commits / PRs; one-line commit messages; signed commits.
- A finding that only exists in the not-yet-deployed PR code is not live-exploitable — reconcile the master's go/no-go
  against **what is actually deployed on-chain** before treating a finding as blocking.

---

_Pre-audit artifacts are internal, first-party reviews run before the external audit — **not** a formal audit,
certification, warranty, or guarantee of safety._
