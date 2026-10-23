## test_portal_twin.gd
## Tests for Step 4: switch_world(), portal zone check, and twin sync.
## Run: Script editor → File → Run (or attach to a Node and press F5).
## No GUT needed — prints PASS / FAIL.
## Role A owns this file.
extends Node

func _ready() -> void:
	_run_tests()
	get_tree().quit()


func _run_tests() -> void:
	print("=== Portal & Twin Tests ===")
	var all_pass: bool = true
	all_pass = _t01_switch_blocked_outside_portal() and all_pass
	all_pass = _t02_switch_works_inside_portal()    and all_pass
	all_pass = _t03_world_toggles_AtoB()            and all_pass
	all_pass = _t04_world_toggles_BtoA()            and all_pass
	all_pass = _t05_last_spawn_updates()            and all_pass
	all_pass = _t06_find_entity_by_id()             and all_pass
	all_pass = _t07_sync_twin_deletion()            and all_pass
	all_pass = _t08_sync_twin_position()            and all_pass
	print("=== %s ===" % ("ALL PASS ✓" if all_pass else "SOME FAILED ✗"))


func _pass(name: String) -> bool:
	print("  PASS  %s" % name)
	return true

func _fail(name: String, detail: String) -> bool:
	print("  FAIL  %s  →  %s" % [name, detail])
	return false


# ── Helpers ───────────────────────────────────────────────

## Loads level 1 and manually sets player position.
func _setup(px: float, py: float) -> void:
	Game.load_level(1)
	# Directly write into state for test purposes
	var st: Dictionary = Game._state
	st["player"]["x"] = px
	st["player"]["y"] = py

## Returns a copy of the current world string.
func _world() -> String:
	return str(Game._state.get("world", "A"))

# ─────────────────────────────────────────────────────────

# T01 — switch_world does nothing outside portal
func _t01_switch_blocked_outside_portal() -> bool:
	_setup(800.0, 600.0)   # far from portal (portal is at x≈280)
	Game.switch_world()
	if _world() == "A":
		return _pass("T01 switch blocked outside portal")
	return _fail("T01", "world changed when player was outside portal")


func _setup_in_portal() -> Dictionary:
	Game.load_level(1)
	var portal: Dictionary = Game._state.get("portals", [])[0]
	var cx: float = float(portal["x"]) + float(portal["w"]) * 0.5
	var cy: float = float(portal["y"]) + float(portal["h"])
	Game._state["player"]["x"] = cx
	Game._state["player"]["y"] = cy
	return portal

# T02 — switch_world succeeds inside portal zone
func _t02_switch_works_inside_portal() -> bool:
	_setup_in_portal()
	Game.switch_world()
	if _world() == "B":
		return _pass("T02 switch works inside portal")
	return _fail("T02", "world did not change to B inside portal")


# T03 — A → B
func _t03_world_toggles_AtoB() -> bool:
	_setup_in_portal()
	Game._state["world"] = "A"
	Game.switch_world()
	if _world() == "B":
		return _pass("T03 A → B toggle")
	return _fail("T03", "expected B, got %s" % _world())


# T04 — B → A
func _t04_world_toggles_BtoA() -> bool:
	_setup_in_portal()
	Game._state["world"] = "B"
	Game.switch_world()
	if _world() == "A":
		return _pass("T04 B → A toggle")
	return _fail("T04", "expected A, got %s" % _world())


# T05 — _last_spawn updated to portal centre after switch
func _t05_last_spawn_updates() -> bool:
	var portal: Dictionary = _setup_in_portal()
	var expected_x: float = float(portal["x"]) + float(portal["w"]) * 0.5
	var expected_y: float = float(portal["y"]) + float(portal["h"])
	Game.switch_world()
	var sp: Vector2 = Game._last_spawn
	if absf(sp.x - expected_x) < 2.0 and absf(sp.y - expected_y) < 2.0:
		return _pass("T05 _last_spawn updated to portal bottom-centre")
	return _fail("T05", "_last_spawn is %s, expected (%f,%f)" % [str(sp), expected_x, expected_y])


# T06 — _find_entity_by_id returns correct entity
func _t06_find_entity_by_id() -> bool:
	Game.load_level(1)
	var ent: Dictionary = Game._find_entity_by_id("spike_a1")
	if ent.get("id","") == "spike_a1" and ent.get("type","") == "spike":
		return _pass("T06 _find_entity_by_id finds spike_a1")
	return _fail("T06", "got: %s" % str(ent))


# T07 — _sync_twin mirrors deletion from B editBlock to its A twin
func _t07_sync_twin_deletion() -> bool:
	Game.load_level(1)
	# edit_spike_b1 twinId = "spike_a1"
	var b_ent: Dictionary = Game._find_entity_by_id("edit_spike_b1")
	if b_ent.is_empty():
		return _fail("T07", "edit_spike_b1 not found")
	b_ent["deleted"] = true
	Game._sync_twin(b_ent)
	var twin: Dictionary = Game._find_entity_by_id("spike_a1")
	if twin.get("deleted", false) == true and twin.get("active", true) == false:
		return _pass("T07 _sync_twin mirrors deletion to A twin")
	return _fail("T07", "twin state: %s" % str(twin))


# T08 — _sync_twin mirrors position from B to A twin
func _t08_sync_twin_position() -> bool:
	Game.load_level(1)
	var b_ent: Dictionary = Game._find_entity_by_id("edit_spike_b1")
	if b_ent.is_empty():
		return _fail("T08", "edit_spike_b1 not found")
	b_ent["x"] = 999.0
	b_ent["y"] = 888.0
	Game._sync_twin(b_ent)
	var twin: Dictionary = Game._find_entity_by_id("spike_a1")
	if absf(float(twin.get("x",0.0)) - 999.0) < 0.01 and absf(float(twin.get("y",0.0)) - 888.0) < 0.01:
		return _pass("T08 _sync_twin mirrors position to A twin")
	return _fail("T08", "twin pos: (%s,%s)" % [twin.get("x","?"), twin.get("y","?")])
