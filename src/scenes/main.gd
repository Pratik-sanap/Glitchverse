extends Node2D

## Gameplay Scene (res://src/scenes/main.gd)
## Role C: UI, Art, and Presentation Lead.
## Renders the grid, player, hazards, and collectibles cleanly from Game state.
## Interacts strictly via Game autoload actions and signals.

const CELL_SIZE := 72.0
const CELL_GAP := 4.0

# Sci-Fi Cyber Palette
const COLOR_BG := Color("070a13")
const COLOR_GRID_BORDER := Color("1e293b")
const COLOR_HINT_A := Color("38bdf8")
const COLOR_HINT_B := Color("00f0ff")

var _bg_rect: TextureRect
var _board_container: Node2D
var _tiles_container: Node2D
var _fx_container: Node2D
var _player_node: Node2D = null
var _anim_sprite: AnimatedSprite2D = null

var _level_data: Dictionary = {}
var _current_world: String = "A"
var _last_grid_pos: Vector2i = Vector2i(-1, -1)
var _board_origin: Vector2 = Vector2.ZERO
var _grid_width: int = 10
var _grid_height: int = 7

# Top and Bottom quick HUD labels
var _header_label: Label
var _status_label: Label
var _hint_label: Label

func _ready() -> void:
	_setup_background()
	_setup_containers()
	_setup_labels()
	_setup_player()

	# Connect to Game autoload signals
	Game.state_changed.connect(_on_state_changed)
	if Game.has_signal("points_changed"):
		Game.points_changed.connect(_on_points_changed)

	# Fetch initial level data
	_level_data = Game.get_current_level_data()
	if _level_data.is_empty():
		Game.load_level(1)
	else:
		_on_state_changed(Game.get_state())

func _setup_background() -> void:
	_bg_rect = TextureRect.new()
	_bg_rect.name = "Background"
	_bg_rect.z_index = -10
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_rect.size = get_viewport_rect().size

	var bg_texture := _load_bg_texture()
	if bg_texture != null:
		_bg_rect.texture = bg_texture
		# Darken background slightly so grid stands out with high contrast
		_bg_rect.modulate = Color(0.4, 0.45, 0.55, 1.0)
	else:
		_bg_rect.modulate = COLOR_BG

	add_child(_bg_rect)

func _load_bg_texture() -> Texture2D:
	var paths := [
		"res://assets/background.jpg",
		"res://images/player/background.jpg",
		"res://images/player/360_F_1242581090_hM3YlxylRy5gjJi7QBanWrdsghrMf1zH (1).jpg"
	]
	for p in paths:
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
	return null

func _setup_containers() -> void:
	_board_container = Node2D.new()
	_board_container.name = "BoardContainer"
	add_child(_board_container)

	_tiles_container = Node2D.new()
	_tiles_container.name = "TilesContainer"
	_board_container.add_child(_tiles_container)

	_fx_container = Node2D.new()
	_fx_container.name = "FXContainer"
	_fx_container.z_index = 8
	add_child(_fx_container)

func _setup_labels() -> void:
	var vp_size := get_viewport_rect().size

	# Header Title & Dimension Badge
	_header_label = Label.new()
	_header_label.position = Vector2(0, 16)
	_header_label.size = Vector2(vp_size.x, 34)
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 22)
	_header_label.add_theme_color_override("font_color", Color("f8fafc"))
	add_child(_header_label)

	# Stats HUD Label
	_status_label = Label.new()
	_status_label.position = Vector2(0, 52)
	_status_label.size = Vector2(vp_size.x, 28)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color("38bdf8"))
	add_child(_status_label)

	# Bottom Hint / Action Guide
	_hint_label = Label.new()
	_hint_label.position = Vector2(0, vp_size.y - 48)
	_hint_label.size = Vector2(vp_size.x, 32)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 15)
	_hint_label.add_theme_color_override("font_color", Color("94a3b8"))
	add_child(_hint_label)

