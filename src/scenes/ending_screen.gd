## ending_screen.gd — Victory & Campaign Ending Screen for Rift Runner.
## Role C owns this file. No game rules logic here.
extends Control

const GameProgress = preload("res://src/scenes/game_progress.gd")


func _ready() -> void:
	GameProgress.load_progress()
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Deep Cosmic Blue Background
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.09, 1.0)
	add_child(bg)

	var center_root: CenterContainer = CenterContainer.new()
	center_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_root)

	var center_box: VBoxContainer = VBoxContainer.new()
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 20)
	center_box.custom_minimum_size = Vector2(720, 0)
	center_root.add_child(center_box)

	# Badge
	var badge: Label = Label.new()
	badge.text = "★ GLITCHVERSE MISSION COMPLETE ★"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	badge.add_theme_font_size_override("font_size", 16)
	center_box.add_child(badge)

	# Main Title
	var title: Label = Label.new()
	title.text = "RIFT ENGINE RESTORED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	title.add_theme_font_size_override("font_size", 42)
	center_box.add_child(title)

	# Narrative
	var story: Label = Label.new()
	story.text = "Astronaut Nova has synchronized the Source Layer and Reality!\n" + \
		"All ship components were recovered across Moon, Mars, Europa, and the Glitch Core.\n" + \
		"The warp drive ignited and stabilized the dimensional tear."
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	story.add_theme_font_size_override("font_size", 15)
	center_box.add_child(story)

	# Score Summary Panel
	var panel: PanelContainer = PanelContainer.new()
	var pstyle: StyleBoxFlat = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.07, 0.1, 0.16, 0.9)
	pstyle.border_width_left = 2
	pstyle.border_width_right = 2
	pstyle.border_width_top = 2
	pstyle.border_width_bottom = 2
	pstyle.border_color = Color(0.0, 0.75, 1.0, 0.5)
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	pstyle.content_margin_left = 24
	pstyle.content_margin_right = 24
	pstyle.content_margin_top = 16
	pstyle.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", pstyle)
	center_box.add_child(panel)

	var score_grid: GridContainer = GridContainer.new()
	score_grid.columns = 2
	score_grid.add_theme_constant_override("h_separation", 36)
	score_grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(score_grid)

	_add_score_row(score_grid, "Level 1 — Moon Outpost:", "%d EP" % GameProgress.level_scores.get(1, 0))
	_add_score_row(score_grid, "Level 2 — Mars Dunes:", "%d EP" % GameProgress.level_scores.get(2, 0))
	_add_score_row(score_grid, "Level 3 — Europa Ice:", "%d EP" % GameProgress.level_scores.get(3, 0))
	_add_score_row(score_grid, "Level 4 — Glitch Core:", "%d EP" % GameProgress.level_scores.get(4, 0))
	_add_score_row(score_grid, "★ TOTAL CAMPAIGN SCORE:", "%d EP" % GameProgress.total_campaign_score, Color(0.1, 1.0, 0.5))

	# Credits
	var credits: Label = Label.new()
	credits.text = "Team GlitchVerse — Artificial Arcade PS01\n" + \
		"Role A: Core Logic • Role B: Level Design • Role C: UI, Art & Audio"
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_theme_color_override("font_color", Color(0.5, 0.58, 0.7))
	credits.add_theme_font_size_override("font_size", 12)
	center_box.add_child(credits)

	# Buttons
	var btn_box: HBoxContainer = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 16)
	center_box.add_child(btn_box)

	var btn_again: Button = Button.new()
	btn_again.text = "PLAY CAMPAIGN AGAIN"
	btn_again.custom_minimum_size = Vector2(200, 44)
	btn_again.pressed.connect(func():
		GameProgress.selected_level = 1
		Game.load_level(1)
		get_tree().change_scene_to_file("res://src/scenes/gameplay.tscn")
	)
	btn_box.add_child(btn_again)

	var btn_select: Button = Button.new()
	btn_select.text = "LEVEL SELECT"
	btn_select.custom_minimum_size = Vector2(160, 44)
	btn_select.pressed.connect(func(): get_tree().change_scene_to_file("res://src/scenes/level_select.tscn"))
	btn_box.add_child(btn_select)

	var btn_title: Button = Button.new()
	btn_title.text = "MAIN MENU"
	btn_title.custom_minimum_size = Vector2(140, 44)
	btn_title.pressed.connect(func(): get_tree().change_scene_to_file("res://src/scenes/title_screen.tscn"))
	btn_box.add_child(btn_title)


func _add_score_row(grid: GridContainer, label: String, val: String, col: Color = Color.WHITE) -> void:
	var l: Label = Label.new()
	l.text = label
	l.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	grid.add_child(l)

	var v: Label = Label.new()
	v.text = val
	v.add_theme_color_override("font_color", col)
	grid.add_child(v)
