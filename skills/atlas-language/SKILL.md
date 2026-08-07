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
- **Resource:** `System` (software/infrastructure actors use), `Database` (a structured data store holding tables of business records — SQL database, warehouse, or spreadsheet-backed store; a specialized System, is-a System), `Data Table` (a structured table/collection of records within a Database; columns, primary key, and schema live as properties), `Artifact` (a document/file/data object produced or consumed by a step), `Document` (an uploaded file/attachment: PDF, image, transcript), `Equipment` (physical hardware/machinery), `Policy` (a governing rule/standard to follow), `Skill` (a capability an actor has; for Agents wraps an MCP server/tool)
- **Business Model:** `Product` (an offering the business sells — physical product or service; group families via `member_of`), `Customer` (an organization or person that buys from the business)
- **Outcome:** `Outcome` (a goal/OKR being worked toward), `Metric` (a quantified measurement of performance), `Risk` (a threat/uncertainty that could harm an outcome)
- **Accounting / Treasury:** `Account` (a chart-of-accounts line, e.g. Revenue, COGS), `Bank Account` (a specific account at a financial institution; links to chart-of-accounts Accounts)
- **Location:** `Physical Site` (a physical place where work happens: office, warehouse, store)
- **Time:** `Date` (a time point, absolute or relative), `TimeRange` (a bounded period, e.g. Q3 2026), `Trigger` (what initiates an actor to act: schedule, event, manual invocation)

## Path types (edges) - source → target

A Path with `any` on a side is unconstrained **in the ontology** on that side. The core structural paths now carry enforced source/target constraints (shown in the table): `accountable_for`, `provided_by`, `extracted_from`, `has_context`, `has_attachment`, `reports_to`, `performs`, `has_step`, `has_role`, `member_of`, `owned_by`, `subaccount_of`, `has_table`, `joins_to`, `initiates`. The validator rejects new writes that violate them. Paths shown `any → any` have empty constraint arrays — **`any` means "the ontology doesn't enforce a type here," not "any pairing is sensible."** For unconstrained paths the intended pairing still matters: `uses_resource` is conceptually Step→System/Equipment. `lookup_ontology` now serves per-type usage guidance and examples, not just the raw spec — call it when the table isn't enough. For intended usage follow the `atlas-modeling` skill.

| Path | Source → Target | Multiplicity |
|------|-----------------|--------------|
| `creates_output` | any → any | many-to-many |
| `followed_by` | any → any | many-to-many |
| `followed_by_if` | any → any | many-to-many |
| `from_person` | any → any | many-to-many |
| `handoff_of` | any → any | many-to-many |
| `has_step` | Process → Step, Decision, Approval, Review, Handoff, Process | many-to-many |
| `performs` | any → Step, Decision, Approval, Review, Handoff | many-to-many |
| `to_person` | any → any | many-to-many |
| `accountable_for` | Person, Position → Outcome, Process, Step | many-to-one |
| `has_role` | Person → Position | many-to-many |
| `has_skill` | any → any | many-to-many |
| `member_of` | Person, Position, Organization, Agent, Group → Group | many-to-many |
| `reports_to` | Position, Agent → Position | many-to-many |
| `owned_by` | Organization, Customer → Organization | many-to-many |
| `subaccount_of` | Account → Account | many-to-one |
| `has_table` | Database → Data Table | one-to-many |
| `joins_to` | Data Table → Data Table | many-to-many |
| `initiates` | Trigger → Process, Step, Agent, Person | one-to-many |
| `extracted_from` | any → Document | many-to-many |
| `has_context` | Agent → Document | many-to-many |
| `is_a` *(schema/meta - not for data graphs)* | any → any | many-to-many |
| `part_of` *(schema/meta - not for data graphs)* | any → any | many-to-many |
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

Glosses for the newer paths:

