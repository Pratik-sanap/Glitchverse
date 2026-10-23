## hud.gd — Heads-Up Display for Rift Runner.
## Role C owns this file. No game rules logic here.
## Displays points, lives, ship parts, planet name, skill bar and floating score changes.
extends CanvasLayer

# ── Tunable Colors & Styling ────────────────────────────────
const COLOR_EP_GAIN: Color = Color(0.1, 1.0, 0.45, 1.0) # Bright neon green
const COLOR_EP_LOSS: Color = Color(1.0, 0.25, 0.35, 1.0) # Danger neon red
const COLOR_HEART_ACTIVE: Color = Color(1.0, 0.2, 0.4, 1.0)
const COLOR_HEART_EMPTY: Color = Color(0.35, 0.38, 0.45, 0.6)

# ── Node References (Created in Code) ───────────────────────
var _root_container: Control
var _planet_label: Label
var _dimension_label: Label
var _parts_label: Label
var _points_label: Label
var _lives_container: HBoxContainer
var _life_icons: Array[Label] = []

# Skill Buttons
var _btn_delete: Button
var _btn_duplicate: Button
var _btn_move: Button
var _btn_shield: Button

# Floating numbers container
var _float_container: Control

# Track previous points to calculate deltas
var _current_points: int = -9999


func _ready() -> void:
	layer = 10 # Render over game elements
	_build_ui()
	
	# Connect to logic signals
	if not Game.state_changed.is_connected(_on_state_changed):
		Game.state_changed.connect(_on_state_changed)
	if not Game.points_changed.is_connected(_on_points_changed):
		Game.points_changed.connect(_on_points_changed)
	if not Game.player_died.is_connected(_on_player_died):
		Game.player_died.connect(_on_player_died)
	
	_update_ui()


# ── UI CONSTRUCTION (Code-Driven) ───────────────────────────
func _build_ui() -> void:
	_root_container = Control.new()
	_root_container.name = "HUDControl"
	_root_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_container)
	
	# ── Top Bar Container ───────────────────────────────────
	var top_bar: PanelContainer = PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 20
	top_bar.offset_top = 16
	top_bar.offset_right = -20
	top_bar.offset_bottom = 66
	
	var top_style: StyleBoxFlat = StyleBoxFlat.new()
	top_style.bg_color = Color(0.06, 0.08, 0.14, 0.85)
	top_style.border_width_bottom = 1
	top_style.border_color = Color(0.2, 0.35, 0.5, 0.5)
	top_style.corner_radius_bottom_left = 6
	top_style.corner_radius_bottom_right = 6
	top_style.content_margin_left = 16
	top_style.content_margin_right = 16
	top_style.content_margin_top = 8
	top_style.content_margin_bottom = 8
	top_bar.add_theme_stylebox_override("panel", top_style)
	_root_container.add_child(top_bar)
	
	var top_box: HBoxContainer = HBoxContainer.new()
	top_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_box.add_theme_constant_override("separation", 24)
	top_bar.add_child(top_box)
	
	# 1. Planet & Dimension Badge
	var left_box: HBoxContainer = HBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.add_theme_constant_override("separation", 12)
	top_box.add_child(left_box)
	
	_planet_label = Label.new()
	_planet_label.text = "PLANET: MOON"
	_planet_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	left_box.add_child(_planet_label)
	
	_dimension_label = Label.new()
	_dimension_label.text = "[REALITY — WORLD A]"
	_dimension_label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	left_box.add_child(_dimension_label)
	
	# 2. Ship Parts Objective
	_parts_label = Label.new()
	_parts_label.text = "PARTS: 0 / 1"
	_parts_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	top_box.add_child(_parts_label)
	
	# 3. Energy Points (EP)
	_points_label = Label.new()
	_points_label.text = "EP: 30"
	_points_label.add_theme_color_override("font_color", Color(0.1, 1.0, 0.6))
	top_box.add_child(_points_label)
	
	# 4. Lives (3 Heart Icons)
	_lives_container = HBoxContainer.new()
	_lives_container.add_theme_constant_override("separation", 6)
	top_box.add_child(_lives_container)
	
	_life_icons.clear()
	for i in range(3):
		var heart: Label = Label.new()
		heart.text = "♥"
		heart.add_theme_color_override("font_color", COLOR_HEART_ACTIVE)
		_lives_container.add_child(heart)
		_life_icons.append(heart)
	
	# ── Floating Numbers Container ──────────────────────────
	_float_container = Control.new()
	_float_container.name = "FloatingContainer"
	_float_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_float_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_container.add_child(_float_container)
	
	# ── Bottom Skill Bar ────────────────────────────────────
	var bottom_panel: PanelContainer = PanelContainer.new()
	bottom_panel.name = "SkillBar"
	bottom_panel.anchor_left = 0.5
	bottom_panel.anchor_right = 0.5
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = -350
	bottom_panel.offset_right = 350
	bottom_panel.offset_top = -70
	bottom_panel.offset_bottom = -18
	bottom_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 0.92)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.0, 0.85, 1.0, 0.5)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 6
	panel_style.content_margin_bottom = 6
	bottom_panel.add_theme_stylebox_override("panel", panel_style)
	_root_container.add_child(bottom_panel)
	
	var skill_box: HBoxContainer = HBoxContainer.new()
	skill_box.add_theme_constant_override("separation", 10)
	skill_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_panel.add_child(skill_box)
	
	# Skill 1: Delete
	_btn_delete = Button.new()
	_btn_delete.text = "[1] DELETE (%d EP)" % Config.COST_DELETE
	_btn_delete.focus_mode = Control.FOCUS_NONE
	_btn_delete.pressed.connect(func(): Game.use_skill("delete", ""))
	skill_box.add_child(_btn_delete)
	
	# Skill 2: Duplicate
	_btn_duplicate = Button.new()
	_btn_duplicate.text = "[2] DUPLICATE (%d EP)" % Config.COST_DUPLICATE
	_btn_duplicate.focus_mode = Control.FOCUS_NONE
	_btn_duplicate.pressed.connect(func(): Game.use_skill("duplicate", ""))
	skill_box.add_child(_btn_duplicate)
	
	# Skill 3: Move
	_btn_move = Button.new()
	_btn_move.text = "[3] MOVE (%d EP)" % Config.COST_MOVE
	_btn_move.focus_mode = Control.FOCUS_NONE
	_btn_move.pressed.connect(func(): Game.use_skill("move", ""))
	skill_box.add_child(_btn_move)
	
	# Skill 4: Shield
	_btn_shield = Button.new()
	_btn_shield.text = "[4] SHIELD (%d EP)" % Config.COST_SHIELD
	_btn_shield.focus_mode = Control.FOCUS_NONE
	_btn_shield.pressed.connect(func(): Game.use_skill("shield", ""))
	skill_box.add_child(_btn_shield)


