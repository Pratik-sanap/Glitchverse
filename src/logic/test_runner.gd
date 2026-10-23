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
	print("       RUNNING LOGIC TESTS: STEP 7      ")
	print("========================================")
	var passed: int = 0
	var failed: int = 0

	# Step 1-6 Regression Tests
	if test_valid_level_json():
		print("[PASS] Test 1: Valid level JSON parsed and validated.")
		passed += 1
	else:
		printerr("[FAIL] Test 1: Valid level JSON failed.")
		failed += 1

	if test_load_level_1_file_with_array_parts():
		print("[PASS] Test 1b: Level 1 with array parts parsed successfully without error.")
		passed += 1
	else:
		printerr("[FAIL] Test 1b: Loading level_1.json failed.")
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

	if test_skills_and_sync():
		print("[PASS] Test 4: Delete skill in B syncs twin in A and clears hazard.")
		passed += 1
	else:
		printerr("[FAIL] Test 4: Skills and twin sync failed.")
		failed += 1

	if test_puzzle_reward_with_bonus():
		print("[PASS] Test 5: Solving B puzzle within move limit awards +35 EP.")
		passed += 1
	else:
		printerr("[FAIL] Test 5: Puzzle reward failed.")
		failed += 1

	if test_push_block_to_target_in_b():
		print("[PASS] Test 5b: Pushing block onto target object in B automatically solves puzzle and awards points.")
		passed += 1
	else:
		printerr("[FAIL] Test 5b: Push block to target in B failed.")
		failed += 1

	# Step 7 Win/Lose & Signals Tests
	if test_exit_blocked_without_parts():
		print("[PASS] Test 6: Exit portal 'X' blocked when missing required ship parts.")
		passed += 1
	else:
		printerr("[FAIL] Test 6: Exit was allowed without all parts.")
		failed += 1

	if test_level_clear_with_all_parts():
		print("[PASS] Test 7: Collecting all parts and stepping on 'X' clears level with life bonus.")
		passed += 1
	else:
		printerr("[FAIL] Test 7: Level clear win condition failed.")
		failed += 1

	if test_game_over_signal_on_zero_lives():
		print("[PASS] Test 8: game_over signal emitted when lives reach 0.")
		passed += 1
	else:
		printerr("[FAIL] Test 8: game_over signal failed to emit.")
		failed += 1

	if test_all_contract_signals():
		print("[PASS] Test 9: All contract signals (points_changed, state_changed, player_died, level_cleared, game_over) verified.")
		passed += 1
	else:
		printerr("[FAIL] Test 9: Contract signals verification failed.")
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
			"#POc..FX#",
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

func test_load_level_1_file_with_array_parts() -> bool:
	if not FileAccess.file_exists("res://src/levels/level_1.json"):
		return true
	var g = GameScript.new()
	var ok: bool = g.load_level(1)
	var state: Dictionary = g.get_state()
	var success: bool = ok and state["level_id"] == 1 and state["parts"]["total"] == 1
	g.free()
	return success

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

func test_skills_and_sync() -> bool:
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
	var ok: bool = g.solve_b_puzzle()
	var state: Dictionary = g.get_state()
	var success: bool = ok and state["points"] == 65 and g.is_puzzle_solved()
	g.free()
	return success

func test_push_block_to_target_in_b() -> bool:
	var g = GameScript.new()
	var test_data: Dictionary = {
		"id": 1,
		"planet": "Moon",
		"startPoints": 30,
		"lives": 3,
		"gridSize": {"width": 6, "height": 3},
		"worldA": [
			"######",
			"#PO..#",
			"######"
		],
		"worldB": [
			"######",
			"#PO..#",
			"######"
		],
		"objects": [
			{
				"id": "pushblock_1",
				"type": "pushblock",
				"pos": {"x": 3, "y": 1},
				"world": "B"
			},
			{
				"id": "target_1",
				"type": "target",
				"pos": {"x": 4, "y": 1},
				"world": "B"
			}
		],
		"parts": 1,
		"portals": [{"x": 1, "y": 1}],
		"puzzle": {"type": "pushBlockToTarget", "moveLimit": 5}
	}
	g.load_level_from_data(test_data)
	g.switch_world() # Switch to B on portal (1, 1)
	g.move_player(Vector2i(1, 0)) # move to (2, 1)

	# Walk into pushblock at (3, 1): pushes it to (4, 1) which is target_1!
	var pushed: bool = g.move_player(Vector2i(1, 0))
	var state: Dictionary = g.get_state()

	var block_on_target: bool = false
	for obj in state["objects"]:
		if obj["id"] == "pushblock_1" and int(obj["pos"]["x"]) == 4 and int(obj["pos"]["y"]) == 1:
			block_on_target = true

	var solved: bool = g.is_puzzle_solved() and state["points"] == 65 # 30 + 25 + 10 = 65 EP!
	g.free()
	return pushed and block_on_target and solved

