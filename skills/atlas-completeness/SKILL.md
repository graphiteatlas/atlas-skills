---
name: atlas-completeness
description: Use when a built atlas needs to be interrogated for what is MISSING rather than what is wrong - before handing a build to a customer, when reviewing an atlas someone else built, or when preparing the follow-up interview after a first modeling pass. Runs read-only absence checks per point type, through the server's `run_audit` where it covers one and a short script over the atlas export where it does not (does this step have a performer, a system, an input, an output, a sequence, a source document; does this person have a position; does this process have steps and an accountable owner; is this system provided by a vendor), then produces an INTERVIEW SCRIPT of the questions that cannot be answered from the graph, grouped by who can answer them. Complements atlas-auditing, which detects violations; this one detects absences. Reports only, never mutates.
---

# Atlas Completeness

**Principle:** `atlas-auditing` answers *"what did we model wrong?"*. This skill answers a different question: **"what did we never find out?"**

A build can pass every violation check and still be unusable, because nothing in it is wrong - it is just thin. The output of this skill is not a findings list. It is **an interview script**: the specific questions to take back to the customer, grouped by who can answer them.

**When this applies:** before handing a build to a customer, when inheriting someone else's atlas, after a first modeling pass from documents or a transcript, or any time the question is "is this good enough to trust yet?"

---

## How to run this

**The sweep is set-based. Do not iterate per node.** Each check below returns *every* node failing it across the whole atlas in one pass. Eighteen checks total (a couple run more than one pass), whatever the atlas size - a 77-point atlas and a 5,000-point atlas cost the same: one `run_audit` call and one export. An agent that loops "for each step, ask the eight questions" is doing thousands of times the work for a worse answer, and will run out of context before it finishes.

**Sources.** The same two as `atlas-auditing`, both read-only, and its "Running the checks" section has the details:

- **`run_audit` (MCP)** where a check names a server check. One call with no `check` runs them all. A count of 0 is a pass; a failed call is an error, never a pass; raise `limit` when a report says `truncated`.
- **The atlas export** for everything else: `GET /api/atlas/{atlas_id}/export` with the MCP server's token, loaded once with the helpers defined there (`P`, `E`, `name`, `typ`, `of`, `out`, `inn`, `paths`, `ACTIONS`, `SEQ`). Those helpers already drop retired points and paths (`model_status: superseded`) and refuse a partial export. Every snippet below runs over them.

`list_points` and `list_paths` return one page each, so they cannot answer an absence question: a path missing from a page is not a path that is absent. Where `query_atlas` (AtlasQL) runs on your deployment, any export check can be one read-only SQL query over `points` and `paths` instead.

Order of operations:

1. Run `atlas-auditing` first. Wrong beats thin, and a violation changes how a completeness result reads.
2. Run all eighteen checks in Part 1 as one batch: one `run_audit` call, one export, one script.
3. Do Part 2 (judgment) once, with the whole sweep in context.
4. Emit Part 3 (the interview script).

## Part 1 - The sweep (deterministic)

Each check returns every node that cannot answer its question. An empty result is a pass.

### Action nodes (Step, Decision, Approval, Review, Handoff)

**C1. No system.** *"What does this step run in?"*

**Server:** `run_audit` check `actions_without_resource` returns the actions with no `uses_resource` at all. Add the actions whose only resources are not Systems (most often Equipment) to get this check's full list. **Export:**
```python
[(name(s), typ(s)) for s in of(*ACTIONS) if not [t for t in out(s, "uses_resource") if typ(t) == "System"]]
```
Legitimately empty when the work is purely physical or conversational. Judgment required - do not auto-fail.

**C2. No performer.** *"Who does this?"*

**Server:** `run_audit` check `unperformed_actions`. **Export:**
```python
[(name(s), typ(s)) for s in of(*ACTIONS) if not inn(s, "performs")]
```
Overlaps `atlas-auditing` check 6. Kept here because the interview question differs: the audit asks "fix this", the interview asks "who owns it?"

**C3. No input.** *"What has to exist before this can start?"*

**Server:** none. **Export:**
```python
[name(s) for s in of("Step", "Decision", "Approval", "Review") if not out(s, "needs_input")]
```

**C4. No output.** *"What exists after this that did not before?"*

**Server:** none. **Export:**
```python
[name(s) for s in of("Step", "Decision", "Approval", "Review") if not out(s, "creates_output")]
```
C3 and C4 are the two most commonly skipped questions in a first pass and the two that most often reveal a missing step between two modelled ones.

**C5. No sequence.** *"What comes before and after?"*

**Server:** `run_audit` check `dead_end_actions` gives the successor half (actions with no `followed_by` or `followed_by_if` out). The predecessor half has no server check. **Export**, both halves at once:
```python
[(name(s), bool(inn(s, *SEQ)), bool(out(s, *SEQ)))   # step, has_predecessor, has_successor
 for s in of(*ACTIONS) if not (inn(s, *SEQ) and out(s, *SEQ))]
```
Reports partial sequencing, not just total absence. A step with only an inbound edge is either the end of the process or a dead end nobody noticed. Distinguish start and end nodes by hand.

**C6. Conditional path with no condition.** *"Under what circumstances does this branch fire?"*

**Server:** none. The condition is a path property, which `list_paths` does not return. **Export:**
```python
[(name(e["source"]), name(e["target"])) for e in paths("followed_by_if")
 if not str((e.get("properties") or {}).get("condition") or "").strip()]
```
The ontology declares `condition` required on `followed_by_if` and the create modal enforces it, so this should be empty on anything built through the UI. It is here to catch paths written around the validator - MCP batch writes, migrations, imports - where an unconditional conditional is invisible and silently makes a branch untraceable.

