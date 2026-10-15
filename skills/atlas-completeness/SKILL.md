---
name: atlas-completeness
description: Use when a built atlas needs to be interrogated for what is MISSING rather than what is wrong - before handing a build to a customer, when reviewing an atlas someone else built, or when preparing the follow-up interview after a first modeling pass. Runs read-only absence checks per point type through run_audit and the read tools (does this step have a performer, a system, an input, an output, a sequence, a source document; does this person have a position; does this process have steps and an accountable owner; is this system provided by a vendor), then produces an INTERVIEW SCRIPT of the questions that cannot be answered from the graph, grouped by who can answer them. Complements atlas-auditing, which detects violations; this one detects absences. Reports only, never mutates.
---

# Atlas Completeness

**Principle:** `atlas-auditing` answers *"what did we model wrong?"*. This skill answers a different question: **"what did we never find out?"**

A build can pass every violation check and still be unusable, because nothing in it is wrong - it is just thin. The output of this skill is not a findings list. It is **an interview script**: the specific questions to take back to the customer, grouped by who can answer them.

**When this applies:** before handing a build to a customer, when inheriting someone else's atlas, after a first modeling pass from documents or a transcript, or any time the question is "is this good enough to trust yet?"

**Tools:** read-only, and the same four moves as `atlas-auditing` ("Reading the atlas"):

- **`run_audit`** for the checks Atlas runs itself (`unperformed_actions`, `unowned_processes`, `dead_end_actions`, `actions_without_resource` and the rest). Raise `limit` (maximum 1000) or read `truncated`.
- **`run_audit` with `check: "isolated_points"` and `path_types`** as the absence test: it returns every point with no path of those types in either direction. Keep the type the check is about.
- **`search_paths`** with a path type as the query returns every path of that type, with source and target ids and the path's properties. `"followed_by"` also returns `followed_by_if`; filter on `type`.
- **The type map:** id to type for every point, from `list_points`, or from `search_points` per type name when that list is partial (filter on `type`).

**With AtlasQL.** On a deployment that runs AtlasQL, `query_atlas` (read `describe_schema` first) answers each check as one SQL query. Elsewhere it answers `available: false`, and the procedures below run on every deployment.

---

## How to run this

**The sweep is set-based. Do not iterate per node.** Each check below is one or two calls that return *every* node failing it across the whole atlas, and several checks share one `search_paths` list. Eighteen checks total, whatever the atlas size - a 77-point atlas and a 5,000-point atlas cost the same number of round trips. An agent that loops "for each step, ask the eight questions" is doing thousands of times the work for a worse answer, and will run out of context before it finishes.

Order of operations:

1. Run `atlas-auditing` first. Wrong beats thin, and a violation changes how a completeness result reads.
2. Run all eighteen checks in Part 1 as one batch.
3. Do Part 2 (judgment) once, with the whole sweep in context.
4. Emit Part 3 (the interview script).

## Part 1 - The sweep (deterministic)

Each check returns every node that cannot answer its question. An empty result is a pass.

### Action nodes (Step, Decision, Approval, Review, Handoff)

**C1. No system.** *"What does this step run in?"*
`run_audit` with `check: "actions_without_resource"` returns every action with no `uses_resource` path. Add the actions whose `uses_resource` paths all point at something other than a `System` (`search_paths` with `"uses_resource"`, plus the type map); keep that list for C16 and C17.

Legitimately empty when the work is purely physical or conversational. Judgment required - do not auto-fail.

**C2. No performer.** *"Who does this?"*
`run_audit` with `check: "unperformed_actions"`.

Overlaps `atlas-auditing` check 6. Kept here because the interview question differs: the audit asks "fix this", the interview asks "who owns it?"

**C3. No input.** *"What has to exist before this can start?"*
`run_audit` with `check: "isolated_points"` and `path_types: ["needs_input"]`; keep Step, Decision, Approval and Review.

**C4. No output.** *"What exists after this that did not before?"*
`run_audit` with `check: "isolated_points"` and `path_types: ["creates_output"]`; keep Step, Decision, Approval and Review.

C3 and C4 are the two most commonly skipped questions in a first pass and the two that most often reveal a missing step between two modelled ones.

**C5. No sequence.** *"What comes before and after?"*
Two calls. `run_audit` with `check: "dead_end_actions"` returns the actions with no successor. `run_audit` with `check: "orphaned_actions"` and `path_types: ["followed_by", "followed_by_if"]` returns the actions with no predecessor (without `path_types`, a `has_step` would count as one). Report every action in either list, marked has_predecessor and has_successor.

Reports partial sequencing, not just total absence. A step with only an inbound edge is either the end of the process or a dead end nobody noticed. Distinguish start and end nodes by hand.

**C6. Conditional path with no condition.** *"Under what circumstances does this branch fire?"*
`search_paths` with `"followed_by_if"`; report every path whose properties carry no `condition`, or a blank one.

The ontology declares `condition` required on `followed_by_if` and the create modal enforces it, so this should be empty on anything built through the UI. It is here to catch paths written around the validator - MCP batch writes, migrations, imports - where an unconditional conditional is invisible and silently makes a branch untraceable.

**C7. Decision with a single outgoing branch.** *"What happens in the other case?"*
`search_paths` with `"followed_by"` (both sequence types); count the paths out of each `Decision` in the type map. Report every Decision with fewer than two, including none.

