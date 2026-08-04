# atlas-skills

Modeling skills for building, refining, and auditing a Graphite Atlas. Installed and in use, and the
source for the `graphite-atlas` Claude Code plugin (see `README.plugin.md`).

## The skills

| Skill | Role |
|---|---|
| `atlas-modeling` | preflight: the 3 modeling principles, each with its **anti-pattern examples inline** (always in context). Deeper worked examples in `atlas-modeling/references/`. |
| `atlas-language` | the **Atlas language** — typed vocabulary of Point types, Path types, Properties + the default folder structure + naming rules. |
| `atlas-auditing` | read-only Cypher health checks — the deterministic backstop that catches principle violations after a build. |


## How to use

- **Before any write to an Atlas:** invoke `atlas-modeling` (3 principles + inline anti-patterns).
- **To check what types exist / what can connect:** use `atlas-language`.
- **After a build or edit:** invoke `atlas-auditing`.

Each top-level skill folder is symlinked into `~/.claude/skills/` so the Skill tool discovers them
across all Claude Code sessions. This repo is the source of truth; the symlinks point back.

## The three principles (examples now in `atlas-modeling/references/`)

### 1. Name by function
A node represents one thing, named by what it functionally is. Identity, vendor, person, and per-flow
context live on edges and properties, not in the node's name or description.
- `references/name-by-function` — name nodes by function; vendor/person/system identity lives on edges
- `references/structure-over-prose` — facts with a structural home live there once; descriptions carry only nuance
- `references/instance-nodes` — actions are per-flow instances; entities are shared singletons

### 2. Attach at the right level and type
Connect things at the right level and type. Dependencies on the atomic step. Services as Systems with
Vendors via `provided_by`. Documents/messages as Artifacts via `creates_output`/`needs_input`.
- `references/dependencies-on-steps` — `uses_resource`/`needs_input` attach to the leaf step
- `references/service-as-system` — Step → Service (System) → `provided_by` → Vendor; never Step → Vendor
- `references/artifact-vs-system` — Systems do work; Artifacts are documents/messages (EDI 850/856, NACHA, 1099/K-1 are Artifacts)

### 3. Type by meaning, membership explicit
Use the right Point type. Sequenced steps need an explicit `has_step`. Handoff is a transfer of
responsibility, not a notification.
- `references/step-membership` — every member step needs its own `has_step`; `followed_by` is order only
- `references/handoff-vs-communication` — `Handoff` = responsibility transfer; notifications are plain Steps

## Discipline for adding new patterns

When a new edge case surfaces during live modeling:
1. **First ask:** does it fit under one of the three principles? Almost always yes.
2. **If yes:** add it as a one-line anti-pattern in `atlas-modeling`'s checklist (and a worked example
   in `references/` if it needs depth). Do **not** create a new top-level skill.
3. **If no:** propose a new principle. New top-level principles should be rare.

## Maintenance

This repo is the canonical source for the Atlas skill set. The `atlas-language` vocabulary tracks the
product's type system; new modeling patterns are added as examples under an existing principle rather
than as new top-level skills.
