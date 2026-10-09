---
name: atlas-modeling
description: Use before any write to a Graphite Atlas (creating, updating, or deleting Points or Paths; proposing schema changes; modeling a new process from a transcript, screenshot, or interview). Surfaces the three modeling principles, each with its anti-pattern examples inline so they are always in context; deeper worked examples live in `references/`. Invoke once per atlas-mutation session.
---

# Atlas modeling

Three principles. Most modeling mistakes are a violation of one of them, so hold all three as you
build or edit an Atlas. Each has its anti-pattern examples inline below, so you don't need to invoke
anything else; deeper worked examples are in `references/`.

*Terms: Atlas calls graph nodes **Points** and edges **Paths**. This skill uses Points and Paths.*

## Which skill answers your question

This one is the default and usually enough. Escalate only when it genuinely does not answer:

| You are | Use |
|---|---|
| Modelling something (the common case) | **this skill**: the three principles below |
| Unsure a type or path exists, or what may connect to what | `atlas-language`, or `lookup_ontology`, which reads live |
| Refused by the ontology, or unable to say something true about the business | `atlas-language`, for what is sayable and what may connect. If the thing you need has no type, that is a gap to report, not one to model around |
| Building from a PDF, transcript or spreadsheet | `atlas-build` FIRST, for what Atlas can read and the attach-then-cite ordering |
| Ready to show a human before writing | `atlas-build`, step 4 |
| Writing the approved change, and it is more than ~20 points or paths | `atlas-build`, step 5: go over the HTTP API, not through individual tool calls |
| Finished writing | `atlas-auditing` for violations, `atlas-completeness` for absences |

**Record a convention when you settle it, not after it has been settled twice.** The same
questions arrive repeatedly and get answered slightly differently each time, which is invisible
within one session and obvious across an atlas. Keep the answers somewhere they can be reread.

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

