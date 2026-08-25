---
name: atlas-completeness
description: Use when a built atlas needs to be interrogated for what is MISSING rather than what is wrong - before handing a build to a customer, when reviewing an atlas someone else built, or when preparing the follow-up interview after a first modeling pass. Runs read-only Cypher absence checks per point type (does this step have a performer, a system, an input, an output, a sequence, a source document; does this person have a position; does this process have steps and an accountable owner; is this system provided by a vendor), then produces an INTERVIEW SCRIPT of the questions that cannot be answered from the graph, grouped by who can answer them. Complements atlas-auditing, which detects violations; this one detects absences. Reports only, never mutates.
---

# Atlas Completeness

**Principle:** `atlas-auditing` answers *"what did we model wrong?"*. This skill answers a different question: **"what did we never find out?"**

A build can pass every violation check and still be unusable, because nothing in it is wrong - it is just thin. The output of this skill is not a findings list. It is **an interview script**: the specific questions to take back to the customer, grouped by who can answer them.

**When this applies:** before handing a build to a customer, when inheriting someone else's atlas, after a first modeling pass from documents or a transcript, or any time the question is "is this good enough to trust yet?"

**Rules for every query:** scope to the atlas (`{atlasId: $atlasId}`), exclude deleted (`deletedAt IS NULL`), read-only (MATCH/RETURN only). Path type is in `r.name`; relationships use the `:PATH` label.

---

## How to run this

**The sweep is set-based. Do not iterate per node.** Each check below is a single query that returns *every* node failing it across the whole atlas. Eighteen checks total (a couple run more than one query), whatever the atlas size - a 77-point atlas and a 5,000-point atlas cost the same number of round trips. An agent that loops "for each step, ask the eight questions" is doing thousands of times the work for a worse answer, and will run out of context before it finishes.

Order of operations:

1. Run `atlas-auditing` first. Wrong beats thin, and a violation changes how a completeness result reads.
2. Run all eighteen checks in Part 1 as one batch.
3. Do Part 2 (judgment) once, with the whole sweep in context.
4. Emit Part 3 (the interview script).

## Part 1 - The sweep (deterministic)

Each query returns every node that cannot answer its question. An empty result is a pass.

### Action nodes (Step, Decision, Approval, Review, Handoff)

**C1. No system.** *"What does this step run in?"*
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review','Handoff'] AND s.deletedAt IS NULL
  AND NOT EXISTS { MATCH (s)-[:PATH {name:'uses_resource'}]->(:Point {type:'System'}) }
RETURN s.name AS step, s.type AS kind
```
Legitimately empty when the work is purely physical or conversational. Judgment required - do not auto-fail.

**C2. No performer.** *"Who does this?"*
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review','Handoff'] AND s.deletedAt IS NULL
  AND NOT EXISTS { MATCH (:Point)-[:PATH {name:'performs'}]->(s) }
RETURN s.name AS step, s.type AS kind
```
Overlaps `atlas-auditing` check 6. Kept here because the interview question differs: the audit asks "fix this", the interview asks "who owns it?"

**C3. No input.** *"What has to exist before this can start?"*
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review'] AND s.deletedAt IS NULL
  AND NOT EXISTS { MATCH (s)-[:PATH {name:'needs_input'}]->() }
RETURN s.name AS step
```

**C4. No output.** *"What exists after this that did not before?"*
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review'] AND s.deletedAt IS NULL
  AND NOT EXISTS { MATCH (s)-[:PATH {name:'creates_output'}]->() }
RETURN s.name AS step
```
C3 and C4 are the two most commonly skipped questions in a first pass and the two that most often reveal a missing step between two modelled ones.

**C5. No sequence.** *"What comes before and after?"*
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review','Handoff'] AND s.deletedAt IS NULL
WITH s,
  EXISTS { MATCH ()-[i:PATH]->(s) WHERE i.name IN ['followed_by','followed_by_if'] } AS has_in,
  EXISTS { MATCH (s)-[o:PATH]->() WHERE o.name IN ['followed_by','followed_by_if'] } AS has_out
