# Rift Runner

A 2D side-scrolling platformer built for the **Artificial Arcade — GlitchVerse (PS01)** hackathon.

## Engine

| | |
|---|---|
| **Engine** | Godot 4.7 (stable) |
| **Language** | GDScript only |
| **Renderer** | GL Compatibility |

Download Godot 4.7 stable from https://godotengine.org/download/

> ⚠️ Do **NOT** use Godot 3 syntax. Never use `onready var`, `export var`, `yield`, or the old `connect("signal", self, "method")` form. Use `@onready`, `@export`, `await`, and `signal.connect(callable)`.

## Team & Folder Ownership

| Role | Folders | Notes |
|------|---------|-------|
| **Role A** (Core Logic) | `src/logic/`, `project.godot` | No drawing code |
| **Role B** (Levels & Docs) | `src/levels/`, `docs/` | JSON level files |
| **Role C** (Scenes & UI) | `src/scenes/`, `src/ui/`, `assets/` | No logic |

Only the owner of a folder edits files inside it.

## Running the Project

1. Open Godot 4.3 (or 4.x stable).
2. Click **Import** → select the `project.godot` file in this repository.
3. Press **F5** (or the Play button) to run.

## Controls

| Key | Action |
|-----|--------|
| A / ← | Move left |
| D / → | Move right |
| Space / W | Jump |
| F | Switch dimension (A ↔ B) |
| 1 | Skill: Delete (B only, costs 15 EP) |
| 2 | Skill: Duplicate (B only, costs 20 EP) |
| 3 | Skill: Move (B only, costs 10 EP) |
| 4 | Skill: Shield (A only, costs 10 EP) |

## Sprite & Asset Pipeline

Source artwork is preprocessed using `tools/prep_sprite.py` into production-ready textures under `assets/art/world/`:
- **Energy Cell** (`assets/art/world/energy_cell.png`): Display size 30x44 with subtle vertical bobbing.
- **Ship Part** (`assets/art/world/ship_part.png`): Display size 96x56 with cyan glow pulse.
- **Exit Ship** (`assets/art/world/exit_ship.png`): Display size 280x112 with dynamic dimming until all ship parts are gathered.
- **Crate** (`assets/art/world/crate.png`): Display size 56x56.
- **Portal** (`assets/art/world/portal.png`): Display size 160x160 with scale breathing animation.
- **Hazard Spikes** (`assets/art/world/spike_tile.png`): Seamless 165x64 repeating tiles with hazard underglow.

## Project Structure

```
Glitchverse/
├── project.godot
├── icon.svg
├── src/
│   ├── logic/          # Role A — pure logic, no Node drawing
│   │   ├── config.gd
│   │   └── game.gd     # autoload "Game"
│   ├── levels/         # Role B — JSON level files (levels 1 to 4)
│   ├── scenes/         # Role C — .tscn + scene scripts (gameplay, etc.)
│   └── ui/             # Role C — HUD, menus
├── assets/
│   ├── art/            # Source and processed game art
│   │   └── world/      # Processed in-game textures
│   ├── sprites/        # Character & entity sprites
│   └── sounds/         # Audio SFX
├── tools/              # Sprite preparation & utility scripts
└── docs/
    ├── AI_CONTEXT.md
    └── level_budgets.md
```

## Commit cadence

One meaningful commit every ≤ 2 hours.
