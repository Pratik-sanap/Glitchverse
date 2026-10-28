## touch_controls.gd — Mobile On-Screen Virtual Controls for Rift Runner.
## Provides multi-touch D-pad (Left/Right) and Action buttons (Jump, Rift Switch).
## Feeds standard Godot Input actions directly without altering core game logic.
extends CanvasLayer

# ── Styling Constants ───────────────────────────────────────
const COLOR_CYAN_ACCENT: Color = Color(0.0, 0.9, 1.0, 0.85)
const COLOR_PURPLE_ACCENT: Color = Color(0.9, 0.3, 1.0, 0.85)
const COLOR_BTN_BG_NORMAL: Color = Color(0.04, 0.08, 0.16, 0.55)
const COLOR_BTN_BG_PRESSED: Color = Color(0.12, 0.28, 0.45, 0.9)
const COLOR_BTN_BG_PRESSED_PURPLE: Color = Color(0.35, 0.12, 0.42, 0.9)

# ── Internal State ──────────────────────────────────────────
var _root_control: Control
var _btn_left: PanelContainer
var _btn_right: PanelContainer
var _btn_jump: PanelContainer
var _btn_rift: PanelContainer
var _skill_cluster_a: HBoxContainer
var _skill_cluster_b: HBoxContainer

# Map button name -> { "action": String, "node": PanelContainer, "normal_style": StyleBoxFlat, "pressed_style": StyleBoxFlat, "label": Label }
var _button_defs: Dictionary = {}

# Active touches: touch_id (int) -> action (String)
var _active_touches: Dictionary = {}


func _ready() -> void:
	layer = 15 # Render above gameplay, below pause menu dialogs
	_build_ui()
	_update_visibility()
	
	if not Game.state_changed.is_connected(_on_game_state_changed):
		Game.state_changed.connect(_on_game_state_changed)
	_on_game_state_changed()

	# Connect to window size changes if needed
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all()


func _on_viewport_size_changed() -> void:
	_update_visibility()


# ── VISIBILITY LOGIC ────────────────────────────────────────
func _update_visibility() -> void:
	var mode: String = GameProgress.touch_controls_mode
	if mode == "on":
		visible = true
	elif mode == "off":
		visible = false
	else:
		# Auto-detect: touch screen hardware, mobile OS, or web mobile
		var is_touch_dev: bool = DisplayServer.is_touchscreen_available() \
			or OS.has_feature("mobile") \
			or OS.has_feature("web_android") \
			or OS.has_feature("web_ios")
		visible = is_touch_dev


func set_mode(new_mode: String) -> void:
	GameProgress.touch_controls_mode = new_mode
	GameProgress.save_progress()
	_update_visibility()


func cycle_mode() -> String:
	var current: String = GameProgress.touch_controls_mode
	var next_mode: String = "auto"
	if current == "auto":
		next_mode = "on"
	elif current == "on":
		next_mode = "off"
	else:
		next_mode = "auto"
	set_mode(next_mode)
	return next_mode


