@tool
extends EditorScript

## Level JSON Validator for Rift Runner
## Run from Godot's Script Editor: File > Run
## Checks all level_*.json files in src/levels/ against the contract.

# --- Contract: required top-level keys ---
const REQUIRED_KEYS := [
	"id", "planet", "startPoints", "lives", "gridSize",
	"worldA", "worldB", "objects", "parts", "portals", "puzzle"
]

# --- Contract: valid tile characters ---
# Original 8: # . P O c S F X
# Extended:   G(gap) M(monster) B(block) T(target) D(door) _(plate) ~(glitch)
const VALID_TILES := "#.POcSFXGMBTD_~"

# --- Contract: required object keys ---
const REQUIRED_OBJ_KEYS := ["id", "type", "pos", "world", "twinId"]

# --- Contract: required puzzle keys ---
const REQUIRED_PUZZLE_KEYS := ["type", "moveLimit"]

# --- Contract: required portal keys ---
const REQUIRED_PORTAL_KEYS := ["world", "pos"]


func _run() -> void:
	print("\n========================================")
	print("  Rift Runner — Level Validator")
	print("========================================\n")

	var levels_dir := "res://src/levels/"
	var dir := DirAccess.open(levels_dir)
	if dir == null:
		printerr("ERROR: Cannot open directory: %s" % levels_dir)
		return

	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("level_") and file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	files.sort()

	if files.is_empty():
		printerr("WARNING: No level_*.json files found in %s" % levels_dir)
		return

	var total_errors := 0
	var total_warnings := 0

	for fname in files:
		var result := _validate_level(levels_dir + fname, fname)
		total_errors += result.errors
		total_warnings += result.warnings

	print("\n========================================")
	if total_errors == 0:
		print("  ALL %d LEVELS PASSED  (%d warnings)" % [files.size(), total_warnings])
	else:
		printerr("  %d ERROR(S) across %d levels  (%d warnings)" % [total_errors, files.size(), total_warnings])
	print("========================================\n")


