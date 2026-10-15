---
name: atlas-auditing
description: Use when asked to audit, review, QA, or health-check a Graphite Atlas, or before signing off on a process build, or when inheriting an atlas copied from production. Runs a fixed set of read-only checks, as AtlasQL SQL through query_atlas with run_audit and the read tools as the fallback, that detect violations of the Atlas modeling patterns (dependencies at the wrong level, resources pointing at artifacts or vendors, orphaned step membership, steps with no performer, system/vendor names baked into nodes, overloaded part_of, orphan Data Tables, execution-mode contradictions). Reports findings; does not mutate.
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

**With AtlasQL: SQL first.** Every check below gives an AtlasQL query as its primary method. Call
`describe_schema` once, then run each query with `query_atlas`. A query returns the findings
directly, with names and ids, and leaves out superseded rows. If `query_atlas` answers
`available: false`, the deployment does not run AtlasQL: use the tool procedure under each query,
which runs on every deployment.

**The live preamble.** Every query starts with these two common table expressions, which drop
points and paths whose properties carry `model_status: superseded`. Queries that add their own
expressions continue the `with` list after a comma; recursive ones start `with recursive`.

```sql
with pt as (select * from points
            where jsonb_extract_path_text(properties, 'model_status') is distinct from 'superseded'),
     pa as (select * from paths
            where jsonb_extract_path_text(properties, 'model_status') is distinct from 'superseded')
```

Join every path to `pt` at both ends, so a live path into a retired point drops too. The actions
are `('Step', 'Decision', 'Approval', 'Review', 'Handoff')`. A query returns at most 1,000 rows and
sets `truncated` when there are more; narrow it by type or process and run it again. A recursive
query stops after 20 rounds.

**Without AtlasQL: the tool procedures.** Four tool moves cover most checks:

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

**Count only live work.** Deleted points and paths never reach these tools; retired ones can. An
atlas that retires by status keeps the row, with `model_status: superseded`, a reason and a date in
its properties. The live preamble drops those rows from every query. `run_audit` counts them as
live, so on the fallback drop retired paths from `search_paths` results, and read a finding's
properties (`search_points` or `get_point`) before reporting it. Without this
filter a check reports retired work as a live defect, or counts a retired path as the one that makes
something whole. On one large atlas the unfiltered checks reported 90 unconditional forks where 46
were live, and two execution-mode contradictions that were both retired performers.

### 1. Dependency at the wrong level (Pattern 3): process-level uses_resource
```sql
select pr.name as process, pr.id as process_id, r.name as resource, r.type as resource_type,
       r.id as resource_id, pa.id as path_id
from pa join pt pr on pr.id = pa.source_id join pt r on r.id = pa.target_id
where pa.type = 'uses_resource' and pr.type = 'Process'
order by pr.name, r.name
```
Fallback: `search_paths` with `"uses_resource"`; keep the paths whose source is a `Process`. Report
the process and the resource.

Violation = a process carrying a resource edge that belongs on a leaf step. Fix: move to the step that uses it; let the process derive by rollup.

### 2. Wrong resource target (Pattern 3): uses_resource to a non-System
```sql
select s.name as source, s.type as source_type, s.id as source_id,
       t.name as target, t.type as target_type, t.id as target_id, pa.id as path_id
from pa join pt s on s.id = pa.source_id join pt t on t.id = pa.target_id
where pa.type = 'uses_resource' and t.type not in ('System', 'Database', 'Equipment')
order by s.name
```
`Database` is a kind of `System`, so a path to one passes. Fallback: from the same
`uses_resource` list, keep the paths whose target is neither `System`, `Database` nor `Equipment`.
Report the step, the target and the target's type.

Violation = `uses_resource` pointing at an Artifact (use `needs_input`) or a Vendor (use the service-as-System pattern).

