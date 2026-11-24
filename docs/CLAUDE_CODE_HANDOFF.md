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
- Latest session log: `Projects/Four-in-a-Rogue/Session-Logs/2026-11-23 Claude - M6e Destroy category.md`
- Special Goobs spec (M6e roster, categories, deck rule): `Projects/Four-in-a-Rogue/Design/Special Goobs.md` → "2026-11-23 update"
- Vault agent rules: `GameDev/CLAUDE.md`

**Conflict rule:** Obsidian vault wins over repo `CLAUDE.md` for game design.

---

## Remaining plan to v0.1 (APPROVED by Sean, 2026-11-20 grill)

Full plan, gap table and open questions: vault **`Projects/Four-in-a-Rogue/Design/Roadmap v0.1 - remaining art and code.md`**. `CLAUDE.md` §Milestones mirrors it (checklists + Strange Man brief). **Everything through M6d is accepted and merged (M6d on 2026-11-23). Sean then added M6e (special Goobs) before M7; the M6e framework is accepted and merged (2026-11-23). M6e Move and M6e Destroy accepted and merged (2026-11-23). Next: M6e Discard category, then draw → tech → uniquely powerful → Art F → Art G → M7.** Key decisions: v0.1 art is *real but rough*; worried = 7th expression; title idle Goobs Vanilla only; vignette in Art B; Art E after v0.1; M7 required (Pixel 11; Pixel 8 if available); M6b-2 split if M6b overflows; D1 opens with a per-type interview; M6c opens with an AI grill.

