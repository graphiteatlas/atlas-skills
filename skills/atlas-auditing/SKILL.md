---
name: atlas-auditing
description: Use when asked to audit, review, QA, or health-check a Graphite Atlas, or before signing off on a process build, or when inheriting an atlas copied from production. Runs a fixed set of read-only checks, the server's `run_audit` where it covers a check and a short script over the atlas export where it does not, that detect violations of the Atlas modeling patterns (dependencies at the wrong level, resources pointing at artifacts or vendors, orphaned step membership, steps with no performer, system/vendor names baked into nodes, overloaded part_of, orphan Data Tables, execution-mode contradictions). Reports findings; does not mutate.
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

## Running the checks

Every check names its source. There are two, both read-only.

**1. `run_audit` (MCP), where a check names a server check.** It runs on the server over the
live atlas. Omit `check` to run every server check in one call, or pass one name. A count of 0
is a pass; a failed call is an error, never a pass. When a report says `truncated`, raise `limit`
(up to 1000) before reading the findings as complete. The server's action set is Step plus every
subtype of it (Decision, Approval, Review, Handoff, and any custom subtype the atlas defines).

**2. The atlas export, for every other check.** One call returns every point, path and view, so
the whole audit is one download and a short script:

```bash
curl -s "https://graphiteatlas.com/api/atlas/$ATLAS_ID/export" \
  -H "Authorization: Bearer $GRAPHITE_ACCESS_TOKEN" -o atlas-export.json
```

The token is the one the MCP server uses. Points carry `id`, `name`, `type`, `description` and
`properties`; paths carry `name` (the path type), `displayName`, `source`, `target` and
`properties`; views carry `viewType`, `parentId` and `pointIds`. Load it once, and every check
below is a set operation over these helpers:

```python
import json
from collections import defaultdict

d = json.load(open("atlas-export.json"))["data"]
assert d["complete"], "partial export: do not score it"

def live(x): return (x.get("properties") or {}).get("model_status") != "superseded"
P = {p["id"]: p for p in d["points"] if live(p)}
E = [e for e in d["paths"] if live(e) and e["source"] in P and e["target"] in P]
OUT, IN = defaultdict(list), defaultdict(list)
for e in E: OUT[e["source"]].append(e); IN[e["target"]].append(e)

ACTIONS = {"Step", "Decision", "Approval", "Review", "Handoff"}
SEQ = ("followed_by", "followed_by_if")
def name(i): return P[i]["name"]
def typ(i): return P[i]["type"]
def prop(i, k): return (P[i].get("properties") or {}).get(k)
def of(*types): return [i for i in P if typ(i) in types]
def out(i, *t): return [e["target"] for e in OUT[i] if e["name"] in t]
def inn(i, *t): return [e["source"] for e in IN[i] if e["name"] in t]
def paths(t): return [e for e in E if e["name"] == t]
```

Add any custom subtype of Step the atlas defines to `ACTIONS`.

**Do not sweep with `list_points` or `list_paths`.** Each returns one page, so a path missing from
the page is not a path that is absent; compare the count returned with the totals in
`get_atlas_brief` and you will usually find the page is short. Use `get_node_neighborhood` to
confirm a single finding before you report it, not to sweep.

**AtlasQL.** Where `query_atlas` runs on your deployment, any export check can be one read-only
SQL query over the `points` and `paths` tables instead (`describe_schema` lists the columns).
Where it answers that AtlasQL is not configured, use the export.

**Count only live points and paths.** `run_audit` does. In the export, `live()` above drops
anything whose `properties` carry `model_status: superseded`, and `E` drops every path touching
a dropped point. Retired work keeps its rows (`model_status: superseded`, with a reason and a
date), so a check that skips this filter reports retired work as a live defect, or counts a
retired path as the one that makes something whole. On one large atlas the unfiltered checks
reported 90 unconditional forks where 46 were live, and two execution-mode contradictions that
were both retired performers.

### 1. Dependency at the wrong level (Pattern 3): process-level uses_resource
**Server:** none. **Export:**
```python
[(name(e["source"]), name(e["target"])) for e in paths("uses_resource") if typ(e["source"]) == "Process"]
```
Violation = a process carrying a resource edge that belongs on a leaf step. Fix: move to the step that uses it; let the process derive by rollup.

