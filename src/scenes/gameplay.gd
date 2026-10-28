## gameplay.gd — Presentation and rendering layer for levels.
## Role C owns this file. No game rules or physics logic here.
## Reads level geometry from JSON and synchronizes visuals with Game state.
extends Node2D

# ── References & Containers ─────────────────────────────────
var _level_data: Dictionary = {}
var _level_id: int = 1
var _current_world: String = "A"
var _spawn_pos: Vector2 = Vector2(100, 500)

var _world_root: Node2D
var _platforms_container: Node2D
var _portals_container: Node2D
var _entities_a_container: Node2D
var _entities_b_container: Node2D
var _player_node: Node2D
var _player_visual: Node2D
var _player_sprite: Sprite2D
var _player_velocity_x: float = 0.0
var _player_on_ground: bool = false
var _player_animation_time: float = 0.0
var _camera: Camera2D
var _shield_visual: Node2D
var _bg_rect_a: TextureRect
var _bg_rect_b: TextureRect

const PLAYER_SPRITE_PATH: String = "res://assets/sprites/Firefly.png"
const PLAYER_SHEET_COLUMNS: int = 4
const PLAYER_SHEET_ROWS: int = 7
const PLAYER_WALK_ROW: int = 2
const PLAYER_WALK_FPS: float = 10.0

# Entity ID -> Node2D lookup for fast positional updates
var _entity_nodes: Dictionary = {}
var _portal_sprites: Array[Sprite2D] = []
var _exit_nodes: Array[Node2D] = []

# Audio
var _audio_mgr: Node

# In-Game Pause Menu
var _pause_menu: Node = null
var _pause_canvas: CanvasLayer = null


func _ready() -> void:
	# Check if Game already has an active level ID, or read from GameProgress
	var initial_state: Dictionary = Game.get_state()
	_level_id = initial_state.get("level_id", GameProgress.selected_level)
	if _level_id <= 0:
		_level_id = 1
	
	_load_level_file(_level_id)
	_build_scene_hierarchy()
	_populate_level_geometry()
	
	# Attach HUD overlay
	var hud_scene: PackedScene = load("res://src/ui/hud.tscn")
	if hud_scene:
		var hud_node: Node = hud_scene.instantiate()
		if hud_node.has_signal("pause_requested"):
			hud_node.pause_requested.connect(_on_pause_requested)
		add_child(hud_node)

	# Attach Touch Controls overlay (for mobile & touch devices)
	var touch_scene: PackedScene = load("res://src/ui/touch_controls.tscn")
	if touch_scene:
		var touch_node: Node = touch_scene.instantiate()
		add_child(touch_node)

	# Attach Audio Manager
	var audio_script: GDScript = load("res://src/scenes/audio_manager.gd")
	if audio_script:
		_audio_mgr = audio_script.new()
		_audio_mgr.name = "AudioManager"
		add_child(_audio_mgr)
	
	# Connect to logic signals
	if not Game.state_changed.is_connected(_on_state_changed):
		Game.state_changed.connect(_on_state_changed)
	if not Game.level_cleared.is_connected(_on_level_cleared):
		Game.level_cleared.connect(_on_level_cleared)
	if not Game.game_over.is_connected(_on_game_over):
		Game.game_over.connect(_on_game_over)
	
	# Request Game to load the level
	Game.load_level(_level_id)
	
	# Initial draw sync
	_on_state_changed()


func _process(delta: float) -> void:
	_update_player_animation(delta)
	_feed_input_to_game()

	# Visual flash during invulnerability frames (after shield pop or respawn)
	var state: Dictionary = Game.get_state()
	var inv_timer: float = float(state.get("invulnerable_timer", 0.0))
	if inv_timer > 0.0 and _player_visual:
		_player_visual.modulate.a = 0.35 if int(Time.get_ticks_msec() / 100) % 2 == 0 else 1.0
	elif _player_visual:
		_player_visual.modulate.a = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_P:
			_toggle_pause()
			get_viewport().set_input_as_handled()


func _update_player_animation(delta: float) -> void:
	if _player_sprite == null:
		return

	var frame_index: int = 0
	if _player_on_ground and absf(_player_velocity_x) > 10.0:
		_player_animation_time += delta
		frame_index = int(_player_animation_time * PLAYER_WALK_FPS) % PLAYER_SHEET_COLUMNS
	else:
		_player_animation_time = 0.0

	_player_sprite.frame_coords = Vector2i(frame_index, PLAYER_WALK_ROW)


# ── INPUT FEEDING ───────────────────────────────────────────
func _feed_input_to_game() -> void:
	# 1. Horizontal movement
	var move_axis: float = Input.get_axis("move_left", "move_right")
	Game.set_move(move_axis)
	
	# 2. Jump
	if Input.is_action_just_pressed("jump"):
		Game.jump(true)
		if _audio_mgr:
			_audio_mgr.play_jump()
	elif Input.is_action_just_released("jump"):
		Game.jump(false)
	
	# 3. Dimensional Rift switch
	if Input.is_action_just_pressed("switch_world"):
		Game.switch_world()
	
	# 4. Skills (1: Delete, 2: Duplicate, 3: Move, 4: Shield)
	if Input.is_action_just_pressed("skill_1"):
		var target: String = _find_nearest_target("delete")
		Game.use_skill("delete", target)
		if _audio_mgr:
			_audio_mgr.play_skill()
	elif Input.is_action_just_pressed("skill_2"):
		var target: String = _find_nearest_target("duplicate")
		Game.use_skill("duplicate", target)
		if _audio_mgr:
			_audio_mgr.play_skill()
	elif Input.is_action_just_pressed("skill_3"):
		var target: String = _find_nearest_target("move")
		Game.use_skill("move", target)
		if _audio_mgr:
			_audio_mgr.play_skill()
	elif Input.is_action_just_pressed("skill_4"):
		Game.use_skill("shield", "")
		if _audio_mgr:
			_audio_mgr.play_skill()


