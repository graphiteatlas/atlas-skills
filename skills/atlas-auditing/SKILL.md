---
name: atlas-auditing
description: Use when asked to audit, review, QA, or health-check a Graphite Atlas, or before signing off on a process build, or when inheriting an atlas copied from production. Runs a fixed set of read-only Cypher checks that detect violations of the Atlas modeling patterns (dependencies at the wrong level, resources pointing at artifacts or vendors, orphaned step membership, steps with no performer, system/vendor names baked into nodes, overloaded part_of, orphan Data Tables, execution-mode contradictions). Reports findings; does not mutate.
---

# Atlas Audit

**Principle:** A handful of read-only Cypher checks catch the most common modeling violations. Run them, report findings per check, then propose fixes (don't mutate as part of the audit).

**When this applies:** "audit / review / QA this atlas", before sign-off on a build, or when inheriting production-copied content.

**The graph checks are half the audit.** Views and folders live outside the graph,
and their rules are in `atlas-modeling` 2a: one connected flow per view, view and
folder names of one or two words, a folder per process with its Overview first, the
folder tree mirroring the process tree, no empty or unfiled views, and size limits.
Checks 13 to 18 below cover them.

**Score the change before you write it, not only after.** A proposed revision can
be checked against the same rules while it is still a proposal, and a revision that
scores worse than the atlas it replaces is a failed check, not a note.

**Rules for every query:** scope to the atlas (`{atlasId: $atlasId}`), read-only (MATCH/RETURN only), and count only **live** points and paths. Path type is in `r.name`; relationships use the `:PATH` label.

**Live** means not deleted and not retired, for every point and every path a query touches, including the ones inside `EXISTS { }`:

    x.deletedAt IS NULL AND coalesce(x.model_status,'') <> 'superseded'
      AND NOT coalesce(x.properties,'') CONTAINS '"model_status":"superseded"'

Retired work keeps its rows (`model_status: superseded`, with a reason and a date), so a check that
filters only `deletedAt` reports retired work as a live defect, or counts a retired path as the one
that makes something whole. Older retirements sit in the `properties` string rather than the field,
hence the third clause. On one large atlas the unfiltered checks reported 90 unconditional forks
where 46 were live, and two execution-mode contradictions that were both retired performers.

One database quirk: filter the far end of an `EXISTS` pattern by writing the pattern from the outer
variable, `(s)<-[f:PATH {name:'performs'}]-(a)`, not `(a:Point)-[f...]->(s)`; the second form errors.

### 1. Dependency at the wrong level (Pattern 3) — process-level uses_resource
```cypher
MATCH (p:Point {atlasId:$atlasId, type:'Process'})-[r:PATH {name:'uses_resource'}]->(sys:Point)
WHERE p.deletedAt IS NULL AND coalesce(p.model_status,'') <> 'superseded' AND NOT coalesce(p.properties,'') CONTAINS '"model_status":"superseded"' AND sys.deletedAt IS NULL AND coalesce(sys.model_status,'') <> 'superseded' AND NOT coalesce(sys.properties,'') CONTAINS '"model_status":"superseded"' AND r.deletedAt IS NULL AND coalesce(r.model_status,'') <> 'superseded' AND NOT coalesce(r.properties,'') CONTAINS '"model_status":"superseded"'
RETURN p.name AS process, sys.name AS resource
```
Violation = a process carrying a resource edge that belongs on a leaf step. Fix: move to the step that uses it; let the process derive by rollup.

### 2. Wrong resource target (Pattern 3) — uses_resource to a non-System
```cypher
MATCH (s:Point {atlasId:$atlasId})-[r:PATH {name:'uses_resource'}]->(t:Point)
WHERE s.deletedAt IS NULL AND coalesce(s.model_status,'') <> 'superseded' AND NOT coalesce(s.properties,'') CONTAINS '"model_status":"superseded"' AND t.deletedAt IS NULL AND coalesce(t.model_status,'') <> 'superseded' AND NOT coalesce(t.properties,'') CONTAINS '"model_status":"superseded"' AND r.deletedAt IS NULL AND coalesce(r.model_status,'') <> 'superseded' AND NOT coalesce(r.properties,'') CONTAINS '"model_status":"superseded"' AND NOT t.type IN ['System','Equipment']
RETURN s.name AS step, t.name AS target, t.type AS target_type
```
Violation = `uses_resource` pointing at an Artifact (use `needs_input`) or a Vendor (use the service-as-System pattern). 

### 3. Step → Vendor (Pattern 4)
```cypher
MATCH (s:Point {atlasId:$atlasId})-[r:PATH]->(v:Point {type:'Vendor'})
WHERE s.deletedAt IS NULL AND coalesce(s.model_status,'') <> 'superseded' AND NOT coalesce(s.properties,'') CONTAINS '"model_status":"superseded"' AND v.deletedAt IS NULL AND coalesce(v.model_status,'') <> 'superseded' AND NOT coalesce(v.properties,'') CONTAINS '"model_status":"superseded"' AND r.deletedAt IS NULL AND coalesce(r.model_status,'') <> 'superseded' AND NOT coalesce(r.properties,'') CONTAINS '"model_status":"superseded"' AND r.name <> 'provided_by'
RETURN s.name AS source, r.name AS rel, v.name AS vendor
```
Violation = work pointing at a company. Fix: insert a Service (System) `provided_by` the Vendor.

### 4. part_of used for provision (Pattern 4)
```cypher
MATCH (s:Point {atlasId:$atlasId, type:'System'})-[r:PATH {name:'part_of'}]->(v:Point {type:'Vendor'})
WHERE s.deletedAt IS NULL AND coalesce(s.model_status,'') <> 'superseded' AND NOT coalesce(s.properties,'') CONTAINS '"model_status":"superseded"' AND v.deletedAt IS NULL AND coalesce(v.model_status,'') <> 'superseded' AND NOT coalesce(v.properties,'') CONTAINS '"model_status":"superseded"' AND r.deletedAt IS NULL AND coalesce(r.model_status,'') <> 'superseded' AND NOT coalesce(r.properties,'') CONTAINS '"model_status":"superseded"'
RETURN s.name AS system, v.name AS vendor
```
Violation = mereological overload. Fix: replace with `provided_by`.

### 5. Incomplete has_step membership (rule #10)
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review','Handoff'] AND s.deletedAt IS NULL AND coalesce(s.model_status,'') <> 'superseded' AND NOT coalesce(s.properties,'') CONTAINS '"model_status":"superseded"'
  AND EXISTS { MATCH (s)-[f:PATH]-(o:Point) WHERE f.name IN ['followed_by','followed_by_if'] AND f.deletedAt IS NULL AND coalesce(f.model_status,'') <> 'superseded' AND NOT coalesce(f.properties,'') CONTAINS '"model_status":"superseded"' AND o.deletedAt IS NULL AND coalesce(o.model_status,'') <> 'superseded' AND NOT coalesce(o.properties,'') CONTAINS '"model_status":"superseded"' }
  AND NOT EXISTS { MATCH (p:Point {type:'Process'})-[m:PATH {name:'has_step'}]->(s) WHERE m.deletedAt IS NULL AND coalesce(m.model_status,'') <> 'superseded' AND NOT coalesce(m.properties,'') CONTAINS '"model_status":"superseded"' AND p.deletedAt IS NULL AND coalesce(p.model_status,'') <> 'superseded' AND NOT coalesce(p.properties,'') CONTAINS '"model_status":"superseded"' }
RETURN s.name AS sequenced_but_not_member
```
Violation = a sequenced step with no `has_step` parent. Fix: add `has_step` from its owning process.

### 6. Steps with no performer (accountability)
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review'] AND s.deletedAt IS NULL AND coalesce(s.model_status,'') <> 'superseded' AND NOT coalesce(s.properties,'') CONTAINS '"model_status":"superseded"'
  AND NOT EXISTS { MATCH (s)<-[f:PATH {name:'performs'}]-(a) WHERE f.deletedAt IS NULL AND coalesce(f.model_status,'') <> 'superseded' AND NOT coalesce(f.properties,'') CONTAINS '"model_status":"superseded"' AND a.deletedAt IS NULL AND coalesce(a.model_status,'') <> 'superseded' AND NOT coalesce(a.properties,'') CONTAINS '"model_status":"superseded"' }
RETURN s.name AS step_without_performer
```
Violation = atomic work with no owner. Fix: add `performs` from the responsible Position (Decisions may legitimately have none — use judgment).

### 7. System/vendor token baked into a node name (Pattern 6)
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.deletedAt IS NULL AND coalesce(s.model_status,'') <> 'superseded' AND NOT coalesce(s.properties,'') CONTAINS '"model_status":"superseded"' AND s.type IN ['Step','Decision','Approval','Review','Handoff']
WITH s, [w IN ['SAP','Oracle','NetSuite','Salesforce','SharePoint','QuickBooks'] WHERE s.name CONTAINS w] AS hits
WHERE size(hits) > 0
RETURN s.name AS node, hits AS tokens
```
(Adjust the token list per atlas.) Violation = a name encoding identity that lives on an edge. Fix: rename by function; reach the specific via the path.

### 8a. Orphaned action nodes (no membership)
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review','Handoff'] AND s.deletedAt IS NULL AND coalesce(s.model_status,'') <> 'superseded' AND NOT coalesce(s.properties,'') CONTAINS '"model_status":"superseded"'
  AND NOT EXISTS { MATCH (s)-[f:PATH]-(o:Point) WHERE f.name = 'has_step' AND f.deletedAt IS NULL AND coalesce(f.model_status,'') <> 'superseded' AND NOT coalesce(f.properties,'') CONTAINS '"model_status":"superseded"' AND o.deletedAt IS NULL AND coalesce(o.model_status,'') <> 'superseded' AND NOT coalesce(o.properties,'') CONTAINS '"model_status":"superseded"' }
RETURN s.name AS no_membership
```
Violation = an action that belongs to no process. Fix: attach `has_step` membership (or confirm it is genuinely standalone).

### 8b. Unsequenced action nodes (membership but no flow)
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review','Handoff'] AND s.deletedAt IS NULL AND coalesce(s.model_status,'') <> 'superseded' AND NOT coalesce(s.properties,'') CONTAINS '"model_status":"superseded"'
  AND EXISTS { MATCH (s)-[m:PATH]-(o:Point) WHERE m.name = 'has_step' AND m.deletedAt IS NULL AND coalesce(m.model_status,'') <> 'superseded' AND NOT coalesce(m.properties,'') CONTAINS '"model_status":"superseded"' AND o.deletedAt IS NULL AND coalesce(o.model_status,'') <> 'superseded' AND NOT coalesce(o.properties,'') CONTAINS '"model_status":"superseded"' }
  AND NOT EXISTS { MATCH (s)-[f:PATH]-(o2:Point) WHERE f.name IN ['followed_by','followed_by_if'] AND f.deletedAt IS NULL AND coalesce(f.model_status,'') <> 'superseded' AND NOT coalesce(f.properties,'') CONTAINS '"model_status":"superseded"' AND o2.deletedAt IS NULL AND coalesce(o2.model_status,'') <> 'superseded' AND NOT coalesce(o2.properties,'') CONTAINS '"model_status":"superseded"' }
RETURN s.name AS unsequenced_action
```
Violation = a step that is IN a process but wired into no sequence — it passes naive isolation checks while being orphaned from the flow (found live in the Payment Operations build, 7/14: `has_step` present, zero `followed_by` on either side, invisible to the old combined check). Fix: sequence it, or confirm it is a true any-time step (some checklist-style processes have them — judgment call, not auto-fail).

### 9. Unconditional multi-branch (parallel vs mis-modeled choice)
```cypher
MATCH (s:Point {atlasId:$atlasId})-[r:PATH {name:'followed_by'}]->(t:Point)
WHERE s.deletedAt IS NULL AND coalesce(s.model_status,'') <> 'superseded' AND NOT coalesce(s.properties,'') CONTAINS '"model_status":"superseded"' AND t.deletedAt IS NULL AND coalesce(t.model_status,'') <> 'superseded' AND NOT coalesce(t.properties,'') CONTAINS '"model_status":"superseded"' AND r.deletedAt IS NULL AND coalesce(r.model_status,'') <> 'superseded' AND NOT coalesce(r.properties,'') CONTAINS '"model_status":"superseded"'
WITH s, count(DISTINCT t) AS successors, collect(DISTINCT t.name) AS targets
WHERE successors > 1
RETURN s.name AS step, targets
```
Violation = a node with 2+ **unconditional** `followed_by` successors, which reads as a parallel fork (all branches happen). Almost always a mis-modeled choice; convert each branch to `followed_by_if` with a `condition`. Genuine parallel forks are rare — confirm intent before leaving as-is. (Related: a Process whose children are concurrent should carry `ordering: parallel`; see Patterns / rule #12.)

### 10. Message-type masquerading as System (Artifact-vs-System rule)
```cypher
MATCH (s:Point {atlasId:$atlasId, type:'System'}) WHERE s.deletedAt IS NULL AND coalesce(s.model_status,'') <> 'superseded' AND NOT coalesce(s.properties,'') CONTAINS '"model_status":"superseded"'
WITH s, [w IN ['EDI ','NACHA','HL7',' Form',' Letter',' Report',' File',' Message','1099','W-9','W-2','K-1','Schedule K'] WHERE toUpper(s.name) CONTAINS toUpper(w)] AS hits
WHERE size(hits) > 0
RETURN s.name AS suspect_system, hits AS tokens
```
Violation = a Point typed `System` whose name reads like a document or message type (EDI X12 codes, NACHA file, HL7 message, named forms). Fix: re-type as `Artifact` and swap incoming `uses_resource` edges to `creates_output` (sender side) or `needs_input` (receiver side). See `atlas-modeling` → `references/artifact-vs-system.md`.

### 11. Orphan Data Tables (no has_table parent)
```cypher
MATCH (t:Point {atlasId:$atlasId, type:'Data Table'})
WHERE t.deletedAt IS NULL AND coalesce(t.model_status,'') <> 'superseded' AND NOT coalesce(t.properties,'') CONTAINS '"model_status":"superseded"'
  AND NOT EXISTS { MATCH (d:Point {type:'Database'})-[h:PATH {name:'has_table'}]->(t) WHERE h.deletedAt IS NULL AND coalesce(h.model_status,'') <> 'superseded' AND NOT coalesce(h.properties,'') CONTAINS '"model_status":"superseded"' AND d.deletedAt IS NULL AND coalesce(d.model_status,'') <> 'superseded' AND NOT coalesce(d.properties,'') CONTAINS '"model_status":"superseded"' }
RETURN t.name AS orphan_table
```
Violation = a Data Table with no owning Database — "which store is this in?" is unanswerable, and `joins_to` guidance loses its anchor. Fix: add `has_table` from the Database that holds it (`has_table` is strictly Database → Data Table; if the intended parent is typed `System`, re-type it `Database` first).

### 12. System-executed steps with a human performer (execution_mode contradiction)
```cypher
MATCH (a:Point)-[r:PATH {name:'performs'}]->(s:Point {atlasId:$atlasId})
WHERE s.deletedAt IS NULL AND coalesce(s.model_status,'') <> 'superseded' AND NOT coalesce(s.properties,'') CONTAINS '"model_status":"superseded"' AND a.deletedAt IS NULL AND coalesce(a.model_status,'') <> 'superseded' AND NOT coalesce(a.properties,'') CONTAINS '"model_status":"superseded"' AND r.deletedAt IS NULL AND coalesce(r.model_status,'') <> 'superseded' AND NOT coalesce(r.properties,'') CONTAINS '"model_status":"superseded"'
  AND s.execution_mode = 'system'
  AND a.type IN ['Person','Position','Group']
RETURN s.name AS step, a.name AS performer, a.type AS performer_type
```
Violation = a step marked `execution_mode: 'system'` (runs without a human) that also has a Person/Position/Group `performs` edge — the two claims contradict. Fix: either the mode is wrong (a human does perform it → `human`) or the performer is wrong (remove the edge, or point it at the Agent/System actor that actually executes). An `Agent` performer is consistent with `system` and is not flagged.

**Output:** a short scorecard (one line per check: pass / N findings), then the findings, then proposed fixes. Confirm before mutating.

---

### 13. Fragmented flow views (more than one connected component)

Views live outside the graph, so this is a per-view check, not one Cypher query.

Besides fragments, look for **hand-offs OUT and IN**: sequence paths that leave the
view, or enter it, from a card that is not on the canvas. Those read as orphans on
screen even when the view is one component, so they are findings too; show the
neighbour's card as an entry or exit box, per `atlas-modeling` 2a.

**By hand:** for each flow view (`list_views`, then `get_view_points`), take its actions
(Step, Decision, Approval, Review, Handoff) and the `followed_by` / `followed_by_if` paths between
them, and count connected components (ignore direction; `mage_connected_components` on the subgraph,
or a union-find over the pairs). Then list sequence paths whose other end is not in the view.

Violation = a flow view with more than one component, or with an isolated action. Report each
fragment with its first and last action. Fix: see atlas-modeling 2a, "One connected flow per view":
missing sequence, parallel work, or two processes in one view. Never invent a sequence to pass the
check. Inventory views (Org, Systems, Artifacts) are exempt.

### 14. Near-duplicate actions (the usual cause of check 13)

A fragmented view is most often not a missing link but a **duplicated step**: a continuation symbol in
the source diagram (Visio's off-page connector, "home plate", a "go to page 3" box) modeled as a second
copy of the step instead of a join. Each copy heads its own chain, so one flow draws as two.

```cypher
MATCH (a:Point), (b:Point)
WHERE a.atlasId=$atlasId AND b.atlasId=$atlasId AND a.deletedAt IS NULL AND coalesce(a.model_status,'') <> 'superseded' AND NOT coalesce(a.properties,'') CONTAINS '"model_status":"superseded"' AND b.deletedAt IS NULL AND coalesce(b.model_status,'') <> 'superseded' AND NOT coalesce(b.properties,'') CONTAINS '"model_status":"superseded"'
  AND a.type IN ['Step','Decision','Approval','Review','Handoff'] AND a.type = b.type AND a.id < b.id
WITH a, b,
  trim(toLower(split(a.name,' (')[0])) AS na, trim(toLower(split(b.name,' (')[0])) AS nb
WHERE na = nb
RETURN a.name AS first, b.name AS second
```

It catches case differences ("Are repairs Satisfactory?" / "Are repairs satisfactory?") and a
parenthetical suffix added to disambiguate ("Receive 92051 Inspection and Invoice (Repair Completion)").
Violation = a pair that is the same action in the same flow. Fix: merge, keeping every incoming and
outgoing path. **Not** a violation when the two are genuinely separate instances in different flows:
actions are per-flow instances (atlas-modeling, instance nodes), so check membership before merging.

### 15. Process size (a process that should be decomposed)

```cypher
MATCH (p:Point {atlasId:$atlasId, type:'Process'})-[r:PATH {name:'has_step'}]->(s:Point)
WHERE p.deletedAt IS NULL AND s.deletedAt IS NULL
  AND s.type IN ['Step','Decision','Approval','Review','Handoff']
  AND coalesce(r.model_status, '') <> 'superseded'
WITH p, count(s) AS steps
WHERE steps >= 13
RETURN p.name AS process, steps ORDER BY steps DESC
```

Violation = 16 or more direct steps (warn from 13). For a parent Process, count its sub-processes
plus its direct steps as phases: 3 to 9 passes, 16 or more fails. A sub-process under 4 steps is too
fine unless the business names it or it is an any-order box. Fix: decompose by the cut rules in
atlas-modeling 2a (`references/large-process-decomposition.md`). The trigger is the process, not
the view: a 40-step process spread over three views still fails.

### 16. Single entry, single exit (a sub-process cut in the wrong place)

For each sequential sub-process (a Process that has a parent Process and no `ordering: any`), take
its direct steps and the sequence paths between them. **Entries** are steps no step inside
precedes; **exits** are steps no step inside follows.

Violation = more than two entries or more than two exits (two is a warning: a parallel start or
end). An exit that leads nowhere at all is usually a missing `followed_by`, not a bad cut: ask what
happens next before moving the boundary. Any-order boxes are exempt; their entry is the box.

### 17. A rework loop crossing a sub-process edge

Compute strongly connected components over the live sequence paths between actions
(`followed_by`, `followed_by_if`); any component with two or more actions is a loop. Violation = a
loop whose actions belong to more than one sub-process. A loop is one piece of work repeated, so the
cut goes around it, never through it. A conditional loop inside one sub-process is correct modelling,
not a finding.

### 18. Fan-out that should be an any-order box

```cypher
MATCH (s:Point {atlasId:$atlasId})-[r:PATH {name:'followed_by'}]->(t:Point)
WHERE s.deletedAt IS NULL AND t.deletedAt IS NULL AND coalesce(r.model_status, '') <> 'superseded'
WITH s, collect(t) AS ts WHERE size(ts) >= 5
WHERE NONE(a IN ts WHERE EXISTS { MATCH (a)-[q:PATH]->(b) WHERE q.name IN ['followed_by','followed_by_if'] AND b IN ts })
RETURN s.name AS step, [t IN ts | t.name] AS unordered_successors
```

Violation = one step pointing to five or more steps with no order among them. They are an any-order
set: put them in a Process with `ordering: any`, point the step at that box once, and retire the
individual arrows. Fewer branches are check 9's question (parallel or a mis-modelled choice).

**Reading retired facts:** a retired path carries `model_status: superseded`. Depending on when it was
retired, that sits natively on the relationship or inside its `properties` text. Filter on both, or
retired paths count as live. The queries above check the native field; add
`AND NOT coalesce(r.properties, '') CONTAINS '"model_status":"superseded"'` for older data.

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

