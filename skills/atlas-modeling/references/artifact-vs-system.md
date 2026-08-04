# Artifact vs System

**Principle:** Persistent infrastructure that does work is a **System**. Documents, messages, files, and forms produced or consumed by steps are **Artifacts**. Standardized message types (EDI X12 transactions, NACHA files, HL7 messages, 1099/K-1 forms) are Artifacts, not Systems.

**When this applies:** Choosing the type for any Point that names a file, document, message, transaction, form, report, ledger entry, or named information artifact. Most commonly when you are tempted to type an EDI message code (850/846/856) as a System.

**Do:**
- Type `System` when something can be logged into, queried, sent to, or runs continuously: an ERP, a CRM, an EDI VAN, FedEx parcel service, a Cash Receipts Module, a state filing portal.
- Type `Artifact` when something is produced by one step and read or sent by another: Packing Slip, Inspection Report, Returned Payment Letter, EDI 850 order, EDI 856 ASN, 1099 form, NACHA file.
- Use `creates_output` from the producing step; `needs_input` from the consuming step.

**Don't (anti-pattern):**
- Don't type a standardized message format as a System just because it has a product-sounding name. EDI 856 is not a system. The ERP sends it. The EDI VAN routes it. Those are the systems.
- Don't use `uses_resource → Artifact`. Resources are tools the step works with (Systems and Equipment). Documents flow through `creates_output` and `needs_input`.

**Litmus test:**
- "Can I log into it, query it, or call its API?" → System
- "Is it created by one step and consumed (read, sent, signed, filed) by another?" → Artifact
- "Is it a specification or format definition, with each transmission being one instance?" → Artifact (model the message type as a singleton; instances are conceptual)
- Verb tells: Systems are *run, host, store, route, process*. Artifacts are *create, send, receive, submit, sign, file, generate*.

**Common traps:**
- EDI X12 transactions (850, 846, 856, 810, 820, etc.) are message types → Artifact.
- NACHA file, ACH return file, HL7 message → Artifact.
- 1099, K-1, W-2, W-9, Schedule K, Form 990 → Artifact.
- "ACH/Wire Feed" is borderline: the feed itself (recurring data stream infrastructure) is a System; individual transactions in it are Artifacts (rarely modeled individually).
- "Inventory Database" is a System; an inventory-query *result* isn't typically an Artifact unless a step explicitly produces a report.
- "Email" is a System (the service); a specific email message would be an Artifact (rarely modeled).

