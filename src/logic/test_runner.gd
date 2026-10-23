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

func _init() -> void:
	print("========================================")
	print("       RUNNING LOGIC TESTS: STEP 5      ")
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

	if test_player_spike_hazard():
		print("[PASS] Test 3: Stepping on spike loses 1 life and 20 EP, respawns at portal.")
		passed += 1
	else:
		printerr("[FAIL] Test 3: Spike hazard penalty failed.")
		failed += 1

	if test_portal_transit_success():
		print("[PASS] Test 4: switch_world() on portal 'O' transitions between A and B.")
		passed += 1
	else:
		printerr("[FAIL] Test 4: World switch on portal failed.")
		failed += 1

	if test_twin_delete_sync():
		print("[PASS] Test 5: Deleting object in B deletes twin in A and clears hazard tile.")
		passed += 1
	else:
		printerr("[FAIL] Test 5: Twin delete synchronization failed.")
		failed += 1

	# Step 5 Skill Tests
	if test_shield_in_dimension_a():
		print("[PASS] Test 6: Shield activates in Dimension A and costs 10 EP.")
		passed += 1
	else:
		printerr("[FAIL] Test 6: Shield in Dimension A failed.")
		failed += 1

	if test_shield_rejected_in_dimension_b():
		print("[PASS] Test 7: Shield correctly rejected in Dimension B.")
		passed += 1
	else:
		printerr("[FAIL] Test 7: Shield was allowed in Dimension B.")
		failed += 1

	if test_delete_skill_in_dimension_b():
		print("[PASS] Test 8: Delete in Dimension B costs 15 EP and awards 10 EP for obstacle.")
		passed += 1
	else:
		printerr("[FAIL] Test 8: Delete skill in Dimension B failed.")
		failed += 1

	if test_move_skill_in_dimension_b():
		print("[PASS] Test 9: Move in Dimension B costs 10 EP and syncs twin position.")
		passed += 1
	else:
		printerr("[FAIL] Test 9: Move skill in Dimension B failed.")
		failed += 1

	if test_duplicate_skill_in_dimension_b():
		print("[PASS] Test 10: Duplicate in Dimension B costs 20 EP and creates twin in A.")
		passed += 1
	else:
		printerr("[FAIL] Test 10: Duplicate skill in Dimension B failed.")
		failed += 1

	if test_insufficient_points_locks_skill():
		print("[PASS] Test 11: Skills cannot be used when player has insufficient points.")
		passed += 1
	else:
		printerr("[FAIL] Test 11: Insufficient points check failed.")
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

func test_player_walkable_movement() -> bool:
	var g: Node = _create_game_instance()
	var ok: bool = g.move_player(Vector2i(1, 0))
	var state: Dictionary = g.get_state()
	var success: bool = ok and state["player"]["x"] == 2 and state["player"]["y"] == 1 and state["moves"] == 1
	g.free()
	return success

func test_player_spike_hazard() -> bool:
	var g: Node = _create_game_instance()
	g.move_player(Vector2i(1, 0)) # to (2, 1) portal
	g.move_player(Vector2i(1, 0)) # to (3, 1) energy cell (+5 EP)
	var points_before: int = g.get_state()["points"]

	g.move_player(Vector2i(1, 0)) # to (4, 1) spike
	var state: Dictionary = g.get_state()

	var success: bool = (
		state["lives"] == 2 and
		state["points"] == (points_before - Config.PENALTY_DEATH) and
		state["player"]["x"] == 2 and
		state["player"]["y"] == 1
	)
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

func test_twin_delete_sync() -> bool:
	var g: Node = _create_game_instance()
	var ok: bool = g.sync_delete("block_1")
	var state: Dictionary = g.get_state()

	var block_deleted: bool = false
	var spike_deleted: bool = false
	for obj in state["objects"]:
		if obj["id"] == "block_1" and obj.get("deleted", false):
			block_deleted = true
		if obj["id"] == "spike_1" and obj.get("deleted", false):
			spike_deleted = true

	g.free()
	return ok and block_deleted and spike_deleted

func test_shield_in_dimension_a() -> bool:
	var g: Node = _create_game_instance()
	# World is "A", points = 30. Shield costs 10 EP.
	var ok: bool = g.use_skill("shield", "")
	var state: Dictionary = g.get_state()

	var success: bool = ok and g.has_shield() and state["points"] == 20
	g.free()
	return success

func test_shield_rejected_in_dimension_b() -> bool:
	var g: Node = _create_game_instance()
	g.move_player(Vector2i(1, 0))
	g.switch_world() # Now in Dimension B
	var ok: bool = g.use_skill("shield", "")
	var state: Dictionary = g.get_state()

	var success: bool = not ok and not g.has_shield() and state["points"] == 30
	g.free()
	return success

func test_delete_skill_in_dimension_b() -> bool:
	var g: Node = _create_game_instance()
	# Move to portal and switch to Dimension B
	g.move_player(Vector2i(1, 0))
	g.switch_world()
	# Points are 30. Delete costs 15 EP. Target "block_1" has twin "spike_1" (obstacle), earning +10 EP reward.
	# Net points: 30 - 15 + 10 = 25 EP.
	var ok: bool = g.use_skill("delete", "block_1")
	var state: Dictionary = g.get_state()

	var success: bool = ok and state["points"] == 25
	g.free()
	return success

func test_move_skill_in_dimension_b() -> bool:
	var g: Node = _create_game_instance()
	g.move_player(Vector2i(1, 0))
	g.switch_world() # Dimension B
	# Move costs 10 EP (30 - 10 = 20 EP)
	var ok: bool = g.use_skill("move", "block_1", Vector2i(6, 1))
	var state: Dictionary = g.get_state()

	var target_moved: bool = false
	for obj in state["objects"]:
		if obj["id"] == "block_1" and int(obj["pos"]["x"]) == 6:
			target_moved = true

	var success: bool = ok and state["points"] == 20 and target_moved
	g.free()
	return success

func test_duplicate_skill_in_dimension_b() -> bool:
	var g: Node = _create_game_instance()
	g.move_player(Vector2i(1, 0))
	g.switch_world() # Dimension B
	# Duplicate costs 20 EP (30 - 20 = 10 EP)
	var ok: bool = g.use_skill("duplicate", "block_1", Vector2i(5, 1))
	var state: Dictionary = g.get_state()

	var success: bool = ok and state["points"] == 10 and state["objects"].size() == 4
	g.free()
	return success

func test_insufficient_points_locks_skill() -> bool:
	var g: Node = _create_game_instance()
	# Set points to 5 (cannot afford any skill)
	g._state["points"] = 5
	var ok: bool = g.use_skill("shield", "")
	var state: Dictionary = g.get_state()

	var success: bool = not ok and state["points"] == 5 and not g.has_shield()
	g.free()
	return success