3. **Describe the business, not the model or its source.** A description says what the thing IS in
   the customer's world: what a phase achieves, what a team or role does. Never what it looks like in
   a diagram ("a lane", "a swimlane", "opens in"), which page or file it came from ("built from the
   PDF", "page 2"), or the source's own heading pasted in as prose. Provenance lives on `extracted_from`
   citations; a source's title belongs in `aliases` if people say it out loud.

```
X  Group "Steering Committee", description: "A lane in the PMO Flow."     (describes the drawing)
X  Process "Charter and Change Council", description: "Definition and Planning to Council."
                                                                  (the page title, not what happens)
X  atlas description: "Built from the intake workflow deck."           (provenance, not the business)
V  "Committee that decides whether a project goes ahead on its cost-benefit case."
V  "Sets up the approved project with a charter and a complexity assessment, and gets the
    go-ahead to define requirements."
```

The same holds for view and atlas descriptions: a view describes the part of the business it shows,
not how it renders.

Allowed in descriptions: facts with no structural home in the ontology (e.g. "primary regulator" where
no regulates Path type exists), ILLUSTRATIVE/placeholder flags, and operational ATTACH notes.

### Property governance

Do not invent a property to give explanatory prose the appearance of structure. A
relationship belongs in a Path, a fact about the point belongs in its description, and a
defined property is for a value some query, rule or automation reads consistently.

Before proposing a new property, state its name, meaning, applicable types, value type
and cardinality, an example, and what consumes it. Approved conventions, including
`fields` on `needs_input`: `references/property-governance`.

### An action is a verb and an object

**A Step, Review, Approval or Handoff is named by what someone DOES: a verb and its object.** A noun
phrase is a topic, not an action. "Business Costs" could be a document, a number, a meeting or a task;
nobody can tell what is done, or when it is finished. The test: **could someone be told to do it, and
say when they had?** If the name only makes sense with a verb added in your head, add the verb.

```
X  "Business Costs"                 V  "Estimate Business Costs"
X  "Technology Impact Review"       V  "Review Technology Impact"
X  "Client Engagement"              V  "Engage Clients"
X  "Completion of Benefits"         V  "Confirm Benefits Delivered"
X  "Steering Committee Approval"    V  "Approve Project"        (performed by Steering Committee)
```

- **Who does it is not in the name.** The performer is a `performs` path, so "Approve Project" plus
  the Steering Committee, not "Steering Committee Project Approval".
- **A Decision names the check, as a verb or a question:** "Check UAT Result", "Check Cost Against
  Initial Estimate", not "UAT Pass". The outcomes live on the `followed_by_if` branches.
- **Every `followed_by_if` carries a `displayName`**, and that is what the canvas draws on the arrow.
  Write it as "If <short condition>", or **"Always"** for an inclusive branch that always happens.
  The `condition` property still states the rule in full; `displayName` is the half a reader sees.
  A Decision whose outcomes are unlabelled arrows is a diagram that asks a question and shows no
  answers, and the condition being populated does not fix it, because nothing renders it.
  `displayName` is a **native field on the Path, not a property**, so it is set and read separately
  from `condition` and does not appear in a properties blob. This holds throughout,
  for every conditional branch.

```
✗  Check Open Items ─followed_by_if→ Collect Closing Docs    displayName: (none)
     condition: "all items cleared"                          (true, and invisible on the canvas)
✓  Check Open Items ─followed_by_if→ Collect Closing Docs    displayName: "If cleared"
     condition: "Every open item signed off by the account owner"
```

- **Keep the source's label as an alias** when it is what people say ("QC Pass", "Business Impact
  Review"), so search finds it and a citation quoting the source still reads naturally.
- A diagram box label is usually the noun form. Transcribing it verbatim is where this goes wrong
  most often: the shape told the reader it was an action, and the name alone does not.

### 1a. Abbreviations

Name a point with the words a stranger can read; put the short form in `aliases`, so
search finds it either way. "Field Operations Support", aliased "FO Support", not the
reverse. An abbreviation in the name costs every future reader a lookup.

Worked examples, including when a customer's own abbreviation is the better name:
`references/abbreviations-and-aliases`.

### 1b. Suffixes are a disambiguator, not a house style

When two Points must share a natural name because they are genuinely different things, suffix
BOTH with what they are, and only then.

```
✓  "Construction Management Process"  (Process, holds the work)
✓  "Construction Management Team"     (Group, holds the people)
```

Do not append a type suffix to a name that is already unique. A suffix on every Point is noise and
makes the map harder to read, not clearer.

**Why this is not cosmetic: `batch_create` resolves path endpoints BY NAME.** Two Points sharing a
name means the write picks one, silently, and it may be the wrong type. A `has_step` aimed at a
Group fails validation; worse cases succeed and attach work to the wrong Point. Run a duplicate-name
check before any batch write.

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

**Where the system attaches: the artifact, or the tool the step runs in. Never by inference.**
A step that fills in a spreadsheet does not "use Excel"; the spreadsheet lives in Excel. Put
the system on the artifact, and the step reaches it through what it creates or needs:

```
✗  Complete Request Scoring Sheet ─uses_resource→ Excel        (inferred from the document)
✓  Complete Request Scoring Sheet ─creates_output→ Request Scoring Sheet
   Request Scoring Sheet ─uses_resource→ Excel                  (the document lives there)

✗  Send Report to Client ─uses_resource→ Microsoft Outlook     (a mail client hung on a step
                                                               that merely sends; vendor in the name)
✗  Send Report to Client  properties: channel: email           (a fact with a structural home,
                                                               written as prose)
✓  Report ─uses_resource→ Email (System) ─provided_by→ Microsoft
   (the document travels by email; the step reaches Email through what it sends)
✓  Monitor Claims Inbox ─uses_resource→ Email                  (the step IS watching a mailbox,
                                                               so the tool belongs to the step)
```

A step that reads specific facts out of a document puts them on the `needs_input` Path, one Path
per source document:

```
✗  Enter Client Details ─needs_input→ Signed Order Form        (reads it, but takes what from it?)
✗  Enter Client Details ─needs_input→ Signed Order Form
     fields: [legal entity, billing terms, account manager]    (the manager is in the email, not the
                                                               form: the union asserts something false)
✓  Enter Client Details ─needs_input→ Signed Order Form  fields: [legal entity, billing terms]
✓  Enter Client Details ─needs_input→ Handoff Email      fields: [assigned account manager]
```

"Which document does this field come from" is the question an automation answers before it can do
the step at all. Reference: `references/fields-on-inputs`.

How a thing moves is a relationship, not a property. `channel:` on a point restates an edge
that should exist, and then the two desync. The same holds for "lives in a shared folder":
`Artifact -uses_resource-> Dropbox`, never `location: Dropbox`.

A step carries `uses_resource` itself only when the step is **performed inside a tool**, and
then the target is the **module**, not the suite, reached `provided_by` its Vendor:

```
✗  Review and Approve Request ─uses_resource→ WorkSuite        (a suite of thirty tools)
✓  Review and Approve Request ─uses_resource→ WorkSuite Approvals ─uses_resource→ WorkSuite
   WorkSuite Approvals ─provided_by→ WorkSuite                  (display_name: module)
```

Test: *could the step be done with the document open in a different application?* If yes, the
system belongs to the document. If the step cannot exist without the tool (a workflow
approval, a site check in a field quality app, an e-signature), the tool belongs to the step. Then "what
runs on Excel" answers through artifacts and "what runs in WorkSuite Approvals" through steps,
and neither answer contains a guess.

This is **pass 3** of the build (below), and the coverage question for it is two questions,
not one: does every artifact have a system, and does every in-tool step name its module.

**Granularity test (actions and artifacts alike).** If a Step's description enumerates several actions
("prepare X, obtain Y, and complete Z"), those are sub-steps hiding in prose — promote the Step to a
Process and give each action its own Step, especially when the actions have *different* performers.
Correspondingly, a bundled Artifact splits into component Artifacts exactly when a distinct step or
actor produces each component; components produced by one actor in one step stay as prose in the
parent Artifact's description. Apply the line consistently, or the graph says "these components are
nodes" and "those are text" with no principle behind it.

### 2a. A view is a unit of review

A flow view holds one subgraph a person can check in one look. When a process view
grows past that, the view is the symptom and the undecomposed process is the disease.
Fix it upstream: promote the phases to child Processes, wire `parent -has_step-> child`,
and give each child its own view in a folder named for the parent. Splitting the picture
alone leaves a thirty-step process pretending to be atomic, and every later query
inherits that.

Where to cut, the spine view, entry and exit boxes, and the checks:
`references/view-decomposition` and `references/large-process-decomposition`.

### 2b. Reference documents

A `Document` is a file that was uploaded, so a Document point with no bytes behind it
contradicts its own type. Which type a referenced document gets depends on whether the
file is in the atlas: hold the file and it is a `Document`; name an authority you only
link to and it is an `Artifact` carrying a `url`.

The full table, and how each is attached: `references/reference-documents`.

### A rule that governs a step is a Policy, not only a branch

When a source states a rule the step must follow, model the rule as a `Policy` point that
the step reads with `needs_input`. Add a branch only where the path through the process
actually differs.

```
✗  Check Eligibility --followed_by_if--> ... one branch per jurisdiction
     (fifteen branches that all rejoin, encoding the rules as flow)
✓  Check Eligibility --needs_input--> "Eligibility Rules: <jurisdiction>" (Policy)
     plus one branch where the process genuinely diverges
```

The rules are then readable, citable and editable in one place, and the flow stays the
shape of the work. A branch per rule buries the rule in the topology, where changing it
means redrawing the process.

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

## Build in passes, not in one sweep

A room, a transcript or a document gives you **sequence** first, because that is how people
tell a story: what happens, then what happens next. It almost never gives you inputs,
outputs, systems or measures unless asked. So a model built in one sweep from a live source
arrives with the order right and everything else missing. Measured on a real session: 193
actions captured, 113 with neither an input nor an output, 142 with no system.

Model in four passes, each a question asked of every action, and do not call the build
done before pass 4:

1. **Sequence.** What happens, in what order, who performs it. This is the capture.
2. **Inputs and outputs.** For every action: what does it need, what does it produce. Most
   answers are already in the action's own name ("Complete Request Scoring Sheet"
   produces the Request Scoring Sheet). Where the artifact has no Point, that is
   the moment to create it: a real document, not a phrase.
