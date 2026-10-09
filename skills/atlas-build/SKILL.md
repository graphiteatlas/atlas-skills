---
name: atlas-build
description: Use when building an Atlas from source material - a PDF, an SOP, a transcript, a spreadsheet, a set of documents, or a cache of dozens of them - rather than from a conversation, AND when adding new material to an atlas that already exists. Covers the whole arc: what Atlas can read and what has to be converted first, the attach-then-cite ordering that fails silently, choosing the unit of work, proposing the change in chat before writing it, labelling what you inferred, asking only the questions that change the model, writing it (including from a chat client with only the MCP tools), verifying by reading back rather than trusting a success response, and matching, editing and superseding rather than duplicating when the atlas already has points. Invoke alongside atlas-modeling, which decides HOW to model; this decides the order of operations and where the silent failures are.
---

# Atlas: build from documents

`atlas-modeling` decides **how** to model. This decides **the order of operations**,
and it exists because most of what goes wrong here goes wrong quietly: the write
reports success and the result is not what you asked for.

*Terms: Atlas calls graph nodes **Points** and edges **Paths**. A citation lives on
the Path, not the Point.*

## Two paths, and you should know which you are on

**In the app.** Upload a document and Atlas proposes a model, shows it to you as a
proposal you can read, lets you correct it, and builds on approval. If you are a
customer with an Atlas, this is the path. It is a product feature, it is kept
current, and nothing in this skill replaces it.

**From an agent, over MCP or the HTTP API.** You compose the change yourself. You
get more control and no safety net: none of the review surface is there unless you
build it. Everything below is written for this path. If you are on the first path
and something here contradicts what the app does, the app is right.

## 1. Prepare: what Atlas can actually read

Atlas extracts text from **PDF, `.docx` and plain-text formats**. Anything else is
where builds quietly lose most of their evidence.

As of 2026-09, an unsupported format **uploads successfully** and writes a warning
string into the Document Point instead of the document's content. Nothing looks
wrong until a citation matches the apology. This affects `.xlsx`, `.pptx`, `.doc`,
`.xls`, `.ppt` and `.vsdx`, which between them are most of what people send.

So before uploading anything that is not a PDF, a `.docx` or plain text:

- **Convert it yourself.** A spreadsheet to CSV rather than PDF, so the structure
  stays citable. A multi-sheet workbook to PDF if the sheets only make sense
  visually. A diagram export to PDF.
- **Convert it rather than asking for a re-export.** The person can usually oblige,
  but their own export is often partial in ways nobody notices until the citations
  come up short: a ten-page diagram workbook exported by hand covered two pages.
- **Check the text survived**, not just that the file uploaded. See step 2.

**In a chat client you cannot convert anything**, so the move is to say so before
the upload rather than after. Name the file, say Atlas will store a warning string
instead of its contents, and ask for a PDF, a `.docx` or a CSV. Uploading it anyway
"to see" costs a Document Point whose body is an apology and citations that match
it. If it is already uploaded, `list_files` showing `chunkCount` 0 is the proof,
and the honest report is that the document is not readable rather than that it is
thin.

A `.docx` that is mostly images is its own trap. Exported chat and meeting
transcripts often carry one avatar image per utterance, which makes the file large
enough to fail ingestion while containing every word you want. Strip the media or
export to PDF instead; the PDF export deduplicates the images.

## 2. Ingest: attach first, wait for chunks, THEN cite

**This is the single most common way this workflow fails, and it has no error
message.**

A citation is verified server-side against the document's extracted text at write
time. If the file has not finished ingesting there are no chunks, the verifier
loads empty text, no quote matches, and **every citation is stripped silently**.
The Path is still created. The write reports success. The citations are gone, and
you find out when someone opens the panel and the evidence is not there.

**Read the document yourself first.** You are better at it than the pipeline. Model
it now, following `atlas-modeling`, and keep for each fact the sentence you took it
from, verbatim, plus its page.

**Attach the file before any point or path work:**

```
attach_file_to_point(atlas_id, point_id, file_path)
```