func _setup_player() -> void:
	var player_scene := _load_player_scene()
	if player_scene != null:
		_player_node = player_scene.instantiate() as Node2D
		_player_node.name = "Player"
		_player_node.scale = Vector2(0.18, 0.18)
		_player_node.z_index = 6
		add_child(_player_node)

		_anim_sprite = _player_node.find_child("AnimatedSprite2D") as AnimatedSprite2D
		if _anim_sprite != null and _anim_sprite.sprite_frames != null:
			if _anim_sprite.sprite_frames.has_animation("Rwalk"):
				_anim_sprite.play("Rwalk")
	else:
		# Procedural fallback astronaut token
		_player_node = Node2D.new()
		_player_node.name = "PlayerFallback"
		_player_node.z_index = 6

		var glow := ColorRect.new()
		glow.size = Vector2(CELL_SIZE - 20, CELL_SIZE - 20)
		glow.position = Vector2(-(CELL_SIZE - 20) * 0.5, -(CELL_SIZE - 20) * 0.5)
		glow.color = Color("38bdf8")
		_player_node.add_child(glow)
		add_child(_player_node)

func _load_player_scene() -> PackedScene:
	if ResourceLoader.exists("res://src/scenes/player.tscn"):
		return load("res://src/scenes/player.tscn")
	if ResourceLoader.exists("res://player.tscn"):
		return load("res://player.tscn")
	return null

func _input(event: InputEvent) -> void:
	var state: Dictionary = Game.get_state()
	if state.get("status", "") != "playing":
		return

	# Keyboard Input
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			var code: int = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode

			if key_event.is_action_pressed("move_up") or code == KEY_UP or code == KEY_W:
				_handle_direction(Vector2i.UP)
			elif key_event.is_action_pressed("move_down") or code == KEY_DOWN or code == KEY_S:
				_handle_direction(Vector2i.DOWN)
			elif key_event.is_action_pressed("move_left") or code == KEY_LEFT or code == KEY_A:
				_handle_direction(Vector2i.LEFT)
			elif key_event.is_action_pressed("move_right") or code == KEY_RIGHT or code == KEY_D:
				_handle_direction(Vector2i.RIGHT)
			elif key_event.is_action_pressed("switch_world") or code == KEY_SPACE:
				Game.switch_world()
			elif key_event.is_action_pressed("skill_1") or code == KEY_1:
				_trigger_primary_skill()
			elif key_event.is_action_pressed("skill_4") or code == KEY_4:
				Game.use_skill("shield", "")

	# Mouse Click to Move (touchpad / mouse friendly)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_mouse_click(mb.position)

func _handle_direction(dir: Vector2i) -> void:
	if dir == Vector2i.LEFT and _anim_sprite != null:
		if _anim_sprite.sprite_frames.has_animation("Lwalk"):
			_anim_sprite.play("Lwalk")
	elif dir == Vector2i.RIGHT and _anim_sprite != null:
		if _anim_sprite.sprite_frames.has_animation("Rwalk"):
			_anim_sprite.play("Rwalk")

	Game.move_player(dir)

func _handle_mouse_click(click_pos: Vector2) -> void:
	var state: Dictionary = Game.get_state()
	var player_pos: Vector2i = Vector2i(int(state["player"]["x"]), int(state["player"]["y"]))

	# Calculate clicked grid coordinate
	var local_pos := click_pos - _board_origin
	if local_pos.x < 0 or local_pos.y < 0:
		return
	var grid_x := int(local_pos.x / CELL_SIZE)
	var grid_y := int(local_pos.y / CELL_SIZE)
	var clicked_tile := Vector2i(grid_x, grid_y)

	# If clicked adjacent tile, move there
	var diff := clicked_tile - player_pos
	if (abs(diff.x) == 1 and diff.y == 0) or (abs(diff.y) == 1 and diff.x == 0):
		_handle_direction(diff)

