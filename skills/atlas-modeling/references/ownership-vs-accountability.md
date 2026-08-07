# Ownership vs Accountability

**Principle:** "Owns" means two unrelated things in business speech. Equity/legal ownership is `owned_by` (owned entity → owner, with `ownership_pct`); responsibility for work or results is `accountable_for` (Person/Position → Outcome/Process/Step). Never encode one with the other's path.

**When this applies:** Any time a source says "X owns Y" — corporate structures, cap tables, subsidiaries, joint ventures, and equally "Sam owns the month-end close" or "Ops owns onboarding".

**Do:**
- Legal/equity structure: `Acme Europe (Organization) ─owned_by→ Acme Corp (Organization)`, direction owned → owner. Partial stakes carry `ownership_pct` on the edge (e.g. `ownership_pct: 60`).
- A `Customer` can also be owned: `Customer ─owned_by→ Organization` is legal (a portfolio company that also buys from you).
- Responsibility: `Controller (Position) ─accountable_for→ Month-End Close (Process)`. RACI accountability always targets an Outcome, Process, or Step.

**Don't (anti-pattern):**
- Don't model "the CFO owns the forecast" as `owned_by` — nothing is being held as equity. That is `accountable_for`.
- Don't model "the fund owns 30% of the company" as `accountable_for`, `member_of`, or a prose note — that is `owned_by` + `ownership_pct: 30`.
- Don't invert the direction: the owned entity points at its owner, not the reverse.

**Litmus test:** *"If the relationship dissolved, would shares change hands (owned_by) or would someone stop being on the hook for results (accountable_for)?"*
