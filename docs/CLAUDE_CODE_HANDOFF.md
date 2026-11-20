# Claude Code handoff — Four in a Rogue

**Owner:** Sean Bishop · **Repo:** https://github.com/chumbb/four-in-a-rogue · **Engine:** Godot 4.7 (only)

Read **`CLAUDE.md`** at repo root too (Claude Code loads it automatically). **Design docs live in Obsidian**, not in this repo.

---

## Session startup (Sean’s PC)

```powershell
cd $HOME\four-in-a-rogue
git checkout main
claude
```

**Before coding:**

1. **Obsidian** open → vault **`C:\Users\Sean\Documents\GameDev`**
2. **Local REST API** plugin enabled (for MCP)
3. First time only: approve **obsidian** MCP when Claude prompts
4. Project **`.mcp.json`** in repo root (gitignored) — already configured like Cursor

**Read design via MCP or files:**

- Canonical v0.1 rules: `Projects/Four-in-a-Rogue/Design/vertical-slice-v0.1.md`
- Full GDD: `Projects/Four-in-a-Rogue/Design/GDD.md`
- Decision log: `Projects/Four-in-a-Rogue/Decisions/Decision-Log.md`
- Latest session log: `Projects/Four-in-a-Rogue/Session-Logs/2026-11-19 Claude - Art pass A.md`
- Vault agent rules: `GameDev/CLAUDE.md`

**Conflict rule:** Obsidian vault wins over repo `CLAUDE.md` for game design.

---

## Current focus — M5 Goob effects

| Milestone | Status |
|-----------|--------|
| M1, M2, M3, M3.5, M3.6 | Done, merged to `main` |
| **M4 Decks & hands** | **Accepted by Sean and merged to `main` 2026-11-19** (`dbb9446`) |
| **Art pass A** | **Accepted by Sean and merged to `main` 2026-11-19** |
| **Hand stump** (follow-up) | Accepted and merged to `main` 2026-11-19: Forest oak stump under the hand (`art/hand/make_stump.py`; round top, flared base off the screen edges), board feet removed |
| **Writing session** | Accepted and merged 2026-11-19 |
| **M5 Goob effects** | **Built on `m5-goob-effects` (2026-11-19), awaiting Sean's F5 playtest** |
| M6–M7 | Queued — see `CLAUDE.md` §Milestones |

### M5 (2026-11-19, branch `m5-goob-effects`)

- Rules: `TurnLoop._resolve_effect()` (targets picked before any animation), `last_effect` for the view, `scoring_cells()` = every Goob in any winning line. Tests inject an all-Vanilla deck (`TurnLoop.start(..., deck)`, `scenario.deck`) so specials don't make turn tests random.
- View: `BoardView2D.play_flip/play_destroy/play_hop/play_draw_cue/play_fizzle/bounce_cell`; scenario `_play_effect()` and `_play_scoring()`.
- Sounds: `python art/audio/make_effect_sounds.py <packs_dir>` (packs = the unpacked Godot Asset Store kits listed in `assets/audio/CREDITS.md`).

### Art pass A (2026-11-19, branch `art-pass-a`)

- Palette: `art/palette/resurrect64.py` (OKLab nearest + lightness `Ramp`s, `.gpl` for Aseprite). Goob frames: `art/tests/rotation/make_goob_flips.py` quantises to blue/red ramps; copy `out_*` into `assets/goobs/vanilla/`. Board: `python art/board/make_board.py` (`board.aseprite` is now stale; the script is the source).
- Holes: both board layers transparent in the holes; the back layer only has a 1–2 px inner wall.
- Font: `UiTheme` (`scripts/ui/ui_theme.gd`) is installed by `GameFlow._ready`. Use `theme_type_variation` `Mono2` / `Mono3` / `Mono1Italic` on Labels (no variation = 1×); don't add raw `font_size` overrides. Size = round(16 × n × pixel_scale / ui_scale); checked crisp at 1080 wide (43 / 85 / 128).
- Background: start ComfyUI (`cd C:\Users\Sean\Documents\comfy\ComfyUI; python main.py`), then `python art/backgrounds/make_forest.py generate <seed>` and `... grade art/backgrounds/forest_raw_<seed>.png`. Chosen seed: 11.
- Playtest changes: landing sound = `column_tick.ogg` pitched down ~5 semitones (`art/audio/make_drop_sounds.py`; synthesised thunk/click versions were rejected); fall = synthesised whoosh; Forest grade has **no blur** (Sean).
- Screenshots on a landscape monitor: a temporary `override.cfg` (window mode 0, 540×960) gives a half-size 1080×1920 window; delete it after.

