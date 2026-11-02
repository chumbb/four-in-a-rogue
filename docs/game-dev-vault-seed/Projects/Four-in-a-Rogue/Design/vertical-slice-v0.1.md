
Status: v0.1 rules locked for implementation (see §4–§5). Scope: **one playable scenario**, standard **7×6** board, **upright 3D board** (like the real game) in Godot **4.6.3**.

Reference: [four-in-a-rogue-design.md](./four-in-a-rogue-design.md)

---

## 1. Slice goal and acceptance criteria

### Goal

Deliver a **PC-first Godot vertical slice** that proves the core fantasy: **deck-driven Connect 4** against a game-controlled opponent in **one scenario**, with a complete **menu → play → outcome → menu** loop. No run progression, shop, encounters, boss, or meta unlocks in this slice—only enough rules and UI to make a single scenario win or lose feel intentional.

### Acceptance criteria

| # | Criterion | Pass when |
|---|-----------|-----------|
| A1 | **Main menu** | Player can start the slice scenario from a main menu (and return there after the scenario ends). |
| A2 | **Scenario entry** | Entering play shows the standard 7×6 board, scenario win/lose requirements visible in UI (per GDD onboarding: extra win requirements clearly displayed). |
| A3 | **Deck + hand** | Both sides use identical **21-Goob starter decks** (18 vanilla + 1 each of three specials). Each turn: **draw 1**, **play 1** (unless a special says otherwise). **Max hand size 10.** No skipping turns. Empty draw pile = no further draws; player may still play from hand until hand empty. |
| A4 | **Connect 4 foundation** | Drops obey standard Connect 4 placement (column pick, gravity to lowest empty cell in column). **Four in a row** (horizontal, vertical, diagonal) resolves a connect win per standard rules. |
| A5 | **Win** | **Four in a row only** (no point threshold for v0.1). On win, show **score from multipliers** on Goobs in the winning line (see §4). |
| A6 | **Lose** | **Opponent four in a row only.** Return to main menu. |
| A7 | **No dead ends** | After win or lose, player can return to main menu without restart or crash. |
| A8 | **Readability** | Goob effect text is shown for chips in hand/on board (GDD: each Goob’s text explains its effects). Shape/pattern redundancy for player vs opponent pieces is in scope for slice if art permits; full color-blind mode and full accessibility suite can follow later (GDD accessibility list remains target for full game). |

### Out of scope for “done” (see §6)

Multi-scenario runs, shop, encounters, money persistence across scenarios, meta unlocks, tutorial dialogue, mobile builds, and variant boards are **not** required to pass v0.1 acceptance.

---

## 2. Godot project recommendations (high level)

| Topic | Recommendation | Notes |
|-------|----------------|-------|
| **Engine version** | **Godot 4.6.3** (pinned). | Sean, 2026-11-01: develop and test on 4.6.3 only. `project.godot` declares 4.6. |
| **2D vs 3D** | **Upright 3D board** in 3D space, like a real Connect 4 board. | Sean, 2026-11-01 (supersedes the earlier isometric + 2D-sprites-only direction). Goobs get physics, 3D effects and play animations (see Presentation below). UI (hand, HUD) is a Control-based 2D overlay. Logic remains grid-based 7×6. |
| **Rendering** | Forward+ or Compatibility per target GPU; default PC Forward+. | Accessibility toggles (reduce flash/shake) can stub in v0.1. |
| **Input** | **Mouse only** for v0.1. | Keyboard/controller deferred. |

### Suggested folder sketch (Godot project root)

High level only—adjust to team taste:

```
project.godot
scenes/
  app/                 # Main menu, flow root
  scenario/            # Single slice scenario scene
  board/               # Grid, columns, drop preview
  ui/                  # HUD, hand, scenario goals, win/lose overlays
scripts/
  core/                # Game state, turn flow, win detection
  rules/               # Connect 4 + scenario rules
  deck/                # Deck, hand, draw timing
  goobs/               # Chip definitions / effect hooks (v0.1 subset)
  ai/                  # Opponent choice logic
resources/
  goobs/               # Data (Resource or JSON) for chip defs
  fonts/ audio/        # Placeholder OK for slice
assets/                # Sprites, SFX stubs
```

Use **scenes for composition**, **Resources or typed data** for Goob definitions so full-game content can grow without rewriting board logic.

### Presentation (Sean, 2026-11-01)

Supersedes the earlier "isometric 3D + 2D sprites only" direction.

- **Board:** **upright 3D board**, like the real game, existing in 3D space (front panel with holes, columns, floor, stand). The frame is solid for physics so Goobs can fall down the columns.
- **Goobs:** visually interesting, with **real physics and 3D effects when played**, and **animations of being played** (we see the Goob travel down the column). Inspiration: *Hearthstone*, *Marvel Snap*.
- **Hand:** the player **draws a hand of Goobs** and **sees the Goobs in hand**, represented like *Hearthstone* or *Slay the Spire*.
- **Sides:** **enemy red, player blue** (red is the bad guy). Pattern/shape redundancy still planned per GDD accessibility.
- **Column picking** via raycast from camera to column colliders. **HUD** (hand, coin flip, win/lose) on a separate `CanvasLayer`.
- **Logic vs render:** keep **7×6 integer grid state** in code as the source of truth; the 3D view follows it.

