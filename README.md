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

1. Open Godot 4.3.
2. Click **Import** → select `d:/Glitchverse/project.godot`.
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

## Project Structure

```
Glitchverse/
├── project.godot
├── icon.svg
├── src/
│   ├── logic/          # Role A — pure logic, no Node drawing
│   │   ├── config.gd
│   │   └── game.gd     # autoload "Game"
│   ├── levels/         # Role B — JSON level files
│   ├── scenes/         # Role C — .tscn + scene scripts
│   └── ui/             # Role C — HUD, menus
├── assets/
│   ├── sprites/
│   └── sounds/
└── docs/
    └── AI_CONTEXT.md
```

## Commit cadence

One meaningful commit every ≤ 2 hours.