### M4 wrap-up (2026-11-19)

- Playtest changes: every column entry clicks (`column_tick`); inspect open = page turn, close = soft book close (Kenney RPG Audio, CC0); drag pickup = synthesised pop. Credits in `assets/audio/CREDITS.md`.
- Bug fix from a separate session: first-turn hand reveal landed off-screen (`24ca515`, `scripts/hand/hand_view.gd`).
- Claude's M4 choices stood (Sean accepted the build): tap-aimed column counts at timeout; cancelling a drag deselects; fuse strip left for M6.
- Where things live: `scripts/deck/` (Deck, StarterDeck), `scripts/rules/turn_loop.gd`, `scripts/hand/hand_view.gd`, `scripts/scenario/scenario_placeholder.gd` (input), `scripts/ui/inspect_panel.gd`, `scripts/audio/sfx.gd`.

### Tests (all pass on `m5-goob-effects`, 644 checks)

```powershell
$g = "C:/Users/Sean/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
& $g --headless --editor --quit            # refresh class cache / reimport (may segfault on quit; harmless)
& $g --headless -s res://tests/test_scenario.gd    # 331 checks
& $g --headless -s res://tests/test_turn_loop.gd   # 138
& $g --headless -s res://tests/test_board_state.gd # 74
& $g --headless -s res://tests/test_flow_m3.gd     # 15
& $g --headless -s res://tests/test_opponent_ai.gd # 86
```

Known: `test_git_sync` "temp repos cleaned up" fails on this machine — pre-existing.

### Gotchas

- GDScript warnings are errors: type anything that would infer as Variant (`var x: GoobDefinition = arr.back()`).
- Gameplay input is `InputEventScreenTouch` / `InputEventScreenDrag` only.
- Animated scenario tests must wait for the opening draw reveal before input unlocks (`_wait_input`).
- `.import` files are not tracked; replacing an asset keeps its path.
- Obsidian MCP can fail right after Obsidian starts; retry, or write the vault files on disk.

---

## Kickoff prompt (paste each session)

```text
You are coding Four in a Rogue (Godot 4.7) in this repo.

1. Read CLAUDE.md and docs/CLAUDE_CODE_HANDOFF.md.
2. Read v0.1 rules from Obsidian: Projects/Four-in-a-Rogue/Design/vertical-slice-v0.1.md, plus the latest session log and decision log.
3. Do the next item in CLAUDE.md §Milestones (currently the writing session) on a new branch; push it for Sean's playtest.
4. One milestone only; small commits, push each; match existing GDScript style.
5. Do not invent mechanics or add scope (no shop, runs, new Goobs).
6. When done: exact F5 playtest steps for Sean, then stop.

If a design rule is missing, ask Sean — do not guess.
```

---

## Tooling reference

| Tool | Role |
|------|------|
| **Claude Code** | Implementation in this repo |
| **Obsidian MCP** | Read/write design markdown in GameDev vault (never in git) |
| **Cursor** | Same repo + `four-in-a-rogue.code-workspace` |
| **Godot 4.7** | F5 from `project.godot` |

MCP setup notes: `docs/CLAUDE_CODE_MCP.md`

---

## Git

- Remote: `https://github.com/chumbb/four-in-a-rogue`
- Commit messages: `<milestone>: <short description>` (e.g. `Art A: ...`, `M5: ...`)
- Editor toolbar **Git: [branch] [Sync]** (addon `git_sync`) switches branch + pulls from inside Godot; it only fast-forwards, so push every commit
- Do not commit `.mcp.json` or secrets

---

*Last updated: 2026-11-19 (Art pass A accepted and merged; next the writing session)*
