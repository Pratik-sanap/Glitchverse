extends Node

## Game autoload singleton (res://src/logic/game.gd)
## Central bridge between UI/Scenes and decoupled core logic.

const ConfigScript = preload("res://src/logic/config.gd")
const LevelLoaderScript = preload("res://src/logic/level_loader.gd")
const GridSystemScript = preload("res://src/logic/grid_system.gd")
const SyncSystemScript = preload("res://src/logic/sync_system.gd")

signal state_changed(state: Dictionary)
signal points_changed(new_points: int, delta: int)
signal player_died(lives_left: int, points_left: int)
signal level_cleared(level_id: int, score_summary: Dictionary)
signal game_over()

# Loaded level definitions and mutable grid rows
var _current_level_data: Dictionary = {}
var _world_a_grid: Array = []
var _world_b_grid: Array = []
var _respawn_pos: Vector2i = Vector2i(0, 0)
var _has_shield: bool = false

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

	_current_level_data = data.duplicate(true)
	_world_a_grid = (_current_level_data["worldA"] as Array).duplicate(true)
	_world_b_grid = (_current_level_data["worldB"] as Array).duplicate(true)
	_has_shield = false

	var start_pos: Vector2i = LevelLoaderScript.find_player_start(_world_a_grid)
	if start_pos == Vector2i(-1, -1):
		printerr("[Game] Warning: No player start 'P' found in worldA, defaulting to (0, 0)")
		start_pos = Vector2i(0, 0)

	# Set respawn point: entry portal if present, else spawn 'P'
	if _current_level_data.has("portals") and (_current_level_data["portals"] as Array).size() > 0:
		var p0: Dictionary = _current_level_data["portals"][0]
		_respawn_pos = Vector2i(int(p0.get("x", start_pos.x)), int(p0.get("y", start_pos.y)))
	else:
		_respawn_pos = start_pos

	_state["level_id"] = int(data["id"])
	_state["world"] = "A"
	_state["player"] = {"x": start_pos.x, "y": start_pos.y}
	_state["points"] = int(data.get("startPoints", ConfigScript.STARTING_POINTS))
	_state["lives"] = int(data.get("lives", ConfigScript.STARTING_LIVES))
	_state["parts"] = {
		"collected": 0,
		"total": int(data.get("parts", 1))
	}
	_state["objects"] = (_current_level_data.get("objects", []) as Array).duplicate(true)
	_state["moves"] = 0
	_state["status"] = "playing"

	state_changed.emit(_state)
	return true

## Moves the player one tile on the grid, handles collisions, hazards, and monster turns.
func move_player(direction: Vector2i) -> bool:
	if _state.get("status", "") != "playing":
		return false

	var grid_size: Dictionary = _current_level_data.get("gridSize", {"width": 0, "height": 0})
	var current_pos: Vector2i = Vector2i(int(_state["player"]["x"]), int(_state["player"]["y"]))
	var target_pos: Vector2i = current_pos + direction

	# 1. Bounds check
	if not GridSystemScript.is_inside_grid(target_pos, grid_size):
		return false

	# 2. Wall check
	var active_grid: Array = _world_a_grid if _state["world"] == "A" else _world_b_grid
	var tile: String = GridSystemScript.get_tile_at(active_grid, target_pos)
	if not GridSystemScript.is_tile_walkable(tile):
		return false

	# 3. Apply player move and increment turn counter
	_state["player"]["x"] = target_pos.x
	_state["player"]["y"] = target_pos.y
	_state["moves"] += 1

	# 4. Check pickups at player destination
	_handle_pickups(target_pos, tile, active_grid)

	# 5. Check hazard immediately upon stepping (spikes/gaps/stationary monsters)
	if GridSystemScript.check_hazard_at(target_pos, tile, _state["objects"], _state["world"]):
		_handle_player_hit()
		state_changed.emit(_state)
		return true

	# 6. Monster turn: monsters advance one tile in Dimension A
	if _state["world"] == "A":
		GridSystemScript.advance_monsters(_state["objects"], _world_a_grid, grid_size)

		# 7. Check if a monster moved into player's cell
		var player_now: Vector2i = Vector2i(int(_state["player"]["x"]), int(_state["player"]["y"]))
		var tile_now: String = GridSystemScript.get_tile_at(_world_a_grid, player_now)
		if GridSystemScript.check_hazard_at(player_now, tile_now, _state["objects"], _state["world"]):
			_handle_player_hit()

	state_changed.emit(_state)
	return true

