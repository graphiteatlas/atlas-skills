---
name: atlas-modeling
description: Use before any write to a Graphite Atlas (creating, updating, or deleting Points or Paths; proposing schema changes; modeling a new process from a transcript, screenshot, or interview). Surfaces the three modeling principles, each with its anti-pattern examples inline so they are always in context; deeper worked examples live in `references/`. Invoke once per atlas-mutation session.
---

# Atlas modeling

Three principles. Most modeling mistakes are a violation of one of them, so hold all three as you
build or edit an Atlas. Each has its anti-pattern examples inline below, so you don't need to invoke
anything else; deeper worked examples are in `references/`.

*Terms: Atlas calls graph nodes **Points** and edges **Paths**. This skill uses Points and Paths.*

---

## 1. Name by function

**A Point is named by what it functionally is.** Identity (vendor, person), per-flow context, and any
fact with a structural home live on Paths/properties, not in the name or description. Then a vendor
swap is a one-Path change, "all payroll systems" queries hit it, and accountability stays queryable.

```
✗  "Rippling Payroll System"                          (vendor baked into the name)
✓  "Payroll System" ─provided_by→ Rippling

✗  step description: "the distributor allocates the part"   (accountability trapped in prose)
✓  "Local Distributor" (Org) ─performs→ the allocate Step

✗  artifact description: "Maintained by QuickBooks"          (prose RESTATING an edge that already
                                                              exists — desync risk + vendor baked in)
✓  description says what the thing IS ("the receivables ledger");
   the maintained-by fact lives ONLY on the creates_output/provided_by edges
```

**Description hygiene (same principle, applied to the description property).** A description is just
another property of the Point, so it must contain only facts UNIQUE to that Point. Two hard rules:

1. **Never restate a relationship.** If a fact is (or should be) a Path, it does not also go in prose —
   otherwise replacing the CIO means editing two places and they will desync. A change to Paths must
   never require a corresponding description edit.
2. **Factual only.** No value judgments, commentary, quips, or turns of phrase. State what the thing is.

```
✗  Organization description: "De novo asset manager. CIO: Jane Doe."   (has_role restated in prose)
✓  description: "De novo asset manager."; Jane Doe ─has_role→ "CIO" carries who holds the seat

✗  step description: "...the paper trail regulators ask for — especially load-bearing here"  (commentary)
✓  "Document the valuation methodology and rationale for each Level 3 position."
```

Allowed in descriptions: facts with no structural home in the ontology (e.g. "primary regulator" where
no regulates Path type exists), ILLUSTRATIVE/placeholder flags, and operational ATTACH notes.

Deeper examples: `references/name-by-function.md`, `references/structure-over-prose.md`,
`references/instance-nodes.md` (actions are per-flow instances; entities are shared singletons — never
wire one action Point into two flows).

## 2. Attach at the right level and type

**Attach dependencies to the atomic leaf Step, at the right type.** A Process inherits its steps'
dependencies by rollup, so hanging them on the Process loses which step actually uses what. Services
are Systems reached `provided_by` a Vendor; documents/messages are Artifacts.

```
✗  Process ─uses_resource→ SAP                (which of its 30 steps?)
✓  leaf Step ─uses_resource→ SAP

✗  Step ─uses_resource→ FedEx Corp            (step pointing straight at a Vendor)
✓  Step ─uses_resource→ "FedEx Parcel Service" (System) ─provided_by→ FedEx Corp

✗  Step ─uses_resource→ EDI 856               (a message treated as a System)
✓  Step ─creates_output→ EDI 856 (Artifact)
```

**Granularity test (actions and artifacts alike).** If a Step's description enumerates several actions
("prepare X, obtain Y, and complete Z"), those are sub-steps hiding in prose — promote the Step to a
Process and give each action its own Step, especially when the actions have *different* performers.
Correspondingly, a bundled Artifact splits into component Artifacts exactly when a distinct step or
actor produces each component; components produced by one actor in one step stay as prose in the
parent Artifact's description. Apply the line consistently, or the graph says "these components are
nodes" and "those are text" with no principle behind it.

Deeper examples: `references/dependencies-on-steps.md`, `references/service-as-system.md`,
`references/artifact-vs-system.md` (EDI X12, NACHA files, 1099/K-1 forms are Artifacts, not Systems),
`references/database-vs-table.md` (the store is a Database, the app is a System; tables attach via
`has_table`, columns are properties, join conditions live on `joins_to` edge descriptions).

## 3. Type by meaning, membership explicit

