# v0.1 smoke test (A1–A10) — M6d, 2026-11-23

Desktop only (Windows, Godot 4.7.2, 1080×1920 window). Criteria: vault `Design/vertical-slice-v0.1.md` §Acceptance criteria. On-device (Pixel 11) is M7.

## How it was checked

- **Headless suites** (all pass): `test_scenario` 437, `test_flow_m3` 186, `test_turn_loop` 138, `test_board_state` 74, `test_opponent_ai` 77 checks.
- **Real-time soak** `tests/soak_m6d.gd` (new): 8 full games with the starter deck, animations on and the real AI. 3 Normal + 3 Fast games where the player taps (win, else block, else random), plus 1 Fast + 1 Normal game where every player turn times out (2 s timer) and rolls. It fails on 20 s with no Goob landing or a stuck end screen. Result: 16 checks, 0 failures, no softlocks; every end button reached the Title. The AI won all 8 games (it looks one move ahead), so real-time player wins and draws were covered by the suites, not the soak.
- **Windowed flow capture** `tests/capture_e2e.gd`: title → black fade → Strange Man → forest → coin flip → toss → banner → board fade → scenario, all screens reached.
- **Sean's F5 playtest** is still the real check for feel and audio.

## Results

| # | Criterion | Desktop | Evidence |
|---|-----------|---------|----------|
| A1 | Title tap starts; back to title after the end | ✅ | flow: tap/click = Press Start, buttons don't start; soak: Back to title ×8 |
| A2 | 7×6 portrait board; goal visible in the HUD | ✅ | HUD objective "Get four in a row"; layout tests at 1080×1920 + 1080×2340 |
| A3 | 21-Goob starter decks, draw 1 / play 1, hand max 5, empty deck | ✅ | turn_loop: 21 Goobs, start 2 + draw, hand cap, skipped 6th draw, empty deck, stalemate |
| A4 | Gravity drops, four H/V/diag | ✅ | board_state suite |
| A5 | Four only; hidden multipliers; scoring sequence; win → title | ✅ | scenario scoring checks (order, ladder, sum, recognise); soak end flow |
| A6 | Opponent four = lose → title | ✅ | soak (8 losses, all back to Title) |
| A7 | No dead ends after the end | ✅ | soak + end-screen tests (View board / Show result / Back to title / Replay) |
| A8 | Effect text readable on hand and board Goobs | ✅ (see gap 1) | inspect: name, card text, flavour; hand + board; closes on next tap |
| A9 | Portrait single-pointer touch, 1080×1920 + tall + safe area, ≥ 96 px | ✅ desktop / M7 on hardware | touch-only input; F3 insets; ≥ 96 px checks for title, options (12 targets), pause, end button |
| A10 | Options Normal / Fast changes play animations + scoring | ✅ | Fast doubles play animations and halves waits; scoring tweens use the speed |

## Known gaps

1. **A8 wording (fixed).** The criterion said "long-press"; the game uses **double tap** (Sean, 2026-11-10). Long press was tried again on 2026-11-23 and dropped because it clashes with dragging hand Goobs, so A8 now says double tap (vault + `CLAUDE.md`).
2. **A9 on hardware** = M7 (Pixel 11, both renderers). Low-end device check is after v0.1.
3. **Mobile audio is untested until M7.** Built: Master is muted while the app is backgrounded; iOS session = Ambient + mix with others. Android has no silent switch, and Godot doesn't take audio focus, so the player's music should keep playing; check on the Pixel 11. iOS needs a Mac.
4. **Sound-table differences (already Sean's calls or doubling):**
   - Turn banners use one soft whoosh, a little lower for the opponent (Sean, 2026-11-20), instead of two chiptune variants.
   - The column-touch "blip" is the column tick (every column entry clicks; Sean, 2026-11-19).
   - There is no separate "toast pop": every toast already has its own sound (Column full = error, Hand full = hand full, Time's up!).
5. **Music** comes after v0.1. The Music slider has nothing to control yet.
6. **No ambience:** the forest ambience in the sound table was built and then removed (Sean, 2026-11-23; the game gets a retro chiptune soundtrack after v0.1).
7. **Exit warning (debug console only):** quitting while the fuse loop plays can print "resources still in use at exit". Players can't see it.
8. **Real-time player wins and draws** weren't reached by the soak (the AI won every soak game). Unit tests cover both. Sean's playtest should include a win.