func _trigger_primary_skill() -> void:
	if _current_world == "B":
		var state: Dictionary = Game.get_state()
		var player_pos: Vector2i = Vector2i(int(state["player"]["x"]), int(state["player"]["y"]))
		var objects: Array = state.get("objects", [])

		var best_target: Dictionary = {}
		var closest_dist: int = 999999

		for obj in objects:
			if not (obj is Dictionary) or obj.get("deleted", false):
				continue
			var obj_world: String = str(obj.get("world", "B"))
			if obj_world != "B":
				continue
			var twin_id: Variant = obj.get("twinId", null)
			if twin_id == null or str(twin_id) == "":
				continue

			var opos: Dictionary = obj.get("pos", {})
			var ox := int(opos.get("x", -999))
			var oy := int(opos.get("y", -999))
			var dist := absi(ox - player_pos.x) + absi(oy - player_pos.y)

			# Must be within 1 tile
			if dist <= 1 and dist < closest_dist:
				closest_dist = dist
				best_target = obj

		if not best_target.is_empty():
			var target_id: String = str(best_target["id"])
			var ok: bool = Game.use_skill("delete", target_id)
			if ok:
				print("[Role C] Deleted twin object: ", target_id)
		else:
			_hint_label.text = "⚠️ NO TWIN OBJECT WITHIN 1 TILE TO DELETE! STEP CLOSER TO AN OBSTACLE."
			_hint_label.add_theme_color_override("font_color", Color("f87171"))
	else:
		Game.use_skill("shield", "")

func _on_state_changed(state: Dictionary) -> void:
	_level_data = Game.get_current_level_data()
	_current_world = state.get("world", "A")
	_redraw_board(state)

func _on_points_changed(new_points: int, delta: int) -> void:
	# Show floating combat text popup
	_spawn_floating_text(delta)

func _redraw_board(state: Dictionary) -> void:
	# Clear previous tiles
	for child in _tiles_container.get_children():
		child.queue_free()

	if _level_data.is_empty():
		return

	var world_key := "worldA" if _current_world == "A" else "worldB"
	var rows: Array = _level_data.get(world_key, [])
	if rows.is_empty():
		return

	var grid_size: Dictionary = _level_data.get("gridSize", {})
	_grid_width = int(grid_size.get("width", 10))
	_grid_height = int(grid_size.get("height", rows.size()))

	var board_pixel_size := Vector2(_grid_width * CELL_SIZE, _grid_height * CELL_SIZE)
	var vp_size := get_viewport_rect().size
	_board_origin = (vp_size - board_pixel_size) * 0.5
	_board_origin.y += 10 # slightly center vertically accounting for HUD

	# Update Top HUD Labels
	var planet_name := str(_level_data.get("planet", "Moon")).to_upper()
	var dimension_badge := "DIMENSION A: REALITY" if _current_world == "A" else "DIMENSION B: SOURCE LAYER (WIREFRAME)"
	var header_color := Color("f8fafc") if _current_world == "A" else Color("00f0ff")

	_header_label.text = "RIFT RUNNER  —  %s  |  %s" % [planet_name, dimension_badge]
	_header_label.add_theme_color_override("font_color", header_color)

	var ep: int = int(state.get("points", 30))
	var lives: int = int(state.get("lives", 3))
	var parts: Dictionary = state.get("parts", {"collected": 0, "total": 1})
	var parts_text := "%d / %d" % [parts.get("collected", 0), parts.get("total", 1)]
	var heart_icons := "❤❤❤".substr(0, maxi(0, lives))

	_status_label.text = "ENERGY: %d EP   |   LIVES: %s   |   SHIP PARTS: %s   |   MOVES: %d" % [
		ep, heart_icons, parts_text, int(state.get("moves", 0))
	]

	# Build Outer Frame
	var frame := ReferenceRect.new()
	frame.position = _board_origin - Vector2(4, 4)
	frame.size = board_pixel_size + Vector2(8, 8)
	frame.border_color = Color("00f0ff") if _current_world == "B" else Color("334155")
	frame.border_width = 3.0
	frame.editor_only = false
	_tiles_container.add_child(frame)

	# Render Individual Grid Tiles
	for y in range(mini(_grid_height, rows.size())):
		var row: String = str(rows[y])
		for x in range(mini(_grid_width, row.length())):
			var tile: String = row[x]
			var cell_pos := _board_origin + Vector2(x * CELL_SIZE, y * CELL_SIZE)
			_draw_tile_cell(tile, cell_pos, Vector2i(x, y))

	# Draw state objects (monsters, pushblocks, targets) on top of tiles
	_draw_objects(state)

	# Update Dynamic Hint Label
	var player_pos: Vector2i = Vector2i(int(state["player"]["x"]), int(state["player"]["y"]))
	_update_hint_text(player_pos, rows)

	# Position Player Smoothly
	_update_player_position(player_pos)

