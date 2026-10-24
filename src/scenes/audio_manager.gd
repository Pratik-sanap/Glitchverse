## audio_manager.gd -- Central sound controller for Rift Runner.
## Role C owns this file. No game logic here.
##
## Sound map:
##   blipSelect.wav  -> movement (left/right held)
##   click.wav       -> skill / button use
##   random.wav      -> dimension switch (A <-> B)
##   pickupCoin.wav  -> EP pickup / points gained
##   powerUp.wav     -> ship part collected / level cleared
##   explosion.wav   -> player death / hazard hit
##   jump.wav        -> jump
extends Node

# ── Players (one per sound channel) ──────────────────────────────────────────
var _snd_move:      AudioStreamPlayer
var _snd_click:     AudioStreamPlayer
var _snd_dimension: AudioStreamPlayer
var _snd_pickup:    AudioStreamPlayer
var _snd_powerup:   AudioStreamPlayer
var _snd_explosion: AudioStreamPlayer
var _snd_jump:      AudioStreamPlayer

# State tracking to avoid spamming
var _last_pts: int = 0
var _move_cooldown: float = 0.0
const MOVE_INTERVAL: float = 0.18   # seconds between blips while walking


func _ready() -> void:
	_load_sounds()
	_connect_signals()


func _process(delta: float) -> void:
	_move_cooldown = maxf(0.0, _move_cooldown - delta)
	# Tick movement blip while player is actually moving
	var axis: float = Input.get_axis("move_left", "move_right")
	if abs(axis) > 0.1 and _move_cooldown <= 0.0:
		_play(_snd_move)
		_move_cooldown = MOVE_INTERVAL


# ── Setup ─────────────────────────────────────────────────────────────────────
func _load_sounds() -> void:
	_snd_move      = _make_player("res://assets/sounds/blipSelect.wav",  0.0,  -6.0)
	_snd_click     = _make_player("res://assets/sounds/click.wav",       0.0,   0.0)
	_snd_dimension = _make_player("res://assets/sounds/random.wav",      0.0,   0.0)
	_snd_pickup    = _make_player("res://assets/sounds/pickupCoin.wav",  0.0,   0.0)
	_snd_powerup   = _make_player("res://assets/sounds/powerUp.wav",     0.0,   0.0)
	_snd_explosion = _make_player("res://assets/sounds/explosion.wav",   0.0,   0.0)
	_snd_jump      = _make_player("res://assets/sounds/jump.wav",        0.0,  -3.0)


func _make_player(path: String, pitch: float, volume_db: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.volume_db = volume_db
	if pitch != 0.0:
		player.pitch_scale = pitch
	if ResourceLoader.exists(path):
		player.stream = load(path)
	else:
		push_warning("AudioManager: sound not found: %s" % path)
	add_child(player)
	return player


func _connect_signals() -> void:
	# player_died  -> explosion
	if not Game.player_died.is_connected(_on_player_died):
		Game.player_died.connect(_on_player_died)
	# points_changed -> pickup coin (EP gain) or powerup (large gain like ship part)
	if not Game.points_changed.is_connected(_on_points_changed):
		Game.points_changed.connect(_on_points_changed)
	# level_cleared -> powerup jingle
	if not Game.level_cleared.is_connected(_on_level_cleared):
		Game.level_cleared.connect(_on_level_cleared)
	# state_changed -> detect dimension switches and skill use
	if not Game.state_changed.is_connected(_on_state_changed):
		Game.state_changed.connect(_on_state_changed)


# ── Helpers ───────────────────────────────────────────────────────────────────
var _last_world: String = "A"
var _last_skill_pts: int = -1   # detect skill EP deduction

func _play(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	if player.is_playing():
		player.stop()
	player.play()


# ── Public API (called by gameplay.gd for explicit events) ───────────────────
func play_jump() -> void:
	_play(_snd_jump)


func play_skill() -> void:
	_play(_snd_click)


# ── Signal Handlers ───────────────────────────────────────────────────────────
func _on_player_died(_lives_left: int) -> void:
	_play(_snd_explosion)


func _on_points_changed(new_pts: int) -> void:
	var delta: int = new_pts - _last_pts
	_last_pts = new_pts
	if delta <= 0:
		# Skill cost deduction or death penalty -- no sound here (explosion covers death)
		return
	if delta >= 30:
		# Ship part (+30) or level clear bonus -- big reward sound
		_play(_snd_powerup)
	else:
		# Energy cell (+5), objective bonus (+25), etc.
		_play(_snd_pickup)


func _on_level_cleared(_points: int) -> void:
	_play(_snd_powerup)


func _on_state_changed() -> void:
	var state: Dictionary = Game.get_state()
	if state.is_empty():
		return
	# Dimension switch detection
	var world: String = state.get("world", "A")
	if world != _last_world:
		_last_world = world
		_play(_snd_dimension)