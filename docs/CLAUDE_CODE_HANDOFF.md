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

Full plan, gap table and open questions: vault **`Projects/Four-in-a-Rogue/Design/Roadmap v0.1 - remaining art and code.md`**. `CLAUDE.md` §Milestones mirrors it (checklists + Strange Man brief). **Everything through M6c is accepted and merged (M6c on 2026-11-23). Next: M6d, then M7.** Key decisions: v0.1 art is *real but rough*; worried = 7th expression; title idle Goobs Vanilla only; vignette in Art B; Art E after v0.1; M7 required (Pixel 11; Pixel 8 if available); M6b-2 split if M6b overflows; D1 opens with a per-type interview; M6c opens with an AI grill.

| # | Session | Delivers | Needs |
|---|---------|----------|-------|
| 1 | **Art pass B** — UI kit ✅ | 9-slice pixel panels (HUD, dialogue box, buttons, toast, inspect, end banner, pause/options, scrim), Options widgets, pause + speaker icons, pixel logo, fuse strip art, vignette; approved as one mock set | — |
| 2 | **Art pass C** — Strange Man ✅ | Full body ~96×160 + light pool (stop for Sean's OK) per the brief in `CLAUDE.md`; two painted intro Goobs (red flat, face up); HUD bust portrait drawn separately × 7 expressions; crack/explode frames | — |
| 3 | **M6a** — Flow & screens ✅ | 0.3 s fades; title (logo, idle Goobs, Tap to start, Options); Strange Man 5-page intro with Skip + Goob pop-in; **coin flip rebuilt** (swipe up, 50/50, winner-colour flash + banner, draw replay over the forest) | B, C |
| 4 | **M6b** — HUD, pause, options, speed ✅ | Pixel HUD + Pause (replaces Quit) with scrim + Quit confirm; Options panel + persisted settings + audio buses; Normal/Fast (Skip removed in M6c); haptics; turn banners | B |
| 5 | **Art pass D1** — Goob type sheets ✅ | Face + rim emblem + 6 expression keyframes, blue/red, for all 5 types; Sean approves each | — |
| 6 | **Art pass D2** — Goob production ✅ | Expression loops, board/hand stills, flip frames per type; `SpriteFrames`; hand labels removed | D1 |
| 7 | **M6c** — AI, play anims, reactions ✅ | Hand-aware AI; flip from hand / up from behind the board; Goob expressions; portrait reactions; low-time fuse; win/lose lead-ins | C, D2 |
| 8 | **M6d** — Sound + smoke ← **next** | Remaining sounds, audio rules; A1–A10 smoke, known gaps (ambience built then removed) | all |
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
| **M6c** AI, play anims, reactions | ✅ Accepted and merged 2026-11-23 (18 playtest rounds) |

### M6d — sound completion + smoke test (on `m6d-sound-smoke`, not merged; next = sound effects grill)

- **Built:** Master mute on `NOTIFICATION_APPLICATION_PAUSED` (restored by `Settings.apply_audio()`), `[audio] general/ios/session_category=0` + `mix_with_others=true`. Credits rows for M6c + M6d added. **Removed by Sean (2026-11-23):** the forest ambience (chiptune soundtrack later) and a long-press inspect attempt (clashes with dragging; inspect stays double tap). **Playtest 2:** the opponent red column flash (+ blip) removed; a full column under the finger = dark highlight (`COLOR_FLASH_FULL`) + "Column full" toast, and only a release there gives the shake + error sound + haptic.
- **Open → next session: sound effects grill** (Sean, 2026-11-23: "update handoff for new sound effects convo"). State to start from:
  - **Removed, Sean disliked all of them:** forest ambience, opponent red-flash blip (the red flash itself is gone too), draw sting. Draws and the opponent's move now have no sound of their own.
  - **Press start** = option A, a soft triangle C5 → G5 blip (`make_flow_sounds.py` `press_start()`). Sean: "right".
  - **Every other UI press** = `ui_tap.ogg`: buttons, Skip, Resume/Options/Quit, pause open/close, Options rows + slider steps, Strange Man page advance. `Sfx.STREAMS` aliases `page`, `pause_open`, `pause_close` and `slider_tick` to it; UI sounds skip the ±5 % pitch jitter (`Sfx.NO_JITTER`); once-per-frame is per sample.
  - **Settled 2026-11-23 (later):** Sean asked for SNES-like (16-bit) UI sounds and picked the **wood block** (`ui_tap.ogg` dry, `press_start.ogg` with SNES echo), the **warm metal coin flick + table landing** (`coin_whirr.ogg` / `coin_clink.ogg`), all built by `make_flow_sounds.py` from `art/audio/make_snes_coin_fizzle_options.py`. **Fizzle:** "water putting out a candle" = A1 (`make_effect_sounds.py` `write_fizzle()`). Later rounds: UI tap a fifth lower (493 Hz) + 1.4 kHz low-pass; press start = `first_sting` + chorus/delay; coin = -6 dB high shelf at 5 kHz (a 3.8 kHz low-pass was "too washed out"); coin pitch keeps rising with toss strength (Sean). Open: SNES style for the other chiptune sounds? Scenario test count is 436 (437 was stale).
  - **(History) The UI tap was not settled before that.** History: the old square blip (harsh) → C sine bubble ("too bright and wobbly") → D felt tap, a ~180 Hz thump + muffled click (picked, now in the game) → "too much bass, use a high pass filter" → high-passed D at 250/350/500 Hz (Butterworth + 3 kHz top cut): **Sean didn't like those either.** Sean wants a **dull tap** that is not bright, not wobbly and not bassy. Show options and wait for his pick (never wire one in yourself).
  - **Listening files (local only, untracked):** `art/audio/compare_soft_ui/` holds `0_current_*` (the old harsh ones), A/B/C press start + tap, D/E/F dull taps, `D_hp250|350|500_ui_tap.ogg`. Generator for the high-pass set: `art/audio/make_highpass_tap_options.py` (untracked). Sean got annoyed when the comparison files were deleted, so keep them until Sean says otherwise.
  - **Checking what the game really plays:** `godot --headless -s res://tests/record_ui_tap.gd -- <out.wav> <sound>` records the Master bus to a WAV. Compare it with the file (ffmpeg + numpy). If Sean hears something different from a file, first check that he is on the branch and has reloaded the project (Godot import cache).
  - **Still to decide in the grill:** whether draws and the opponent's move get sounds, and anything else in the vault §2B Sound table Sean wants redone. Sound tooling: `art/audio/make_*_sounds.py` (numpy + scipy + ffmpeg at `C:\Users\Sean\Apps\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe`). Rerunning a script re-encodes every ogg it writes, so restore the files you didn't mean to change with `git checkout`. The headless editor (`--editor --quit`) rewrites `project.godot`: always `git checkout -- project.godot` afterwards.
  - **Also on this branch (playtest-confirmed or untouched by sound):** Master muted while backgrounded, the iOS ambient session, a full column = dark highlight + toast on hover with shake + error on release, no opponent red flash.
- **Smoke:** `docs/SMOKE_V0.1.md` (A1–A10 pass on desktop; known gaps). Soak: `godot --headless -s res://tests/soak_m6d.gd` (8 real-time games, ~6 min).
- **Gotcha:** a looping sound (fuse) still playing when a test quits can print "resources still in use at exit"; stop it and wait a moment before `quit()`.
- Test counts: scenario 437, flow 186, turn_loop 138, board_state 74, opponent_ai 77.

Original scope notes:

Scope (CLAUDE.md §M6d, vault slice §2B "Sound"):
- **Remaining sound events.** Compare the vault §2B Sound table with `scripts/audio/sfx.gd` (49 sounds wired).
- ~~Forest ambience loop~~ (removed by Sean 2026-11-23).
- **Audio rules.**
  - Fast = sounds sooner, normal pitch.
  - Pause = SFX stop, including the fuse loop (already pauses with the tree).
  - Each sound plays at most once per frame.
  - Opponent sounds about 10 % lower; ±5 % random pitch on repeats.
  - Skip no longer exists, so its "result sounds only" rule is gone.
- **Mobile audio.** Ambient audio category (respects the silent switch, the player's music keeps playing); pause in the background.
- **Smoke A1–A10** on desktop; document known gaps.
- **Sound tooling.** Synthesised sounds come from `art/audio/make_*_sounds.py` (numpy + ffmpeg; helpers in `make_effect_sounds.py`). CC0 packs are credited in `assets/audio/CREDITS.md`.
- **Gotcha:** rerunning a sound script re-encodes every ogg it writes. Restore the files you didn't mean to change with `git checkout`.

### M6c (accepted by Sean and merged to `main` 2026-11-23; 18 playtest rounds + one post-merge fix)

Full round-by-round history: vault session log `2026-11-22 Claude - M6c AI animations reactions.md` and the Decision-Log.

**What it ended up as:**
- **AI.** A fair teacher: always the strongest play, looks one move ahead, simulates effects over every outcome, ties go to Vanilla. Think delay 0.7 ± 0.2 s (+0.4 s on a block or close call), starting **after** the red "Opponent's turn" banner.
- **Play.**
  - While aiming, a **faint ghost** (`BoardView2D.GHOST_ALPHA` 0.45) flips in sideways from the hand over the column.
  - On commit, your Goob replaces the ghost, rests 0.2 s (`TOP_PAUSE_SEC`) and drops.
  - His Goob flips end over end up from behind the board (pitch frames; rise 0.22 s + settle 0.1 s), rests 0.2 s, then drops.
  - Vanilla flips vertically everywhere (`GoobDefinition.flips_vertically`, `flip_frames()`; `pitch_frames()` for every type).
- **Scoring** (snappier, about 4.4 s for a four):
  - Gold recognition hop.
  - Each Goob flips to its back (`BoardView2D.flip_cell()`) and shows its multiplier there.
  - The multiplier floats up into the **gap between the HUD and the board** (`gap_center()`).
  - The multipliers collapse into the total, which stays in the gap.
- **All text notifications are in that gap:** toasts ("Time's up!", "Column full", "Hand full"), turn banners, GAME START, and the drawn Goob's name.
- **Portrait faces** (`ScenarioHud.PORTRAITS`; art from `make_strange_man.py` `EXPRESSIONS`):

  | Face | When |
  |---|---|
  | idle | base |
  | greeting (tips his beanie) | GAME START |
  | thinking | his delay |
  | waiting (raised brow) | 8 s idle, or the fuse |
  | happy (old giggle A) | he makes a three / his effect hits you |
  | giggle (old happy) | he blocks your two |
  | well played | you block his two; your win |
  | sad | you block his three |
  | angry | your effect hits him; a chain hands you the win (`_defeat_face()`) |
  | surprised | a chain or a timeout roll |
  | celebrating | his win |

  After well played or angry, the bust cracks and explodes. Reactions (`react()`) play during the effect.
- **Goob faces:** giggle when selected / ghost / falling; worried while the fuse burns; surprised when flipped or knocked down; happy / sad / celebrating in the lead-in.
- **End screen** (`scripts/ui/end_screen.gd`):
  - Pixel window, 252 px wide, with a one-line 5× heading.
  - Buttons: **View board** / **Back to title** (Replay on a draw).
  - View board lets you review and inspect the board; **Show result** brings the window back.
- **Other:**
  - **Skip removed** (Normal / Fast; a saved Skip loads as Normal).
  - Pixel-bold button font.
  - Pause menu sits above the draw reveal.
  - No swipe arrow when the coin auto-flips.
- **Bugs fixed:** a timeout removed two cards from the fan (wrong Goob played later); Convincing's target showed the new colour before flipping.

**Code map:**
- **AI:** `OpponentAI.choose_move(board, hand, deck_count, rng)` → {column, hand_index, blocking, close}. `open_threes()` / `open_lines(board, side, n, touching)` drive the reactions; `TurnLoop.effect_outcomes()` shares the effect targets.
- **Reactions:** `_reaction_for()`, `_chained()`, `_defeat_face()`, `_lead_in()`.
- **Portrait:** `set_base_face()`, `react()`, `hold_face()`, `play_defeat(scale, face)`.
- **Faces:** `BoardView2D.set_face()` / `set_side_face()` / `face_at()`; token meta `face` / `busy` (spins set `busy`). Tests compare art with `shows_goob()` and `shows_back()`.
- **Play:** `show_preview(..., from_global)` + `_fly_preview()` (ghost); `play_drop(..., from_behind)` + `_rise_from_behind()`.
- **Fuse:** `FuseStrip`, placed in `_layout_table()`.
- **Screenshot tools** (windowed):
  - `tests/capture_m6c.gd -- <dir>`
  - `tests/capture_end.gd -- <dir>`
  - `tests/capture_scoring.gd -- <dir>`
- **Art builds:**
  - Portraits: `python art/strange_man/make_strange_man.py c_pro3`.
  - End headings: `python art/ui/make_ui_kit.py`.
  - Button font: `python art/fonts/make_monogram_bold.py`.
  - Sounds: `python art/audio/make_reaction_sounds.py`.

### M6b (accepted by Sean and merged to `main` 2026-11-21)

- `Settings` autoload (`scripts/core/settings.gd`): `speed` (Normal/Fast; Skip removed in M6c), `haptics`, `screen_shake`, `auto_flip`, `volume` / `muted` per bus; setters save `user://settings.cfg` and emit `changed`. `anim_sec()`, `anim_scale()`, `vibrate()`. Tests set `Settings.path = "user://test_settings.cfg"` then `reset()`, so they never touch the player's file.
- **Gotcha:** autoload names (`Settings`, `GameFlow`) are not compile-time identifiers when a `-s` test script compiles a class it names (e.g. `BoardView2D`). Keep autoload references out of class_name scripts that tests type against (the board gets `shake_enabled` from the scenario instead), and leave `PauseMenu` / `OptionsPanel` untyped in tests.
- `ScenarioHud` (`scripts/ui/scenario_hud.gd`): own `PixelStage`; `set_seconds()`, `set_timer("—")`, `show_turn_banner(player, sec)`, `bottom()` (the scenario sizes `%HudSlot` from it), `set_banner_band(top, bottom)` (banners centred between HUD and board). Playtest 1: emblem inside the block, no Objective heading, scenario "1", whoosh `turn_whoosh.ogg`.
- `PauseMenu` pauses the tree (it and its `OptionsPanel` are `PROCESS_MODE_ALWAYS`); scenario timers, tweens and sounds pause with it.
- Speed: `BoardView2D.speed_scale` / `HandView.speed_scale` (Fast = 2) on play tweens via `_tween()`; `animate = false` is now only the tests' path (Skip removed in M6c).
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

### Tests (all pass on `main`, 908 checks, 2026-11-23)

```powershell
$g = "C:/Users/Sean/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
& $g --headless --editor --quit            # refresh class cache / reimport (may segfault on quit; harmless)
& $g --headless -s res://tests/test_scenario.gd    # 435 checks
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
- **Running `--headless --editor --quit` rewrites `project.godot`.** It drops the lines that restate defaults and reorders keys. Run `git checkout -- project.godot` afterwards, and stage files by name, never with `git add -u`. In M6c a rewrite was committed by mistake and then restored.
- **Autoload names in `-s` test scripts:** don't name `Settings` or `GameFlow` or the classes that use them (e.g. `OptionsPanel`) as types in tests. Use `_settings()` / `load()` at runtime.
- **Art versions are Sean's pick:** show the comparison sheet and wait. Never wire in, commit or push your own choice.
- **Fixes after a merge** go on a short branch (e.g. `m6c-chain-loss-angry`) for Sean to check, then get merged.

---

## Kickoff prompt (paste each session)

```text
You are coding Four in a Rogue (Godot 4.7) in this repo.

1. Read CLAUDE.md and docs/CLAUDE_CODE_HANDOFF.md.
2. Read v0.1 rules from Obsidian: Projects/Four-in-a-Rogue/Design/vertical-slice-v0.1.md, plus the latest session log and decision log.
3. Do the next item in CLAUDE.md §Milestones (currently **M6d**: remaining sounds, audio rules, A1–A10 smoke) on a new branch; push it for Sean's playtest.
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

*Last updated: 2026-11-23 (M6c accepted and merged, plus the chain-loss fix; next = M6d)*
