## title_screen.gd — Main Title & Menu for Rift Runner.
## Role C owns this file. No game rules logic here.
extends Control

const GameProgress = preload("res://src/scenes/game_progress.gd")

var _controls_modal: PanelContainer


func _ready() -> void:
	GameProgress.load_progress()
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# 1. Deep cosmic gradient background
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.09, 1.0)
	add_child(bg)

	# Decorative starfield grid
	var grid: Control = Control.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(grid)
	for i in range(40):
		var star: ColorRect = ColorRect.new()
		star.color = Color(0.4, 0.7, 1.0, randf_range(0.2, 0.8))
		star.size = Vector2(randf_range(1, 3), randf_range(1, 3))
		star.position = Vector2(randf_range(20, 1260), randf_range(20, 700))
		grid.add_child(star)

	# Optional: Background art integration if provided by teammate
	var bg_art_path: String = "res://assets/sprites/title_bg.png"
	if ResourceLoader.exists(bg_art_path):
		var bg_tex: TextureRect = TextureRect.new()
		bg_tex.texture = load(bg_art_path)
		bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.add_child(bg_tex)

	# 2. Main Centered Content (Uses CenterContainer to guarantee within 1280x720 frame)
	var center_root: CenterContainer = CenterContainer.new()
	center_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_root)

	var center: VBoxContainer = VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	center_root.add_child(center)

	# Logo & Badges
	var badge: Label = Label.new()
	badge.text = "ARTIFICIAL ARCADE • PROBLEM STATEMENT 01"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0, 0.75))
	badge.add_theme_font_size_override("font_size", 13)
	center.add_child(badge)

	# Title Graphic or Typography
	var logo_path: String = "res://assets/sprites/title_logo.png"
	if ResourceLoader.exists(logo_path):
		var logo_rect: TextureRect = TextureRect.new()
		logo_rect.texture = load(logo_path)
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_rect.custom_minimum_size = Vector2(480, 100)
		center.add_child(logo_rect)
	else:
		var title: Label = Label.new()
		title.text = "RIFT RUNNER"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
		title.add_theme_font_size_override("font_size", 54)
		center.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "DUAL-DIMENSION SOURCE LAYER PLATFORMER"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	center.add_child(subtitle)

	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	center.add_child(spacer)

	# Buttons Container
	var btn_box: VBoxContainer = VBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 14)
	center.add_child(btn_box)

	var btn_play: Button = _create_styled_btn("▶  START MISSION", Color(0.0, 0.8, 1.0))
	btn_play.pressed.connect(_on_play_pressed)
	btn_box.add_child(btn_play)

	var btn_select: Button = _create_styled_btn("🌌  PLANET SELECT", Color(0.7, 0.4, 1.0))
	btn_select.pressed.connect(_on_level_select_pressed)
	btn_box.add_child(btn_select)

	var btn_how: Button = _create_styled_btn("📖  HOW TO PLAY", Color(0.3, 0.85, 0.5))
	btn_how.pressed.connect(_on_how_to_play_pressed)
	btn_box.add_child(btn_how)

	# Footer
	var footer: Label = Label.new()
	footer.text = "Astronaut Nova • Moon • Mars • Europa • Glitch Core"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
	footer.add_theme_font_size_override("font_size", 12)
	center.add_child(footer)

	# Build Controls Modal (hidden by default)
	_build_controls_modal()


func _create_styled_btn(text: String, accent: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 48)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", accent)
	
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.85)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = accent.darkened(0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style)

	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = Color(0.12, 0.18, 0.28, 0.95)
	hover_style.border_color = accent
	btn.add_theme_stylebox_override("hover", hover_style)

	return btn


func _build_controls_modal() -> void:
	var modal_center: CenterContainer = CenterContainer.new()
	modal_center.name = "ModalCenter"
	modal_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_center)

	_controls_modal = PanelContainer.new()
	_controls_modal.name = "ControlsModal"
	_controls_modal.custom_minimum_size = Vector2(560, 420)
	_controls_modal.visible = false

	var modal_style: StyleBoxFlat = StyleBoxFlat.new()
	modal_style.bg_color = Color(0.06, 0.08, 0.13, 0.96)
	modal_style.border_width_left = 2
	modal_style.border_width_right = 2
	modal_style.border_width_top = 2
	modal_style.border_width_bottom = 2
	modal_style.border_color = Color(0.0, 0.85, 1.0, 0.7)
	modal_style.corner_radius_top_left = 8
	modal_style.corner_radius_top_right = 8
	modal_style.corner_radius_bottom_left = 8
	modal_style.corner_radius_bottom_right = 8
	modal_style.content_margin_left = 28
	modal_style.content_margin_right = 28
	modal_style.content_margin_top = 24
	modal_style.content_margin_bottom = 24
	_controls_modal.add_theme_stylebox_override("panel", modal_style)
	modal_center.add_child(_controls_modal)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_controls_modal.add_child(box)

	var head: Label = Label.new()
	head.text = "MISSION BRIEFING & CONTROLS"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	head.add_theme_font_size_override("font_size", 20)
	box.add_child(head)

	var desc: Label = Label.new()
	desc.text = "Astronaut Nova is stranded across 4 planets in the GlitchVerse.\n" + \
		"You must run, jump, manipulate reality, collect ship parts, and reach the exit portal."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	desc.add_theme_font_size_override("font_size", 14)
	box.add_child(desc)

	var sep: HSeparator = HSeparator.new()
	box.add_child(sep)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)

	_add_ctrl_row(grid, "A / D or Left / Right", "Move horizontally")
	_add_ctrl_row(grid, "W / Space", "Jump (variable height)")
	_add_ctrl_row(grid, "F (Inside Portal)", "Switch Reality (A) ↔ Source Layer (B)")
	_add_ctrl_row(grid, "1 / 2 / 3 / 4", "Skills: 1:Delete, 2:Duplicate, 3:Move, 4:Shield")
	_add_ctrl_row(grid, "Objective in B", "Push crate onto pad to earn 25 EP + Time bonus")
	_add_ctrl_row(grid, "Goal", "Collect all ship parts & enter the EXIT portal")

	var btn_close: Button = Button.new()
	btn_close.text = "UNDERSTOOD"
	btn_close.custom_minimum_size = Vector2(160, 36)
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_close.pressed.connect(func(): _controls_modal.visible = false)
	box.add_child(btn_close)


func _add_ctrl_row(grid: GridContainer, key: String, action: String) -> void:
	var l_key: Label = Label.new()
	l_key.text = key
	l_key.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	grid.add_child(l_key)

	var l_act: Label = Label.new()
	l_act.text = action
	l_act.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	grid.add_child(l_act)


func _on_play_pressed() -> void:
	# Launch current selected level
	Game.load_level(GameProgress.selected_level)
	get_tree().change_scene_to_file("res://src/scenes/gameplay.tscn")


func _on_level_select_pressed() -> void:
	get_tree().change_scene_to_file("res://src/scenes/level_select.tscn")


func _on_how_to_play_pressed() -> void:
	_controls_modal.visible = true
