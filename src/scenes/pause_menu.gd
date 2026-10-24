## pause_menu.gd — In-Game Pause & Warp Menu for Rift Runner.
## Role C owns this file. No game rules logic here.
## Provides options to Resume, Restart Level, Jump to any Unlocked Level,
## go to Planet Select, or return to Main Menu.
extends Control

signal resume_requested
signal restart_requested
signal level_selected(level_id: int)
signal level_select_screen_requested
signal main_menu_requested

const GameProgress = preload("res://src/scenes/game_progress.gd")

const PLANETS: Array[Dictionary] = [
	{
		"id": 1,
		"name": "MOON",
		"desc": "Lunar Outpost",
		"color": Color(0.65, 0.72, 0.85)
	},
	{
		"id": 2,
		"name": "MARS",
		"desc": "Crimson Dunes",
		"color": Color(1.0, 0.38, 0.25)
	},
	{
		"id": 3,
		"name": "EUROPA",
		"desc": "Frozen Depths",
		"color": Color(0.2, 0.9, 1.0)
	},
	{
		"id": 4,
		"name": "GLITCH CORE",
		"desc": "Source Dimension",
		"color": Color(0.85, 0.3, 1.0)
	}
]

var _level_id: int = 1
var _subtitle_lbl: Label
var _levels_grid: GridContainer
var _click_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio()
	_build_ui()
	_refresh_display()


func setup(level_id: int) -> void:
	_level_id = level_id
	GameProgress.load_progress()
	if _subtitle_lbl:
		_refresh_display()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_P:
			_play_click()
			emit_signal("resume_requested")
			get_viewport().set_input_as_handled()


func _setup_audio() -> void:
	_click_player = AudioStreamPlayer.new()
	_click_player.process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists("res://assets/sounds/click.wav"):
		_click_player.stream = load("res://assets/sounds/click.wav")
	add_child(_click_player)


func _play_click() -> void:
	if _click_player and _click_player.stream:
		if _click_player.is_playing():
			_click_player.stop()
		_click_player.play()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# 1. Dark semi-transparent blur backdrop
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.05, 0.09, 0.88)
	add_child(bg)

	# 2. Centered Modal Dialog
	var center_root: CenterContainer = CenterContainer.new()
	center_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_root)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 440)
	center_root.add_child(panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.07, 0.13, 0.97)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.0, 0.85, 1.0, 0.85)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", panel_style)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	# Header
	var title_lbl: Label = Label.new()
	title_lbl.text = "⏸ MISSION PAUSED"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	box.add_child(title_lbl)

	_subtitle_lbl = Label.new()
	_subtitle_lbl.text = "LEVEL 1: MOON — Lunar Outpost"
	_subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_lbl.add_theme_font_size_override("font_size", 13)
	_subtitle_lbl.add_theme_color_override("font_color", Color(0.8, 0.88, 1.0))
	box.add_child(_subtitle_lbl)

	var sep1: HSeparator = HSeparator.new()
	box.add_child(sep1)

	# Primary Actions (Resume / Restart)
	var action_box: HBoxContainer = HBoxContainer.new()
	action_box.add_theme_constant_override("separation", 14)
	box.add_child(action_box)

	var btn_resume: Button = _create_styled_button(
		"▶ RESUME [ESC]",
		Color(0.08, 0.28, 0.22, 0.95),
		Color(0.1, 1.0, 0.6, 0.9),
		Color(0.2, 1.0, 0.7)
	)
	btn_resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_resume.custom_minimum_size = Vector2(0, 44)
	btn_resume.pressed.connect(func():
		_play_click()
		emit_signal("resume_requested")
	)
	action_box.add_child(btn_resume)

	var btn_restart: Button = _create_styled_button(
		"↺ RESTART LEVEL",
		Color(0.28, 0.2, 0.08, 0.95),
		Color(1.0, 0.75, 0.2, 0.9),
		Color(1.0, 0.85, 0.3)
	)
	btn_restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_restart.custom_minimum_size = Vector2(0, 44)
	btn_restart.pressed.connect(func():
		_play_click()
		emit_signal("restart_requested")
	)
	action_box.add_child(btn_restart)

	var sep2: HSeparator = HSeparator.new()
	box.add_child(sep2)

	# Unlocked Level Select Section
	var level_header: Label = Label.new()
	level_header.text = "WARP TO DESTINATION (UNLOCKED LEVELS):"
	level_header.add_theme_font_size_override("font_size", 12)
	level_header.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	box.add_child(level_header)

	_levels_grid = GridContainer.new()
	_levels_grid.columns = 2
	_levels_grid.add_theme_constant_override("h_separation", 12)
	_levels_grid.add_theme_constant_override("v_separation", 10)
	box.add_child(_levels_grid)

	var sep3: HSeparator = HSeparator.new()
	box.add_child(sep3)

	# Navigation Buttons (Planet Select / Main Menu)
	var nav_box: HBoxContainer = HBoxContainer.new()
	nav_box.add_theme_constant_override("separation", 12)
	box.add_child(nav_box)

	var btn_planet_select: Button = _create_styled_button(
		"🌌 PLANET SELECT",
		Color(0.09, 0.12, 0.2, 0.9),
		Color(0.3, 0.5, 0.8, 0.7),
		Color(0.85, 0.92, 1.0)
	)
	btn_planet_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_planet_select.custom_minimum_size = Vector2(0, 36)
	btn_planet_select.pressed.connect(func():
		_play_click()
		emit_signal("level_select_screen_requested")
	)
	nav_box.add_child(btn_planet_select)

	var btn_main_menu: Button = _create_styled_button(
		"🏠 MAIN MENU",
		Color(0.14, 0.08, 0.1, 0.9),
		Color(0.7, 0.25, 0.35, 0.7),
		Color(1.0, 0.8, 0.85)
	)
	btn_main_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_main_menu.custom_minimum_size = Vector2(0, 36)
	btn_main_menu.pressed.connect(func():
		_play_click()
		emit_signal("main_menu_requested")
	)
	nav_box.add_child(btn_main_menu)


