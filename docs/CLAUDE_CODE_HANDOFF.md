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
- Latest session log: `Projects/Four-in-a-Rogue/Session-Logs/2026-11-22 Claude - M6c AI animations reactions.md`
- Vault agent rules: `GameDev/CLAUDE.md`

**Conflict rule:** Obsidian vault wins over repo `CLAUDE.md` for game design.

---

## Remaining plan to v0.1 (APPROVED by Sean, 2026-11-20 grill)

Full plan, gap table and open questions: vault **`Projects/Four-in-a-Rogue/Design/Roadmap v0.1 - remaining art and code.md`**. `CLAUDE.md` §Milestones mirrors it (checklists + Strange Man brief). **Art pass B, Art pass C and M6a accepted and merged (2026-11-20). M6b built on `m6b-hud-pause-options`, playtest pending.** Key decisions: v0.1 art is *real but rough*; worried = 7th expression; title idle Goobs Vanilla only; vignette in Art B; Art E after v0.1; M7 required (Pixel 11; Pixel 8 if available); M6b-2 split if M6b overflows; D1 opens with a per-type interview; M6c opens with an AI grill.

| # | Session | Delivers | Needs |
|---|---------|----------|-------|
| 1 | **Art pass B** — UI kit ✅ | 9-slice pixel panels (HUD, dialogue box, buttons, toast, inspect, end banner, pause/options, scrim), Options widgets, pause + speaker icons, pixel logo, fuse strip art, vignette; approved as one mock set | — |
| 2 | **Art pass C** — Strange Man ✅ | Full body ~96×160 + light pool (stop for Sean's OK) per the brief in `CLAUDE.md`; two painted intro Goobs (red flat, face up); HUD bust portrait drawn separately × 7 expressions; crack/explode frames | — |
| 3 | **M6a** — Flow & screens ✅ | 0.3 s fades; title (logo, idle Goobs, Tap to start, Options); Strange Man 5-page intro with Skip + Goob pop-in; **coin flip rebuilt** (swipe up, 50/50, winner-colour flash + banner, draw replay over the forest) | B, C |
| 4 | **M6b** — HUD, pause, options, speed ← **built, playtest pending** | Pixel HUD + Pause (replaces Quit) with scrim + Quit confirm; Options panel + persisted settings + audio buses; Normal/Fast/Skip everywhere; haptics; turn banners | B |
| 5 | **Art pass D1** — Goob type sheets | Face + rim emblem + 6 expression keyframes, blue/red, for all 5 types; Sean approves each | — |
| 6 | **Art pass D2** — Goob production | Expression loops, board/hand stills, flip frames per type; `SpriteFrames`; hand labels removed | D1 |
| 7 | **M6c** — AI, play anims, reactions | Hand-aware AI; flip from hand / up from behind the board; Goob expressions; portrait reactions; low-time fuse; win/lose lead-ins | C, D2 |
| 8 | **M6d** — Sound + smoke | Remaining sounds + ambience, audio rules; A1–A10 smoke, known gaps | all |
| 9 | **M7** (required) | Android build on Pixel 11 (both renderers), Pixel 8 if available | all |

After v0.1: **Art pass E** (per-type pixel impact VFX replacing the M5 placeholders).

### Status so far

| Milestone | Status |
|-----------|--------|
| M1, M2, M3, M3.5, M3.6 | Done, merged to `main` |
| **M4 Decks & hands** | Accepted and merged 2026-11-19 (`dbb9446`) |
| **Art pass A** (+ Forest hand stump) | Accepted and merged 2026-11-19 |
| **Writing session** | Accepted and merged 2026-11-19 |
| **M5 Goob effects** | Accepted and merged 2026-11-20 |
| **Art pass B** UI kit | Accepted and merged 2026-11-20 |
| **Art pass C** Strange Man | Accepted and merged 2026-11-20 |
| **M6a** Flow & screens | ✅ Accepted and merged 2026-11-20 |
| **M6b** HUD, pause, options, speed | Accepted and merged 2026-11-21 |
| **Art D1 / D2** Goob types | Accepted and merged 2026-11-21 |
| **Specials design grill** | Confirmed 2026-11-22 (vault `Design/Special Goobs.md`) |
| **M6c** AI, play anims, reactions | Built on `m6c-ai-animations-reactions`; playtest rounds 1–8 done, **in playtest** |

### M6c (built 2026-11-22, branch `m6c-ai-animations-reactions`, in playtest)

**Where we are (handoff 2026-11-22, after playtest 8):**

- **Blocked two (done, Sean "for now"):** when either side blocks the other's two (a side-by-side pair, `OpponentAI.open_lines(board, side, 2, true)`), the portrait shows the **well played** face as a normal 1.5 s reaction. This replaced the nod (`4d205bd`, removed).
- **Playtest 10 (Sean, done):** AI strength is fun (retest once all effects exist); win sequence OK; **Vanilla flips vertically** (`GoobDefinition.flips_vertically` + `flip_frames()`, pitch frames); **scoring**: each Goob flips to its back (`BoardView2D.flip_cell()`), its multiplier shows there then floats up into the gap, total in the gap (`gap_center()`); **all toasts in the gap** (`_place_toast()`). End buttons per Sean: "View board" / "Back to title". Screenshots: `tests/capture_scoring.gd -- <dir>`.
- **Playtest 11 (Sean), built:** Fast + Skip work. (1) **Remove Skip** from the game (Options shows Normal / Fast; a saved Skip loads as Normal). (2) **Aim ghost:** while aiming with a Goob selected, a *faint* copy floats over the column, arriving with a **horizontal** (yaw) flip; when the column is chosen the faint copy disappears and the real Goob **flips into place vertically** (pitch) on top of the board, then drops. All types. (3) **Think delay starts after** the red opponent banner (`_run_opponent_turn` awaits the banner). Code: `BoardView2D.GHOST_ALPHA`, `_flip_in()`, `play_drop(..., flip_in)`, `GoobDefinition.pitch_frames()`; the opponent's rise from behind also uses pitch frames. Next: Sean playtests the ghost + flips; then merge.
- **Playtest 12 (Sean):** think timing and Options OK. Rest after a flip into place shortened (`BoardView2D.FLIPPED_PAUSE_SEC` 0.06, was the 0.2 `TOP_PAUSE_SEC`; plain drops keep 0.2). Auto-flip coin: no swipe arrow.
- **Playtest 13 (Sean):** the player's Goob **drops from the ghost** (no flip-in; `_flip_in` removed); the opponent's still **flips into place** from behind the board (pitch frames). Rest before the drop = `BoardView2D.PLAY_PAUSE_SEC` 0.1 s for both (plain drops keep `TOP_PAUSE_SEC` 0.2).
- **Playtest 14 (Sean):** player's Goob rests the usual 0.2 s (`TOP_PAUSE_SEC`) after replacing the ghost; opponent's flip into place + rest = 0.2 s (`OPPONENT_PLAY_SEC`: rise 0.12 + settle 0.05 + rest 0.03). `PLAY_PAUSE_SEC` removed.
- **Playtest 15 (Sean):** player drop at 0.2 s accepted. Opponent: back to the full flip up from behind (rise 0.22 + settle 0.1), **then** the 0.2 s rest (`TOP_PAUSE_SEC` for every played Goob; `OPPONENT_PLAY_SEC` removed).
- **Playtest 16 (Sean): snappier scoring.** Recognition 1.0 → 0.7 s; per Goob ~0.85 → ~0.55 s (flip frames 0.06 → 0.04 `SCORE_FLIP_FRAME_SEC`, show 0.25 → 0.15, float 0.3 → 0.2, step 0.6 → 0.4); pause 0.4 → 0.25; collapse 0.3 → 0.25; total hold 1.0 unchanged. A four now scores in ~4.4 s instead of ~6 (incl. the 1 s hold on the total).
- **Playtest 17 (Sean):** scoring timing accepted. Bug fixed: Convincing's target showed the new colour during the wind-up (`play_flip` set `_token_owner` at the start, so the face player repainted it). The owner now changes when the spin starts; the colour turns edge-on mid-spin. Test `_test_convincing_flip_colour`.
- **Sean confirmed fixed:** wrong Goob played after a timeout (double `_hand.remove()`, `53e484f`).
- **Playtest changes so far:**
  - Drawn Goob's name shows above the board.
  - End overlay: View board (review and inspect), then Show result.
  - Hand Goobs react to the win or loss.
  - GAME START banner with its own sound.
  - Pixel end screen with a one-line 5× heading, window 252 px wide.
  - Pause menu sits above the draw reveal.
  - Button text uses pixel-bold Monogram.
  - Portrait reactions play during the effect.
  - Waiting face (b2, 8 s idle or the fuse).
  - Greeting: he tips his beanie (`portrait_greeting`, option c) during GAME START.
  - Blocked-two reaction (see above).
- **Still for Sean to confirm before merging:**
  - Play flips.
  - The ghost + drop, and the opponent's flip-in (playtest 13).
- **On acceptance:** merge into `main`, push, mark M6c accepted in CLAUDE.md, this file and the vault, then stop. M6d is next.

**Code map:**

- AI: `OpponentAI.choose_move(board, hand, deck_count, rng)` → {column, hand_index, blocking, close}; scores every (hand Goob, column) over `TurnLoop.effect_outcomes()` (static, same targets as `_resolve_effect`). `open_threes()` drives the happy/angry portrait. `choose_column()` kept for a plain hand.
- Think delay: `OPPONENT_DELAY_SEC` 0.7 ± 0.2 (+0.4 blocking/close), own `_think_rng`; `opponent_delay_sec = 0` still means none (tests).
- Faces: `BoardView2D` plays expression loops on every token (`set_face`, `set_side_face`, `face_at`; token meta `face` / `busy` — spins set `busy` so the face player leaves the texture alone). `GoobDefinition.face_frame()` reads the baked SpriteFrames durations. Tests compare art with `BoardView2D.shows_goob()` (textures are loop frames now). `HandView.set_worried()`, `face_of()`, `card_center()`.
- Portrait: `ScenarioHud.set_base_face()` (idle/thinking), `react()`, `hold_face()`, `play_defeat(scale)` (await; emits `portrait_sound`).
- Play flips: `show_preview(..., from_global)` flies the float up from the hand; `play_drop(..., from_behind)` raises the opponent's Goob inside the `BehindBoard` clip control.
- Fuse: `FuseStrip` placed in `_layout_table()`; `_refresh_fuse()` each frame; loop player on the SFX bus (pauses with the tree).
- Screenshots: `tests/capture_m6c.gd -- <dir>` and `tests/capture_end.gd -- <dir>` (end screens), windowed.
- Portrait art: `python art/strange_man/make_strange_man.py c_pro3` (EXPRESSIONS maps names to `bust/raw_*.png`). End headings: `python art/ui/make_ui_kit.py`. Button font: `art/fonts/make_monogram_bold.py`.

### M6b (built 2026-11-20, branch `m6b-hud-pause-options`, waiting for Sean's playtest)

- `Settings` autoload (`scripts/core/settings.gd`): `speed` (Normal/Fast/Skip), `haptics`, `screen_shake`, `auto_flip`, `volume` / `muted` per bus; setters save `user://settings.cfg` and emit `changed`. `anim_sec()`, `anim_scale()`, `is_skip()`, `vibrate()`. Tests set `Settings.path = "user://test_settings.cfg"` then `reset()`, so they never touch the player's file.
- **Gotcha:** autoload names (`Settings`, `GameFlow`) are not compile-time identifiers when a `-s` test script compiles a class it names (e.g. `BoardView2D`). Keep autoload references out of class_name scripts that tests type against (the board gets `shake_enabled` from the scenario instead), and leave `PauseMenu` / `OptionsPanel` untyped in tests.
- `ScenarioHud` (`scripts/ui/scenario_hud.gd`): own `PixelStage`; `set_seconds()`, `set_timer("—")`, `show_turn_banner(player, sec)`, `bottom()` (the scenario sizes `%HudSlot` from it), `set_banner_band(top, bottom)` (banners centred between HUD and board). Playtest 1: emblem inside the block, no Objective heading, scenario "1", whoosh `turn_whoosh.ogg`.
- `PauseMenu` pauses the tree (it and its `OptionsPanel` are `PROCESS_MODE_ALWAYS`); scenario timers, tweens and sounds pause with it.
- Speed: `BoardView2D.speed_scale` / `HandView.speed_scale` (Fast = 2) on play tweens via `_tween()`; Skip = `animate = false` (same path tests use), and the board then emits only impact sounds.
- **Gotcha:** set a Button's size after it gets the pixel theme. Built before entering the tree, it measures the default font and grows (the Options speed segments are re-sized in `_layout`).
- Dev screenshots: `tests/capture_m6b.gd -- <dir> [w h [insets]]` (windowed).
- Sounds: `python art/audio/make_menu_sounds.py`. Ribbons: `make_ui_kit.py` (`ribbon()`).

### M6a (accepted by Sean and merged to `main` 2026-11-20)

- `GameFlow.go_to(key, transition)`: `BLACK` (default), `FOREST` (cover = forest + vignette: the screen fades out leaving the forest; used for coin flip → scenario and draw replay), `CUT`. 0.3 s out + 0.3 s in; the old scene is `PROCESS_MODE_DISABLED` under the cover. `GameFlow.sfx` plays flow sounds so they survive the freeze. `GameFlow.fade_sec = 0` in tests. `GameFlow.auto_flip_coin` = M6b's Options row.
- `PixelStage` (`scripts/ui/pixel_stage.gd`): canvas Control scaled to the board's pixel scale, children in game px (mock coordinates 1:1), canvas theme = Monogram 16/32/48 + kit buttons. `safe` = safe area in game px; screens re-place in `relayout`. Text is crisp at 4× (checked).
- Title `scripts/app/title.gd`, Strange Man `scripts/app/strange_man.gd` (`PAGES`, `advance()`, `finish()`), coin flip `scripts/ui/coin_flip.gd` (`strength_for()`, `toss()`, `frame_at()`; pitch frames: half turn = A 0,1,2 → B 6,7 → B 0).
- Sounds: `python art/audio/make_flow_sounds.py` (no packs needed).
- Dev screenshot tools (not tests): `tests/capture_flow.gd -- <dir> <w> <h> [insets]`, `tests/capture_e2e.gd -- <dir>` (run windowed with `--path .`).
- Gotcha: use `set_anchors_and_offsets_preset` for full-rect nodes built in code; `set_anchors_preset` on a node already in the tree keeps its 0×0 size.
- Gotcha: `root.push_input(ev, true)` in tests when positions are in viewport (720-base) coordinates; the test window is 1080×1920.

### Art pass C (accepted and merged 2026-11-20)

Build: `python art/strange_man/make_strange_man.py c_pro3` writes `assets/strange_man/*`, `art/strange_man/mock_intro.png` (intro mock) and `art/strange_man/sheet_portraits.png` (review sheet). The whole history is in the vault session log `2026-11-20 Claude - Art pass C Strange Man.md` and the Decision-Log.

**Settled by Sean:**
- **Still:** Pro 3 (`raw_c_pro3.png`) with the Goob patch removed (copy op in `EDITS`) → `full_body.png` 96×160, plus `light_pool.png`.
- **Bust + 7 expressions** (64 px, PixelLab portrait + edits) → `portrait_<expr>.png`.
  - Well played = `bust/raw_well_played2.png`: serious, with a slight bow.
  - Happy stands in for Pro 2's warm smile.
- **Crack + explode frames:** procedural. `portrait_explode.png` is 6 frames of 128×128.
- **Blue intro Goob:** `goobs/raw_blue_edit.png`, upright with its rim showing. No complaints so far.

Sean hasn't yet given an explicit OK on the bust, the expressions or the crack/explode frames. Ask him to review them before merging.

- **Red intro Goob (settled 2026-11-20): flat B.** `goobs/raw_red_flat_b.png` from `goobs/make_red_flat.py`.
  - The Goob lies flat on the ground, face up.
  - The top face is an exact ellipse (a perfect circle lying down, symmetric), with the rim underneath.
  - The face is the blue's own pixels turned sideways, blush included.
  - Ramp e83b3b / ae2334 / 6e2727 / f57d4a, outline 2e222f.
  - Wired via `RED_SRC` in `make_strange_man.py`.
  - Rejected along the way: PixelLab tries, the squash/tip hack, and the blue rotated 90° (no flat edges and no "on the ground" look). Sean: it must lie **flat on the ground** and be **perfectly circular**.

Sean approved the bust, the 7 expressions and the crack/explode frames (2026-11-20, "portraits are good").

**M6b:** the HUD now shows the 64 px bust at 1:1 (block 76 px; Sean 2026-11-20).

### M5 (accepted and merged 2026-11-20)

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

### Tests (all pass on `m6c-ai-animations-reactions`, 904 checks)

```powershell
$g = "C:/Users/Sean/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
& $g --headless --editor --quit            # refresh class cache / reimport (may segfault on quit; harmless)
& $g --headless -s res://tests/test_scenario.gd    # 431 checks
& $g --headless -s res://tests/test_turn_loop.gd   # 138
& $g --headless -s res://tests/test_board_state.gd # 74
& $g --headless -s res://tests/test_flow_m3.gd     # 184
& $g --headless -s res://tests/test_opponent_ai.gd # 77
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
3. Do the next item in CLAUDE.md §Milestones (currently the M6c playtest on `m6c-ai-animations-reactions`, see the M6c section here; then M6d) on a new branch; push it for Sean's playtest.
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