## Processes pickups: energy cells (+5 EP) and ship parts (+30 EP).
func _handle_pickups(pos: Vector2i, tile: String, active_grid: Array) -> void:
	if tile == "c":
		# Energy Cell pickup
		GridSystemScript.set_tile_at(active_grid, pos, ".")
		_state["points"] += ConfigScript.REWARD_ENERGY_CELL
		points_changed.emit(_state["points"], ConfigScript.REWARD_ENERGY_CELL)

	elif tile == "F" and _state["world"] == "A":
		# Ship Part pickup
		GridSystemScript.set_tile_at(active_grid, pos, ".")
		_state["parts"]["collected"] += 1
		_state["points"] += ConfigScript.REWARD_SHIP_PART
		points_changed.emit(_state["points"], ConfigScript.REWARD_SHIP_PART)

## Handles hazard damage, shield absorption, life loss, and respawning.
func _handle_player_hit() -> void:
	if _has_shield:
		# Shield blocks one hit and is consumed
		_has_shield = false
		print("[Game] Shield absorbed the hit!")
		return

	# Lose 1 life and 20 EP penalty (minimum 0)
	_state["lives"] = maxi(0, int(_state["lives"]) - 1)
	var prev_points: int = int(_state["points"])
	_state["points"] = maxi(0, prev_points - ConfigScript.PENALTY_DEATH)
	var delta: int = _state["points"] - prev_points

	# Respawn at entry portal
	_state["player"]["x"] = _respawn_pos.x
	_state["player"]["y"] = _respawn_pos.y

	player_died.emit(_state["lives"], _state["points"])
	if delta != 0:
		points_changed.emit(_state["points"], delta)

	if _state["lives"] <= 0:
		_state["status"] = "lost"
		game_over.emit()

## Switches between Dimension A (Reality) and Dimension B (Source Layer).
## Allowed when player stands on a portal tile 'O' or when force is true.
func switch_world(force: bool = false) -> bool:
	var player_pos: Vector2i = Vector2i(int(_state["player"]["x"]), int(_state["player"]["y"]))
	var portals: Array = _current_level_data.get("portals", [])
	var active_grid: Array = _world_a_grid if _state["world"] == "A" else _world_b_grid

	if not force and not SyncSystemScript.is_on_portal(player_pos, portals, active_grid):
		return false

	_state["world"] = "B" if _state["world"] == "A" else "A"
	state_changed.emit(_state)
	return true

## Synchronizes a Delete edit from Dimension B to its twin in Dimension A.
func sync_delete(target_id: String) -> bool:
	var ok: bool = SyncSystemScript.sync_delete(_state["objects"], target_id, _world_a_grid)
	if ok:
		state_changed.emit(_state)
	return ok

## Synchronizes a Move edit from Dimension B to its twin in Dimension A.
func sync_move(target_id: String, new_pos: Vector2i) -> bool:
	var ok: bool = SyncSystemScript.sync_move(_state["objects"], target_id, new_pos)
	if ok:
		state_changed.emit(_state)
	return ok

## Synchronizes a Duplicate edit from Dimension B to its twin in Dimension A.
func sync_duplicate(target_id: String, new_pos: Vector2i) -> Dictionary:
	var created: Dictionary = SyncSystemScript.sync_duplicate(_state["objects"], target_id, new_pos, _world_a_grid)
	if not created.is_empty():
		state_changed.emit(_state)
	return created

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
	return _state.duplicate(true)

func get_current_level_data() -> Dictionary:
	return _current_level_data

func set_shield(active: bool) -> void:
	_has_shield = active

func has_shield() -> bool:
	return _has_shield
