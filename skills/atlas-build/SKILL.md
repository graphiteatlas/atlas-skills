---
name: atlas-build
description: Use when building an Atlas from source material - a PDF, an SOP, a transcript, a spreadsheet, a set of documents, or a cache of dozens of them - rather than from a conversation, AND when adding new material to an atlas that already exists. Covers the order of operations: reading the sources and keeping the sentence each fact came from, choosing the unit of work, proposing the change in chat before writing it, labelling what you inferred, asking only the questions that change the model, writing it, verifying by reading it back, and matching, editing and superseding rather than duplicating when the atlas already has points. Invoke alongside atlas-modeling, which decides HOW to model; this decides in what order.
---

# Atlas: build from documents

`atlas-modeling` decides **how** to model. This decides **the order of operations**:
what to read, what unit to work in, what to show a person before writing, how to
label what you inferred, and how to add to an atlas that already has content.

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

## 1. Read the sources yourself, then make them citable

**Read the documents yourself. You are better at it than any extraction pipeline.**
Model from what you read, and for each fact keep the sentence you took it from,
verbatim, plus its page. That sentence is what makes the fact checkable later, and
collecting it as you read costs nothing; reconstructing it afterwards is most of a
day.

**A citation needs the document to be in the atlas.** Attach the file to the Point
it is *about* (the process, the entity, the system), which creates the Document
Point and wires `extracted_from` in one step:

```
attach_file_to_point(atlas_id, point_id, file_path)
```

If no such Point exists yet, create that one Point first and attach to it.

**Then cite with the exact sentence**, because the quote is verified server-side
against the document's own extracted text:

```
create_path(atlas_id, name: 'extracted_from', source: <point>, target: <document>,
            properties: { citations: [{ quote: '<verbatim sentence>', page: 7 }] })
```

- **The quote must appear verbatim.** Not paraphrased, not trimmed to a fragment
  that got reflowed, not your summary of it.
- **A citation with no quote stores nothing.** `{page: 2}` alone is not a citation,
  and should not be counted as coverage.
- **One end of the Path must be the Document**, because that is what the quote is
  checked against.
- **You cannot bluff.** An invented quote does not become evidence by being
  well-formed.

**If a fact has no quotable sentence, leave it uncited and say so.** An uncited
point is an honest gap a reviewer can act on. A stretched quote is worse than a
gap, because it looks like evidence.

**Attach before you cite, and let indexing finish.** A document that has not
finished indexing has nothing to verify against. See *Rough edges* for how that
currently fails.

## 2. Choose the unit of work

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

## 3. Propose before you write

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
PROPOSAL - Vendor Onboarding, from Supplier Setup SOP v4.pdf
12 new · 4 edited · 2 superseded · 3 inferred · 2 questions

NEW
  Step  Run Credit Check        "A credit check is ordered within 5 days
                                 of the signed agreement."               p.7
  Step  Verify Bank Details     "Bank details must be verified before
                                 the first payment run."                 p.7
EDITED
  Step  Assign Buyer            + alias "Category Owner"                 p.6
SUPERSEDED
  Step  Manual Supplier Log     replaced by Run Credit Check             p.7
INFERRED (no source states these)
  Run Credit Check -> Verify Bank Details    both listed under day 5
QUESTIONS
  1. Does Verify Bank Details block the credit check, or run alongside it?
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

## 4. Write it

**Properties go inside `properties`**, never spread at the top level.

**A Document Point's name includes the file extension.** A view or reference that
names the document without it matches nothing.

**Use ids, not names.** Look the Point up once, keep the id, and reference the id
from then on. Writing by name on an atlas of any size is how you get duplicates
that look like typos.

**Make each batch a complete, meaningful unit**: a process with its steps, or one
view's worth of paths. Not "the next fifty things on my list". A batch that fails
halfway should leave something coherent behind, which matters most from a chat
client, where you cannot resume the way a script can.

**Keep your own list of what you have written, with ids, as you go.** In a chat
client that list is the only state you have, and it is the difference between
resuming and starting over.

**Refused by the ontology?** Check `atlas-language` for what is sayable and which
types may connect, including the decision table for when nothing fits. If the
thing you need genuinely has no type, say so rather than forcing a near-miss: a
near-miss type looks correct and answers queries wrongly.

## 5. Verify by reading back

**Read the graph back and check it says what you meant.** Not because writes fail
often, but because a write confirms that it was accepted, not that the model is
right, and those are different claims.

```
list_paths(atlas_id)          citation_count on each path that carries one
get_path(atlas_id, path_id)   the quotes themselves
list_files(atlas_id)          what is attached and whether it extracted
```

Three things worth checking every time: that each cited Path came back with a
citation, that every document you attached is in the views you expected, and that
each view you created is where you meant it rather than at the root.

A cited Path that comes back with no citation almost always means the quote did
not match the extracted text, or you wrote before indexing finished.

Then run `atlas-auditing` for what is wrong and `atlas-completeness` for what is
missing, in that order: wrong beats thin.

## 6. Adding to an atlas that already exists

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

Search the **aliases** too, not just names. A process recorded as "Supplier
Invoice Reconciliation" with the alias "Invoice Recon" will not be found by the
second phrase unless you look for it. Where you find a match, use it and keep its id. A
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

**Check `model_status` in both places.** It can appear as a field and inside the
properties blob, and an older atlas may carry it only in the properties string: one
has 166 paths retired that way. Check the field alone and you will treat every one
of them as live, re-model things that were deliberately retired, and report the
atlas as inconsistent when it is not.

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

**Propose the whole change before writing any of it**, as in section 3, and say
plainly which points you are creating, which you are editing, and which you are
superseding. "12 new, 4 edited, 2 superseded" is the sentence a reviewer needs; a
list of 18 writes is not.

## Rough edges, as of 2026-10-08

**Everything above is how to work. This is what is awkward right now.** It is dated
because it is meant to shrink: delete an entry when it stops being true, rather
than carrying it forever. If something here contradicts what you observe, trust
what you observe.

**Not every file format yields text.** Atlas extracts from PDF, `.docx` and
plain-text formats. A spreadsheet, a deck or a diagram file may upload without
producing citable text, so the Document Point exists and has nothing in it. Convert
before uploading where you can: a spreadsheet to CSV rather than PDF, so the
structure stays citable; a diagram or a multi-sheet workbook to PDF. **From a chat
client you cannot convert anything**, so say so before the upload and ask for a
PDF, `.docx` or CSV instead.

**Check extraction before citing, not after.** `list_files` reports each file's
status and chunk count. A file is ready when the status is terminal **and** the
chunk count is above zero: status alone goes terminal for a scan or an image with
no text layer, so a document can be "done" and unreadable. If the chunk count stays
at zero, stop and say the document has no text rather than citing it.

**Citing before indexing finishes does not work**, and what happens depends on the
version you are talking to: newer builds refuse the write outright, naming the
document; older ones accepted the write and dropped the citations. Either way the
answer is the same, wait and send it again, and section 5 is how you find out which
happened.

**Large batches have practical limits.** Resolving Points by name is capped, which
is the main reason to write by id. Bulk deletes time out well before a long list
finishes, so delete in small batches and read back rather than resending the same
list after a timeout.

**A `.docx` exported from a chat or meeting tool is often mostly images**, one
avatar per utterance, which can make the file too large to ingest while containing
every word you want. Export to PDF instead; the export deduplicates them.

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
