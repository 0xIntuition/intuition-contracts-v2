---
name: "contracts:audit-context"
description: Build audit context for this Solidity codebase
argument-hint: "[codebase-path] [--focus <module>]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
---

Build deep audit context for the target codebase.

Arguments: $ARGUMENTS

Steps:
1. Parse `$ARGUMENTS` into:
   - codebase path (default `.`)
   - optional `--focus <module>`
2. Invoke the `audit-context-building` skill for the parsed target.
3. Produce a concise architecture summary focused on:
   - trust boundaries
   - privileged roles
   - critical state transitions
   - external dependencies
4. Write output to `audits/automated-reports/Audit-Context.md`.
