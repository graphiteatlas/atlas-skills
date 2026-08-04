---
name: atlas-auditing
description: Use when asked to audit, review, QA, or health-check a Graphite Atlas, or before signing off on a process build, or when inheriting an atlas copied from production. Runs a fixed set of read-only Cypher checks that detect violations of the Atlas modeling patterns (dependencies at the wrong level, resources pointing at artifacts or vendors, orphaned step membership, steps with no performer, system/vendor names baked into nodes, overloaded part_of). Reports findings; does not mutate.
---

# Atlas Audit

**Principle:** A handful of read-only Cypher checks catch the most common modeling violations. Run them, report findings per check, then propose fixes (don't mutate as part of the audit).

**When this applies:** "audit / review / QA this atlas", before sign-off on a build, or when inheriting production-copied content.

**Rules for every query:** scope to the atlas (`{atlasId: $atlasId}`), exclude deleted (`deletedAt IS NULL`), read-only (MATCH/RETURN only). Path type is in `r.name`; relationships use the `:PATH` label.

### 1. Dependency at the wrong level (Pattern 3) — process-level uses_resource
```cypher
MATCH (p:Point {atlasId:$atlasId, type:'Process'})-[:PATH {name:'uses_resource'}]->(sys:Point)
WHERE p.deletedAt IS NULL AND sys.deletedAt IS NULL
RETURN p.name AS process, sys.name AS resource
```
Violation = a process carrying a resource edge that belongs on a leaf step. Fix: move to the step that uses it; let the process derive by rollup.

### 2. Wrong resource target (Pattern 3) — uses_resource to a non-System
```cypher
MATCH (s:Point {atlasId:$atlasId})-[:PATH {name:'uses_resource'}]->(t:Point)
WHERE s.deletedAt IS NULL AND t.deletedAt IS NULL AND NOT t.type IN ['System','Equipment','Transport']
RETURN s.name AS step, t.name AS target, t.type AS target_type
```
Violation = `uses_resource` pointing at an Artifact (use `needs_input`) or a Vendor (use the service-as-System pattern). 

### 3. Step → Vendor (Pattern 4)
```cypher
MATCH (s:Point {atlasId:$atlasId})-[r:PATH]->(v:Point {type:'Vendor'})
WHERE s.deletedAt IS NULL AND v.deletedAt IS NULL AND r.name <> 'provided_by'
RETURN s.name AS source, r.name AS rel, v.name AS vendor
```
Violation = work pointing at a company. Fix: insert a Service (System) `provided_by` the Vendor.

### 4. part_of used for provision (Pattern 4)
```cypher
MATCH (s:Point {atlasId:$atlasId, type:'System'})-[:PATH {name:'part_of'}]->(v:Point {type:'Vendor'})
WHERE s.deletedAt IS NULL AND v.deletedAt IS NULL
RETURN s.name AS system, v.name AS vendor
```
Violation = mereological overload. Fix: replace with `provided_by`.

### 5. Incomplete has_step membership (rule #10)
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review','Handoff'] AND s.deletedAt IS NULL
  AND EXISTS { MATCH (s)-[f:PATH]-() WHERE f.name IN ['followed_by','followed_by_if'] }
  AND NOT EXISTS { MATCH (:Point {type:'Process'})-[:PATH {name:'has_step'}]->(s) }
RETURN s.name AS sequenced_but_not_member
```
Violation = a sequenced step with no `has_step` parent. Fix: add `has_step` from its owning process.

### 6. Steps with no performer (accountability)
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review'] AND s.deletedAt IS NULL
  AND NOT EXISTS { MATCH (:Point)-[:PATH {name:'performs'}]->(s) }
RETURN s.name AS step_without_performer
```
Violation = atomic work with no owner. Fix: add `performs` from the responsible Position (Decisions may legitimately have none — use judgment).

### 7. System/vendor token baked into a node name (Pattern 6)
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.deletedAt IS NULL AND s.type IN ['Step','Decision','Approval','Review','Handoff']
WITH s, [w IN ['SAP','Oracle','NetSuite','Salesforce','SharePoint','QuickBooks'] WHERE s.name CONTAINS w] AS hits
WHERE size(hits) > 0
RETURN s.name AS node, hits AS tokens
```
(Adjust the token list per atlas.) Violation = a name encoding identity that lives on an edge. Fix: rename by function; reach the specific via the path.

### 8a. Orphaned action nodes (no membership)
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review','Handoff'] AND s.deletedAt IS NULL
  AND NOT EXISTS { MATCH (s)-[f:PATH]-() WHERE f.name = 'has_step' }
RETURN s.name AS no_membership
```
Violation = an action that belongs to no process. Fix: attach `has_step` membership (or confirm it is genuinely standalone).

### 8b. Unsequenced action nodes (membership but no flow)
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review','Handoff'] AND s.deletedAt IS NULL
  AND EXISTS { MATCH (s)-[m:PATH]-() WHERE m.name = 'has_step' }
  AND NOT EXISTS { MATCH (s)-[f:PATH]-() WHERE f.name IN ['followed_by','followed_by_if'] }
RETURN s.name AS unsequenced_action
```
Violation = a step that is IN a process but wired into no sequence — it passes naive isolation checks while being orphaned from the flow (found live in the Payment Operations build, 7/14: `has_step` present, zero `followed_by` on either side, invisible to the old combined check). Fix: sequence it, or confirm it is a true any-time step (some checklist-style processes have them — judgment call, not auto-fail).

### 9. Unconditional multi-branch (parallel vs mis-modeled choice)
```cypher
MATCH (s:Point {atlasId:$atlasId})-[:PATH {name:'followed_by'}]->(t:Point)
WHERE s.deletedAt IS NULL AND t.deletedAt IS NULL
WITH s, count(DISTINCT t) AS successors, collect(DISTINCT t.name) AS targets
WHERE successors > 1
RETURN s.name AS step, targets
```
Violation = a node with 2+ **unconditional** `followed_by` successors, which reads as a parallel fork (all branches happen). Almost always a mis-modeled choice; convert each branch to `followed_by_if` with a `condition`. Genuine parallel forks are rare — confirm intent before leaving as-is. (Related: a Process whose children are concurrent should carry `ordering: parallel`; see Patterns / rule #12.)

### 10. Message-type masquerading as System (Artifact-vs-System rule)
```cypher
MATCH (s:Point {atlasId:$atlasId, type:'System'}) WHERE s.deletedAt IS NULL
WITH s, [w IN ['EDI ','NACHA','HL7',' Form',' Letter',' Report',' File',' Message','1099','W-9','W-2','K-1','Schedule K'] WHERE toUpper(s.name) CONTAINS toUpper(w)] AS hits
WHERE size(hits) > 0
RETURN s.name AS suspect_system, hits AS tokens
```
Violation = a Point typed `System` whose name reads like a document or message type (EDI X12 codes, NACHA file, HL7 message, named forms). Fix: re-type as `Artifact` and swap incoming `uses_resource` edges to `creates_output` (sender side) or `needs_input` (receiver side). See `atlas-artifact-vs-system`.

**Output:** a short scorecard (one line per check: pass / N findings), then the findings, then proposed fixes. Confirm before mutating.

**Reference:** `nav-claude-code-demo/atlas-patterns.md` (Patterns 1-6) and `atlas-rules-gaps.md`.
