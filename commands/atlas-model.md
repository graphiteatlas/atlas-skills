---
description: Preflight before building or editing a Graphite Atlas — load the modeling principles, then model.
---

Before creating, updating, or deleting any Points or Paths in a Graphite Atlas:

1. Invoke the `atlas-modeling` skill (the three-principle preflight: clean structure, correct attachment, semantic node typing — with the anti-pattern examples inline).
2. Use `atlas-language` to confirm valid point/path types and the default folder structure before you create anything — never guess a type.
3. For a specific hard call (Handoff vs Step, Artifact vs System, instance vs singleton, naming), read the matching worked example in `atlas-modeling/references/`.
4. After the write, run the `atlas-auditing` skill to QA against the modeling principles.

Then proceed with the user's modeling task.
