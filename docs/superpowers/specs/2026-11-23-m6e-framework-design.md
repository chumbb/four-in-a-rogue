# M6e framework — design (2026-11-23)

Part 1 of M6e (special Goobs before M7). Decisions: vault Decision-Log 2026-11-23; roster and deck rules: vault `Design/Special Goobs.md` "2026-11-23 update". This session builds **no new Goob effects**: each category session proposes its Goobs' rules for Sean's approval first. The framework is everything those sessions share, plus the testing tools.

## Intent

The category sessions should each only have to add Goob resources plus their effect code. Every common mechanic (new decks, multipliers, piles, delayed effects, rolling, the discard reveal) and every testing aid (picker, forced categories, auto-play) lands here, playtested once.

## Goals

1. **Multipliers and names.** Convincing, Fat, Popular and Plentiful go to ×2. Vanilla is shown as "Goob", and Popular's card text becomes "Drop a Goob into a random column." Scoring shows ×2 / ×1, so a four can sum to 8.
2. **Categories.** `GoobDefinition.category` (NONE, UNIQUE, TECH, MOVE, DESTROY, DISCARD, DRAW). Convincing and Popular = UNIQUE, Fat = DESTROY, Plentiful = DRAW, Vanilla = NONE.
3. **Rolled decks.** `DeckBuilder.roll(rng, roster, forced := {})` builds each side's 21 separately, per the spec:
   - 11 Goobs;
   - 1–2 from the UNIQUE+TECH pool;
   - 2 different categories from MOVE/DESTROY/DISCARD, sized so the total is 10;
   - draw Goobs fill 0–1 slots of one pool and 0–2 of the other (which pool is random);
   - no duplicate types while the pool has enough.

   The roster = every `.tres` in `resources/goobs/` with a category. A draw replay reshuffles the same two decks. `starter_deck.json` stays only for tests that pass an explicit deck.
4. **Piles.** Each `Deck` gets `discard_pile` and `destroyed_pile`.
   - Fat's destroy (and every destroy after it) puts the Goob into the pile of the side that owned it.
   - `Deck.discard(index)` moves a hand Goob into the discard pile.
5. **Effect steps.** TurnLoop records `effect_steps: Array[Dictionary]`, one entry per thing that happened, in order. The scenario plays them one after another. The current four effects each produce one step. `last_effect` stays as the first step, so reactions and the AI keep working unchanged. Later effects (discard 2 then destroy, chains) append more steps.
6. **Delayed and on-board effects.**
   - TurnLoop keeps `statuses: Array[Dictionary]` (`id`, `side`, `label`, `text`, `turns_left` or −1 for "while on the board"), with turn-start and turn-end hooks where later sessions plug in.
   - The HUD–board gap shows one text pill per status: blue = yours, red = his. Tapping a pill shows its text as a toast.
7. **Shared roll rule.** `TurnLoop.roll_goob(cell, dir) -> Array[Vector2i]` (the path) moves a Goob sideways while the next column is lower, letting it fall into each column. It stops at the border or at a column of equal or greater height, and never leaves the board. The Goobs above the old cell fall. Logic + unit tests only; the move session adds the animation.
8. **Discard reveal.** `_show_discard(goob, side)` in the scenario:
   - the Goob pops up big in the centre, using the drawn-Goob reveal motion;
   - its name shows in the gap for ~1.2 s;
   - it leaves the screen, downward for yours and upward for his.

   Several discards play one at a time at normal speed, even on Fast.
9. **Debug Goob picker (F4, debug builds only).** A panel listing every Goob in the roster, with a "You / Opponent" switch. Tapping a Goob adds it to that hand; with a full hand it replaces the oldest Goob. "Discard random" plays the reveal (to test it), and "Add test status" makes a pill. The panel also holds a **category deck** row: Auto, or a pick of the UP/tech pool and the two main categories for the **next** deck. The choice is held in `GameFlow` until reset.
10. **Auto-play (debug builds only).**
    - A "»" button (Monogram, normal button panel, ≥ 96 px) sits right of Pause and lights up while auto-play is on. A debug-only Options row "Auto-play button" (default On) shows or hides it.
    - While it's on, `OpponentAI.choose_move` picks your moves on a mirrored board, with the same think delay. Your timer and fuse are hidden and input is locked.
    - Pressing it again gives control back; if it's your turn, the timer restarts at 30 s.
    - The coin flip auto-flips while it's on. It stops (turns off) at the win/lose end screen and continues through draw replays.

## Non-goals

- Any new Goob or effect.
- New art or icons (Art F / Art G).
- Biome tags.
- AI values for effects that don't exist yet.

## Anti-goals

- The current game playing differently, apart from the decks and ×2.
- Debug tools reachable in release builds.
- Faster discard reveals.

## Constraints

- GDScript style as in the repo.
- Gameplay input stays on touch events.
- Everything in debug builds hangs off `OS.is_debug_build()`.
- Existing tests are updated for ×2 and rolled decks.

## Approaches

- **Steps list vs one effect dict.** (a) An ordered `effect_steps` list (chosen): multi-part effects and chains become data the view replays, and `last_effect` stays for old callers. (b) Keep one dict and add fields per Goob: grows messy by the second category. (c) An event bus with signals: cuts across the existing land → effect → win check flow and the AI's simulation.
- **Statuses in TurnLoop vs per-Goob nodes.** Kept in TurnLoop (chosen), because the rules stay headless and testable and the AI can read them. Nodes would put rules in the view.

## Calls I made (Sean to check)

- **Categories with no built Goobs yet** (move, discard, tech today) can still be rolled, and their slots become plain Goobs until that category exists. A category with only one or two types repeats them (per "no duplicates while there are enough types"). Today's decks are therefore 11–19 plain Goobs + Convincing/Popular + some Fats/Plentifuls, and they fill up as categories land. Rolling only from categories that have Goobs would give 8–9 Fats per deck.
- The picker **replaces the oldest Goob** when the hand is full.
- **Auto-play turns itself off at the end screen**, so the next game starts manual.
- Pills sit in one row in the strip of the gap above the aim lane (never over a column hit area): yours from the left, his from the right. Toasts and banners still play centred over them. (Ruling during build: the bottom of the gap is the aim lane.)
- The F4 panel holds the category deck setting (not Options), so Options stays player-facing.