---

## 3. Standard board spec

Aligned with GDD (“standard Connect 4 rules remain the foundation”) and slice direction (**7 columns × 6 rows**; variant boards deferred).

| Property | Value |
|----------|--------|
| Columns | **7** |
| Rows | **6** |
| Cell states | Empty; occupied by **player** chip; occupied by **opponent** chip (ownership must not rely on color alone in final art—GDD accessibility). |
| Placement | Player chooses a column; chip falls to the **lowest unoccupied row** in that column. **Full column UX:** shake + error sound + toast (see §4 Invalid placement feedback). |
| Connect win | **Four in a row** ends scenario; **win check always last** after placement and all effects resolve. If **both sides** have four in a row at the win check, the result is a **draw** (Sean, 2026-11-01). |
| Destroyed Goob | When a Goob is destroyed, the Goobs **above it fall** (gravity) — no gaps in a column (Sean, 2026-11-01). |
| Board state | **Empty 7×6** at scenario start. |

---

## 4. v0.1 rules (Sean confirmed)

### Scenario & flow

- **Title:** *Four in a Rogue* (scenario label for slice).
- **Launch flow:** Game launch → **title / start menu** (press start) → **Strange Man** exposition scene (Professor Oak–style minimal lore) → scenario begins → on win/lose, return to menu.
- **Strange Man:** plays **every time** after Press Start, before the scenario (same approved opening dialogue).

### Turn and win/lose

- **First player:** **Coin flip** with animation; **player chooses heads or tails** before flip. **Player wins flip → player moves first.** **As soon as the flip is decided, the scenario begins** — no extra "start scenario" step (Sean, 2026-11-01).
- **Turn flow:** Strict alternation. Each turn: **draw 1 Goob** (if draw pile not empty), then **play exactly 1 Goob** (unless a special allows otherwise). **No skipping.**
- **Hand:** **Max 10** Goobs. **Starting hand: 3** Goobs after shuffle (before first turn).
- **Player wins / loses:** **Four in a row only** (either side). No turn-limit loss in v0.1.
- **Both sides four in a row** at the same win check (possible after effects): **draw** (Sean, 2026-11-01).
- **Draw (stalemate):** If the round ends with **no win** and neither side can continue (both **hands and draw piles empty**, no legal placement path — exact detection in implementation), the scenario ends **immediately as a draw**. **Replay same scenario:** board reset to empty, newly shuffled decks, **new starting hand (3)**. **Do not** repeat Strange Man — go straight to **coin flip** (re-flipped).
- **Resolution order:** Goob **lands** → **special effect** resolves → **win check** (always last).

### Scoring multipliers (v0.1 display)

- Each Goob has a **multiplier**; only Goobs in the **winning line of four** contribute to the displayed score.
- **Vanilla Goob:** **1×**.
- **Special Goobs (starter):** **Convincing Goob**, **Fat Goob**, **Popular Goob** each **0.5×**. Design rule for full game: **stronger effects → lower multiplier**; **high multiplier → “bad” Goobs** (negative effects / more counterplay).
- **Win screen:** show **total score** from multipliers on Goobs in the **winning line of four** (v0.1).
- **Money / shop:** skipped in v0.1; multipliers still useful for feedback and future economy.

### Decks (both sides)

- **Same starter deck** for player and opponent (for now): **21 Goobs** = **18× Vanilla Goob** + **1× Convincing Goob** + **1× Fat Goob** + **1× Popular Goob**.
- **Shuffle once** at scenario start (and again on **draw replay**). **No mid-scenario reshuffle** when draw pile empties.
- **Empty draw pile:** that side **cannot draw** further; may still **play from hand** until hand is empty.

### Starter Goob roster (v0.1)

| Goob | Multiplier | On-play effect |
|------|------------|----------------|
| Vanilla Goob | 1× | None (column drop only) |
| Convincing Goob | 0.5× | **Flip** — random adjacent opposing Goob → yours (8-way, from landed cell) |
| Fat Goob | 0.5× | **Destroy** — random adjacent Goob destroyed (8-way, from landed cell); Goobs above it fall |
| Popular Goob | 0.5× | **Extra drop** — random column, then gravity; spawns a **Vanilla Goob** (your side) |
- Opponent deck is **randomized shuffle** each scenario; encounters **not seeded** (full game will vary; slice uses same composition).

### Invalid placement feedback (Q19 / F1)

- **Full column:** **D** — column **shake** + **error sound** + toast (e.g. “Column full”).
- **Blocked by Goob effects** (frozen slot, etc.): same **shake + error sound**; toast: **“A Goob stops you from playing here”**.

