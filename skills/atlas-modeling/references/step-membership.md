# Complete has_step Membership

**Principle:** `has_step` is the membership relation ("step is part of this process"); `followed_by` is order. Every member step needs its own `has_step` from the process. Do not let `followed_by` imply membership.

**When this applies:** Building a process (attach every step, not just the first); auditing a process — especially one copied from another atlas or a production export.

**Do:**
- For each step in a process, create `Process --has_step--> Step`, in addition to the `followed_by`/`followed_by_if` chain that orders them.
- When a chain crosses into another sub-process, the boundary is the next sub-process's entry; assign each step to the process whose chain it sits on.

**Don't (anti-pattern):** Attach only the entry step via `has_step` and chain the rest with `followed_by`. Then "what steps are in this process?" via `has_step` returns only the entry, and any `has_step → uses_resource` rollup misses most of the process.

**Detection (read-only):** sequenced steps with no `has_step` parent are the gap:
```cypher
MATCH (s:Point {atlasId: $atlasId})
WHERE s.type IN ['Step','Decision','Approval','Review','Handoff'] AND s.deletedAt IS NULL
  AND EXISTS { MATCH (s)-[f:PATH]-() WHERE f.name IN ['followed_by','followed_by_if'] }
  AND NOT EXISTS { MATCH (:Point {type:'Process'})-[:PATH {name:'has_step'}]->(s) }
RETURN s.name
```

**Litmus test:** *Can I list this process's steps with `has_step` alone?* If a sequenced step is missing, add its `has_step`.