# ── STATE & SIGNAL HANDLERS ─────────────────────────────────
func _on_state_changed() -> void:
	_update_ui()


func _on_points_changed(new_points: int) -> void:
	if _current_points != -9999 and new_points != _current_points:
		var delta: int = new_points - _current_points
		_spawn_floating_number(delta)
	_current_points = new_points
	_points_label.text = "EP: %d" % new_points
	_update_skill_buttons(new_points)


func _on_player_died(lives_left: int) -> void:
	_update_lives(lives_left)


func _update_ui() -> void:
	var state: Dictionary = Game.get_state()
	if state.is_empty():
		return
	
	# 1. Update Points
	var pts: int = state.get("points", Config.POINTS_START)
	if _current_points == -9999:
		_current_points = pts
	elif pts != _current_points:
		var delta: int = pts - _current_points
		_spawn_floating_number(delta)
		_current_points = pts
	
	_points_label.text = "EP: %d" % pts
	_update_skill_buttons(pts)
	
	# 2. Update Lives
	var lives: int = state.get("lives", 3)
	_update_lives(lives)
	
	# 3. Update Ship Parts
	var parts: Dictionary = state.get("parts", {"collected": 0, "total": 1})
	var collected: int = parts.get("collected", 0)
	var total: int = parts.get("total", 1)
	_parts_label.text = "PARTS: %d / %d" % [collected, total]
	
	# 4. Update Planet Name & Dimension
	var planet: String = state.get("planet", "Moon")
	_planet_label.text = "PLANET: %s" % planet.to_upper()
	
	var world: String = state.get("world", "A")
	if world == "B":
		_dimension_label.text = "[SOURCE LAYER — WORLD B]"
		_dimension_label.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	else:
		_dimension_label.text = "[REALITY — WORLD A]"
		_dimension_label.add_theme_color_override("font_color", Color(0.9, 0.65, 1.0))


func _update_lives(lives_count: int) -> void:
	for i in range(_life_icons.size()):
		if i < lives_count:
			_life_icons[i].text = "♥"
			_life_icons[i].add_theme_color_override("font_color", COLOR_HEART_ACTIVE)
		else:
			_life_icons[i].text = "♡"
			_life_icons[i].add_theme_color_override("font_color", COLOR_HEART_EMPTY)


func _update_skill_buttons(points: int) -> void:
	_btn_delete.disabled = (points < Config.COST_DELETE)
	_btn_duplicate.disabled = (points < Config.COST_DUPLICATE)
	_btn_move.disabled = (points < Config.COST_MOVE)
	_btn_shield.disabled = (points < Config.COST_SHIELD)


# ── FLOATING NUMBER ANIMATION ───────────────────────────────
func _spawn_floating_number(delta: int) -> void:
	if delta == 0:
		return
	
	var label: Label = Label.new()
	var text_sign: String = "+" if delta > 0 else ""
	label.text = "%s%d EP" % [text_sign, delta]
	
	var color: Color = COLOR_EP_GAIN if delta > 0 else COLOR_EP_LOSS
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	
	# Position near the points counter (top right area)
	var spawn_x: float = _points_label.global_position.x + randf_range(-15.0, 15.0)
	var spawn_y: float = _points_label.global_position.y + 30.0
	label.position = Vector2(spawn_x, spawn_y)
	_float_container.add_child(label)
	
	# Animate: float upward and fade out
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", spawn_y - 45.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)
