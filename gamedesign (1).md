# Rift Runner — Game Design Document

**Event:** Artificial Arcade (24-hour hackathon, Atharva University, Mumbai)
**Problem statement:** PS01 GlitchVerse (single-player puzzle and adventure)
**Team:** 3 members, all beginners in game development
**Version:** 2.1 — scope locked to 4 levels, built in Godot 4

> Working title. Alternatives: *Parallax Pilot*, *Source Layer*.

---

## 1. One-line pitch

An astronaut stranded across four planets rewrites reality from a hidden "Source Layer", spending energy points to delete, duplicate and move objects, so she can collect her ship's parts and escape.

## 2. Story

Astronaut **Nova** crash-lands and her ship breaks apart. The broken parts are scattered across four planets, and every planet is glitched: it exists as two linked dimensions.

- **Dimension A — Reality.** The dangerous world: spikes, broken bridges, walls, monsters.
- **Dimension B — Source Layer.** A blue wireframe copy of the same level where objects can be edited. Whatever Nova changes in B changes in A.

Collect every part on a planet, reach the exit portal, and travel to the next planet. After Planet 4, the ship is rebuilt and Nova flies home.

## 3. Design pillars

1. **Edit reality.** The hook of the game is that Dimension B rewrites Dimension A. Everything else supports this.
2. **Every point is a choice.** One currency, with tight decisions about what to spend on.
3. **Simple to learn, clear to read.** Turn-based grid, one tile per move, no physics.
4. **Small but polished.** Four well-tested levels beat ten half-working ones.

## 4. Core gameplay loop

1. **Look** at the obstacle in Dimension A.
2. **Enter the portal** to Dimension B.
3. **Solve the B-world puzzle** to earn points (for example, push a block onto a target).
4. **Spend points** on a skill to edit the matching object (delete a spike, duplicate a block into a bridge, move a crate).
5. **Return to A**, where the change has taken effect.
6. **Collect the ship part**, reach the exit portal, and clear the level.

## 5. Core rules

| Rule | Detail |
|---|---|
| Movement | Turn-based on a grid. The player moves one tile per turn (up, down, left, right). Monsters move one tile after each player move. |
| Worlds | Each level has two linked grids, A and B, with the same size. Objects have shared IDs, so an edit to the B object changes its A twin. |
| Portal | Stepping on a portal tile switches worlds. It is free and unlimited. |
| Lives | **3 lives per level.** Losing all 3 restarts the level with its starting points. Lives refill at the start of each new level. |
| Points | One currency called **Energy Points (EP)**. Points can't drop below 0, and a skill you can't afford is locked. |
| Death | Touching a spike, being hit by a monster, or falling in a gap costs **1 life and 20 EP**. You respawn at the level's entry portal. Edits you already made stay. |
| Win | Collect all required ship parts and step on the exit portal. |
| Lose | Lives reach 0. Show Game Over, with a retry. |

## 6. Skills

| Skill | Where used | Cost | Effect |
|---|---|---|---|
| **Delete** | Dimension B | 15 EP | Removes the selected object, and its twin in A disappears (spike, wall, monster). |
| **Duplicate** | Dimension B | 20 EP | Copies a block into an empty cell, and the copy appears in A (a bridge tile, a stepping block). |
| **Move** | Dimension B | 10 EP | Slides an object to a new cell, and it moves in A too (a crate onto a pressure plate). |
| **Shield** | Dimension A | 10 EP | Blocks the next hit from a monster or spike (one use). |

**Stretch skills (only if time remains):** Light level (reveals hidden tiles), Freeze (stops monsters for 2 turns).

## 7. Point economy

### Earning

| Action | EP |
|---|---|
| Solve a B-world puzzle | +25 |
| Solve it within the move limit (bonus) | +10 |
| Pick up an energy cell (A or B) | +5 |
| Clear an obstacle with a skill | +10 |
| Collect a ship part | +30 |
| Finish the level with lives left | +10 per life |

### Spending and losing

