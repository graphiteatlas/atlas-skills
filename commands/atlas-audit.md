---
description: Run the read-only Atlas health audit on an atlas (detects modeling violations; no mutations).
---

Run the `atlas-auditing` skill against the atlas the user names (ask which atlas / tenant if unspecified). It runs a fixed set of read-only health checks for the modeling patterns (dependencies at the wrong level, resources pointing at artifacts/vendors, orphaned step membership, steps with no performer, system/vendor names baked into nodes, overloaded part_of), through the server's `run_audit` and a short script over the atlas export.

Report the scorecard of findings with proposed fixes. Do **not** mutate anything.
