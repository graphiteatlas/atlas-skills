# atlas-skills

[![version](https://img.shields.io/badge/version-0.2.0-blue)](.claude-plugin/plugin.json)
[![license](https://img.shields.io/badge/license-Terms%20of%20Service-lightgrey)](LICENSE.md)

Skills that teach an AI agent to model well in [Graphite Atlas](https://graphiteatlas.com):
the vocabulary, the modeling principles, the order of operations, and the checks.

Also the source for the `graphite-atlas` Claude Code plugin, which bundles these
skills with the Atlas MCP server — tools plus the know-how to use them. See
[`README.plugin.md`](README.plugin.md).

## The skills

| Skill | What it answers |
|---|---|
| `atlas-modeling` | **How should this be modeled?** The three principles, each with its anti-patterns inline, and worked examples in `atlas-modeling/references/`. |
| `atlas-language` | **What can I say?** Point types, Path types and what may connect to what, properties, the default folders and the naming rules. |
| `atlas-build` | **In what order?** Reading sources, choosing the unit of work, proposing the change before writing it, labelling what was inferred, writing, and reading it back. |
| `atlas-auditing` | **What is wrong?** 18 read-only checks that catch principle violations after a build. |
| `atlas-completeness` | **What is missing?** Absence checks, output as an interview script grouped by who can answer. |

## How to use them

- **Before any write:** `atlas-modeling`.
- **Building from documents** (a PDF, an SOP, a transcript, a set of them): `atlas-build` first.
- **Unsure what a type is or what may connect:** `atlas-language`.
- **After a build or edit:** `atlas-auditing`, then `atlas-completeness`. In that order: wrong beats thin.

## Contributing

Every skill must read as a finished, generic artifact: neutral examples, no people, no internal
references. See [`CONTRIBUTING.md`](CONTRIBUTING.md), and run `scripts/check-public.sh` before pushing.