WHERE NOT (has_in AND has_out)
RETURN s.name AS step, has_in AS has_predecessor, has_out AS has_successor
```
Reports partial sequencing, not just total absence. A step with only an inbound edge is either the end of the process or a dead end nobody noticed. Distinguish start and end nodes by hand.

**C6. Conditional path with no condition.** *"Under what circumstances does this branch fire?"*
```cypher
MATCH (a:Point {atlasId:$atlasId})-[r:PATH {name:'followed_by_if'}]->(b:Point)
WHERE a.deletedAt IS NULL AND b.deletedAt IS NULL
  AND (r.condition IS NULL OR trim(r.condition) = '')
RETURN a.name AS from_step, b.name AS to_step
```
The ontology declares `condition` required on `followed_by_if` and the create modal enforces it, so this should be empty on anything built through the UI. It is here to catch paths written around the validator - MCP batch writes, migrations, imports - where an unconditional conditional is invisible and silently makes a branch untraceable.

**C7. Decision with a single outgoing branch.** *"What happens in the other case?"*
```cypher
MATCH (d:Point {atlasId:$atlasId, type:'Decision'})
WHERE d.deletedAt IS NULL
WITH d, count { (d)-[o:PATH]->() WHERE o.name IN ['followed_by','followed_by_if'] } AS branches
WHERE branches < 2
RETURN d.name AS decision, branches
```
A decision with one exit is not a decision. Either the other branch was never modelled, or the node is a Step wearing the wrong type. This is one of the highest-yield questions on the list because the missing branch is almost always the exception path, which is where the actual work happens.

**C8. No provenance.** *"Where did we learn this?"*
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review','Handoff','Process'] AND s.deletedAt IS NULL
  AND NOT EXISTS { MATCH (s)-[:PATH {name:'extracted_from'}]->(:Point {type:'Document'}) }
RETURN s.name AS node, s.type AS kind
```
The trust question. A node with no `extracted_from` is somebody's recollection. That may be fine, but the customer should know which parts of their own map are sourced and which are hearsay.

**C9. No attached document.** *"Is there a form, template, or SOP for this?"*
```cypher
MATCH (s:Point {atlasId:$atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review'] AND s.deletedAt IS NULL
  AND NOT EXISTS { MATCH (s)-[:PATH {name:'has_attachment'}]->(:Point {type:'Document'}) }
RETURN s.name AS step
```
Distinct from C8. `extracted_from` is where the *model* came from; `has_attachment` is the artifact the *worker* needs.

### Process

**C10. Process with no steps.**
```cypher
MATCH (p:Point {atlasId:$atlasId, type:'Process'})
WHERE p.deletedAt IS NULL
  AND NOT EXISTS { MATCH (p)-[:PATH {name:'has_step'}]->() }
RETURN p.name AS empty_process
```
A named process with no steps is a placeholder someone intended to come back to. It is the single highest-signal absence in the whole sweep.

**C11. Process with nobody accountable.**
```cypher
MATCH (p:Point {atlasId:$atlasId, type:'Process'})
WHERE p.deletedAt IS NULL
  AND NOT EXISTS { MATCH (:Point)-[:PATH {name:'accountable_for'}]->(p) }
RETURN p.name AS unowned_process
```
Note the deliberate distinction from C2: `performs` is who does the work, `accountable_for` is who answers for the outcome. A process can be fully staffed and still have nobody accountable, and that gap is usually real rather than a modelling slip.

**C12. Process with no trigger.** *"What makes this start?"*
```cypher
MATCH (p:Point {atlasId:$atlasId, type:'Process'})
WHERE p.deletedAt IS NULL
  AND NOT EXISTS { MATCH (:Point {type:'Trigger'})-[:PATH {name:'initiates'}]->(p) }
  AND NOT EXISTS { MATCH ()-[i:PATH]->(p) WHERE i.name IN ['followed_by','followed_by_if'] }
RETURN p.name AS process_with_no_start
```
Excludes processes started by an upstream process, so what remains is genuinely unexplained: work that appears to happen for no stated reason. Usually the answer is a schedule, an inbound message, or a threshold nobody thought to write down.


### Person and Position

**C13. Person with no position.**
```cypher
MATCH (p:Point {atlasId:$atlasId, type:'Person'})
WHERE p.deletedAt IS NULL
  AND NOT EXISTS { MATCH (p)-[:PATH {name:'has_role'}]->(:Point {type:'Position'}) }
RETURN p.name AS person_without_role
```
People attach to work through Positions. A Person with no `has_role` is disconnected from every process they actually touch.

