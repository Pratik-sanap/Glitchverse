extends Node

## Game autoload singleton (res://src/logic/game.gd)
## Central bridge between UI/Scenes and decoupled core logic.

const ConfigScript = preload("res://src/logic/config.gd")
const LevelLoaderScript = preload("res://src/logic/level_loader.gd")

signal state_changed(state: Dictionary)
signal points_changed(new_points: int, delta: int)
signal player_died(lives_left: int, points_left: int)
signal level_cleared(level_id: int, score_summary: Dictionary)
signal game_over()

# Loaded level definitions and grid configuration
var _current_level_data: Dictionary = {}

# Current game state dictionary adhering strictly to the contract
var _state: Dictionary = {
	"level_id": 1,
	"world": "A",
	"player": {"x": 0, "y": 0},
	"points": ConfigScript.STARTING_POINTS,
	"lives": ConfigScript.STARTING_LIVES,
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

## Loads a level by ID from res://src/levels/level_<id>.json
func load_level(id: int) -> bool:
	var path: String = LevelLoaderScript.get_level_path(id)
	var data: Dictionary = LevelLoaderScript.load_from_file(path)
	if data.is_empty():
		printerr("[Game] Unable to load level file: ", path)
		return false

	return load_level_from_data(data)

## Initializes game state from a validated level dictionary
func load_level_from_data(data: Dictionary) -> bool:
	if not LevelLoaderScript.validate_schema(data):
		printerr("[Game] Level data failed schema validation.")
		return false

	_current_level_data = data

	var start_pos: Vector2i = LevelLoaderScript.find_player_start(data["worldA"])
	if start_pos == Vector2i(-1, -1):
		printerr("[Game] Warning: No player start 'P' found in worldA, defaulting to (0, 0)")
		start_pos = Vector2i(0, 0)

	_state["level_id"] = int(data["id"])
	_state["world"] = "A"
	_state["player"] = {"x": start_pos.x, "y": start_pos.y}
	_state["points"] = int(data.get("startPoints", ConfigScript.STARTING_POINTS))
	_state["lives"] = int(data.get("lives", ConfigScript.STARTING_LIVES))
	_state["parts"] = {
		"collected": 0,
		"total": int(data.get("parts", 1))
	}
	_state["objects"] = (data.get("objects", []) as Array).duplicate(true)
	_state["moves"] = 0
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
	if not _current_level_data.is_empty():
		load_level_from_data(_current_level_data)
	else:
		load_level(int(_state.get("level_id", 1)))

func get_state() -> Dictionary:
	return _state

func get_current_level_data() -> Dictionary:
	return _current_level_data