- `has_table` — a Database contains a Data Table ("the data lives here"). Applications don't have tables; apps write TO databases.
- `joins_to` — two Data Tables can be joined; direction child→parent (the FK-holding table points at the referenced table), with the join condition in the edge description (e.g. `OrderLineItems.orderID → Orders.orderID`).
- `subaccount_of` — chart-of-accounts hierarchy, child Account → parent Account (QuickBooks/Xero vocabulary).
- `owned_by` — equity/legal ownership, owned entity → owner, with the `ownership_pct` property for partial stakes. Equity only: responsibility for a process or outcome is `accountable_for`.
- `initiates` — a Trigger (schedule, event, manual invocation) initiates a Process, Step, Agent, or Person acting.

**Retired paths** (unselectable for new writes; old edges in existing atlases still render): `has_child`, `rolls_up` and `maps_to` (COA hierarchy is now `subaccount_of`), `has_interest` and `has_subsidiary` (ownership is now `owned_by`), `triggered_by` (replaced by `initiates`, which flows from the Trigger outward). Do not create edges with these names.

## Properties

39 typed properties attach key/value data to Points and Paths (e.g. `condition` on `followed_by_if`, `execution_mode` on Step — `human` | `system` | `external`, `ownership_pct` on `owned_by`, `columns` / `primary_key` / `schema` / `verified_queries` on Data Table, dates, amounts, status). They live **on the Point/Path**, never as separate nodes. Call `lookup_ontology` for the full property list with `applicableToTypes`.

## Default atlas structure (folders)

A new atlas opens with six **default folders** (user-editable) that organize its views by aspect. Use this map to decide which folder a view belongs in, and when Nav generates a view, file it into the matching folder.

| Folder | Point types | Key path types | Example maps (1-2 word names) |
|--------|-------------|----------------|-------------------------------|
| **People** | Person, Position, Group | `has_role`, `member_of`, `reports_to`, `performs`, `accountable_for` | Org, Leadership, Teams, RACI |
| **Entities** | Organization, Vendor, Account, Bank Account | `owned_by`, `provided_by`, `located_in` | Entities, Ownership, Banking |
| **Business Model** | Product, Customer, Outcome | `member_of` (product families), `owned_by` | Customers, Products, Value |
| **Process** | Process, Step, Decision, Approval, Review, Handoff, Trigger | `has_step`, `followed_by`, `followed_by_if`, `performs`, `needs_input`, `creates_output`, `handoff_of`, `initiates` | Intake, Payoff, Onboarding (one per flow) |
| **Systems** | System, Database, Data Table, Artifact, Document, Equipment, Skill | `uses_resource`, `provided_by`, `has_table`, `joins_to`, `creates_output`, `has_attachment`, `extracted_from`, `has_context` | Systems, Software, Tables |
| **Metrics** | Outcome, Metric, Risk | `impacts` (driver tree), `measured_by`, `has_risk`, `mitigates`, `accountable_for` | KPIs, Outcomes, Risks |

