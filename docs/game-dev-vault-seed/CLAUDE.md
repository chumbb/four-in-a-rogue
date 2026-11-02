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

## Record everything here (Sean, 2026-11-02)

Every Claude and Cursor session stores its work in this vault — not only in chat or the repo:

| What | Where |
|------|-------|
| Session summary (what was done, state, open items) | `Projects/<Game>/Session-Logs/YYYY-MM-DD <Tool> - <topic>.md` (`type: session`) |
| Decisions Sean makes | Append a row to `Projects/<Game>/Decisions/Decision-Log.md`; if a rule changed, update `Design/vertical-slice-v0.1.md` / `GDD.md` too |
| Research, findings, reports | `Projects/<Game>/Research/<title>.md` (`type: note`) |

Link new notes from the project hub (e.g. [[Four-in-a-Rogue]]). Write during the session, not only at the end.

## Obsidian MCP

Sean uses Local REST API + `obsidian-mcp-server` in Cursor and Claude Code. Setup: Godot repo `docs/CLAUDE_CODE_MCP.md`. Keep Obsidian open on this vault when using MCP tools.

## Reaching this vault from a Claude app session

Claude sessions in the Claude app (not the local `claude` CLI) don't load the repo's `.mcp.json`. They read and edit these files directly through folder access to `C:\Users\Sean\Documents\GameDev`.