### 2. Wrong resource target (Pattern 3): uses_resource to a non-System
**Server:** none. **Export:**
```python
[(name(e["source"]), name(e["target"]), typ(e["target"]))
 for e in paths("uses_resource") if typ(e["target"]) not in ("System", "Equipment")]
```
Violation = `uses_resource` pointing at an Artifact (use `needs_input`) or a Vendor (use the service-as-System pattern).

### 3. Step to Vendor (Pattern 4)
**Server:** none. **Export:**
```python
[(name(e["source"]), e["name"], name(e["target"]))
 for e in E if typ(e["target"]) == "Vendor" and e["name"] != "provided_by"]
```
Violation = work pointing at a company. Fix: insert a Service (System) `provided_by` the Vendor.

### 4. part_of used for provision (Pattern 4)
**Server:** none. **Export:**
```python
[(name(e["source"]), name(e["target"]))
 for e in paths("part_of") if typ(e["source"]) == "System" and typ(e["target"]) == "Vendor"]
```
Violation = mereological overload. Fix: replace with `provided_by`.

### 5. Incomplete has_step membership (rule #10)
**Server:** `run_audit` check `sequenced_outside_process`: actions in a `followed_by` or
`followed_by_if` sequence, at either end, that no Process has as a step. **Export**, for an
offline copy:
```python
[name(s) for s in of(*ACTIONS)
 if (out(s, *SEQ) or inn(s, *SEQ)) and not [p for p in inn(s, "has_step") if typ(p) == "Process"]]
```
Violation = a sequenced step with no `has_step` parent. Fix: add `has_step` from its owning process.

### 6. Steps with no performer (accountability)
**Server:** `run_audit` check `unperformed_actions`: actions with no `performs` path into them.
It also reports Handoffs, which this check has always left out; read those with the same
judgment, or drop them. **Export:**
```python
[name(s) for s in of("Step", "Decision", "Approval", "Review") if not inn(s, "performs")]
```
Violation = atomic work with no owner. Fix: add `performs` from the responsible Position (Decisions may legitimately have none; use judgment).

### 7. System/vendor token baked into a node name (Pattern 6)
**Server:** none. **Export:**
```python
TOKENS = ["SAP", "Oracle", "NetSuite", "Salesforce", "SharePoint", "QuickBooks"]
[(name(s), [w for w in TOKENS if w in name(s)]) for s in of(*ACTIONS) if any(w in name(s) for w in TOKENS)]
```
(Adjust the token list per atlas.) Violation = a name encoding identity that lives on an edge. Fix: rename by function; reach the specific via the path.

### 8a. Orphaned action nodes (no membership)
**Server:** none. `run_audit`'s `orphaned_actions` is narrower: it reports actions with no
`has_step` **and** no incoming sequence, so an action that a step leads to but no process
contains passes it. Every `orphaned_actions` finding is also a finding here. **Export:**
```python
[name(s) for s in of(*ACTIONS) if not (out(s, "has_step") or inn(s, "has_step"))]
```
Violation = an action that belongs to no process. Fix: attach `has_step` membership (or confirm it is genuinely standalone).

### 8b. Unsequenced action nodes (membership but no flow)
**Server:** none. **Export:**
```python
[name(s) for s in of(*ACTIONS)
 if (out(s, "has_step") or inn(s, "has_step")) and not (out(s, *SEQ) or inn(s, *SEQ))]
```
Violation = a step that is IN a process but wired into no sequence. It passes naive isolation checks while being orphaned from the flow (found live in the Payment Operations build, 7/14: `has_step` present, zero `followed_by` on either side, invisible to the old combined check). Fix: sequence it, or confirm it is a true any-time step (some checklist-style processes have them; a judgment call, not auto-fail).

