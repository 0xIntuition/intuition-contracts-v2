---
description: Run end-to-end Solidity audit workflow
argument-hint: "[codebase-path] [spec-document-optional]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
  - WebFetch
---

Execute a full smart contract security workflow for this repository.

Arguments: $ARGUMENTS

Workflow:
1. Parse `$ARGUMENTS`:
   - codebase path (default `.`)
   - optional specification path/URL
2. Build architecture and trust-boundary context using `audit-context-building`.
3. Map attack surface using `entry-point-analyzer`.
4. Run static analysis using `semgrep` (and `sarif-parsing` if SARIF exists).
5. Apply `variant-analysis` on each medium/high/critical finding pattern.
6. If a spec is provided, run `spec-to-code-compliance`.
7. Recommend property-based tests for critical invariants using `property-based-testing`.
8. Produce a consolidated report with severity-ranked findings and remediation actions.

Write final report to `audits/automated-reports/Solidity-Security-Audit.md`.
