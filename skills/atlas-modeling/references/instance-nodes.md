# Instance Nodes Over Shared Nodes

**Principle:** Actions are per-flow instances. Entities are shared singletons. Never wire one action node into multiple processes.

**When this applies:** Building or refining a process when an action looks identical to one in another flow ("Mark ID QC", "Approve", "Review"), or when tempted to point a second process's `has_step` at an existing step.

**Do:**
- Create a distinct action node per flow, even when two look the same. Give it a flow-qualified name if needed (`Mark ACH/Wire ID QC for Manager Review`).
- Reuse the same entity node everywhere it is referenced: one `Cash Receipts Module` System, one `Custodial Accounting Specialist` Position. Point every flow at those shared entities.

**Don't (anti-pattern):** Share one action node across processes (multiple `has_step` parents). A node's outgoing `followed_by`/`followed_by_if` edges are global to the node, so the moment the flows diverge downstream, the shared node carries every flow's next-step and traversal returns false paths ("from the Cash flow, QC appears to lead to Return/Reject"). Querying "what happens next" stops being trustworthy.

**Exception (factor, don't share):** If a block of logic is genuinely identical across flows all the way to a single common exit, promote it to its own sub-`Process` and have each flow `has_step` to it. Encapsulation keeps the internal edges from bleeding. If the divergence lives *inside* the block, keep distinct instances.

**Litmus test:** *Would sharing this node force two different "what happens next" answers onto it?* If yes, instance it. *Is this a real-world thing that exists once?* If yes, share it.

