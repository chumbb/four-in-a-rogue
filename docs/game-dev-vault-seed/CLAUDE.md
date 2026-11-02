# CLAUDE.md — game design vault

**Sean Bishop · solo game design source of truth**

This directory is an **Obsidian vault**. All **game design** decisions live here as markdown. Godot code lives in the parent repo (`../`); do not put implementation-only notes in place of design specs.

## Your job in this vault

- Read and edit design docs under `Projects/`
- Use frontmatter on structured notes (see below)
- **Never invent mechanics** not described in the GDD or vertical slice without asking Sean
- When Sean approves a design change, update the relevant `Design/*.md` file **here first**, then tell Sean to sync repo `CLAUDE.md` if coding rules changed

## Frontmatter

```yaml
---
type: project | gdd | spec | decision | session | daily | note
date: YYYY-MM-DD
project: Four-in-a-Rogue
status: active | locked | draft | archived
tags: []
---
```

## Projects

| Project | Hub | Implementation repo |
|---------|-----|------------------------|
| Four in a Rogue | [[Four-in-a-Rogue]] | https://github.com/chumbb/four-in-a-rogue |

### Four in a Rogue — canonical design files

| File | Purpose |
|------|---------|
| `Projects/Four-in-a-Rogue/Design/GDD.md` | Full-game vision |
| `Projects/Four-in-a-Rogue/Design/vertical-slice-v0.1.md` | **Locked v0.1 rules** for implementation |

**Conflict rule:** `vertical-slice-v0.1.md` wins over GDD for v0.1 scope. Repo `CLAUDE.md` is a coding summary; if it disagrees with this vault, **vault wins**.

## Wikilinks

Use `[[Four-in-a-Rogue]]`, `[[vertical-slice-v0.1]]`, etc.

## Session logs

Store AI session archives in `Projects/<Game>/Session-Logs/` (e.g. from `/compress`).

## Protected

- Do not delete `Design/vertical-slice-v0.1.md` sections without Sean’s approval
- Do not move locked rules into code comments only—vault stays authoritative

## Obsidian MCP

Sean uses Local REST API + `obsidian-mcp-server` in Cursor and Claude Code. Setup: Godot repo `docs/CLAUDE_CODE_MCP.md`. Keep Obsidian open on this vault when using MCP tools.
