---
description: Find code variants of a known vulnerability pattern
argument-hint: "[vulnerability-description]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
---

Find vulnerability variants across this repository.

Arguments: $ARGUMENTS

Steps:
1. Use `$ARGUMENTS` as the known bug pattern summary.
2. If no argument is provided, infer the pattern from recent conversation context.
3. Invoke the `variant-analysis` skill.
4. Classify matches into:
   - confirmed variants
   - probable variants needing review
   - false positives
5. Write output to `audits/automated-reports/Variant-Analysis.md`.
