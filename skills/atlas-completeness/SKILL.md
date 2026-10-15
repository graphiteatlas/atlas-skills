---
name: atlas-completeness
description: Use when a built atlas needs to be interrogated for what is MISSING rather than what is wrong - before handing a build to a customer, when reviewing an atlas someone else built, or when preparing the follow-up interview after a first modeling pass. Runs read-only absence checks per point type, as AtlasQL SQL through query_atlas with run_audit and the read tools as the fallback (does this step have a performer, a system, an input, an output, a sequence, a source document; does this person have a position; does this process have steps and an accountable owner; is this system provided by a vendor), then produces an INTERVIEW SCRIPT of the questions that cannot be answered from the graph, grouped by who can answer them. Complements atlas-auditing, which detects violations; this one detects absences. Reports only, never mutates.
---

# Atlas Completeness

**Principle:** `atlas-auditing` answers *"what did we model wrong?"*. This skill answers a different question: **"what did we never find out?"**

A build can pass every violation check and still be unusable, because nothing in it is wrong - it is just thin. The output of this skill is not a findings list. It is **an interview script**: the specific questions to take back to the customer, grouped by who can answer them.

**When this applies:** before handing a build to a customer, when inheriting someone else's atlas, after a first modeling pass from documents or a transcript, or any time the question is "is this good enough to trust yet?"

**Tools:** read-only, and the same reading as `atlas-auditing` ("Reading the atlas").

**With AtlasQL: SQL first.** Every check gives an AtlasQL query as its primary method: call
`describe_schema` once, then run each query with `query_atlas`. Each query starts with the live
preamble from `atlas-auditing`, which drops points and paths whose properties carry
`model_status: superseded`:

```sql
with pt as (select * from points
            where jsonb_extract_path_text(properties, 'model_status') is distinct from 'superseded'),
     pa as (select * from paths
            where jsonb_extract_path_text(properties, 'model_status') is distinct from 'superseded')
```

Queries that add their own expressions continue the `with` list after a comma. A query returns at
most 1,000 rows and sets `truncated` when there are more.

**The absence query.** Most checks ask one question: which points of these types have no live path
of these types, in either direction? One query answers all of them, with the path types as `$1` and
the point types as `$2`, each a comma-separated list:

```sql
select a.name, a.type, a.id
from pt a
where a.type = any (string_to_array($2, ','))
  and not exists (select 1 from pa join pt o on o.id in (pa.source_id, pa.target_id) and o.id <> a.id
                  where pa.type = any (string_to_array($1, ','))
                    and a.id in (pa.source_id, pa.target_id))
order by a.type, a.name
```

**Without AtlasQL.** If `query_atlas` answers `available: false`, use the tool procedure under each
query. Its four moves:

- **`run_audit`** for the checks Atlas runs itself (`unperformed_actions`, `unowned_processes`, `dead_end_actions`, `actions_without_resource` and the rest). Raise `limit` (maximum 1000) or read `truncated`.
- **`run_audit` with `check: "isolated_points"` and `path_types`** as the absence test: it returns every point with no path of those types in either direction. Keep the type the check is about.
- **`search_paths`** with a path type as the query returns every path of that type, with source and target ids and the path's properties. `"followed_by"` also returns `followed_by_if`; filter on `type`.
- **The type map:** id to type for every point, from `list_points`, or from `search_points` per type name when that list is partial (filter on `type`).

The tool procedures count superseded rows as live; read a finding's properties before reporting it.

---

## How to run this

**The sweep is set-based. Do not iterate per node.** Each check below is one query, or one or two calls on the fallback, that return *every* node failing it across the whole atlas, and several checks share one `search_paths` list. Eighteen checks total, whatever the atlas size - a 77-point atlas and a 5,000-point atlas cost the same number of round trips. An agent that loops "for each step, ask the eight questions" is doing thousands of times the work for a worse answer, and will run out of context before it finishes.

Order of operations:

1. Run `atlas-auditing` first. Wrong beats thin, and a violation changes how a completeness result reads.
2. Run all eighteen checks in Part 1 as one batch.
3. Do Part 2 (judgment) once, with the whole sweep in context.
4. Emit Part 3 (the interview script).

