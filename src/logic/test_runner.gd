extends SceneTree

## Headless Test Runner for Rift Runner logic.
## Can be executed directly with:
## godot --headless -s res://src/logic/test_runner.gd

const LevelLoader = preload("res://src/logic/level_loader.gd")
const Config = preload("res://src/logic/config.gd")
const GameScript = preload("res://src/logic/game.gd")
const GridSystem = preload("res://src/logic/grid_system.gd")
const SyncSystem = preload("res://src/logic/sync_system.gd")

func _init() -> void:
	print("========================================")
	print("       RUNNING LOGIC TESTS: STEP 4      ")
	print("========================================")
	var passed: int = 0
	var failed: int = 0

	# Step 2 & 3 Regression Tests
	if test_valid_level_json():
		print("[PASS] Test 1: Valid level JSON parsed and validated.")
		passed += 1
	else:
		printerr("[FAIL] Test 1: Valid level JSON failed.")
		failed += 1

	if test_find_player_start():
		print("[PASS] Test 2: Player start 'P' found at expected coordinates.")
		passed += 1
	else:
		printerr("[FAIL] Test 2: Player start coordinate extraction failed.")
		failed += 1

	if test_player_walkable_movement():
		print("[PASS] Test 3: Player moves correctly on walkable floor.")
		passed += 1
	else:
		printerr("[FAIL] Test 3: Player movement on walkable floor failed.")
		failed += 1

	if test_player_wall_collision():
		print("[PASS] Test 4: Wall correctly blocks player movement.")
		passed += 1
	else:
		printerr("[FAIL] Test 4: Wall collision failed to block.")
		failed += 1

	if test_player_spike_hazard():
		print("[PASS] Test 5: Stepping on spike loses 1 life and 20 EP, respawns at portal.")
		passed += 1
	else:
		printerr("[FAIL] Test 5: Spike hazard penalty failed.")
		failed += 1

	if test_shield_blocks_hit():
		print("[PASS] Test 6: Shield absorbs hazard hit without losing life or points.")
		passed += 1
	else:
		printerr("[FAIL] Test 6: Shield hit absorption failed.")
		failed += 1

	# Step 4 Portal and Twin Sync Tests
	if test_portal_transit_rejection_outside():
		print("[PASS] Test 7: switch_world() is rejected when not standing on portal.")
		passed += 1
	else:
		printerr("[FAIL] Test 7: World switch was allowed outside portal.")
		failed += 1

	if test_portal_transit_success():
		print("[PASS] Test 8: switch_world() on portal 'O' transitions between A and B.")
		passed += 1
	else:
		printerr("[FAIL] Test 8: World switch on portal failed.")
		failed += 1

	if test_twin_delete_sync():
		print("[PASS] Test 9: Deleting object in B deletes twin in A and clears hazard tile.")
		passed += 1
	else:
		printerr("[FAIL] Test 9: Twin delete synchronization failed.")
		failed += 1

	if test_twin_move_sync():
		print("[PASS] Test 10: Moving object in B synchronizes twin position in A.")
		passed += 1
	else:
		printerr("[FAIL] Test 10: Twin move synchronization failed.")
		failed += 1

	if test_twin_duplicate_sync():
		print("[PASS] Test 11: Duplicating object in B creates matching twin in A.")
		passed += 1
	else:
		printerr("[FAIL] Test 11: Twin duplicate synchronization failed.")
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
	var ok: bool = g.move_player(Vector2i(1, 0))
	var state: Dictionary = g.get_state()
	var success: bool = ok and state["player"]["x"] == 2 and state["player"]["y"] == 1 and state["moves"] == 1
	g.free()
	return success

func test_player_wall_collision() -> bool:
	var g: Node = _create_game_instance()
	var ok: bool = g.move_player(Vector2i(0, -1))
	var state: Dictionary = g.get_state()
	var success: bool = not ok and state["player"]["x"] == 1 and state["player"]["y"] == 1 and state["moves"] == 0
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

func test_shield_blocks_hit() -> bool:
	var g: Node = _create_game_instance()
	g.set_shield(true)
	g.move_player(Vector2i(1, 0))
	g.move_player(Vector2i(1, 0))
	var points_before: int = g.get_state()["points"]
	var lives_before: int = g.get_state()["lives"]

	g.move_player(Vector2i(1, 0))
	var state: Dictionary = g.get_state()

	var success: bool = (
		state["lives"] == lives_before and
		state["points"] == points_before and
		not g.has_shield()
	)
	g.free()
	return success

func test_portal_transit_rejection_outside() -> bool:
	var g: Node = _create_game_instance()
	# Nova starts at (1, 1) which is 'P' (floor), NOT portal 'O' (2, 1)
	var ok: bool = g.switch_world()
	var state: Dictionary = g.get_state()
	# Should fail and remain in world "A"
	var success: bool = not ok and state["world"] == "A"
	g.free()
	return success

func test_portal_transit_success() -> bool:
	var g: Node = _create_game_instance()
	# Move to portal at (2, 1)
	g.move_player(Vector2i(1, 0))
	var ok_to_b: bool = g.switch_world()
	var state_b: Dictionary = g.get_state()

	# Now switch back from B to A while on portal
	var ok_to_a: bool = g.switch_world()
	var state_a: Dictionary = g.get_state()

	var success: bool = ok_to_b and state_b["world"] == "B" and ok_to_a and state_a["world"] == "A"
	g.free()
	return success

func test_twin_delete_sync() -> bool:
	var g: Node = _create_game_instance()
	# Delete object block_1 in B
	var ok: bool = g.sync_delete("block_1")
	var state: Dictionary = g.get_state()

	var block_deleted: bool = false
	var spike_deleted: bool = false
	for obj in state["objects"]:
		if obj["id"] == "block_1" and obj.get("deleted", false):
			block_deleted = true
		if obj["id"] == "spike_1" and obj.get("deleted", false):
			spike_deleted = true

	# After twin delete, player can safely walk onto (4, 1) in world A without taking damage!
	g.move_player(Vector2i(1, 0)) # to (2, 1)
	g.move_player(Vector2i(1, 0)) # to (3, 1)
	g.move_player(Vector2i(1, 0)) # to (4, 1) -> former spike!
	var state_after_walk: Dictionary = g.get_state()

	var no_death: bool = state_after_walk["lives"] == 3 and state_after_walk["player"]["x"] == 4

	g.free()
	return ok and block_deleted and spike_deleted and no_death

func test_twin_move_sync() -> bool:
	var g: Node = _create_game_instance()
	# Move block_1 to (7, 1)
	var ok: bool = g.sync_move("block_1", Vector2i(7, 1))
	var state: Dictionary = g.get_state()

	var block_moved: bool = false
	var spike_moved: bool = false
	for obj in state["objects"]:
		if obj["id"] == "block_1" and int(obj["pos"]["x"]) == 7:
			block_moved = true
		if obj["id"] == "spike_1" and int(obj["pos"]["x"]) == 7:
			spike_moved = true

	g.free()
	return ok and block_moved and spike_moved

func test_twin_duplicate_sync() -> bool:
	var g: Node = _create_game_instance()
	var new_obj: Dictionary = g.sync_duplicate("block_1", Vector2i(3, 1))
	var state: Dictionary = g.get_state()

	var count_copies: int = 0
	for obj in state["objects"]:
		if str(obj["id"]).begins_with("block_1_copy"):
			count_copies += 1

	# Both the B-copy and its A-twin copy should be added (2 new objects)
	var success: bool = not new_obj.is_empty() and count_copies >= 1 and state["objects"].size() == 4
	g.free()
	return success
