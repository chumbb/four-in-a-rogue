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

Full plan, gap table and open questions: vault **`Projects/Four-in-a-Rogue/Design/Roadmap v0.1 - remaining art and code.md`**. `CLAUDE.md` §Milestones mirrors it (checklists + Strange Man brief). **Everything through M6d is accepted and merged (M6d on 2026-11-23). Sean then added M6e (special Goobs) before M7; the M6e framework is accepted and merged (2026-11-23). M6e Move, Destroy and Discard accepted and merged (2026-11-23), Draw, Tech and Uniquely powerful (2026-11-24): M6e is done. M6f pre-M7 fixes accepted and merged (2026-11-24). Next: M7; Art F / G deferred to after M7 (Sean, 2026-11-24).** Key decisions: v0.1 art is *real but rough*; worried = 7th expression; title idle Goobs Vanilla only; vignette in Art B; Art E after v0.1; M7 required (Pixel 11; Pixel 8 if available); M6b-2 split if M6b overflows; D1 opens with a per-type interview; M6c opens with an AI grill.

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
| 9 | **M6e** special Goobs (Sean 2026-11-23) ✅ | Framework ✅ → Move ✅ → Destroy ✅ → Discard ✅ → Draw ✅ → Tech ✅ → Uniquely powerful ✅ (M6e done) | all |
| 10 | **M6f** pre-M7 fixes ✅ | Last-minute fixes and changes; **Sean plans the list at the start of the session** | M6e |
| 11 | **M7** (required) ← **next** | Android build on Pixel 11 (both renderers), Pixel 8 if available | M6f |
| 12 | **Art F / Art G** (deferred to after M7, Sean 2026-11-24) | Special Goob faces; effect icons (starts with a grill) | M7 |

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
| **M6e Discard** | ✅ Accepted and merged 2026-11-23 |
| **M6e Draw** | ✅ Accepted and merged 2026-11-24 |

### M6e Discard category (accepted and merged 2026-11-23)

- **Rules approved by Sean (2026-11-23):** vault spec `Design/Special Goobs.md` → "M6e Discard rules", Decision-Log 2026-11-23. Distracting (opponent discards a random Goob), Defiant (when discarded, it drops for its owner into a random open column instead), Fickle (discard 1, then draw 1; empty hand fizzles), Ruthless (discard 2, then destroy a random enemy Goob), Reckless (discard your hand, +2 on your next turn draw), Thrifty (a random Goob from your discard pile drops for you, like Occult), Desperate (discard 1, then destroy a random Goob, never itself). **Discard costs are paid in full or the whole effect fizzles, nothing discarded.**
- **Engine (`TurnLoop`):** every discard goes through `_discard` (Defiant drops instead; `_can_discard` hook for tech) and `_discard_random`. Discard Goobs record a `cue` step, then one step per discard; Fickle's draw and Ruthless / Desperate's destroy are their own later steps (the destroy is `last_effect`). Reckless: `_bonus_draws` → `_turn_draw_count`, used up by that draw, "Reckless" pill. Thrifty shares Occult's branch. `sim_state(mirrored)` gives the AI its own hand, the other hand as plain Goobs, and both discard piles.
- **AI:** `_hand_value`: each Goob gained or lost = `DRAW_VALUE`; destroys and Thrifty simulated. **View:** `BoardView2D.play_cue`; `HandView.play_discard(…, defiant)` shakes and shrinks the card at the centre, then the Defiant flips up from behind the board and drops; `_play_draw_step` / `_play_discard_step` in the scenario; debug discards play a Defiant drop too.
- **Tests:** 10 unit tests in `tests/test_turn_loop.gd`, `_test_discard_animations` in `tests/test_scenario.gd`, fuzz `godot --headless -s res://tests/fuzz_m6e_discard.gd` (100 games, ~2.5 min; 300 games passed with 2043 discards / 332 Defiant plays).
- **Claude's calls to confirm in the playtest:** each discard Goob winds up before its reveals; Reckless discards from the right end of the hand; Defiant's drop counts as a landing but not as the turn's play.
- **Test in F5:** F4 → category deck main = Discard + another → "New game with these", or give yourself each Goob (F4 picker); » auto-play to watch the AI.
- Playtest OK (Sean: "playtest is good", 2026-11-23) → merged (`aaf18e3`); Claude's calls stand. Destroy fuzz re-run after the change: 300 games, 0 failures.
- **Post-merge code review:** Sean started `/code-review` on 2026-11-23 after the merge; its findings weren't in when this handoff was written. If they're still open next session, triage them (fix on `main` or a small branch, push) before starting Draw.

