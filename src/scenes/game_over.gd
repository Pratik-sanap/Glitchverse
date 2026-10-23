## game_over.gd — Game Over screen / overlay for Rift Runner.
## Role C owns this file. No game rules logic here.
extends Control

signal retry_requested
signal level_select_requested
signal main_menu_requested

var _level_id: int = 1


func setup(level_id: int) -> void:
	_level_id = level_id


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Dark red-tinted backdrop
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.02, 0.03, 0.92)
	add_child(bg)

	var center_root: CenterContainer = CenterContainer.new()
	center_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_root)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 360)
	center_root.add_child(panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.04, 0.06, 0.98)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.2, 0.3, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var title: Label = Label.new()
	title.text = "CRITICAL FAILURE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.3))
	box.add_child(title)

	var sub: Label = Label.new()
	sub.text = "All Life Support Depleted\nNova was lost inside the dimensional rift."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.85, 0.8, 0.85))
	box.add_child(sub)

	var sep: HSeparator = HSeparator.new()
	box.add_child(sep)

	# Buttons
	var btn_box: VBoxContainer = VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 12)
	box.add_child(btn_box)

	var btn_retry: Button = Button.new()
	btn_retry.text = "↺ RETRY LEVEL"
	btn_retry.custom_minimum_size = Vector2(0, 44)
	btn_retry.pressed.connect(func(): emit_signal("retry_requested"))
	btn_box.add_child(btn_retry)

	var btn_select: Button = Button.new()
	btn_select.text = "🌌 PLANET SELECT"
	btn_select.custom_minimum_size = Vector2(0, 40)
	btn_select.pressed.connect(func(): emit_signal("level_select_requested"))
	btn_box.add_child(btn_select)

	var btn_menu: Button = Button.new()
	btn_menu.text = "🏠 MAIN MENU"
	btn_menu.custom_minimum_size = Vector2(0, 40)
	btn_menu.pressed.connect(func(): emit_signal("main_menu_requested"))
	btn_box.add_child(btn_menu)