func _refresh_display() -> void:
	var planet_name: String = "UNKNOWN"
	for p in PLANETS:
		if p["id"] == _level_id:
			planet_name = p["name"] + " — " + p["desc"]
			break
	if _subtitle_lbl:
		_subtitle_lbl.text = "CURRENT: LEVEL %d — %s" % [_level_id, planet_name]

	if not _levels_grid:
		return

	for child in _levels_grid.get_children():
		child.queue_free()

	for p in PLANETS:
		var lvl_id: int = p["id"]
		var is_unlocked: bool = GameProgress.is_unlocked(lvl_id)
		var is_current: bool = (lvl_id == _level_id)
		var p_name: String = p["name"]
		var p_col: Color = p["color"]

		var btn: Button
		if is_current:
			btn = _create_styled_button(
				"▶ [CURRENT] LVL %d: %s" % [lvl_id, p_name],
				Color(0.1, 0.2, 0.28, 0.95),
				Color(0.0, 0.85, 1.0, 0.9),
				Color(0.4, 0.95, 1.0)
			)
			btn.pressed.connect(func():
				_play_click()
				emit_signal("resume_requested")
			)
		elif is_unlocked:
			btn = _create_styled_button(
				"WARP LVL %d: %s" % [lvl_id, p_name],
				Color(0.08, 0.1, 0.16, 0.9),
				p_col * 0.7,
				p_col
			)
			btn.pressed.connect(func():
				_play_click()
				emit_signal("level_selected", lvl_id)
			)
		else:
			btn = _create_styled_button(
				"🔒 LVL %d: %s (LOCKED)" % [lvl_id, p_name],
				Color(0.05, 0.06, 0.08, 0.6),
				Color(0.2, 0.22, 0.28, 0.4),
				Color(0.4, 0.42, 0.48)
			)
			btn.disabled = true
			btn.mouse_default_cursor_shape = Control.CURSOR_ARROW

		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 38)
		_levels_grid.add_child(btn)


func _create_styled_button(text: String, bg: Color, border: Color, font_col: Color = Color.WHITE) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

	var norm: StyleBoxFlat = StyleBoxFlat.new()
	norm.bg_color = bg
	norm.border_color = border
	norm.border_width_left = 1
	norm.border_width_right = 1
	norm.border_width_top = 1
	norm.border_width_bottom = 1
	norm.corner_radius_top_left = 6
	norm.corner_radius_top_right = 6
	norm.corner_radius_bottom_left = 6
	norm.corner_radius_bottom_right = 6
	norm.content_margin_left = 12
	norm.content_margin_right = 12
	norm.content_margin_top = 6
	norm.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", norm)

	var hov: StyleBoxFlat = norm.duplicate()
	hov.bg_color = bg.lightened(0.14)
	hov.border_color = border.lightened(0.25)
	hov.border_width_left = 2
	hov.border_width_right = 2
	hov.border_width_top = 2
	hov.border_width_bottom = 2
	btn.add_theme_stylebox_override("hover", hov)

	var press: StyleBoxFlat = norm.duplicate()
	press.bg_color = bg.darkened(0.18)
	btn.add_theme_stylebox_override("pressed", press)

	var dis: StyleBoxFlat = norm.duplicate()
	dis.bg_color = Color(0.05, 0.06, 0.08, 0.5)
	dis.border_color = Color(0.2, 0.22, 0.26, 0.3)
	btn.add_theme_stylebox_override("disabled", dis)

	return btn