### 9. Unconditional multi-branch (parallel vs mis-modeled choice)
**Server:** none. **Export:**
```python
[(name(s), sorted({name(t) for t in out(s, "followed_by")}))
 for s in P if len(set(out(s, "followed_by"))) > 1]
```
Violation = a node with 2+ **unconditional** `followed_by` successors, which reads as a parallel fork (all branches happen). Almost always a mis-modeled choice; convert each branch to `followed_by_if` with a `condition`. Genuine parallel forks are rare; confirm intent before leaving as-is. (Related: a Process whose children are concurrent should carry `ordering: parallel`; see Patterns / rule #12.)

### 10. Message-type masquerading as System (Artifact-vs-System rule)
**Server:** none. **Export:**
```python
MESSAGE = ["EDI ", "NACHA", "HL7", " Form", " Letter", " Report", " File", " Message",
           "1099", "W-9", "W-2", "K-1", "Schedule K"]
[(name(s), [w for w in MESSAGE if w.upper() in name(s).upper()])
 for s in of("System") if any(w.upper() in name(s).upper() for w in MESSAGE)]
```
Violation = a Point typed `System` whose name reads like a document or message type (EDI X12 codes, NACHA file, HL7 message, named forms). Fix: re-type as `Artifact` and swap incoming `uses_resource` edges to `creates_output` (sender side) or `needs_input` (receiver side). See `atlas-modeling` → `references/artifact-vs-system.md`. A token match is a prompt to look, not a verdict: "Secure File Transfer" is a real system.

### 11. Orphan Data Tables (no has_table parent)
**Server:** none. **Export:**
```python
[name(t) for t in of("Data Table") if not [x for x in inn(t, "has_table") if typ(x) == "Database"]]
```
Violation = a Data Table with no owning Database: "which store is this in?" is unanswerable, and `joins_to` guidance loses its anchor. Fix: add `has_table` from the Database it belongs to (`has_table` is strictly Database → Data Table; if the intended parent is typed `System`, re-type it `Database` first).

### 12. System-executed steps with a human performer (execution_mode contradiction)
**Server:** none. **Export:**
```python
[(name(e["target"]), name(e["source"]), typ(e["source"])) for e in paths("performs")
 if prop(e["target"], "execution_mode") == "system" and typ(e["source"]) in ("Person", "Position", "Group")]
```
Violation = a step marked `execution_mode: 'system'` (runs without a human) that also has a Person/Position/Group `performs` edge; the two claims contradict. Fix: either the mode is wrong (a human does perform it → `human`) or the performer is wrong (remove the edge, or point it at the Agent/System actor that actually executes). An `Agent` performer is consistent with `system` and is not flagged.

**Output:** a short scorecard (one line per check: pass / N findings), then the findings, then proposed fixes. Confirm before mutating.

---

### 13. Fragmented flow views (more than one connected component)

**Server:** none. Views live outside the graph, so this is a per-view check. The export carries
every view with its `pointIds`.

Besides fragments, look for **hand-offs OUT and IN**: sequence paths that leave the
view, or enter it, from a card that is not on the canvas. Those read as orphans on
screen even when the view is one component, so they are findings too; show the
neighbour's card as an entry or exit box, per `atlas-modeling` 2a.

For each flow view, take its actions and the `followed_by` / `followed_by_if` paths between them,
count connected components ignoring direction, then list the sequence paths with one end outside
the view:

```python
import networkx as nx   # or a union-find over the pairs

for v in d["views"]:
    ids = {i for i in v.get("pointIds") or [] if i in P and typ(i) in ACTIONS}
    if v["viewType"] == "folder" or not ids:
        continue
    g = nx.Graph(); g.add_nodes_from(ids)
    g.add_edges_from((e["source"], e["target"]) for e in E
                     if e["name"] in SEQ and e["source"] in ids and e["target"] in ids)
    parts = list(nx.connected_components(g))
    crossing = [(name(e["source"]), name(e["target"])) for e in E
                if e["name"] in SEQ and (e["source"] in ids) != (e["target"] in ids)]
    if len(parts) > 1 or crossing:
        print(v["name"], len(parts), [sorted(name(i) for i in c) for c in parts], crossing)
```

Violation = a flow view with more than one component, or with an isolated action. Report each
fragment with its first and last action. Fix: see atlas-modeling 2a, "One connected flow per view":
missing sequence, parallel work, or two processes in one view. Never invent a sequence to pass the
check. Inventory views (Org, Systems, Artifacts) are exempt.

### 14. Near-duplicate actions (the usual cause of check 13)

A fragmented view is most often not a missing link but a **duplicated step**: a continuation symbol in
the source diagram (Visio's off-page connector, "home plate", a "go to page 3" box) modeled as a second
copy of the step instead of a join. Each copy heads its own chain, so one flow draws as two.

**Server:** `run_audit` check `duplicates`: same-type points whose normalized names are equal or
similar (trigram similarity of 0.7 or more). It compares every point type, so keep the action
pairs for this check and treat the rest as a lead for the inventory views. **Export**, the exact
rule this check has always used (case and a trailing parenthetical ignored), as a backstop for a
long suffix that pulls a pair under the server's threshold:
```python
def base(n): return n.split(" (")[0].strip().lower()
acts = of(*ACTIONS)
[(name(a), name(b)) for a in acts for b in acts
 if a < b and typ(a) == typ(b) and base(name(a)) == base(name(b))]
```

It catches case differences ("Are repairs Satisfactory?" / "Are repairs satisfactory?") and a
parenthetical suffix added to disambiguate ("Receive 92051 Inspection and Invoice (Repair Completion)").
Violation = a pair that is the same action in the same flow. Fix: merge, keeping every incoming and
outgoing path. **Not** a violation when the two are genuinely separate instances in different flows:
actions are per-flow instances (atlas-modeling, instance nodes), so check membership before merging.

### 15. Process size (a process that should be decomposed)

**Server:** none. **Export:**
```python
sorted(((name(p), n) for p in of("Process")
        for n in [len([s for s in out(p, "has_step") if typ(s) in ACTIONS])] if n >= 13),
       key=lambda x: -x[1])
```

Violation = 16 or more direct steps (warn from 13). For a parent Process, count its sub-processes
plus its direct steps as phases: 3 to 9 passes, 16 or more fails. A sub-process under 4 steps is too
fine unless the business names it or it is an any-order box. Fix: decompose by the cut rules in
atlas-modeling 2a (`references/large-process-decomposition.md`). The trigger is the process, not
the view: a 40-step process spread over three views still fails.

### 16. Single entry, single exit (a sub-process cut in the wrong place)

**Server:** none. For each sequential sub-process (a Process that has a parent Process and no
`ordering: any`), take its direct steps and the sequence paths between them. **Entries** are
steps no step inside precedes; **exits** are steps no step inside follows. **Export:**
```python
for p in of("Process"):
    if not [x for x in inn(p, "has_step") if typ(x) == "Process"] or prop(p, "ordering") == "any":
        continue
    steps = {s for s in out(p, "has_step") if typ(s) in ACTIONS}
    entries = [name(s) for s in steps if not set(inn(s, *SEQ)) & steps]
    exits = [name(s) for s in steps if not set(out(s, *SEQ)) & steps]
    if len(entries) >= 2 or len(exits) >= 2:
        print(name(p), entries, exits)
```

Violation = more than two entries or more than two exits (two is a warning: a parallel start or
end). An exit that leads nowhere at all is usually a missing `followed_by`, not a bad cut: ask what
happens next before moving the boundary. Any-order boxes are exempt; their entry is the box.

### 17. A rework loop crossing a sub-process edge

**Server:** none. Compute strongly connected components over the live sequence paths between
actions (`followed_by`, `followed_by_if`); any component with two or more actions is a loop.
**Export:**
```python
import networkx as nx

g = nx.DiGraph((e["source"], e["target"]) for e in E
               if e["name"] in SEQ and typ(e["source"]) in ACTIONS and typ(e["target"]) in ACTIONS)
for loop in (c for c in nx.strongly_connected_components(g) if len(c) > 1):
    owners = {p for s in loop for p in inn(s, "has_step") if typ(p) == "Process"}
    if len(owners) > 1:
        print(sorted(name(s) for s in loop), sorted(name(p) for p in owners))
```

Violation = a loop whose actions belong to more than one sub-process. A loop is one piece of work
repeated, so the cut goes around it, never through it. A conditional loop inside one sub-process
is correct modelling, not a finding.

### 18. Fan-out that should be an any-order box

**Server:** none. **Export:**
```python
[(name(s), sorted(name(t) for t in ts)) for s in P
 for ts in [set(out(s, "followed_by"))]
 if len(ts) >= 5 and not any(set(out(a, *SEQ)) & ts for a in ts)]
```

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