**C7. Decision with a single outgoing branch.** *"What happens in the other case?"*

**Server:** none. **Export:**
```python
[(name(x), len(out(x, *SEQ))) for x in of("Decision") if len(out(x, *SEQ)) < 2]
```
A decision with one exit is not a decision. Either the other branch was never modelled, or the node is a Step wearing the wrong type. This is one of the highest-yield questions on the list because the missing branch is almost always the exception path, which is where the actual work happens.

**C8. No provenance.** *"Where did we learn this?"*

**Server:** none. **Export:**
```python
[(name(s), typ(s)) for s in of(*ACTIONS, "Process")
 if not [t for t in out(s, "extracted_from") if typ(t) == "Document"]]
```
The trust question. A node with no `extracted_from` is somebody's recollection. That may be fine, but the customer should know which parts of their own map are sourced and which are hearsay.

**C9. No attached document.** *"Is there a form, template, or SOP for this?"*

**Server:** none. **Export:**
```python
[name(s) for s in of("Step", "Decision", "Approval", "Review")
 if not [t for t in out(s, "has_attachment") if typ(t) == "Document"]]
```
Distinct from C8. `extracted_from` is where the *model* came from; `has_attachment` is the artifact the *worker* needs.

### Process

**C10. Process with no steps.**

**Server:** none. **Export:**
```python
[name(p) for p in of("Process") if not out(p, "has_step")]
```
A named process with no steps is a placeholder someone intended to come back to. It is the single highest-signal absence in the whole sweep.

**C11. Process with nobody accountable.**

**Server:** `run_audit` check `unowned_processes`. **Export:**
```python
[name(p) for p in of("Process") if not inn(p, "accountable_for")]
```
Note the deliberate distinction from C2: `performs` is who does the work, `accountable_for` is who answers for the outcome. A process can be fully staffed and still have nobody accountable, and that gap is usually real rather than a modelling slip.

**C12. Process with no trigger.** *"What makes this start?"*

**Server:** none. **Export:**
```python
[name(p) for p in of("Process")
 if not [t for t in inn(p, "initiates") if typ(t) == "Trigger"] and not inn(p, *SEQ)]
```
Excludes processes started by an upstream process, so what remains is genuinely unexplained: work that appears to happen for no stated reason. Usually the answer is a schedule, an inbound message, or a threshold nobody thought to write down.


### Person and Position

**C13. Person with no position.**

**Server:** none. **Export:**
```python
[name(p) for p in of("Person") if not [t for t in out(p, "has_role") if typ(t) == "Position"]]
```
People attach to work through Positions. A Person with no `has_role` is disconnected from every process they actually touch.

**C14. Position that performs nothing and is accountable for nothing.**

**Server:** none. **Export:**
```python
[name(p) for p in of("Position") if not out(p, "performs", "accountable_for")]
```

### System and Vendor

**C15. System with no vendor.**

**Server:** none. **Export:**
```python
[name(s) for s in of("System") if not [t for t in out(s, "provided_by") if typ(t) == "Vendor"]]
```
Legitimately empty for genuinely in-house systems - which is itself the answer to the question, and worth recording rather than leaving blank.

**C16. System nothing uses.**

**Server:** none. **Export:**
```python
[name(s) for s in of("System") if not inn(s, "uses_resource")]
```
Either a step is missing, or the system is shelfware. Both are worth saying out loud to a customer.

### Level placement

**C17. Same resource asserted at both process and step level.**

**Server:** none. **Export:**
```python
[(name(p), name(s), name(r)) for p in of("Process") for r in out(p, "uses_resource")
 for s in out(p, "has_step") if r in out(s, "uses_resource")]
```
This is the "one or the other, not both" rule. The convention is that dependencies live on the leaf step and the process derives by rollup (`atlas-auditing` check 1 treats a process-level `uses_resource` as a violation). This check finds the duplicative case specifically, which reads as agreement rather than error and so survives the violation sweep.

### Ambiguity (where the model had to squint)

**C18. The squint report.** Three passes, one question: *where was the ontology not quite right, and how did we paper over it?*

**(a) Where the optional path name was used as an escape hatch.** `name` on a relationship is the ontology type; `displayName` is the optional user-facing label that overrides the pill (see `getPathDisplayLabel`). A populated `displayName` means someone reached for a type that was close but not right and relabelled it.

**Server:** none. `displayName` is a field on the path itself, beside `properties`, in the export. **Export:**
```python
sorted((e["name"], e["displayName"], name(e["source"]), name(e["target"])) for e in E
       if (e.get("displayName") or "").strip() and e["displayName"] != e["name"])
```

**(b) Generic types carrying the load.** A high count on the unconstrained catch-alls means meaning is living in prose instead of structure.

**Server:** none. **Export:**
```python
from collections import Counter
Counter(e["name"] for e in E
        if e["name"] in ("part_of", "uses_resource", "located_in", "impacts", "is_a")).most_common()
```

**(c) Nodes carrying no description.** With a generic type and no description, a node cannot be disambiguated by any reader, human or agent.

**Server:** none. **Export:**
```python
Counter(typ(i) for i in P if not (P[i].get("description") or "").strip()).most_common()
```

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

Run Part 1 as a single batch regardless of atlas size - one export and one script are cheap. Part 2 needs the whole picture in one context to catch cross-step gaps, so keep it as one pass while the atlas fits. Split by process (not by point type) only when it does not, since splitting by type destroys exactly the input/output continuity that Part 2 exists to find.

## Related

- `atlas-auditing` - the violation sweep. Run it first; wrong beats thin.
- `atlas-modeling` - the three principles, including variables-as-points.
- `atlas-language` - the typed vocabulary and what may legally connect to what.
