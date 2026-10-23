## test_skills.gd
## Tests for Step 5: use_skill() — Delete, Duplicate, Shield, and range/cost guards.
## Run: Attached to test_skills.tscn in Godot headless or Script editor.
## Role A owns this file.
extends Node

func _ready() -> void:
	_run_tests()
	get_tree().quit()


func _run_tests() -> void:
	print("=== Skill Tests (Step 5) ===")
	var all_pass: bool = true
	all_pass = _t01_delete_blocked_in_world_a()         and all_pass
	all_pass = _t02_delete_blocked_out_of_range()       and all_pass
	all_pass = _t03_delete_blocked_insufficient_points() and all_pass
	all_pass = _t04_delete_succeeds_and_syncs_twin()    and all_pass
	all_pass = _t05_duplicate_creates_bridge_and_sync() and all_pass
	all_pass = _t06_shield_blocks_hazard_in_world_a()   and all_pass
	all_pass = _t07_auto_target_finds_nearest_block()   and all_pass
	print("=== %s ===" % ("ALL PASS ✓" if all_pass else "SOME FAILED ✗"))


func _pass(name: String) -> bool:
	print("  PASS  %s" % name)
	return true

func _fail(name: String, detail: String) -> bool:
	print("  FAIL  %s  →  %s" % [name, detail])
	return false


# ── Helpers ───────────────────────────────────────────────

func _setup_world_b() -> void:
	Game.load_level(1)
	Game._state["world"] = "B"
	Game._state["points"] = 50


# ─────────────────────────────────────────────────────────

# T01: Delete skill fails if attempted in Dimension A
func _t01_delete_blocked_in_world_a() -> bool:
	Game.load_level(1)
	Game._state["world"] = "A"
	Game._state["points"] = 50
	var ent: Dictionary = Game._find_entity_by_id("edit_spike_b1")
	Game._state["player"]["x"] = ent.get("x", 0.0)
	Game._state["player"]["y"] = ent.get("y", 0.0)
	
	Game.use_skill("delete", "edit_spike_b1")
	if not ent.get("deleted", false) and Game._state["points"] == 50:
		return _pass("T01 delete blocked in World A")
	return _fail("T01", "delete executed in World A")


# T02: Delete skill fails if player is out of range (> Config.SKILL_RANGE)
func _t02_delete_blocked_out_of_range() -> bool:
	_setup_world_b()
	var ent: Dictionary = Game._find_entity_by_id("edit_spike_b1")
	var ew: float = float(ent.get("w", 32.0))
	Game._state["player"]["x"] = float(ent["x"]) + ew + Config.SKILL_RANGE + 100.0
	Game._state["player"]["y"] = float(ent["y"])
	
	Game.use_skill("delete", "edit_spike_b1")
	if not ent.get("deleted", false) and Game._state["points"] == 50:
		return _pass("T02 delete blocked when out of range")
	return _fail("T02", "delete executed when player was out of range")


# T03: Delete skill fails if points < Config.COST_DELETE
func _t03_delete_blocked_insufficient_points() -> bool:
	_setup_world_b()
	var ent: Dictionary = Game._find_entity_by_id("edit_spike_b1")
	Game._state["player"]["x"] = float(ent["x"])
	Game._state["player"]["y"] = float(ent["y"])
	Game._state["points"] = 5  # less than COST_DELETE (15)
	
	Game.use_skill("delete", "edit_spike_b1")
	if not ent.get("deleted", false) and Game._state["points"] == 5:
		return _pass("T03 delete blocked with insufficient points")
	return _fail("T03", "delete executed without enough points")


