---
name: atlas-language
description: The Atlas language - Graphite Atlas's typed vocabulary of Point types, Path types (with source→target constraints + multiplicity), Properties, and the default folder structure. Use whenever you need to know what types exist or what can legally connect to what: before creating/validating Points or Paths, when picking a relationship type, when modeling a process/org/metric tree, when structuring a new atlas (which default folder a view/point belongs in), or when a non-Atlas Claude session needs the Atlas vocabulary. Pairs with `atlas-modeling` (the modeling principles).
---

# The Atlas Language (reference)

*The Atlas language is the typed vocabulary of Points and Paths.*


Atlas is a typed knowledge graph: **Points** (nodes) connected by **Paths** (edges), conforming to this ontology. Every Point and Path has a `category`; Paths carry source→target type constraints and a multiplicity. The authoritative, current definition lives in your Atlas — call the `lookup_ontology` tool for the exact spec of any type, including descriptions, usage guidance, and examples. The tables below are the working summary.

For *how to model well* (naming, attachment, typing), use the companion **`atlas-modeling`** skill and its sub-skills. This skill is **what exists**; that one is **how to use it**.

## Point types (nodes), by category

Glosses below are the working summary; call `lookup_ontology` for full descriptions.

- **Action:** `Process` (named end-to-end workflow; container of ordered Steps), `Step` (a discrete unit of work; the generic action node), `Decision` (a choice among options; the `result` property captures the pick), `Approval` (a required sign-off before the process continues), `Review` (work evaluated for quality/compliance, no go/no-go gate), `Handoff` (explicit transfer of ownership between actors)
- **Actor:** `Person` (an individual human), `Position` (a role/title independent of who fills it, e.g. CFO), `Group` (a named collection of people, e.g. Finance Team), `Organization` (a legal/business entity), `Vendor` (an external supplier/provider), `Agent` (an autonomous AI actor)
- **Resource:** `System` (software/infrastructure actors use), `Artifact` (a document/file/data object produced or consumed by a step), `Document` (an uploaded file/attachment: PDF, image, transcript), `Equipment` (physical hardware/machinery), `Policy` (a governing rule/standard to follow), `Skill` (a capability an actor has; for Agents wraps an MCP server/tool)
- **Outcome:** `Outcome` (a goal/OKR being worked toward), `Metric` (a quantified measurement of performance), `Risk` (a threat/uncertainty that could harm an outcome)
- **Accounting / Treasury:** `Account` (a chart-of-accounts line, e.g. Revenue, COGS), `Bank Account` (a specific account at a financial institution; links to chart-of-accounts Accounts)
- **Location:** `Physical Site` (a physical place where work happens: office, warehouse, store)
- **Time:** `Date` (a time point, absolute or relative), `TimeRange` (a bounded period, e.g. Q3 2026), `Trigger` (what initiates an actor to act: schedule, event, manual invocation)

## Path types (edges) - source → target

A Path with `any` on a side is unconstrained **in the ontology** on that side. Important: only 6 paths below actually carry source/target constraints (`accountable_for`, `provided_by`, `extracted_from`, `has_context`, `has_attachment`, `triggered_by`); the rest have empty constraint arrays, so the validator treats them as `any → any`. **`any` means "the ontology doesn't enforce a type here," not "any pairing is sensible."** For paths without enforced constraints, the intended pairings are: `reports_to` is conceptually Position→Position, `performs` Actor→Step, `has_step` Process→Step, `has_role` Person→Position, `member_of` Person→Group, `uses_resource` Step→System/Equipment, **`has_child` Account→Account only — chart-of-accounts roll-up, pair with `rolls_up`; not a generic parent-child, see anti-patterns**). For intended usage follow the `atlas-modeling` skill.

