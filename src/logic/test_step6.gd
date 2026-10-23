## test_step6.gd
## Tests for Step 6: Pickups (energy cell, ship part), B objective, exit portal, and reset_level.
## Run: Attached to test_step6.tscn in Godot headless or Script editor.
## Role A owns this file.
extends Node

var _cleared_signal_received: bool = false
var _cleared_points: int = 0


func _ready() -> void:
	_run_tests()
	get_tree().quit()


func _run_tests() -> void:
	print("=== Interactions & Objectives Tests (Step 6) ===")
	var all_pass: bool = true
	all_pass = _t01_energy_cell_pickup()             and all_pass
	all_pass = _t02_ship_part_pickup()               and all_pass
	all_pass = _t03_exit_blocked_without_parts()     and all_pass
	all_pass = _t04_exit_succeeds_with_parts()       and all_pass
	all_pass = _t05_dimension_b_crate_objective()    and all_pass
	all_pass = _t06_reset_level()                    and all_pass
	print("=== %s ===" % ("ALL PASS ✓" if all_pass else "SOME FAILED ✗"))


func _pass(name: String) -> bool:
	print("  PASS  %s" % name)
	return true

func _fail(name: String, detail: String) -> bool:
	print("  FAIL  %s  →  %s" % [name, detail])
	return false


# ── Helpers ───────────────────────────────────────────────

func _setup_level_1(world: String = "A") -> void:
	Game.load_level(1)
	Game._state["world"] = world
	_cleared_signal_received = false
	_cleared_points = 0
	if not Game.level_cleared.is_connected(_on_level_cleared):
		Game.level_cleared.connect(_on_level_cleared)


func _on_level_cleared(pts: int) -> void:
	_cleared_signal_received = true
	_cleared_points = pts


# ─────────────────────────────────────────────────────────

# T01: Touch energy cell in World A -> collected, +5 EP
func _t01_energy_cell_pickup() -> bool:
	_setup_level_1("A")
	var cell: Dictionary = Game._find_entity_by_id("cell_a1")
	if cell.is_empty():
		return _fail("T01", "cell_a1 not found in level 1")

	var initial_pts: int = Game._state["points"] # 30
	# Move player onto cell
	Game._state["player"]["x"] = float(cell["x"]) + 10.0
	Game._state["player"]["y"] = float(cell["y"]) + 10.0

	Game._check_interactions(Game._state["player"], 0.016)

	if cell.get("collected", false) == true and Game._state["points"] == initial_pts + Config.REWARD_ENERGY_CELL:
		return _pass("T01 energy cell collected (+5 EP)")
	return _fail("T01", "cell collected=%s, points=%d (expected %d)" % [
		str(cell.get("collected", false)), Game._state["points"], initial_pts + Config.REWARD_ENERGY_CELL
	])


# T02: Touch ship part in World A -> collected, +30 EP, parts.collected increments
func _t02_ship_part_pickup() -> bool:
	_setup_level_1("A")
	var part: Dictionary = Game._find_entity_by_id("part_a1")
	if part.is_empty():
		return _fail("T02", "part_a1 not found in level 1")

	var initial_pts: int = Game._state["points"]
	Game._state["player"]["x"] = float(part["x"]) + 10.0
	Game._state["player"]["y"] = float(part["y"]) + 10.0

	Game._check_interactions(Game._state["player"], 0.016)

	var parts_col: int = int(Game._state["parts"]["collected"])
	if part.get("collected", false) == true and parts_col == 1 and Game._state["points"] == initial_pts + Config.REWARD_SHIP_PART:
		return _pass("T02 ship part collected (+30 EP, parts count = 1)")
	return _fail("T02", "part collected=%s, count=%d, points=%d" % [
		str(part.get("collected", false)), parts_col, Game._state["points"]
	])


# T03: Exit portal touched without required parts -> does NOT clear level
func _t03_exit_blocked_without_parts() -> bool:
	_setup_level_1("A")
	var exit_ent: Dictionary = Game._find_entity_by_id("exit_a1")
	if exit_ent.is_empty():
		return _fail("T03", "exit_a1 not found in level 1")

	# Ensure parts.collected is 0
	Game._state["parts"]["collected"] = 0

	Game._state["player"]["x"] = float(exit_ent["x"]) + 10.0
	Game._state["player"]["y"] = float(exit_ent["y"]) + 10.0

	Game._check_interactions(Game._state["player"], 0.016)

	if Game._state["status"] == "playing" and not _cleared_signal_received:
		return _pass("T03 exit ignored when ship parts are missing")
	return _fail("T03", "level cleared prematurely without ship parts")


# T04: Exit portal touched with parts collected -> clears level, status = 'won', adds life bonus
func _t04_exit_succeeds_with_parts() -> bool:
	_setup_level_1("A")
	var exit_ent: Dictionary = Game._find_entity_by_id("exit_a1")

	# Set all required parts collected
	Game._state["parts"]["collected"] = Game._state["parts"]["total"] # 1/1
	Game._state["points"] = 50
	Game._state["lives"] = 3

	Game._state["player"]["x"] = float(exit_ent["x"]) + 10.0
	Game._state["player"]["y"] = float(exit_ent["y"]) + 10.0

	Game._check_interactions(Game._state["player"], 0.016)

	var expected_total: int = 50 + (3 * Config.REWARD_LIFE_END) # 50 + 30 = 80
	if Game._state["status"] == "won" and _cleared_signal_received and Game._state["points"] == expected_total:
		return _pass("T04 exit clears level, awards life bonus (+30 EP), status='won'")
	return _fail("T04", "status=%s, signal=%s, pts=%d (expected %d)" % [
		Game._state["status"], str(_cleared_signal_received), Game._state["points"], expected_total
	])


# T05: Dimension B objective: crate pushed onto plate -> completed, +25 EP + 10 time bonus
func _t05_dimension_b_crate_objective() -> bool:
	_setup_level_1("B")
	var crate: Dictionary = Game._find_entity_by_id("crate_b1")
	var plate: Dictionary = Game._find_entity_by_id("plate_b1")
	if crate.is_empty() or plate.is_empty():
		return _fail("T05", "crate_b1 or plate_b1 not found in level 1")

	Game._state["points"] = 30
	Game._state["time"] = 10.0 # within 30s limit

	# Place crate overlapping plate
	crate["x"] = plate["x"]
	crate["y"] = plate["y"]

	Game._check_interactions(Game._state["player"], 0.016)

	var obj_done: bool = Game._state.get("objective", {}).get("completed", false)
	var expected_pts: int = 30 + Config.REWARD_B_OBJECTIVE + Config.REWARD_B_TIME_BONUS # 30 + 25 + 10 = 65
	if obj_done and Game._state["points"] == expected_pts:
		return _pass("T05 B objective completed on crate-plate overlap (+35 EP with time bonus)")
	return _fail("T05", "completed=%s, pts=%d (expected %d)" % [str(obj_done), Game._state["points"], expected_pts])


# T06: reset_level() restores fresh level state
func _t06_reset_level() -> bool:
	_setup_level_1("A")
	Game._state["points"] = 999
	Game._state["lives"] = 1
	Game._state["parts"]["collected"] = 1

	Game.reset_level()

	if Game._state["points"] == Config.POINTS_START and Game._state["lives"] == 3 and Game._state["parts"]["collected"] == 0:
		return _pass("T06 reset_level restores original level configuration")
	return _fail("T06", "pts=%d, lives=%d, parts=%d" % [
		Game._state["points"], Game._state["lives"], Game._state["parts"]["collected"]
	])