func _draw_objects(state: Dictionary) -> void:
	var objects: Array = state.get("objects", [])
	for obj in objects:
		if not (obj is Dictionary) or obj.get("deleted", false):
			continue
		var obj_world: String = str(obj.get("world", "A"))
		if obj_world != _current_world:
			continue
		var opos: Dictionary = obj.get("pos", {})
		var ox: int = int(opos.get("x", -1))
		var oy: int = int(opos.get("y", -1))
		if ox < 0 or oy < 0:
			continue
		var cell_pos := _board_origin + Vector2(ox * CELL_SIZE, oy * CELL_SIZE)
		var obj_type: String = str(obj.get("type", "")).to_lower()

		var icon_text: String = ""
		var bg_color: Color = Color("00000000")
		var icon_color: Color = Color("ffffff")

		match obj_type:
			"pushblock", "block", "crate":
				bg_color = Color("1d4ed8cc")
				icon_text = "📦"
				icon_color = Color("93c5fd")
			"target":
				bg_color = Color("164e6399")
				icon_text = "🎯"
				icon_color = Color("67e8f9")
			"spike":
				bg_color = Color("450a0acc")
				icon_text = "▲"
				icon_color = Color("ef4444")
			"monster":
				bg_color = Color("7c0b8bcc")
				icon_text = "👾"
				icon_color = Color("e879f9")
			_:
				icon_text = obj_type.substr(0, 1).to_upper()
				bg_color = Color("334155cc")

		# Draw colored background on top of floor tile
		var obj_rect := ColorRect.new()
		obj_rect.position = cell_pos + Vector2(CELL_GAP * 0.5, CELL_GAP * 0.5)
		obj_rect.size = Vector2(CELL_SIZE - CELL_GAP, CELL_SIZE - CELL_GAP)
		obj_rect.color = bg_color
		obj_rect.z_index = 3
		_tiles_container.add_child(obj_rect)

		if icon_text != "":
			var lbl := Label.new()
			lbl.text = icon_text
			lbl.position = cell_pos
			lbl.size = Vector2(CELL_SIZE, CELL_SIZE)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 18)
			lbl.add_theme_color_override("font_color", icon_color)
			lbl.z_index = 4
			_tiles_container.add_child(lbl)

		# Draw a twinId indicator (glow outline) to signal it's a hackable obstacle
		var twin_id: Variant = obj.get("twinId", null)
		if twin_id != null and str(twin_id) != "":
			var twin_border := ReferenceRect.new()
			twin_border.position = cell_pos + Vector2(2, 2)
			twin_border.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
			twin_border.border_color = Color("f97316")
			twin_border.border_width = 2.0
			twin_border.editor_only = false
			twin_border.z_index = 5
			_tiles_container.add_child(twin_border)