| Path | Source → Target | Multiplicity |
|------|-----------------|--------------|
| `has_child` | any → any | many-to-many |
| `maps_to` | any → any | many-to-many |
| `rolls_up` | any → any | many-to-many |
| `creates_output` | any → any | many-to-many |
| `followed_by` | any → any | many-to-many |
| `followed_by_if` | any → any | many-to-many |
| `from_person` | any → any | many-to-many |
| `handoff_of` | any → any | many-to-many |
| `has_step` | any → any | many-to-many |
| `performs` | any → any | many-to-many |
| `to_person` | any → any | many-to-many |
| `accountable_for` | Person, Position → Outcome, Process, Step | many-to-one |
| `has_interest` | any → any | many-to-many |
| `has_role` | any → any | many-to-many |
| `has_skill` | any → any | many-to-many |
| `has_subsidiary` | any → any | many-to-many |
| `member_of` | any → any | many-to-many |
| `reports_to` | any → any | many-to-many |
| `extracted_from` | any → Document | many-to-many |
| `has_context` | Agent → Document | many-to-many |
| `is_a` *(schema/meta - not for data graphs)* | any → any | many-to-many |
| `part_of` *(schema/meta - not for data graphs)* | any → any | many-to-many |
| `triggered_by` | Agent, Person, Position, Group → Trigger | many-to-many |
| `located_in` | any → any | many-to-many |
| `has_risk` | any → any | many-to-many |
| `impacts` | any → any | many-to-many |
| `measured_by` | any → any | many-to-many |
| `mitigates` | any → any | many-to-many |
| `has_attachment` | any → Document | one-to-many |
| `needs_input` | any → any | many-to-many |
| `provided_by` | System → Vendor | many-to-one |
| `uses_resource` | any → any | many-to-many |
| `happens_after` | any → any | one-to-many (directed) |
| `happens_before` | any → any | one-to-many (directed) |
| `has_deadline` | any → any | many-to-many |
| `simultaneous_with` | any → any | many-to-many (bidirectional) |

## Properties

32 typed properties attach key/value data to Points (e.g. `condition` on `followed_by_if`, dates, amounts, status). They live **on the Point/Path**, never as separate nodes. Call `lookup_ontology` for the full property list with `applicableToTypes`.

## Default atlas structure (folders)

A new atlas opens with six **default folders** (user-editable) that organize its views by aspect. Use this map to decide which folder a view belongs in, and when Nav generates a view, file it into the matching folder.

| Folder | Point types | Key path types | Example maps (1-2 word names) |
|--------|-------------|----------------|-------------------------------|
| **People** | Person, Position, Group | `has_role`, `member_of`, `reports_to`, `performs`, `accountable_for` | Org, Leadership, Teams, RACI |
| **Entities** | Organization, Vendor, Account, Bank Account | `has_subsidiary`, `provided_by`, `located_in` | Entities, Ownership, Banking |
| **Business Model** | Organization (as customer), Outcome | `has_interest` | Customers, Products, Value |
| **Process** | Process, Step, Decision, Approval, Review, Handoff, Trigger | `has_step`, `followed_by`, `followed_by_if`, `performs`, `needs_input`, `creates_output`, `handoff_of`, `triggered_by` | Intake, Payoff, Onboarding (one per flow) |
| **Systems** | System, Artifact, Document, Equipment, Skill | `uses_resource`, `provided_by`, `creates_output`, `has_attachment`, `extracted_from`, `has_context` | Stack, Systems, Integrations |
| **Metrics** | Outcome, Metric, Risk | `impacts` (driver tree), `measured_by`, `has_risk`, `mitigates`, `rolls_up`, `accountable_for` | KPIs, Outcomes, Risks |

