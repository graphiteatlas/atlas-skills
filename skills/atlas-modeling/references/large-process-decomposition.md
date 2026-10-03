# Decomposing a large process

A Process with more than fifteen direct steps is not a process; it is several, never separated.
This reference is the long form of atlas-modeling **2a**: when to decompose, where to cut, how
to lay out the result, and the checks that say whether the cut is good. Every rule here has a
published basis, cited at the end, so a reviewer can argue with the source rather than with taste.

## When it applies

| Measure | Pass | Warn | Must decompose |
|---|---|---|---|
| Direct steps in a leaf Process | 4 to 12 | 13 to 15 | 16 or more |
| Phases in a parent Process (sub-processes plus direct steps) | 3 to 9 | 10 to 15, or under 3 | 16 or more |
| Own actions on one flow view | up to 12 | 13 to 15 | 16 or more |
| Cards on one flow view | up to 30 | 31 to 49 | 50 or more |

The ceiling comes from process-model quality research: models past about 50 elements carry a
sharply higher error rate and should be decomposed, and published ranges for one model run from
5 to 7 activities, through 5 to 15, to IDEF0's 3 to 6 boxes per diagram. A sub-process under four
steps is usually a cut too fine: merge it back unless the business names it on its own.

The trigger is the **process**, not the picture. A 40-step Process drawn across three views is
still a 40-step Process, and every rollup, document and query inherits it.

## Where to cut: five rules, in order

1. **Cut at breakpoints.** A sub-process ends where the business reaches a milestone: a document
   is signed or issued, a meeting is held, the work passes to another team, an approval lands.
   Name the sub-process by that outcome, in the business's own words where it has them
   (`Offer`, `Paperwork`, `Probation Review`), never a coined label (`Phase 2`, `Core Activities`).
2. **Keep a document's producer with its main consumer.** Steps that create and use the same
   documents belong together. A cut that separates the step that produces a form from the step
   that reviews it is suspect.
3. **Never cut through a loop.** A rework cycle (review, request corrections, review again) stays
   inside one sub-process. If a loop crosses the cut, move the cut.
4. **An any-order set is its own sub-process.** Steps with no required order among them become a
   Process with `ordering: any`. The step that starts them points to the box once, instead of
   fanning out to every member, and the box points to whatever follows.
5. **Use roles only to break a tie.** A change of team supports a breakpoint; it never forces one.
   A role-based cut alone produces swimlanes, not phases.

The first three apply to any process. The last two apply only when the pattern is present. None
of them is sufficient alone: they say where a cut may go, and the checks below say whether it was
a good one.

**Never invent a seam.** If a long process genuinely has no milestone the business recognises,
leave it whole and record why. A slightly oversized process beats a fictional sub-process every
reader has to translate back.

## The layout

```
Process (folder)
  Employee Onboarding (folder)
    Employee Onboarding Overview       the spine
    Offer                              one view per sub-process, in flow order
    Paperwork
    Provisioning                       an any-order box
    First Week
    Probation Review
    Entire Employee Onboarding         optional: the whole thing on one canvas
```

- **The spine** (`<Process> Overview`) holds the parent Process and its sub-processes. Their order
  is drawn with `followed_by` between the sub-processes, the same way a stage lifecycle is drawn
  between stage Processes. An any-order sub-process appears as one box. No steps appear on the
  spine except a milestone step that sits directly under the parent.
- **A sub-process view** holds that sub-process (Atlas draws it as a container around its steps),
  its steps, the step on either side of it in a neighbouring sub-process (its entry and exit
  cards), who performs each step, and the documents they create and use. Neighbouring
  sub-processes appear only on the spine.
- **The whole-process view** (`Entire <Process>`) is allowed and optional. It is deliberately big,
  so size and overlap checks do not apply to it, but it must still be one connected flow. IDEF0
  has the same idea under the name For Exposition Only diagram: a view outside the hierarchy,
  labelled as such.
- **Recurse.** A sub-process that itself passes fifteen steps gets the same treatment one level
  down, in its own folder. Keep it to four folder levels under the default folder.

`<Process> Overview` and `Entire <Process>` are the two names allowed past the one-or-two-word view
name rule, because a bare `Overview` in every folder makes view names collide and search useless.