## Part 1 - The sweep (deterministic)

Each check returns every node that cannot answer its question. An empty result is a pass.

### Action nodes (Step, Decision, Approval, Review, Handoff)

**C1. No system.** *"What does this step run in?"*
```sql
select a.name, a.type, a.id,
       (select string_agg(r.name || ' [' || r.type || ']', '; ') from pa join pt r on r.id = pa.target_id
         where pa.type = 'uses_resource' and pa.source_id = a.id) as other_resources
from pt a
where a.type in ('Step', 'Decision', 'Approval', 'Review', 'Handoff')
  and not exists (select 1 from pa join pt r on r.id = pa.target_id
                  where pa.type = 'uses_resource' and pa.source_id = a.id
                    and r.type in ('System', 'Database'))
order by a.name
```
`other_resources` lists what the action uses instead, if anything. Fallback: `run_audit` with `check: "actions_without_resource"` returns every action with no `uses_resource` path. Add the actions whose `uses_resource` paths all point at something other than a `System` (`search_paths` with `"uses_resource"`, plus the type map); keep that list for C16 and C17.

Legitimately empty when the work is purely physical or conversational. Judgment required - do not auto-fail.

**C2. No performer.** *"Who does this?"*
The query of `atlas-auditing` check 6. Fallback: `run_audit` with `check: "unperformed_actions"`.

Overlaps `atlas-auditing` check 6. Kept here because the interview question differs: the audit asks "fix this", the interview asks "who owns it?"

**C3. No input.** *"What has to exist before this can start?"*
The absence query with `params: ["needs_input", "Step,Decision,Approval,Review"]`. Fallback: `run_audit` with `check: "isolated_points"` and `path_types: ["needs_input"]`; keep Step, Decision, Approval and Review.

**C4. No output.** *"What exists after this that did not before?"*
The absence query with `params: ["creates_output", "Step,Decision,Approval,Review"]`. Fallback: `run_audit` with `check: "isolated_points"` and `path_types: ["creates_output"]`; keep Step, Decision, Approval and Review.

C3 and C4 are the two most commonly skipped questions in a first pass and the two that most often reveal a missing step between two modelled ones.

**C5. No sequence.** *"What comes before and after?"*
```sql
, seq as (select pa.source_id, pa.target_id from pa
          join pt s on s.id = pa.source_id join pt t on t.id = pa.target_id
          where pa.type in ('followed_by', 'followed_by_if')),
flag as (select a.name, a.type, a.id,
                exists (select 1 from seq where seq.target_id = a.id) as has_predecessor,
                exists (select 1 from seq where seq.source_id = a.id) as has_successor
         from pt a where a.type in ('Step', 'Decision', 'Approval', 'Review', 'Handoff'))
select * from flag
where not (has_predecessor and has_successor)
order by has_predecessor, has_successor, name
```
Fallback: two calls. `run_audit` with `check: "dead_end_actions"` returns the actions with no successor. `run_audit` with `check: "orphaned_actions"` and `path_types: ["followed_by", "followed_by_if"]` returns the actions with no predecessor (without `path_types`, a `has_step` would count as one). Report every action in either list, marked has_predecessor and has_successor.

Reports partial sequencing, not just total absence. A step with only an inbound edge is either the end of the process or a dead end nobody noticed. Distinguish start and end nodes by hand.

**C6. Conditional path with no condition.** *"Under what circumstances does this branch fire?"*
```sql
select s.name as source, s.id as source_id, t.name as target, t.id as target_id, pa.id as path_id
from pa join pt s on s.id = pa.source_id join pt t on t.id = pa.target_id
where pa.type = 'followed_by_if'
  and coalesce(btrim(jsonb_extract_path_text(pa.properties, 'condition')), '') = ''
order by s.name
```
Fallback: `search_paths` with `"followed_by_if"`; report every path whose properties carry no `condition`, or a blank one.

The ontology declares `condition` required on `followed_by_if` and the create modal enforces it, so this should be empty on anything built through the UI. It is here to catch paths written around the validator - MCP batch writes, migrations, imports - where an unconditional conditional is invisible and silently makes a branch untraceable.