func _find_nearest_target(skill_name: String) -> String:
	var nearest_id: String = ""
	var nearest_dist: float = Config.SKILL_RANGE
	var player_pos: Vector2 = _player_node.position
	
	var entities: Array = _level_data.get("entities", [])
	for ent in entities:
		if not (ent is Dictionary):
			continue
		var ent_dict: Dictionary = ent
		if ent_dict.get("world", "") != _current_world:
			continue
		
		# In Dimension B, skills act on editBlock entities
		if _current_world == "B" and ent_dict.get("type", "") == "editBlock":
			var target_skill: String = ent_dict.get("skill", "")
			if target_skill == skill_name:
				var ex: float = float(ent_dict.get("x", 0.0))
				var ey: float = float(ent_dict.get("y", 0.0))
				var ew: float = float(ent_dict.get("w", 32.0))
				var eh: float = float(ent_dict.get("h", 32.0))
				var closest_x: float = clampf(player_pos.x, ex, ex + ew)
				var closest_y: float = clampf(player_pos.y, ey, ey + eh)
				var dist: float = player_pos.distance_to(Vector2(closest_x, closest_y))
				if dist <= nearest_dist:
					nearest_dist = dist
					nearest_id = str(ent_dict.get("id", ""))
	
	return nearest_id


# ── STATE SYNCHRONIZATION ───────────────────────────────────
func _on_state_changed() -> void:
	var state: Dictionary = Game.get_state()
	if state.is_empty():
		# Logic layer has not populated state yet; retain defaults
		return
	
	# 1. Update player position & facing
	if state.has("player"):
		var p: Dictionary = state["player"]
		var px: float = p.get("x", _spawn_pos.x)
		var py: float = p.get("y", _spawn_pos.y)
		_player_node.position = Vector2(px, py)
		_player_velocity_x = float(p.get("vx", 0.0))
		_player_on_ground = bool(p.get("on_ground", false))
		
		var facing: float = p.get("facing", 1.0)
		if facing != 0.0:
			_player_visual.scale.x = 1.0 if facing > 0.0 else -1.0

	# Update shield visual visibility
	if _shield_visual:
		_shield_visual.visible = bool(state.get("shielded", false))
	
	# 2. Update active dimension
	if state.has("world"):
		var new_world: String = state["world"]
		if new_world != _current_world:
			_current_world = new_world
			_apply_world_appearance()
	
	# 3. Update dynamic entity states (e.g. collected items, removed blocks, dynamically created bridges)
	if state.has("entities"):
		var state_entities: Array = state["entities"]
		for ent in state_entities:
			if not (ent is Dictionary):
				continue
			var ent_dict: Dictionary = ent
			var eid: String = str(ent_dict.get("id", ""))
			
			# Create visual node if it was dynamically spawned in logic (e.g. duplicate bridge wall)
			if not _entity_nodes.has(eid):
				var new_node: Node2D = _create_entity_visual(ent_dict)
				_entity_nodes[eid] = new_node
				if ent_dict.get("world", "A") == "B":
					_entities_b_container.add_child(new_node)
				else:
					_entities_a_container.add_child(new_node)
			
			var node: Node2D = _entity_nodes[eid]
			# Position update if moved
			if ent_dict.has("x") and ent_dict.has("y"):
				node.position = Vector2(ent_dict["x"], ent_dict["y"])
				
			# Visibility based on deleted/collected status
			var is_inactive: bool = ent_dict.get("collected", false) or ent_dict.get("deleted", false)
			node.visible = (not is_inactive) and (ent_dict.get("world", "A") == _current_world)

			# Monster horizontal flip based on patrol direction
			if ent_dict.get("type", "") == "monster":
				var m_vis: Node2D = node.get_node_or_null("MonsterVisual")
				if m_vis:
					var cur_x: float = float(ent_dict.get("x", node.position.x))
					var last_x: float = float(node.get_meta("last_x", cur_x))
					var dx: float = cur_x - last_x
					var cur_facing: float = float(node.get_meta("facing", 1.0))
					if dx > 0.05 or float(ent_dict.get("vx", 0.0)) > 0.05:
						cur_facing = 1.0
					elif dx < -0.05 or float(ent_dict.get("vx", 0.0)) < -0.05:
						cur_facing = -1.0
					elif ent_dict.has("facing"):
						cur_facing = float(ent_dict["facing"])
					node.set_meta("facing", cur_facing)
					node.set_meta("last_x", cur_x)
					m_vis.scale.x = cur_facing
			
			# Dynamic visual updates (e.g. editBlock becoming duplicated)
			if ent_dict.get("type", "") == "editBlock" and ent_dict.get("duplicated", false):
				var bg_rect: ColorRect = node.get_node_or_null("Background")
				if bg_rect:
					bg_rect.color = Color(0.06, 0.38, 0.2, 0.9)
				var border_top: ColorRect = node.get_node_or_null("BorderTop")
				if border_top:
					border_top.color = Color(0.1, 1.0, 0.6, 1.0)
				var elbl: Label = node.get_node_or_null("Label")
				if elbl:
					elbl.text = "✓ BRIDGE DUPLICATED — ACTIVE IN REALITY [A]"
					elbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.75))
	
	# 4. Update exit readiness visual (dimmed 0.5 alpha until all parts collected)
	var parts_info: Dictionary = state.get("parts", {})
	var total_parts: int = int(parts_info.get("total", _level_data.get("parts", 1)))
	var collected_parts: int = int(parts_info.get("collected", 0))
	var has_all_parts: bool = (collected_parts >= total_parts and total_parts > 0)
	for enode in _exit_nodes:
		if is_instance_valid(enode):
			enode.modulate.a = 1.0 if has_all_parts else 0.5


func _apply_world_appearance() -> void:
	# World A entities visible in Reality, World B in Source Layer
	_entities_a_container.visible = (_current_world == "A")
	_entities_b_container.visible = (_current_world == "B")
	
	if _bg_rect_a:
		_bg_rect_a.visible = (_current_world == "A")
	if _bg_rect_b:
		_bg_rect_b.visible = (_current_world == "B")

	# In Dimension B tint portal cyan (modulate)
	for psp in _portal_sprites:
		if is_instance_valid(psp):
			psp.modulate = Color(0.2, 0.9, 1.0, 1.0) if _current_world == "B" else Color(1.0, 1.0, 1.0, 1.0)


