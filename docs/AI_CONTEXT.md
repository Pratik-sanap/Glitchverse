# AI_CONTEXT — Rift Runner

## Purpose
This document is the single source of truth for every AI assistant working in this repo.
Read this before writing any code.

---

## What this game is

**Rift Runner** — a 2D side-scrolling platformer (Godot 4.3, GDScript).
Astronaut Nova is stranded on 4 planets and must run, jump, collect ship parts and reach the exit portal in each level.

---

## Dimension system

Every level has two linked dimensions:

| Dimension | Alias | Description |
|-----------|-------|-------------|
| A | Reality | Spikes, monsters, energy cells, the ship part, the exit |
| B | Source Layer | Blue wireframe copy. Objects can be edited here. An edit to an object changes its twin in A. |

The player can switch between dimensions only while standing inside a **portal zone**.

---

## Entities (contract — do not change keys)

Each entity in a level JSON has:

```json
{
  "id":     "string",
  "type":   "spike|pit|wall|monster|crate|plate|energyCell|shipPart|editBlock|portal|exit",
  "world":  "A|B",
  "x":      0.0,
  "y":      0.0,
  "w":      0.0,   // optional
  "h":      0.0,   // optional
  "skill":  "...", // optional, for editBlock
  "twinId": "..."  // optional, links to twin in other world
}
```

---

## Level JSON contract

```json
{
  "id":        1,
  "planet":    "Moon",
  "startPoints": 30,
  "lives":     3,
  "levelSize": { "w": 3200, "h": 720 },
  "spawn":     { "x": 100, "y": 500 },
  "gravity":   1600.0,
  "platforms": [ { "x": 0, "y": 680, "w": 3200, "h": 40 } ],
  "entities":  [ ... ],
  "portals":   [ { "x": 600, "y": 580, "w": 80, "h": 100 } ],
  "parts":     1,
  "objective": { "type": "push_block", "timeLimit": 30 }
}
```

---

## Game state keys

```
level_id, world, player{x,y,vx,vy,on_ground,facing},
points, lives, parts{collected,total},
entities[], status(playing|won|lost), time
```

---

## Signals (Game autoload)

| Signal | Args |
|--------|------|
| `state_changed` | — |
| `points_changed` | `new_points: int` |
| `player_died` | `lives_left: int` |
| `level_cleared` | `points: int` |
| `game_over` | — |

---

## Actions (public methods on Game)

```
load_level(id)
set_move(axis)          # axis ∈ [-1, 1]
jump(pressed)
switch_world()
use_skill(skill_name, target_id)
reset_level()
get_state() → Dictionary
```

---

## Skill rules

| Skill | World | Cost | Effect |
|-------|-------|------|--------|
| delete | B | 15 EP | removes nearest editable twin in range |
| duplicate | B | 20 EP | copies nearest editable twin in range |
| move | B | 10 EP | moves nearest editable twin in range |
| shield | A | 10 EP | blocks one hit |

Range = 120 px (Config.SKILL_RANGE).

---

## Points rules

| Event | Change |
|-------|--------|
| Start of level | +30 EP |
| Complete B-room objective | +25 |
| Complete B-room within time limit | +10 bonus |
| Pick up energy cell | +5 |
| Clear obstacle with a skill | +10 |
| Collect ship part | +30 |
| Per life remaining at level end | +10 |
| Die (touch spike/monster/fall in pit) | −20 |
| Use skill | −cost (see above) |
| Floor | never below 0 |

---

## GDScript rules

- Godot 4 only: `@onready`, `@export`, `await`, `signal.connect(callable)`
- Never use: `onready var`, `export var`, `yield`, `connect("signal", self, "method")`
- Typed variables everywhere
- No drawing/Node code in `src/logic/`
- All numbers in `src/logic/config.gd`

---

## Folder ownership

| Folder | Owner |
|--------|-------|
| `src/logic/`, `project.godot` | Role A |
| `src/levels/`, `docs/` | Role B |
| `src/scenes/`, `src/ui/`, `assets/` | Role C |
