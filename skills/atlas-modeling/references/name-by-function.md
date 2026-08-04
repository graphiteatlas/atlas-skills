# Name by Function; Keep Identity Structural

**Principle:** A node's name and description describe the function. The specific vendor, person, system, or instance that fills the role is reached through a path (`provided_by`, `member_of`, `performs`, `uses_resource`), not baked into the name or restated in prose.

**When this applies:** Naming a Step, System, or service; writing a description; reviewing names that contain a system/vendor/product token ("...in SAP", "...to DocuSign", "Chase ...").

**Do:**
- Function names: `Submit State Regulatory Filing` (system on `uses_resource`), `Cash Deposit Service` (vendor on `provided_by`), `Email Bank to Recall Returned ACH/Wire`.
- Keep the specific name in exactly one place: the entity's own node (the Vendor/System point). Reach it by traversal.
- To show the specific name in an SOP or card, render it from the graph at output time.
- Same function from multiple providers → one function-named node with multiple `provided_by` edges, not per-vendor twins.

**Don't (anti-pattern):** Bake the filler into names/descriptions (`Chase Cash Deposit`, "...provided by Chase Bank"). The structural swap-test passes but the labels and prose go stale on a swap, breaking "change it in one place" at the cosmetic layer and quietly misleading readers.

**Litmus test:** *If you swapped the vendor/person/system, how many places change?* Exactly one — the edge. If a name or description would also need editing, it's holding identity that belongs in structure.