| Action | EP |
|---|---|
| Delete | −15 |
| Duplicate | −20 |
| Move | −10 |
| Shield | −10 |
| Dying | −20 (and −1 life) |

### Fairness rules

- Each level starts with **30 EP**.
- Every level has at least one route that is winnable with the starting points plus the B puzzle reward, even after one death.
- Levels 1 to 3 are generous. Only Level 4 is deliberately tight, so the player must choose what to bypass.
- Points never go negative.

### Final score

`Final score = EP remaining at the end of Level 4 + (lives left in each level × 10)`

Stars: 1 star for finishing, 2 stars for a good score, 3 stars for a high score. Exact thresholds are set after playtesting.

---

## 8. Levels

Four levels only. Difficulty rises gradually, and each planet adds one new idea.

### Level 1 — Moon (tutorial)

- **New idea:** portal travel and Delete.
- **Obstacles (A):** one spike blocking a narrow path.
- **B puzzle:** push one block onto a target tile (+25 EP), then delete the red block that matches the spike (−15 EP).
- **Parts:** Fuel Cell (1).
- **Starting EP:** 30. **Difficulty:** easy. Text hints guide the player.

Example layout (Dimension A), 9 × 3 tiles:

```
#########
#POcS.FX#
#########
```

Legend: `#` wall, `P` player start, `O` portal to B, `c` energy cell, `S` spike, `.` floor, `F` ship part, `X` exit.

### Level 2 — Mars

- **New idea:** Duplicate.
- **Obstacles (A):** a broken bridge (gap) and a rock wall.
- **B puzzle:** move a block to complete a pattern, then duplicate a block to fill the gap and delete the wall block.
- **Parts:** Navigation Chip (1).
- **Starting EP:** 30. **Difficulty:** easy to medium.
- **Points check:** Duplicate 20 + Delete 15 = 35, and the puzzle reward gives enough.

### Level 3 — Europa (ice moon)

- **New idea:** Move, monsters and Shield.
- **Obstacles (A):** one patrolling monster, a pressure-plate door and a gap.
- **B puzzle:** move a block onto the plate, duplicate for the gap, then either delete the monster or use Shield.
- **Parts:** Thruster (2, both required).
- **Starting EP:** 30. **Difficulty:** medium.
- **Points check:** Move 10 + Duplicate 20 + (Delete 15 or Shield 10) = 40 to 45. The player must collect energy cells, and a death makes it tight.

### Level 4 — Glitch Core (final)

- **New idea:** everything combined, with scarce points.
- **Obstacles (A):** two monsters, spikes, a gap, a locked door and fake "glitch" tiles that cause a death if stepped on.
- **B puzzle:** two B rooms to solve in order.
- **Parts:** Core Crystal (1) plus the final launch gate.
- **Starting EP:** 30. **Difficulty:** hard.
- **Points check:** using every skill would cost more than the player can earn, so the player must decide which obstacles to remove and which to walk around.

### Difficulty curve

| Level | Planet | Skills in play | Hazards | Difficulty |
|---|---|---|---|---|
| 1 | Moon | Delete | Spike | Easy |
| 2 | Mars | Delete, Duplicate | Gap, wall | Easy to medium |
| 3 | Europa | Delete, Duplicate, Move, Shield | Monster, plate, gap | Medium |
| 4 | Glitch Core | All | Two monsters, spikes, gap, door, fake tiles | Hard |

---

## 9. Objects and obstacles

| Object | In A | In B | Notes |
|---|---|---|---|
| Wall | Blocks movement | Block | Can be deleted or moved if marked movable |
| Spike | Kills on contact | Red block | Delete removes it |
| Gap / broken bridge | Fatal to walk into | Empty cell | Duplicate a block into it to make a bridge |
| Crate | Pushable | Block | Move places it on plates |
| Pressure plate | Opens a door when something is on it | Target tile | Needs a crate or the player |
| Monster | Patrols a fixed path | Block | Can be deleted or avoided |
| Energy cell | +5 EP | +5 EP | Optional pickup |
| Ship part | Required | Not present | Counts toward the level goal |
| Portal | Switches worlds | Switches worlds | Free to use |
| Exit | Ends the level | Not present | Only works with all parts collected |

