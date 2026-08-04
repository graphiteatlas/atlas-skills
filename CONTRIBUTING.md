# Contributing a skill

This is a public repo. Every skill and reference doc must read as a finished, generic artifact. Before writing, internalize the rules; before pushing, run the check.

## The rules

1. **Generic examples only.** Illustrate with widely-known neutral brands (Chase, SAP, Oracle, NetSuite, Salesforce, QuickBooks, FedEx, HubSpot, DocuSign) or role names ("the legacy ERP", "a state filing portal"). Never a customer's system, vendor, employee, or product name.
2. **No people.** No personal names, no team or session names, no "X owns this".
3. **No internal references.** No issue numbers, no PR links, no local filesystem paths, no internal tool names, no links to private repos or docs.
4. **No roadmap language.** Nothing "planned", "not yet", "coming", "until X ships", or dated "as of" snapshots. Describe what is, not what will be.
5. **Live product over bundled copies.** Point readers at the `lookup_ontology` tool for the authoritative type spec; do not bundle product data files that can drift.
6. **One invocable skill per concern; examples are reference docs.** Deep worked examples go in `references/*.md` as plain markdown (no skill frontmatter). A model won't invoke a narrow anti-pattern skill at the moment it's about to violate it, so anti-patterns live inline in the parent skill's checklist with the long-form example in references.

## Skill template

```markdown
---
name: <kebab-name>
description: Use when <trigger situations, concrete enough for a model to match>. <What it ensures, in one sentence.>
---

# <Title: the principle, stated imperatively>

**Principle:** <one sentence>

**When this applies:** <situations>

**Do:**
- <concrete, generic examples>

**Don't (anti-pattern):** <the failure, with a generic example>

**Litmus test:** *<the one question to ask>*
```

## Pre-push check

```
./scripts/check-public.sh
```

Fails on internal references and any term in the maintainer's local blocklist. Run it before every push; it is not optional.