# ── LEVEL LOADING & GENERATION ──────────────────────────────
func _load_level_file(id: int) -> void:
	var path: String = "res://src/levels/level_%d.json" % id
	if not FileAccess.file_exists(path):
		push_warning("Level file not found: %s" % path)
		return
	
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open level file: %s" % path)
		return
	
	var text: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_level_data = parsed
	else:
		push_error("Invalid JSON in level file: %s" % path)


func _build_scene_hierarchy() -> void:
	# Root container for in-world elements
	_world_root = Node2D.new()
	_world_root.name = "WorldRoot"
	add_child(_world_root)
	
	var level_size: Dictionary = _level_data.get("levelSize", {"w": 2400, "h": 720})
	var lw: float = float(level_size.get("w", 2400))
	var lh: float = float(level_size.get("h", 720))
	
	# Background
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.05, 0.07, 0.11, 1.0) # Deep lunar cosmic dark
	bg.position = Vector2(0, 0)
	bg.size = Vector2(lw, lh)
	_world_root.add_child(bg)

	# Dynamic background art from teammate if available
	var planet_name: String = str(_level_data.get("planet", "Moon")).to_lower().replace(" ", "_")
	var is_moon: bool = (_level_id == 1 or planet_name == "moon")
	var is_mars: bool = (_level_id == 2 or planet_name == "mars")
	var is_europa: bool = (_level_id == 3 or planet_name == "europa")
	var is_glitch_core: bool = (_level_id == 4 or "glitch" in planet_name)
	
	# Dimension A background (Reality)
	var bg_paths_a: Array[String] = []
	if is_moon:
		bg_paths_a.append("res://assets/art/bg/Cratered Moonset Over Alien Wasteland.png")
	elif is_mars:
		bg_paths_a.append("res://assets/art/bg/Crimson Planet Over Alien Canyon.png")
	elif is_europa:
		bg_paths_a.append("res://assets/art/bg/level3.png")
		bg_paths_a.append("res://assets/art/bg/level_3.png")
	elif is_glitch_core:
		bg_paths_a.append("res://assets/art/bg/Level4.png")
		bg_paths_a.append("res://assets/art/bg/level4.png")
		bg_paths_a.append("res://assets/art/bg/level_4.png")
	bg_paths_a.append("res://assets/art/bg/bg_%s_a.png" % planet_name)
	bg_paths_a.append("res://assets/art/bg/bg_%s.png" % planet_name)
	bg_paths_a.append("res://assets/sprites/bg_%s.png" % planet_name)
	bg_paths_a.append("res://assets/sprites/bg_level_%d.png" % _level_id)
	bg_paths_a.append("res://assets/sprites/background.png")
	
	var bg_tex_a: Texture2D = _try_load_texture(bg_paths_a)
	if bg_tex_a:
		_bg_rect_a = TextureRect.new()
		_bg_rect_a.name = "BackgroundA"
		_bg_rect_a.texture = bg_tex_a
		_bg_rect_a.size = Vector2(lw, lh)
		_bg_rect_a.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bg_rect_a.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_world_root.add_child(_bg_rect_a)
	
	# Dimension B background (Source Layer / Glitchscape)
	var bg_paths_b: Array[String] = []
	if is_moon:
		bg_paths_b.append("res://assets/art/bg/Cosmic Glitchscape_ Fractured Moon Horizon.png")
	elif is_mars:
		bg_paths_b.append("res://assets/art/bg/Glitched Mars Dimension at Sunset.png")
	elif is_europa:
		bg_paths_b.append("res://assets/art/bg/glitchedLevel3.png")
		bg_paths_b.append("res://assets/art/bg/glitched_level_3.png")
	elif is_glitch_core:
		bg_paths_b.append("res://assets/art/bg/glitchedLevel4.png")
		bg_paths_b.append("res://assets/art/bg/glitched_level_4.png")
	bg_paths_b.append("res://assets/art/bg/bg_%s_b.png" % planet_name)
	bg_paths_b.append("res://assets/sprites/bg_%s_b.png" % planet_name)
	bg_paths_b.append("res://assets/sprites/bg_glitch.png")
	
	var bg_tex_b: Texture2D = _try_load_texture(bg_paths_b)
	if bg_tex_b:
		_bg_rect_b = TextureRect.new()
		_bg_rect_b.name = "BackgroundB"
		_bg_rect_b.texture = bg_tex_b
		_bg_rect_b.size = Vector2(lw, lh)
		_bg_rect_b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bg_rect_b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_bg_rect_b.visible = false
		_world_root.add_child(_bg_rect_b)
	
	# Containers
	_platforms_container = Node2D.new()
	_platforms_container.name = "Platforms"
	_world_root.add_child(_platforms_container)
	
	_portals_container = Node2D.new()
	_portals_container.name = "Portals"
	_world_root.add_child(_portals_container)
	
	_entities_a_container = Node2D.new()
	_entities_a_container.name = "EntitiesA"
	_world_root.add_child(_entities_a_container)
	
	_entities_b_container = Node2D.new()
	_entities_b_container.name = "EntitiesB"
	_world_root.add_child(_entities_b_container)
	
	# Player Node with Nova placeholder
	_player_node = Node2D.new()
	_player_node.name = "Player"
	var spawn: Dictionary = _level_data.get("spawn", {"x": 100, "y": 500})
	_spawn_pos = Vector2(float(spawn.get("x", 100)), float(spawn.get("y", 500)))
	_player_node.position = _spawn_pos
	_world_root.add_child(_player_node)
	
	_player_visual = _create_player_visual()
	_player_node.add_child(_player_visual)

	# Shield Aura Visual
	var shield_script: GDScript = load("res://src/scenes/shield_effect.gd")
	if shield_script:
		_shield_visual = shield_script.new()
		_shield_visual.name = "ShieldVisual"
		_shield_visual.position = Vector2(0, -24)
		_shield_visual.visible = false
		_player_node.add_child(_shield_visual)
	
	# Camera2D
	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(lw)
	_camera.limit_bottom = int(lh)
	_player_node.add_child(_camera)


