## level_clear.gd — Level Cleared screen / overlay for Rift Runner.
## Role C owns this file. No game rules logic here.
extends Control

signal next_level_requested
signal replay_requested
signal level_select_requested

var _level_id: int = 1
var _points: int = 0
var _lives: int = 3

var _title_lbl: Label
var _pts_lbl: Label
var _lives_bonus_lbl: Label
var _total_lbl: Label
var _btn_next: Button


func setup(level_id: int, points: int, lives: int) -> void:
	_level_id = level_id
	_points = points
	_lives = lives
	_update_display()


func _ready() -> void:
	_build_ui()
	_update_display()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Dark semi-transparent blur backdrop
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.1, 0.88)
	add_child(bg)

	var center_root: CenterContainer = CenterContainer.new()
	center_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_root)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 420)
	center_root.add_child(panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.15, 0.98)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.9, 1.0, 0.8)
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

	_title_lbl = Label.new()
	_title_lbl.text = "PLANET ESCAPED!"
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 28)
	_title_lbl.add_theme_color_override("font_color", Color(0.1, 1.0, 0.5))
	box.add_child(_title_lbl)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = "Dimensional Rift Stabilized — Ship Part Secured"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	box.add_child(sub_lbl)

	var sep: HSeparator = HSeparator.new()
	box.add_child(sep)

	# Points Breakdown Grid
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)

	var l1: Label = Label.new()
	l1.text = "Remaining Energy Points:"
	l1.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	grid.add_child(l1)

	_pts_lbl = Label.new()
	_pts_lbl.text = "0 EP"
	_pts_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	grid.add_child(_pts_lbl)

	var l2: Label = Label.new()
	l2.text = "Survival Life Bonus (+10/life):"
	l2.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	grid.add_child(l2)

	_lives_bonus_lbl = Label.new()
	_lives_bonus_lbl.text = "+0 EP"
	_lives_bonus_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	grid.add_child(_lives_bonus_lbl)

	var l3: Label = Label.new()
	l3.text = "★ TOTAL LEVEL SCORE:"
	l3.add_theme_color_override("font_color", Color.WHITE)
	grid.add_child(l3)

	_total_lbl = Label.new()
	_total_lbl.text = "0 EP"
	_total_lbl.add_theme_color_override("font_color", Color(0.1, 1.0, 0.5))
	_total_lbl.add_theme_font_size_override("font_size", 18)
	grid.add_child(_total_lbl)

	var sep2: HSeparator = HSeparator.new()
	box.add_child(sep2)

	# Action Buttons
	var btn_box: VBoxContainer = VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 10)
	box.add_child(btn_box)

	_btn_next = Button.new()
	_btn_next.text = "▶ NEXT PLANET"
	_btn_next.custom_minimum_size = Vector2(0, 42)
	_btn_next.pressed.connect(func(): emit_signal("next_level_requested"))
	btn_box.add_child(_btn_next)

	var h_sub_btns: HBoxContainer = HBoxContainer.new()
	h_sub_btns.add_theme_constant_override("separation", 12)
	btn_box.add_child(h_sub_btns)

	var btn_replay: Button = Button.new()
	btn_replay.text = "↺ REPLAY"
	btn_replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_replay.custom_minimum_size = Vector2(0, 36)
	btn_replay.pressed.connect(func(): emit_signal("replay_requested"))
	h_sub_btns.add_child(btn_replay)

	var btn_select: Button = Button.new()
	btn_select.text = "🌌 PLANET SELECT"
	btn_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_select.custom_minimum_size = Vector2(0, 36)
	btn_select.pressed.connect(func(): emit_signal("level_select_requested"))
	h_sub_btns.add_child(btn_select)


func _update_display() -> void:
	if not _title_lbl:
		return
	_title_lbl.text = "LEVEL %d CLEARED!" % _level_id
	_pts_lbl.text = "%d EP" % _points
	_lives_bonus_lbl.text = "+%d EP (%d lives)" % [_lives * 10, _lives]
	_total_lbl.text = "%d EP" % (_points + _lives * 10)

	if _level_id >= 4:
		_btn_next.text = "★ VIEW ENDING & CREDITS ★"
	else:
		_btn_next.text = "▶ NEXT PLANET (LEVEL %d)" % (_level_id + 1)