### 3. Step to Vendor (Pattern 4)
```sql
select v.name as vendor, v.id as vendor_id, pa.type as path_type,
       s.name as source, s.type as source_type, s.id as source_id, pa.id as path_id
from pa join pt v on v.id = pa.target_id join pt s on s.id = pa.source_id
where v.type = 'Vendor' and pa.type <> 'provided_by'
order by v.name, s.name
```
Fallback: `search_points` with `"Vendor"` lists the vendors. For each, `traverse` with
`direction: "in"` and `depth: 1` returns every path into it. Flag every path whose type is not
`provided_by`, with its source. Vendors are few, so one call each is cheap.

Violation = work pointing at a company. Fix: insert a Service (System) `provided_by` the Vendor.

### 4. part_of used for provision (Pattern 4)
```sql
select s.name as system, s.id as system_id, v.name as vendor, v.id as vendor_id, pa.id as path_id
from pa join pt s on s.id = pa.source_id join pt v on v.id = pa.target_id
where pa.type = 'part_of' and s.type in ('System', 'Database') and v.type = 'Vendor'
order by s.name
```
Fallback: `search_paths` with `"part_of"`; keep the paths from a `System` to a `Vendor`. Check 3's
traversals show them too.

Violation = mereological overload. Fix: replace with `provided_by`.

### 5. Incomplete has_step membership (rule #10)
```sql
select a.name, a.type, a.id
from pt a
where a.type in ('Step', 'Decision', 'Approval', 'Review', 'Handoff')
  and exists (select 1 from pa where pa.type in ('followed_by', 'followed_by_if')
              and a.id in (pa.source_id, pa.target_id))
  and not exists (select 1 from pa join pt pr on pr.id = pa.source_id
                  where pa.type = 'has_step' and pa.target_id = a.id and pr.type = 'Process')
order by a.name
```
Fallback: `run_audit` with `check: "sequenced_outside_process"`: every action in a `followed_by` or
`followed_by_if` sequence, at either end, that no Process has as a step.

Violation = a sequenced step with no `has_step` parent. Fix: add `has_step` from its owning process.

### 6. Steps with no performer (accountability)
```sql
select a.name, a.type, a.id
from pt a
where a.type in ('Step', 'Decision', 'Approval', 'Review')
  and not exists (select 1 from pa join pt p on p.id = pa.source_id
                  where pa.type = 'performs' and pa.target_id = a.id)
order by a.name
```
Handoff is out of scope, since a Handoff names its actors with `from_actor` and `to_actor`.
Fallback: `run_audit` with `check: "unperformed_actions"`: every action with no `performs` path into
it, over the same four types.

Violation = atomic work with no owner. Fix: add `performs` from the responsible Position (Decisions may legitimately have none: use judgment).

### 7. System/vendor token baked into a node name (Pattern 6)
```sql
, tokens as (select tok from unnest(string_to_array($1, ',')) as tok
             union select name from pt where type in ('System', 'Database', 'Vendor'))
select a.name, a.type, a.id, string_agg(t.tok, ', ') as tokens
from pt a join tokens t on strpos(lower(a.name), lower(t.tok)) > 0
where a.type in ('Step', 'Decision', 'Approval', 'Review', 'Handoff')
group by a.name, a.type, a.id
order by a.name
```
with `params: ["SAP,Oracle,NetSuite,Salesforce,SharePoint,QuickBooks"]`. The query also matches the
names of the atlas's own systems and vendors, so a step named after one shows up without a custom
list. Fallback: `search_points` once per token (`"SAP"`, `"Oracle"`, `"NetSuite"`, `"Salesforce"`,
`"SharePoint"`, `"QuickBooks"`, plus each System and Vendor name); keep the actions (Step, Decision,
Approval, Review, Handoff). Report each name with its tokens.

(Adjust the token list per atlas.) Violation = a name encoding identity that lives on an edge. Fix: rename by function; reach the specific via the path.

### 8a. Orphaned action nodes (no membership)
```sql
select a.name, a.type, a.id
from pt a
where a.type in ('Step', 'Decision', 'Approval', 'Review', 'Handoff')
  and not exists (select 1 from pa join pt pr on pr.id = pa.source_id
                  where pa.type = 'has_step' and pa.target_id = a.id)
order by a.name
```
Fallback: `run_audit` with `check: "orphaned_actions"` and `path_types: ["has_step"]`: every action
no `has_step` path leads into.