This creates the Document Point, uploads, and wires `extracted_from` in one call.
`point_id` is what the document is *about*: the process, the entity, the system.
If no such Point exists yet, create that one Point first and attach to it.

**Then poll until it is genuinely ready:**

```
list_files(atlas_id)
```

Ready means **`status` is terminal AND `chunkCount` > 0**. Both. `status` alone
goes terminal for a file with no extractable text, such as a scan or an image, so
a document can be "done" and unreadable. A large PDF takes tens of seconds. Poll;
do not sleep once and assume.

**If `chunkCount` stays 0, stop.** The document has no text layer. Say so. Do not
write citations against it: every one will be stripped.

A failed ingestion is currently not surfaced to the person who uploaded the file,
so checking this yourself is not optional politeness, it is the only way anyone
finds out.

## 3. Choose the unit of work

**The unit is rarely the document.** This is the design decision that costs the
most when you get it wrong.

Documents about the same process disagree with each other, and the disagreements
are the interesting part. A transcript of people doing the work and a summary
written about it afterwards will differ, and **the transcript usually wins**: it is
what happened, not what someone remembers or intended.

So: group the documents by the thing they describe, and produce **one proposal per
process**, not one per document. Then reconcile across processes, because they
share teams, systems and names.

Building per document gives you a stack of overlapping, contradictory drafts to
merge by hand, and the merge is harder than the modeling was.

Expect to resolve, every time:

- **Same thing, different names.** Two documents naming one system differently.
- **Different things, same name.** A step called the same thing in two processes
  that is genuinely two different activities.
- **One thing, several shapes.** A team modelled four ways by four authors.
- **A source that is simply wrong.** A diagram that mislabels a step the transcript
  describes twice.

None of that is mechanical. It is the work.

### A cache of dozens of documents

Same rule, harder to hold. Do not start at file 1 and read to file 40.

**Inventory before you read.** Filename, date, type, and one line on what it
appears to describe. Cheap, and it is what lets you group. Dates matter more than
they look: two documents describing one process a year apart are a current state
and a historical one, not a contradiction to reconcile.

**Group by the thing described, then take one group at a time** through model,
propose, write, verify. A group is a process. Finish it before opening the next.

**One pass holds about one process.** Past that you start losing the detail of
what you read early, and the symptom is subtle: you keep the shape and lose the
specific sentence you needed for a citation, so coverage quietly drops. If a group
is too big for one pass, decompose the process first and take a sub-process per
pass.

**Read the structure the rules require, not the structure the files have.** A
folder layout, a deck's section order and a drive's naming convention are how
somebody filed things, not how the work runs. **If the tree you are given is
broken, report that as a finding** rather than reproducing it in the model: a
model that mirrors a bad filing system looks organised and answers nothing.

**Some files will not be worth modelling at all.** Say which you skipped and why.
A list of 40 files where 12 were used is a fact about the engagement; silently
reading all 40 into one flat view is how a fifty-point view happens.

## 4. Propose before you write

**Show a human the model before it touches the graph.** In the app this is the
proposal screen. From an agent it is whatever you can put in front of someone: a
file-based mock of the folders and views, a rendered document, a plain list of the
Points and Paths you are about to create.

The point is not ceremony. A model written from documents is wrong in specific,
findable ways, and a person who knows the business finds them in minutes. After the
write those same errors take an audit to find.

State what you could NOT determine, rather than filling it in. A gap you name is a
question someone can answer; a gap you guess at is a fact nobody will check.

### The proposal, in chat

**Print it in the conversation. Do not build an artifact for it.** Artifacts are
specific to one chat client and this has to work in any of them, and a proposal
exists to be corrected in the moment, which a separate surface the reader has to
open works against.

Counts first, because that is the line a reviewer actually needs. Every new fact
carries its verbatim quote and page. Inferences in their own block. Questions last.

