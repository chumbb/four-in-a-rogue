# Claude Code handoff — Four in a Rogue

**Owner:** Sean Bishop · **Repo:** https://github.com/chumbb/four-in-a-rogue · **Engine:** Godot 4.7 (only)

Read **`CLAUDE.md`** at repo root too (Claude Code loads it automatically). **Design docs live in Obsidian**, not in this repo.

---

## Session startup (Sean’s PC)

```powershell
cd $HOME\four-in-a-rogue
git checkout m4-decks-hands   # until M4 is accepted and merged; then main
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
- Latest session log: `Projects/Four-in-a-Rogue/Session-Logs/2026-11-13 Claude - M4 decks and hands.md`
- Vault agent rules: `GameDev/CLAUDE.md`

**Conflict rule:** Obsidian vault wins over repo `CLAUDE.md` for game design.

---

## Current focus — M4 check (Decks & hands)

| Milestone | Status |
|-----------|--------|
| M1, M2, M3, M3.5, M3.6 | Done, merged to `main` (M3.6 on 2026-11-13) |
| **M4 Decks & hands** | **Built on `m4-decks-hands`, pushed, not merged — awaiting Sean’s playtest** |
| Art pass A, Writing session | Queued, each its own session, after M4 is accepted |
| M5–M7 | Queued — see `CLAUDE.md` §Milestones |

### Commits on `m4-decks-hands`

| Commit | What |
|--------|------|
| `f020221` | Decks, hands and turn draws in `TurnLoop`; exact card text in Goob `.tres` |
| `b4e13bc` | Player hand fan, drag and tap aim, double-tap inspect, draw reveal |
| `2875103` | Inspect panel fills the screen (dim + centred panel) |
| `ecd54d2` | Sounds for hand, aiming, drops and timeout (CC0 + credited CC-BY) |
| `da50d91` | Docs: M4 status + M4 open rules in `CLAUDE.md` |

### What M4 added (where to look)

- **Rules:** `scripts/deck/deck.gd` (`Deck`: draw pile + hand, max 5, start 3, skipped draws stay on top), `scripts/deck/starter_deck.gd` (`build()` = 21 Goobs), `scripts/rules/turn_loop.gd` (shuffle, start hands, draw 1 per turn, side with no Goobs is skipped, both out = draw).
- **Hand UI:** `scripts/hand/hand_view.gd` (`HandView` on the `PlayerHand` node): fan, select lift, drag ghost, fly-back, drawn-Goob reveal.
- **Input:** `scripts/scenario/scenario_placeholder.gd` — gestures (hand / board), tap-aim + second tap drop, hold/slide release drop, drag drop/cancel, double-tap inspect, full-column grey, timeout pick, hand-full toast + shake.
- **Inspect:** `scripts/ui/inspect_panel.gd` (`InspectPanel`, built in code; placeholder flavour line).
- **Sound:** `scripts/audio/sfx.gd` (`Sfx` node, 17 named sounds, ±5 % pitch, opponent −10 %, once per frame); files in `assets/audio/sfx/`, credits in `assets/audio/CREDITS.md`. `BoardView2D.drop_sound` and `HandView.hand_sound` signals feed it.

### Sean’s answers this milestone (2026-11-13, in vault + `CLAUDE.md`)

- Column touch with no hand Goob selected → ignored silently.
- Timeout → the selected/dragged Goob plays, else a random hand Goob.
- Until M6 the opponent plays a random Goob from its hand.

### Claude’s implementation choices — Sean to confirm

- A tap-aimed column (aim still showing after the finger lifts) counts as the timeout column.
- Cancelling a drag deselects the Goob.
- The 24 px fuse strip is left for M6 (adding it now pushed the board off centre).
- Sounds were picked by name and length, not by ear — judge them in the playtest.
- Noah Kuehne’s menu pack: store says CC0, its `License.txt` says CC-BY 4.0 → treated as CC-BY and credited.

### Playtest (Sean, local copy, 1080×1920, mouse as touch)

Git Sync → switch to `m4-decks-hands` → open `project.godot` → **F5** → tap → Strange Man → flip. Then:

1. You start with 4 Goobs (3 + first draw); the drawn one pops in big at the centre, then flies into the fan.
2. Tap a column with nothing selected → nothing happens.
3. Tap a Goob (lifts, outline white-blue), tap column A (blue flash + floating Goob), tap column B (aim moves), tap B again → drops.
4. Hold or slide on a column, release → drops.
5. Drag a Goob off the board and let go → flies back; drag onto a column and let go → drops.
6. Fill a column, select a Goob → that column is greyed; touching it → shake + error sound + "Column full".
7. Double-tap a hand Goob → inspect (name, card text, flavour placeholder); next tap closes. With nothing selected, double-tap a board Goob → inspect.
8. Let the 30 s timer run out with a Goob selected → that Goob plays ("Time's up!" + column flash first).
9. Play a full game → win/lose overlay → Title; a full board with no four → "Draw" → Replay → coin flip, fresh hands of 3.
10. Listen: select, drag, cancel, column blip/tick, rest, roll, fall, land, draw pop, fly, inspect open/close, "Time's up!".

"Hand full" only happens after Plentiful’s draw 2 (M5), so it is covered by tests but not visible in play yet.

**Pass:** draw/play limits right, hand never above 5, both input styles play and cancel, no softlock, draw replays.

### After the playtest

- **Accepted:** merge `m4-decks-hands` → `main`, push, tick M4 ✅ in `CLAUDE.md` (Now/Next table + Start-here prompt → next is Art pass A), log it in the vault.
- **Changes asked:** fix on `m4-decks-hands`, push each commit, re-run tests, ask Sean to re-check.

### Tests (all pass on `m4-decks-hands`)

```powershell
$g = "C:/Users/Sean/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
& $g --headless --editor --quit            # refresh class cache after new class_name scripts
& $g --headless -s res://tests/test_scenario.gd    # 289 checks
& $g --headless -s res://tests/test_turn_loop.gd   # 93
& $g --headless -s res://tests/test_board_state.gd # 74
& $g --headless -s res://tests/test_flow_m3.gd     # 15
& $g --headless -s res://tests/test_opponent_ai.gd # 86
```

Known: `test_git_sync` "temp repos cleaned up" fails on this machine with or without M4 — pre-existing, not an M4 regression.

### Gotchas

- GDScript warnings are errors: type anything that would infer as Variant (`var x: GoobDefinition = arr.back()`).
- Gameplay input is `InputEventScreenTouch` / `InputEventScreenDrag` only.
- Animated scenario tests must wait for the opening draw reveal before input unlocks (`_wait_input`).

---

## Kickoff prompt (paste each session)

```text
You are coding Four in a Rogue (Godot 4.7) in this repo.

1. Read CLAUDE.md and docs/CLAUDE_CODE_HANDOFF.md.
2. Read v0.1 rules from Obsidian: Projects/Four-in-a-Rogue/Design/vertical-slice-v0.1.md, plus the latest session log and decision log.
3. M4 is built on m4-decks-hands and awaiting Sean's playtest: apply his feedback there, or merge once he accepts. Do not start the next milestone before that.
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
- Commit messages: `M4: <short description>`
- Editor toolbar **Git: [branch] [Sync]** (addon `git_sync`) switches branch + pulls from inside Godot; it only fast-forwards, so push every commit
- Do not commit `.mcp.json` or secrets

---

*Last updated: 2026-11-18 (M4 check handoff)*
