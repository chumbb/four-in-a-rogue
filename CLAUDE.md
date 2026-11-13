# Four in a Rogue — solo dev + Claude Code

**Sean Bishop** · Godot **4.7** (develop and test on this version only; was 4.6.3 until 2026-11-09) · https://github.com/chumbb/four-in-a-rogue

Roguelike Connect 4 with deck Goobs. **You are the only programmer.** Implement **one milestone per session**, playtest in Godot, commit, stop. **Do not invent mechanics** — if a rule is missing, ask Sean.

---

## Design source of truth (global GameDev Obsidian vault)

| What | Where (Sean’s machine) |
|------|-------------------------|
| **Vault root (all games)** | `C:\Users\Sean\Documents\GameDev\` |
| **v0.1 locked rules (canonical)** | `...\GameDev\Projects\Four-in-a-Rogue\Design\vertical-slice-v0.1.md` |
| **Full-game GDD** (incl. Art direction) | `...\GameDev\Projects\Four-in-a-Rogue\Design\GDD.md` |
| **Decision log** | `...\GameDev\Projects\Four-in-a-Rogue\Decisions\Decision-Log.md` |
| **Art research** | `...\GameDev\Projects\Four-in-a-Rogue\Research\HD 2D art style in Godot.md` |
| **Vault AI rules** | `...\GameDev\CLAUDE.md` |

**Conflict rule:** If this file disagrees with the vault, **the vault wins**. After changing design in Obsidian, update §Locked rules here if needed.

**Cursor:** Open `four-in-a-rogue.code-workspace` (repo + GameDev vault).

**Claude Code + Obsidian MCP:** Project `.mcp.json` in repo root (gitignored; matches Cursor). Run `claude` from repo root; approve **obsidian** MCP once. Keep **Obsidian open** on GameDev. Setup/troubleshooting: `docs/CLAUDE_CODE_MCP.md`. Session handoff: `docs/CLAUDE_CODE_HANDOFF.md`.

**Art (Sean, 2026-11-10; was Aseprite-only 2026-11-09): Claude makes Goob art with Aseprite + PixelLab** (no Blender, no manual art steps for Sean). Goob rotation (flips/spins) comes from **PixelLab 8-directional Pro** run through `art/tests/rotation/make_goob_flips.py` as baked frames; Goob backs are plain red/blue. In-use art lives in `assets/goobs/` (Vanilla: `blue|red_yaw|pitch/frame_00–07.png` + strips; `*_yaw/frame_00.png` is the board still). Aseprite (via [pixel-plugin](https://github.com/willibrandon/pixel-plugin)) is for cleanup, expressions, the board and anything PixelLab can't do; on Windows use the `aseprite-win` MCP server (the plugin's own server can't start there). PixelLab MCP is at user scope. Install once in local Claude Code: `claude plugin marketplace add willibrandon/pixel-plugin`, `claude plugin install pixel-plugin`, then `/pixel-setup` (Aseprite 1.3+). Claude app sessions can't reach Aseprite; do art from local `claude`. Painted biome background tooling is still being researched.

**Seed vault once:** copy everything from `docs/game-dev-vault-seed/` into your `GameDev` folder.

**Record everything in the vault (Sean, 2026-11-02):** every Claude and Cursor session stores its work in the GameDev vault, during the session:
- Session summary → `Projects/Four-in-a-Rogue/Session-Logs/YYYY-MM-DD <Claude|Cursor> - <topic>.md`
- Decisions Sean makes → append to `Projects/Four-in-a-Rogue/Decisions/Decision-Log.md`; if a rule changed, update the vault spec and §Locked rules here
- Research / findings → `Projects/Four-in-a-Rogue/Research/<title>.md`
- Read the latest session log and decision log before starting. Local `claude` uses the Obsidian MCP; Claude app sessions use folder access to the vault; Cursor follows `.cursor/rules/obsidian-vault.mdc`.

---

## Start here (copy into Claude Code)

```text
Repo: four-in-a-rogue. Read CLAUDE.md, then GameDev vault vertical-slice-v0.1.md (path in §Design source of truth) for rules.