**C7. Decision with a single outgoing branch.** *"What happens in the other case?"*
```sql
select d.name, d.id, count(t.id) as branches, string_agg(t.name, '; ') as targets
from pt d
left join pa on pa.source_id = d.id and pa.type in ('followed_by', 'followed_by_if')
left join pt t on t.id = pa.target_id
where d.type = 'Decision'
group by d.name, d.id
having count(t.id) < 2
order by branches, d.name
```
Fallback: `search_paths` with `"followed_by"` (both sequence types); count the paths out of each `Decision` in the type map. Report every Decision with fewer than two, including none.

A decision with one exit is not a decision. Either the other branch was never modelled, or the node is a Step wearing the wrong type. This is one of the highest-yield questions on the list because the missing branch is almost always the exception path, which is where the actual work happens.

**C8. No provenance.** *"Where did we learn this?"*
The absence query with `params: ["extracted_from", "Step,Decision,Approval,Review,Handoff,Process"]`. It does not test the target's type; this one lists every `extracted_from` path that points at something other than a `Document`:

```sql
select s.name as source, s.id as source_id, t.name as target, t.type as target_type, pa.id as path_id
from pa join pt s on s.id = pa.source_id join pt t on t.id = pa.target_id
where pa.type = 'extracted_from' and t.type <> 'Document'
order by s.name
```
Fallback: `run_audit` with `check: "isolated_points"` and `path_types: ["extracted_from"]`; keep the actions and `Process`. `search_paths` with `"extracted_from"` shows any path that points at something other than a `Document`.

The trust question. A node with no `extracted_from` is somebody's recollection. That may be fine, but the customer should know which parts of their own map are sourced and which are hearsay.

**C9. No attached document.** *"Is there a form, template, or SOP for this?"*
The absence query with `params: ["has_attachment", "Step,Decision,Approval,Review"]`. Fallback: `run_audit` with `check: "isolated_points"` and `path_types: ["has_attachment"]`; keep Step, Decision, Approval and Review.

Distinct from C8. `extracted_from` is where the *model* came from; `has_attachment` is the artifact the *worker* needs.

### Process

**C10. Process with no steps.**
```sql
select pr.name, pr.id
from pt pr
where pr.type = 'Process'
  and not exists (select 1 from pa join pt c on c.id = pa.target_id
                  where pa.type = 'has_step' and pa.source_id = pr.id)
order by pr.name
```
The query tests outgoing `has_step` only, so the absence query does not fit: a sub-process with no steps still has the `has_step` from its parent. Fallback: `search_paths` with `"has_step"`; report every `Process` in the type map that is the source of none.

A named process with no steps is a placeholder someone intended to come back to. It is the single highest-signal absence in the whole sweep.

**C11. Process with nobody accountable.**
```sql
select pr.name, pr.id
from pt pr
where pr.type = 'Process'
  and not exists (select 1 from pa join pt o on o.id = pa.source_id
                  where pa.type = 'accountable_for' and pa.target_id = pr.id)
order by pr.name
```
Fallback: `run_audit` with `check: "unowned_processes"`.

Note the deliberate distinction from C2: `performs` is who does the work, `accountable_for` is who answers for the outcome. A process can be fully staffed and still have nobody accountable, and that gap is usually real rather than a modelling slip.

**C12. Process with no trigger.** *"What makes this start?"*
```sql
select pr.name, pr.id
from pt pr
where pr.type = 'Process'
  and not exists (select 1 from pa join pt o on o.id = pa.source_id
                  where pa.type in ('initiates', 'followed_by', 'followed_by_if') and pa.target_id = pr.id)
order by pr.name
```
Fallback: `search_paths` with `"initiates"` and with `"followed_by"`; report every `Process` that is the target of none of them.

Excludes processes started by an upstream process, so what remains is genuinely unexplained: work that appears to happen for no stated reason. Usually the answer is a schedule, an inbound message, or a threshold nobody thought to write down.


### Person and Position