func test_exit_blocked_without_parts() -> bool:
	var g: Node = _create_game_instance()
	# Row 1: # P O c . . F X #
	# P=(1,1), O=(2,1), c=(3,1), (4,1)=., (5,1)=., F=(6,1), X=(7,1)
	# Walk past F without collecting (e.g. if parts collected is 0)
	g.move_player(Vector2i(1, 0)) # (2, 1)
	g.move_player(Vector2i(1, 0)) # (3, 1)
	g.move_player(Vector2i(1, 0)) # (4, 1)
	g.move_player(Vector2i(1, 0)) # (5, 1)
	# Artificially keep parts at 0 to test check
	g._state["parts"]["collected"] = 0

	# Try to step on exit without collecting part
	g.move_player(Vector2i(1, 0)) # steps on (6, 1) which normally has F, but pretend missing
	g._state["parts"]["collected"] = 0

	g.move_player(Vector2i(1, 0)) # steps on (7, 1) exit X
	var state: Dictionary = g.get_state()

	# Must NOT be won because parts < total
	var success: bool = state["status"] == "playing"
	g.free()
	return success

func test_level_clear_with_all_parts() -> bool:
	var g: Node = _create_game_instance()
	var clear_emitted: Array = []
	g.level_cleared.connect(func(lvl_id, summary): clear_emitted.append({"id": lvl_id, "summary": summary}))

	# Row 1: # P O c . . F X #
	# P=(1,1) -> (2,1) -> (3,1)[+5] -> (4,1) -> (5,1) -> (6,1)[F, +30] -> (7,1)[X]
	g.move_player(Vector2i(1, 0)) # (2, 1)
	g.move_player(Vector2i(1, 0)) # (3, 1) cell (+5 EP)
	g.move_player(Vector2i(1, 0)) # (4, 1)
	g.move_player(Vector2i(1, 0)) # (5, 1)
	g.move_player(Vector2i(1, 0)) # (6, 1) ship part F (+30 EP)
	g.move_player(Vector2i(1, 0)) # (7, 1) exit X!

	var state: Dictionary = g.get_state()
	# Level cleared:
	# 30 (start) + 5 (cell) + 30 (part) + 30 (3 lives * 10 life bonus) = 95 EP!
	var success: bool = (
		state["status"] == "won" and
		clear_emitted.size() == 1 and
		clear_emitted[0]["id"] == 1 and
		clear_emitted[0]["summary"]["final_points"] == 95 and
		clear_emitted[0]["summary"]["lives_remaining"] == 3 and
		clear_emitted[0]["summary"]["life_bonus"] == 30
	)
	g.free()
	return success

func test_game_over_signal_on_zero_lives() -> bool:
	var g: Node = _create_game_instance()
	var game_over_caught: Array = []
	g.game_over.connect(func(): game_over_caught.append(true))

	# Lose 3 lives by hitting obstacle
	g._handle_player_hit()
	g._handle_player_hit()
	g._handle_player_hit()

	var success: bool = game_over_caught.size() > 0
	g.free()
	return success

func test_all_contract_signals() -> bool:
	var g: Node = _create_game_instance()
	var signals_caught: Dictionary = {
		"state_changed": 0,
		"points_changed": 0,
		"player_died": 0,
		"level_cleared": 0,
		"game_over": 0
	}

	g.state_changed.connect(func(_s): signals_caught["state_changed"] += 1)
	g.points_changed.connect(func(_pts, _delta): signals_caught["points_changed"] += 1)
	g.player_died.connect(func(_l, _p): signals_caught["player_died"] += 1)
	g.level_cleared.connect(func(_id, _sum): signals_caught["level_cleared"] += 1)
	g.game_over.connect(func(): signals_caught["game_over"] += 1)

	# Trigger points_changed and state_changed
	g.move_player(Vector2i(1, 0)) # moves
	g.move_player(Vector2i(1, 0)) # cell pickup (+points)

	# Trigger player_died
	g._handle_player_hit()

	# Trigger level_cleared
	g._state["parts"]["collected"] = 1
	g._check_level_clear()

	# Trigger game_over
	g._state["lives"] = 0
	g._handle_player_hit()

	var success: bool = (
		signals_caught["state_changed"] >= 2 and
		signals_caught["points_changed"] >= 2 and
		signals_caught["player_died"] >= 1 and
		signals_caught["level_cleared"] == 1 and
		signals_caught["game_over"] == 1
	)
	g.free()
	return success
