# Handoff Is Responsibility Transfer, Not Communication

**Principle:** Use `Handoff` only when ownership of the work passes to another actor who then continues the flow. Sending a message, notification, or request is a plain `Step`.

**When this applies:** Any step phrased as notify / email / advise / escalate / refer / request / send, or any genuine "person A hands the work to person B who does the next step."

**Do:**
- True transfer → `Handoff` with `from_person`, `to_person`, and `handoff_of` (e.g., specialist hands the letter and check to the administration clerk, who performs the mailing step).
- Outbound communication → plain `Step` that `uses_resource` the channel (e.g., an Email system), consistent with how "Notify HUD" / "Advise Attorney" are modeled. If "who do we contact externally, in which step?" must be queryable, propose a dedicated `notifies`/`sends_to` (Step → Actor) path rather than stretching Handoff.

**Don't (anti-pattern):** Model "email the bank", "notify HUD", "advise the attorney" as Handoffs. Nothing transfers — you send and keep going on your side; the other party acts independently. The definition's "...or context" clause invites this overload and pollutes "what work is handed off here?"

**Litmus test:** *After this, does the next step happen in someone else's hands as part of this process?* Yes → Handoff. No (we proceed; they act on their side) → Step.

