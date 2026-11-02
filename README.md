# Four in a Rogue

Deck-driven **Connect 4** roguelike (Godot 4, PC-first). Currently at **M3 (turn loop)**, awaiting playtest: scene flow, starter Goob data, and a playable upright 7×6 3D board with alternating turns against a win/block/random opponent — no decks or effects yet.

Design references live in the project docs (`four-in-a-rogue-vertical-slice.md`, `four-in-a-rogue-design.md`).

## Requirements

- **Godot 4.6.3** (Forward+ renderer).
- Windows / Linux / macOS for development; target is **1920×1080**, **mouse** input for v0.1.

## Open in Godot

1. Install [Godot 4.6.3](https://godotengine.org/download).
2. Clone this repo and open the folder containing `project.godot`.
3. In the Project Manager, **Import** → select `project.godot` (or double-click it).
4. Press **F5** (Run). Flow: **title (Press Start)** → **Strange Man** dialogue → **coin flip stub** → **scenario**. A left click on the title is Press Start. Pressing **Flip** locks the choice (Heads and Tails can be changed until then) and the scenario loads after 1.5 s. In the scenario, left click drops blue (player) and red (opponent AI) answers after 0.6 s; the end overlay shows Win / Lose / Draw with **Back to title** or **Replay** (draw, goes to the coin flip).

## Project layout

```
scenes/app/          Boot, title, strange man
scenes/ui/           Coin flip
scenes/scenario/     Slice scenario shell
scenes/board/        Isometric 3D board placeholder
scripts/core/        GameFlow autoload, boot
scripts/rules/       BoardState (7×6 stub)
scripts/deck/        Starter deck manifest loader
scripts/goobs/       GoobDefinition resource type
scripts/ai/          Opponent AI stub (M6)
resources/goobs/     Vanilla, Convincing, Fat, Popular + starter_deck.json
assets/              Art/audio placeholders
```

## Git Sync (editor toolbar)

`addons/git_sync` adds **Git: [branch ▾] [Sync] [↻]** to the editor toolbar (enabled in `project.godot`). **Sync** fetches, switches to the picked branch and fast-forward pulls, then rescans the project. Tracked local edits are stashed first (`git stash pop` to restore); it never merges, rebases or discards commits — if the branch has diverged it stops and says so. Needs `git` on PATH.

## Tests

Headless, no editor needed:

```bash
godot --headless -s res://tests/test_board_state.gd   # BoardState logic
godot --headless -s res://tests/test_opponent_ai.gd    # OpponentAI win / block / random column
godot --headless -s res://tests/test_turn_loop.gd      # TurnLoop alternation and end result
godot --headless -s res://tests/test_scenario.gd       # scenario scene: picking, drops, full column, turn loop
godot --headless -s res://tests/test_flow_m3.gd        # title click, coin flip auto-continue, replay flow
godot --headless -s res://tests/test_git_sync.gd       # Git Sync plugin logic (throwaway local repos)
```

Each exits 0 on pass, 1 on failure.

## Starter Goobs (v0.1 data)

| Goob | Multiplier | Effect (on play) |
|------|------------|------------------|
| Vanilla Goob | 1× | None |
| Convincing Goob | 0.5× | Flip adjacent opposing Goob |
| Fat Goob | 0.5× | Destroy adjacent Goob |
| Popular Goob | 0.5× | Extra Vanilla drop in random column |

Both sides use the same **21-card** starter deck (18 vanilla + 3 specials); shuffle and turn rules land in later milestones.

## Milestones

- **M1 (this repo):** Shell + wired flow ✅
- **M2:** Board core — drops, gravity, four-in-a-row, mouse column picking, full-column feedback ✅
- **M3–M6:** Turns, decks, Goob effects, AI — see `CLAUDE.md` §7.

## License

TBD.
