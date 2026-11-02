# Claude Code + Obsidian MCP (Sean)

Use the **same Local REST API key** as Cursor. Obsidian must be open on the **GameDev** vault while using MCP.

## Option A — CLI (recommended, one time)

From PowerShell (replace the key with yours from Obsidian → Local REST API):

```powershell
cd $HOME\four-in-a-rogue
claude mcp add obsidian `
  -e OBSIDIAN_API_KEY=your-key-here `
  -e OBSIDIAN_BASE_URL=http://127.0.0.1:27123 `
  -- npx -y obsidian-mcp-server
```

Verify:

```powershell
claude mcp list
```

Restart Claude Code if it was running.

## Option B — Project `.mcp.json` (repo-local)

1. Copy the example:

   ```powershell
   Copy-Item .mcp.json.example .mcp.json
   ```

2. Edit `.mcp.json` and paste your API key (this file is **gitignored**).

3. Run `claude` from the repo root so the project MCP config loads.

## Option C — User config `%USERPROFILE%\.claude.json`

Merge into existing `mcpServers` (keep any other servers):

```json
{
  "mcpServers": {
    "obsidian": {
      "command": "npx",
      "args": ["-y", "obsidian-mcp-server"],
      "env": {
        "OBSIDIAN_API_KEY": "your-key-here",
        "OBSIDIAN_BASE_URL": "http://127.0.0.1:27123"
      }
    }
  }
}
```

If you use HTTPS in the plugin: `"OBSIDIAN_BASE_URL": "https://127.0.0.1:27124"`.

## Test in Claude Code

```powershell
cd $HOME\four-in-a-rogue
claude
```

Prompt:

```text
Use Obsidian MCP to read Projects/Four-in-a-Rogue/Design/vertical-slice-v0.1.md and summarize M2.
```

## Design + code workflow

| Task | Where to run `claude` |
|------|------------------------|
| Godot M2+ | `~\four-in-a-rogue` |
| Edit GDD / slice only | `~\Documents\GameDev` (file access) or repo with MCP |

MCP talks to whichever vault is open in Obsidian (should be **GameDev**).