# ── UI CONSTRUCTION ─────────────────────────────────────────
func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.name = "TouchOverlay"
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_control)

	# ── Left Movement Cluster (Bottom-Left) ──────────────────
	var left_cluster: HBoxContainer = HBoxContainer.new()
	left_cluster.name = "MovementCluster"
	left_cluster.anchor_left = 0.0
	left_cluster.anchor_top = 1.0
	left_cluster.anchor_right = 0.0
	left_cluster.anchor_bottom = 1.0
	left_cluster.offset_left = 32.0
	left_cluster.offset_top = -120.0
	left_cluster.offset_right = 210.0
	left_cluster.offset_bottom = -32.0
	left_cluster.add_theme_constant_override("separation", 16)
	left_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(left_cluster)

	_btn_left = _create_touch_button("move_left", "◀", Vector2(76, 76), COLOR_CYAN_ACCENT, COLOR_BTN_BG_NORMAL, COLOR_BTN_BG_PRESSED, 28)
	left_cluster.add_child(_btn_left)

	_btn_right = _create_touch_button("move_right", "▶", Vector2(76, 76), COLOR_CYAN_ACCENT, COLOR_BTN_BG_NORMAL, COLOR_BTN_BG_PRESSED, 28)
	left_cluster.add_child(_btn_right)

	# ── Right Action Cluster (Bottom-Right) ──────────────────
	var right_cluster: HBoxContainer = HBoxContainer.new()
	right_cluster.name = "ActionCluster"
	right_cluster.anchor_left = 1.0
	right_cluster.anchor_top = 1.0
	right_cluster.anchor_right = 1.0
	right_cluster.anchor_bottom = 1.0
	right_cluster.offset_left = -224.0
	right_cluster.offset_top = -124.0
	right_cluster.offset_right = -32.0
	right_cluster.offset_bottom = -32.0
	right_cluster.add_theme_constant_override("separation", 16)
	right_cluster.alignment = BoxContainer.ALIGNMENT_END
	right_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(right_cluster)

	# Rift Switch (World A <-> World B)
	_btn_rift = _create_touch_button("switch_world", "🌀\nRIFT", Vector2(76, 76), COLOR_PURPLE_ACCENT, COLOR_BTN_BG_NORMAL, COLOR_BTN_BG_PRESSED_PURPLE, 14)
	right_cluster.add_child(_btn_rift)

	# Jump Button (Prominent)
	_btn_jump = _create_touch_button("jump", "▲\nJUMP", Vector2(84, 84), COLOR_CYAN_ACCENT, COLOR_BTN_BG_NORMAL, COLOR_BTN_BG_PRESSED, 16)
	right_cluster.add_child(_btn_jump)

	# ── Right Thumb Skill Cluster (Arched above Jump/Rift) ──
	# World A Skill: Shield
	_skill_cluster_a = HBoxContainer.new()
	_skill_cluster_a.name = "ThumbSkillsA"
	_skill_cluster_a.anchor_left = 1.0
	_skill_cluster_a.anchor_top = 1.0
	_skill_cluster_a.anchor_right = 1.0
	_skill_cluster_a.anchor_bottom = 1.0
	_skill_cluster_a.offset_left = -224.0
	_skill_cluster_a.offset_top = -178.0
	_skill_cluster_a.offset_right = -32.0
	_skill_cluster_a.offset_bottom = -132.0
	_skill_cluster_a.alignment = BoxContainer.ALIGNMENT_END
	_skill_cluster_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(_skill_cluster_a)

	var btn_thumb_shield = _create_touch_button("skill_4", "🛡️ SHIELD (10)", Vector2(176, 44), Color(0.2, 1.0, 0.6), COLOR_BTN_BG_NORMAL, COLOR_BTN_BG_PRESSED, 12)
	_skill_cluster_a.add_child(btn_thumb_shield)

	# World B Skills: Delete, Duplicate, Move
	_skill_cluster_b = HBoxContainer.new()
	_skill_cluster_b.name = "ThumbSkillsB"
	_skill_cluster_b.anchor_left = 1.0
	_skill_cluster_b.anchor_top = 1.0
	_skill_cluster_b.anchor_right = 1.0
	_skill_cluster_b.anchor_bottom = 1.0
	_skill_cluster_b.offset_left = -224.0
	_skill_cluster_b.offset_top = -178.0
	_skill_cluster_b.offset_right = -32.0
	_skill_cluster_b.offset_bottom = -132.0
	_skill_cluster_b.add_theme_constant_override("separation", 8)
	_skill_cluster_b.alignment = BoxContainer.ALIGNMENT_END
	_skill_cluster_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(_skill_cluster_b)

	var btn_thumb_del = _create_touch_button("skill_1", "DEL (15)", Vector2(56, 44), Color(0.9, 0.25, 0.35), COLOR_BTN_BG_NORMAL, COLOR_BTN_BG_PRESSED, 11)
	_skill_cluster_b.add_child(btn_thumb_del)

	var btn_thumb_dup = _create_touch_button("skill_2", "DUP (20)", Vector2(56, 44), Color(0.1, 0.85, 1.0), COLOR_BTN_BG_NORMAL, COLOR_BTN_BG_PRESSED, 11)
	_skill_cluster_b.add_child(btn_thumb_dup)

	var btn_thumb_mov = _create_touch_button("skill_3", "MOV (10)", Vector2(56, 44), Color(1.0, 0.8, 0.2), COLOR_BTN_BG_NORMAL, COLOR_BTN_BG_PRESSED, 11)
	_skill_cluster_b.add_child(btn_thumb_mov)


func _on_game_state_changed() -> void:
	var state: Dictionary = Game.get_state()
	var world: String = state.get("world", "A")
	var is_shielded: bool = bool(state.get("shielded", false))
	if _skill_cluster_a:
		_skill_cluster_a.visible = (world == "A")
	if _skill_cluster_b:
		_skill_cluster_b.visible = (world == "B")
	if _button_defs.has("skill_4"):
		var lbl: Label = _button_defs["skill_4"].get("label", null)
		if lbl:
			lbl.text = "🛡️ ACTIVE" if is_shielded else "🛡️ SHIELD (10)"


