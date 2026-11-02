# One-time Obsidian MCP setup for Claude Code (same key as Cursor).
# Usage: .\scripts\setup-claude-obsidian-mcp.ps1

$ErrorActionPreference = "Stop"

$key = $env:OBSIDIAN_API_KEY
if (-not $key) {
    $key = Read-Host "Paste Obsidian Local REST API key"
}

$baseUrl = $env:OBSIDIAN_BASE_URL
if (-not $baseUrl) {
    $baseUrl = "http://127.0.0.1:27123"
}

Write-Host "Adding obsidian MCP to Claude Code (base URL: $baseUrl)..."
claude mcp add obsidian `
    -e "OBSIDIAN_API_KEY=$key" `
    -e "OBSIDIAN_BASE_URL=$baseUrl" `
    -- npx -y obsidian-mcp-server

Write-Host ""
Write-Host "Done. Run: claude mcp list"
Write-Host "Then restart Claude Code and test from repo root."
