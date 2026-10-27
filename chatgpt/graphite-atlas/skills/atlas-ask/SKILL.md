---
name: atlas-ask
description: "Use when someone asks a question a Graphite Atlas can answer: how a process works, who does a step, what happened on a job and who did it, how long steps take, or what a job is waiting on. Covers finding the right atlas, reading the process map, and querying the activity history (events on each job, with evidence)."
---

# Answer questions from a Graphite Atlas

An atlas has two parts:

- **The map:** how the business works. Processes, steps, roles, people, systems and the
  paths between them.
- **The activity history:** what happened on each job. An *event* is one run of a map step,
  at a time, on a job (its *case*), done by someone, with the record that shows it.

"How does X work" is a map question. "What happened on job Y" is a history question. Many
questions need both: the map names the steps, the history says which ran and when.

You only read. Never call a tool that creates, updates, deletes or loads anything while
answering a question.

## 1. Find the atlas

Call `list_atlases` (or `search_atlases` with the company name) and pick the atlas by name.
If two could fit, ask which one. Then `get_atlas_brief` for its processes and main points.

## 2. Map questions

- Find steps and people with `search_points` (by name) or `semantic_search` (by meaning).
- Follow a process with `traverse` or `get_node_neighborhood`: its steps, who performs each,
  the systems used, the inputs and outputs.
- Use the `atlas-language` skill for what each point and path type means.

## 3. History questions

Call `describe_schema` first: its `atlas.activity` section gives the counts of events and
jobs. Then query with `query_atlas` (read-only SQL). The tables:

| table | columns |
|---|---|
| `events` | id, occurrence_id, step_id, occurred_at, occurred_from, occurred_to, time_basis, exact, confidence, source_system, attributes |
| `event_objects` | event_id, object_id, qualifier (`case`, `performed_by`, `evidence`, `creates_output`, `needs_input`) |
| `objects` | id, type_id, source_system, number, name, attributes |
| `points` | id, name, type: the map. `events.step_id` is a step point |
| `directly_follows` | case_id, from_step_id, to_step_id, from_at, to_at, both_exact, ordered, min_confidence |

**What happened on a job, and who did it:**

```sql
select to_char(min(e.occurred_at), 'YYYY-MM-DD') as day, s.name as step,
       string_agg(distinct coalesce(pp.name, po.name), ', ') as who,
       string_agg(distinct e.source_system, ', ') as sources,
       string_agg(distinct e.time_basis, ', ') as time_basis
from objects j
join event_objects ej on ej.object_id = j.id and ej.qualifier = 'case'
join events e on e.id = ej.event_id
left join points s on s.id = e.step_id
left join event_objects ep on ep.event_id = e.id and ep.qualifier = 'performed_by'
left join objects po on po.id = ep.object_id
left join points pp on pp.id = po.type_id
where j.name ilike '%<job name>%'
  and e.occurred_at >= '<from>' and e.occurred_at < '<to>'
group by e.occurrence_id, s.name
order by min(e.occurred_at), s.name
```

One row per happening. A happening seen in several sources (a Monday post, a calendar
entry, a document) is one event per source, joined by a shared `occurrence_id`: group by it,
and `sources` lists where it was recorded. An event can also name both a person and their
role (`Tyson Woodham, Project Manager`). Without the grouping, one happening comes back once
per source and per performer. Count happenings with `count(distinct e.occurrence_id)`.

Find the job first if you are unsure of its name:
`select distinct j.number, j.name from objects j join event_objects eo on eo.object_id = j.id and eo.qualifier = 'case'`.

**The evidence for an event:** join `event_objects` with qualifier `evidence` to `objects`
and read its `name`: a document, a message or a calendar entry.

**How long between steps:** use `directly_follows`, only rows with `both_exact` and
`min_confidence >= 0.8`, and say how many rows were left out.

## 4. How to answer

- **Lead with the answer**, then the events behind it: date, step, who, and the source.
- **Say how far the history goes.** Give the date of the job's latest event. Anything after
  it is not in the atlas, so say "the atlas has nothing after <date>", not "nothing happened".
- **Dates, not times,** unless `exact` is true. A date-only event may show a placeholder time
  such as noon; never quote it.
- **Name jobs by their number and name, people by name.** Never show ids or hashes.
- **Same day, order unknown** when `directly_follows.ordered` is false.
- A step with no events did not necessarily not happen: it may not have been recorded. Say
  "no record of" rather than "never".