3. **Systems.** For every artifact: where does it live (`Artifact -uses_resource-> System`).
   For every action performed inside a tool: which module (`Step -uses_resource-> Module`,
   module `provided_by` vendor). A step that only touches a document gets no system edge of
   its own; it reaches the system through the document. This pass has the least source
   evidence, so mark inferences `draft` and leave gaps visible rather than guessing.
4. **Measures.** For every process: what number says it went well, and which step produces
   that number. Attach the metric to the producing step, not to the report that displays it.

Each pass is a query you can run before and after ("actions with no output", "artifacts
with no system"), so progress is a count, not a feeling. The counts are also the honest
statement of what the source did not say, which belongs in the proposal as gaps.

## Show it before you write it

**A model a human has not seen is not agreed to.** Before writing points and paths to an atlas,
render the proposal and let them read it: what gets created, what is reused, what could not be
staged, and the passage each point came from. They say build; then you write exactly that.

If you have an Atlas, the app's own proposal screen does this: it reads the staged revision and
shows you the change before it is applied. From an agent, put whatever you can in front of the
person: a rendered document, a file-based mock of the folders and views, or a plain list of the
Points and Paths you are about to create. Skip it only when the change is a one-off edit to a
single existing point that is trivially reversible.

**Then write it over the HTTP API if it is large.** Past roughly twenty points or paths,
composing individual tool calls means emitting every payload into the conversation and receiving it
back again; one real build burned about 150,000 tokens that way before switching. Read the API's own
definitions rather than assuming the tool arguments carry across: **the HTTP payload shapes differ
from the MCP tool shapes**. Check the batch for duplicate names and unverifiable quotes before
sending. How the approved change is written never changes whether it was approved.

## Building from documents

When the source of the model is a document (a PDF, a spreadsheet, an SOP) rather than a
conversation, invoke `atlas-build` BEFORE writing anything. Attaching the file and
citing it still has an ordering requirement, but it is now enforced rather than silent: a
write whose citations point at a document that is still being indexed is refused with a
409 naming the document, and nothing is stored. Wait for indexing to finish and send it
again. A quote that does not appear in a FINISHED document is still dropped without
comment, and the path is written without it, because a confidently wrong highlight costs
more than a missing one.

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

**Check what exists before creating folders.** A new atlas
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
