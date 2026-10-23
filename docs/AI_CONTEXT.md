# AI Context & Team Contract: Rift Runner (GlitchVerse)

This document is the **single source of truth** across all 3 team members and their respective AI coding assistants in Antigravity.
Never alter this contract without explicit team consensus.

---

## 1. Team Division & Folder Ownership

- **Role A (Core Logic Lead):** Owns `src/logic/` and `project.godot`.
  - Pure GDScript logic classes (`RefCounted`) with no rendering dependencies.
  - Autoload singleton `Game` (`src/logic/game.gd`) as the single API entry point for scenes.
  - Economy and balance configuration (`src/logic/config.gd`).
  - Automated tests verifying rules headless.
- **Role B (Level & Data Lead):** Owns `src/levels/` and `docs/`.
  - Level data in pure JSON format (`res://src/levels/level_*.json`).
  - Puzzle design and documentation.
- **Role C (Rendering & UI Lead):** Owns `src/scenes/`, `src/ui/`, `assets/`.
  - Visuals, tilemaps, animations, camera, audio, HUD, and screen menus.
  - Connects strictly to `Game` autoload methods and signals. Never writes independent game logic.

---

## 2. Tech Stack & Rules

1. **Godot 4 Only:**
   - Syntax: Use `@onready`, `@export`, `await`, `signal.connect(callable)`.
   - FORBIDDEN: Godot 3 syntax (`onready var`, `export var`, `yield`, `connect("signal", self, "method")`).
2. **Decoupled Architecture:**
   - The game logic must run and pass tests without an active window or scene tree.
   - Game logic must NEVER import or reference Nodes, Sprites, or UI elements.

---

## 3. Level JSON Contract (Role B Owner)

Level files live in `res://src/levels/level_1.json`, `level_2.json`, etc.

### Keys Required:
```json
{
  "id": 1,
  "planet": "Moon",
  "startPoints": 30,
  "lives": 3,
  "gridSize": {"width": 9, "height": 3},
  "worldA": [
    "#########",
    "#POcS.FX#",
    "#########"
  ],
  "worldB": [
    "#########",
    "#PO.....#",
    "#########"
  ],
  "objects": [
    {
      "id": "spike_1",
      "type": "spike",
      "pos": {"x": 4, "y": 1},
      "twinId": "block_1"
    }
  ],
  "parts": 1,
  "portals": [
    {"x": 2, "y": 1}
  ],
  "puzzle": {
    "type": "push_block",
    "moveLimit": 10
  }
}
```

### Tile Legend:
- `#` : Wall (impassable)
- `.` : Floor (passable)
- `P` : Player spawn position
- `O` : Portal tile (switches between Dimension A and Dimension B)
- `c` : Energy cell pickup (+5 EP)
- `S` : Hazard / Spike (costs 1 life and 20 EP on touch)
- `F` : Ship part (objective item)
- `X` : Level exit portal (triggers level clear when all parts are collected)

---

## 4. Game State Contract (Dictionary schema)

Obtained via `Game.get_state()` and passed with `state_changed(state)`:

```gdscript
{
    "level_id": int,                 # Current level (1..4)
    "world": String,                 # "A" (Reality) or "B" (Source Layer)
    "player": {"x": int, "y": int},  # Grid position of Nova
    "points": int,                   # Current Energy Points (EP >= 0)
    "lives": int,                    # Remaining lives (0..3)
    "parts": {
        "collected": int,            # Ship parts collected in level
        "total": int                 # Ship parts required to exit
    },
    "objects": Array[Dictionary],    # Dynamic object instances and state
    "moves": int,                    # Turn / move counter
    "status": String                 # "playing", "won", "lost"
}
```

---

## 5. Game Autoload Public API (`src/logic/game.gd`)

### Actions (Methods):
- `load_level(id: int) -> bool`
- `move_player(direction: Vector2i) -> bool`
- `switch_world() -> bool`
- `use_skill(skill_name: String, target_id: String) -> bool`
- `reset_level() -> void`
- `get_state() -> Dictionary`

### Signals:
- `signal state_changed(state: Dictionary)`
- `signal points_changed(new_points: int, delta: int)`
- `signal player_died(lives_left: int, points_left: int)`
- `signal level_cleared(level_id: int, score_summary: Dictionary)`
- `signal game_over()`

---

## 6. Point Economy & Rules (`src/logic/config.gd`)

- **Starting values:** 30 EP, 3 lives per level.
- **Earn:**
  - B-world puzzle solved: `+25 EP`
  - Puzzle solved within move limit bonus: `+10 EP`
  - Energy cell pickup: `+5 EP`
  - Clear obstacle with skill: `+10 EP`
  - Ship part collected: `+30 EP`
  - Life remaining at level end: `+10 EP` per life
- **Spend:**
  - Delete skill (B): `-15 EP`
  - Duplicate skill (B): `-20 EP`
  - Move skill (B): `-10 EP`
  - Shield skill (A): `-10 EP`
- **Penalties:**
  - Death: `-20 EP`, `-1 life`, respawns at entry portal, prior edits remain.
  - Energy Points cannot drop below 0.
  - Running out of lives (0 lives) triggers `game_over` / restarts level.
