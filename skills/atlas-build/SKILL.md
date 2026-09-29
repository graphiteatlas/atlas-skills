---
name: atlas-build
description: Use when building an Atlas from source material - a PDF, an SOP, a transcript, a spreadsheet, a set of documents - rather than from a conversation. Covers the whole arc: what Atlas can read and what has to be converted first, the attach-then-cite ordering that fails silently, choosing the unit of work, showing a human the change before writing it, writing it, and verifying by reading back rather than trusting a success response. Invoke alongside atlas-modeling, which decides HOW to model; this decides the order of operations and where the silent failures are.
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