func _populate_level_geometry() -> void:
	var planet_name: String = str(_level_data.get("planet", "Moon")).to_lower().replace(" ", "_")
	var tile_tex: Texture2D = _try_load_texture([
		"res://assets/sprites/tile_%s.png" % planet_name,
		"res://assets/sprites/tile_level_%d.png" % _level_id,
		"res://assets/sprites/platform.png",
		"res://assets/sprites/tile.png"
	])

	# 1. Platforms
	var platforms: Array = _level_data.get("platforms", [])
	for p in platforms:
		if not (p is Dictionary):
			continue
		var plat: Dictionary = p
		var px: float = float(plat.get("x", 0))
		var py: float = float(plat.get("y", 0))
		var pw: float = float(plat.get("w", 100))
		var ph: float = float(plat.get("h", 20))
		
		if tile_tex:
			var patch: NinePatchRect = NinePatchRect.new()
			patch.texture = tile_tex
			patch.position = Vector2(px, py)
			patch.size = Vector2(pw, ph)
			patch.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
			patch.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
			_platforms_container.add_child(patch)
		else:
			var plat_rect: ColorRect = ColorRect.new()
			plat_rect.color = Color(0.24, 0.27, 0.35, 1.0) # Slate moon rock
			plat_rect.position = Vector2(px, py)
			plat_rect.size = Vector2(pw, ph)
			
			# Top highlight trim
			var trim: ColorRect = ColorRect.new()
			trim.color = Color(0.42, 0.48, 0.60, 1.0)
			trim.position = Vector2(0, 0)
			trim.size = Vector2(pw, 3)
			plat_rect.add_child(trim)
			
			_platforms_container.add_child(plat_rect)
	
	# 2. Portals
	_portal_sprites.clear()
	_exit_nodes.clear()
	var portal_tex: Texture2D = _try_load_texture([
		"res://assets/art/world/portal.png",
		"res://assets/art/world/rift.png",
		"res://assets/sprites/rift.png",
		"res://assets/sprites/portal.png",
		"res://assets/sprites/dimensional_rift.png"
	])
	var portals: Array = _level_data.get("portals", [])
	for p in portals:
		if not (p is Dictionary):
			continue
		var port: Dictionary = p
		var px: float = float(port.get("x", 0))
		var py: float = float(port.get("y", 0))
		var pw: float = float(port.get("w", 120))
		var ph: float = float(port.get("h", 160))
		
		var portal_node: Node2D = Node2D.new()
		portal_node.position = Vector2(px, py)
		
		if portal_tex:
			var glow: ColorRect = ColorRect.new()
			glow.color = Color(0.65, 0.2, 0.95, 0.25)
			glow.size = Vector2(pw + 16, ph + 16)
			glow.position = Vector2(-8, -8)
			portal_node.add_child(glow)

			var sp: Sprite2D = Sprite2D.new()
			sp.texture = portal_tex
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var tsize: Vector2 = portal_tex.get_size()
			var s0: Vector2 = Vector2(160.0 / tsize.x, 160.0 / tsize.y) if (tsize.x > 0 and tsize.y > 0) else Vector2(0.5, 0.5)
			sp.scale = s0
			# Centered horizontally on the zone (pw * 0.5), bottom-aligned to the zone's bottom edge (ph - 80.0)
			sp.position = Vector2(pw * 0.5, ph - 80.0)
			portal_node.add_child(sp)
			_portal_sprites.append(sp)

			# Pulse scale between 1.0 and 1.05 over 1.5 seconds with a Tween
			var start_pulse: Callable = func() -> void:
				if not is_instance_valid(sp) or not sp.is_inside_tree():
					return
				var tween: Tween = sp.create_tween()
				tween.set_loops()
				tween.tween_property(sp, "scale", s0 * 1.05, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				tween.tween_property(sp, "scale", s0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

			if sp.is_inside_tree():
				start_pulse.call()
			else:
				sp.tree_entered.connect(start_pulse)
		else:
			var portal_bg: ColorRect = ColorRect.new()
			portal_bg.color = Color(0.6, 0.2, 0.9, 0.35) # Glowing dimensional rift
			portal_bg.size = Vector2(pw, ph)
			portal_node.add_child(portal_bg)
			
			var portal_label: Label = Label.new()
			portal_label.text = "DIMENSIONAL\nRIFT\n[F]"
			portal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			portal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			portal_label.position = Vector2(0, 0)
			portal_label.size = Vector2(pw, ph)
			portal_label.add_theme_font_size_override("font_size", 14)
			portal_node.add_child(portal_label)
		
		_portals_container.add_child(portal_node)
	
	# 3. Entities
	var entities: Array = _level_data.get("entities", [])
	for e in entities:
		if not (e is Dictionary):
			continue
		var ent: Dictionary = e
		var ent_node: Node2D = _create_entity_visual(ent)
		var eid: String = str(ent.get("id", ""))
		_entity_nodes[eid] = ent_node
		
		if ent.get("world", "A") == "B":
			_entities_b_container.add_child(ent_node)
		else:
			_entities_a_container.add_child(ent_node)

		# If this entity is a duplicate bridge block in B, pre-register the World A bridge wall node!
		if ent.get("type", "") == "editBlock" and str(ent.get("skill", "")) == "duplicate":
			var dup_wall_id: String = "dup_wall_" + eid
			var bridge_dict: Dictionary = {
				"id": dup_wall_id,
				"type": "wall",
				"world": "A",
				"x": ent.get("x", 0),
				"y": ent.get("y", 0),
				"w": ent.get("w", 32),
				"h": ent.get("h", 32),
				"active": false,
				"deleted": true
			}
			var bridge_node: Node2D = _create_entity_visual(bridge_dict)
			bridge_node.visible = false
			_entity_nodes[dup_wall_id] = bridge_node
			_entities_a_container.add_child(bridge_node)
	
	_apply_world_appearance()


func _create_player_visual() -> Node2D:
	var visual: Node2D = Node2D.new()
	visual.name = "Visual"
	
	if ResourceLoader.exists(PLAYER_SPRITE_PATH):
		var sprite_texture: Texture2D = load(PLAYER_SPRITE_PATH) as Texture2D
		if sprite_texture:
			_player_sprite = Sprite2D.new()
			_player_sprite.name = "Astronaut"
			_player_sprite.texture = sprite_texture
			_player_sprite.hframes = PLAYER_SHEET_COLUMNS
			_player_sprite.vframes = PLAYER_SHEET_ROWS
			_player_sprite.frame_coords = Vector2i(0, PLAYER_WALK_ROW)
			_player_sprite.position = Vector2(0, -36)
			_player_sprite.scale = Vector2(0.3, 0.3)
			_player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			visual.add_child(_player_sprite)
			return visual
	
	var pw: float = Config.PLAYER_WIDTH
	var ph: float = Config.PLAYER_HEIGHT
	var half_w: float = pw * 0.5
	
	# Oxygen Backpack (on back)
	var pack: ColorRect = ColorRect.new()
	pack.color = Color(0.7, 0.75, 0.8)
	pack.position = Vector2(-half_w - 4, -ph + 12)
	pack.size = Vector2(6, 24)
	visual.add_child(pack)
	
	# Suit Body
	var body: ColorRect = ColorRect.new()
	body.color = Color(0.92, 0.94, 0.98) # Bright white spacesuit
	body.position = Vector2(-half_w, -ph)
	body.size = Vector2(pw, ph)
	visual.add_child(body)
	
	# Visor (glowing cyan)
	var visor: ColorRect = ColorRect.new()
	visor.color = Color(0.0, 0.85, 1.0)
	visor.position = Vector2(-half_w + 10, -ph + 6)
	visor.size = Vector2(16, 12)
	visual.add_child(visor)
	
	# Belt / trim
	var trim: ColorRect = ColorRect.new()
	trim.color = Color(0.2, 0.4, 0.7)
	trim.position = Vector2(-half_w, -ph + 26)
	trim.size = Vector2(pw, 4)
	visual.add_child(trim)
	
	return visual


func _try_load_texture(paths: Array[String]) -> Texture2D:
	for p in paths:
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
		elif FileAccess.file_exists(p):
			var img: Image = Image.load_from_file(ProjectSettings.globalize_path(p))
			if img:
				return ImageTexture.create_from_image(img)
	return null


func _create_entity_visual(ent: Dictionary) -> Node2D:
	var node: Node2D = Node2D.new()
	var eid: String = str(ent.get("id", "entity"))
	node.name = eid
	node.position = Vector2(float(ent.get("x", 0)), float(ent.get("y", 0)))
	
	var etype: String = str(ent.get("type", ""))
	var ew: float = float(ent.get("w", 32))
	var eh: float = float(ent.get("h", 32))
	
	match etype:
		"spike":
			# Faint red glow underneath so the hazard reads clearly against the blue Dimension B tint
			var glow: ColorRect = ColorRect.new()
			glow.color = Color(1.0, 0.15, 0.15, 0.3)
			glow.size = Vector2(ew, eh + 4)
			glow.position = Vector2(0, -2)
			node.add_child(glow)

			var tex: Texture2D = _try_load_texture([
				"res://assets/art/world/spike_tile.png",
				"res://assets/art/world/spike.png",
				"res://assets/sprites/spike.png",
				"res://assets/sprites/spikes.png"
			])
			if tex:
				var tsize: Vector2 = tex.get_size()
				var tile_w: float = 165.0
				var tile_h: float = 64.0
				var scale_x: float = tile_w / tsize.x if tsize.x > 0 else 0.5
				var scale_y: float = tile_h / tsize.y if tsize.y > 0 else 0.5

				# Container with clip_contents = true clips any excess width of the last tile at the right edge
				var clip_container: Control = Control.new()
				clip_container.clip_contents = true
				clip_container.size = Vector2(ew, eh)
				clip_container.position = Vector2(0, 0)
				node.add_child(clip_container)

				var count: int = maxi(1, int(ceil(ew / tile_w)))
				for i in range(count):
					var sp: Sprite2D = Sprite2D.new()
					sp.texture = tex
					sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
					sp.scale = Vector2(scale_x, scale_y)
					# Bottom-aligned to entity bottom edge (eh)
					sp.position = Vector2(i * tile_w + tile_w * 0.5, eh - tile_h * 0.5)
					clip_container.add_child(sp)
			else:
				var rect: ColorRect = ColorRect.new()
				rect.color = Color(0.9, 0.2, 0.2, 0.9)
				rect.size = Vector2(ew, eh)
				node.add_child(rect)
				
				var lbl: Label = Label.new()
				lbl.text = "▲▲▲"
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.size = Vector2(ew, eh)
				lbl.add_theme_font_size_override("font_size", 22)
				node.add_child(lbl)
			
		"pit":
			var rect: ColorRect = ColorRect.new()
			rect.color = Color(0.6, 0.05, 0.05, 0.4)
			rect.size = Vector2(ew, eh)
			node.add_child(rect)
			
			var lbl: Label = Label.new()
			lbl.text = "PIT"
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.size = Vector2(ew, eh)
			node.add_child(lbl)
			
		"wall":
			var is_bridge: bool = eid.begins_with("dup_wall") or eid.contains("bridge")
			if is_bridge:
				# ── QUANTUM HARD-LIGHT BRIDGE ───────────────────────────
				# 1. Outer ambient energy glow
				var glow: ColorRect = ColorRect.new()
				glow.name = "Glow"
				glow.color = Color(0.0, 0.9, 1.0, 0.25)
				glow.size = Vector2(ew, eh + 8)
				glow.position = Vector2(0, -4)
				node.add_child(glow)

				# 2. Translucent energy body
				var body: ColorRect = ColorRect.new()
				body.name = "Body"
				body.color = Color(0.04, 0.22, 0.38, 0.9)
				body.size = Vector2(ew, eh)
				node.add_child(body)

				# 3. Solid glowing walking deck surface on top
				var deck: ColorRect = ColorRect.new()
				deck.name = "Deck"
				deck.color = Color(0.35, 1.0, 0.85, 0.98)
				deck.size = Vector2(ew, 5)
				deck.position = Vector2(0, 0)
				node.add_child(deck)

				# 4. Energy support struts across the bridge span
				var strut_count: int = int(ew / 40.0)
				for i in range(1, strut_count):
					var strut: ColorRect = ColorRect.new()
					strut.color = Color(0.0, 0.85, 1.0, 0.55)
					strut.size = Vector2(2, eh - 5)
					strut.position = Vector2(i * 40.0, 5)
					node.add_child(strut)

				# 5. Glowing cybernetic label
				var lbl: Label = Label.new()
				lbl.text = "⚡ QUANTUM BRIDGE [ACTIVE] ⚡"
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.size = Vector2(ew, eh)
				lbl.add_theme_font_size_override("font_size", 12)
				lbl.add_theme_color_override("font_color", Color(0.9, 1.0, 1.0))
				node.add_child(lbl)
			else:
				var tex: Texture2D = _try_load_texture(["res://assets/sprites/wall.png", "res://assets/sprites/block.png"])
				if tex:
					var sp: Sprite2D = Sprite2D.new()
					sp.texture = tex
					sp.position = Vector2(ew * 0.5, eh * 0.5)
					node.add_child(sp)
				else:
					var rect: ColorRect = ColorRect.new()
					rect.color = Color(0.35, 0.4, 0.48)
					rect.size = Vector2(ew, eh)
					node.add_child(rect)
			
		"monster":
			# Procedural dark purple blob placeholder (130x130 box, no copyrighted art)
			var visual: Node2D = Node2D.new()
			visual.name = "MonsterVisual"
			var center_x: float = ew * 0.5
			var center_y: float = eh * 0.5
			visual.position = Vector2(center_x, center_y)

			# 1. Outer ambient dark purple glow
			var outer_glow: Polygon2D = Polygon2D.new()
			outer_glow.color = Color(0.45, 0.1, 0.65, 0.25)
			var glow_pts: Array[Vector2] = []
			for i in range(16):
				var angle: float = i * (PI * 2.0 / 16.0)
				var r: float = 64.0 + 4.0 * sin(angle * 3.0)
				glow_pts.append(Vector2(cos(angle) * r, sin(angle) * (r * 0.92)))
			outer_glow.polygon = PackedVector2Array(glow_pts)
			visual.add_child(outer_glow)

			# 2. Main dark purple blob body (smooth organic shape)
			var body: Polygon2D = Polygon2D.new()
			body.name = "Body"
			body.color = Color(0.28, 0.08, 0.44, 0.96) # Dark purple
			var body_pts: Array[Vector2] = []
			for i in range(24):
				var angle: float = i * (PI * 2.0 / 24.0)
				var r: float = 56.0 + 5.0 * sin(angle * 4.0) + (8.0 if sin(angle) > 0.0 else -3.0)
				body_pts.append(Vector2(cos(angle) * r, sin(angle) * (r * 0.9)))
			body.polygon = PackedVector2Array(body_pts)
			visual.add_child(body)

			# 3. Inner body layer for depth
			var inner_body: Polygon2D = Polygon2D.new()
			inner_body.color = Color(0.38, 0.12, 0.56, 0.85)
			var inner_pts: Array[Vector2] = []
			for pt in body_pts:
				inner_pts.append(pt * 0.8)
			inner_body.polygon = PackedVector2Array(inner_pts)
			visual.add_child(inner_body)

			# 4. Two glowing red eyes
			var eye_glow_l: ColorRect = ColorRect.new()
			eye_glow_l.color = Color(1.0, 0.05, 0.1, 0.35)
			eye_glow_l.size = Vector2(26, 26)
			eye_glow_l.position = Vector2(-35, -18)
			visual.add_child(eye_glow_l)

			var eye_glow_r: ColorRect = ColorRect.new()
			eye_glow_r.color = Color(1.0, 0.05, 0.1, 0.35)
			eye_glow_r.size = Vector2(26, 26)
			eye_glow_r.position = Vector2(9, -18)
			visual.add_child(eye_glow_r)

			var eye_l: ColorRect = ColorRect.new()
			eye_l.color = Color(0.95, 0.1, 0.15, 1.0) # Glowing red
			eye_l.size = Vector2(18, 18)
			eye_l.position = Vector2(-31, -14)
			visual.add_child(eye_l)

			var eye_r: ColorRect = ColorRect.new()
			eye_r.color = Color(0.95, 0.1, 0.15, 1.0) # Glowing red
			eye_r.size = Vector2(18, 18)
			eye_r.position = Vector2(13, -14)
			visual.add_child(eye_r)

			var pupil_l: ColorRect = ColorRect.new()
			pupil_l.color = Color(1.0, 0.88, 0.9, 1.0)
			pupil_l.size = Vector2(6, 6)
			pupil_l.position = Vector2(-25, -12)
			visual.add_child(pupil_l)

			var pupil_r: ColorRect = ColorRect.new()
			pupil_r.color = Color(1.0, 0.88, 0.9, 1.0)
			pupil_r.size = Vector2(6, 6)
			pupil_r.position = Vector2(19, -12)
			visual.add_child(pupil_r)

			node.add_child(visual)
			node.set_meta("last_x", float(ent.get("x", 0)))
			node.set_meta("facing", 1.0)

			# Slight bob with a Tween
			var start_bob: Callable = func() -> void:
				if not is_instance_valid(visual) or not visual.is_inside_tree():
					return
				var tween: Tween = visual.create_tween()
				tween.set_loops()
				tween.tween_property(visual, "position:y", center_y - 6.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				tween.tween_property(visual, "position:y", center_y, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

			if visual.is_inside_tree():
				start_bob.call()
			else:
				visual.tree_entered.connect(start_bob)
			
		"crate":
			var tex: Texture2D = _try_load_texture([
				"res://assets/art/world/crate.png",
				"res://assets/sprites/crate.png",
				"res://assets/sprites/box.png"
			])
			if tex:
				var sp: Sprite2D = Sprite2D.new()
				sp.texture = tex
				sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				var tsize: Vector2 = tex.get_size()
				if tsize.x > 0 and tsize.y > 0:
					sp.scale = Vector2(ew / tsize.x, eh / tsize.y)
				else:
					sp.scale = Vector2(0.5, 0.5)
				sp.position = Vector2(ew * 0.5, eh * 0.5)
				node.add_child(sp)
			else:
				var rect: ColorRect = ColorRect.new()
				rect.color = Color(0.72, 0.45, 0.2)
				rect.size = Vector2(ew, eh)
				node.add_child(rect)
				
				var lbl: Label = Label.new()
				lbl.text = "CRATE"
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.size = Vector2(ew, eh)
				node.add_child(lbl)
			
		"plate":
			var tex: Texture2D = _try_load_texture(["res://assets/sprites/plate.png", "res://assets/sprites/pad.png"])
			if tex:
				var sp: Sprite2D = Sprite2D.new()
				sp.texture = tex
				var tsize: Vector2 = tex.get_size()
				if tsize.x > 0 and tsize.y > 0:
					var s: float = minf(float(ew) / tsize.x, float(eh) / tsize.y)
					sp.scale = Vector2(s, s)
				sp.position = Vector2(ew * 0.5, eh * 0.5)
				node.add_child(sp)
			else:
				var rect: ColorRect = ColorRect.new()
				rect.color = Color(0.2, 0.8, 0.4)
				rect.size = Vector2(ew, eh)
				node.add_child(rect)
			
		"energyCell":
			var tex: Texture2D = _try_load_texture([
				"res://assets/art/world/energy_cell.png",
				"res://assets/art/world/oxygen.png",
				"res://assets/sprites/oxygen_cylinder.png",
				"res://assets/sprites/oxygen.png",
				"res://assets/sprites/cylinder.png",
				"res://assets/sprites/energy_cell.png",
				"res://assets/sprites/cell.png"
			])
			if tex:
				var sp: Sprite2D = Sprite2D.new()
				sp.texture = tex
				sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				var tsize: Vector2 = tex.get_size()
				if tsize.x > 0 and tsize.y > 0:
					sp.scale = Vector2(30.0 / tsize.x, 44.0 / tsize.y)
				else:
					sp.scale = Vector2(0.5, 0.5)
				
				# Position at 30x44 with bottom edge on entity's bottom edge (eh)
				var base_x: float = ew * 0.5
				var base_y: float = eh - 22.0
				sp.position = Vector2(base_x, base_y)
				node.add_child(sp)

				# Gentle 6 px up/down bob with a Tween
				var start_bob: Callable = func() -> void:
					if not is_instance_valid(sp) or not sp.is_inside_tree():
						return
					var tween: Tween = sp.create_tween()
					tween.set_loops()
					tween.tween_property(sp, "position:y", base_y - 6.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					tween.tween_property(sp, "position:y", base_y, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

				if sp.is_inside_tree():
					start_bob.call()
				else:
					sp.tree_entered.connect(start_bob)
			else:
				var glow: ColorRect = ColorRect.new()
				glow.color = Color(0.0, 1.0, 0.5, 0.35)
				glow.size = Vector2(28, 28)
				glow.position = Vector2(-2, -2)
				node.add_child(glow)

				var rect: ColorRect = ColorRect.new()
				rect.color = Color(0.0, 1.0, 0.5)
				rect.size = Vector2(24, 24)
				node.add_child(rect)
				
				var lbl: Label = Label.new()
				lbl.text = "+5"
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.size = Vector2(24, 24)
				lbl.add_theme_font_size_override("font_size", 10)
				lbl.add_theme_color_override("font_color", Color(0.05, 0.15, 0.05))
				node.add_child(lbl)
			
		"shipPart":
			var tex: Texture2D = _try_load_texture([
				"res://assets/art/world/ship_part.png",
				"res://assets/art/world/parts.png",
				"res://assets/sprites/parts.png",
				"res://assets/sprites/ship_part.png",
				"res://assets/sprites/part.png"
			])
			if tex:
				var sp: Sprite2D = Sprite2D.new()
				sp.texture = tex
				sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				var tsize: Vector2 = tex.get_size()
				if tsize.x > 0 and tsize.y > 0:
					sp.scale = Vector2(96.0 / tsize.x, 56.0 / tsize.y)
				else:
					sp.scale = Vector2(0.5, 0.5)
				
				# Bottom-aligned to entity's bottom edge (eh), centered on entity's x center (ew * 0.5)
				var base_x: float = ew * 0.5
				var base_y: float = eh - 28.0
				sp.position = Vector2(base_x, base_y)
				node.add_child(sp)

				# Slow glow pulse (modulate between white and light cyan)
				var start_pulse: Callable = func() -> void:
					if not is_instance_valid(sp) or not sp.is_inside_tree():
						return
					var tween: Tween = sp.create_tween()
					tween.set_loops()
					tween.tween_property(sp, "modulate", Color(0.65, 0.95, 1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					tween.tween_property(sp, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

				if sp.is_inside_tree():
					start_pulse.call()
				else:
					sp.tree_entered.connect(start_pulse)
			else:
				var glow: ColorRect = ColorRect.new()
				glow.color = Color(1.0, 0.8, 0.1, 0.4)
				glow.size = Vector2(ew + 12, eh + 12)
				glow.position = Vector2(-6, -6)
				node.add_child(glow)

				var rect: ColorRect = ColorRect.new()
				rect.color = Color(1.0, 0.85, 0.0)
				rect.size = Vector2(ew, eh)
				node.add_child(rect)
				
				var lbl: Label = Label.new()
				lbl.text = "⚡PART"
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.size = Vector2(ew, eh)
				lbl.add_theme_font_size_override("font_size", 14)
				lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
				node.add_child(lbl)
			
		"editBlock":
			var is_dup_skill: bool = (str(ent.get("skill", "")) == "duplicate")
			var rect: ColorRect = ColorRect.new()
			rect.name = "Background"
			rect.color = Color(0.08, 0.28, 0.42, 0.8) if is_dup_skill else Color(0.0, 0.9, 1.0, 0.5)
			rect.size = Vector2(ew, eh)
			node.add_child(rect)

			var border_top: ColorRect = ColorRect.new()
			border_top.name = "BorderTop"
			border_top.color = Color(0.2, 0.9, 1.0, 0.9)
			border_top.size = Vector2(ew, 4)
			node.add_child(border_top)
			
			var lbl: Label = Label.new()
			lbl.name = "Label"
			var skill: String = str(ent.get("skill", "")).to_upper()
			if is_dup_skill:
				lbl.text = "PRESS [2] TO DUPLICATE BRIDGE INTO REALITY [A]"
			else:
				lbl.text = "[%s]" % skill
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.size = Vector2(ew, eh)
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", Color(0.95, 1.0, 1.0))
			node.add_child(lbl)

			
		"exit":
			var tex: Texture2D = _try_load_texture([
				"res://assets/art/world/exit_ship.png",
				"res://assets/art/world/exit.png",
				"res://assets/sprites/spaceship.png",
				"res://assets/sprites/ship.png",
				"res://assets/sprites/exit.png",
				"res://assets/sprites/warp.png"
			])
			if tex:
				var glow: ColorRect = ColorRect.new()
				glow.color = Color(0.2, 0.8, 1.0, 0.2)
				glow.size = Vector2(ew + 16, eh + 16)
				glow.position = Vector2(-8, -8)
				node.add_child(glow)

				var sp: Sprite2D = Sprite2D.new()
				sp.texture = tex
				sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				var tsize: Vector2 = tex.get_size()
				var s: Vector2 = Vector2(280.0 / tsize.x, 112.0 / tsize.y) if (tsize.x > 0 and tsize.y > 0) else Vector2(0.5, 0.5)
				sp.scale = s
				# Bottom-aligned (eh - 56.0) and horizontally centered (ew * 0.5) on entity's box
				sp.position = Vector2(ew * 0.5, eh - 56.0)
				node.add_child(sp)

				# Track exit node for state-based dimming/brightness
				_exit_nodes.append(node)
				var parts_info: Dictionary = Game.get_state().get("parts", {})
				var total_parts: int = int(parts_info.get("total", _level_data.get("parts", 1)))
				var collected_parts: int = int(parts_info.get("collected", 0))
				var has_all_parts: bool = (collected_parts >= total_parts and total_parts > 0)
				node.modulate.a = 1.0 if has_all_parts else 0.5
			else:
				var glow: ColorRect = ColorRect.new()
				glow.color = Color(0.7, 0.3, 0.9, 0.4)
				glow.size = Vector2(ew + 12, eh + 12)
				glow.position = Vector2(-6, -6)
				node.add_child(glow)

				var rect: ColorRect = ColorRect.new()
				rect.color = Color(0.65, 0.2, 0.85)
				rect.size = Vector2(ew, eh)
				node.add_child(rect)
				
				var lbl: Label = Label.new()
				lbl.text = "🚀 SPACESHIP\nEXTRACTION [EXIT]"
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.size = Vector2(ew, eh)
				lbl.add_theme_font_size_override("font_size", 16)
				node.add_child(lbl)
		_:
			var rect: ColorRect = ColorRect.new()
			rect.color = Color(0.5, 0.5, 0.5)
			rect.size = Vector2(ew, eh)
			node.add_child(rect)
	
	return node


# ── SCREEN TRANSITIONS & OVERLAYS ───────────────────────────
func _on_level_cleared(points: int) -> void:
	var state: Dictionary = Game.get_state()
	var lives: int = state.get("lives", 3)
	GameProgress.unlock_next_level(_level_id, points)
	
	var clear_scene: PackedScene = load("res://src/scenes/level_clear.tscn")
	if clear_scene:
		var clear_node = clear_scene.instantiate()
		clear_node.setup(_level_id, points, lives)
		clear_node.next_level_requested.connect(_on_next_level_requested)
		clear_node.replay_requested.connect(_on_replay_level)
		clear_node.level_select_requested.connect(_on_return_to_level_select)
		
		var canvas: CanvasLayer = CanvasLayer.new()
		canvas.layer = 25
		canvas.add_child(clear_node)
		add_child(canvas)


func _on_game_over() -> void:
	var over_scene: PackedScene = load("res://src/scenes/game_over.tscn")
	if over_scene:
		var over_node = over_scene.instantiate()
		over_node.setup(_level_id)
		over_node.retry_requested.connect(_on_replay_level)
		over_node.level_select_requested.connect(_on_return_to_level_select)
		over_node.main_menu_requested.connect(_on_return_to_main_menu)
		
		var canvas: CanvasLayer = CanvasLayer.new()
		canvas.layer = 25
		canvas.add_child(over_node)
		add_child(canvas)


func _on_next_level_requested() -> void:
	get_tree().paused = false
	if _level_id >= 4:
		if FileAccess.file_exists("res://assets/video/credits.ogv"):
			VideoPlayerScene.play_video(get_tree(), "res://assets/video/credits.ogv", "res://src/scenes/ending_screen.tscn")
		else:
			get_tree().change_scene_to_file("res://src/scenes/ending_screen.tscn")
	else:
		var next_id: int = _level_id + 1
		GameProgress.selected_level = next_id
		Game.load_level(next_id)
		get_tree().change_scene_to_file("res://src/scenes/gameplay.tscn")


func _on_replay_level() -> void:
	get_tree().paused = false
	Game.load_level(_level_id)
	get_tree().change_scene_to_file("res://src/scenes/gameplay.tscn")


func _on_jump_to_level(target_level_id: int) -> void:
	get_tree().paused = false
	GameProgress.selected_level = target_level_id
	Game.load_level(target_level_id)
	get_tree().change_scene_to_file("res://src/scenes/gameplay.tscn")


func _on_return_to_level_select() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/scenes/level_select.tscn")


func _on_return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/scenes/title_screen.tscn")


# ── PAUSE MENU CONTROLLER ───────────────────────────────────
func _on_pause_requested() -> void:
	_toggle_pause()


func _toggle_pause() -> void:
	if get_tree().paused:
		_resume_game()
	else:
		_pause_game()


func _pause_game() -> void:
	var state: Dictionary = Game.get_state()
	if state.get("status", "playing") != "playing":
		return

	get_tree().paused = true

	if _pause_menu == null:
		var pause_scene: PackedScene = load("res://src/scenes/pause_menu.tscn")
		if pause_scene:
			_pause_menu = pause_scene.instantiate()
			_pause_menu.setup(_level_id)
			_pause_menu.resume_requested.connect(_resume_game)
			_pause_menu.restart_requested.connect(_on_replay_level)
			_pause_menu.level_selected.connect(_on_jump_to_level)
			_pause_menu.level_select_screen_requested.connect(_on_return_to_level_select)
			_pause_menu.main_menu_requested.connect(_on_return_to_main_menu)

			_pause_canvas = CanvasLayer.new()
			_pause_canvas.layer = 30
			_pause_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
			_pause_canvas.add_child(_pause_menu)
			add_child(_pause_canvas)
	else:
		_pause_menu.setup(_level_id)
		_pause_canvas.visible = true


func _resume_game() -> void:
	get_tree().paused = false
	if _pause_canvas:
		_pause_canvas.visible = false
