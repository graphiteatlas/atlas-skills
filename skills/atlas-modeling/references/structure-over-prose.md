# Structure Over Prose

**Principle:** Any fact with a structural home lives there once. Descriptions carry only what has no structural home: judgment, rationale, edge cases.

**When this applies:** Authoring or editing any description; importing prose from a source SOP; any time a value (rate, threshold, duration, date, count) or a relationship (uses X, done by Y, leads to Z) shows up in text.

**Do:**
- Push each fact to its structural home: system used → `uses_resource`; input document → `needs_input`; who does it → `performs`/`responsible_for`; what's next / branch condition → `followed_by`/`followed_by_if` (+ `condition` property); a value → a property on the node, or its own `Metric` node if it drives other numbers.
- Keep the description for the why, the judgment the operator applies, and the gotcha that bites.
- If you need structural facts rendered in prose (for an SOP), generate that sentence from the graph at output time so it stays current.

**Don't (anti-pattern):** Bury queryable facts in prose ("Look up the order in the legacy ERP, which we're migrating off in Q3, then route to the Fulfillment Coordinator"). It is unqueryable ("what uses the legacy ERP?" misses it) and drifts out of sync the moment the structured version changes.

**Litmus test:** *If this fact changed, how many places would I edit?* Must be one. *Could someone query for this fact?* If it's a fact (not a judgment), they should be able to — so it belongs in structure.

