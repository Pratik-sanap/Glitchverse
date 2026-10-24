## video_player.gd — Fullscreen video player for cutscenes & credits.
## Role C owns this file.
class_name VideoPlayerScene
extends Control

static var video_path: String = ""
static var next_scene: String = ""
static var post_action: Callable = Callable()

var _video_player: VideoStreamPlayer
var _finished: bool = false


static func play_video(tree: SceneTree, path: String, target_scene: String, on_finish: Callable = Callable()) -> void:
	video_path = path
	next_scene = target_scene
	post_action = on_finish
	tree.change_scene_to_file("res://src/scenes/video_player.tscn")


func _ready() -> void:
	_build_ui()
	_start_playback()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Pure black background
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.BLACK
	add_child(bg)

	# Video stream player
	_video_player = VideoStreamPlayer.new()
	_video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video_player.expand = true
	_video_player.loop = false
	_video_player.finished.connect(_on_video_finished)
	add_child(_video_player)

	# Skip button in bottom right
	var btn_skip: Button = Button.new()
	btn_skip.text = "SKIP [SPACE] ▶"
	btn_skip.custom_minimum_size = Vector2(140, 36)
	btn_skip.offset_right = -24
	btn_skip.offset_bottom = -24
	btn_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	btn_skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	btn_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.75)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.5, 0.6, 0.6)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn_skip.add_theme_stylebox_override("normal", style)
	btn_skip.add_theme_font_size_override("font_size", 12)
	btn_skip.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 0.8))
	btn_skip.pressed.connect(_finish)
	add_child(btn_skip)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			_finish()


func _start_playback() -> void:
	if video_path == "" or not FileAccess.file_exists(video_path):
		print("[VideoPlayer] File not found or empty: ", video_path)
		call_deferred("_finish")
		return

	var stream: VideoStream = null
	if ResourceLoader.exists(video_path):
		stream = load(video_path)
	elif ClassDB.class_exists("VideoStreamTheora"):
		var theora = ClassDB.instantiate("VideoStreamTheora")
		if theora and theora.has_method("set_file"):
			theora.set_file(video_path)
			stream = theora

	if stream:
		_video_player.stream = stream
		_video_player.play()
	else:
		print("[VideoPlayer] Failed to instantiate video stream for: ", video_path)
		call_deferred("_finish")


func _on_video_finished() -> void:
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true

	if _video_player:
		_video_player.stop()

	if post_action.is_valid():
		post_action.call()

	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
