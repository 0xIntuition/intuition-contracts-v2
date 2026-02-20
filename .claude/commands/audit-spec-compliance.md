---
name: "contracts:audit-spec-compliance"
description: Verify implementation against audit spec
argument-hint: "<spec-document> [codebase-path]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
  - WebFetch
---

Run spec-to-code compliance analysis.

Arguments: $ARGUMENTS

Steps:
1. Parse `$ARGUMENTS`:
   - required spec document (path or URL)
   - optional codebase path (default `.`)
2. Invoke the `spec-to-code-compliance` skill.
3. Produce evidence-based mapping of:
   - implemented requirements
   - missing requirements
   - ambiguous implementations requiring manual review
4. Write output to `audits/automated-reports/Spec-Compliance.md`.
