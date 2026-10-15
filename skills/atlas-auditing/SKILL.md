---
name: atlas-auditing
description: Use when asked to audit, review, QA, or health-check a Graphite Atlas, or before signing off on a process build, or when inheriting an atlas copied from production. Runs a fixed set of read-only checks, through run_audit and the read tools, that detect violations of the Atlas modeling patterns (dependencies at the wrong level, resources pointing at artifacts or vendors, orphaned step membership, steps with no performer, system/vendor names baked into nodes, overloaded part_of, orphan Data Tables, execution-mode contradictions). Reports findings; does not mutate.
---

# Atlas Audit

**Principle:** A handful of read-only checks catch the most common modeling violations. Run them, report findings per check, then propose fixes (don't mutate as part of the audit).

**When this applies:** "audit / review / QA this atlas", before sign-off on a build, or when inheriting production-copied content.

**The graph checks are half the audit.** Views and folders live outside the graph,
and their rules are in `atlas-modeling` 2a: one connected flow per view, view and
folder names of one or two words, a folder per process with its Overview first, the
folder tree mirroring the process tree, no empty or unfiled views, and size limits.
Checks 13 to 18 below cover them.

**Score the change before you write it, not only after.** A proposed revision can
be checked against the same rules while it is still a proposal, and a revision that
scores worse than the atlas it replaces is a failed check, not a note.

## Reading the atlas

Every check uses read-only tools. Four moves cover most of them:

- **`run_audit`** runs Atlas's structural checks in one call: `unperformed_actions`,
  `sequenced_outside_process`, `isolated_points`, `duplicates`, `outcomes_without_metric`,
  `unowned_processes`, `dead_end_actions`, `orphaned_actions`, `processes_without_outcome`,
  `actions_without_resource`. Omit `check` to run them all. Each report gives `count` and up to
  `limit` findings (default 50, maximum 1000; `truncated` says there were more). Its **actions** are
  Step and every type that inherits from it: Decision, Approval, Review, Handoff.
- **`run_audit` with `path_types`** sees only those path types, which makes `isolated_points` a
  general absence test: with `path_types: ["has_table"]` it returns every point with no `has_table`
  path in either direction. Keep the findings of the type the check is about.
- **`search_paths`** with a path type as the query (`"uses_resource"`) returns every path of that
  type: source and target ids and names, and the path's properties. It matches substrings, so
  `"followed_by"` also returns `followed_by_if`; filter on `type`.
- **The type map.** `search_paths` carries no point types. Build an id-to-type map once with
  `list_points` (id, name and type of every point). If its answer is partial, call `search_points`
  with each type name instead; it matches names too, so filter on `type`. `search_points` also
  returns each point's properties.

Join and count in your own reasoning. One call per path type plus one type map covers the whole
atlas at any size; never loop a call per point when one list answers the check.

**With AtlasQL.** On a deployment that runs AtlasQL, `query_atlas` (read `describe_schema` first)
answers each check as one SQL query over the `points` and `paths` tables. Elsewhere `query_atlas`
answers `available: false`, and the procedures below run on every deployment.

**Count only live work.** Deleted points and paths never reach these tools; retired ones can. An
atlas that retires by status keeps the row, with `model_status: superseded`, a reason and a date in
its properties, and `run_audit` counts it as live. Drop retired paths from `search_paths` results,
and read a finding's properties (`search_points` or `get_point`) before reporting it. Without this
filter a check reports retired work as a live defect, or counts a retired path as the one that makes
something whole. On one large atlas the unfiltered checks reported 90 unconditional forks where 46
were live, and two execution-mode contradictions that were both retired performers.

### 1. Dependency at the wrong level (Pattern 3): process-level uses_resource
`search_paths` with `"uses_resource"`; keep the paths whose source is a `Process`. Report the process
and the resource.

Violation = a process carrying a resource edge that belongs on a leaf step. Fix: move to the step that uses it; let the process derive by rollup.

### 2. Wrong resource target (Pattern 3): uses_resource to a non-System
From the same `uses_resource` list, keep the paths whose target is neither `System` nor `Equipment`.
Report the step, the target and the target's type.

Violation = `uses_resource` pointing at an Artifact (use `needs_input`) or a Vendor (use the service-as-System pattern).

### 3. Step to Vendor (Pattern 4)
`search_points` with `"Vendor"` lists the vendors. For each, `traverse` with `direction: "in"` and
`depth: 1` returns every path into it. Flag every path whose type is not `provided_by`, with its
source. Vendors are few, so one call each is cheap.

Violation = work pointing at a company. Fix: insert a Service (System) `provided_by` the Vendor.

### 4. part_of used for provision (Pattern 4)
`search_paths` with `"part_of"`; keep the paths from a `System` to a `Vendor`. Check 3's traversals
show them too.

Violation = mereological overload. Fix: replace with `provided_by`.

### 5. Incomplete has_step membership (rule #10)
`run_audit` with `check: "sequenced_outside_process"`: every action in a `followed_by` or
`followed_by_if` sequence, at either end, that no Process has as a step.

Violation = a sequenced step with no `has_step` parent. Fix: add `has_step` from its owning process.

### 6. Steps with no performer (accountability)
`run_audit` with `check: "unperformed_actions"`: every action with no `performs` path into it. The
check covers Step, Decision, Approval and Review; a Handoff finding is out of scope, since a Handoff
names its actors with `from_actor` and `to_actor`.

Violation = atomic work with no owner. Fix: add `performs` from the responsible Position (Decisions may legitimately have none: use judgment).

### 7. System/vendor token baked into a node name (Pattern 6)
`search_points` once per token (`"SAP"`, `"Oracle"`, `"NetSuite"`, `"Salesforce"`, `"SharePoint"`,
`"QuickBooks"`); keep the actions (Step, Decision, Approval, Review, Handoff). Report each name with
its tokens.

(Adjust the token list per atlas.) Violation = a name encoding identity that lives on an edge. Fix: rename by function; reach the specific via the path.

### 8a. Orphaned action nodes (no membership)
`run_audit` with `check: "orphaned_actions"` and `path_types: ["has_step"]`: every action no
`has_step` path leads into.

Violation = an action that belongs to no process. Fix: attach `has_step` membership (or confirm it is genuinely standalone).

### 8b. Unsequenced action nodes (membership but no flow)
`run_audit` with `check: "isolated_points"` and `path_types: ["followed_by", "followed_by_if"]`;
keep the actions, then drop the ones 8a found. What remains is in a process but in no sequence.

Violation = a step that is IN a process but wired into no sequence: `has_step` present, zero `followed_by` on either side. It passes naive isolation checks while being orphaned from the flow. Fix: sequence it, or confirm it is a true any-time step (some checklist-style processes have them: judgment call, not auto-fail).

### 9. Unconditional multi-branch (parallel vs mis-modeled choice)
`search_paths` with `"followed_by"`; keep type `followed_by` exactly, group by source, and report
every source with two or more distinct targets, with the targets.

Violation = a node with 2+ **unconditional** `followed_by` successors, which reads as a parallel fork (all branches happen). Almost always a mis-modeled choice; convert each branch to `followed_by_if` with a `condition`. Genuine parallel forks are rare: confirm intent before leaving as-is. (Related: a Process whose children are concurrent should carry `ordering: parallel`; see Patterns / rule #12.)

### 10. Message-type masquerading as System (Artifact-vs-System rule)
`search_points` with `"System"`; keep type `System` and scan each name, ignoring case, for `EDI `,
`NACHA`, `HL7`, ` Form`, ` Letter`, ` Report`, ` File`, ` Message`, `1099`, `W-9`, `W-2`, `K-1`,
`Schedule K`. Report each hit with its tokens.

Violation = a Point typed `System` whose name reads like a document or message type (EDI X12 codes, NACHA file, HL7 message, named forms). Fix: re-type as `Artifact` and swap incoming `uses_resource` edges to `creates_output` (sender side) or `needs_input` (receiver side). See `atlas-modeling`, `references/artifact-vs-system.md`.

### 11. Orphan Data Tables (no has_table parent)
`run_audit` with `check: "isolated_points"` and `path_types: ["has_table"]`; keep type `Data Table`.

Violation = a Data Table with no owning Database: "which store is this in?" is unanswerable, and `joins_to` guidance loses its anchor. Fix: add `has_table` from the Database that holds it (`has_table` is strictly Database to Data Table; if the intended parent is typed `System`, re-type it `Database` first).

### 12. System-executed steps with a human performer (execution_mode contradiction)
`search_paths` with `"performs"`; keep the paths whose source is a `Person`, `Position` or `Group`.
For each distinct target, read `execution_mode` from its properties (`search_points` by the step's
type returns them; `get_point` reads one). Report every target whose mode is `system`, with the
performer and its type.

Violation = a step marked `execution_mode: 'system'` (runs without a human) that also has a Person/Position/Group `performs` edge: the two claims contradict. Fix: either the mode is wrong (a human does perform it, so `human`) or the performer is wrong (remove the edge, or point it at the Agent/System actor that actually executes). An `Agent` performer is consistent with `system` and is not flagged.

**Output:** a short scorecard (one line per check: pass / N findings), then the findings, then proposed fixes. Confirm before mutating.

---

### 13. Fragmented flow views (more than one connected component)

Views live outside the graph, so this is a per-view check, not one atlas-wide call.

Besides fragments, look for **hand-offs OUT and IN**: sequence paths that leave the
view, or enter it, from a card that is not on the canvas. Those read as orphans on
screen even when the view is one component, so they are findings too; show the
neighbour's card as an entry or exit box, per `atlas-modeling` 2a.

**Procedure:** fetch the sequence paths once (`search_paths` with `"followed_by"`, which returns
both types). For each flow view (`list_views`, then `get_view_points`), take its actions (Step,
Decision, Approval, Review, Handoff) and the sequence paths between them, and count connected
components (ignore direction; a union-find over the pairs). Then list sequence paths with one end in
the view and the other outside it.

Violation = a flow view with more than one component, or with an isolated action. Report each
fragment with its first and last action. Fix: see atlas-modeling 2a, "One connected flow per view":
missing sequence, parallel work, or two processes in one view. Never invent a sequence to pass the
check. Inventory views (Org, Systems, Artifacts) are exempt.

### 14. Near-duplicate actions (the usual cause of check 13)

A fragmented view is most often not a missing link but a **duplicated step**: a continuation symbol in
the source diagram (Visio's off-page connector, "home plate", a "go to page 3" box) modeled as a second
copy of the step instead of a join. Each copy heads its own chain, so one flow draws as two.

`run_audit` with `check: "duplicates"` returns every pair of one type whose names match once
normalized (case, punctuation, spacing) or reach a trigram similarity of 0.7; keep the action pairs.
A long parenthetical suffix can fall under that threshold, so also strip everything from ` (` in the
action names of the type map and compare what is left within each type.

Together they catch case differences ("Are repairs Satisfactory?" / "Are repairs satisfactory?") and a
parenthetical suffix added to disambiguate ("Receive 92051 Inspection and Invoice (Repair Completion)").
Violation = a pair that is the same action in the same flow. Fix: merge, keeping every incoming and
outgoing path. **Not** a violation when the two are genuinely separate instances in different flows:
actions are per-flow instances (atlas-modeling, instance nodes), so check membership before merging.

### 15. Process size (a process that should be decomposed)

`search_paths` with `"has_step"`; for each `Process` source, count the targets that are actions.
Report every process with 13 or more, largest first.

Violation = 16 or more direct steps (warn from 13). For a parent Process, count its sub-processes
plus its direct steps as phases: 3 to 9 passes, 16 or more fails. A sub-process under 4 steps is too
fine unless the business names it or it is an any-order box. Fix: decompose by the cut rules in
atlas-modeling 2a (`references/large-process-decomposition.md`). The trigger is the process, not
the view: a 40-step process spread over three views still fails.

### 16. Single entry, single exit (a sub-process cut in the wrong place)

For each sequential sub-process (a Process that has a parent Process and no `ordering: any`), take
its direct steps (from the `has_step` list) and the sequence paths between them (from the
`followed_by` list). **Entries** are steps no step inside precedes; **exits** are steps no step
inside follows.

Violation = more than two entries or more than two exits (two is a warning: a parallel start or
end). An exit that leads nowhere at all is usually a missing `followed_by`, not a bad cut: ask what
happens next before moving the boundary. Any-order boxes are exempt; their entry is the box.

### 17. A rework loop crossing a sub-process edge

Compute strongly connected components over the live sequence paths between actions
(`followed_by`, `followed_by_if`, from one `search_paths` call); any component with two or more
actions is a loop. Violation = a loop whose actions belong to more than one sub-process. A loop is one piece of work repeated, so the
cut goes around it, never through it. A conditional loop inside one sub-process is correct modelling,
not a finding.

### 18. Fan-out that should be an any-order box

From check 9's `followed_by` list, take every source with five or more targets. Report it when no
`followed_by` or `followed_by_if` path runs between any two of those targets.

Violation = one step pointing to five or more steps with no order among them. They are an any-order
set: put them in a Process with `ordering: any`, point the step at that box once, and retire the
individual arrows. Fewer branches are check 9's question (parallel or a mis-modelled choice).

## After the audit: the graph is not the deliverable

These checks end at the graph. They say nothing about whether a change reached the
document, map, book or site the reader actually sees.

**A renderer can assert a fact three ways:** from a property, from graph structure, or from
a hardcoded string selected on a point's name. Only the first two move when the graph
moves. The third is invisible to every check above, so a clean audit can sit behind an
output still printing a fact you just retired.

**So after any change a reader will see, grep the renderer for the rendered string, not
only for the property name, then regenerate and look at the output.** Retirement is the
case that bites: adding a fact usually fails loudly when it is missing, while retiring one
fails silently when a literal keeps printing it.

