# Fix B: create gitignored .mcp.json in repo root (Obsidian MCP for Claude Code).
# Run from repo root:  .\scripts\create-dot-mcp-json.ps1

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$out = Join-Path $repoRoot ".mcp.json"

$key = $env:OBSIDIAN_API_KEY
if (-not $key) {
    $key = Read-Host "Obsidian Local REST API key (regenerate if exposed)"
}

$baseUrl = $env:OBSIDIAN_BASE_URL
if (-not $baseUrl) {
    $baseUrl = "http://127.0.0.1:27123"
}

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
} | ConvertTo-Json -Depth 6 | Set-Content -Path $out -Encoding UTF8

Write-Host "Wrote $out"
Write-Host "Start Claude from repo root:  cd $repoRoot ; claude"