func _create_touch_button(action_name: String, label_text: String, size: Vector2, accent_color: Color, bg_normal: Color, bg_pressed: Color, font_size: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var st_normal: StyleBoxFlat = StyleBoxFlat.new()
	st_normal.bg_color = bg_normal
	st_normal.border_width_left = 2
	st_normal.border_width_right = 2
	st_normal.border_width_top = 2
	st_normal.border_width_bottom = 2
	st_normal.border_color = accent_color
	st_normal.corner_radius_top_left = 14
	st_normal.corner_radius_top_right = 14
	st_normal.corner_radius_bottom_left = 14
	st_normal.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", st_normal)

	var st_pressed: StyleBoxFlat = st_normal.duplicate()
	st_pressed.bg_color = bg_pressed
	st_pressed.border_color = Color.WHITE

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(lbl)

	_button_defs[action_name] = {
		"action": action_name,
		"node": panel,
		"normal_style": st_normal,
		"pressed_style": st_pressed,
		"label": lbl,
		"accent": accent_color
	}
	return panel


# ── MULTI-TOUCH INPUT PROCESSING ───────────────────────────
func _input(event: InputEvent) -> void:
	if not visible:
		return

	# 1. Screen Touch (Mobile touch & Emulated touch)
	if event is InputEventScreenTouch:
		var touch_id: int = event.index
		if event.pressed:
			_handle_touch_down(touch_id, event.position)
		else:
			_handle_touch_up(touch_id)
		return

	# 2. Screen Drag (Thumb sliding between buttons)
	if event is InputEventScreenDrag:
		_handle_touch_drag(event.index, event.position)
		return

	# 3. Direct Mouse support for desktop editor/browser testing
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_touch_id: int = -1
			if event.pressed:
				_handle_touch_down(mouse_touch_id, event.position)
			else:
				_handle_touch_up(mouse_touch_id)
		return

	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_handle_touch_drag(-1, event.position)


func _handle_touch_down(touch_id: int, pos: Vector2) -> void:
	var action: String = _get_action_at_position(pos)
	if action.is_empty():
		return

	_active_touches[touch_id] = action
	_press_action(action)


func _handle_touch_up(touch_id: int) -> void:
	if not _active_touches.has(touch_id):
		return

	var action: String = _active_touches[touch_id]
	_active_touches.erase(touch_id)

	# Only release the input action if NO other finger is currently holding it
	if not _active_touches.values().has(action):
		_release_action(action)


func _handle_touch_drag(touch_id: int, pos: Vector2) -> void:
	var current_action: String = _active_touches.get(touch_id, "")
	var new_action: String = _get_action_at_position(pos)

	if current_action == new_action:
		return

	# Released old button
	if not current_action.is_empty():
		_active_touches.erase(touch_id)
		if not _active_touches.values().has(current_action):
			_release_action(current_action)

	# Pressed new button
	if not new_action.is_empty():
		_active_touches[touch_id] = new_action
		_press_action(new_action)


func _get_action_at_position(pos: Vector2) -> String:
	for action in _button_defs.keys():
		var node: PanelContainer = _button_defs[action]["node"]
		if node and node.is_visible_in_tree():
			var rect: Rect2 = node.get_global_rect()
			# Expand touch boundary slightly (8px margin) for smoother touch registration
			var expanded_rect: Rect2 = rect.grow(8.0)
			if expanded_rect.has_point(pos):
				return action
	return ""


func _press_action(action: String) -> void:
	if not Input.is_action_pressed(action):
		Input.action_press(action)
	_set_button_pressed_visual(action, true)


func _release_action(action: String) -> void:
	if Input.is_action_pressed(action):
		Input.action_release(action)
	_set_button_pressed_visual(action, false)


func _set_button_pressed_visual(action: String, is_pressed: bool) -> void:
	if not _button_defs.has(action):
		return
	var def: Dictionary = _button_defs[action]
	var node: PanelContainer = def["node"]
	var style: StyleBoxFlat = def["pressed_style"] if is_pressed else def["normal_style"]
	node.add_theme_stylebox_override("panel", style)

	# Subtle scale punch for immediate feedback
	node.pivot_offset = node.size * 0.5
	if is_pressed:
		node.scale = Vector2(0.94, 0.94)
	else:
		node.scale = Vector2(1.0, 1.0)


func release_all() -> void:
	for touch_id in _active_touches.keys():
		var action: String = _active_touches[touch_id]
		Input.action_release(action)
		_set_button_pressed_visual(action, false)
	_active_touches.clear()
