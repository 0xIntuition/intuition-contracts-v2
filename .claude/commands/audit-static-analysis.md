---
description: Run static analysis workflow for security findings
argument-hint: "[codebase-path]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
---

Run a static-analysis-first audit pass for the target codebase.

Arguments: $ARGUMENTS

Steps:
1. Use `$ARGUMENTS` as codebase path (default `.`).
2. Invoke the `semgrep` skill from `static-analysis`.
3. If SARIF is produced, invoke `sarif-parsing` to summarize and deduplicate findings.
4. If CodeQL is available in the environment, invoke the `codeql` skill for deeper data-flow checks.
5. Focus triage on Solidity security classes (access control, reentrancy, unchecked external calls, invariant breaks).
6. Write output to `audits/automated-reports/Static-Analysis.md`.
