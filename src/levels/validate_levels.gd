@tool
extends EditorScript

## validate_levels.gd — Role B validator
## Run from Godot: open this script, then File > Run.
## Checks every level_*.json in src/levels/ against the contract.

const REQUIRED_TOP_KEYS: Array[String] = [
	"id", "planet", "startPoints", "lives", "levelSize",
	"spawn", "gravity", "platforms", "entities", "portals",
	"parts", "objective"
]

const VALID_ENTITY_TYPES: Array[String] = [
	"spike", "pit", "wall", "monster", "crate", "plate",
	"energyCell", "shipPart", "editBlock", "portal", "exit"
]

const VALID_SKILLS: Array[String] = [
	"delete", "duplicate", "move", "shield"
]


func _run() -> void:
	var dir: DirAccess = DirAccess.open("res://src/levels")
	if dir == null:
		printerr("ERROR: cannot open res://src/levels/")
		return

	var files: PackedStringArray = dir.get_files()
	var level_files: Array[String] = []
	for f: String in files:
		if f.begins_with("level_") and f.ends_with(".json"):
			level_files.append(f)

	if level_files.is_empty():
		printerr("No level_*.json files found in res://src/levels/")
		return

	level_files.sort()
	var total_errors: int = 0

	for filename: String in level_files:
		var path: String = "res://src/levels/" + filename
		print("\n══════ Validating: %s ══════" % filename)
		var errors: int = _validate_file(path)
		total_errors += errors
		if errors == 0:
			print("  ✓ PASSED — no errors")
		else:
			printerr("  ✗ FAILED — %d error(s)" % errors)

	print("\n══════ Summary ══════")
	print("Files checked: %d  |  Total errors: %d" % [level_files.size(), total_errors])
	if total_errors == 0:
		print("All levels valid! ✓")
	else:
		printerr("Fix the errors above and run again.")


func _validate_file(path: String) -> int:
	var errors: int = 0
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("  Cannot open %s" % path)
		return 1

	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(text)
	if parse_err != OK:
		printerr("  JSON parse error line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return 1

	var data: Variant = json.data
	if not data is Dictionary:
		printerr("  Root is not a JSON object")
		return 1

	var d: Dictionary = data as Dictionary

	# ── 1. Required top-level keys ──
	for key: String in REQUIRED_TOP_KEYS:
		if not d.has(key):
			printerr("  MISSING key: '%s'" % key)
			errors += 1

	# ── 2. levelSize ──
	if d.has("levelSize"):
		var ls: Variant = d["levelSize"]
		if ls is Dictionary:
			if not ls.has("w") or not ls.has("h"):
				printerr("  levelSize missing 'w' or 'h'")
				errors += 1
		else:
			printerr("  levelSize is not an object")
			errors += 1

	# ── 3. spawn ──
	if d.has("spawn"):
		var sp: Variant = d["spawn"]
		if sp is Dictionary:
			if not sp.has("x") or not sp.has("y"):
				printerr("  spawn missing 'x' or 'y'")
				errors += 1
		else:
			printerr("  spawn is not an object")
			errors += 1

	# ── 4. platforms — valid rects ──
	if d.has("platforms"):
		var plats: Variant = d["platforms"]
		if plats is Array:
			var idx: int = 0
			for p: Variant in plats:
				if p is Dictionary:
					for k: String in ["x", "y", "w", "h"]:
						if not p.has(k):
							printerr("  platform[%d] missing '%s'" % [idx, k])
							errors += 1
						elif not _is_number(p[k]):
							printerr("  platform[%d]['%s'] is not a number" % [idx, k])
							errors += 1
					if p.has("w") and _is_number(p["w"]) and float(p["w"]) <= 0:
						printerr("  platform[%d] width <= 0" % idx)
						errors += 1
					if p.has("h") and _is_number(p["h"]) and float(p["h"]) <= 0:
						printerr("  platform[%d] height <= 0" % idx)
						errors += 1
				else:
					printerr("  platform[%d] is not an object" % idx)
					errors += 1
				idx += 1
		else:
			printerr("  platforms is not an array")
			errors += 1

	# ── 5. entities ──
	var entity_ids: Dictionary = {}  # id -> entity dict
	if d.has("entities"):
		var ents: Variant = d["entities"]
		if ents is Array:
			var idx: int = 0
			for e: Variant in ents:
				if not e is Dictionary:
					printerr("  entity[%d] is not an object" % idx)
					errors += 1
					idx += 1
					continue
				var ent: Dictionary = e as Dictionary

				# required: id, type, world, x, y
				for k: String in ["id", "type", "world", "x", "y"]:
					if not ent.has(k):
						printerr("  entity[%d] missing '%s'" % [idx, k])
						errors += 1

				# valid type
				if ent.has("type"):
					var etype: String = str(ent["type"])
					if not VALID_ENTITY_TYPES.has(etype):
						printerr("  entity[%d] unknown type '%s'" % [idx, etype])
						errors += 1

				# valid world
				if ent.has("world"):
					var w: String = str(ent["world"])
					if w != "A" and w != "B":
						printerr("  entity[%d] world must be 'A' or 'B', got '%s'" % [idx, w])
						errors += 1

				# editBlock must have skill
				if ent.has("type") and str(ent["type"]) == "editBlock":
					if not ent.has("skill"):
						printerr("  entity[%d] editBlock missing 'skill'" % idx)
						errors += 1
					elif not VALID_SKILLS.has(str(ent["skill"])):
						printerr("  entity[%d] editBlock unknown skill '%s'" % [idx, str(ent["skill"])])
						errors += 1

				# store id for twin check
				if ent.has("id"):
					var eid: String = str(ent["id"])
					if entity_ids.has(eid):
						printerr("  entity[%d] duplicate id '%s'" % [idx, eid])
						errors += 1
					else:
						entity_ids[eid] = ent

				idx += 1
		else:
			printerr("  entities is not an array")
			errors += 1

	# ── 6. twinId cross-check ──
	for eid: String in entity_ids:
		var ent: Dictionary = entity_ids[eid]
		if ent.has("twinId"):
			var tid: String = str(ent["twinId"])
			if not entity_ids.has(tid):
				printerr("  entity '%s' has twinId '%s' which does not exist" % [eid, tid])
				errors += 1
			else:
				# twin must be in the other world
				var my_world: String = str(ent.get("world", ""))
				var twin_world: String = str(entity_ids[tid].get("world", ""))
				if my_world == twin_world and my_world != "":
					printerr("  entity '%s' (world %s) twin '%s' is in the same world (%s)" % [eid, my_world, tid, twin_world])
					errors += 1

	# ── 7. portals — valid rects ──
	if d.has("portals"):
		var ports: Variant = d["portals"]
		if ports is Array:
			var idx: int = 0
			for p: Variant in ports:
				if p is Dictionary:
					for k: String in ["x", "y", "w", "h"]:
						if not p.has(k):
							printerr("  portal[%d] missing '%s'" % [idx, k])
							errors += 1
				else:
					printerr("  portal[%d] is not an object" % idx)
					errors += 1
				idx += 1
		else:
			printerr("  portals is not an array")
			errors += 1

	# ── 8. objective ──
	if d.has("objective"):
		var obj: Variant = d["objective"]
		if obj is Dictionary:
			if not obj.has("type"):
				printerr("  objective missing 'type'")
				errors += 1
			if not obj.has("timeLimit"):
				printerr("  objective missing 'timeLimit'")
				errors += 1
		else:
			printerr("  objective is not an object")
			errors += 1

	return errors


func _is_number(val: Variant) -> bool:
	return val is int or val is float
