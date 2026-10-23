extends SceneTree

## Headless Test Runner for Rift Runner logic.
## Can be executed directly with:
## cmd.exe /c "D:\Godot_v4.7.2-stable_win64.exe --headless -s res://src/logic/test_runner.gd"

const LevelLoader = preload("res://src/logic/level_loader.gd")
const Config = preload("res://src/logic/config.gd")
const GameScript = preload("res://src/logic/game.gd")
const GridSystem = preload("res://src/logic/grid_system.gd")
const SyncSystem = preload("res://src/logic/sync_system.gd")
const SkillSystem = preload("res://src/logic/skill_system.gd")
const PuzzleSystem = preload("res://src/logic/puzzle_system.gd")

func _init() -> void:
	print("========================================")
	print("       RUNNING LOGIC TESTS: STEP 6      ")
	print("========================================")
	var passed: int = 0
	var failed: int = 0

	# Regression Tests
	if test_valid_level_json():
		print("[PASS] Test 1: Valid level JSON parsed and validated.")
		passed += 1
	else:
		printerr("[FAIL] Test 1: Valid level JSON failed.")
		failed += 1

	if test_player_walkable_movement():
		print("[PASS] Test 2: Player moves correctly on walkable floor.")
		passed += 1
	else:
		printerr("[FAIL] Test 2: Player movement on walkable floor failed.")
		failed += 1

	if test_portal_transit_success():
		print("[PASS] Test 3: switch_world() on portal 'O' transitions between A and B.")
		passed += 1
	else:
		printerr("[FAIL] Test 3: World switch on portal failed.")
		failed += 1

	if test_delete_skill_in_dimension_b():
		print("[PASS] Test 4: Delete in Dimension B costs 15 EP and awards 10 EP for obstacle.")
		passed += 1
	else:
		printerr("[FAIL] Test 4: Delete skill in Dimension B failed.")
		failed += 1

	# Step 6 Points and Lives Tests
	if test_puzzle_reward_with_bonus():
		print("[PASS] Test 5: Solving B puzzle within move limit awards +35 EP (+25 base, +10 bonus).")
		passed += 1
	else:
		printerr("[FAIL] Test 5: Puzzle reward with move bonus failed.")
		failed += 1

	if test_puzzle_reward_without_bonus():
		print("[PASS] Test 6: Solving B puzzle after move limit awards base +25 EP only.")
		passed += 1
	else:
		printerr("[FAIL] Test 6: Puzzle reward without bonus failed.")
		failed += 1

	if test_points_never_below_zero_on_death():
		print("[PASS] Test 7: Death penalty clamps points at 0 (never negative).")
		passed += 1
	else:
		printerr("[FAIL] Test 7: Points fell below 0 on death.")
		failed += 1

	if test_death_preserves_edits():
		print("[PASS] Test 8: Death respawns Nova at portal but keeps previous edits intact.")
		passed += 1
	else:
		printerr("[FAIL] Test 8: Edits were lost upon player death.")
		failed += 1

	if test_zero_lives_restarts_level():
		print("[PASS] Test 9: Losing all 3 lives restarts level with initial points and 3 lives.")
		passed += 1
	else:
		printerr("[FAIL] Test 9: Level restart on 0 lives failed.")
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
			"#POT....#",
			"#########"
		],
		"objects": [
			{
				"id": "spike_1",
				"type": "spike",
				"pos": {"x": 4, "y": 1},
				"world": "A",
				"twinId": "block_1"
			},
			{
				"id": "block_1",
				"type": "block",
				"pos": {"x": 4, "y": 1},
				"world": "B",
				"twinId": "spike_1"
			}
		],
		"parts": 1,
		"portals": [
			{"x": 2, "y": 1}
		],
		"puzzle": {
			"type": "push_block",
			"moveLimit": 5,
			"targetPos": {"x": 3, "y": 1}
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

func test_player_walkable_movement() -> bool:
	var g: Node = _create_game_instance()
	var ok: bool = g.move_player(Vector2i(1, 0))
	var state: Dictionary = g.get_state()
	var success: bool = ok and state["player"]["x"] == 2 and state["player"]["y"] == 1 and state["moves"] == 1
	g.free()
	return success

func test_portal_transit_success() -> bool:
	var g: Node = _create_game_instance()
	g.move_player(Vector2i(1, 0))
	var ok_to_b: bool = g.switch_world()
	var state_b: Dictionary = g.get_state()
	var ok_to_a: bool = g.switch_world()
	var state_a: Dictionary = g.get_state()

	var success: bool = ok_to_b and state_b["world"] == "B" and ok_to_a and state_a["world"] == "A"
	g.free()
	return success

func test_delete_skill_in_dimension_b() -> bool:
	var g: Node = _create_game_instance()
	g.move_player(Vector2i(1, 0))
	g.switch_world()
	var ok: bool = g.use_skill("delete", "block_1")
	var state: Dictionary = g.get_state()

	var success: bool = ok and state["points"] == 25
	g.free()
	return success

func test_puzzle_reward_with_bonus() -> bool:
	var g: Node = _create_game_instance()
	# Starts at 30 EP. Moves = 0 (within moveLimit 5).
	# Solve puzzle -> +25 base + 10 bonus = +35 EP (total 65 EP)
	var ok: bool = g.solve_b_puzzle()
	var state: Dictionary = g.get_state()

	var success: bool = ok and state["points"] == 65 and g.is_puzzle_solved()
	g.free()
	return success

func test_puzzle_reward_without_bonus() -> bool:
	var g: Node = _create_game_instance()
	# Set moves to 6 (exceeds moveLimit 5)
	g._state["moves"] = 6
	var ok: bool = g.solve_b_puzzle()
	var state: Dictionary = g.get_state()

	# Base reward only: 30 + 25 = 55 EP
	var success: bool = ok and state["points"] == 55 and g.is_puzzle_solved()
	g.free()
	return success

func test_points_never_below_zero_on_death():
	var g: Node = _create_game_instance()
	# Set player points to 10 (death penalty is 20)
	g._state["points"] = 10
	# Trigger death by hitting spike at (4, 1)
	g.move_player(Vector2i(1, 0)) # (2, 1)
	g.move_player(Vector2i(1, 0)) # (3, 1) cell pickup -> +5 EP (total 15)
	# Set back to 10 to ensure penalty (20) exceeds points
	g._state["points"] = 10
	g.move_player(Vector2i(1, 0)) # (4, 1) spike hit!

	var state: Dictionary = g.get_state()
	# Points must clamp at 0, not -10
	var success: bool = state["points"] == 0 and state["lives"] == 2
	g.free()
	return success

func test_death_preserves_edits():
	var g: Node = _create_game_instance()
	# Switch to B and duplicate block_1
	g.move_player(Vector2i(1, 0))
	g.switch_world()
	g.use_skill("duplicate", "block_1", Vector2i(5, 1))
	var obj_count_after_dup: int = g.get_state()["objects"].size() # 4 objects

	# Switch back to A and take a death hit
	g.switch_world()
	g.move_player(Vector2i(1, 0)) # (3, 1)
	g.move_player(Vector2i(1, 0)) # (4, 1) spike hit!

	var state_after_death: Dictionary = g.get_state()
	# Edits MUST stay! Object count remains 4, lives = 2, respawned at portal (2, 1)
	var success: bool = (
		state_after_death["lives"] == 2 and
		state_after_death["player"]["x"] == 2 and
		state_after_death["player"]["y"] == 1 and
		state_after_death["objects"].size() == obj_count_after_dup
	)
	g.free()
	return success

func test_zero_lives_restarts_level():
	var g: Node = _create_game_instance()
	# Nova has 3 lives. Let's lose all 3 lives:
	# Death 1:
	g.move_player(Vector2i(1, 0))
	g.move_player(Vector2i(1, 0))
	g.move_player(Vector2i(1, 0)) # Dies, respawns at (2, 1), lives = 2

	# Death 2:
	g.move_player(Vector2i(1, 0)) # (3, 1)
	g.move_player(Vector2i(1, 0)) # Dies, respawns at (2, 1), lives = 1

	# Death 3:
	g.move_player(Vector2i(1, 0)) # (3, 1)
	g.move_player(Vector2i(1, 0)) # Dies -> lives reach 0! Triggers reset_level()

	var state_after_restart: Dictionary = g.get_state()
	# Level is re-initialized: lives back to 3, points back to starting 30
	var success: bool = (
		state_after_restart["lives"] == 3 and
		state_after_restart["points"] == 30 and
		state_after_restart["status"] == "playing"
	)
	g.free()
	return success
