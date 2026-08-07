# Database vs Data Table

**Principle:** A **Database** is the store ("the data lives in X"); a **Data Table** is a structured collection of records *inside* a store. Database is-a System (subtype); a Data Table is-in a Database (`has_table` edge), not a subtype of it. Columns are properties on the Data Table, never separate Points.

**When this applies:** Modeling a data estate — a warehouse, an application database, a reporting store, a spreadsheet-backed dataset — or preparing an atlas that an agent will use to write SQL.

**The subtype rule (is-a vs is-in):** make something a *subtype* (superType) when you'd substitute it in a sentence ("the Orders DB is a system we run" — Database is-a System). Make it a *path* when you'd locate it ("the Orders table is in the Orders DB" — `has_table`). Substitution → subtype; location → path.

**Do:**
- Type the store as `Database` ("Orders DB", "Sales Data Warehouse"); the application that writes to it stays a `System` ("the ERP (System) writes to the Orders DB (Database)").
- Wire `Database ─has_table→ Data Table` for every table. `has_table` is strictly Database → Data Table; the validator rejects "application has_table X".
- Capture columns in the `columns`, `primary_key`, `schema`, and `column_count` **properties** on the Data Table. A 99-column table stays one readable Point.
- Wire `joins_to` between joinable tables, child→parent (the FK-holding table points at the referenced table), with the join condition in the edge description: `OrderLineItems.orderID → Orders.orderID`.
- Put analyst gotchas — type quirks, required filters, soft-delete flags, timezone traps — in the Data Table's **description**. That is the knowledge that stops an agent writing bad SQL.
- Store 2-3 known-good SQL snippets in the `verified_queries` property (semantic-model practice: give the agent proven starting points).

**Don't (anti-pattern):**
- Don't model columns as Points. Column-points make schema atlases unreadable and add nothing until per-column lineage is a real need.
- Don't give a `System` a `has_table` edge. "What systems do we use" (apps) and "where does our data live" (stores) must stay separable queries.
- Don't leave a Data Table with no `has_table` parent — an orphan table is unlocatable ("which store is this in?").

**Litmus test:** *"Would I say 'the data lives in X' (Database) or 'we work in X' (System)? And for a table: can I answer 'which Database is it in' with one `has_table` hop?"*