## Worked example

Before: `Employee Onboarding` holds 28 steps directly, in one view. `File Employee Record` fans
out to seven provisioning steps (create email account, order laptop, issue badge, add to payroll,
enroll in benefits, assign desk, create directory entry) that have no order among them.

```
X  Employee Onboarding -has_step-> 28 Steps          one view, 40 cards
   File Employee Record -followed_by-> 7 steps        seven arrows from one card
```

After: cut at five milestones (offer accepted, paperwork filed, accounts ready, first week done,
probation decided), the provisioning set boxed.

```
V  Employee Onboarding -has_step-> Offer, Paperwork, Provisioning, First Week, Probation Review
   Offer -followed_by-> Paperwork -followed_by-> Provisioning -followed_by-> First Week -> ...
   Provisioning  ordering: any   -has_step-> the seven steps
   File Employee Record -followed_by-> Provisioning -followed_by-> Welcome New Hire
   Review Eligibility Form -followed_by_if-> Request Form Corrections -followed_by-> Review ...
                                                         (the rework loop stays in Paperwork)
```

## The checks

Run these after the cut and before writing. Each has a pass mark; an accepted exception is
recorded with its reason and stays visible, it does not count as a pass.

| Check | What it measures | Pass |
|---|---|---|
| Process size | direct steps, or phases for a parent | the table above |
| Single entry, single exit | in a sequential sub-process, the steps nothing inside precedes (entries) and nothing inside follows (exits) | one of each; two is a warning (a parallel start or end); more fails |
| Cohesion and coupling | arrows and shared documents inside the sub-process against those crossing its edge | at least 30% inside. Research uses these to compare candidate cuts, so a low score means try another cut |
| Loops | strongly connected components of the sequence graph | none spans two sub-processes |
| Box candidates | a step with five or more unconditional successors not ordered among themselves | none; each one found is an any-order set to box |
| View structure | each sub-process view is one connected piece, every hand-off shown as an entry or exit card | one piece |
| Routing paths | outgoing sequence arrows from one card on a view | under 4; 7 or more fails |
| Folder placement | a sub-process view sits in the folder named for its parent; the spine sits there too and is named `<Process> Overview` | both |
| Node tree | every process with sub-processes has a folder named for it, `<Process> Overview` first in it, a view or subfolder per sub-process, and `Entire <Process>` last if there is one | all; a missing folder or Overview fails, a missing sub-process view or the wrong order warns |
| Viewpoint | two views drawing more than 30% of the same steps | none, the whole-process view aside |

The single-entry, single-exit check is the one that most often finds something. An exit that
leads nowhere is usually a missing arrow, not a bad cut: ask what happens next before moving
the boundary.

## Sources

- Mendling, Reijers, van der Aalst, *Seven Process Modeling Guidelines (7PMG)*, Information and
  Software Technology 52(2), 2010. G2 minimise routing paths per element; G3 one start and one
  end; G4 model as structured as possible; G7 decompose a model with more than 50 elements.
- Milani, Dumas, Ahmed, Matulevičius, Kasela, *Criteria and Heuristics for Business Process Model
  Decomposition: Review and Comparative Evaluation*, Business and Information Systems
  Engineering 58(1), 2016. The six heuristic classes (breakpoints, data objects, roles, shared
  processes, repetition, structuredness), the size ranges, and the finding that heuristics give
  necessary but not sufficient criteria.
- Vanhatalo, Völzer, Koehler, *The Refined Process Structure Tree*, 2008: single-entry,
  single-exit fragments as the unit of decomposition.
- Vanderfeesten, Reijers, van der Aalst and others on cohesion and coupling metrics for process
  models.
- IDEF0 (FIPS 183): a parent diagram of 3 to 6 boxes, each decomposed into a child diagram, and
  For Exposition Only diagrams outside the hierarchy. Its node tree (node index), which lists
  every diagram under its parent, is what the node tree check holds the folders to.
- ARIS: a value-added chain at the top, each function assigned a detailed process model one
  level down. The same parent-overview, child-detail layout.
- BPMN 2.0: the ad-hoc sub-process, the standard's name for an any-order set.
