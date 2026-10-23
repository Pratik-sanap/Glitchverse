# Rift Runner (GlitchVerse — PS01)

A 2D, turn-based, grid-based puzzle & adventure game built with **Godot 4** for the 24-hour Artificial Arcade hackathon.

## Engine Version
- **Godot Engine:** `4.7` (Standard 64-bit GDScript)
- *Note:* Godot 4.x GDScript standard.

---

## Team Roles & Ownership

| Role | Name / Lead | Owned Folders & Files | Responsibilities |
|---|---|---|---|
| **Role A** | Core Logic Lead | `src/logic/`, `project.godot` | Game rules, state machine, economy, decoupled autoload (`Game`), test scripts |
| **Role B** | Level & Data Lead | `src/levels/`, `docs/` | 4 Level JSONs, balance, mechanics documentation, puzzle setups |
| **Role C** | Rendering & UI Lead | `src/scenes/`, `src/ui/`, `assets/` | 2D tilemaps, character rendering, HUD, audio, screens |

---

## Project Structure
```text
Glitchverse/
├── project.godot          # Master Godot 4 project configuration (Role A)
├── .gitignore             # Godot 4 ignore rules (Role A)
├── README.md              # Project overview & engine specs
├── docs/
│   └── AI_CONTEXT.md      # Shared contract & architectural agreement for all AI agents
├── src/
│   ├── logic/             # Pure GDScript logic & RefCounted rules (Role A)
│   │   ├── config.gd      # Costs, rewards, starting values
│   │   └── game.gd        # Autoload Node singleton bridge
│   ├── levels/            # Level JSON data files (Role B)
│   ├── scenes/            # World & level scenes (Role C)
│   │   └── main.tscn      # Empty main scene
│   └── ui/                # HUD & UI menus (Role C)
└── assets/                # Audio, fonts, sprite assets (Role C)
```

---

## How to Open and Run

1. Download and launch **Godot 4.7 Standard**.
2. Click **Import**, navigate to `d:\Glitchverse`, select `project.godot`, and click **Import & Edit**.
3. Press **F5** (or the Play button at the top right) to run the project.
   - It will run `res://src/scenes/main.tscn`.
   - The Output panel at the bottom will log:
     ```text
     [Game] Autoload initialized successfully.
     ```
