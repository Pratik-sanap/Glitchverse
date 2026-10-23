## level_loader.gd
## Pure data class — reads a level JSON from res://src/levels/ and
## returns a fully typed Dictionary that Game._state is built from.
## No Node, no drawing, no signals.  Role A owns this file.
class_name LevelLoader
extends RefCounted

## Loads level_{id}.json and returns a Dictionary on success, or {} on failure.
static func load(id: int) -> Dictionary:
	var path: String = "res://src/levels/level_%d.json" % id
	if not FileAccess.file_exists(path):
		push_error("LevelLoader: file not found — %s" % path)
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("LevelLoader: cannot open — %s" % path)
		return {}

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("LevelLoader: invalid JSON in — %s" % path)
		return {}

	return _validate(parsed)


## Validates required keys and applies safe defaults for missing optional fields.
static func _validate(raw: Dictionary) -> Dictionary:
	# ── Required top-level keys ────────────────────────────
	if not raw.has("id") or not raw.has("spawn") or not raw.has("platforms"):
		push_error("LevelLoader: JSON missing required keys (id / spawn / platforms).")
		return {}

	var d: Dictionary = {}

	# ── Scalars ────────────────────────────────────────────
	d["id"]          = int(raw.get("id",          1))
	d["planet"]      = str(raw.get("planet",      "Unknown"))
	d["startPoints"] = int(raw.get("startPoints", Config.POINTS_START))
	d["lives"]       = int(raw.get("lives",       3))
	d["gravity"]     = float(raw.get("gravity",   Config.GRAVITY))
	d["parts"]       = int(raw.get("parts",       1))

	# ── levelSize ─────────────────────────────────────────
	var ls: Dictionary = raw.get("levelSize", {})
	d["levelSize"] = {
		"w": float(ls.get("w", 2400)),
		"h": float(ls.get("h", 720))
	}

	# ── spawn ─────────────────────────────────────────────
	var sp: Dictionary = raw.get("spawn", {})
	d["spawn"] = {
		"x": float(sp.get("x", 100)),
		"y": float(sp.get("y", 500))
	}

	# ── platforms ─────────────────────────────────────────
	d["platforms"] = _parse_rects(raw.get("platforms", []))

	# ── portals ───────────────────────────────────────────
	d["portals"] = _parse_rects(raw.get("portals", []))

	# ── entities ──────────────────────────────────────────
	d["entities"] = _parse_entities(raw.get("entities", []))

	# ── objective ─────────────────────────────────────────
	var obj: Dictionary = raw.get("objective", {})
	d["objective"] = {
		"type":      str(obj.get("type",      "none")),
		"timeLimit": float(obj.get("timeLimit", 0.0))
	}

	return d


## Converts an Array of raw Dicts into typed rect Dicts {x,y,w,h}.
static func _parse_rects(raw_arr: Array) -> Array:
	var out: Array = []
	for item in raw_arr:
		if not (item is Dictionary):
			continue
		out.append({
			"x": float(item.get("x", 0)),
			"y": float(item.get("y", 0)),
			"w": float(item.get("w", 64)),
			"h": float(item.get("h", 32))
		})
	return out


## Converts raw entity Dicts into typed entity Dicts.
## Adds runtime fields: collected, deleted, active.
static func _parse_entities(raw_arr: Array) -> Array:
	var out: Array = []
	for item in raw_arr:
		if not (item is Dictionary):
			continue
		var e: Dictionary = {}
		e["id"]        = str(item.get("id",    ""))
		e["type"]      = str(item.get("type",  ""))
		e["world"]     = str(item.get("world", "A"))
		e["x"]         = float(item.get("x",   0))
		e["y"]         = float(item.get("y",   0))
		e["w"]         = float(item.get("w",   32))
		e["h"]         = float(item.get("h",   32))
		e["skill"]     = str(item.get("skill", ""))
		e["twinId"]    = str(item.get("twinId",""))
		# ── Runtime state flags ───────────────────────────
		e["collected"] = false   # energy cells / ship parts
		e["deleted"]   = false   # deleted by skill
		e["active"]    = true    # false = does not interact
		out.append(e)
	return out