A decision with one exit is not a decision. Either the other branch was never modelled, or the node is a Step wearing the wrong type. This is one of the highest-yield questions on the list because the missing branch is almost always the exception path, which is where the actual work happens.

**C8. No provenance.** *"Where did we learn this?"*
`run_audit` with `check: "isolated_points"` and `path_types: ["extracted_from"]`; keep the actions and `Process`. The check does not test the target's type: `search_paths` with `"extracted_from"` shows any path that points at something other than a `Document`.

The trust question. A node with no `extracted_from` is somebody's recollection. That may be fine, but the customer should know which parts of their own map are sourced and which are hearsay.

**C9. No attached document.** *"Is there a form, template, or SOP for this?"*
`run_audit` with `check: "isolated_points"` and `path_types: ["has_attachment"]`; keep Step, Decision, Approval and Review.

Distinct from C8. `extracted_from` is where the *model* came from; `has_attachment` is the artifact the *worker* needs.

### Process

**C10. Process with no steps.**
`search_paths` with `"has_step"`; report every `Process` in the type map that is the source of none. (`isolated_points` does not fit here: a sub-process with no steps still has the `has_step` from its parent.)

A named process with no steps is a placeholder someone intended to come back to. It is the single highest-signal absence in the whole sweep.

**C11. Process with nobody accountable.**
`run_audit` with `check: "unowned_processes"`.

Note the deliberate distinction from C2: `performs` is who does the work, `accountable_for` is who answers for the outcome. A process can be fully staffed and still have nobody accountable, and that gap is usually real rather than a modelling slip.

**C12. Process with no trigger.** *"What makes this start?"*
`search_paths` with `"initiates"` and with `"followed_by"`; report every `Process` that is the target of none of them.

Excludes processes started by an upstream process, so what remains is genuinely unexplained: work that appears to happen for no stated reason. Usually the answer is a schedule, an inbound message, or a threshold nobody thought to write down.


### Person and Position

**C13. Person with no position.**
`run_audit` with `check: "isolated_points"` and `path_types: ["has_role"]`; keep `Person`.

People attach to work through Positions. A Person with no `has_role` is disconnected from every process they actually touch.

**C14. Position that performs nothing and is accountable for nothing.**
`run_audit` with `check: "isolated_points"` and `path_types: ["performs", "accountable_for"]`; keep `Position`.

### System and Vendor

**C15. System with no vendor.**
`run_audit` with `check: "isolated_points"` and `path_types: ["provided_by"]`; keep `System`.

Legitimately empty for genuinely in-house systems - which is itself the answer to the question, and worth recording rather than leaving blank.

**C16. System nothing uses.**
From C1's `uses_resource` list, report every `System` that is the target of none.

Either a step is missing, or the system is shelfware. Both are worth saying out loud to a customer.

### Level placement

**C17. Same resource asserted at both process and step level.**
Join two lists from C1 and C10: for each `uses_resource` path out of a `Process`, find that process's `has_step` targets that carry a `uses_resource` path to the same resource. Report process, step and resource.

This is the "one or the other, not both" rule. The convention is that dependencies live on the leaf step and the process derives by rollup (`atlas-auditing` check 1 treats a process-level `uses_resource` as a violation). This check finds the duplicative case specifically, which reads as agreement rather than error and so survives the violation sweep.

### Ambiguity (where the model had to squint)

**C18. The squint report.** Three checks, one question: *where was the ontology not quite right, and how did we paper over it?*

**(a) Where the optional path name was used as an escape hatch.** `name` on a relationship is the ontology type; `displayName` is the optional user-facing label that overrides the pill (see `getPathDisplayLabel`). A populated `displayName` means someone reached for a type that was close but not right and relabelled it.

No list tool returns `displayName`; `get_path` reads it one path at a time. The cheapest procedure: run (b) first, then `get_path` on the paths of the generic types it reports. On a deployment that runs AtlasQL, `query_atlas` answers it atlas-wide in one call.

**(b) Generic types carrying the load.** A high count on the unconstrained catch-alls means meaning is living in prose instead of structure.

`get_atlas_brief` reports a count for every path type in its stats. Read `part_of`, `uses_resource`, `located_in`, `impacts` and `is_a`.

**(c) Nodes carrying no description.** With a generic type and no description, a node cannot be disambiguated by any reader, human or agent.

No list tool returns descriptions; `get_point` reads one point at a time. The cheapest procedure: `get_point` on the actions and processes, the types a reader most often needs to disambiguate, and count the blanks per type. On a deployment that runs AtlasQL, `query_atlas` counts them atlas-wide in one call.

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

Run Part 1 as a single batch regardless of atlas size - the calls are cheap, except C18 (a) and (c), which read one point or path per call. Part 2 needs the whole picture in one context to catch cross-step gaps, so keep it as one pass while the atlas fits. Split by process (not by point type) only when it does not, since splitting by type destroys exactly the input/output continuity that Part 2 exists to find.

## Related

- `atlas-auditing` - the violation sweep. Run it first; wrong beats thin.
- `atlas-modeling` - the three principles, including variables-as-points.
- `atlas-language` - the typed vocabulary and what may legally connect to what.
