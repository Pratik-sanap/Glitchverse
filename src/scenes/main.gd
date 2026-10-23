extends Node2D

const CELL_SIZE := 64.0
const CELL_GAP := 3.0

const TILE_COLORS := {
	"#": Color("242d3d"),
	".": Color("151e2a"),
	"P": Color("151e2a"),
	"O": Color("35c9d0"),
	"c": Color("f5d76e"),
	"S": Color("e85d5d"),
	"F": Color("f0a64a"),
	"X": Color("8bd17c"),
	"B": Color("3979b9"),
	"T": Color("55c6d4")
}

var _bg_rect: TextureRect
var _tiles_container: Node2D
var _player_node: Node2D = null
var _anim_sprite: AnimatedSprite2D = null
var _level_data: Dictionary = {}
var _last_player_grid_pos: Vector2i = Vector2i(-1, -1)
var _current_world: String = "A"


func _ready() -> void:
	_setup_background()

	_tiles_container = Node2D.new()
	_tiles_container.name = "TilesContainer"
	add_child(_tiles_container)

	_setup_player()

	Game.state_changed.connect(_on_state_changed)

	_level_data = Game.get_current_level_data()
	if _level_data.is_empty():
		Game.load_level(1)
	else:
		_redraw(Game.get_state())


func _setup_background() -> void:
	_bg_rect = TextureRect.new()
	_bg_rect.name = "Background"
	_bg_rect.z_index = -10
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_rect.size = get_viewport_rect().size

	var bg_tex := _find_background_texture()
	if bg_tex != null:
		_bg_rect.texture = bg_tex
	else:
		_bg_rect.modulate = Color("121620")

	add_child(_bg_rect)


func _find_background_texture() -> Texture2D:
	var candidates: Array[String] = [
		"res://images/player/360_F_1242581090_hM3YlxylRy5gjJi7QBanWrdsghrMf1zH (1).jpg",
		"res://images/player/background.jpg",
		"res://assets/background.jpg",
		"res://images/player/bg.webp",
		"res://images/player/bg.png",
		"res://images/player/bg.jpg"
	]

	for path in candidates:
		if ResourceLoader.exists(path):
			return load(path)

	# Auto-scan images/player/ for any background picture
	var dir := DirAccess.open("res://images/player")
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and not file_name.ends_with(".import") and not file_name.ends_with(".uid"):
				var lower := file_name.to_lower()
				if (lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".png") or lower.ends_with(".webp")):
					if not ("walk" in lower or "jump" in lower):
						var full_path := "res://images/player/" + file_name
						if ResourceLoader.exists(full_path):
							return load(full_path)
			file_name = dir.get_next()
	return null


func _setup_player() -> void:
	var player_scene := _get_player_scene()
	if player_scene != null:
		_player_node = player_scene.instantiate() as Node2D
		_player_node.name = "Player"
		_player_node.scale = Vector2(0.16, 0.16)
		_player_node.z_index = 5
		add_child(_player_node)

		_anim_sprite = _player_node.find_child("AnimatedSprite2D") as AnimatedSprite2D
		if _anim_sprite != null:
			# Play right-walk animation continuously so Nova is visibly moving/animated!
			_anim_sprite.play("Rwalk")
	else:
		# Fallback player box
		_player_node = Node2D.new()
		_player_node.name = "PlayerFallback"
		var rect := ColorRect.new()
		rect.size = Vector2(CELL_SIZE - 20.0, CELL_SIZE - 20.0)
		rect.position = Vector2(-(CELL_SIZE - 20.0) * 0.5, -(CELL_SIZE - 20.0) * 0.5)
		rect.color = Color("f4f7f8")
		_player_node.add_child(rect)
		_player_node.z_index = 5
		add_child(_player_node)


func _get_player_scene() -> PackedScene:
	if ResourceLoader.exists("res://src/scenes/player.tscn"):
		return load("res://src/scenes/player.tscn")
	if ResourceLoader.exists("res://player.tscn"):
		return load("res://player.tscn")
	return null


func _unhandled_input(event: InputEvent) -> void:
	if Game.get_state().get("status", "") != "playing":
		return

	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var code: int = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode

	if key_event.is_action_pressed("move_up") or code == KEY_UP or code == KEY_W:
		_try_move(Vector2i.UP)
	elif key_event.is_action_pressed("move_down") or code == KEY_DOWN or code == KEY_S:
		_try_move(Vector2i.DOWN)
	elif key_event.is_action_pressed("move_left") or code == KEY_LEFT or code == KEY_A:
		_try_move(Vector2i.LEFT)
	elif key_event.is_action_pressed("move_right") or code == KEY_RIGHT or code == KEY_D:
		_try_move(Vector2i.RIGHT)
	elif key_event.is_action_pressed("switch_world") or code == KEY_SPACE:
		Game.switch_world()
	elif key_event.is_action_pressed("skill_1") or code == KEY_1:
		Game.use_skill("delete", "block_1")
	elif key_event.is_action_pressed("skill_4") or code == KEY_4:
		Game.use_skill("shield", "")