**C14. Position that performs nothing and is accountable for nothing.**
```cypher
MATCH (pos:Point {atlasId:$atlasId, type:'Position'})
WHERE pos.deletedAt IS NULL
  AND NOT EXISTS { MATCH (pos)-[r:PATH]->() WHERE r.name IN ['performs','accountable_for'] }
RETURN pos.name AS position_with_no_work
```

### System and Vendor

**C15. System with no vendor.**
```cypher
MATCH (sys:Point {atlasId:$atlasId, type:'System'})
WHERE sys.deletedAt IS NULL
  AND NOT EXISTS { MATCH (sys)-[:PATH {name:'provided_by'}]->(:Point {type:'Vendor'}) }
RETURN sys.name AS system_without_vendor
```
Legitimately empty for genuinely in-house systems - which is itself the answer to the question, and worth recording rather than leaving blank.

**C16. System nothing uses.**
```cypher
MATCH (sys:Point {atlasId:$atlasId, type:'System'})
WHERE sys.deletedAt IS NULL
  AND NOT EXISTS { MATCH ()-[:PATH {name:'uses_resource'}]->(sys) }
RETURN sys.name AS unused_system
```
Either a step is missing, or the system is shelfware. Both are worth saying out loud to a customer.

### Level placement

**C17. Same resource asserted at both process and step level.**
```cypher
MATCH (p:Point {atlasId:$atlasId, type:'Process'})-[:PATH {name:'uses_resource'}]->(sys:Point)
MATCH (p)-[:PATH {name:'has_step'}]->(s:Point)-[:PATH {name:'uses_resource'}]->(sys)
WHERE p.deletedAt IS NULL AND s.deletedAt IS NULL AND sys.deletedAt IS NULL
RETURN p.name AS process, s.name AS step, sys.name AS resource
```
This is the "one or the other, not both" rule. The convention is that dependencies live on the leaf step and the process derives by rollup (`atlas-auditing` check 1 treats a process-level `uses_resource` as a violation). This check finds the duplicative case specifically, which reads as agreement rather than error and so survives the violation sweep.

### Ambiguity (where the model had to squint)

**C18. The squint report.** Three queries, one question: *where was the ontology not quite right, and how did we paper over it?*

**(a) Where the optional path name was used as an escape hatch.** `name` on a relationship is the ontology type; `displayName` is the optional user-facing label that overrides the pill (see `getPathDisplayLabel`). A populated `displayName` means someone reached for a type that was close but not right and relabelled it.
```cypher
MATCH (a:Point {atlasId:$atlasId})-[r:PATH]->(b:Point)
WHERE a.deletedAt IS NULL AND b.deletedAt IS NULL
  AND r.displayName IS NOT NULL AND trim(r.displayName) <> ''
  AND r.displayName <> r.name
RETURN r.name AS ontology_type, r.displayName AS relabelled_as,
       a.name AS from_node, b.name AS to_node
ORDER BY ontology_type
```

**(b) Generic types carrying the load.** A high count on the unconstrained catch-alls means meaning is living in prose instead of structure.
```cypher
MATCH (a:Point {atlasId:$atlasId})-[r:PATH]->(b:Point)
WHERE a.deletedAt IS NULL AND b.deletedAt IS NULL
  AND r.name IN ['part_of','uses_resource','located_in','impacts','is_a']
RETURN r.name AS generic_type, count(*) AS uses
ORDER BY uses DESC
```

**(c) Nodes carrying no description.** With a generic type and no description, a node cannot be disambiguated by any reader, human or agent.
```cypher
MATCH (n:Point {atlasId:$atlasId})
WHERE n.deletedAt IS NULL
  AND (n.description IS NULL OR trim(n.description) = '')
RETURN n.type AS kind, count(*) AS undescribed
ORDER BY undescribed DESC
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

Run Part 1 as a single batch regardless of atlas size - the queries are cheap. Part 2 needs the whole picture in one context to catch cross-step gaps, so keep it as one pass while the atlas fits. Split by process (not by point type) only when it does not, since splitting by type destroys exactly the input/output continuity that Part 2 exists to find.

## Related

- `atlas-auditing` - the violation sweep. Run it first; wrong beats thin.
- `atlas-modeling` - the three principles, including variables-as-points.
- `atlas-language` - the typed vocabulary and what may legally connect to what.
