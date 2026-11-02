# One-time Obsidian MCP setup for Claude Code (same key as Cursor).
# Usage: .\scripts\setup-claude-obsidian-mcp.ps1
# Run from repo root: ~\four-in-a-rogue

$ErrorActionPreference = "Stop"

$key = $env:OBSIDIAN_API_KEY
if (-not $key) {
    $key = Read-Host "Paste Obsidian Local REST API key"
}

$baseUrl = $env:OBSIDIAN_BASE_URL
if (-not $baseUrl) {
    $baseUrl = "http://127.0.0.1:27123"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$mcpPath = Join-Path $repoRoot ".mcp.json"

Write-Host "Writing project .mcp.json (gitignored) at $mcpPath ..."

@{
    mcpServers = @{
        obsidian = @{
            command = "npx"
            args    = @("-y", "obsidian-mcp-server")
            env     = @{
                OBSIDIAN_API_KEY  = $key
                OBSIDIAN_BASE_URL = $baseUrl
            }
        }
    }
} | ConvertTo-Json -Depth 6 | Set-Content -Path $mcpPath -Encoding UTF8

Write-Host "Done. Start Claude Code from this repo so it loads .mcp.json:"
Write-Host "  cd $repoRoot"
Write-Host "  claude"
Write-Host ""
Write-Host "Optional CLI registration (PowerShell — use --% so -y goes to npx):"
Write-Host '  claude mcp add --scope user obsidian -e OBSIDIAN_API_KEY=... -e OBSIDIAN_BASE_URL=http://127.0.0.1:27123 --% npx -y obsidian-mcp-server'