func _draw_tile_cell(tile: String, cell_pos: Vector2, grid_coord: Vector2i) -> void:
	var tile_rect := ColorRect.new()
	tile_rect.position = cell_pos + Vector2(CELL_GAP * 0.5, CELL_GAP * 0.5)
	tile_rect.size = Vector2(CELL_SIZE - CELL_GAP, CELL_SIZE - CELL_GAP)

	var icon_text: String = ""
	var icon_color: Color = Color("ffffff")

	# Base tile styling
	if _current_world == "B":
		# Dimension B: Blueprint wireframe cyber aesthetic
		match tile:
			"#": # Wall
				tile_rect.color = Color("0c1a2d")
			".", "P": # Floor
				tile_rect.color = Color("06111e")
			"O": # Portal
				tile_rect.color = Color("083344")
				icon_text = "🌀 PORTAL"
				icon_color = Color("22d3ee")
			"T": # Target in B
				tile_rect.color = Color("164e63")
				icon_text = "🎯 TARGET"
				icon_color = Color("67e8f9")
			"B": # Block in B
				tile_rect.color = Color("1d4ed8")
				icon_text = "📦 BLOCK"
				icon_color = Color("93c5fd")
			_:
				tile_rect.color = Color("06111e")
				icon_text = tile
	else:
		# Dimension A: Reality hazard world
		match tile:
			"#": # Wall
				tile_rect.color = Color("1e293b")
			".", "P": # Floor
				tile_rect.color = Color("0f172a")
			"O": # Portal
				tile_rect.color = Color("083344")
				icon_text = "🌀 PORTAL"
				icon_color = Color("38bdf8")
			"c": # Energy Cell
				tile_rect.color = Color("422006")
				icon_text = "⚡ +5 EP"
				icon_color = Color("facc15")
			"S": # Spike Hazard
				tile_rect.color = Color("450a0a")
				icon_text = "▲ SPIKE"
				icon_color = Color("ef4444")
			"F": # Ship Part
				tile_rect.color = Color("7c2d12")
				icon_text = "⭐ PART"
				icon_color = Color("fb923c")
			"X": # Exit
				tile_rect.color = Color("064e3b")
				icon_text = "🚪 EXIT"
				icon_color = Color("4ade80")
			_:
				tile_rect.color = Color("0f172a")

	_tiles_container.add_child(tile_rect)

	# Add cell inner border for crisp readability
	var border := ReferenceRect.new()
	border.position = tile_rect.position
	border.size = tile_rect.size
	border.border_color = Color("00e5ff33") if _current_world == "B" else Color("33415555")
	border.border_width = 1.0
	border.editor_only = false
	_tiles_container.add_child(border)

	# Label icon if relevant
	if icon_text != "":
		var lbl := Label.new()
		lbl.text = icon_text
		lbl.position = cell_pos
		lbl.size = Vector2(CELL_SIZE, CELL_SIZE)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", icon_color)
		_tiles_container.add_child(lbl)

func _update_hint_text(player_pos: Vector2i, rows: Array) -> void:
	var current_tile := "."
	if player_pos.y >= 0 and player_pos.y < rows.size():
		var row: String = str(rows[player_pos.y])
		if player_pos.x >= 0 and player_pos.x < row.length():
			current_tile = row[player_pos.x]

	if current_tile == "O":
		_hint_label.text = "⚡ YOU ARE STANDING ON A PORTAL! PRESS [SPACEBAR] TO RIFT TO " + ("DIMENSION B" if _current_world == "A" else "DIMENSION A")
		_hint_label.add_theme_color_override("font_color", Color("00f0ff"))
	elif _current_world == "B":
		_hint_label.text = "[DIMENSION B] Press [1] to DELETE obstacle block (-15 EP)  |  Move blocks onto target pads!"
		_hint_label.add_theme_color_override("font_color", Color("38bdf8"))
	else:
		_hint_label.text = "Move: Arrow Keys / WASD / Click Tiles  |  Step on 'O' to enter Portal  |  Collect '⭐ PART' and reach '🚪 EXIT'"
		_hint_label.add_theme_color_override("font_color", Color("94a3b8"))

func _update_player_position(grid_pos: Vector2i) -> void:
	if _player_node == null:
		return

	var target_pixel_pos := _board_origin + Vector2(
		grid_pos.x * CELL_SIZE + CELL_SIZE * 0.5,
		grid_pos.y * CELL_SIZE + CELL_SIZE * 0.5
	)

	if _last_grid_pos == Vector2i(-1, -1) or _player_node.position == Vector2.ZERO:
		_player_node.position = target_pixel_pos
	else:
		# Snappy slide tween for juicy responsiveness
		var tween := create_tween()
		tween.tween_property(_player_node, "position", target_pixel_pos, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_last_grid_pos = grid_pos

func _spawn_floating_text(delta: int) -> void:
	if delta == 0:
		return

	var text := ("+%d EP" if delta > 0 else "%d EP") % delta
	var col := Color("4ade80") if delta > 0 else Color("f87171")

	var lbl := Label.new()
	lbl.text = text
	lbl.position = _player_node.position - Vector2(40, 40) if _player_node != null else Vector2(640, 360)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", col)
	_fx_container.add_child(lbl)

	# Float up and fade out
	var tween := create_tween()
	tween.tween_property(lbl, "position", lbl.position - Vector2(0, 40), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tween.tween_callback(lbl.queue_free)