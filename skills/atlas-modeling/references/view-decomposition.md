# A view is a unit of review, so decompose the process, not the picture

**A flow view holds one subgraph a person can check in one look.** When a process view grows past
that, the view is the symptom; the disease is a process that was never decomposed. Fix it upstream:
promote the phases to child Processes, wire `parent -has_step-> child`, and give each child its own
view in a folder named for the parent. Splitting the picture alone leaves a 30-step process pretending
to be atomic, and every later query inherits that.

```
X  Process "HUD Liquidation Claims" -has_step-> 30 Steps, all in one view
   (nobody reviews this; they scroll it, agree, and miss the branch that is wrong)

V  Process "HUD Liquidation Claims" -has_step-> "Curtailment Review" (Process) -has_step-> 5 Steps
   one view per child Process, nested in a "HUD Liquidation Claims" folder
```

**Do not make this a point count.** An inventory view (Artifacts, Systems, Org) is a list, and a list
stays readable at thirty. A *sequence* stops being reviewable at about a dozen, because the reader has
to hold the order in their head while they pan. The rule applies to flow views only. A rule that counts
points flags the wrong views, and people learn to ignore it.

The test is behavioural first: **can a reviewer read this view and say "yes, that is how it works"
without panning to keep the sequence straight?** If they pan, it is two views. Behind it sit
published limits, and they are a gate, not a suggestion:

| | Pass | Warn | Must decompose |
|---|---|---|---|
| Direct steps in a leaf Process | 4 to 12 | 13 to 15 | 16 or more |
| Phases in a parent Process | 3 to 9 | 10 to 15 | 16 or more |
| Own actions on a flow view | up to 12 | 13 to 15 | 16 or more |
| Cards on a flow view | up to 30 | 31 to 49 | 50 or more |

**Where to cut, in order:** at breakpoints (a milestone the business recognises: a document issued,
a meeting held, a hand-off to another team), keeping a document's producer with its consumer, never
through a rework loop, with any-order sets boxed as their own sub-process (`ordering: any`; a chain
of real order inside one is nested as a small sub-process within it, and a box drawn inline on its
parent's flow needs no folder or Overview), and
roles only as a tie-breaker. Then check the result: one entry and one exit per sequential
sub-process, more connections inside it than across its edge, no loop spanning two sub-processes.

**The layout:** a folder named for the process holds `<Process> Overview` first (the spine: the
sub-processes in sequence, an any-order set as one box), then one view per sub-process in flow
order, then optionally `Entire <Process>`, the whole thing on one canvas, exempt from the size limits
but still one connected flow. Those two names are allowed past the one-or-two-word rule. The long
form, the checks and the sources are in `references/large-process-decomposition.md`.

**Count actions, not points.** A view also holds the Process node, the performers and the artifacts,
so twelve actions is comfortably past twenty points. Briefing someone with a *point* budget instead
of an *action* budget forces over-splitting: on one custodial-accounting build a "4 to 9 points"
brief produced twenty-five child processes with a median of four actions, one of them holding a
single step. A Process that exists only to justify a view is the failure of this rule, not its application.

**The floor matters as much as the ceiling.** Below about three actions, ask whether the business
would name this separately. If the name is one you coined, merge it back up.

**The limit that keeps this a judgment call: never split into a subprocess the business has no name
for.** If nobody in the room calls those six steps anything, "Claim Preparation Phase" is vocabulary
you invented, and every reader has to translate it back to what they actually say. A slightly
oversized view beats a fictional subprocess. Decompose along the seams the business already names
(the handoff, the system change, the role change, the phase they say out loud); if there is no seam,
leave it whole and say so.

**One connected flow per view.** A flow view shows one **connected component**: every action in it is
reachable from every other along the sequence paths (`followed_by`, `followed_by_if`), ignoring
direction. Two or more chains sitting side by side with no path between them are **disconnected
components**, or **fragments**; a single unlinked action is an **isolated node**. In process-modeling
terms the view is not **well-formed**: there is no single path from its start to its end. (Process
theory calls the stronger version **soundness**: every step lies on some path from start to end.)

```
X  View "Definition and Planning": [Line of Business Engagement -> Vendor Engagement]
   [Within 20%? -> Present to Steering Committee -> SteerCo Approval -> Cancel Project]
   [Client Engagement]   [Provide Documentation...]      <- four fragments, no path between them

V  one entry, one or more exits, every action on a path between them; parallel work branches
   from a common step and rejoins (or ends) explicitly
```

A fragment means one of three things, and each has a different fix:

- **Missing sequence.** The steps do follow each other and nobody recorded it. Ask, then wire it.
- **Parallel work.** The chains run at the same time. Branch them from the step that starts them and
  join them where they meet, or, if their order is genuinely unknown, show them in a named container
  with no implied arrows (see atlas-process-book).
- **Two processes in one view.** The chains belong to different processes or phases. Split the view
  along that seam (2a). Show the other process as an entry or exit box joined by an arrow, or link
  across with a hyperlink to its view; never a floating, unjoined box.

Never "fix" a fragment by inventing a `followed_by` nobody stated. An honest disconnected view with a
question attached beats a connected view that is wrong.

**A Process on its own view is a container, never a hub.** Atlas draws a Process on a view as a
container around its steps, so the sub-process view holds its Process and the steps sit inside the
box. If containers are switched off for a view, every step draws a `has_step` line back to the
Process instead and the flow disappears under the spokes: then leave the Process off its own view.
A Process card that holds nothing on the canvas is an **entry or exit box**: a DIFFERENT process (the
previous or next stage, an any-order box the flow passes through) drawn as one box, joined by an
arrow from or to this view's process or one of its steps, and never shown alongside its own steps.
The step-level form, the neighbouring step itself, is an entry or exit card; the box is the default.
Full rule in references/large-process-decomposition.md.

```
X  containers off: view "Initiation" holds Process "Initiation" + its 12 steps   (12 spokes)
V  view "Initiation" holds Process "Initiation" drawn as the box around its 12 steps,
   plus Process "Charter and Change Council" as the exit box, joined by an arrow from the last step
```
