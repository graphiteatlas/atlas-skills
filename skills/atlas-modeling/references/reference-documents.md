# Reference documents: the point type follows whether you hold the file

**A `Document` is a file that was uploaded.** The ontology defines it as created for every
uploaded file, so a Document point with no bytes behind it contradicts its own type. Which
point type a referenced document gets therefore depends on whether it is in the atlas:

| The document is | Point | Path from the thing that references it |
|---|---|---|
| the **source** the model was built from | `Document` (created by the upload) | `extracted_from`, carrying the citations |
| an **authority you uploaded** | `Document` | `has_attachment` (declared `* -> Document`) |
| an **authority you only link to** | `Artifact`, tag `knowledge_doc`, `url` property | `needs_input`, from the step that opens it |

**Anti-pattern: confusing modeling evidence with an operational resource.** A guide, transcript,
sticky-note photograph, or SOP that the agent reads to construct the graph is not automatically
something the business uses to perform the work. Its existence, title, or instructional wording
does not establish a `needs_input` or `uses_resource` Path. The linked-authority pattern above
applies only when its operational use is evidenced, not as a fallback for an unuploaded source.

```
Source statement in a startup guide: "Check the construction sequence for access conflicts."

✗ Create Startup Guide [Artifact] merely because it supplied that statement, then:
  Review Construction Sequence [Review] ─uses_resource→ Startup Guide [Artifact]
  (asserts use of the guide that the source never established)

✓ Upload the source, then record provenance:
  Review Construction Sequence [Review] ─extracted_from→ Startup Guide [Document]
  Attach a supporting quotation only after ingestion and verification.

Separate statement: "Open the startup checklist and complete each required item."
✓ This DOES evidence an operational input. Model that use with the appropriate
  reference-document pattern above, separately from provenance.
```

If the source is not uploaded, retain its URL, local reference and supporting passage in the
proposal/evidence record. Do not fabricate a file-backed Document or create an operational
Artifact just to give the source a graph home. Selected diagrams may be attached as reference
Documents without implying that every performer consults them or that their examples describe
every job. One source can support both provenance and operational use, but each requires its own
evidence; do not create duplicate representations solely to express the two roles.

**Test:** *Does the evidence say the performer uses this material, or only that the modeler did?*

**Upload when someone needs to read it from inside the atlas; link when they do not.**
Attaching costs ingestion, storage and a point, and pays in retrieval and citation. For a
mapping guide a step follows field by field, upload. For a 400-page handbook nobody opens per
transaction, link.

**A citation list at the back of an SOP is a bibliography, not a relation.** Where a source
lists governing guidance without mapping any of it to a step, put the list in the governed
Process's description and model nothing: every citation would otherwise attach to the parent
and "what must we review if this changes" would answer "all of it", which the description
already says. Where the rules ARE the subject (a compliance matrix, a control register), model
each obligation as a **Step carrying its citation and deadline as properties**.

Prior art, if you need to argue it: Dublin Core's `dcterms:conformsTo` relates a **resource to
a standard**, document to document, not a process to a rule. PROV-O's `wasDerivedFrom` is our
`extracted_from`. FRBR's work/expression/manifestation split is why a blank form and a
completed form are one Artifact, not two.

Deeper examples: `references/dependencies-on-steps.md`, `references/service-as-system.md`,
`references/artifact-vs-system.md` (EDI X12, NACHA files, 1099/K-1 forms are Artifacts, not Systems),
`references/database-vs-table.md` (the store is a Database, the app is a System; tables attach via
`has_table`, columns are properties, join conditions live on `joins_to` edge descriptions).
