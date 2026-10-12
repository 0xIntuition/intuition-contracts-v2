# Smart Contract Auditor Skill

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Claude Code skill for systematic, checklist-driven security audits of Solidity/EVM smart contracts.

The skill walks Claude through a 370-item checklist spanning 13 categories (attack patterns, DeFi, integrations, tokens, cross-chain, signatures, low-level, and more), anchoring every finding to a checklist item so reasoning is traceable to prior art.

## Reference

The checklist content under `references/` is sourced from and adapted from the [Cyfrin/audit-checklist](https://github.com/Cyfrin/audit-checklist) repository — a curated distillation of real findings from Solodit (Code4rena, Sherlock, Cyfrin, Spearbit, and others).

All credit for the underlying checklist data goes to Cyfrin and the contributors of that repository.

## Structure

```
.
├── SKILL.md          # Skill entry point — workflow, scoping, triage rubric
├── references/       # Checklist content, split per category
│   ├── INDEX.md
│   ├── attacker-s-mindset.md
│   ├── basics.md
│   ├── defi.md
│   ├── integrations.md
│   ├── token.md
│   └── ...
└── evals/            # Evaluation harness and fixture contracts
    ├── evals.json
    └── files/
```

## Installation

Clone into your Claude Code skills directory:

```bash
git clone https://github.com/farrellh1/smart-contract-auditor-skill.git ~/.claude/skills/smart-contract-audit
```

Claude Code will auto-discover the skill via `SKILL.md`.

## Usage

Once installed, trigger the skill by asking Claude to audit, review, or assess the security of a Solidity contract. Examples:

- "Audit this lending contract"
- "Review `Vault.sol` for security issues"
- "Any reentrancy risks in this AMM?"

Claude will scope the contract, load only the relevant reference files, walk the checklist, and report findings with severity and checklist-item citations.

## License

This skill — `SKILL.md`, the workflow, and the evals — is released under the [MIT License](LICENSE).

The checklist content under `references/` derives from [Cyfrin/audit-checklist](https://github.com/Cyfrin/audit-checklist); refer to that repository for the upstream license governing the underlying data.
