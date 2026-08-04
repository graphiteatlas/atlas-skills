# Dependencies Attach to the Step

**Principle:** A resource dependency is asserted once, on the atomic step that uses it. A process's dependency is derived by rolling up its steps, never authored as a standalone process-level edge.

**When this applies:** Modeling which systems/inputs a process uses; reviewing a Process that has `uses_resource` edges directly on it; building any multi-step process.

**Do:**
- Put `uses_resource` (→ System/Equipment/Transport) and `needs_input` (→ Artifact/Step) on the specific leaf step that touches the resource.
- Answer "what does this process depend on?" by traversing `has_step → uses_resource` and aggregating.

**Don't (anti-pattern):** `Process --uses_resource--> System` with no step connected to it. The dependency floats: you know the process "uses" it but not which step, why, or what fails if it goes away. Asserting it at both levels duplicates the fact and lets it drift. Also: do not use `uses_resource` to point at an Artifact (that's `needs_input`); `uses_resource` targets System/Equipment/Transport only.

**Litmus test:** *Which step requires this resource?* If you can name it, put the edge there. If you can't, the edge shouldn't exist (or the step isn't modeled yet). *If the resource changed, how many edges would I edit?* One — the step; the rollup follows.

