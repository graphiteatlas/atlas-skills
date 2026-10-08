# Which Facts the Step Takes From Which Document

**Principle:** When a step reads specific facts out of a document, the document is a
`needs_input` Path and the facts it supplies are the `fields` property on that Path. One
`needs_input` per source document, each listing only its own fields.

**When this applies:** Any "person D enters A and B from document C into system X" step: data
entry, intake, setup, onboarding, reconciliation. Also any step whose automation you intend to
design, because this is the question an automation has to answer first.

**Do:**
- One Step, named by function: **Enter Project Details**. The system is reached by a Path, never
  part of the name (principle 1).
- `Person --performs--> Step`.
- `Step --uses_resource--> System`. If the system is a suite, point at the module and reach the
  vendor through `provided_by` on it (principle 2).
- `Step --needs_input--> Artifact` for each source document, carrying
  `fields: [<the facts read from that document>]`.

```
Enter Client Setup Details
  performed_by     Onboarding Coordinator
  uses_resource    Billing module  --provided_by--> <vendor>
  needs_input      Signed Order Form      fields: [legal entity name, billing terms]
  needs_input      Sales Handoff Email    fields: [assigned account manager]
```

Two documents, one step, and the split between them is the content.

**Don't (anti-pattern):** a single `needs_input` to each document with no `fields`, or one
`needs_input` carrying the union of every field across several documents. Both say the step reads
the document; neither says what it takes from it, and the union actively asserts something false,
that either document could supply any of the fields. Also don't put the field list in the Step's
description: it is a list of discrete facts with a consumer, which is what makes it a property
rather than prose.

**Litmus test:** *Which document does this field come from?* If the graph cannot answer that for
every field the step enters, the `fields` lists are missing or merged. *If one source document
changed, how many edges would I edit?* One.

**The mirror case,** optional and the same shape: `creates_output` may carry `fields` for the facts
a step writes.

**Not to be confused with `columns`**, which is the schema of a `Data Table` and describes the
store. `fields` is per-Path and describes what one step takes from one document on one flow: the
same document read by two steps can carry different fields on each.

**A field with no stated source is an inference.** If nobody said which document supplies it, say
so on the Path rather than letting the field list imply it was observed.