func _validate_level(path: String, display_name: String) -> Dictionary:
	var errors := 0
	var warnings := 0

	print("--- Validating: %s ---" % display_name)

	# ---- Load and parse JSON ----
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("  ERROR: Cannot open file: %s" % path)
		return {"errors": 1, "warnings": 0}

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(text)
	if parse_result != OK:
		printerr("  ERROR: Invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return {"errors": 1, "warnings": 0}

	var data: Dictionary = json.data
	if not data is Dictionary:
		printerr("  ERROR: Root element must be a JSON object (Dictionary)")
		return {"errors": 1, "warnings": 0}

	# ---- Check required top-level keys ----
	for key in REQUIRED_KEYS:
		if not data.has(key):
			printerr("  ERROR: Missing required key: '%s'" % key)
			errors += 1

	if errors > 0:
		print("  Skipping further checks due to missing keys.")
		return {"errors": errors, "warnings": warnings}

	# ---- Validate gridSize ----
	var grid_size: Array = data["gridSize"]
	if grid_size.size() != 2:
		printerr("  ERROR: gridSize must be [width, height], got %s" % str(grid_size))
		errors += 1
		return {"errors": errors, "warnings": warnings}

	var width: int = int(grid_size[0])
	var height: int = int(grid_size[1])
	print("  Grid size: %d × %d" % [width, height])

	# ---- Validate worldA grid ----
	var world_a: Array = data["worldA"]
	errors += _validate_grid(world_a, "worldA", width, height)

	# ---- Validate worldB grid ----
	var world_b: Array = data["worldB"]
	errors += _validate_grid(world_b, "worldB", width, height)

	# ---- Validate grids are same size ----
	if world_a.size() != world_b.size():
		printerr("  ERROR: worldA has %d rows but worldB has %d rows" % [world_a.size(), world_b.size()])
		errors += 1
	else:
		for row_idx in range(world_a.size()):
			var row_a: String = world_a[row_idx]
			var row_b: String = world_b[row_idx]
			if row_a.length() != row_b.length():
				printerr("  ERROR: Row %d width mismatch: worldA=%d, worldB=%d" % [row_idx, row_a.length(), row_b.length()])
				errors += 1

	# ---- Validate objects ----
	var objects: Array = data["objects"]
	var object_ids := {}  # id -> object dict for twin lookup

	for obj_idx in range(objects.size()):
		var obj: Dictionary = objects[obj_idx]
		var obj_label := "objects[%d]" % obj_idx

		# Check required keys
		for key in REQUIRED_OBJ_KEYS:
			if not obj.has(key):
				printerr("  ERROR: %s missing key '%s'" % [obj_label, key])
				errors += 1

		if not obj.has("id"):
			continue

		var obj_id: String = str(obj["id"])

		# Check for duplicate IDs
		if object_ids.has(obj_id):
			printerr("  ERROR: Duplicate object id: '%s'" % obj_id)
			errors += 1
		object_ids[obj_id] = obj

		# Check world field
		if obj.has("world"):
			var world_val: String = str(obj["world"])
			if world_val != "A" and world_val != "B":
				printerr("  ERROR: %s (id='%s') has invalid world: '%s' (must be 'A' or 'B')" % [obj_label, obj_id, world_val])
				errors += 1

		# Check position is within grid bounds
		if obj.has("pos"):
			var pos: Array = obj["pos"]
			if pos.size() != 2:
				printerr("  ERROR: %s (id='%s') pos must be [x, y], got %s" % [obj_label, obj_id, str(pos)])
				errors += 1
			else:
				var px: int = int(pos[0])
				var py: int = int(pos[1])
				if px < 0 or px >= width or py < 0 or py >= height:
					printerr("  ERROR: %s (id='%s') pos [%d, %d] out of grid bounds [%d × %d]" % [obj_label, obj_id, px, py, width, height])
					errors += 1

	# ---- Validate twin IDs exist ----
	for obj_id in object_ids:
		var obj: Dictionary = object_ids[obj_id]
		var twin_id = obj.get("twinId")
		if twin_id != null and str(twin_id) != "" and not object_ids.has(str(twin_id)):
			printerr("  ERROR: Object '%s' has twinId '%s' which does not exist" % [obj_id, str(twin_id)])
			errors += 1

	# ---- Validate twin pairs are in different worlds ----
	for obj_id in object_ids:
		var obj: Dictionary = object_ids[obj_id]
		var twin_id = obj.get("twinId")
		if twin_id != null and str(twin_id) != "" and object_ids.has(str(twin_id)):
			var twin: Dictionary = object_ids[str(twin_id)]
			if obj.has("world") and twin.has("world"):
				if str(obj["world"]) == str(twin["world"]):
					printerr("  ERROR: Object '%s' and twin '%s' are both in world '%s' (must be in different worlds)" % [obj_id, str(twin_id), str(obj["world"])])
					errors += 1

	# ---- Validate twin links are bidirectional ----
	for obj_id in object_ids:
		var obj: Dictionary = object_ids[obj_id]
		var twin_id = obj.get("twinId")
		if twin_id != null and str(twin_id) != "" and object_ids.has(str(twin_id)):
			var twin: Dictionary = object_ids[str(twin_id)]
			var reverse_twin = twin.get("twinId")
			if reverse_twin == null or str(reverse_twin) != obj_id:
				printerr("  ERROR: Twin link not bidirectional: '%s' -> '%s' but '%s' -> '%s'" % [obj_id, str(twin_id), str(twin_id), str(reverse_twin)])
				errors += 1

	# ---- Validate portals ----
	var portals: Array = data["portals"]
	var has_portal_a := false
	var has_portal_b := false
	for portal_idx in range(portals.size()):
		var portal: Dictionary = portals[portal_idx]
		for key in REQUIRED_PORTAL_KEYS:
			if not portal.has(key):
				printerr("  ERROR: portals[%d] missing key '%s'" % [portal_idx, key])
				errors += 1
		if portal.has("world"):
			var pw: String = str(portal["world"])
			if pw == "A":
				has_portal_a = true
			elif pw == "B":
				has_portal_b = true

		# Check that portal position has O tile in the matching grid
		if portal.has("world") and portal.has("pos"):
			var pw: String = str(portal["world"])
			var ppos: Array = portal["pos"]
			if ppos.size() == 2:
				var px: int = int(ppos[0])
				var py: int = int(ppos[1])
				var grid: Array = world_a if pw == "A" else world_b
				if py >= 0 and py < grid.size():
					var row_str: String = grid[py]
					if px >= 0 and px < row_str.length():
						var tile := row_str[px]
						if tile != "O":
							printerr("  ERROR: Portal (world=%s) at [%d, %d] expects 'O' tile but found '%s'" % [pw, px, py, tile])
							errors += 1

	if not has_portal_a:
		printerr("  ERROR: No portal defined for world A")
		errors += 1
	if not has_portal_b:
		printerr("  ERROR: No portal defined for world B")
		errors += 1

	# ---- Validate exactly one P in worldA ----
	var p_count := _count_tile(world_a, "P")
	if p_count == 0:
		printerr("  ERROR: worldA has no player start tile 'P'")
		errors += 1
	elif p_count > 1:
		printerr("  ERROR: worldA has %d player start tiles 'P' (expected 1)" % p_count)
		errors += 1

	# ---- Validate at least one X (exit) in worldA ----
	var x_count := _count_tile(world_a, "X")
	if x_count == 0:
		printerr("  ERROR: worldA has no exit tile 'X'")
		errors += 1

	# ---- Validate ship parts match ----
	var parts_list: Array = data["parts"]
	var f_count := _count_tile(world_a, "F")
	var part_objects := 0
	for obj_id in object_ids:
		var obj: Dictionary = object_ids[obj_id]
		if str(obj.get("type", "")) == "ship_part":
			part_objects += 1

	if parts_list.size() == 0:
		printerr("  ERROR: 'parts' array is empty (need at least 1 ship part)")
		errors += 1
	if f_count != parts_list.size():
		print("  WARNING: %d 'F' tiles in worldA but %d entries in 'parts' array" % [f_count, parts_list.size()])
		warnings += 1

	# ---- Validate puzzle ----
	var puzzle: Dictionary = data["puzzle"]
	for key in REQUIRED_PUZZLE_KEYS:
		if not puzzle.has(key):
			printerr("  ERROR: puzzle missing key '%s'" % key)
			errors += 1

	# ---- Validate startPoints and lives ----
	var start_pts: int = int(data["startPoints"])
	var lives_val: int = int(data["lives"])
	if start_pts != 30:
		print("  WARNING: startPoints is %d (contract says 30)" % start_pts)
		warnings += 1
	if lives_val != 3:
		print("  WARNING: lives is %d (contract says 3)" % lives_val)
		warnings += 1

	# ---- Summary ----
	if errors == 0:
		print("  PASSED (%d warnings)" % warnings)
	else:
		printerr("  FAILED with %d error(s), %d warning(s)" % [errors, warnings])

	return {"errors": errors, "warnings": warnings}


func _validate_grid(grid: Array, grid_name: String, expected_width: int, expected_height: int) -> int:
	var errors := 0

	if grid.size() != expected_height:
		printerr("  ERROR: %s has %d rows but gridSize says %d" % [grid_name, grid.size(), expected_height])
		errors += 1

	for row_idx in range(grid.size()):
		var row: String = grid[row_idx]
		if row.length() != expected_width:
			printerr("  ERROR: %s row %d has width %d but gridSize says %d" % [grid_name, row_idx, row.length(), expected_width])
			errors += 1

		for col_idx in range(row.length()):
			var tile := row[col_idx]
			if not VALID_TILES.contains(tile):
				printerr("  ERROR: %s row %d col %d has invalid tile '%s'" % [grid_name, row_idx, col_idx, tile])
				errors += 1

	return errors


func _count_tile(grid: Array, tile_char: String) -> int:
	var count := 0
	for row in grid:
		var row_str: String = row
		for i in range(row_str.length()):
			if row_str[i] == tile_char:
				count += 1
	return count