# T04: Delete succeeds: deducts 15 EP, awards 10 EP clear reward, marks deleted, and syncs twin in World A
func _t04_delete_succeeds_and_syncs_twin() -> bool:
	_setup_world_b()
	var b_ent: Dictionary = Game._find_entity_by_id("edit_spike_b1")
	Game._state["player"]["x"] = float(b_ent["x"]) + 10.0
	Game._state["player"]["y"] = float(b_ent["y"])
	Game._state["points"] = 50
	
	Game.use_skill("delete", "edit_spike_b1")
	
	var expected_pts: int = 50 - Config.COST_DELETE + Config.REWARD_CLEAR_OBSTACLE # 50 - 15 + 10 = 45
	var actual_pts: int = Game._state["points"]
	var twin: Dictionary = Game._find_entity_by_id("spike_a1")
	
	if b_ent.get("deleted", false) and twin.get("deleted", false) and actual_pts == expected_pts:
		return _pass("T04 delete succeeds, deducts net 5 EP, and syncs deletion to twin")
	return _fail("T04", "b_del=%s, twin_del=%s, pts=%d (expected %d)" % [
		str(b_ent.get("deleted", false)), str(twin.get("deleted", false)), actual_pts, expected_pts
	])


# T05: Duplicate succeeds: deducts 20 EP, awards 10 EP clear reward, and enables bridge wall in World A
func _t05_duplicate_creates_bridge_and_sync() -> bool:
	_setup_world_b()
	var b_bridge: Dictionary = Game._find_entity_by_id("edit_bridge_b1")
	Game._state["player"]["x"] = float(b_bridge["x"]) + 20.0
	Game._state["player"]["y"] = float(b_bridge["y"])
	Game._state["points"] = 50
	
	Game.use_skill("duplicate", "edit_bridge_b1")
	
	var expected_pts: int = 50 - Config.COST_DUPLICATE + Config.REWARD_CLEAR_OBSTACLE # 50 - 20 + 10 = 40
	var actual_pts: int = Game._state["points"]
	var twin_pit: Dictionary = Game._find_entity_by_id("pit_a1")
	var dup_wall: Dictionary = Game._find_entity_by_id("dup_wall_edit_bridge_b1")
	
	if b_bridge.get("duplicated", false) and twin_pit.get("deleted", false) and not dup_wall.is_empty() and actual_pts == expected_pts:
		return _pass("T05 duplicate deactivates pit, creates solid bridge wall, net -10 EP")
	return _fail("T05", "dup=%s, pit_del=%s, wall=%s, pts=%d (expected %d)" % [
		str(b_bridge.get("duplicated", false)), str(twin_pit.get("deleted", false)), str(not dup_wall.is_empty()), actual_pts, expected_pts
	])


# T06: Shield works in World A, costs 10 EP, and absorbs a hazard hit without dying
func _t06_shield_blocks_hazard_in_world_a() -> bool:
	Game.load_level(1)
	Game._state["world"] = "A"
	Game._state["points"] = 50
	var initial_lives: int = Game._state["lives"]
	
	Game.use_skill("shield", "")
	if not Game._state.get("shielded", false) or Game._state["points"] != 40:
		return _fail("T06", "shield not activated or cost not deducted")
	
	# Simulate touching spike_a1
	var spike: Dictionary = Game._find_entity_by_id("spike_a1")
	Game._state["player"]["x"] = float(spike["x"]) + 10.0
	Game._state["player"]["y"] = float(spike["y"]) + 10.0
	
	Game._check_hazards(Game._state["player"])
	
	# Player should still have initial_lives, status playing, and shield consumed
	if Game._state["lives"] == initial_lives and not Game._state.get("shielded", false) and Game._state["status"] == "playing":
		return _pass("T06 shield absorbed hazard hit without losing lives")
	return _fail("T06", "player lost life despite shield: lives=%d status=%s" % [Game._state["lives"], Game._state["status"]])


# T07: use_skill with target_id == "" automatically resolves nearest editBlock
func _t07_auto_target_finds_nearest_block() -> bool:
	_setup_world_b()
	var b_ent: Dictionary = Game._find_entity_by_id("edit_spike_b1")
	b_ent["deleted"] = false
	Game._state["player"]["x"] = float(b_ent["x"]) + 10.0
	Game._state["player"]["y"] = float(b_ent["y"])
	Game._state["points"] = 50
	
	Game.use_skill("delete", "")
	if b_ent.get("deleted", false):
		return _pass("T07 auto-target resolves nearest matching editBlock")
	return _fail("T07", "nearest target was not resolved when target_id was empty")
