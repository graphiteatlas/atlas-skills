# graphite-atlas plugin (first draft, v0.1.0)

The Atlas **modeling skills + MCP server**, bundled into one installable Claude Code plugin.
The point: an MCP gives an agent *hands* (tools to read/write an atlas); this plugin also gives it
*skill* (how to model well) so it stops flailing on trial-and-error.

## What's in the package

```
atlas-skills/                         ← plugin root
├── .claude-plugin/
│   ├── plugin.json                   ← plugin manifest (name, version, description)
│   └── marketplace.json              ← makes this repo an installable marketplace
├── .mcp.json                         ← bundles the Atlas MCP server (graphite-mcp via npx)
├── skills/                           ← 3 skills (auto-discovered)
│   ├── atlas-modeling/               ← preflight: 3 principles + anti-patterns inline
│   │   └── references/               ← 8 deeper worked examples (read on demand, not invoked)
│   ├── atlas-language/               ← the Atlas language: type vocabulary + folders + naming
│   └── atlas-auditing/                  ← read-only health checks (the backstop)
└── commands/                         ← optional slash-command sugar
    ├── atlas-model.md                ← /atlas-model  (preflight then model)
    └── atlas-audit.md                ← /atlas-audit  (run the health audit)
```

**Why 3 skills, not 11:** the 8 anti-patterns used to be separate skills, but a model won't invoke a
narrow anti-pattern skill at the exact moment it's about to violate it (not recognizing the situation
*is* the bug). So they're folded into `atlas-modeling` as an always-present checklist, with the full
worked examples in `references/` for depth, and `atlas-auditing` as the deterministic backstop that
catches what prevention misses.

So one install delivers: **MCP tools + modeling know-how + two commands.**

## Install (local first draft)

```
# in Claude Code
/plugin marketplace add graphiteatlas/atlas-skills
/plugin install graphite-atlas
```

Set your token in the environment the plugin's MCP server reads:

```
export GRAPHITE_ACCESS_TOKEN=<your token from graphiteatlas.com → Profile → API Apps>
```

Restart Claude Code. You should now have the `mcp__graphite-atlas__*` tools AND the atlas skills
loaded. Try `/atlas-model` then ask it to build a small process; it should consult the skills
(type correctly, attach properly, instance vs singleton) instead of guessing.

