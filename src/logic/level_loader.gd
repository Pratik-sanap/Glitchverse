class_name LevelLoader
extends RefCounted

## Decoupled Level Loader for Rift Runner.
## Loads and validates level JSON data into typed Dictionaries and Arrays.
## Does not depend on any scenes or rendering nodes.

const REQUIRED_KEYS: Array[String] = [
	"id",
	"planet",
	"startPoints",
	"lives",
	"gridSize",
	"worldA",
	"worldB",
	"objects",
	"parts",
	"portals",
	"puzzle"
]

## Returns the standard Godot resource path for a given level ID.
static func get_level_path(level_id: int) -> String:
	return "res://src/levels/level_%d.json" % level_id

## Loads and parses a level from a file path.
static func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		printerr("[LevelLoader] Level file does not exist: ", path)
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		printerr("[LevelLoader] Failed to open file: ", path, " Error: ", FileAccess.get_open_error())
		return {}

	var content: String = file.get_as_text()
	file.close()

	return parse_and_validate(content)

## Parses and validates raw JSON text directly (used in tests and loaders).
static func parse_and_validate(json_text: String) -> Dictionary:
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_text)
	if error != OK:
		printerr("[LevelLoader] JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return {}

	if not (json.data is Dictionary):
		printerr("[LevelLoader] Root JSON must be a Dictionary.")
		return {}

	var data: Dictionary = json.data
	if not validate_schema(data):
		return {}

	return data

## Validates required keys and structure according to the contract.
static func validate_schema(data: Dictionary) -> bool:
	for key in REQUIRED_KEYS:
		if not data.has(key):
			printerr("[LevelLoader] Missing required key: ", key)
			return false

	# Validate gridSize
	if not (data["gridSize"] is Dictionary) or not data["gridSize"].has("width") or not data["gridSize"].has("height"):
		printerr("[LevelLoader] Invalid gridSize format. Expected {'width': int, 'height': int}.")
		return false

	var width: int = int(data["gridSize"]["width"])
	var height: int = int(data["gridSize"]["height"])

	# Validate worldA rows and columns
	if not (data["worldA"] is Array) or data["worldA"].size() != height:
		printerr("[LevelLoader] worldA row count (%d) does not match gridSize height (%d)." % [data["worldA"].size(), height])
		return false

	for row in data["worldA"]:
		if not (row is String) or (row as String).length() != width:
			printerr("[LevelLoader] A row in worldA has width %d; expected %d." % [(row as String).length(), width])
			return false

	# Validate worldB rows and columns
	if not (data["worldB"] is Array) or data["worldB"].size() != height:
		printerr("[LevelLoader] worldB row count (%d) does not match gridSize height (%d)." % [data["worldB"].size(), height])
		return false

	for row in data["worldB"]:
		if not (row is String) or (row as String).length() != width:
			printerr("[LevelLoader] A row in worldB has width %d; expected %d." % [(row as String).length(), width])
			return false

	# Validate objects list
	if not (data["objects"] is Array):
		printerr("[LevelLoader] objects must be an Array.")
		return false

	# Validate portals list
	if not (data["portals"] is Array):
		printerr("[LevelLoader] portals must be an Array.")
		return false

	# Validate puzzle dictionary
	if not (data["puzzle"] is Dictionary) or not data["puzzle"].has("type") or not data["puzzle"].has("moveLimit"):
		printerr("[LevelLoader] Invalid puzzle configuration.")
		return false

	return true

## Extracts the player starting coordinate ('P') from worldA grid.
## Returns Vector2i(-1, -1) if not found.
static func find_player_start(world_a: Array) -> Vector2i:
	for y in range(world_a.size()):
		var row: String = world_a[y]
		var x: int = row.find("P")
		if x != -1:
			return Vector2i(x, y)
	return Vector2i(-1, -1)
