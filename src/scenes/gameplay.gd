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
var _bg_rect_a: TextureRect
var _bg_rect_b: TextureRect

const PLAYER_SPRITE_PATH: String = "res://assets/sprites/Firefly.png"
const PLAYER_SHEET_COLUMNS: int = 4
const PLAYER_SHEET_ROWS: int = 7
const PLAYER_WALK_ROW: int = 2
const PLAYER_WALK_FPS: float = 10.0

# Entity ID -> Node2D lookup for fast positional updates
var _entity_nodes: Dictionary = {}

# Audio
var _audio_mgr: Node


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
		add_child(hud_scene.instantiate())

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
				var ent_pos: Vector2 = Vector2(ent_dict.get("x", 0.0), ent_dict.get("y", 0.0))
				var dist: float = player_pos.distance_to(ent_pos)
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
	
	# 2. Update active dimension
	if state.has("world"):
		var new_world: String = state["world"]
		if new_world != _current_world:
			_current_world = new_world
			_apply_world_appearance()
	
	# 3. Update dynamic entity states (e.g. collected items, removed blocks)
	if state.has("entities"):
		var state_entities: Array = state["entities"]
		for ent in state_entities:
			if not (ent is Dictionary):
				continue
			var ent_dict: Dictionary = ent
			var eid: String = str(ent_dict.get("id", ""))
			if _entity_nodes.has(eid):
				var node: Node2D = _entity_nodes[eid]
				# Position update if moved
				if ent_dict.has("x") and ent_dict.has("y"):
					node.position = Vector2(ent_dict["x"], ent_dict["y"])
				# Visibility based on deleted/collected status
				var is_inactive: bool = ent_dict.get("collected", false) or ent_dict.get("deleted", false)
				node.visible = (not is_inactive) and (ent_dict.get("world", "A") == _current_world)


func _apply_world_appearance() -> void:
	# World A entities visible in Reality, World B in Source Layer
	_entities_a_container.visible = (_current_world == "A")
	_entities_b_container.visible = (_current_world == "B")
	
	if _bg_rect_a:
		_bg_rect_a.visible = (_current_world == "A")
	if _bg_rect_b:
		_bg_rect_b.visible = (_current_world == "B")


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
	var portal_tex: Texture2D = _try_load_texture(["res://assets/sprites/portal.png", "res://assets/sprites/rift.png"])
	var portals: Array = _level_data.get("portals", [])
	for p in portals:
		if not (p is Dictionary):
			continue
		var port: Dictionary = p
		var px: float = float(port.get("x", 0))
		var py: float = float(port.get("y", 0))
		var pw: float = float(port.get("w", 80))
		var ph: float = float(port.get("h", 100))
		
		var portal_node: Node2D = Node2D.new()
		portal_node.position = Vector2(px, py)
		
		if portal_tex:
			var sp: Sprite2D = Sprite2D.new()
			sp.texture = portal_tex
			sp.position = Vector2(pw * 0.5, ph * 0.5)
			portal_node.add_child(sp)
		else:
			var portal_bg: ColorRect = ColorRect.new()
			portal_bg.color = Color(0.6, 0.2, 0.9, 0.35) # Glowing dimensional rift
			portal_bg.size = Vector2(pw, ph)
			portal_node.add_child(portal_bg)
			
			var portal_label: Label = Label.new()
			portal_label.text = "RIFT\n[F]"
			portal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			portal_label.position = Vector2(0, ph * 0.3)
			portal_label.size = Vector2(pw, 40)
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
	return null


