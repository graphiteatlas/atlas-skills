# Property governance: reuse definitions, not arbitrary keys

**Do not invent a property to give explanatory prose the appearance of structure.**
`review_considerations`, `review_topics`, and `review_checks` are not three useful conventions
merely because the API accepts them. Structure over prose means modeling relationships as Paths;
it does not mean turning every sentence or checklist into a new field.

Choose the representation by purpose:

- **Typed Paths:** performers, inputs, outputs, systems, membership, and dependencies. Do not
  hide these in descriptions or custom properties.
- **Description:** concise factual scope and explanatory review criteria belonging to the Point.
  Do not duplicate facts already represented by Paths or defined properties.
- **Defined properties:** values that a concrete query, validation rule, comparison, or automation
  needs to consume consistently. Reuse the ontology or an explicitly approved modeling convention;
  an arbitrary existing key is not proof that it is a standard.
- **Reference material:** long checklists, instructions, diagrams, and illustrative cases. Preserve
  them in an appropriately linked Artifact or uploaded Document, following section 2b. Distinct
  actions with their own performers, inputs, or outputs still deserve Steps, not a buried checklist.

Before proposing a new property, state its **name, meaning, applicable Point/Path types, value
type and cardinality, allowed values or units where relevant, example, and intended consumer**.
Check existing definitions for synonyms. Show the proposed convention for approval before using
it as an established field. Record an approved definition once in the appropriate shared or
account-specific modeling rules; do not silently extend the global ontology for one account.

**Approved conventions** (recorded here per the rule above, not added to the global ontology):

| | |
|---|---|
| **name** | `fields` |
| **applies to** | `needs_input` Paths; optionally `creates_output` |
| **value** | list of strings, the facts the step reads from that document |
| **cardinality** | one `needs_input` per source document, each listing only its own fields |
| **consumer** | agent and automation design (which document supplies which field), and the inference register |
| **example** | `needs_input → Signed Order Form`, `fields: [legal entity name, billing terms]` |

It passes the test above because a concrete consumer reads it: an automation cannot do a data-entry
step until it knows which document each field comes from. It is not a checklist given the appearance
of structure. Distinct from `columns`, which is a `Data Table`'s schema. Worked example and
anti-patterns: `references/fields-on-inputs`.

Illustrative examples:

```
✗ Review Request Scoring Sheet
    review_considerations: [score, current workload, team assignment]
✓ description: "Reviews the request score and current workload to inform team assignment."
  Keep the performer, sheet input, and subsequent assignment as typed Paths.

✗ Pre-Construction Meeting
    agenda_topics: [safety, access, payment, schedule, permits, ...]
  (a one-off field no consumer has agreed to read)
✓ A concise description of the meeting's scope; the detailed agenda stays in its reference.
  If agenda items must drive a checklist application, propose a defined schema first.

✗ Review Construction Sequence
    example_scope: "These diagrams are examples, not mandatory steps."
✓ Put that interpretation in the proposal/reference caption, not a new business-data field.

✓ Artifact ─uses_resource {usage_role: "storage"}→ Document Store
  When usage_role is an approved convention, it serves a real consumer: distinguishing
  storage from authoring or delivery. Do not replace that distinction with free-form prose.
```

**Migration is separate from the rule.** Do not delete existing custom properties or move their
values automatically. Inspect consumers and evidence, preserve information, and propose exact
before/after changes. A missing value stays missing; do not populate a field just to complete a table.

Deeper examples: `references/name-by-function.md`, `references/structure-over-prose.md`,
`references/instance-nodes.md` (actions are per-flow instances; entities are shared singletons — never
wire one action Point into two flows).
