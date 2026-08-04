# Model the Service as a System, the Vendor as its Provider

**Principle:** A step depends on a capability, never on a company. Model the service as a System; attach the step to it via `uses_resource`; link the Vendor to the System via `provided_by`. One vendor can provide many services.

**When this applies:** Any step that touches an external party — bank deposit, vendor platform, external feed, outside counsel. Also when reviewing a step or process that points at a Vendor directly.

**Do:**
- `Step --uses_resource--> Service (System) --provided_by--> Vendor`.
- Name the service by function (`Cash Deposit Service`, not `Chase Cash Deposit` — see `name-by-function.md`).
- When one capability is consumed identically regardless of provider, use one function-named service with multiple `provided_by` edges (one `ACH/Wire Feed` provided by both banks).

**Don't (anti-pattern):** `Step --uses_resource--> Vendor` (or `Process --uses_resource--> Vendor`). It couples the work to the company instead of the function, can't represent a vendor that offers several services, and isn't ontology-valid (`uses_resource` targets System/Equipment/Transport, not Vendor). Do not substitute `part_of` for provision — that's a mereological overload; use `provided_by`.

**Litmus test:** *Is a step (or process) pointing at a company?* Insert the service layer. *If we replaced this vendor, how many edges change?* Exactly one — the `provided_by` link — no matter how many steps use the service.

