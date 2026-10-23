extends SceneTree

## Headless Test Runner for Rift Runner logic.
## Can be executed directly with:
## godot --headless -s res://src/logic/test_runner.gd

const LevelLoader = preload("res://src/logic/level_loader.gd")
const Config = preload("res://src/logic/config.gd")
const GameScript = preload("res://src/logic/game.gd")

func _init() -> void:
	print("========================================")
	print("       RUNNING LOGIC TESTS: STEP 2      ")
	print("========================================")
	var passed: int = 0
	var failed: int = 0

	# Test 1: Valid level JSON parsing and schema validation
	if test_valid_level_json():
		print("[PASS] Test 1: Valid level JSON parsed and validated.")
		passed += 1
	else:
		printerr("[FAIL] Test 1: Valid level JSON failed.")
		failed += 1

	# Test 2: Schema rejection on missing keys
	if test_missing_keys():
		print("[PASS] Test 2: Incomplete JSON correctly rejected.")
		passed += 1
	else:
		printerr("[FAIL] Test 2: Incomplete JSON was not rejected.")
		failed += 1

	# Test 3: Schema rejection on mismatched grid dimensions
	if test_mismatched_grid():
		print("[PASS] Test 3: Mismatched grid dimensions correctly rejected.")
		passed += 1
	else:
		printerr("[FAIL] Test 3: Mismatched grid dimensions were not rejected.")
		failed += 1

	# Test 4: Find player start 'P' coordinate
	if test_find_player_start():
		print("[PASS] Test 4: Player start 'P' found at expected coordinates.")
		passed += 1
	else:
		printerr("[FAIL] Test 4: Player start coordinate extraction failed.")
		failed += 1

	# Test 5: Game state hydration from LevelLoader
	if test_game_autoload_hydration():
		print("[PASS] Test 5: Game autoload state properly initialized from level data.")
		passed += 1
	else:
		printerr("[FAIL] Test 5: Game state hydration failed.")
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
	"""

func test_valid_level_json() -> bool:
	var data: Dictionary = LevelLoader.parse_and_validate(_get_sample_valid_json())
	if data.is_empty():
		return false
	if data["planet"] != "Moon":
		return false
	if data["startPoints"] != 30:
		return false
	if data["objects"].size() != 1:
		return false
	return true

func test_missing_keys() -> bool:
	var invalid_json: String = '{"id": 1, "planet": "Moon"}'
	var data: Dictionary = LevelLoader.parse_and_validate(invalid_json)
	return data.is_empty()

func test_mismatched_grid() -> bool:
	var bad_grid_json: String = """
	{
		"id": 1,
		"planet": "Moon",
		"startPoints": 30,
		"lives": 3,
		"gridSize": {"width": 9, "height": 3},
		"worldA": [
			"#########",
			"#POcS.FX"
		],
		"worldB": [
			"#########",
			"#PO.....#"
		],
		"objects": [],
		"parts": 1,
		"portals": [],
		"puzzle": {"type": "push_block", "moveLimit": 10}
	}
	"""
	var data: Dictionary = LevelLoader.parse_and_validate(bad_grid_json)
	return data.is_empty()

func test_find_player_start() -> bool:
	var world_a: Array = [
		"#########",
		"#POcS.FX#",
		"#########"
	]
	var pos: Vector2i = LevelLoader.find_player_start(world_a)
	# 'P' is at index 1 in row 1 -> (1, 1)
	return pos == Vector2i(1, 1)

func test_game_autoload_hydration() -> bool:
	var data: Dictionary = LevelLoader.parse_and_validate(_get_sample_valid_json())
	if data.is_empty():
		return false

	var game_node = root.get_node_or_null("Game")
	var cleanup: bool = false
	if not game_node:
		game_node = GameScript.new()
		cleanup = true

	var ok: bool = game_node.load_level_from_data(data)
	if not ok:
		if cleanup:
			game_node.free()
		return false

	var state: Dictionary = game_node.get_state()
	var valid: bool = true
	if state["level_id"] != 1:
		valid = false
	elif state["world"] != "A":
		valid = false
	elif state["player"]["x"] != 1 or state["player"]["y"] != 1:
		valid = false
	elif state["points"] != 30:
		valid = false
	elif state["lives"] != 3:
		valid = false
	elif state["parts"]["total"] != 1 or state["parts"]["collected"] != 0:
		valid = false
	elif state["status"] != "playing":
		valid = false

	if cleanup:
		game_node.free()

	return valid
