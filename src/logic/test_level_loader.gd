## test_level_loader.gd
## Run from the Godot Output panel:  File → Run → (select this script)
## Or attach to a Node in a test scene and press F5.
## No GUT needed — prints PASS / FAIL to the Output panel.
## Role A owns this file.
extends Node

func _ready() -> void:
	_run_tests()
	get_tree().quit()


func _run_tests() -> void:
	print("=== LevelLoader Tests ===")
	var all_pass: bool = true
	all_pass = _t01_file_not_found()  and all_pass
	all_pass = _t02_level1_loads()    and all_pass
	all_pass = _t03_required_keys()   and all_pass
	all_pass = _t04_entity_fields()   and all_pass
	all_pass = _t05_platform_fields() and all_pass
	all_pass = _t06_runtime_flags()   and all_pass
	print("=== %s ===" % ("ALL PASS ✓" if all_pass else "SOME FAILED ✗"))


func _pass(name: String) -> bool:
	print("  PASS  %s" % name)
	return true

func _fail(name: String, detail: String) -> bool:
	print("  FAIL  %s  →  %s" % [name, detail])
	return false


# T01 — missing file returns empty dict
func _t01_file_not_found() -> bool:
	var d: Dictionary = LevelLoader.load(999)
	if d.is_empty():
		return _pass("T01 missing file → {}")
	return _fail("T01", "expected empty dict, got %s" % str(d))


# T02 — level_1.json loads without error
func _t02_level1_loads() -> bool:
	var d: Dictionary = LevelLoader.load(1)
	if not d.is_empty():
		return _pass("T02 level_1.json loads")
	return _fail("T02", "returned empty dict")


# T03 — top-level required keys exist
func _t03_required_keys() -> bool:
	var d: Dictionary = LevelLoader.load(1)
	var keys: Array = ["id","planet","startPoints","lives","gravity",
					   "parts","levelSize","spawn","platforms",
					   "portals","entities","objective"]
	for k in keys:
		if not d.has(k):
			return _fail("T03", "missing key: %s" % k)
	return _pass("T03 all required keys present")


# T04 — every entity has the 9 contract fields + runtime flags
func _t04_entity_fields() -> bool:
	var d: Dictionary = LevelLoader.load(1)
	var required: Array = ["id","type","world","x","y","w","h",
						   "skill","twinId","collected","deleted","active"]
	for ent in d["entities"]:
		for k in required:
			if not ent.has(k):
				return _fail("T04", "entity '%s' missing field '%s'" % [ent.get("id","?"), k])
	return _pass("T04 all entity fields present")


# T05 — all platforms have x,y,w,h as floats
func _t05_platform_fields() -> bool:
	var d: Dictionary = LevelLoader.load(1)
	for plat in d["platforms"]:
		for k in ["x","y","w","h"]:
			if not plat.has(k):
				return _fail("T05", "platform missing '%s'" % k)
			if not (plat[k] is float):
				return _fail("T05", "platform.%s is not float" % k)
	return _pass("T05 all platform fields are floats")


# T06 — runtime flags start at correct defaults
func _t06_runtime_flags() -> bool:
	var d: Dictionary = LevelLoader.load(1)
	for ent in d["entities"]:
		if ent["collected"] != false:
			return _fail("T06", "entity '%s' collected should start false" % ent["id"])
		if ent["deleted"] != false:
			return _fail("T06", "entity '%s' deleted should start false" % ent["id"])
		if ent["active"] != true:
			return _fail("T06", "entity '%s' active should start true" % ent["id"])
	return _pass("T06 runtime flags initialised correctly")
