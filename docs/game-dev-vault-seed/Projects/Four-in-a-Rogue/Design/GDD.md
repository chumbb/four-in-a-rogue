---
type: gdd
project: Four-in-a-Rogue
status: active
date: 2026-11-01
---

Status: High-level GDD approved pending final document review.

## High-level synthesis

**4 in a Rogue** is a single-player Connect 4 roguelike in which players use decks of Goobs—chips with modifiers, multipliers, and special traits—to win scenario after scenario on the way to a boss. Runs last about 30–60 minutes, escalate through nine scenarios (easy, medium, hard) plus a boss, and mix familiar Connect 4 play with randomness, shops, encounters, in-run purchases, and deckbuilding. Four in a row wins immediately unless a scenario adds a point threshold; chip points drive scenario payouts. Losing any scenario ends the run; winning and meta progression unlock more Goobs, harder content, cosmetics, and custom starting decks until the player collects every Goob.

The experience is framed by an absurdist land of Goobs, with *Balatro*-leaning atmosphere, brighter *Fields of Mistria* / *Hearthstone*-influenced color, flashy combo moments, and chiptune music. Scope stays tight: no FOMO, minimal story, brief onboarding, and focus on fun runs and Goob synergies. PC launches first, then Android and iOS, as a single upfront purchase. Success means the full unlock-and-harder-run loop stays fun; ten sales is a satisfying commercial bar.

## Confirmed design direction

### Player promise

- Runs offer greater variety and strategic depth than ordinary Connect 4 through random elements, combos, and synergies.
- Satisfying runs feature flashy, high-impact moments and make players feel clever for discovering an emergent solution—like solving a puzzle they did not initially know they were solving.
- After a run, newly unlocked tools and game pieces create excitement to begin another run through meta progression.

### Core loop

- The game is single-player, with the player competing against the game itself.
- The player progresses through scenarios with different board states, completing each within a turn limit or by satisfying other special conditions.
- Completing a scenario awards money that can be spent on power-ups or game pieces which persist for the remainder of the run.
- A successful run ends when the player defeats the boss scenario.
- A successful run should take approximately 30–60 minutes.
- A run contains nine scenarios followed by a boss scenario: three easy scenarios, three medium scenarios, three hard scenarios, then the boss as the most challenging scenario.
- Between scenarios, the player chooses either to visit the shop or undertake a random encounter. An encounter may have positive effects, negative effects, or both.

### Audience and difficulty

- The game assumes Connect 4 is broadly familiar but requires no prior roguelike experience.
- It is easy to learn and becomes progressively more challenging as the player completes scenarios.

### Strategic rules

- Standard Connect 4 rules remain the foundation of play.
- Both the player and the game-controlled opponent use their own deck of chips, begin with a three-chip hand, and draw one chip at the start of each turn.
- Forming a line of four wins the scenario immediately unless the scenario also requires a minimum point total for the win to count.
- Chip point values determine the money awarded at the end of the scenario.
- Chips may have modifiers, multipliers, or special traits that affect scoring or alter the game state, including creating or destroying pieces, converting enemy pieces, causing the opponent to skip a turn, freezing an empty space, or shifting existing pieces.
- Planning, adaptation, and luck may all affect a run, but the player's decisions should feel decisive in whether they win or lose.

### Meta progression

- Unlocked chips persist between runs.
- Players can build different chip decks to begin future runs with.
- Defeating a boss unlocks harder bosses and scenarios for future runs.
- A run-history menu records high scores.
- Secret achievements award cosmetics.

### Failure

- Losing any scenario immediately ends the run and returns the player to the start menu.

### World and presentation

- The gameplay is framed by an absurdist setting called the land of Goobs.
- On the player's first launch, a strange man delivers the opening dialogue: “Hey, you must not be from around here. This is a land of Goobs. If you want to progress, you'll need to get 4 goobs in a row before your opponent does. You'll collect more Goobs as you progress. Once you get all the Goobs, well, I think you know...”
- The atmosphere draws heavily from *Balatro*.
- The color palette is brighter, drawing from *Fields of Mistria* and *Hearthstone*.
- The soundtrack uses chiptunes.
- The board is an upright 3D Connect 4 board in 3D space, like the real game (Sean, 2026-11-01).
- Goobs are visually interesting, with real physics, 3D effects and animations when played; inspiration *Hearthstone* and *Marvel Snap* (Sean, 2026-11-01).
- The player's hand of Goobs is visible on screen, represented like *Hearthstone* or *Slay the Spire* (Sean, 2026-11-01).
- The opponent is red and the player is blue (Sean, 2026-11-01).

### Platforms

- The game launches on PC first, followed by Android and iOS.

### Scope boundaries

- Avoid FOMO-driven mechanics and rewards.
- Avoid excessive story, lengthy or dull tutorials, and feature bloat.
- Keep the game focused on completing runs and unlocking more Goobs that enable fun, exciting combinations.

### Onboarding

- A brief tutorial appears at the start.
- The game builds on familiar Connect 4 rules.
- Any additional win requirements are clearly displayed within the scenario.
- Each Goob's text explains its effects.

### Accessibility

- Include a color-blind mode.
- Use shape and pattern redundancy so ownership and status are never communicated through color alone.
- Support scalable text and UI so Goob effects and scenario goals remain readable across PC and mobile.
- Maintain readable contrast between text, Goobs, board spaces, and effects.
- Provide controls to reduce or disable flashes, animation intensity, and screen shake.
- Support control remapping, controllers, and adequately sized touch targets.
- Communicate important audio cues through text or visuals as well as sound.

### Business model

- The game is sold as a single upfront purchase on Steam and mobile app stores, with no ongoing monetization.

### Success criteria

- The full progression loop remains fun: complete runs, unlock Goobs and harder runs, use increasingly complex and powerful Goobs to complete those challenges, and ultimately collect every Goob.
- Selling at least ten copies would be a satisfying commercial outcome.