### M6e Draw category (accepted and merged 2026-11-24)

- **Rules approved by Sean (2026-11-23/24):** vault spec `Design/Special Goobs.md` → "M6e Draw rules", Decision-Log "M6e Draw rules". **Renames:** draw-2 = **Greedy** (`greedy_goob.tres`, Vanilla art); **Plentiful** (`plentiful_goob.tres`, keeps the Plentiful art + flavour) = "While on the board, you draw a Goob whenever your opponent draws one." **Jinxing** "Your opponent skips their next draw." (−1 on his next turn draw per copy, all on that one turn; never below 0; a forced draw after a skip wins and uses it up; fizzle: his deck empty). **Generous** "While on the board, draw an extra Goob each turn." (+1 per copy owned at the turn start).
- **Engine (`TurnLoop`):** `_turn_draw_count(side, jinxed)` = 1 + Reckless + Generous − Jinxings; `_jinxes` + "Jinxed" pill; `last_jinx_lost` / `last_draw_count` for the toast; `_echo_draws(drawer, n)` after every draw (turn draw → `turn_draw_steps`; Greedy / Fickle → `effect_steps`); echo draws never echo. Generous / Plentiful are passive with board pills (`_sync_board_statuses`, `_owned_cells`).
- **View:** `_play_turn_draw_extras(side)` after the turn draw (yours in `_show_turn_draw`, his in `_run_opponent_turn`): "Jinxed: no draw" / "Opponent jinxed: no draw" toast, then the Plentiful steps (draw cue from the Plentiful, your Goobs revealed into the fan, also during his turn). Jinxing winds up (`cue`).
- **AI:** `_draw_effect_value`: Jinxing = one draw, Generous / Plentiful = `DRAW_EFFECT_TURNS` (2) draws.
- **Tests:** 7 unit tests (`tests/test_turn_loop.gd`), `_test_draw_animations` (`tests/test_scenario.gd`), fuzz `godot --headless -s res://tests/fuzz_m6e_draw.gd` (100 games: 505 Plentiful draws, 149 jinxed draws, 0 failures).
- **Claude's calls to confirm in the playtest:** "Jinxed: N fewer" toast when Reckless / Generous still leave a draw; a Plentiful's echo shows as its own draw cue from the Plentiful's cell; each Plentiful copy is its own step.
- **Test in F5:** F4 → give yourself Jinxing / Generous / Plentiful / Greedy; » auto-play to watch the AI.
- Playtest OK (Sean: "playtest works", 2026-11-24) → code review fixes → merged. Fixes: the Jinxed pill lasts through the jinxed turn (2 ticks); the toast counts only Goobs the deck / hand cap would really have given; a Plentiful whose owner's hand is full (or deck empty) draws nothing, silently; Generous pill wording; Locked rules say Greedy. Left open (nits): the AI's flat draw values ignore the hand cap and a forced draw after a skip; a jinx toast is lost when the jinx skips the turn (the skip toast still shows).

### M6e Tech category (accepted and merged 2026-11-24)

