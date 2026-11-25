# Export the Web build (release) and push it to itch.io with butler.
# iPhone test build (Sean, 2026-11-25). Run from the repo root:
#   powershell -ExecutionPolicy Bypass -File tools/itch/push_web.ps1 -Target <itch-user>/<game>
# The target can also come from the ITCH_TARGET environment variable.
# Flags: -DebugBuild exports a debug build (F4 panel, » button; for Sentry tests),
#        -SkipExport pushes export/web as it is, -DryRun only shows what would happen.
# One-time setup: get butler from https://itchio.itch.io/butler, put it on PATH
# (or set BUTLER to its full path), then run `butler login`.
param(
	[string]$Target = $env:ITCH_TARGET,
	[string]$Channel = "html5",
	[switch]$DebugBuild,
	[switch]$SkipExport,
	[switch]$DryRun
)
$ErrorActionPreference = "Stop"
$repo = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $repo

if ([string]::IsNullOrWhiteSpace($Target) -or $Target -notmatch "^[^/\s]+/[^/\s]+$") {
	Write-Error "Give the itch.io target as -Target <user>/<game> (or set ITCH_TARGET)."
}

$butler = $env:BUTLER
if ([string]::IsNullOrWhiteSpace($butler)) {
	$cmd = Get-Command butler -ErrorAction SilentlyContinue
	if ($cmd) { $butler = $cmd.Source }
}
if ([string]::IsNullOrWhiteSpace($butler) -or -not (Test-Path $butler)) {
	Write-Error "butler not found. Get it from https://itchio.itch.io/butler, put it on PATH (or set BUTLER), then run 'butler login'."
}

$godot = $env:GODOT
if ([string]::IsNullOrWhiteSpace($godot)) {
	$godot = "godot"
}
if (-not (Test-Path "config/telemetry_keys.gd")) {
	Write-Warning "config/telemetry_keys.gd is missing: this build will send no telemetry."
}

# Version shown on itch.io: application/config/version + the short commit.
$version = (Select-String -Path project.godot -Pattern '^config/version="(.+)"').Matches[0].Groups[1].Value
$commit = (git rev-parse --short HEAD).Trim()
$userVersion = "$version-$commit"
if ($DebugBuild) { $userVersion += "-debug" }

# Native tools write progress to stderr; that must not stop the script.
$ErrorActionPreference = "Continue"
if (-not $SkipExport) {
	$mode = if ($DebugBuild) { "--export-debug" } else { "--export-release" }
	Write-Host "Exporting Web ($mode) ..."
	if (-not $DryRun) {
		# Keep Godot from importing the exported files back into the project.
		if (-not (Test-Path export/.gdignore)) { New-Item -ItemType File -Force export/.gdignore | Out-Null }
		if (Test-Path export/web) { Remove-Item -Recurse -Force export/web }
		New-Item -ItemType Directory -Force export/web | Out-Null
		& $godot --headless $mode "Web" export/web/index.html | Out-Null
		if (-not (Test-Path export/web/index.html)) { throw "Export failed: export/web/index.html is missing." }
	}
}

Write-Host "Pushing export/web to ${Target}:$Channel as $userVersion"
if ($DryRun) {
	& $butler push export/web "${Target}:$Channel" --userversion $userVersion --dry-run
} else {
	& $butler push export/web "${Target}:$Channel" --userversion $userVersion
}
if ($LASTEXITCODE -ne 0) { throw "butler push failed ($LASTEXITCODE)." }
Write-Host "Done. On itch.io, the first push needs: Kind of project = HTML, tick 'This file will be played in the browser' for the html5 upload."
