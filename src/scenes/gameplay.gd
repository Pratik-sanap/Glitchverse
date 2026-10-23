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
var _camera: Camera2D

# Entity ID -> Node2D lookup for fast positional updates
var _entity_nodes: Dictionary = {}


func _ready() -> void:
	# Check if Game already has an active level ID; default to 1
	var initial_state: Dictionary = Game.get_state()
	_level_id = initial_state.get("level_id", 1)
	
	_load_level_file(_level_id)
	_build_scene_hierarchy()
	_populate_level_geometry()
	
	# Connect to logic signals
	if not Game.state_changed.is_connected(_on_state_changed):
		Game.state_changed.connect(_on_state_changed)
	
	# Request Game to load the level
	Game.load_level(_level_id)
	
	# Initial draw sync
	_on_state_changed()


func _process(_delta: float) -> void:
	_feed_input_to_game()


# ── INPUT FEEDING ───────────────────────────────────────────
func _feed_input_to_game() -> void:
	# 1. Horizontal movement
	var move_axis: float = Input.get_axis("move_left", "move_right")
	Game.set_move(move_axis)
	
	# 2. Jump
	if Input.is_action_just_pressed("jump"):
		Game.jump(true)
	elif Input.is_action_just_released("jump"):
		Game.jump(false)
	
	# 3. Dimensional Rift switch
	if Input.is_action_just_pressed("switch_world"):
		Game.switch_world()
	
	# 4. Skills (1: Delete, 2: Duplicate, 3: Move, 4: Shield)
	if Input.is_action_just_pressed("skill_1"):
		var target: String = _find_nearest_target("delete")
		Game.use_skill("delete", target)
	elif Input.is_action_just_pressed("skill_2"):
		var target: String = _find_nearest_target("duplicate")
		Game.use_skill("duplicate", target)
	elif Input.is_action_just_pressed("skill_3"):
		var target: String = _find_nearest_target("move")
		Game.use_skill("move", target)
	elif Input.is_action_just_pressed("skill_4"):
		Game.use_skill("shield", "")


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


func _create_entity_visual(ent: Dictionary) -> Node2D:
	var node: Node2D = Node2D.new()
	node.name = str(ent.get("id", "entity"))
	node.position = Vector2(float(ent.get("x", 0)), float(ent.get("y", 0)))
	
	var etype: String = str(ent.get("type", ""))
	var ew: float = float(ent.get("w", 32))
	var eh: float = float(ent.get("h", 32))
	
	match etype:
		"spike":
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
			var rect: ColorRect = ColorRect.new()
			rect.color = Color(0.35, 0.4, 0.48)
			rect.size = Vector2(ew, eh)
			node.add_child(rect)
			
		"monster":
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
			var rect: ColorRect = ColorRect.new()
			rect.color = Color(0.2, 0.8, 0.4)
			rect.size = Vector2(ew, eh)
			node.add_child(rect)
			
		"energyCell":
			var rect: ColorRect = ColorRect.new()
			rect.color = Color(0.0, 1.0, 0.5)
			rect.size = Vector2(24, 24)
			node.add_child(rect)
			
			var lbl: Label = Label.new()
			lbl.text = "+5"
			lbl.size = Vector2(24, 24)
			node.add_child(lbl)
			
		"shipPart":
			var rect: ColorRect = ColorRect.new()
			rect.color = Color(1.0, 0.85, 0.0)
			rect.size = Vector2(32, 32)
			node.add_child(rect)
			
			var lbl: Label = Label.new()
			lbl.text = "PART"
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.size = Vector2(32, 32)
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
			var rect: ColorRect = ColorRect.new()
			rect.color = Color(0.7, 0.3, 0.9)
			rect.size = Vector2(ew, eh)
			node.add_child(rect)
			
			var lbl: Label = Label.new()
			lbl.text = "EXIT"
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.size = Vector2(ew, eh)
			node.add_child(lbl)
			
		_:
			var rect: ColorRect = ColorRect.new()
			rect.color = Color(0.5, 0.5, 0.5)
			rect.size = Vector2(ew, eh)
			node.add_child(rect)
	
	return node