**C13. Person with no position.**
The absence query with `params: ["has_role", "Person"]`. Fallback: `run_audit` with `check: "isolated_points"` and `path_types: ["has_role"]`; keep `Person`.

People attach to work through Positions. A Person with no `has_role` is disconnected from every process they actually touch.

**C14. Position that performs nothing and is accountable for nothing.**
The absence query with `params: ["performs,accountable_for", "Position"]`. Fallback: `run_audit` with `check: "isolated_points"` and `path_types: ["performs", "accountable_for"]`; keep `Position`.

### System and Vendor

**C15. System with no vendor.**
The absence query with `params: ["provided_by", "System"]`. Fallback: `run_audit` with `check: "isolated_points"` and `path_types: ["provided_by"]`; keep `System`.

Legitimately empty for genuinely in-house systems - which is itself the answer to the question, and worth recording rather than leaving blank.

**C16. System nothing uses.**
```sql
select s.name, s.type, s.id
from pt s
where s.type in ('System', 'Database')
  and not exists (select 1 from pa join pt u on u.id = pa.source_id
                  where pa.type = 'uses_resource' and pa.target_id = s.id)
order by s.name
```
Fallback: from C1's `uses_resource` list, report every `System` that is the target of none.

Either a step is missing, or the system is shelfware. Both are worth saying out loud to a customer.

### Level placement

**C17. Same resource asserted at both process and step level.**
```sql
select pr.name as process, pr.id as process_id, st.name as step, st.id as step_id,
       r.name as resource, r.id as resource_id
from pa pu
join pt pr on pr.id = pu.source_id and pr.type = 'Process'
join pt r on r.id = pu.target_id
join pa hs on hs.type = 'has_step' and hs.source_id = pr.id
join pt st on st.id = hs.target_id
join pa su on su.type = 'uses_resource' and su.source_id = st.id and su.target_id = r.id
where pu.type = 'uses_resource'
order by pr.name, st.name
```
Fallback: join two lists from C1 and C10: for each `uses_resource` path out of a `Process`, find that process's `has_step` targets that carry a `uses_resource` path to the same resource. Report process, step and resource.

This is the "one or the other, not both" rule. The convention is that dependencies live on the leaf step and the process derives by rollup (`atlas-auditing` check 1 treats a process-level `uses_resource` as a violation). This check finds the duplicative case specifically, which reads as agreement rather than error and so survives the violation sweep.

### Ambiguity (where the model had to squint)

**C18. The squint report.** Three checks, one question: *where was the ontology not quite right, and how did we paper over it?*

**(a) Where the optional path name was used as an escape hatch.** `name` on a relationship is the ontology type; `displayName` is the optional user-facing label that overrides the pill (see `getPathDisplayLabel`). A populated `displayName` means someone reached for a type that was close but not right and relabelled it.

`paths.display_name` carries the label, so one query groups every relabel by type and label:

```sql
select pa.type, pa.display_name, count(*) as paths,
       string_agg(s.name || ' -> ' || t.name || ' (' || pa.id || ')', '; ') as examples
from pa join pt s on s.id = pa.source_id join pt t on t.id = pa.target_id
where coalesce(btrim(pa.display_name), '') <> ''
  and lower(pa.display_name) <> lower(pa.type)
  and lower(pa.display_name) is distinct from lower(jsonb_extract_path_text(pa.properties, 'condition'))
group by pa.type, pa.display_name
order by paths desc, pa.type
```

A `followed_by_if` whose label repeats its `condition` is the branch label, not a relabel, so the query leaves it out. Fallback: `get_path` reads `displayName` one path at a time. Run (b) first, then `get_path` on the paths of the generic types it reports; relabels on other types go unseen.

**(b) Generic types carrying the load.** A high count on the unconstrained catch-alls means meaning is living in prose instead of structure.

```sql
select pa.type, count(*) as paths
from pa join pt s on s.id = pa.source_id join pt t on t.id = pa.target_id
where pa.type in ('part_of', 'uses_resource', 'located_in', 'impacts', 'is_a')
group by pa.type
order by paths desc
```
Fallback: `get_atlas_brief` reports a count for every path type in its stats. Read `part_of`, `uses_resource`, `located_in`, `impacts` and `is_a`.