- **People vs Entities:** keep the *human* org (People: who reports to whom) separate from the *legal/corporate* org (Entities: which company owns which). Ownership/`has_subsidiary` structure belongs in Entities, never People.
- **Business Model modeling:** model a **customer** as an `Organization`; do not invent a `Customer` type. Model a product / product-line as `Group` with `member_of` (product `member_of` line), and a market as `Organization`. Do **not** use `impacts` for product→market (that's the metric driver-tree type - see the displayName anti-pattern).
- **View AND folder names: one or two words, a clean noun.** Think financial-model tabs (`Inputs`, `BS`, `CF`). **Banned:** `&`, `+`, `:`, `/`, and verbose AI-generated "slop" titles (`How X Works`, `X & Y Candidates`, `Specify to Install`). A `&`/`+` joining two concepts is a **smell that it should be two views** — split it (`Systems & Data Flow` → `Systems` + `Data Flow`). Examples of the fix: `Order Lifecycle: Specify to Install` → `Lifecycle`; `Org & AI-Augmentation Candidates` → `AI Roles`; `Product Lines & Manufacturing` → `Products`; `How Forms+Surfaces Works` → `Overview`. This applies to anything Nav names — views and folders alike.

## Key modeling patterns

*Modeling judgment and anti-patterns (naming, attachment, typing — with ✓/✗ examples) live in `atlas-modeling`. This section is vocabulary-level composition only: which path types build which structures.*

- **Process flow:** a `Process` owns its steps via `has_step` (membership); order them with `followed_by`. A conditional branch is `followed_by_if` with a `condition` property; a loop is a `followed_by_if` that points back upstream. Use `Decision` for a choice point and `Approval` for a sign-off - not a generic `Step`.
- **Actors:** `Person` `has_role` `Position`; `Person` `member_of` `Group`; `Position` `reports_to` `Position`; an actor `performs` a `Step`; RACI accountability is `accountable_for` → `Outcome`/`Process`/`Step`. An `Agent` (AI) is a unified actor - it uses the same paths (e.g. `performs`), with its skill doc attached via `has_context`.
- **Resources:** attach `uses_resource` to the **atomic leaf Step**, not the parent Process. A service is a `System` reached `provided_by` a `Vendor` - never Step → Vendor. Documents/messages are `Artifact`s, produced via `creates_output` (not Systems).
- **Metrics:** `impacts` edges between `Metric`s form an impact/driver tree.
- **Orgs:** `Organization` `has_subsidiary` `Organization` for legal-entity structure.
- **Instances vs singletons:** each flow's actions are their own per-flow `Step` nodes; entities (a System, a Position, a Vendor) are shared singletons. Never wire one action node into multiple flows.

## Anti-patterns to avoid

- **Loose steps:** a `Step` sequenced via `followed_by` but with no `has_step` from its owning `Process`. It's a member in spirit but invisible to membership queries and generated docs. Always wire `has_step`.
- **Identity baked into a name:** "Rippling Payroll System" hard-codes the vendor. Name by **function** ("Payroll System") and put identity on an edge (`provided_by` → Rippling).
- **`uses_resource` on the Process** instead of the leaf step → rollups can't tell which of N steps actually uses the resource.
- **Step → Vendor directly**, or treating an `Artifact` (EDI/NACHA/forms, messages, files) as a `System`.
- **Facts in prose** that have a structural home (an unattached "the distributor allocates the part" instead of a `performs` edge).
- **Reusing one action node across flows** (actions are per-flow instances).
- **Confusing label with type:** a path's *type* is `Path.name` (the ontology value, e.g. `followed_by_if`); the human label is `displayName`. Set `displayName` for a custom label - never repurpose the type.
- **`displayName` that contradicts the path type (house principle):** a `displayName` must *align with* and add context to the underlying path type - never contradict or vague-ify it. Example violation: labeling an `impacts` edge (the metric driver-tree relationship) `serves` to express product→market. `impacts` does not mean "serves," so the label contradicts the type. If no path type fits the meaning, that's a signal a path type is **missing** (file it), not a license to relabel a wrong one.
- **`has_child` for generic parent-child:** `has_child` is **only** for chart-of-accounts hierarchies (parent `Account` → child `Account`, pair with `rolls_up`). Do **not** use it for a product line → product, department → sub-department, or process → sub-process hierarchy. Use the right path per case: `member_of` for collection membership (incl. product families), `has_step` for process structure, `has_subsidiary` for legal-entity ownership.
- **Using `is_a` / `part_of` in the data graph:** those are schema/metagraph (meta) relationships, not user-data paths.
- **Ignoring source/target constraints:** e.g. `accountable_for` only targets `Outcome`/`Process`/`Step` - it can't point at an `Organization`.