### Opponent AI (v0.1)

- **Always try to win** when possible (immediate four-in-a-row).
- Otherwise play to **win with the hand/deck available** — emulate human-like play (not random-only).
- **Block immediate player win** when a blocking column exists.
- Full game will add **easy / medium / hard / boss** AI; v0.1 uses this single “human-like” baseline.
- AI uses same deck structure; shuffle not seeded.

### Presentation

- **Upright 3D** board; Goobs with physics, 3D effects and play animations; hand shown like *Hearthstone* / *Slay the Spire* (see §2 Presentation).
- **Enemy red, player blue** (add pattern redundancy later per GDD).
- **Input:** mouse only (v0.1).

### Economy

- **Money / shop:** skipped in v0.1.

---

---

## 6. Suggested implementation order (milestones 1–6)

| Milestone | Focus | Deliverable |
|-----------|--------|-------------|
| **M1 — Project shell** | Godot 4 project, resolution, main menu scene, scene flow controller. | Menu with “Play” → loads scenario; “Quit”; return path from end state. |
| **M2 — Board core** | 7×6 grid model, column input, gravity placement, full-column handling, connect-four detection (both players). | Debug or minimal UI to drop player/opponent tokens and log wins. |
| **M3 — Turn loop** | Turn order per Sean’s decision; legal move enforcement; game over → win/lose overlay → menu. | Alternating drops with immutable board state; no decks yet OK if using placeholders. |
| **M4 — Decks and hands** | Starter deck, shuffle, draw 1 / play 1, hand max 10, start 3, empty pile rules. | Both sides; draw replay reshuffle. |
| **M5 — Goobs v0.1 subset** | Data-driven defs: Vanilla, Convincing, Fat, Popular + invalid-placement toasts. | Scenario goal panel; win score from winning line. |
| **M6 — Opponent + polish pass** | AI baseline per Sean; juice (drop anim, connect highlight); scenario end screens; smoke test full loop. | Acceptance criteria A1–A8; known gaps documented for v0.2. |

Dependencies: M2 before M3; M3 before M4; M4 before M5; M5 before meaningful AI with effects (M6).

---

## 7. Explicitly OUT of v0.1

- **Run structure:** nine scenarios + boss; difficulty tiers; run length 30–60 minutes.
- **Between-scenario layer:** shop, random encounters, money spent across scenarios.
- **Meta progression:** unlock Goobs, harder bosses/scenarios, run history, achievements, cosmetics, custom starting decks persistence.
- **Content breadth:** full Goob roster; all effect types listed in GDD; combo systems beyond agreed slice subset.
- **Board variants:** non–7×6 boards; scenario-specific board shapes (deferred per product direction).
- **Onboarding:** opening dialogue from strange man; full tutorial flow (brief tutorial **TBD**—recommend stub or skip for v0.1).
- **Platforms:** Android, iOS, Steam integration beyond local PC build.
- **Business / online:** purchases, analytics, cloud saves.
- **Full accessibility pass:** complete color-blind mode, remapping, touch targets, audio captioning—track against GDD for post-slice.
- **Presentation final:** chiptune soundtrack, Balatro-grade VFX, final art direction (placeholders OK for slice).
- **FOMO, story bloat, lengthy tutorials** (explicitly out of product scope per GDD—do not add in slice).

---

## Document history

| Date | Change |
|------|--------|
| 2026-11-01 | Initial vertical slice v0.1 plan from approved GDD + Sean build direction (Godot, one scenario, standard board). |
| 2026-11-01 | Sean confirmed v0.1 rules: coin flip, lose on opponent 4, 21-card decks (18 vanilla + 3 specials), block-win AI, three special effects, no money. |
| 2026-11-01 | Presentation: isometric 3D board with 2D sprite assets (Godot 3D scene + sprites, 2D UI overlay). |
| 2026-11-01 | Sean answered TBD batch: multipliers, hand max 10, deck rules, 8-way adjacency, effect order, AI, flow, Goob names, red/blue; §5 follow-ups remain. |
| 2026-11-01 | F1–F8 locked: invalid placement D + variable toasts; start hand 3; starter table; draw → replay; win score UI. |
| 2026-11-01 | Draw replay: skip Strange Man, re-flip coin; Popular extra = Vanilla; Goob block toast fixed copy. |
| 2026-11-01 | Sean (Claude session): Godot 4.6.3 pinned; enemy red / player blue; destroyed Goob → Goobs above fall; both sides four in a row → draw; scenario starts as soon as the coin flip is decided; full-column UX recorded in §3. |
| 2026-11-01 | Sean (Claude session): presentation is an **upright 3D board** (supersedes isometric + 2D sprites only); Goobs get physics, 3D effects and play animations (Hearthstone / Marvel Snap); hand shown like Hearthstone / Slay the Spire. M2 board core done. |