**(c) Nodes carrying no description.** With a generic type and no description, a node cannot be disambiguated by any reader, human or agent.

`points.description` carries the text, so one query counts the blanks per type and names them:

```sql
select type, count(*) as points,
       count(*) filter (where coalesce(btrim(description), '') = '') as without_description,
       string_agg(name || ' (' || id || ')', '; ')
         filter (where coalesce(btrim(description), '') = '') as missing
from pt
group by type
having count(*) filter (where coalesce(btrim(description), '') = '') > 0
order by without_description desc
```

Read the actions and processes first: those are the types a reader most often needs to disambiguate. Fallback: `get_point` reads one point at a time; run it on the actions and processes and count the blanks per type.

**Read this section differently from the rest.** Every other check produces a question for the customer. This one produces feedback for **us**: a relabelled path is a candidate missing path type, and a cluster of relabels on the same type is an ontology gap with evidence attached. Route confirmed gaps through `ontology-update`, do not add types casually.

Three legitimate resolutions when a type is close but not exact, in order of preference:

1. **A description** on the node or path - free, and it survives an ontology change.
2. **A property** - structured, queryable, and the right answer when the distinction is a value rather than a kind.
3. **An optional path name (`displayName`)** - a deliberate design choice, not a failure. It keeps the graph queryable by the real type while showing the reader the local word for it. Use it knowingly, and log it here so the pattern is visible.

The failure mode is none of the three: a generic type, no description, no property, and a node name doing all the work.

---

## Part 2 - The judgment pass

The sweep produces absences. Most absences are not gaps. Do not hand a customer 200 rows.

Read the sweep output together with the actual node names and descriptions, then classify every absence into exactly one of three buckets:

- **Answerable from the graph** - the information is present somewhere else, or implied by structure. Fix it, do not ask.
- **Legitimately empty** - a purely conversational step needs no system; an in-house tool has no vendor; a start node has no predecessor. Record the reason so the next reviewer does not re-raise it.
- **A real question** - nobody can answer it from what we have. **This is the only bucket that reaches the customer.**

Then answer the question no query can produce: *"is there anything else I am missing?"* Read the process end to end and look for:

- A step whose output is nothing else's input, or an input nothing produces (the strongest signal of a missing step)
- A decision with one branch modelled and the other implied
- A handoff between two positions with no artifact crossing
- A process that starts with no trigger
- Two steps that are the same work under different names
- Any place the description carries a fact that should be a point (see `atlas-modeling`, the variables-as-points rule)

---

## Part 3 - Output: the interview script

The deliverable is a question list grouped by **who can answer it**, because that is how it gets used. Not grouped by check, not grouped by point type.

```
## For the process owner ([name])
1. "Invoice Coding" has no accountable owner. Who answers for it when it goes wrong?
2. "Route for Approval" produces nothing downstream. What comes out of it, and who receives it?

## For IT / systems
3. Is "Legacy Portal" still in use? Nothing in the map references it.
4. Is "Recon Tool" in-house, or is there a vendor behind it?

## For the individual
5. [Person] has no position recorded. What is their role?

## Answered internally (no need to ask)
- 14 steps had no attached document; all 14 are conversational. Recorded as intentional.

## Structural gaps found by inspection (not by query)
- "Approve Payment" needs an input nothing produces. There is likely a missing preparation step between "Verify Vendor" and it.
```

Close with a one-line readiness call: **which processes are complete enough to trust, and which are still a placeholder.**

---

## Scale note

Run Part 1 as a single batch regardless of atlas size - the queries are cheap. On the fallback, C18 (a) and (c) read one point or path per call. Part 2 needs the whole picture in one context to catch cross-step gaps, so keep it as one pass while the atlas fits. Split by process (not by point type) only when it does not, since splitting by type destroys exactly the input/output continuity that Part 2 exists to find.

## Related

- `atlas-auditing` - the violation sweep. Run it first; wrong beats thin.
- `atlas-modeling` - the three principles, including variables-as-points.
- `atlas-language` - the typed vocabulary and what may legally connect to what.
