class_name GridSystem
extends RefCounted

## Decoupled Grid and Turn System for Rift Runner.
## Handles player movement, collision detection, turn progression,
## hazard checks (spikes, gaps), and monster patrol execution.
## Pure GDScript - no scene/drawing dependencies.

const ConfigScript = preload("res://src/logic/config.gd")

## Checks if grid coordinates are within the level dimensions.
static func is_inside_grid(pos: Vector2i, grid_size: Dictionary) -> bool:
	var width: int = int(grid_size.get("width", 0))
	var height: int = int(grid_size.get("height", 0))
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

## Returns the tile character at the given coordinates in the specified world grid.
static func get_tile_at(grid_rows: Array, pos: Vector2i) -> String:
	if pos.y < 0 or pos.y >= grid_rows.size():
		return "#"
	var row: String = str(grid_rows[pos.y])
	if pos.x < 0 or pos.x >= row.length():
		return "#"
	return row[pos.x]

## Sets the tile character at the given coordinates in the specified world grid rows.
static func set_tile_at(grid_rows: Array, pos: Vector2i, new_tile: String) -> void:
	if pos.y < 0 or pos.y >= grid_rows.size():
		return
	var row: String = str(grid_rows[pos.y])
	if pos.x < 0 or pos.x >= row.length():
		return
	grid_rows[pos.y] = row.substr(0, pos.x) + new_tile + row.substr(pos.x + 1)

## Checks whether a tile is passable for the player.
static func is_tile_walkable(tile: String) -> bool:
	# Walls '#' block movement
	return tile != "#"

## Finds an object at specific grid coordinates in the active world.
static func get_object_at(objects: Array, pos: Vector2i, active_world: String = "") -> Dictionary:
	for obj in objects:
		if not (obj is Dictionary):
			continue
		if active_world != "" and obj.has("world") and str(obj["world"]) != active_world:
			continue
		var obj_pos: Dictionary = obj.get("pos", {})
		if int(obj_pos.get("x", -1)) == pos.x and int(obj_pos.get("y", -1)) == pos.y:
			# Check if object is active (not deleted)
			if obj.get("deleted", false) == false:
				return obj
	return {}

## Advances all monsters by one step along their patrol path or direction.
static func advance_monsters(objects: Array, grid_rows: Array, grid_size: Dictionary) -> void:
	for obj in objects:
		if not (obj is Dictionary):
			continue
		if obj.get("type", "") != "monster" or obj.get("deleted", false):
			continue

		var current_pos: Vector2i = Vector2i(int(obj["pos"]["x"]), int(obj["pos"]["y"]))

		# 1. Waypoint patrol list
		if obj.has("patrol") and (obj["patrol"] is Array) and obj["patrol"].size() > 1:
			var patrol: Array = obj["patrol"]
			var idx: int = int(obj.get("patrol_index", 0))
			var dir: int = int(obj.get("patrol_dir", 1))

			var next_idx: int = idx + dir
			if next_idx >= patrol.size():
				dir = -1
				next_idx = patrol.size() - 2 if patrol.size() > 1 else 0
			elif next_idx < 0:
				dir = 1
				next_idx = 1 if patrol.size() > 1 else 0

			var next_wp: Dictionary = patrol[next_idx]
			var next_pos: Vector2i = Vector2i(int(next_wp.get("x", current_pos.x)), int(next_wp.get("y", current_pos.y)))

			# Verify waypoint tile is walkable
			if is_tile_walkable(get_tile_at(grid_rows, next_pos)):
				obj["pos"]["x"] = next_pos.x
				obj["pos"]["y"] = next_pos.y
				obj["patrol_index"] = next_idx
				obj["patrol_dir"] = dir

		# 2. Simple linear direction patrol
		elif obj.has("dir"):
			var dir_dict: Dictionary = obj["dir"]
			var move_vec: Vector2i = Vector2i(int(dir_dict.get("x", 0)), int(dir_dict.get("y", 0)))
			var target_pos: Vector2i = current_pos + move_vec

			if is_inside_grid(target_pos, grid_size) and is_tile_walkable(get_tile_at(grid_rows, target_pos)):
				obj["pos"]["x"] = target_pos.x
				obj["pos"]["y"] = target_pos.y
			else:
				# Bounce / reverse direction
				obj["dir"]["x"] = -move_vec.x
				obj["dir"]["y"] = -move_vec.y

## Checks if the given position is fatal (spike, gap, or monster collision).
static func check_hazard_at(pos: Vector2i, tile: String, objects: Array, world: String) -> bool:
	# Spikes 'S', gaps ' ' (empty space) or 'G' are hazards in Dimension A
	if world == "A":
		if tile == "S" or tile == " " or tile == "G":
			return true

	# Check monster collision in Dimension A
	if world == "A":
		for obj in objects:
			if obj.get("type", "") == "monster" and not obj.get("deleted", false):
				var m_pos: Dictionary = obj.get("pos", {})
				if int(m_pos.get("x", -1)) == pos.x and int(m_pos.get("y", -1)) == pos.y:
					return true

	return false