```
PROPOSAL - Vendor Onboarding, from Referral SOP v4.pdf
12 new · 4 edited · 2 superseded · 3 inferred · 2 questions

NEW
  Step  Order Title Search      "The supplier orders a title search within
                                 5 days of referral."                    p.7
  Step  Confirm Occupancy       "Occupancy must be confirmed before..."  p.7
EDITED
  Step  Refer to Counsel        + alias "Attorney Referral"              p.6
SUPERSEDED
  Step  Manual Referral Log     replaced by Order Title Search           p.7
INFERRED (no source states these)
  Order Title Search -> Confirm Occupancy    both listed under day 5
QUESTIONS
  1. Does Confirm Occupancy block the title order, or run alongside it?
```

**If it is too long to read in a chat message, the unit of work is too big.** That
is section 3's problem, not a reason to change the medium. A proposal nobody can
read is the same failure as a model nobody checks.

Keep the rendered, in-app document for the proposal screen. This is the chat
version of the same thing, not a replacement for it.

### Label what you inferred

**Most of a model from documents is inference, and that is legitimate.** Nobody
writes down the whole process. You read six documents, listen to one call, and fill
the gaps with what must be true. What is not legitimate is an inference that stops
being visible as one, because six weeks later nobody can tell what was observed
from what was assumed.

**Step order is where this bites hardest.** Sources almost never state sequence. One
customer atlas had **0 of 663 sequence arrows** supported by a citation; on another,
most of the open questions were nothing but "does A come before B". If you model a
flow at all, you are inferring order, so say so.

**Label it on the thing itself, when you write it:**

```
source_ref: "inferred 2026-10-08: both steps are listed under day 5 in the SOP,
             and the second cannot start without the first's output"
```

One property, `source_ref`, beginning `inferred <date>: <basis>`. The basis is the
part that matters: *why* you believed it, in a sentence a reviewer can agree or
disagree with. "inferred" alone records that you guessed without saying from what.

**An unlabelled inference is a defect, not a style choice.** A new Path whose
`source_ref` neither cites a source nor says it was inferred has lost the
distinction permanently, and no later audit can recover it: the graph looks the
same either way.

**Mark them in the proposal too**, as their own block rather than mixed in with the
cited facts. The reviewer reads a different way: a cited fact they skim, an
inference they check. Mixing the two costs you the checking.

**When someone confirms one, write it back** as `confirmed_on` and `confirmed_by`
rather than quietly deleting the label. An inference that was tested and held is
worth more than one nobody ever questioned, and only the write-back can tell those
two apart.

**Rank them by what breaks if you are wrong.** A flat list of thirty is a list
nobody reads by week three. The useful test: if this turned out false tomorrow,
would we redo nothing, one view, or the deliverable? Only the third is urgent, and
that is the one to put in front of a person.

### Ask only what matters

**A long question list does not get answered.** That is the argument, not
politeness. One engagement reached 67 open questions, most of them establishing
only whether step A came before step B, and the three that genuinely mattered
drowned among the sixty that did not. A short list gets answered.

Before a question reaches the customer, ask whether the answer would change:

- who owns or answers for a piece of work;
- a compliance or financial risk;
- money or time;
- a structure a reviewer could not catch by looking at the map.

**If none of those, do not ask it.** Infer it, from the sources, from file dates,
from earlier answers or from plain logic, label it as inferred, and let the map
carry it. A sequence nobody disputes is a sentence you can write yourself and they
can correct in ten seconds while reading it.

**And the inverse: if the answer would not change what you build, it is not a
question.** It is curiosity, and it spends someone else's attention.

**The two halves are one bargain.** Infer aggressively only because every inference
is labelled and therefore correctable. Without the labels, "infer the rest" is
guessing with extra steps. With them, the map is a draft the customer corrects
rather than a claim they have to audit, and they confirm the inferences as a whole
when they sign off the map rather than one question at a time.

**A wrong inference is cheap. A wrong inference nobody can find is not.** That is
the whole reason the labelling rule above is not optional.

Aim for a handful of questions, asked with the proposal, not a questionnaire sent
ahead of it.

## 5. Write, and the traps

**Citations, which are strict:**

```
create_path(atlas_id, name: 'extracted_from', source: <point>, target: <document>,
            properties: { citations: [{ quote: '<verbatim sentence>', page: 7 }] })
```

