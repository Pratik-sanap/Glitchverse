extends SceneTree

## Headless Test Runner for Rift Runner logic.
## Can be executed directly with:
## godot --headless -s res://src/logic/test_runner.gd

const LevelLoader = preload("res://src/logic/level_loader.gd")
const Config = preload("res://src/logic/config.gd")
const GameScript = preload("res://src/logic/game.gd")
const GridSystem = preload("res://src/logic/grid_system.gd")

func _init() -> void:
	print("========================================")
	print("       RUNNING LOGIC TESTS: STEP 3      ")
	print("========================================")
	var passed: int = 0
	var failed: int = 0

	# Step 2 Regression Tests
	if test_valid_level_json():
		print("[PASS] Test 1: Valid level JSON parsed and validated.")
		passed += 1
	else:
		printerr("[FAIL] Test 1: Valid level JSON failed.")
		failed += 1

	if test_missing_keys():
		print("[PASS] Test 2: Incomplete JSON correctly rejected.")
		passed += 1
	else:
		printerr("[FAIL] Test 2: Incomplete JSON was not rejected.")
		failed += 1

	if test_find_player_start():
		print("[PASS] Test 3: Player start 'P' found at expected coordinates.")
		passed += 1
	else:
		printerr("[FAIL] Test 3: Player start coordinate extraction failed.")
		failed += 1

	# Step 3 Grid and Turn Tests
	if test_player_walkable_movement():
		print("[PASS] Test 4: Player moves correctly on walkable floor.")
		passed += 1
	else:
		printerr("[FAIL] Test 4: Player movement on walkable floor failed.")
		failed += 1

	if test_player_wall_collision():
		print("[PASS] Test 5: Wall correctly blocks player movement.")
		passed += 1
	else:
		printerr("[FAIL] Test 5: Wall collision failed to block.")
		failed += 1

	if test_player_spike_hazard():
		print("[PASS] Test 6: Stepping on spike loses 1 life and 20 EP, respawns at portal.")
		passed += 1
	else:
		printerr("[FAIL] Test 6: Spike hazard penalty failed.")
		failed += 1

	if test_monster_patrol_turn():
		print("[PASS] Test 7: Monster moves one tile after player turn.")
		passed += 1
	else:
		printerr("[FAIL] Test 7: Monster patrol turn failed.")
		failed += 1

	if test_shield_blocks_hit():
		print("[PASS] Test 8: Shield absorbs hazard hit without losing life or points.")
		passed += 1
	else:
		printerr("[FAIL] Test 8: Shield hit absorption failed.")
		failed += 1

	print("========================================")
	print("RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("========================================")

	quit(0 if failed == 0 else 1)

func _get_sample_valid_json() -> String:
	return """
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
				"id": "monster_1",
				"type": "monster",
				"pos": {"x": 5, "y": 1},
				"patrol": [{"x": 5, "y": 1}, {"x": 6, "y": 1}],
				"patrol_index": 0,
				"patrol_dir": 1
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
	"""

func _create_game_instance() -> Node:
	var g = GameScript.new()
	var data: Dictionary = LevelLoader.parse_and_validate(_get_sample_valid_json())
	g.load_level_from_data(data)
	return g

func test_valid_level_json() -> bool:
	var data: Dictionary = LevelLoader.parse_and_validate(_get_sample_valid_json())
	return not data.is_empty() and data["planet"] == "Moon" and data["startPoints"] == 30

func test_missing_keys() -> bool:
	var data: Dictionary = LevelLoader.parse_and_validate('{"id": 1}')
	return data.is_empty()

func test_find_player_start() -> bool:
	var world_a: Array = [
		"#########",
		"#POcS.FX#",
		"#########"
	]
	var pos: Vector2i = LevelLoader.find_player_start(world_a)
	return pos == Vector2i(1, 1)

func test_player_walkable_movement() -> bool:
	var g: Node = _create_game_instance()
	# Spawn at (1, 1), move right to (2, 1) which is 'O' (portal tile, walkable)
	var ok: bool = g.move_player(Vector2i(1, 0))
	var state: Dictionary = g.get_state()
	var success: bool = ok and state["player"]["x"] == 2 and state["player"]["y"] == 1 and state["moves"] == 1
	g.free()
	return success

func test_player_wall_collision() -> bool:
	var g: Node = _create_game_instance()
	# Spawn at (1, 1), move up to (1, 0) which is wall '#'
	var ok: bool = g.move_player(Vector2i(0, -1))
	var state: Dictionary = g.get_state()
	# Movement should be rejected, player stays at (1, 1), moves counter stays 0
	var success: bool = not ok and state["player"]["x"] == 1 and state["player"]["y"] == 1 and state["moves"] == 0
	g.free()
	return success

func test_player_spike_hazard() -> bool:
	var g: Node = _create_game_instance()
	# Level layout row 1: # P O c S . F X #
	# P is (1, 1), O is (2, 1), c is (3, 1), S is (4, 1)
	# Move right to (2, 1)
	g.move_player(Vector2i(1, 0))
	# Move right to (3, 1) -> collects energy cell (+5 EP)
	g.move_player(Vector2i(1, 0))
	var points_before: int = g.get_state()["points"] # 30 + 5 = 35

	# Move right to (4, 1) -> stepping on Spike 'S'!
	g.move_player(Vector2i(1, 0))
	var state: Dictionary = g.get_state()

	# Hazard should cost 1 life, 20 EP penalty (35 - 20 = 15), and respawn at entry portal (2, 1)
	var success: bool = (
		state["lives"] == 2 and
		state["points"] == (points_before - Config.PENALTY_DEATH) and
		state["player"]["x"] == 2 and
		state["player"]["y"] == 1
	)
	g.free()
	return success

func test_monster_patrol_turn() -> bool:
	var g: Node = _create_game_instance()
	# Monster begins at (5, 1) with patrol [(5, 1), (6, 1)]
	# Player makes one valid move (1, 1) -> (2, 1)
	g.move_player(Vector2i(1, 0))
	var state: Dictionary = g.get_state()

	# Monster should have advanced 1 step to (6, 1)
	var monster: Dictionary = state["objects"][0]
	var success: bool = (int(monster["pos"]["x"]) == 6 and int(monster["pos"]["y"]) == 1)
	g.free()
	return success

func test_shield_blocks_hit() -> bool:
	var g: Node = _create_game_instance()
	g.set_shield(true)

	# Move to (2, 1), (3, 1), and then step onto Spike (4, 1)
	g.move_player(Vector2i(1, 0))
	g.move_player(Vector2i(1, 0))
	var points_before: int = g.get_state()["points"]
	var lives_before: int = g.get_state()["lives"]

	g.move_player(Vector2i(1, 0)) # Hit spike
	var state: Dictionary = g.get_state()

	# Shield must absorb hit: lives and points remain unchanged, shield consumed
	var success: bool = (
		state["lives"] == lives_before and
		state["points"] == points_before and
		not g.has_shield()
	)
	g.free()
	return success