- **Rules approved by Sean (2026-11-24):** vault spec `Design/Special Goobs.md` → "M6e Tech rules", Decision-Log "M6e Tech rules". **Steadfast** / **Loyal** (your Goobs can't be moved / destroyed until the end of his next turn; another copy restarts the window), **Stalwart** (itself: never destroyed or moved; a wall for rolls), **Territorial** (his next turn he can't play in its column; at his timeout it counts as full; lifts if every other column is full), **Inspiring** (a random adjacent friendly Goob with a landing effect fires it again, for you), **Stifling** (his next played Goob has no effect, whatever it is), **Thieving** (steals a random enemy Goob's ongoing effect: passives + armed Spiteful / pending Smouldering; the target turns plain), **Hoarding** (while on the board, its owner's hand can't be discarded by anything, own costs too: Fickle / Ruthless / Desperate / Reckless fizzle).
- **Engine (`TurnLoop`):** `_can_move` (new) next to `_can_destroy` / `_can_discard`; `_can_roll` and `_landing_move` ask it, so pushes, rolls and Bouncy / Slippery landings stop at a protected Goob. Windows are statuses (`_protect`, `_lock_column` with a `columns` key; `_window_turns` = 2 ticks, 3 when set during the other side's turn). `column_blocked` / `locked_columns` / `roll_target` (lock = full); `can_play` refuses locked columns. `_stifles` + `_use_stifle` in `play()` → `_resolve_effect(…, stifled)` (step `stifled`). Thieving rewrites `effect_type` / `effect_description` on copy-on-write copies (`_own_copy`, shared with `_mark`); piles still get the plain definition. `sim_state` carries statuses, stifles and the actor's locked columns (mirrored for auto-play); `play_results` applies them.
- **View:** locked column = dark highlight + grey + "A Goob stops you from playing here" (`_blocked_message`); timeout roll uses `_loop.roll_target`. Steadfast / Loyal / Territorial / Stifling wind up (`cue`); a stifled play fizzles with "Stifled: no effect" / "Opponent stifled: no effect"; Inspiring winds up, sparkles its friend, then the friend's effect plays; Thieving: "Stole X's effect" toast, robbed Goob winds up, thief sparkles. Pills: Steadfast, Loyal, Locked (his side), Stifled (victim's side), Hoarding.
- **AI:** skips locked columns (`state.locked`); simulates protections, Stalwart, Inspiring and stifles; flat values: Steadfast / Loyal / Territorial / Hoarding `TECH_VALUE` (2), Stifling one Goob, Thieving one Goob when something is stealable; stifled → no flat values.
- **Tests:** 10 unit tests (`tests/test_turn_loop.gd`, 489 checks), `_test_tech_animations` (`tests/test_scenario.gd`, 678 checks), fuzz `godot --headless -s res://tests/fuzz_m6e_tech.gd` (100 games: 23 protected targets, 157 stifled plays, 106 steals, 41 inspired, 0 failures).
- **Claude's calls to confirm in the playtest:** Territorial's lock stays on its column even if Territorial moves or is destroyed; a Thieving that stole shows "Stole X's effect: …" as its inspect text and the robbed Goob "Its effect was stolen."; a stolen Lopsided / Tipsy also rolls the thief when it falls; Inspiring can retrigger Spiteful / Smouldering (re-arms) and Thieving.
- **Test in F5:** F4 → category deck top = Tech → "New game with these", or give yourself / him each tech Goob; » auto-play to watch the AI.
- Playtest OK (Sean: "playtest is good", 2026-11-24) → code review fixes → merged. Fixes: the AI gives discard Goobs no value when a Hoarding makes them fizzle; a stifled passive (Generous / Plentiful / Hoarding) keeps its value. Left open (nits): the AI's threat check ignores your Territorial-locked column; an Inspiring-triggered hit gets no portrait reaction. Not changed: `_window_turns`' 3-tick branch is for off-turn drops (a Defiant Steadfast dropping on his turn).

### M6e Uniquely powerful category (accepted and merged 2026-11-24)

- **Rules approved by Sean (2026-11-24):** vault spec `Design/Special Goobs.md` → "M6e Uniquely powerful rules", Decision-Log "M6e Uniquely powerful rules". **Seismic** (every Goob one column, random side; the edge column falls off), **Sinking** (bottom row falls out), **Rowdy** (top Goob of every column bounces, left to right), **Nostalgic** / **Mocking** (become the last Goob you / he played: its landing effect fires, its passives stay). Goobs that leave the board are **destroyed** (piles; Loyal / Stalwart keep them on). Convincing and Popular unchanged.
- **Engine (`TurnLoop`):** `SHIFT` / `SINK` / `BOUNCE_TOPS` / `COPY_OWN` / `COPY_ENEMY`; `_shift` (rows slide edge-first, unmovable / protected-edge Goobs wall their row), `_sink`, `_fall_off` (destroyed pile, step `fallen`, motion `gone: true` ending on an `&"off"` point), `_bounce_tops` (temporary `rowdy` mark, cleared after), `_last_played` (what each side's played Goob counts as; a copy records what it became; `_played_as`, static `copy_source`), `_become` (copy-on-write, "Copied X: …" inspect text). `sim_state` carries `last_played`.
- **View:** `&"off"` motion point (slides past the edge or drops below the board, fading; then freed); `play_move` waits for the wind-up settle when the source moves itself; "Copied X" toast; portrait angry/happy when Goobs knocked off are the other side's.
- **AI:** simulates every outcome (Rowdy capped at 48); flat values follow the Goob a copy becomes.
- **Tests:** 7 unit tests (`tests/test_turn_loop.gd`, 530 checks), `_test_unique_animations` (`tests/test_scenario.gd`, 697 checks), fuzz `godot --headless -s res://tests/fuzz_m6e_unique.gd` (100 games: 612 fell off, 375 copies, 0 failures; ~80 ms per play incl. AI, check in M7).
- **Claude's calls to confirm in the playtest:** Rowdy bounces the top Goob of each column *at that moment* (a Goob that just bounced onto the next column covers it, so that column's old top stays); a Nostalgic with nothing to copy becomes a plain Goob for good; a stifled Nostalgic copies nothing; Goobs falling off slide past the edge / drop out the bottom and fade.
- **Playtest 1 (Sean, 2026-11-24):** Springy changed: a rolling Goob jumps onto a Springy's column only if it is higher; level or lower, it bounces back and rolls on (`_springs_back`; vault Decision-Log "Springy bounce-back").
- **Code review fixes:** a stifled copy turns plain and is recorded plain; Seismic slides onto a Goob that stayed put count as landings (Spiteful / Bouncy / Slippery); the AI samples Rowdy (48 random outcomes, fixed seed per column) instead of the first 48 in order; "Nothing to copy yet" inspect text; no land thud for an all-fell-off batch. Not committed: the editor's `project.godot` churn.
- **Test in F5:** F4 → category deck top = Unique → "New game with these", or give yourself / him each Goob; » auto-play to watch the AI.

#### Original plan (for reference)


- **Step 1, before any code:** propose rules, names and card text per draw Goob (edge cases, fizzles); Sean approves; log to the Decision-Log and a new spec section "M6e Draw rules". **Build nothing before that.**
- **Roster** (vault `Design/Special Goobs.md` "2026-11-23 update" + `resources/goobs/special goobs.txt`): **Plentiful** (exists: draw 2; category DRAW already), **Jinxing** ("your opponent does not draw their next Goob"; old spec §5: their next turn draw is skipped, the Goob stays on top, Plentiful/Generous draws still happen), **Generous** (+1 turn draw per copy while on the board, Sean 2026-11-23; old spec §17: flipped → the opponent gets it, ends when destroyed), and "whenever your opponent draws a Goob, you draw a Goob" (needs a name).
- **Questions for Sean** (examples): does Jinxing stack on consecutive turns or add up on one; does Jinxing count as a skipped draw for the "never skipped twice in a row" rule (the forced draw after a skip wins today, `_begin_turn`); does Generous count for whoever owns it now (flips by Convincing) and does a destroyed/moved one stop at once; the copycat draw: board-persistent or one-shot, which draws trigger it (turn, Plentiful, Fickle, Reckless extras), capped by the hand of 5, can two copycats chain (they shouldn't loop).
- **What exists:** `TurnLoop._turn_draw_count(side)` (Reckless `_bonus_draws` adds to it) and the draw in `_begin_turn` (with the skip rules: `_skipped_last`, `last_skipped`); `Deck.draw` / `draw_blocked_by_hand` (hand cap 5, "Hand full"); draw steps with `drawn` + `hand_full` shown by the scenario's `_play_draw_step` (Plentiful, Fickle); status pills (`add_status` / `remove_status`, `_sync_board_statuses` for board-persistent Goobs like Spiteful); per-Goob state via `_mark` / `base_of`; the AI's `sim_state` + `_hand_value` (flat `DRAW_VALUE` per Goob gained/lost).
- **Tests:** unit tests in `tests/test_turn_loop.gd`, a scenario check like `_test_discard_animations`, and a fuzz like `tests/fuzz_m6e_discard.gd` (hand cap, Goob count conservation).

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

### M6f Pre-M7 fixes ✅ (accepted by Sean and merged to `main` 2026-11-24)

- **Code review fixes (2026-11-24):** `EscapeKey` now exists in release builds too (`handle_escape()` skips a missing debug panel; Esc pause keeps a selected hand Goob unless a finger is down); the glint streak is measured within the 32 px frame (`mod(texel, 32)`, expression sheets); `HandView.goob_at()` tap areas are ≥ 96 px wide (capped at the fan step, `_step()`); small hand Goobs keep their bottom on the stump seat and ease to the new size; sparkles skip `busy` tokens and Goobs still behind the board.

- **Sean's list (2026-11-24), built:** surprised face on a destroy target while it blinks; specials tinted to 90 % + a family ring (option A colour band) replacing the D1 rim motifs; legendary glint and ring map; board sparkles by effect kind. Spec: vault `Design/Special Goobs.md` "Look on the board"; decisions in the Decision-Log "2026-11-24 — M6f list".
- **Code:** `GoobLook.dress()` gives any Goob sprite its material (`pixel_outline.gdshader` `tint` / `glint` / `grow`) and a `Ring` child sprite; the board hides the ring while a token is `busy` (spin frames). `GoobDefinition.look()` (meta `look`, set by `TurnLoop._become`) drives ring / tint / glint; `sparkle()` the sparkle kind. Sparkles: `BoardView2D._update_sparkles` / `_draw_sparkles` on one `Sparkles` layer in `_fx`, from the view's own token Goobs (they lag the rules state during animations on purpose); Steadfast / Loyal check `status_lookup` (`TurnLoop.has_status`).
- **Check:** `godot -s res://tests/capture_m6f.gd -- <dir>` stages every family on the board and takes 28 shots.
- **Part 2 (Sean, 2026-11-24), built:** desktop **Esc** (`EscapeKey` node, `PROCESS_MODE_ALWAYS`, calls `scenario.handle_escape()`; title closes Options in its own `_input`); **deck types** `DeckBuilder.DeckType` CLASSIC 10 + 11 / LOADED 14 + 7, picked once in `TurnLoop.start` for both sides, pools by `ring_family()` (`GoobRoster.family()`), top 1–2 / 2–3, Draw 0–1 per main pool, ≤ 2 legendaries; F4 "Deck type" row replaces the old top-pool row (`forced["type"]`). **Hand max 7** (`Deck.HAND_MAX`): `HandView.goob_px()` drops to the board's `board_px()` past 5; `_slot()` widens to the side insets when a step would fall under 96 px; `_stagger_names()` drops every second name a line when they'd overlap. The capture script also shoots 6- and 7-Goob hands.

- Sean, 2026-11-24: one more branch before M7 for last-minute fixes and changes. **He plans the list at the start of that session**: ask for it, don't pick items, build nothing before he has. Then the usual: small commits, playtest, code review, merge.
- Art F / G are **deferred to after M7**, so the hand's name labels under Vanilla-art specials (`HandView._place_name`) and the text pills stay for now.
- Open nits from earlier code reviews, in case Sean wants any: the AI's threat check ignores your Territorial-locked column; an Inspiring-triggered hit gets no portrait reaction; the AI's flat draw values ignore the hand cap and a forced draw after a skip; a jinx toast is lost when the jinx skips the turn. Uncommitted editor churn in `project.godot` (dropped default-valued settings) is still in Sean's working copy.

### M6g Diagnostics & play data ← **built on `m6g-telemetry`, playtest pending** (Sean, 2026-11-25; before M7)

- **Decisions (Sean, 2026-11-25; vault Decision-Log):** testers he knows only, so it's kept light (no store privacy forms yet). **Sentry** handles crashes and script errors, **PostHog** handles play and performance events. "Send diagnostics" in Options is **on by default**, with no prompt. Only **exported builds** send (debug + release, tagged by `environment`); F5 and the editor's headless runs never do. Sean wants **every Goob's win rate, win rates of Goob combinations, and held in hand vs played at once**.
- **Code:**
  - Autoload **`Telemetry`** (`scripts/core/telemetry.gd`, after `Settings`). `track(event, props)` adds a Sentry breadcrumb and queues a PostHog event (anonymous `install_id` in `user://telemetry.cfg`, `$process_person_profile: false`). Batches of 20 or every 30 s go to `/batch/`. The queue is saved to `user://telemetry_queue.jsonl` on background, quit and failed sends, capped at 1000. A per-scenario perf sample (`perf_begin` / `perf_end`) covers avg and p5 fps, frames under 30 fps, the worst frame, and peak static memory.
  - Sentry: the vendored **sentry-godot 2.5.1** addon (`addons/sentry/`, trimmed to Windows x86_64 + Android; .NET, web, Linux, macOS and iOS removed). `options/auto_init=false`; `Telemetry._start_sentry()` starts it, reaching the classes by name so the script parses where the library is missing. `debug/settings/gdscript/always_track_call_stacks=true` is set because Sentry needs it for GDScript stack traces.
  - Keys: `config/telemetry_keys.gd` is **gitignored**; copy `config/telemetry_keys.example.gd` and fill in `SENTRY_DSN`, `POSTHOG_KEY` and `POSTHOG_HOST`. A `.gd` file is always exported, so it needs no include filter. Empty keys = that service stays off.
  - Goob play data: `Deck.turns` (bumped in `TurnLoop._begin_turn`) and `Deck.hand_drawn_at`, kept in step by `draw` / `take` / `add`, give `Deck.held_turns(i)` (0 = played at once; the starting hand counts as drawn on turn 1). Debug Give Goob now goes through `Deck.take` / `add`. The scenario's `_track_start` / `_track_play` / `_track_end` / `_exit_tree` send `scenario_start`, `goob_played` (goob, column, turn, `turns_held`, hand size, timeout, auto-play, effects + fizzles) and `scenario_end`. Per side, `scenario_end` carries the deck, plays in order, held turns, what was left in hand, discarded and destroyed, the winning line, plus result, score and perf. `scenario_quit` is sent on a quit. Other events: `app_start` (device, GPU, renderer, screen), `screen`, `load_time`, `strange_man_skipped`, `turn_timeout`, `hand_full`, `turn_skipped`, `column_full_attempt`, `app_background`. F4-touched games are flagged `debug`.
  - Options row **Send diagnostics** (`Settings.diagnostics`, `[privacy]` in settings.cfg). Off drops the queue and closes Sentry.
  - F4 panel: **Test error** (`push_error`) and **Test crash** (`SentrySDK.get_bad_code().crash_with_abort()`) for checking Sentry from an export.
  - `export_presets.cfg` is now in git (credentials stay in the gitignored `export_credentials.cfg`): Windows Desktop and Android (Gradle build, which Sentry needs; arm64; INTERNET + VIBRATE; package `com.example.$genname` until Sean picks one).
- **Stats:** `tools/telemetry/goob_stats.py` reads `scenario_end` from PostHog (`--project <id>`, personal key in env `POSTHOG_PERSONAL_KEY`, `--host https://us|eu.posthog.com`) or from a file (`--file events.jsonl`). It writes a Markdown report: per Goob win rate in deck / when played / in the winning four; pairs played together (win rate + lift, `--min-pair`); played at once, average held, never played. All rates have Wilson 95 % intervals. Human games only for your side (auto-play and debug games left out; `--include-autoplay` for soak runs); the opponent is reported separately.
- **Tests:** `tests/test_telemetry.gd` (34 checks: off in the editor, batching, failed send kept + reloaded, cap, Off toggle, perf, UUID, Deck held turns, TurnLoop turn counts); `test_flow_m3` now expects 14 / 13 Options targets. All suites pass on 4.7.2: board 78, turn loop 618, AI 77, flow 186, scenario 707. End to end: `godot --headless -s res://tests/telemetry_dump.gd -- out.jsonl 30` plays 30 rolled-deck games and writes their events, then `goob_stats.py --file out.jsonl` reports on them.
- **Known:** with F3 insets at 1080×1920, the debug build's Options window (with the Auto-play row) reaches into the home strip. It fits on the Pixel 11's taller screen, and release builds have one row fewer. Repo +25 MB for the Sentry binaries.
- **Sean to do before checking it:** create the Sentry (Godot platform) + PostHog projects, fill `config/telemetry_keys.gd`, install the Godot 4.7.2 export templates, export Windows Desktop (debug), play one game, check PostHog → Activity / Live events, press F4 → Test error / Test crash and check Sentry. Android waits for M7 (Gradle template, SDK).

### M7 — on-device check (required for v0.1; after M6g; CLAUDE.md §M7)

- **Goal:** an Android debug build on the **Pixel 11**, first with the Mobile renderer, then with Compatibility. Use the **Pixel 8** as the older phone if Sean has one. Check **A9** (portrait touch) on hardware, plus the rest of `docs/SMOKE_V0.1.md`. A true low-end check is a known gap. iOS waits for a Mac; the Retroid Pocket (4:3) is saved for the landscape version.
- **Starting state on this PC (checked 2026-11-23):**
  - `export_presets.cfg` exists since M6g (Windows + Android with Gradle build, INTERNET, VIBRATE); Android still needs the Gradle template (Project → Install Android Build Template) for Sentry
  - `%APPDATA%\Godot\export_templates` is empty
  - no JDK, Android SDK or `adb` on PATH
  - so the session starts with setup:
    - Godot 4.7.2 export templates
    - JDK 17
    - Android SDK (command-line tools, platform-tools, build-tools)
    - set the paths in Editor Settings → Export → Android
    - the debug keystore
    - the Android preset's package name (still `com.example.$genname`)
  - Sean has to do the installs and the USB debugging on the phone himself. Give him exact steps and `!` commands.
- **Things to check on the phone** (desktop smoke already passes):
  - safe area on a real notch / home strip
  - touch: single pointer, 96 px targets, drag vs double-tap inspect
  - haptics (`Input.vibrate_handheld`; needs the VIBRATE permission in the preset)
  - Master muted while backgrounded; ambient audio / silent switch behaviour
  - steady 60 fps
  - the whole-number pixel scale at the phone's width
  - both renderers (the shader baker at export)
  - M6g telemetry from the phone: events in PostHog, F4 Test error / Test crash in Sentry
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
3. Do the next item in CLAUDE.md §Milestones (currently **M6e Tech**: propose each tech Goob's rules for Sean's approval first, see "M6e Tech category" above) on a new branch (`m6e-tech`); push it for Sean's check.
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

*Last updated: 2026-11-24 (M6e Draw accepted and merged with code review fixes; next = M6e Tech. Earlier: M6e Discard accepted and merged; next = M6e Draw. Earlier: M6e Destroy accepted and merged with code review fixes and the resurrect sound. Earlier: M6e Move and framework accepted and merged; M6d accepted and merged after the sound grill)*