Violation = an action that belongs to no process. Fix: attach `has_step` membership (or confirm it is genuinely standalone).

### 8b. Unsequenced action nodes (membership but no flow)
```sql
select a.name, a.type, a.id, pr.name as process, pr.id as process_id
from pt a
join pa m on m.type = 'has_step' and m.target_id = a.id
join pt pr on pr.id = m.source_id
where a.type in ('Step', 'Decision', 'Approval', 'Review', 'Handoff')
  and not exists (select 1 from pa join pt o on o.id in (pa.source_id, pa.target_id) and o.id <> a.id
                  where pa.type in ('followed_by', 'followed_by_if')
                    and a.id in (pa.source_id, pa.target_id))
order by pr.name, a.name
```
Fallback: `run_audit` with `check: "isolated_points"` and
`path_types: ["followed_by", "followed_by_if"]`; keep the actions, then drop the ones 8a found.
What remains is in a process but in no sequence.

Violation = a step that is IN a process but wired into no sequence: `has_step` present, zero `followed_by` on either side. It passes naive isolation checks while being orphaned from the flow. Fix: sequence it, or confirm it is a true any-time step (some checklist-style processes have them: judgment call, not auto-fail).

### 9. Unconditional multi-branch (parallel vs mis-modeled choice)
```sql
select s.name as source, s.type as source_type, s.id as source_id, count(distinct t.id) as targets,
       string_agg(t.name || ' (' || t.id || ')', '; ') as target_list
from pa join pt s on s.id = pa.source_id join pt t on t.id = pa.target_id
where pa.type = 'followed_by'
group by s.name, s.type, s.id
having count(distinct t.id) >= 2
order by targets desc, s.name
```
Fallback: `search_paths` with `"followed_by"`; keep type `followed_by` exactly, group by source, and
report every source with two or more distinct targets, with the targets.

