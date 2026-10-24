## level_select.gd — Planet Selection Screen for Rift Runner.
## Role C owns this file. No game rules logic here.
extends Control

const PLANETS: Array[Dictionary] = [
	{
		"id": 1,
		"name": "MOON",
		"desc": "Lunar Outpost\nTutorial & Basics",
		"parts": 1,
		"color": Color(0.65, 0.72, 0.85),
		"bg_accent": Color(0.12, 0.16, 0.24),
		"sprite": "res://assets/art/bg/Pixel-Art Cratered Moon Sprite.png"
	},
	{
		"id": 2,
		"name": "MARS",
		"desc": "Crimson Dunes\nWide Pits & Heavy Walls",
		"parts": 1,
		"color": Color(1.0, 0.38, 0.25),
		"bg_accent": Color(0.24, 0.08, 0.08),
		"sprite": "res://assets/art/bg/Pixel-Art Mars Sprite.png"
	},
	{
		"id": 3,
		"name": "EUROPA",
		"desc": "Frozen Depths\nDouble Spikes & Monster Rift",
		"parts": 2,
		"color": Color(0.2, 0.9, 1.0),
		"bg_accent": Color(0.06, 0.18, 0.24),
		"sprite": "res://assets/art/bg/Pixel Art Europa Ice Moon.png"
	},
	{
		"id": 4,
		"name": "GLITCH CORE",
		"desc": "Source Dimension\nFinal Core Synchronization",
		"parts": 2,
		"color": Color(0.85, 0.3, 1.0),
		"bg_accent": Color(0.2, 0.06, 0.25),
		"sprite": "res://assets/art/bg/Glitched Neon Energy Planet.png"
	}
]


func _ready() -> void:
	GameProgress.load_progress()
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.08, 1.0)
	add_child(bg)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 28)
	main_vbox.offset_left = 40
	main_vbox.offset_top = 36
	main_vbox.offset_right = -40
	main_vbox.offset_bottom = -36
	add_child(main_vbox)

	# 1. Header
	var header_box: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(header_box)

	var title_lbl: Label = Label.new()
	title_lbl.text = "DESTINATION PLANET SELECT"
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(title_lbl)

	var score_lbl: Label = Label.new()
	score_lbl.text = "CAMPAIGN SCORE: %d EP" % GameProgress.total_campaign_score
	score_lbl.add_theme_font_size_override("font_size", 18)
	score_lbl.add_theme_color_override("font_color", Color(0.1, 1.0, 0.45))
	header_box.add_child(score_lbl)

	# 2. Planet Cards Container
	var cards_hbox: HBoxContainer = HBoxContainer.new()
	cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_hbox.add_theme_constant_override("separation", 20)
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(cards_hbox)

	for p_info in PLANETS:
		var card: PanelContainer = _create_planet_card(p_info)
		cards_hbox.add_child(card)

	# 3. Bottom Controls
	var bottom_box: HBoxContainer = HBoxContainer.new()
	bottom_box.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(bottom_box)

	var btn_back: Button = Button.new()
	btn_back.text = "← BACK TO TITLE"
	btn_back.custom_minimum_size = Vector2(220, 44)
	btn_back.add_theme_font_size_override("font_size", 15)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://src/scenes/title_screen.tscn"))
	bottom_box.add_child(btn_back)


func _create_planet_card(info: Dictionary) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(270, 420)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lvl_id: int = int(info["id"])
	var unlocked: bool = GameProgress.is_unlocked(lvl_id)
	var accent: Color = info["color"]

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = info["bg_accent"] if unlocked else Color(0.06, 0.07, 0.1, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = accent if unlocked else Color(0.2, 0.24, 0.3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	# Planet Number
	var num_lbl: Label = Label.new()
	num_lbl.text = "LEVEL 0%d" % lvl_id
	num_lbl.add_theme_color_override("font_color", accent if unlocked else Color(0.4, 0.45, 0.5))
	num_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(num_lbl)

	# Planet Title
	var name_lbl: Label = Label.new()
	name_lbl.text = info["name"]
	name_lbl.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(0.5, 0.55, 0.6))
	name_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_lbl)

	# Planet Visual Sprite / Orb
	var orb_center: CenterContainer = CenterContainer.new()
	orb_center.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(orb_center)

	var sprite_path: String = String(info.get("sprite", ""))
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var planet_rect: TextureRect = TextureRect.new()
		planet_rect.custom_minimum_size = Vector2(88, 88)
		planet_rect.texture = load(sprite_path)
		planet_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		planet_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not unlocked:
			planet_rect.modulate = Color(0.35, 0.35, 0.38, 0.5)
		orb_center.add_child(planet_rect)
	else:
		var orb: ColorRect = ColorRect.new()
		orb.custom_minimum_size = Vector2(64, 64)
		orb.color = accent if unlocked else Color(0.25, 0.28, 0.35)
		orb_center.add_child(orb)

	# Description
	var desc_lbl: Label = Label.new()
	desc_lbl.text = info["desc"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9) if unlocked else Color(0.4, 0.45, 0.5))
	desc_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(desc_lbl)

	# Ship parts required
	var parts_lbl: Label = Label.new()
	parts_lbl.text = "⚙ Ship Parts: %d" % int(info["parts"])
	parts_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if unlocked else Color(0.4, 0.45, 0.5))
	parts_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(parts_lbl)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Best Score or Status
	var best_score: int = int(GameProgress.level_scores.get(lvl_id, 0))
	var status_lbl: Label = Label.new()
	if not unlocked:
		status_lbl.text = "🔒 LOCKED"
		status_lbl.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
	elif best_score > 0:
		status_lbl.text = "✓ CLEARED (%d EP)" % best_score
		status_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	else:
		status_lbl.text = "★ READY FOR LAUNCH"
		status_lbl.add_theme_color_override("font_color", accent)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(status_lbl)

	# Launch Button
	var btn_launch: Button = Button.new()
	btn_launch.text = "LAUNCH MISSION" if unlocked else "LOCKED"
	btn_launch.disabled = not unlocked
	btn_launch.custom_minimum_size = Vector2(0, 42)
	btn_launch.pressed.connect(func(): _on_launch_level(lvl_id))
	vbox.add_child(btn_launch)

	return card


func _on_launch_level(lvl_id: int) -> void:
	GameProgress.selected_level = lvl_id
	Game.load_level(lvl_id)
	get_tree().change_scene_to_file("res://src/scenes/gameplay.tscn")
