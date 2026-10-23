extends Node

## Game autoload singleton (res://src/logic/game.gd)
## Central bridge between UI/Scenes and the decoupled core logic.

signal state_changed(state: Dictionary)
signal points_changed(new_points: int, delta: int)
signal player_died(lives_left: int, points_left: int)
signal level_cleared(level_id: int, score_summary: Dictionary)
signal game_over()

# Current game state dictionary adhering to the contract
var _state: Dictionary = {
	"level_id": 1,
	"world": "A",
	"player": {"x": 0, "y": 0},
	"points": Config.STARTING_POINTS,
	"lives": Config.STARTING_LIVES,
	"parts": {
		"collected": 0,
		"total": 1
	},
	"objects": [],
	"moves": 0,
	"status": "playing" # "playing", "won", "lost"
}

func _ready() -> void:
	print("[Game] Autoload initialized successfully.")

func load_level(id: int) -> bool:
	# Detailed implementation will be added in Step 2 (Level Loader)
	_state["level_id"] = id
	_state["moves"] = 0
	_state["points"] = Config.STARTING_POINTS
	_state["lives"] = Config.STARTING_LIVES
	_state["status"] = "playing"
	state_changed.emit(_state)
	return true

func move_player(direction: Vector2i) -> bool:
	# Detailed grid and hazard resolution added in Step 3
	_state["moves"] += 1
	state_changed.emit(_state)
	return true

func switch_world() -> bool:
	# Dimension switching logic added in Step 4
	_state["world"] = "B" if _state["world"] == "A" else "A"
	state_changed.emit(_state)
	return true

func use_skill(skill_name: String, target_id: String) -> bool:
	# Skill validation and state mutation added in Step 5
	state_changed.emit(_state)
	return true

func reset_level() -> void:
	load_level(_state["level_id"])

func get_state() -> Dictionary:
	return _state