- **People vs Entities:** keep the *human* org (People: who reports to whom) separate from the *legal/corporate* org (Entities: which company owns which). Ownership/`owned_by` structure belongs in Entities, never People.
- **Accounting folder (house pattern):** `Account` / `Bank Account` points and the COA view do NOT live in Entities (confusing next to orgs/vendors). Create a dedicated **Accounting** folder holding the "Chart of Accounts" view. Canonical finance terms (e.g. "Chart of Accounts") are allowed as view names even beyond the 1-2 word rule — the canonical term beats an abbreviation.
- **Business Model modeling:** a buyer is a `Customer`; an offering is a `Product` (services included, e.g. "Managed Payroll"). Group product families with `member_of` (product `member_of` family Group). A market is still an `Organization`. There is no Customer→Product path yet — describe what a customer buys in the description. Do **not** use `impacts` for product→market (that's the metric driver-tree type - see the displayName anti-pattern).
- **One view, one question:** each view answers a single question ("what do we measure" vs "what data do we have"). Shared EDGES between views' subject matter are fine — they live in the graph and show in point neighborhoods — but duplicating a full point-set (e.g. all Metrics appearing in both a KPIs view and a Data view) makes two views read as competing trees. Curate views to disjoint-ish point-sets; let edges do the cross-linking.
- **The explain-it test:** every view name must survive "if I can't understand it I can't explain it" — a non-technical operator should get it with zero explanation. Plain words beat clever ones: "Software" not "Stack", "Tables" not "Data", "Job Costing Spreadsheet" not "Job Costing Tool". Jargon-flavored names (Stack, Estate, Fabric, Hub) are banned.
- **View AND folder names: one or two words, a clean noun.** Think financial-model tabs (`Inputs`, `BS`, `CF`). **Banned:** `&`, `+`, `:`, `/`, and verbose AI-generated "slop" titles (`How X Works`, `X & Y Candidates`, `Specify to Install`). A `&`/`+` joining two concepts is a **smell that it should be two views** — split it (`Systems & Data Flow` → `Systems` + `Data Flow`). Examples of the fix: `Order Lifecycle: Specify to Install` → `Lifecycle`; `Org & AI-Augmentation Candidates` → `AI Roles`; `Product Lines & Manufacturing` → `Products`; `How Forms+Surfaces Works` → `Overview`. This applies to anything Nav names — views and folders alike.

## Key modeling patterns

*Modeling judgment and anti-patterns (naming, attachment, typing — with ✓/✗ examples) live in `atlas-modeling`. This section is vocabulary-level composition only: which path types build which structures.*

- **Process flow:** a `Process` owns its steps via `has_step` (membership); order them with `followed_by`. A conditional branch is `followed_by_if` with a `condition` property; a loop is a `followed_by_if` that points back upstream. Use `Decision` for a choice point and `Approval` for a sign-off - not a generic `Step`. What kicks a process off is a `Trigger` that `initiates` the Process (or a Step/Agent/Person). Mark each Step's `execution_mode` (`human` | `system` | `external`) where known.
- **Actors:** `Person` `has_role` `Position`; `member_of` puts a Person, Position, Organization, Agent, or Group into a `Group`; `Position` (or `Agent`) `reports_to` `Position`; an actor `performs` a `Step`; RACI accountability is `accountable_for` → `Outcome`/`Process`/`Step`. An `Agent` (AI) is a unified actor - it uses the same paths (e.g. `performs`), with its skill doc attached via `has_context`.
- **Resources:** attach `uses_resource` to the **atomic leaf Step**, not the parent Process. A service is a `System` reached `provided_by` a `Vendor` - never Step → Vendor. Documents/messages are `Artifact`s, produced via `creates_output` (not Systems).
- **Metrics:** `impacts` edges between `Metric`s form an impact/driver tree.
- **Orgs:** legal-entity structure is `owned_by` (owned `Organization`/`Customer` → owner `Organization`), with `ownership_pct` for partial stakes. Equity only: "who owns this process" is `accountable_for`, not `owned_by`.
- **Accounting:** COA hierarchy is child `Account` `subaccount_of` parent `Account` — one edge per child, no inverse edge.
- **Data:** a `Database` (is-a `System` — the store, not the app that writes to it) `has_table` its `Data Table`s; joinable tables link child→parent via `joins_to` with the join condition in the edge description. Columns are properties on the Data Table (`columns`, `primary_key`, `schema`), never separate points; put analyst gotchas in the description and known-good SQL in `verified_queries`.
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
- **Generic parent-child edges:** there is no generic parent-child path, on purpose. `subaccount_of` is chart-of-accounts hierarchy ONLY (child Account → parent Account). For everything else pick the path that names the actual relationship: `member_of` for collection membership (incl. product families), `has_step` for process structure (including sub-processes — Process → Process is legal), `owned_by` for legal-entity ownership.
- **Reaching for a retired path:** `has_child`, `rolls_up`, `maps_to`, `has_interest`, `has_subsidiary`, `triggered_by` are retired and unselectable. Their replacements: `subaccount_of` (COA), `owned_by` (ownership), `initiates` (triggering, direction reversed: Trigger → initiated thing).
- **Using `is_a` / `part_of` in the data graph:** those are schema/metagraph (meta) relationships, not user-data paths.
- **Ignoring source/target constraints:** the validator now enforces the constrained paths on new writes - e.g. `accountable_for` only targets `Outcome`/`Process`/`Step`, `has_table` is strictly Database → Data Table (an application doesn't have tables; it writes to a Database), `reports_to` sources are only Position/Agent.