- **`quote` is the anchor.** It must appear in the extracted text **verbatim**. Not
  paraphrased, not trimmed to a fragment that got reflowed, not your summary. A
  quote that does not match is dropped.
- **The edge must have the Document at one end.** The verifier resolves the
  document from the edge itself, so citations on an edge between two non-Document
  Points have nothing to verify against and are dropped. Any relationship name
  works as long as one end is the Document.
- **A citation with no `quote` is dropped entirely.** `{page: 2}` alone stores
  nothing. If you cannot find a verbatim sentence, the fact gets no citation, and
  that is the honest outcome. Do not count page-only citations as coverage.
- **You cannot bluff.** A fabricated quote on a correctly targeted edge is silently
  dropped too.
- **`page` is a fact about the document**, not the citation. Set it only for a
  paginated format; never invent one for a `.txt` or `.csv`.
- **Properties go inside `properties`**, never spread at the top level.

**Names and documents.** A Document Point's name includes the file extension. A
view or reference that names the document without it matches nothing, silently.

**Large writes.** Past roughly twenty Points or Paths, go over the HTTP API from a
script rather than through individual tool calls: it is faster, it is resumable,
and a batch that fails tells you where. Write it phased, with state, so a failure
halfway does not mean starting again.

**The HTTP payload shapes are not the MCP tool shapes.** Read the API's own
definitions rather than assuming the tool arguments carry across; they do not, and
the mismatch surfaces as a rejected batch rather than a helpful error. Check the
batch for duplicate names and unverifiable quotes before sending it: past twenty
items, finding out afterwards means reading the graph back to work out what landed.

### Writing from a chat client, where you cannot run a script

The advice above assumes a shell. In a chat client you have the MCP tools and
nothing else, so "go over the HTTP API from a script" is not available to you and
the limits below are the ones that bite instead.

