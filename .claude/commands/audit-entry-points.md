---
name: "contracts:audit-entry-points"
description: Enumerate state-changing attack surface
argument-hint: "[directory-path]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
---

Identify and classify state-changing entry points in the target.

Arguments: $ARGUMENTS

Steps:
1. Use `$ARGUMENTS` as the directory path (default `.`).
2. Invoke the `entry-point-analyzer` skill for this scope.
3. Prioritize functions that are:
   - public and unrestricted
   - role-restricted with high-impact state changes
   - upgrade/admin operations
4. Write the full report to `audits/automated-reports/Entry-Points.md`.