func _try_move(dir: Vector2i) -> void:
	if dir == Vector2i.LEFT and _anim_sprite != null:
		_anim_sprite.play("Lwalk")
	elif dir == Vector2i.RIGHT and _anim_sprite != null:
		_anim_sprite.play("Rwalk")

	Game.move_player(dir)



func _on_state_changed(state: Dictionary) -> void:
	_level_data = Game.get_current_level_data()
	_redraw(state)


func _redraw(state: Dictionary) -> void:
	# Clear previous tiles
	for child in _tiles_container.get_children():
		_tiles_container.remove_child(child)
		child.queue_free()

	if _level_data.is_empty():
		return

	_current_world = state.get("world", "A")
	var world_key := "worldA" if _current_world == "A" else "worldB"
	var rows: Array = _level_data.get(world_key, [])
	if rows.is_empty():
		return

	var grid_size: Dictionary = _level_data.get("gridSize", {})
	var width := int(grid_size.get("width", 0))
	var height := int(grid_size.get("height", rows.size()))
	if width <= 0 or height <= 0:
		return

	var board_size := Vector2(width * CELL_SIZE, height * CELL_SIZE)
	var viewport_size := get_viewport_rect().size
	var board_origin := (viewport_size - board_size) * 0.5
	var planet_name := str(_level_data.get("planet", "Unknown Planet"))

	var ep: int = int(state.get("points", 30))
	var lives: int = int(state.get("lives", 3))
	var parts: Dictionary = state.get("parts", {"collected": 0, "total": 1})
	var parts_text := "%d/%d" % [parts.get("collected", 0), parts.get("total", 1)]

	# Header HUD
	_add_label("RIFT RUNNER   /   %s   /   DIMENSION %s" % [planet_name.to_upper(), _current_world], Vector2(0, 18), Vector2(viewport_size.x, 32), 22, Color("e8f1f5"), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("ENERGY POINTS (EP): %d   |   LIVES: %d   |   SHIP PARTS: %s" % [ep, lives, parts_text], Vector2(0, 52), Vector2(viewport_size.x, 26), 16, Color("55c6d4"), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("Move: Arrow Keys or D / Right   |   Portal: Space   |   Skills: 1 (Delete), 4 (Shield)", Vector2(0, board_origin.y + board_size.y + 18), Vector2(viewport_size.x, 28), 15, Color("b0c4de"), HORIZONTAL_ALIGNMENT_CENTER)

	# Render grid tiles
	for y in range(mini(height, rows.size())):
		var row := str(rows[y])
		for x in range(mini(width, row.length())):
			var tile := row.substr(x, 1)
			var cell_position := board_origin + Vector2(x * CELL_SIZE, y * CELL_SIZE)
			var tile_rect := ColorRect.new()
			tile_rect.position = cell_position + Vector2(CELL_GAP, CELL_GAP)
			tile_rect.size = Vector2(CELL_SIZE - CELL_GAP * 2.0, CELL_SIZE - CELL_GAP * 2.0)

			if _current_world == "B":
				var base_col: Color = TILE_COLORS.get(tile, Color("0f2035"))
				tile_rect.color = base_col.lerp(Color("00a8ff"), 0.35)
			else:
				tile_rect.color = TILE_COLORS.get(tile, Color("17232e"))

			_tiles_container.add_child(tile_rect)

			if tile != "." and tile != "P" and tile != "#":
				_add_label(tile, cell_position, Vector2(CELL_SIZE, CELL_SIZE), 22, Color("101820"), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)

	# Update Player Position & Tween Animation
	var player: Dictionary = state.get("player", {})
	var current_player_pos := Vector2i(int(player.get("x", 0)), int(player.get("y", 0)))
	var cell_center := board_origin + Vector2(
		current_player_pos.x * CELL_SIZE + CELL_SIZE * 0.5,
		current_player_pos.y * CELL_SIZE + CELL_SIZE * 0.5
	)

	if _player_node != null:
		if _last_player_grid_pos == Vector2i(-1, -1) or _player_node.position == Vector2.ZERO:
			_player_node.position = cell_center
		else:
			# Smooth slide to new tile
			var tween := create_tween()
			tween.tween_property(_player_node, "position", cell_center, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# Ensure animation continues looping
		if _anim_sprite != null:
			if not _anim_sprite.is_playing():
				_anim_sprite.play("Rwalk")

	_last_player_grid_pos = current_player_pos


func _add_label(text: String, position: Vector2, size: Vector2, font_size: int, color: Color, horizontal_alignment: HorizontalAlignment, vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.horizontal_alignment = horizontal_alignment
	label.vertical_alignment = vertical_alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_tiles_container.add_child(label)