Violation = a node with 2+ **unconditional** `followed_by` successors, which reads as a parallel fork (all branches happen). Almost always a mis-modeled choice; convert each branch to `followed_by_if` with a `condition`. Genuine parallel forks are rare: confirm intent before leaving as-is. (Related: a Process whose children are concurrent should carry `ordering: parallel`; see Patterns / rule #12.)

### 10. Message-type masquerading as System (Artifact-vs-System rule)
```sql
select s.name, s.id, string_agg(btrim(tok), ', ') as tokens
from pt s cross join unnest(string_to_array($1, '|')) as tok
where s.type = 'System' and strpos(lower(s.name), lower(tok)) > 0
group by s.name, s.id
order by s.name
```
with `params: ["EDI |NACHA|HL7| Form| Letter| Report| File| Message|1099|W-9|W-2|K-1|Schedule K"]`.
The leading and trailing spaces are part of the tokens. Fallback: `search_points` with `"System"`;
keep type `System` and scan each name, ignoring case, for the same tokens. Report each hit with its
tokens.

Violation = a Point typed `System` whose name reads like a document or message type (EDI X12 codes, NACHA file, HL7 message, named forms). Fix: re-type as `Artifact` and swap incoming `uses_resource` edges to `creates_output` (sender side) or `needs_input` (receiver side). See `atlas-modeling`, `references/artifact-vs-system.md`.

### 11. Orphan Data Tables (no has_table parent)
```sql
select d.name, d.id
from pt d
where d.type = 'Data Table'
  and not exists (select 1 from pa join pt db on db.id = pa.source_id
                  where pa.type = 'has_table' and pa.target_id = d.id)
order by d.name
```
Fallback: `run_audit` with `check: "isolated_points"` and `path_types: ["has_table"]`; keep type
`Data Table`.

Violation = a Data Table with no owning Database: "which store is this in?" is unanswerable, and `joins_to` guidance loses its anchor. Fix: add `has_table` from the Database that holds it (`has_table` is strictly Database to Data Table; if the intended parent is typed `System`, re-type it `Database` first).

### 12. System-executed steps with a human performer (execution_mode contradiction)
```sql
select t.name as step, t.type as step_type, t.id as step_id,
       s.name as performer, s.type as performer_type, s.id as performer_id, pa.id as path_id
from pa join pt s on s.id = pa.source_id join pt t on t.id = pa.target_id
where pa.type = 'performs' and s.type in ('Person', 'Position', 'Group')
  and lower(jsonb_extract_path_text(t.properties, 'execution_mode')) = 'system'
order by t.name
```
Fallback: `search_paths` with `"performs"`; keep the paths whose source is a `Person`, `Position` or
`Group`. For each distinct target, read `execution_mode` from its properties (`search_points` by the
step's type returns them; `get_point` reads one). Report every target whose mode is `system`, with
the performer and its type.

Violation = a step marked `execution_mode: 'system'` (runs without a human) that also has a Person/Position/Group `performs` edge: the two claims contradict. Fix: either the mode is wrong (a human does perform it, so `human`) or the performer is wrong (remove the edge, or point it at the Agent/System actor that actually executes). An `Agent` performer is consistent with `system` and is not flagged.

**Output:** a short scorecard (one line per check: pass / N findings), then the findings, then proposed fixes. Confirm before mutating.

---

### 13. Fragmented flow views (more than one connected component)

Views live outside the graph, so this is a per-view check, not one atlas-wide call.

Besides fragments, look for **hand-offs OUT and IN**: sequence paths that leave the
view, or enter it, from a card that is not on the canvas. Those read as orphans on
screen even when the view is one component, so they are findings too; show the
neighbour's card as an entry or exit box, per `atlas-modeling` 2a.

**SQL, fragments.** One query labels every action on every view with its component and returns the
fragments of each view that has more than one:

```sql
, va as (select vp.view_id, a.id, a.name from view_points vp join pt a on a.id = vp.point_id
         where vp.removed is not true and a.type in ('Step', 'Decision', 'Approval', 'Review', 'Handoff')),
e as (select s.view_id, pa.source_id as x, pa.target_id as y from pa
      join va s on s.id = pa.source_id join va t on t.id = pa.target_id and t.view_id = s.view_id
      where pa.type in ('followed_by', 'followed_by_if')),
u as (select view_id, x, y from e union select view_id, y, x from e),
reach (view_id, start_id, node_id) as (
  select view_id, id, id from va
  union
  select r.view_id, r.start_id, u.y from reach r join u on u.view_id = r.view_id and u.x = r.node_id),
comp as (select view_id, node_id, min(start_id) as comp_id from reach group by view_id, node_id),
frag as (select c.view_id, c.comp_id, count(*) as actions,
                string_agg(va.name || ' (' || va.id || ')', '; ' order by va.name) as members
         from comp c join va on va.id = c.node_id and va.view_id = c.view_id
         group by c.view_id, c.comp_id)
select v.name as view, v.id as view_id, f.actions, f.members,
       count(*) over (partition by f.view_id) as fragments
from frag f join views v on v.id = f.view_id
where f.view_id in (select view_id from frag group by view_id having count(*) > 1)
order by v.name, f.actions desc
```

This one needs `with recursive`. The recursion stops after 20 rounds, so a chain of more than 20
actions can read as two fragments; confirm a fragment on a long view with the fallback.

**SQL, hand-offs.** Sequence paths with one end on the view and the other off it:

```sql
, vp as (select view_id, point_id from view_points where removed is not true),
va as (select vp.view_id, a.id, a.name from vp join pt a on a.id = vp.point_id
       where a.type in ('Step', 'Decision', 'Approval', 'Review', 'Handoff'))
select v.name as view, v.id as view_id,
       case when va.id = pa.source_id then 'out' else 'in' end as direction,
       va.name as on_canvas, va.id as on_canvas_id, o.name as off_canvas, o.id as off_canvas_id,
       pa.type, pa.id as path_id
from va join views v on v.id = va.view_id
join pa on pa.type in ('followed_by', 'followed_by_if') and va.id in (pa.source_id, pa.target_id)
join pt o on o.id = case when va.id = pa.source_id then pa.target_id else pa.source_id end
where not exists (select 1 from vp where vp.view_id = va.view_id and vp.point_id = o.id)
order by v.name, direction, va.name
```

**Fallback:** fetch the sequence paths once (`search_paths` with `"followed_by"`, which returns
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

```sql
, act as (select id, type, name,
                 regexp_replace(lower(split_part(name, ' (', 1)), '[^a-z0-9]+', '', 'g') as norm
          from pt where type in ('Step', 'Decision', 'Approval', 'Review', 'Handoff'))
select a.type, a.name as a_name, a.id as a_id, b.name as b_name, b.id as b_id,
  (select string_agg(pr.name, ', ') from pa join pt pr on pr.id = pa.source_id
    where pa.type = 'has_step' and pa.target_id = a.id) as a_processes,
  (select string_agg(pr.name, ', ') from pa join pt pr on pr.id = pa.source_id
    where pa.type = 'has_step' and pa.target_id = b.id) as b_processes
from act a join act b on b.type = a.type and b.norm = a.norm and a.id < b.id
order by a.type, a.name
```
The query compares names with case, punctuation, spacing and any suffix from ` (` removed, and
lists each copy's processes for the membership test below. AtlasQL has no trigram similarity, so
also run `run_audit` with `check: "duplicates"` for the near misses; it returns every pair of one
type whose names match once normalized or reach a trigram similarity of 0.7. Keep the action pairs,
and drop any whose points are superseded.

Fallback: `run_audit` with `check: "duplicates"`, as above. A long parenthetical suffix can fall
under its threshold, so also strip everything from ` (` in the action names of the type map and
compare what is left within each type.

Together they catch case differences ("Are repairs Satisfactory?" / "Are repairs satisfactory?") and a
parenthetical suffix added to disambiguate ("Receive 92051 Inspection and Invoice (Repair Completion)").
Violation = a pair that is the same action in the same flow. Fix: merge, keeping every incoming and
outgoing path. **Not** a violation when the two are genuinely separate instances in different flows:
actions are per-flow instances (atlas-modeling, instance nodes), so check membership before merging.

### 15. Process size (a process that should be decomposed)

```sql
select pr.name as process, pr.id as process_id,
       count(*) filter (where c.type in ('Step', 'Decision', 'Approval', 'Review', 'Handoff')) as steps,
       count(*) filter (where c.type = 'Process') as sub_processes
from pa join pt pr on pr.id = pa.source_id join pt c on c.id = pa.target_id
where pa.type = 'has_step' and pr.type = 'Process'
group by pr.name, pr.id
having count(*) filter (where c.type in ('Step', 'Decision', 'Approval', 'Review', 'Handoff', 'Process')) >= 13
order by steps desc
```
Fallback: `search_paths` with `"has_step"`; for each `Process` source, count the targets that are
actions. Report every process with 13 or more, largest first.

Violation = 16 or more direct steps (warn from 13). For a parent Process, count its sub-processes
plus its direct steps as phases: 3 to 9 passes, 16 or more fails. A sub-process under 4 steps is too
fine unless the business names it or it is an any-order box. Fix: decompose by the cut rules in
atlas-modeling 2a (`references/large-process-decomposition.md`). The trigger is the process, not
the view: a 40-step process spread over three views still fails.

### 16. Single entry, single exit (a sub-process cut in the wrong place)

For each sequential sub-process (a Process that has a parent Process and no `ordering: any`), take
its direct steps and the sequence paths between them. **Entries** are steps no step inside
precedes; **exits** are steps no step inside follows.

```sql
, sub as (select pr.id, pr.name from pt pr where pr.type = 'Process'
          and jsonb_extract_path_text(pr.properties, 'ordering') is distinct from 'any'
          and exists (select 1 from pa join pt up on up.id = pa.source_id
                      where pa.type = 'has_step' and pa.target_id = pr.id and up.type = 'Process')),
mem as (select sub.id as process_id, a.id, a.name from sub
        join pa on pa.type = 'has_step' and pa.source_id = sub.id
        join pt a on a.id = pa.target_id and a.type in ('Step', 'Decision', 'Approval', 'Review', 'Handoff')),
seq as (select s.process_id, pa.source_id, pa.target_id from pa
        join mem s on s.id = pa.source_id join mem t on t.id = pa.target_id and t.process_id = s.process_id
        where pa.type in ('followed_by', 'followed_by_if')),
flag as (select m.process_id, m.name as step,
           not exists (select 1 from seq where seq.process_id = m.process_id and seq.target_id = m.id) as is_entry,
           not exists (select 1 from seq where seq.process_id = m.process_id and seq.source_id = m.id) as is_exit
         from mem m)
select sub.name as process, sub.id as process_id,
       count(*) filter (where is_entry) as entry_count, string_agg(step, '; ') filter (where is_entry) as entries,
       count(*) filter (where is_exit) as exit_count, string_agg(step, '; ') filter (where is_exit) as exits
from flag join sub on sub.id = flag.process_id
group by sub.name, sub.id
having count(*) filter (where is_entry) >= 2 or count(*) filter (where is_exit) >= 2
order by sub.name
```
Fallback: take the direct steps from the `has_step` list and the sequence paths from the
`followed_by` list, and count entries and exits per sub-process by hand.

Violation = more than two entries or more than two exits (two is a warning: a parallel start or
end). An exit that leads nowhere at all is usually a missing `followed_by`, not a bad cut: ask what
happens next before moving the boundary. Any-order boxes are exempt; their entry is the box.

### 17. A rework loop crossing a sub-process edge

```sql
, act as (select id, name from pt where type in ('Step', 'Decision', 'Approval', 'Review', 'Handoff')),
e as (select pa.source_id as x, pa.target_id as y from pa
      join act s on s.id = pa.source_id join act t on t.id = pa.target_id
      where pa.type in ('followed_by', 'followed_by_if')),
reach (x, y) as (select x, y from e union select r.x, e.y from reach r join e on e.x = r.y),
loop as (select r.x as id, min(r.y) as loop_id from reach r
         join reach back on back.x = r.y and back.y = r.x group by r.x),
owner as (select l.loop_id, l.id, a.name, pr.name as process from loop l join act a on a.id = l.id
          left join pa on pa.type = 'has_step' and pa.target_id = l.id
          left join pt pr on pr.id = pa.source_id and pr.type = 'Process')
select loop_id, count(distinct id) as actions, count(distinct process) as processes,
       string_agg(distinct name || ' (' || id || ')', '; ') as loop_actions,
       string_agg(distinct process, '; ') as process_names
from owner group by loop_id
having count(distinct id) >= 2 and count(distinct process) > 1
order by processes desc
```
This one needs `with recursive`; a loop longer than 20 actions escapes it. Fallback: compute
strongly connected components over the live sequence paths between actions (`followed_by`,
`followed_by_if`, from one `search_paths` call); any component with two or more actions is a loop.
Violation = a loop whose actions belong to more than one sub-process. A loop is one piece of work repeated, so the
cut goes around it, never through it. A conditional loop inside one sub-process is correct modelling,
not a finding.

### 18. Fan-out that should be an any-order box

```sql
, fan as (select pa.source_id, pa.target_id from pa join pt t on t.id = pa.target_id
          where pa.type = 'followed_by'),
wide as (select source_id from fan group by source_id having count(distinct target_id) >= 5)
select s.name as source, s.id as source_id, count(distinct t.id) as targets,
       string_agg(t.name || ' (' || t.id || ')', '; ') as target_list
from wide w join pt s on s.id = w.source_id join fan f on f.source_id = w.source_id
join pt t on t.id = f.target_id
where not exists (select 1 from fan f1 join fan f2 on f2.source_id = f1.source_id
                  join pa q on q.type in ('followed_by', 'followed_by_if')
                           and q.source_id = f1.target_id and q.target_id = f2.target_id
                  where f1.source_id = w.source_id)
group by s.name, s.id
order by targets desc
```
Fallback: from check 9's `followed_by` list, take every source with five or more targets. Report it
when no `followed_by` or `followed_by_if` path runs between any two of those targets.

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

