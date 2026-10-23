class_name SyncSystem
extends RefCounted

## Decoupled Dimension Synchronization & Twin Object System for Rift Runner.
## Manages portal transit rules and enforces that edits to objects in Dimension B
## instantly mutate their linked twin in Dimension A.
## Pure GDScript - no scene/drawing dependencies.

const GridSystemScript = preload("res://src/logic/grid_system.gd")

## Checks if the player is currently standing on a valid portal tile or coordinate.
static func is_on_portal(player_pos: Vector2i, portals: Array, grid_rows: Array) -> bool:
	# 1. Check tile character at position
	var tile: String = GridSystemScript.get_tile_at(grid_rows, player_pos)
	if tile == "O":
		return true

	# 2. Check portals list from level JSON
	for p in portals:
		if p is Dictionary:
			if int(p.get("x", -1)) == player_pos.x and int(p.get("y", -1)) == player_pos.y:
				return true

	return false

## Finds an object by its unique ID in the objects array.
static func find_object(objects: Array, obj_id: String) -> Dictionary:
	for obj in objects:
		if obj is Dictionary and obj.get("id", "") == obj_id:
			return obj
	return {}

## Finds the twin object in the alternate world.
## Matches via obj["twinId"], or searches for an object whose twinId points to obj_id.
static func find_twin(objects: Array, obj_id: String) -> Dictionary:
	var source: Dictionary = find_object(objects, obj_id)
	if not source.is_empty() and source.has("twinId") and str(source["twinId"]) != "":
		var target_twin_id: String = str(source["twinId"])
		var direct_twin: Dictionary = find_object(objects, target_twin_id)
		if not direct_twin.is_empty():
			return direct_twin

	# Reverse lookup: find object whose twinId matches obj_id
	for obj in objects:
		if obj is Dictionary and str(obj.get("twinId", "")) == obj_id:
			return obj

	return {}

## Applies a Delete edit in Dimension B, synchronizing the twin in Dimension A.
## Clears matching hazard/obstacle tiles in worldA.
static func sync_delete(objects: Array, target_id: String, world_a_grid: Array) -> bool:
	var target: Dictionary = find_object(objects, target_id)
	if target.is_empty() or target.get("deleted", false):
		return false

	target["deleted"] = true

	# Sync twin in A
	var twin: Dictionary = find_twin(objects, target_id)
	if not twin.is_empty():
		twin["deleted"] = true
		var tpos: Dictionary = twin.get("pos", {})
		var pos_vec: Vector2i = Vector2i(int(tpos.get("x", -1)), int(tpos.get("y", -1)))

		# If twin was a spike or obstacle tile in worldA, clear it to floor '.'
		var tile_in_a: String = GridSystemScript.get_tile_at(world_a_grid, pos_vec)
		if tile_in_a == "S" or tile_in_a == "#":
			GridSystemScript.set_tile_at(world_a_grid, pos_vec, ".")

	return true

## Applies a Move edit in Dimension B, synchronizing the twin's position in Dimension A.
static func sync_move(objects: Array, target_id: String, new_pos: Vector2i) -> bool:
	var target: Dictionary = find_object(objects, target_id)
	if target.is_empty() or target.get("deleted", false):
		return false

	target["pos"]["x"] = new_pos.x
	target["pos"]["y"] = new_pos.y

	# Sync twin in A
	var twin: Dictionary = find_twin(objects, target_id)
	if not twin.is_empty():
		twin["pos"]["x"] = new_pos.x
		twin["pos"]["y"] = new_pos.y

	return true

## Applies a Duplicate edit in Dimension B, creating a copy in B and a synchronized twin in A.
## If filling a gap in worldA, converts gap ' ' or 'G' into bridge floor '.'.
static func sync_duplicate(objects: Array, target_id: String, new_pos: Vector2i, world_a_grid: Array) -> Dictionary:
	var source: Dictionary = find_object(objects, target_id)
	if source.is_empty() or source.get("deleted", false):
		return {}

	var new_b_id: String = target_id + "_copy_" + str(objects.size())
	var new_a_id: String = new_b_id + "_twin"

	var copy_b: Dictionary = {
		"id": new_b_id,
		"type": source.get("type", "block"),
		"pos": {"x": new_pos.x, "y": new_pos.y},
		"twinId": new_a_id,
		"world": "B",
		"deleted": false
	}

	var copy_a: Dictionary = {
		"id": new_a_id,
		"type": source.get("type", "block"),
		"pos": {"x": new_pos.x, "y": new_pos.y},
		"twinId": new_b_id,
		"world": "A",
		"deleted": false
	}

	objects.append(copy_b)
	objects.append(copy_a)

	# If duplicating over a gap in worldA, bridge it to '.'
	var tile_in_a: String = GridSystemScript.get_tile_at(world_a_grid, new_pos)
	if tile_in_a == " " or tile_in_a == "G":
		GridSystemScript.set_tile_at(world_a_grid, new_pos, ".")

	return copy_b
