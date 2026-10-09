# Abbreviations: full words in the name, short form in aliases

**The name carries the words a stranger can read. The short form goes in `aliases`.**

```
✗  "FO Support"                       (reader outside the company cannot expand it)
✓  "Field Operations Support"   properties: aliases: ["FO Support"]

✗  "CM Daily Reports"
✓  "Construction Management Daily Reports"   aliases: ["CM Daily Reports"]
```

This is the same principle as name-by-function, applied to legibility. An SOP or process book is
read by people who were not in the room, including new starters, auditors and the customer's own
other departments. An unexpanded abbreviation makes them guess. The alias keeps the short form
searchable, so the people who do use it lose nothing.

**The exception: when the letters ARE the name.** `Director EHS`, `RFI`, `NTP`, `PCO`. If the room
says the letters and nobody says the expansion aloud, the letters are the name. Test: ask what the
expansion is. If people hesitate, it is a name, not an abbreviation.

**`aliases` holds alternate names for the SAME thing.** Four kinds legitimately belong there:
abbreviation (`PM`), spoken synonym (`post-mortem` for the closeout meeting), prior name
(`Change Order Spreadsheet` / `Change Order Log`), and informal reference (`the field`).

Three things do NOT belong there, and all three were found in a real production atlas:

```
✗  aliases: "Jane Dow"             on Person "Jane Doe"         (a MISSPELLING, not an alias.
                                                                 Fix the source, do not enshrine it)
✗  aliases: "the team's request log" on "Request Log"           (one person's INSTANCE of the thing.
                                                                 If it differs, it is another Point)
✗  aliases: "Build Project in <vendor tool>" on Process "Project Setup"
                                                                (a DIFFERENT CONCEPT, and it bakes a
                                                                 vendor in through the back door)
```

The test: **would a reader accept the alias as a name for this Point, out loud, in a sentence?**
If not, it is not an alias.

**Two mechanical traps.**

`aliases` is **not declared in the ontology's property list**, though it is used widely and the
Navigator prompt documents it. So nothing validates it. Write it carefully; you will get no error.

`aliases` is **array-valued, and `update_point` merges at the property level, not inside the
value.** Writing `aliases: ["FO"]` onto a Point that already holds `["FO", "the field"]` REPLACES
the array and silently loses the second entry. Always read the existing value first and write the
union. This is the single easiest way to destroy data in an otherwise safe property merge.

**Store one shape.** The same atlas held both `aliases: ["FO", "the field"]` and `aliases: PO`, a
bare string. Always write a list, even for one entry, so every consumer can iterate without
type-checking.