func _create_entity_visual(ent: Dictionary) -> Node2D:
	var node: Node2D = Node2D.new()
	node.name = str(ent.get("id", "entity"))
	node.position = Vector2(float(ent.get("x", 0)), float(ent.get("y", 0)))
	
	var etype: String = str(ent.get("type", ""))
	var ew: float = float(ent.get("w", 32))
	var eh: float = float(ent.get("h", 32))
	
	match etype:
		"spike":
			var tex: Texture2D = _try_load_texture(["res://assets/sprites/spike.png", "res://assets/sprites/spikes.png"])
			if tex:
				var sp: Sprite2D = Sprite2D.new()
				sp.texture = tex
				sp.position = Vector2(ew * 0.5, eh * 0.5)
				node.add_child(sp)
			else:
				var rect: ColorRect = ColorRect.new()
				rect.color = Color(0.9, 0.2, 0.2, 0.9)
				rect.size = Vector2(ew, eh)
				node.add_child(rect)
				
				var lbl: Label = Label.new()
				lbl.text = "▲▲▲"
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.size = Vector2(ew, eh)
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
			var tex: Texture2D = _try_load_texture(["res://assets/sprites/monster.png", "res://assets/sprites/alien.png"])
			if tex:
				var sp: Sprite2D = Sprite2D.new()
				sp.texture = tex
				sp.position = Vector2(ew * 0.5, eh * 0.5)
				node.add_child(sp)
			else:
				var rect: ColorRect = ColorRect.new()
				rect.color = Color(0.9, 0.4, 0.1)
				rect.size = Vector2(ew, eh)
				node.add_child(rect)
				
				var lbl: Label = Label.new()
				lbl.text = "👾"
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.size = Vector2(ew, eh)
				node.add_child(lbl)
			
		"crate":
			var tex: Texture2D = _try_load_texture(["res://assets/sprites/crate.png", "res://assets/sprites/box.png"])
			if tex:
				var sp: Sprite2D = Sprite2D.new()
				sp.texture = tex
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
				lbl.size = Vector2(ew, eh)
				node.add_child(lbl)
			
		"plate":
			var tex: Texture2D = _try_load_texture(["res://assets/sprites/plate.png", "res://assets/sprites/pad.png"])
			if tex:
				var sp: Sprite2D = Sprite2D.new()
				sp.texture = tex
				sp.position = Vector2(ew * 0.5, eh * 0.5)
				node.add_child(sp)
			else:
				var rect: ColorRect = ColorRect.new()
				rect.color = Color(0.2, 0.8, 0.4)
				rect.size = Vector2(ew, eh)
				node.add_child(rect)
			
		"energyCell":
			var tex: Texture2D = _try_load_texture(["res://assets/sprites/energy_cell.png", "res://assets/sprites/cell.png"])
			if tex:
				var sp: Sprite2D = Sprite2D.new()
				sp.texture = tex
				sp.position = Vector2(12, 12)
				node.add_child(sp)
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
			var tex: Texture2D = _try_load_texture(["res://assets/sprites/ship_part.png", "res://assets/sprites/part.png"])
			if tex:
				var sp: Sprite2D = Sprite2D.new()
				sp.texture = tex
				sp.position = Vector2(ew * 0.5, eh * 0.5)
				node.add_child(sp)
			else:
				var glow: ColorRect = ColorRect.new()
				glow.color = Color(1.0, 0.8, 0.1, 0.4)
				glow.size = Vector2(36, 36)
				glow.position = Vector2(-2, -2)
				node.add_child(glow)

				var rect: ColorRect = ColorRect.new()
				rect.color = Color(1.0, 0.85, 0.0)
				rect.size = Vector2(32, 32)
				node.add_child(rect)
				
				var lbl: Label = Label.new()
				lbl.text = "⚡PART"
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.size = Vector2(32, 32)
				lbl.add_theme_font_size_override("font_size", 9)
				lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
				node.add_child(lbl)
			
		"editBlock":
			var rect: ColorRect = ColorRect.new()
			rect.color = Color(0.0, 0.9, 1.0, 0.5)
			rect.size = Vector2(ew, eh)
			node.add_child(rect)
			
			var lbl: Label = Label.new()
			var skill: String = str(ent.get("skill", "")).to_upper()
			lbl.text = "[%s]" % skill
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.size = Vector2(ew, eh)
			node.add_child(lbl)
			
		"exit":
			var tex: Texture2D = _try_load_texture(["res://assets/sprites/exit.png", "res://assets/sprites/warp.png"])
			if tex:
				var sp: Sprite2D = Sprite2D.new()
				sp.texture = tex
				sp.position = Vector2(ew * 0.5, eh * 0.5)
				node.add_child(sp)
			else:
				var glow: ColorRect = ColorRect.new()
				glow.color = Color(0.7, 0.3, 0.9, 0.4)
				glow.size = Vector2(ew + 8, eh + 8)
				glow.position = Vector2(-4, -4)
				node.add_child(glow)

				var rect: ColorRect = ColorRect.new()
				rect.color = Color(0.65, 0.2, 0.85)
				rect.size = Vector2(ew, eh)
				node.add_child(rect)
				
				var lbl: Label = Label.new()
				lbl.text = "EXIT\nWARP"
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.size = Vector2(ew, eh)
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
	Game.load_level(_level_id)
	get_tree().change_scene_to_file("res://src/scenes/gameplay.tscn")


func _on_return_to_level_select() -> void:
	get_tree().change_scene_to_file("res://src/scenes/level_select.tscn")


func _on_return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://src/scenes/title_screen.tscn")