Implement the next incomplete milestone (currently M4 — Decks & hands; M3.6 2D board accepted and merged 2026-11-13). Rules: vault slice spec + §Locked rules below.
Small diff, match existing GDScript style, no new scope. When done: what to press in F5 to verify, then stop.
```

| Now | Next |
|-----|------|
| **M2** ✅, **M3** ✅, **M3.5** portrait & touch ✅, **M3.6** 2D board ✅ (accepted by Sean and merged to `main` 2026-11-13) | **M4** Decks & hands |
| Local copy → pull (Git Sync) → open `project.godot` → **F5** | On `main`: tap → Strange Man → flip → portrait turn loop vs opponent on the 2D pixel board |

---

## How we work (solo)

1. **One milestone** (M3.5…M7, incl. M3.6) per session unless Sean says otherwise.
2. **Playtest before the next milestone** — Sean always playtests from the **local copy** at `C:\Users\Sean\four-in-a-rogue` (Sean, 2026-11-09): pull first (Git Sync in Godot), then F5 on his vertical **1080×1920** monitor, **mouse clicks as touch**, full flow for that milestone. Cloud / Claude-app sessions must push so the local copy can pull; tell Sean which branch to check out.
3. **Small commits** — e.g. `M2: BoardState drop and win check`. No drive-by refactors.
   **Push every commit/merge right away** — never leave local-only commits; Git Sync in Godot only fast-forwards (Sean, 2026-11-02).
4. **Logic first** — `BoardState` / rules scripts before polish; the view follows grid state (2D from M3.6).
5. **No design drift** — no shop, runs, new Goobs, or “nice to have” unless Sean asks.
6. **Stuck on design?** Ask Sean (see §Ask Sean). Stuck on Godot? Fix with docs; don’t change rules.

---

## Locked rules (v0.1 — do not change)

Full acceptance list: **§Ship checklist** (A1–A10) and vault `vertical-slice-v0.1.md`. Summary below for fast coding sessions.

### Flow

- Boot → Title → **Strange Man** (dialogue below; full body, black spotlight) → forest fades in → **Coin flip** → board transitions in → Scenario. Scenes change with ~0.3 s fades through black (not affected by animation speed).
- **Coin flip (Sean, 2026-11-13; supersedes "player picks heads/tails"):** no pick. The coin is a Vanilla Goob with a blue face and a red face in the screen centre; the player **swipes up anywhere** (starting on the coin = stronger toss; a tap = gentle toss); **50/50 random**, the landed colour goes first (blue = player). Stronger toss = more spins/arc in the same ~0.6 s. Options **Auto-flip coin** (default Off) flips ~0.5 s after the screen appears. After a draw the board fades out, the flip happens over the forest, the board returns.
- **Tapping the start screen counts as Press Start** (a mouse click on desktop). Strange Man plays **after every Press Start** (portrait: old man in Goob-land clothes holding one Goob). No separate tutorial.
- Coin winner moves first (`GameFlow.player_moves_first`). The whole coin flip lasts **≤ 3 s** (Sean, 2026-11-11); M6 animation: coin pops in, ~0.6 s toss, ~0.5 s rest, full-screen flash in the **winner's colour** (blue player / red opponent) + "goes first" banner ~1 s. **Scenario begins as soon as the flip is decided** (no extra start button).
- Win or lose → scoring sequence → **Title**. **Draw** (no four, or both sides four) → no scoring sequence, skip Strange Man (`GameFlow.replay_after_draw()` on `m3-turn-loop` goes straight to the coin flip), coin flip again, reshuffle decks, hand size 3, empty board.

**Strange Man (exact):**

> Hey, you must not be from around here. This is a land of Goobs. If you want to progress, you'll need to get 4 goobs in a row before your opponent does. You'll collect more Goobs as you progress. Once you get all the Goobs, well, I think you know...

### Board & turns

| Rule | Value |
|------|--------|
| Grid | 7×6, empty at start |
| Drop | Column → lowest empty cell |
| Win | 4 in a row (H/V/diag), either side |
| Turn | Draw 1 (if deck not empty), play **exactly 1** Goob; no skip, no mana or cost — every Goob in hand is always playable |
| Hand | Start 3 after shuffle; **max 5** (Sean, 2026-11-09; was 10). A draw that would make a 6th is **skipped** (also Plentiful's draw 2); those Goobs stay on top of the deck. Skipped draw → "Hand full" toast + short whole-screen shake (~0.25 s, even on Skip) |
| Deck | 21 Goobs each side, identical; shuffle once; **no reshuffle** |
| Empty deck | No draws; may still play from hand |
| Out of Goobs | A side with no Goobs (hand + deck) takes no more turns; the other side plays on until the board is full. A four during those turns still ends the scenario |
| Turn timer | **30 s** per player turn (Sean, 2026-11-10), a per-scenario value; HUD countdown; starts when input unlocks, never runs while input is locked; opponent untimed. Timeout must be **obvious** (Sean 2026-11-11: input locks, "Time's up!" toast + column flash ~0.7 s, then the drop). M6 low-time warning: a **burning fuse** for the **last 10 s** in a **24 px** strip between board and hand; fuse end = timeout; HUD countdown stays visible all turn. Timeout → Goob plays into the column under the finger, or (none: never touched / cancelled / released on full column) a **random column, full ones included** |
| Roll | A Goob played into a full column (only at timeout) lands on top, rolls left/right 50/50, keeps going over full columns, **bounces** off the edge, falls into the first open column; then land → effect → win check |
| Stalemate | Both cannot draw and cannot play, no win → **draw** → replay per flow |
| Resolution | **Land → effect → win check last** (Plentiful's draw 2 is its effect) |
| Both sides four | Both sides have four in a row at the win check → **draw** (same replay, no tally) |
| Destroyed Goob | Goobs above it **fall** (no gaps; `BoardState.destroy_cell`) |

### Starter deck (each side)

**17× Vanilla, 1× Convincing, 1× Fat, 1× Popular, 1× Plentiful** (21). Data in `resources/goobs/*.tres` + `starter_deck.json` (updated 2026-11-09: 17 Vanilla + `plentiful_goob.tres`, `EffectType.DRAW_TWO`). The draw-2 effect itself is implemented in M5.

| Goob | Mult | Effect (8-way adjacency from **landed** cell) | Card text (exact) |
|------|------|-----------------------------------------------|-------------------|
| Vanilla | 1.0 | — | (none) |
| Convincing | 0.5 | Flip random **adjacent opposing** Goob to yours | “Flip a random adjacent enemy Goob to your side.” |
| Fat | 0.5 | Destroy random **adjacent** Goob; Goobs above it fall | “Destroy a random adjacent Goob.” |
| Popular | 0.5 | Extra **Vanilla** (your side) in random column (gravity) | “Drop a Vanilla Goob into a random column.” |
| Plentiful | 0.5 | Draw 2 after it lands, before win check (fewer if deck short), on top of the turn draw | “Draw 2 Goobs.” |

Card text = immediate effect only. Random targets: game picks the target first, then that Goob's impact animation plays on it.

**Multipliers are hidden during play.** **Scoring sequence** (one side has four): reveal that line Goob by Goob — lowest column to highest, bottom to top within a column — each bounces and shows its multiplier ~0.6 s apart (Balatro rhythm); short pause; collapse into the sum (tally shown on the board: multipliers float above the Goobs, sum as one big number at the board centre); then declare win (player four) or lose (opponent four). Draws skip it.

### Invalid column UX

- **Full column:** greyed while aiming; drop attempt → shake + error SFX + toast (e.g. “Column full”); Goob stays in hand.
- **Blocked** (future): same + **“A Goob stops you from playing here”**.

### AI (v0.1)

- **M3 (before decks):** opponent drops a plain red Goob, no effect: winning column, else column that blocks the player's immediate four, else **random legal column**.
- **Red flash** (Sean, 2026-11-10): after the think delay, the AI's chosen column flashes red (~0.15 s) right before its Goob is played.
- **M6:** hand-aware, human-like: win if possible → block player’s immediate 4 → else reasonable heuristic (not random). **Opponent's hand is not shown** (Sean, 2026-11-11). After its red flash, its Goob does a subtle **flip up from behind the board**, lands on top of it, then drops.

### Platform & screen (Sean, 2026-11-09 — vault slice §2A/§2B)

- **iOS/Android phones held vertically (portrait)**, developed portrait-first. A landscape Steam version comes later (not v0.1).
- `project.godot`: viewport **720×1280** base; window override **1080×1920** (Sean's monitor); handheld orientation **portrait**; stretch **canvas_items** / aspect **expand** / scale **fractional**; `emulate_touch_from_mouse` **on**, `emulate_mouse_from_touch` **on**; default canvas texture filter **Nearest**; pixel art imported **lossless**; `application/run/max_fps` **60** (fixed 60 fps).
- **Renderer: decided later** (after M7). Project uses **mobile** for now; only use effects that also work in **Compatibility** (no DoF, no CompositorEffects, no HDR 2D). Enable the shader baker at export.
- **Gameplay input reads `InputEventScreenTouch` / `InputEventScreenDrag` only** (never also the emulated mouse events). Single pointer, no hover, no multitouch. Buttons use normal Control signals.
- **Safe area:** full-screen background; HUD/board/hand inside a SafeArea MarginContainer from `DisplayServer.get_display_safe_area()`, reapplied on resize; debug toggle simulates phone insets (~110 px top, ~70 px bottom at 720 base). Nothing interactive in the bottom home-gesture strip; hand inset ≥ 24 px from side edges.
- **Layout (top → bottom, 720 base; revised Sean 2026-11-11):** board **vertically centred**. Above it the HUD: opponent portrait (v0.1 opponent = **Strange Man**, head crop, no name) · "Objective" + per-scenario text ("Get four in a row") · **Pause** top right (Resume / Options / Quit; Sean 2026-11-13, replaces the HUD Quit button; pause stops timer, opponent and animations behind a scrim; Quit confirms "Quit this scenario?" → Title, not a loss) · run details · turn + timer (number from 30, red last 10 s, "—" on opponent's turn); then aim lane 100 · board (no opponent hand zone). Below it a thin **turn-timer strip** (fuse, M6), then **only the player hand**: up to 5 Goobs in a shallow **fan** (tilted outward, no overlap, no slots, ≥ 96 px each), drawn as the **table** the board stands on. **No deck piles or deck count** in v0.1. Drawn Goob pops in big at the centre ~0.7 s, then flies into the fan (M4). Coin result not shown in the scenario. Win/lose/draw = big flashy centred overlay (lead-in: winner's Goobs happy, loser's sad, winning four celebratory face; on a player win the opponent portrait shows "well played", then cracks and explodes; on his win it celebrates). End overlay copy: "You win!" / "You lose" + "Back to title"; "Draw" + "Replay". Opponent portrait expressions (Sean, 2026-11-13): idle, thinking (think delay), happy, angry, surprised (only chains and timeout rolls), celebrating, well played. Toasts: one at a time above the aim lane, ~1.2 s, readable on Skip. **UI pixel unit = one board game pixel** (panels, Monogram text, icons); layout on the 720 base. Full UI spec: vault slice §2B "UI grill (2026-11-13)". Turn banners: red "Opponent's turn", blue "Your turn" (no tint). **Touch-target floor 96 px**; board columns (≈ 85–92 px) accepted, recheck at the M3.6 playtest. HUD, hand and overlays stay crisp Controls on the 720 base.
- **Column touch (M3.5, Sean 2026-11-10):** touch down on a legal column = **blue flash** over column + aim lane, and **your Goob floats on top of the board over that column** (gentle bob; Sean, 2026-11-13; also during the timeout reveal); flash and Goob stay while held and follow the finger; **release over a column = drop**, release outside board = cancel (quick tap drops at once). Touching/sliding onto a full column = shake + error SFX + toast **once per entry**, no flash; releasing there = neutral. Input locked from release until the drop finishes.
- **Playing a Goob (M4):** drag (lift > ~12 px, ghost over the column under the finger, **release over board = drop, release outside = cancel**, Goob flies back to hand; **nothing dims**, same blue column flash as M3.5) or tap (tap Goob to select, tap column to aim, **tap same column again = drop**). From M4 a quick tap on a column only aims; hold > ~0.25 s or slide, then release over a column still drops (Sean, 2026-11-11). **No undo.** Column hit area = full column height + aim lane. Full column greyed while aiming. **Double tap = inspect** (name + card text; closes on next tap; Sean 2026-11-10, was long-press): always on hand Goobs, on board Goobs only when no hand Goob is selected. Input locked during the opponent's turn and animations.
- **Inspect panel (Sean, 2026-11-13):** Goob big on the left; right: name (Monogram 2×, accent colour), effect centred; flavour text (Monogram italic) across the full width at the bottom; board dimmed; next tap closes. Vanilla: name + flavour only. M4 uses a placeholder flavour line. **Hand:** tap lifts the Goob in place, hold makes it follow the finger; giggle face in both.
- **Options:** HUD pause opens Resume / Options / Quit (title also has Options; Quit on the title only in desktop builds). Rows: animation speed, **Haptics** On/Off, **Screen shake** On/Off (all shakes), **Auto-flip coin** On/Off (default Off), Back. Animation speed **Normal / Fast / Skip** (affects play animations and the scoring sequence). **Default Normal; Skip only when the player deliberately turns it on** (Sean, 2026-11-11; revisit if an insanely long effect chain appears). **Haptics:** built-in `Input.vibrate_handheld()` only; one pulse when your Goob lands and on an invalid drop.

### Tech

- Red vs blue: **enemy red, player blue**.
- Grid truth: `scripts/rules/board_state.gd`. View: `scenes/board/board_view_2d.tscn` / `scripts/board/board_view_2d.gd` (`BoardView2D`, upright **2D pixel board**, M3.6; replaced the 3D board). Outline shader: `shaders/pixel_outline.gdshader`.
- **Presentation (all 2D, Sean 2026-11-09):** layers back to front: painted biome background → board back → Goobs → board front (hole mask) → effects → UI.
- **Pixel layer:** board, Goobs and aim lane on a **270×480 game-pixel canvas**, **32 px Goobs/columns**, shown at the **largest whole-number scale that fits screen width in physical pixels** (4× at 1080 wide), nearest filtering; Goob positions snap to whole game pixels while moving. Background and Control UI stay on the 720 base.
- **Art direction (Sean, 2026-11-13 grill; full list in vault GDD §Art direction):** per-biome board skin + painted background (honey wood = **Forest**, v0.1), same board geometry everywhere; **board holes transparent** with a 1–2 px shaded rim; master palette **Resurrect 64** (backgrounds palette-graded, calmer/darker band behind the board); team colour = whole coin body; types = face design + rim emblem; six 2–4 frame expressions per type: idle, **giggle** (selected/dragged/aim float until drop), happy, sad, celebrating, surprised; outline dark brown / gold on winning four / white-blue on selected hand Goob; **hand Goobs one integer step bigger than board** (5× at 1080), fixed size; pixel portraits; coin flip coin = Vanilla Goob with blue and red faces (heads = blue); pixel UI, one look across biomes, font **Monogram** (banners integer 2–3×); no CRT, vignette + pixel VFX on the canvas. Each Goob type gets a type sheet Sean approves before animation.
- **Goob art:** **faces only, no appendages or hands** (Sean, 2026-11-11); Goobs react to game events with **facial expressions**. Pixel sprites with a 3D look, made by Claude with PixelLab + Aseprite (see §Design source of truth, Art); **lighting baked into the sprites**; **outline from a runtime canvas shader**. Placeholders OK for v0.1. Import via `.aseprite`/sprite sheet → `SpriteFrames`.
- Presentation direction: Goobs look visually interesting, with **real physics, 3D effects and play animations** (2D sprites with a 3D look) (Hearthstone / Marvel Snap); each Goob type has its own animation; the hand is a fan of up to 5 faces at the bottom; the opponent's hand is hidden.
- Scenes via **`GameFlow`** autoload only (`scripts/core/game_flow.gd`).
- Goobs: `GoobDefinition` + `.tres`; column hit areas come from `BoardView2D.column_rect()` + the aim lane.

---

## Repo map

```
project.godot                 # boot.tscn, autoload GameFlow
scenes/app/                   # boot, title, strange_man
scenes/ui/coin_flip.tscn
scenes/scenario/scenario.tscn
scenes/board/board_view_2d.tscn   # 2D pixel board (M3.6)
scripts/core/game_flow.gd
scripts/rules/board_state.gd  # extend for M2+
scripts/goobs/, scripts/deck/, scripts/ai/
resources/goobs/*.tres, starter_deck.json
```

```gdscript
# BoardState.CellOwner — EMPTY, PLAYER, OPPONENT
# GoobDefinition.EffectType — NONE, FLIP_ADJACENT, DESTROY_ADJACENT, EXTRA_VANILLA_DROP, DRAW_TWO
```

---

## Milestones

Tick in commit messages. **Do not start M(n+1) until M(n) is playable.**

### M1 — Project shell ✅

Scene flow, Strange Man text, coin flip, empty grid display, Goob resources, `BoardState` stub.

### M2 — Board core ✅

- [x] `BoardState`: `drop(col, owner) -> row or -1`, `column_full`, `find_winner()`
- [x] Mouse column pick (raycast or buttons); full-column feedback
- [x] View syncs tokens on grid (quads/Sprite3D OK)

**Test:** F5 → reach scenario → drops stack correctly; full column shakes/toast; four in a row detectable (temp both sides OK).

### M3 — Turn loop ✅ (merged 2026-11-10; playtested in M3.5)

- [x] Alternate sides after coin flip; end on win/lose; overlay → Title via `GameFlow`
- [x] Draw replay: `GameFlow.replay_after_draw()` → coin flip (no Strange Man)

**Test:** Full win/lose returns to title; draw Replay goes to coin flip, skipping Strange Man (checked in the M3.5 playtest).

### M3.5 — Portrait & touch conversion ✅ (playtested and merged 2026-11-11)

- [x] Open in **Godot 4.7** and let it upgrade the project; commit the result (`c81baf4`)
- [x] `project.godot` portrait settings (§Platform & screen), renderer → **Mobile**
- [x] SafeArea root + simulated-inset toggle on **F3** (debug builds only); background fills the screen
- [x] Reserve empty opponent-hand / player-strip / hand zones; keep the 3D board, fitted to the board zone (no polish)
- [x] Scenario rebuilt in the portrait zones; title, Strange Man, coin flip, end overlay laid out for portrait, ≥ 96 px targets; tap to start
- [x] Board input on touch events: press/hold/release with blue column flash, full-column error once per entry; remove mouse hover preview
- [x] Red opponent flash before its drop
- [x] 30 s turn timer (per-scenario value) with HUD countdown; timeout auto-play; `BoardState` roll resolver with placeholder animation (Goob appears in its final column)

**Test:** Full M3 loop in portrait at 1080×1920 with mouse-as-touch, and in a tall window (e.g. 1080×2340) with simulated insets.

### M3.6 — 2D board conversion ✅ (playtested and merged 2026-11-13)

- [x] Replace the 3D board with an upright 2D pixel board (back layer + front layer with holes). **Art ready** (honey wood, Sean 2026-11-11): `assets/board/board_back.png` + `board_front.png`, 240×216 (panel 240×208 + 8 px feet), grid origin (8, 8), 32 px cells, 28 px holes; source `art/board/board.aseprite` / `make_board.py`. Goob still = `assets/goobs/vanilla/<blue|red>_yaw/frame_00.png`, drawn at cell top-left with y −1 to centre in the hole
- [x] 270×480 pixel layer at whole-number scale; placeholder painted background (gradient); nearest filtering
- [x] Placeholder 32 px Goob sprite + runtime outline shader; 2D drop with pixel snapping
- [x] Roll animation for timeout plays into full columns
- [x] Every played Goob first rests on top of the board over its column (~0.2 s), then falls; rolls start there. This is the landing spot for the M4/M6 flip animations (Sean, 2026-11-12 playtest)
- [x] Aim preview: while holding a legal column, the player's Goob floats (bobbing) on top of the board over it; the drop starts from there (Sean, 2026-11-13)
- [x] Recheck portrait zone heights (board zone 576 at 1080 wide; removed the 60 px opponent-hand zone per 2026-11-11). Grid logic unchanged.

**Test:** Same loop with the 2D board at 1080×1920 and 1080×2340; Goobs sit inside columns; no mixed pixel sizes.

### M4 — Decks & hands ← **next**

- [ ] Load/shuffle `starter_deck.json` (17 Vanilla + 4 specials); draw pile + hand per side; **hand max 5**, start 3
- [ ] Turn draw/play rules; empty deck; draw stalemate → replay
- [ ] Player hand fan (opponent hand hidden), drawn-Goob reveal, hand-full toast + shake; **drag and tap aim state** (ghost, release / second-tap drop, cancel outside board); double-tap inspect

**Test:** Hands visible; deck counts behave; both input styles play and cancel correctly; stalemate replays correctly.

### Art pass A — palette, holes, font, Forest (own session, after M4 is accepted; Sean 2026-11-13)

- [ ] Re-quantise board + Vanilla Goob art to Resurrect 64
- [ ] Transparent board holes with a 1–2 px shaded rim
- [ ] Monogram font for UI text
- [ ] Forest painted background test (palette-graded, calm band behind the board)

### Writing session — lore seed + starter flavour text (own session, after M4; Sean 2026-11-13)

- [ ] Lore seed by effect family and legendary figures (e.g. Goobert the Brave, Gooberius); hints at an apocalyptic calamity that is **never specified anywhere**
- [ ] One flavour line (1–2 sentences) per starter type, Vanilla shared; FromSoftware + Pokédex voice (vault Research notes); Sean approves each

### M5 — Goob effects

- [ ] Land → effect → win check; per-type impact animations
- [ ] Flip / destroy / extra vanilla / draw 2; scoring sequence (Balatro rhythm, ~0.6 s per Goob) on a one-sided four

**Test:** Each special once in a session; order land → effect → win.

### M6 — AI & polish

- [ ] Real `OpponentAI`; flip/drop/impact/highlight animations; coin flip anim
- [ ] Options menu: animation speed Normal / Fast / Skip; built-in haptics
- [ ] Low-time turn-timer warning: burning fuse in the strip between board and hand (Sean, 2026-11-10/11)
- [ ] Coin flip in winner's colour; red/blue turn banners; win/lose lead-ins (Sean, 2026-11-11)
- [ ] Smoke **A1–A10**

### M7 — On-device check (optional for v0.1)

- [ ] Android debug build (one-click deploy; Mobile renderer, then Compatibility on a low-end phone); iOS when a Mac is available

---

## Ship checklist (v0.1 done)

- [ ] A1 Menu ↔ scenario
- [ ] A2 Scenario goals visible
- [ ] A3 Deck/hand/draw rules
- [ ] A4 Connect 4 + detection
- [ ] A5 Win + scoring sequence
- [ ] A6 Lose on opponent 4
- [ ] A7 No softlocks after end
- [ ] A8 Goob text readable (long-press inspect)
- [ ] A9 Portrait touch: whole loop, single pointer, 1080×1920 + tall shape, simulated safe area, ≥ 96 px targets
- [ ] A10 Animation speed Normal / Fast / Skip

---

## Out of scope (unless Sean asks)

Multi-scenario runs, biomes, shop, encounters, money, meta, saves, networking, store builds/submission, the landscape Steam version, accessibility pass (comes at the end — gameplay and UI first), non–7×6 boards, **new Goob types** (Sean, 2026-11-13: 17 more specials come after the starter four work, 21 special types in all; Sean specifies them later), balance changes beyond the starter five, final art (placeholders OK).

Full-game vision: GameDev vault `Design/GDD.md` — **not v0.1 tasks**.

---

## Ask Sean (don’t guess)

- New Goob effects, multipliers, or deck sizes
- Changes to draw/stalemate, AI personality, or UX copy beyond locked strings
- Scope creep (“while we’re here…” features)

Everything else: implement from this file + existing scripts.

---

## Manual test cheat sheet

| Milestone | F5 flow | Pass if |
|-----------|---------|---------|
| M2 | Title → scenario, click columns | Gravity, full column error, 4-in-a-row fires |
| M3 | Play until win/lose/draw | Returns to title; draw Replay goes to coin flip, skipping Strange Man |
| M3.5 | Full loop on the portrait monitor, then a tall window with simulated insets (F3) | Everything fits inside the safe area; hold/flash/release drops; full column errors; red flash; timer auto-plays and rolls; no hover; nothing under the home strip |
| M3.6 | Same as M3.5 | 2D board; Goobs sit inside columns; even pixels at 1080×1920 and 1080×2340 |
| M4 | Several turns, drag and tap | Draw/play limits; hand cap 5; cancel outside board; empty deck |
| M5 | Play each special Goob | Effects match table; score on win line |
| M6 | Let AI play | Blocks/wins when obvious; no softlock |

---

*Last updated: 2026-11-13 (M3.6 accepted and merged; 2026-11-11: M3.5 accepted and merged; grill: hand fan, hidden opponent hand, win/lose faces, fuse, slice §5 resolved) · Handoff: `docs/CLAUDE_CODE_HANDOFF.md`*