| # | Session | Delivers | Needs |
|---|---------|----------|-------|
| 1 | **Art pass B** — UI kit ✅ | 9-slice pixel panels (HUD, dialogue box, buttons, toast, inspect, end banner, pause/options, scrim), Options widgets, pause + speaker icons, pixel logo, fuse strip art, vignette; approved as one mock set | — |
| 2 | **Art pass C** — Strange Man ✅ | Full body ~96×160 + light pool (stop for Sean's OK) per the brief in `CLAUDE.md`; two painted intro Goobs (red flat, face up); HUD bust portrait drawn separately × 7 expressions; crack/explode frames | — |
| 3 | **M6a** — Flow & screens ✅ | 0.3 s fades; title (logo, idle Goobs, Tap to start, Options); Strange Man 5-page intro with Skip + Goob pop-in; **coin flip rebuilt** (swipe up, 50/50, winner-colour flash + banner, draw replay over the forest) | B, C |
| 4 | **M6b** — HUD, pause, options, speed ✅ | Pixel HUD + Pause (replaces Quit) with scrim + Quit confirm; Options panel + persisted settings + audio buses; Normal/Fast (Skip removed in M6c); haptics; turn banners | B |
| 5 | **Art pass D1** — Goob type sheets ✅ | Face + rim emblem + 6 expression keyframes, blue/red, for all 5 types; Sean approves each | — |
| 6 | **Art pass D2** — Goob production ✅ | Expression loops, board/hand stills, flip frames per type; `SpriteFrames`; hand labels removed | D1 |
| 7 | **M6c** — AI, play anims, reactions ✅ | Hand-aware AI; flip from hand / up from behind the board; Goob expressions; portrait reactions; low-time fuse; win/lose lead-ins | C, D2 |
| 8 | **M6d** — Sound + smoke ✅ | Remaining sounds, audio rules; A1–A10 smoke, known gaps (ambience built then removed) | all |
| 9 | **M6e** special Goobs (Sean 2026-11-23) ← **in progress** | Framework ✅ → Move ✅ → Destroy ✅ → Discard ← **next** → Draw → Tech → Uniquely powerful | all |
| 10 | **Art F / Art G** | Special Goob faces; effect icons (starts with a grill) | M6e |
| 11 | **M7** (required) | Android build on Pixel 11 (both renderers), Pixel 8 if available | all |

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
| **M6d** Sound + smoke | ✅ Accepted and merged 2026-11-23 (sound grill done) |
| **M6e framework** | ✅ Accepted and merged 2026-11-23 |
| **M6e Move** | ✅ Accepted and merged 2026-11-23 |
| **M6e Destroy** | ✅ Accepted and merged 2026-11-23 |

### M6e Discard category ← **next** (fresh session; Sean 2026-11-23)

- **Branch:** **`m6e-discard`** from `main`.
- **Step 1, before any code:** propose rules, names ("<Adjective> Goob") and one-line card text for each discard Goob, with edge cases and fizzles; Sean approves; log to the Decision-Log and the spec (a new "M6e Discard rules" section). **Build nothing before that.**
- **Roster** (vault `Design/Special Goobs.md` "2026-11-23 update" + `resources/goobs/special goobs.txt`): Distracting (your opponent discards a Goob), Defiant (when discarded, it is played instead), discard a Goob then draw a Goob, discard 2 Goobs then destroy an opponent Goob, discard your hand then draw 2 extra Goobs next turn, bring back a discarded Goob to your side, discard a Goob then destroy a random Goob.
- **Questions for Sean** (examples): random or chosen discards (framework: random only); fewer Goobs in hand than the cost (fizzle, or do what it can?); where Defiant is played (random column?) and whether its effect fires; whether "bring back a discarded Goob" goes to the hand or the board; whether the destroy Goobs reuse the Destroy rules (`_destroy_target`, Spiteful landings).
- **What exists:** `TurnLoop.discard_from(side, index)` + discard steps; the scenario's `_show_discard` (one at a time, never sped up); empty-hand skip rules (`skip_turn`, `_skipped_last`); `Deck.discard_pile`; the destroy path `_destroy_target` / `_can_destroy`; turn-start hooks + `turn_start_steps` (the "draw 2 extra next turn" can use `_turn_draw_count`); **every "bring back" effect plays the `resurrect` sound** (Sean, 2026-11-23); `play_summon(…, goob, sound)`.
- **Tests:** unit tests in `tests/test_turn_loop.gd`, scenario checks like `_test_destroy_animations`, a fuzz like `tests/fuzz_m6e_destroy.gd`.

### M6e Destroy category (accepted and merged 2026-11-23)

- **Rules approved by Sean:** vault spec `Design/Special Goobs.md` → "M6e Destroy rules", Decision-Log 2026-11-23. Volatile (any Goob, itself included), Spiteful ("Destroy the next Goob that lands on this Goob": any landing, either side, once; the lander's effect still fires, then it is destroyed), Occult (a random Goob from your destroyed pile drops for you; its effect fires), Crushing (below), Brawling (one random side), Smouldering (at the start of the next turn of the player who played it, a random adjacent Goob around where it is then).
- **Engine (`TurnLoop`):**
  - Per-Goob state is metadata on a **copy-on-write copy** of the cell's definition (`_mark`, `base_of`): `armed_by` for Spiteful / Smouldering, `doomed` for a Spiteful's lander. It moves with the Goob, and `play_results` simulations never touch the real board. Piles always get the plain definition.
  - `_check_landing` runs at every landing: drop, Popular, roll (also sliding across the top), bounce, gravity (not riding down), and the Goob that drops into a destroyed cell.
  - `_play_goob` = land and resolve → `_destroy_doomed` → `_sync_board_statuses` (pills).
  - `_destroy_target` is the one destroy path (Fat too), with the `_can_destroy` hook for tech; steps carry `fell`.
  - `turn_start_steps`: `_on_turn_start` runs `_smoulder`; the scenario's `_play_turn_start` shows them after the banner (before your draw / his think delay); `_land_then_continue` skips its sync while they're pending.
- **AI:** `_drop_moves` also simulates drops onto an armed Spiteful. **View:** `play_destroy` handles source == target; `play_summon(…, goob)` for Occult's art.
- **Tests:** `tests/test_turn_loop.gd` (10 destroy tests), `tests/test_scenario.gd` `_test_destroy_animations`, fuzz `godot --headless -s res://tests/fuzz_m6e_destroy.gd`.
- **Claude's calls to confirm in the playtest:** a Spiteful lander that its own effect removed just spends the curse; Smouldering fires before the turn draw and its destroy is win-checked at the end of that turn; Occult reuses Popular's summon animation, with its own resurrect sound (Sean picked A, 2026-11-23).
- Playtest OK (Sean, 2026-11-23) → merged. Code review fixes and the new `resurrect` sound (Sean picked A) are in.

### M6e Move category (accepted and merged 2026-11-23)

- **Rules approved by Sean** (2 rounds): vault spec `Design/Special Goobs.md` → "M6e Move rules", Decision-Log 2026-11-23.
- **Engine** (`TurnLoop`): `_roll` (roll rule + Springy hop + Bouncy bounce; a bounce ends a roll), `_hop` (onto a column top, or the timeout-style roll from the top of a full one), `_apply_gravity` (one group), `_settle` (gravity, then fallen Lopsided/Tipsy roll, repeat). Motions go into the step's `"motions"` (format in the code comment above `_move_step`). `_land_and_resolve` = land → Bouncy/Slippery (an `"instant"` step) → the Goob's own effect. `_pick` replaces direct rng calls so `play_outcomes` can enumerate every random pick for the AI. `roll_goob` now runs on the same engine.
- **View:** `BoardView2D.play_move(source, motions, marked, wind_up)` / `play_motions`; scenario `_play_effect` skips `"passive"` steps (Bouncy/Slippery/Springy played) and plays `"instant"` ones without the lead wait; `roll_dir(path)` passes the timeout roll direction to `TurnLoop.play`.
- **Claude's calls to confirm in the playtest:** Bouncy → Bouncy keeps its direction; Bouncy with no column that way bounces back; sliding across a Bouncy's top counts as landing; Slippery boxed in just stays; Blustery fizzles if nothing in the highest row can move.
- **Test in F5:** F4 → category deck main = Move + another → "New game with these", or give yourself each Goob; » auto-play to watch the AI. Fuzz: `godot --headless -s res://tests/fuzz_m6e_move.gd` (~3 min).
- **Playtest 1 (Sean, 2026-11-23):**
  - "Give doesn't work, no move Goobs drawn" was not a bug. The move Goobs were in the deck but look exactly like plain Goobs (Vanilla art).
  - Testing aid (`0ce50a2`): every special still on Vanilla art shows its name (minus " Goob") in Monogram under it in the hand. This is `HandView._make_card` / `_place_name`, and Art F removes it.
    - The label needs an explicit font override, because the root theme doesn't reach Controls under the Node2D card.
  - Bounce arc (`81a55bb`): a bouncing Goob rises to the cell **above its landing cell**, then gravity-falls in (the `&"hop"` branch of `BoardView2D._queue_motion`).
    - Landing in the top row, or rolling along the top, uses the top of the board.
    - Claude's reading of Sean's "as high as the space above where it will land". If he meant always the top of the board, it is a one-line change.
- **Code review fixes (`b4041c8`):**
  - Chains run one Goob at a time with gravity between: `_settle(pending)` → `_chain_one`.
  - Every landing on a Bouncy/Slippery counts (Sean), done through `_landing_step` / `_landing_move`:
    - Popular's extra Goob, and falls after a destroy or push.
    - Riding one down doesn't count.
  - A chain that repeats a board position stops (`_position_key`), and gravity always ends it.
  - The AI uses `TurnLoop.play_results` (`{board, goobs, weight}`, weighted by real odds). `OpponentAI.winning_drops(board, side, goobs)` simulates drops onto a Bouncy/Slippery.
  - Effect steps carry `target_owner`, which the portrait reaction uses.
  - `play_motions` waits for every tween in a batch.
  - About 40 ms per AI move in the fuzz run; check in M7.
  - Open: Slippery's card text could become "Goobs that land on this Goob roll." (waiting for Sean).
- Then playtest → merged; the Destroy session followed (done).

#### Original plan (for reference)

- **Branch:** `m6e-move` from `main`.
- **Step 1, before any code:** propose rules for each move Goob to Sean and get his approval: name ("<Adjective> Goob"), one-line card text, edge cases, AI value. Use the vault spec `Design/Special Goobs.md` ("2026-11-23 update" wins over the older per-Goob rules below it). Don't invent mechanics; ask. Log his answers in the Decision-Log and the spec.
- **Roster (Sean's list, `resources/goobs/special goobs.txt`):**
  - **Sinister:** push left (causes rolling).
  - **Dexterous:** push right (causes rolling).
  - **Lopsided / Tipsy:** "rolls after falling", both when played and when a destroy makes its column fall.
  - **Bouncy:** Goobs played here jump up to a higher adjacent column and do not roll.
  - "Goobs played here roll".
  - "The highest Goob rolls".
  - "Bounces rolling Goobs".
  - "Roll a Goob in this row".
- **Sean's rules so far:**
  - A **push pushes a row**. The row rolls, and the Goobs above fall into any empty space below them.
  - **Roll:** sideways while the cell beside it is free; a column level with it or higher, or the edge, stops it. A floor Goob rolls all the way to the side.
  - Rolling **never** takes a Goob off the board (only uniquely powerful Goobs do that).
  - Bouncing no longer always means rolling.
  - All specials are ×2, Vanilla art for now.
- **Open questions to put to Sean** (examples):
  - Which Goobs a push moves: the whole row, or only its side?
  - Does the pusher move?
  - Where does Bouncy's jump land?
  - Which Goob and which direction "roll a Goob in this row" picks (random per the spec)?
  - Directions for "played here roll" and "highest Goob rolls".
  - Whether Steadfast/Stalwart-style "can't be moved" matters yet (tech comes later).
- **Build:**
  - Effect types plus `.tres` per Goob (`category = MOVE`, multiplier 2.0, `art_id = "vanilla"`), each added to `GoobRoster.PATHS`.
  - The effect in `TurnLoop._resolve_effect`, using `roll_goob`, appending `effect_steps`.
  - `effect_outcomes` for the AI.
  - A roll/push animation in `BoardView2D` (reuse the timeout roll `_queue_roll` style).
  - The scenario's `_play_effect_impact`.
  - Unit tests per Goob.
- **Test in F5:** F4 → category deck main = Move + another → "New game with these", or give yourself each Goob; » auto-play to watch the AI use them.
- Then playtest → merged (done).

### M6e framework (accepted and merged 2026-11-23)

APIs the category sessions use:

- **Goob data:** `GoobDefinition.Category` (NONE, UNIQUE, TECH, MOVE, DESTROY, DISCARD, DRAW) and `category`. `GoobRoster.PATHS` (`scripts/deck/goob_roster.gd`): add each new Goob's `.tres` path here.
- **Decks:** `DeckBuilder.roll(rng, forced)` / `roll_from(rng, roster, forced)` builds 11 Goobs + 10 specials (`SIZE` 21, `SPECIALS` 10); `forced` is a category dictionary (debug deck). `GameFlow.rolled_decks` (kept over draw replays, cleared for a new game), `GameFlow.debug_forced_categories`, `GameFlow.autoplay`.
- **Piles:** `Deck.discard_pile`, `Deck.destroyed_pile`, `Deck.discard(index)`.
- **TurnLoop** (`scripts/rules/turn_loop.gd`):
  - `destroy_at(cell)` and `_collapse_goobs(column, from_row)`.
  - `discard_from(side, index)` appends a discard step (`"kind"` NONE, `"discarded"`, `"index"`, `"side"`).
  - `effect_steps` holds every step of a resolution; `last_effect = effect_steps[0]`.
  - `statuses` with `add_status(id, side, label, text, turns_left)`, `remove_status(id, side)`, `has_status(id, side)`; hooks `_on_turn_start(side)` / `_on_turn_end(side)`.
  - Status semantics: `turns_left` ticks at every turn start of **either** side inside `play()`, so a status added during an effect with `turns_left` 1 is gone before anyone sees it, and "for N of his turns" ≈ `2N`; steps appended from `_on_turn_start` during `start()` are not shown.
  - `roll_goob(cell, dir)`: a Goob moves sideways while the cell beside it in the next column is free, falling to the top of that column; a column level with it or higher, or the edge, stops it, so on the floor or a flat top it rolls on to the next Goob or the edge (Sean, 2026-11-23); never off the board. Logic only, no animation yet.
  - Empty hand: `skip_turn()` (hand ran out mid-turn), `_turn_draw_count(side)` (draw effects override it), `last_skipped` (sides skipped in the latest turn change; the scenario toasts "Turn skipped" / "Opponent's turn skipped"). An empty hand after the turn draw skips the turn. Skips are never a draw; turn order goes on, and a side skipped last turn always gets its next turn draw (`was_skipped_last(side)`, so never two skips in a row).
- **View:** `StatusPills` (`scripts/ui/status_pills.gd`) sits in the gap strip above the aim lane and never over a column hit rect. Scenario `_show_discard(goob, side, index)` (centre pop, name, off screen; never sped up by Fast).
- **Debug (debug builds only):** F4 `DebugPanel` (`scripts/debug/debug_panel.gd`): give a Goob, discard random, add status, category deck + "New game with these". Scenario helpers `debug_give`, `debug_discard_random`, `debug_add_status`.
- **Auto-play:** "»" button right of Pause; Settings row "Auto-play button" (`Settings.autoplay_button`, default On). Off at win/lose and on quit to title.

### M7 — on-device check (required for v0.1; after M6e + Art F/G; CLAUDE.md §M7)

- **Goal:** an Android debug build on the **Pixel 11**, first with the Mobile renderer, then with Compatibility. Use the **Pixel 8** as the older phone if Sean has one. Check **A9** (portrait touch) on hardware, plus the rest of `docs/SMOKE_V0.1.md`. A true low-end check is a known gap. iOS waits for a Mac; the Retroid Pocket (4:3) is saved for the landscape version.
- **Starting state on this PC (checked 2026-11-23):**
  - no `export_presets.cfg` in the repo
  - `%APPDATA%\Godot\export_templates` is empty
  - no JDK, Android SDK or `adb` on PATH
  - so the session starts with setup:
    - Godot 4.7.2 export templates
    - JDK 17
    - Android SDK (command-line tools, platform-tools, build-tools)
    - set the paths in Editor Settings → Export → Android
    - the debug keystore
    - an Android export preset
  - Sean has to do the installs and the USB debugging on the phone himself. Give him exact steps and `!` commands.
- **Things to check on the phone** (desktop smoke already passes):
  - safe area on a real notch / home strip
  - touch: single pointer, 96 px targets, drag vs double-tap inspect
  - haptics (`Input.vibrate_handheld`; needs the VIBRATE permission in the preset)
  - Master muted while backgrounded; ambient audio / silent switch behaviour
  - steady 60 fps
  - the whole-number pixel scale at the phone's width
  - both renderers (the shader baker at export)
- **Don't change rules or art in M7.** Fixes from the device go on short branches for Sean to check.
- The M7 Android build is a debug export, so the » auto-play button and F4 panel exist on the phone; turn Options → Auto-play button off for the A9 check.

### M6d — sound completion + smoke test (accepted and merged to `main` 2026-11-23)

- **Built:**
  - Master is muted on `NOTIFICATION_APPLICATION_PAUSED` and restored by `Settings.apply_audio()`.
  - iOS ambient session: `[audio] general/ios/session_category=0` + `mix_with_others=true`.
  - Full column: a dark highlight + "Column full" toast while hovering; shake + error sound + haptic only on release.
  - The opponent's red column flash is removed.
  - Credits are updated.
- **Removed by Sean:** the forest ambience, a long-press inspect (it clashed with dragging), the red-flash blip and the draw sting. Draws and the opponent's move have no sound of their own.
- **Sound grill, final picks (Sean, 2026-11-23):**
  - **UI presses** (`ui_tap.ogg`; buttons, Skip, pause, Options rows + sliders, Strange Man pages): a dry SNES-style **wood block**, 493 Hz (a fifth below the first pick), with a 4th-order low-pass at 1.4 kHz. Built by `make_flow_sounds.py` `ui_tap()`.
    - `page`, `pause_open`, `pause_close` and `slider_tick` are aliases of it.
    - UI sounds get no pitch jitter (`Sfx.NO_JITTER`).
  - **Press start:** the "goes first" fanfare (`first_sting()`) through `chorus_delay()` (two detuned wobbling copies + a 170 ms delay with darker repeats).
  - **Coin flip:**
    - `coin_whirr.ogg` = a thumb flick of a warm metal coin (nail click + ringing disc shimmering with the spin).
    - `coin_clink.ogg` = a wood landing with a settling rattle.
    - Both get an RBJ high shelf, -6 dB at 5 kHz. A 3.8 kHz low-pass was "too washed out".
    - The pitch still rises with toss strength (Sean).
  - **Effect fizzle** = water putting out a candle, the soft "tsst" A1 (`make_effect_sounds.py` `write_fizzle()`).
  - **Game start** = a bright SNES horn section, I → V. It's C4 → G4 with a trumpet-like octave on top, played like a SNES sample: 32 kHz, BRR 4-bit grain, a looped sustain, the SNES echo. Built by `make_reaction_sounds.py` `game_start()` → `snes_section(32000, ...)`. C1 was "too warm"; Sean picked D3.
  - **No other sound gets the SNES treatment** (Sean).
  - The shared synthesis lives in `art/audio/make_snes_coin_fizzle_options.py`: SNES chain, BRR, horn, coin, fizzle. Its `main()` rebuilds the listening options only; the game files come from the `make_*_sounds.py` scripts.
- **Listening files (local, untracked; keep them until Sean says otherwise; he got annoyed when some were deleted):**
  - `art/audio/compare_soft_ui/`
  - `art/audio/compare_snes_coin_fizzle/` (README inside)
  - `art/audio/make_highpass_tap_options.py`
- **Sound workflow:**
  - Show options and wait for Sean's pick; never wire one in yourself.
  - Tools: numpy + scipy + ffmpeg at `C:\Users\Sean\Apps\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe`.
  - Rerunning a `make_*_sounds.py` script re-encodes every ogg it writes. Write just the one you need (`write_ogg(module.fn(), "x.ogg")`), or `git checkout` the others.
  - Check what the game really plays with `godot --headless -s res://tests/record_ui_tap.gd -- <out.wav> <sound>` (records the Master bus), then compare it with the file.
  - If Sean hears something different from a file, first check his branch and that the project reloaded (import cache).
  - Python on Windows: open files with `encoding="utf-8"`. Opening a file for writing truncates it even when the write then fails, so build the string first.
- **Smoke:** `docs/SMOKE_V0.1.md` (A1–A10 pass on desktop; known gaps). Soak: `godot --headless -s res://tests/soak_m6d.gd` (8 real-time games, ~6 min).

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

### Tests (all pass, 1080 checks, 2026-11-23; counts below are current on `m6e-framework`)

```powershell
$g = "C:/Users/Sean/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
& $g --headless --editor --quit            # refresh class cache / reimport (may segfault on quit; harmless)
& $g --headless -s res://tests/test_scenario.gd    # 547 checks
& $g --headless -s res://tests/test_turn_loop.gd   # 192
& $g --headless -s res://tests/test_board_state.gd # 78
& $g --headless -s res://tests/test_flow_m3.gd     # 186
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
- **A looping sound** (the fuse) still playing when a test quits can print "resources still in use at exit". Stop it and wait a moment before `quit()`.
- **Fixes after a merge** go on a short branch (e.g. `m6c-chain-loss-angry`) for Sean to check, then get merged.

---

## Kickoff prompt (paste each session)

```text
You are coding Four in a Rogue (Godot 4.7) in this repo.

1. Read CLAUDE.md and docs/CLAUDE_CODE_HANDOFF.md.
2. Read v0.1 rules from Obsidian: Projects/Four-in-a-Rogue/Design/vertical-slice-v0.1.md, plus the latest session log and decision log.
3. Do the next item in CLAUDE.md §Milestones (currently **M6e Discard**: propose each discard Goob's rules for Sean's approval first, see "M6e Discard category" above) on a new branch (`m6e-discard`); push it for Sean's check.
4. One milestone only; small commits, push each; match existing GDScript style.
5. Do not invent mechanics or add scope (no shop, runs, Goobs beyond the M6e roster).
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

*Last updated: 2026-11-23 (M6e Destroy accepted and merged with code review fixes and the resurrect sound; next = M6e Discard. Earlier: M6e Move and framework accepted and merged; M6d accepted and merged after the sound grill)*