## 10. Screens and interface

1. **Title** — game name, Play, Credits.
2. **Level select** — 4 planets, locked until the previous one is cleared.
3. **Gameplay** — grid, player, portal toggle, glitch effect on world change.
4. **HUD** — EP, lives (3 icons), parts collected, skill buttons with costs, current planet name.
5. **Level clear** — points breakdown and Next.
6. **Game over** — Retry, Level select.
7. **Ending** — the ship launches, with the final score and stars.

Feedback: floating `+10` and `−20` numbers, a screen shake on death, a blue wireframe tint in Dimension B, and a short glitch effect when travelling through a portal.

## 11. Art and audio direction

- Pixel-art, space theme, with one astronaut sprite (idle, walk, die).
- One shared tileset, **re-skinned by color** per planet: grey (Moon), red (Mars), icy blue (Europa), purple-black (Glitch Core).
- Dimension B uses the same tiles with a blue wireframe look, so no new art is needed.
- Sound: footstep, portal, skill use, point gain, death, level clear, and one looping background track.

---

## 12. Technical approach (proposed)

- **Engine:** Godot 4 with GDScript (free, open source, MIT licence, no fees). 2D first, built on a grid. Godot also supports 3D, so a later 3D port is possible. The whole team uses the same Godot 4.x version.
- **Tools (all free):** Godot, Antigravity (free Individual plan) as the code editor and LLM agent, GitHub for the repo, and free or CC0 art and sound (Kenney, OpenGameArt, Piskel, Krita, jsfxr, Audacity).
- **Separation:** game logic (state, rules, points, lives) is separate from rendering (scenes, sprites, UI). The logic lives in plain GDScript classes behind one `Game` autoload. Scenes only read state, listen to its signals, and send actions such as `move_player` and `use_skill`.
- **Levels as data:** each level is a JSON file (loaded with Godot's built-in JSON parser) describing the grid size, tiles for A and B, object IDs, portals, parts, starting points, the B puzzle and the move limit.
- **Suggested folders (inside the Godot project):** `src/logic/`, `src/levels/`, `src/scenes/`, `src/ui/`, `assets/`, `docs/`. Each folder has one owner, and only one person edits `project.godot`.
- **Scenes:** one small `.tscn` per screen, with most nodes created in script, so scene files stay tiny and merge cleanly in Git.
- **Export:** a Windows build for the demo, plus a Web (HTML5) build as a backup, using Godot's free export templates.
- **Game state holds:** current level, world (A or B), player position, points, lives, parts collected, object list, and the move counter.
- **Cost table** is kept in one config file (`src/logic/config.gd`), so balance changes never touch the rules.

## 13. Scope lock

**In scope (must have):** 4 levels, 2 linked dimensions, point system, 3 lives per level, Delete, Duplicate, Move, Shield, all 7 screens, basic sound.

**Only if time remains:** Light level and Freeze skills, extra animations, a score leaderboard, level timers.

**Out of scope:** more than 4 levels, real-time combat, physics, multiplayer, 3D.

## 14. Testing checklist

- [ ] Each level can be completed with the starting points plus rewards, and with one death
- [ ] Points never go below 0, and locked skills show as locked
- [ ] Losing all 3 lives restarts the level correctly
- [ ] An edit in B always shows in A, and the player can't get stuck
- [ ] Exit only works with all parts collected
- [ ] All screens appear in the right order, with no crash

## 15. Glossary

| Term | Meaning |
|---|---|
| Dimension A / Reality | The hazard world the player moves through |
| Dimension B / Source Layer | The editable wireframe world |
| EP | Energy Points, the single currency |
| Skill | A power-up that costs EP (Delete, Duplicate, Move, Shield) |
| Part | A ship component the player must collect |