- **Use ids, never names.** The batch endpoint resolves a name against the atlas,
  and that lookup is capped at 1000 points **per scenario** (#2752). Past that it
  silently does not find the point you meant and you get a new one. Create or look
  up the point, keep the id, and reference the id from then on. On any atlas of real
  size, writing by name is how you get duplicates that look like typos.
- **Keep a batch to roughly 20 to 50 items**, and make each batch one complete,
  meaningful unit: a process with its steps, or one view's worth of paths. Not
  "the first 50 things in my list". A batch that fails halfway should leave
  something coherent behind, because you cannot resume from a crash the way a
  script can.
- **Deleting is the sharpest limit.** `bulk_delete_points` times out at 30 seconds,
  which in practice means **10 to 20 ids per call** (#2833). A timeout tells you
  nothing about how many were deleted, so re-read before retrying rather than
  sending the same list again. Prefer superseding to deleting; see section 7.
- **Write phase by phase and verify between phases**, not at the end. Points, read
  back, then paths, read back, then views. Section 6 is not a final step here, it is
  the thing you do between every batch. A chat client gives you no transcript of
  what landed except the one you keep yourself.
- **Keep your own list of what you have written**, with ids, as you go. It is the
  only state you have. If the conversation is interrupted, that list is the
  difference between resuming and starting over.
- **One tool call per fact is fine for small work.** Below roughly twenty items,
  individual `create_point` and `create_path` calls are easier to verify and no
  slower in any way that matters. The batch endpoint is for volume, not for tidiness.

**Refused by the ontology?** Check `atlas-language` for what is sayable and which
types may connect. If the thing you need to express genuinely has no type, that is
a gap in the ontology, not something to model around with a near-miss type. Say so
rather than forcing it.

## 6. Verify by reading back

**Do not trust the write's success response.** Almost every failure in this skill
reports success.

```
list_paths(atlas_id)          → citation_count on each path that carries one
get_path(atlas_id, path_id)   → the quotes themselves
list_files(atlas_id)          → status and chunkCount
```

A path you cited that comes back with no `citation_count` was stripped, and that is
almost always step 2: you wrote before ingestion finished.

Check that every document you attached is actually in the views you expected, and
that every view you created is where you meant it to be rather than at the root of
the hierarchy.

Then run `atlas-auditing` for what is wrong, and `atlas-completeness` for what is
missing. In that order: wrong beats thin.

## 7. Adding to an atlas that already exists

A fresh build and an addition are different jobs. In an addition the atlas is the
senior document: it already carries decisions, names and citations that someone
reviewed, and your new source is one more input, not the truth. Most of the damage
done to an existing atlas is done by an agent that treated it as empty.

**Match before you create.** Before adding any point, look for it:

```
search_points(atlas_id, query)        exact and partial on name and aliases
semantic_search(atlas_id, query)      the same thing said differently
find_similar_points(atlas_id, ...)    near-duplicates you would not think to search
```

Search the **aliases** too, not just names. A process recorded as "Supplier Invoice
Reconciliation" with the alias "Advance Recon" will not be found by the second
phrase unless you look for it. Where you find a match, use it and keep its id. A
duplicate point is worse than a missing one: it splits the citations, the views and
the history of one real thing into two half-records, and nothing in the product
flags it.

**Change the point rather than adding a second one.** When a new source refines
something that already exists, `update_point` it: extend the description, add the
alias, correct the type. The citations already attached stay attached, which is the
whole reason to edit rather than replace.

**Supersede; do not delete.** When something is genuinely no longer true, set
`model_status: superseded` rather than removing it. Deleting destroys the record of
what was believed and the evidence for it, and in an atlas somebody reviewed that
record is the point. A superseded point stays answerable to "what did we think in
September, and what changed it".

**Read `model_status` from both places.** It lives as a field **and** inside the
properties blob, and a backfill moving the old ones into the field has not finished
(#2702). One customer atlas has 166 paths retired only in the properties string. If
you check the field alone you will treat all of them as live, re-model things that
were deliberately retired, and report an atlas as inconsistent when it is not.

**Carry citations forward.** If you supersede a point and create its replacement,
the replacement needs its own `extracted_from` edge and quote from your new source.
It does not inherit the old one, and the old citation stays with the old point,
which is correct: that quote supported the old claim.

**A contradiction is a finding, not a merge conflict.** When your source disagrees
with what the atlas says, do not quietly overwrite it and do not average the two.
Say which point, what the atlas claims, what your source says, and the quote. Then
ask. A customer can settle it in one sentence, and the alternative is an atlas that
disagrees with the document it cites. The same holds when your source is newer: more
recent is not automatically more right, and a transcript of someone describing the
work usually beats a procedure document describing the intent.

**Retire paths the same way.** A sequence that changed is a superseded
`followed_by` plus a new one, not an edited edge, when the old order was something
anyone relied on.

**Propose the whole change before writing any of it**, as in section 4, and say
plainly which points you are creating, which you are editing, and which you are
superseding. "12 new, 4 edited, 2 superseded" is the sentence a reviewer needs; a
list of 18 writes is not.

## Reading a document that is already in the atlas

**Atlas's own retrieval tools are Navigator-only.** `search_document`,
`read_document_pages` and `get_document_overview` exist in the in-app Navigator and
are **not** exposed over MCP. Some MCP tool descriptions mention `search_document` in
passing; that describes what indexing enables in the app, not a tool you can call
from here.

Fetch the file instead. `list_files` returns a `viewerUrl` per file and accepts the
same bearer token as any other call, so download it and read it locally.

That is usually better anyway. You read the real document rather than a retrieved
snippet, and **a quote taken from the file you just read is far more likely to match
the extracted text verbatim**, which is what the citation verifier requires. What it
costs you is the chunk index: for a large document, search your local copy rather
than expecting the atlas to search it for you.

## Auditing an atlas that already has documents

`list_paths` reports `citation_count` only where citations exist, so the paths
missing it are your gap list. Walk the edges into each Document Point and, for each
uncited one, either find the supporting sentence or say plainly that the document
does not support the claim.

**An uncited point is not a failure to be fixed by stretching a quote.** A point the
document genuinely does not establish should stay uncited, and is worth reporting as
such. An uncited claim that nobody flags becomes a fact by default, and a stretched
quote is worse than an honest gap: it looks like evidence.