**Use the Point type that matches the meaning, with the membership Path it requires.** A member Step
needs its own `has_step` from its Process (`followed_by` is order, not membership). `Handoff` is a
transfer of responsibility (both sides modeled), not a notification.

```
✗  Step reachable only by followed_by from a sibling   (membership gap — queries/docs miss it)
✓  Process ─has_step→ Step, plus followed_by for order

✗  "Handoff" for a status update                       (nothing transfers)
✓  plain Step ─creates_output→ Notification; reserve Handoff for sender→receiver Position transfers
```

```
✗  "The CFO owns the forecast" → owned_by             (nothing is held as equity)
✓  CFO (Position) ─accountable_for→ Forecast Process; owned_by is equity only (+ ownership_pct)
```

**A point must say something the point beside it does not.** Never mint a second point that restates
the first. Two points whose names differ only by a word like Issue, Problem, Error, Task or Activity
are one point and a property, or one point and a path.

```
X  "Brittleness Issue" (Risk)  +  "Brittleness Remediation" (Step)   (the pair says one thing twice)
V  "Brittleness Remediation" (Step), with brittleness as the CONDITION under which it runs
```

A troubleshooting table is defect, cause, remedy. The remedy is the Step; the defect is what makes it
run, so it belongs on a `followed_by_if` condition or a property. Turning every row into a pair
doubles the model and adds nothing to it.

**A Risk is a thing that might happen.** It earns a point where the material is genuinely about risk:
a register, a controls assessment, an audit finding, something with an owner and a mitigation as
separate concerns. A named defect that a documented step exists to fix is not a risk, it is that
step's trigger. When in doubt, do not create the Risk. A missing one is a gap the customer can see
and ask for; a fabricated one is noise they have to find and delete.

Deeper examples: `references/step-membership.md`, `references/handoff-vs-communication.md`,
`references/ownership-vs-accountability.md` (the two meanings of "owns": equity = `owned_by`,
responsibility = `accountable_for`).

---

## Show it before you write it

**A model a human has not seen is not agreed to.** Before writing points and paths to an atlas,
render the proposal and let them read it: what gets created, what is reused, what could not be
staged, and the passage each point came from. They say build; then you write exactly that.

Use `atlas-proposal` (internal, in `atlas-tools`). It takes the points/paths/views you composed and
produces the proposal document as one self-contained HTML file, with no Atlas checkout and no
dependencies, so it works from any session. Skip it only when the change is a one-off edit to a
single existing point that is trivially reversible.

## Building from documents

When the source of the model is a document (a PDF, a spreadsheet, an SOP) rather than a
conversation, invoke `atlas-doc-ingest` BEFORE writing anything. Attaching the file and
citing it has an ordering requirement with no error message: citations written before the
file finishes indexing are verified against empty text and silently stripped, while the
write still reports success.

## After the write: QA

Once the build or edit is done, invoke `atlas-auditing`. It runs a fixed set of read-only Cypher checks that surface
violations of all three principles above. The output is a scorecard with proposed fixes. The audit
does not mutate.

---

## When to read a reference

The three principles above (with their inline anti-pattern examples) are enough for most modeling
decisions, and they are **always** here, so you never have to invoke a separate skill to have them.
Read a file in `references/` only when you need the full worked example for a specific call:

- You're stuck on a specific decision and need the full pattern + worked examples
- You're authoring a doc that needs the rule cited
- You're proposing an Atlas-language extension and need the precedent
- The audit flagged a specific violation and you want the fix recipe

## Structuring a new atlas

**NEVER create folders before checking what exists.** A new atlas
auto-provisions the six default folders (People, Entities, Business Model, Process, Systems, Metrics),
possibly with a short allocation delay after `create_atlas`. Creating your own "People"/"Process"/etc.
produces a DUPLICATE set alongside the empty defaults. Rule: after `create_atlas` and before any
folder/view work, call `get_view_hierarchy` (retry once after a pause if empty) and file views INTO
the existing default folders. Create a folder only when it genuinely does not exist in the hierarchy.
More generally: check what is there first before creating any container -- same principle as point dedupe.

When you're organizing (not just typing) an atlas — deciding which folder a view belongs in, or
setting up a new atlas — use the **Default atlas structure** section of the `atlas-language` skill.
It maps the six default folders (People, Entities, Business Model, Process, Systems, Metrics) to
their point types, path types, and example maps, plus the 1-2 word view-naming convention.

## Discipline for new patterns

If during this work you discover a pattern that doesn't fit any of the three principles cleanly,
don't create a new top-level skill; add it as an example under the closest existing principle.

**Reference:** the repo README for the principle-grouped
index.
