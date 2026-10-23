## game.gd  —  The ONE Node in the logic layer.
## Registered as autoload "Game" in project.godot.
## Owns all game state, runs physics in _physics_process,
## forwards input, and emits signals.
## Role A owns this file.
extends Node

# ── Signals ───────────────────────────────────────────────
signal state_changed
@warning_ignore("unused_signal")
signal points_changed(new_points: int)
@warning_ignore("unused_signal")
signal player_died(lives_left: int)
@warning_ignore("unused_signal")
signal level_cleared(points: int)
@warning_ignore("unused_signal")
signal game_over

# ── Internal state ────────────────────────────────────────
var _state: Dictionary = {}
var _move_axis: float   = 0.0
var _jump_pressed: bool = false

# ── Coyote / jump-buffer timers ───────────────────────────
var _coyote_timer:      float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_ground:     bool  = false

# ─────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────

func load_level(id: int) -> void:
	# Stub — will be filled in Step 2
	push_warning("Game.load_level(%d) not yet implemented." % id)

func set_move(axis: float) -> void:
	_move_axis = clampf(axis, -1.0, 1.0)

func jump(pressed: bool) -> void:
	if pressed:
		_jump_buffer_timer = Config.JUMP_BUFFER
	_jump_pressed = pressed

func switch_world() -> void:
	# Stub — will be filled in Step 4
	push_warning("Game.switch_world() not yet implemented.")

func use_skill(skill_name: String, target_id: String) -> void:
	# Stub — will be filled in Step 5
	push_warning("Game.use_skill(%s, %s) not yet implemented." % [skill_name, target_id])

func reset_level() -> void:
	# Stub — will be filled in Step 6
	push_warning("Game.reset_level() not yet implemented.")

func get_state() -> Dictionary:
	return _state.duplicate(true)

# ─────────────────────────────────────────────────────────
# PHYSICS
# ─────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _state.is_empty():
		return
	if _state.get("status", "playing") != "playing":
		return

	var p: Dictionary = _state["player"]

	# ── Coyote time tracking ──────────────────────────────
	var on_ground: bool = p.get("on_ground", false)
	if on_ground:
		_coyote_timer = Config.COYOTE_TIME
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	# ── Jump buffer countdown ─────────────────────────────
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	# ── Horizontal movement ───────────────────────────────
	var vx: float = p.get("vx", 0.0)
	if _move_axis != 0.0:
		vx = move_toward(vx, _move_axis * Config.RUN_SPEED, Config.ACCELERATION * delta)
		p["facing"] = sign(_move_axis)
	else:
		vx = move_toward(vx, 0.0, Config.FRICTION * delta)
	p["vx"] = vx

	# ── Gravity ───────────────────────────────────────────
	var vy: float = p.get("vy", 0.0)
	vy += Config.GRAVITY * delta

	# ── Jump ──────────────────────────────────────────────
	var can_jump: bool = _coyote_timer > 0.0
	if _jump_buffer_timer > 0.0 and can_jump:
		vy = Config.JUMP_VELOCITY
		_coyote_timer      = 0.0
		_jump_buffer_timer = 0.0

	# ── Short-jump cut ────────────────────────────────────
	if not _jump_pressed and vy < 0.0:
		vy *= pow(Config.JUMP_CUT_FACTOR, delta * 60.0)

	p["vy"] = vy
	_was_on_ground = on_ground
	# Collision against platforms is handled in Step 3.
	# For now we just store the updated velocity.
	_state["player"] = p
	emit_signal("state_changed")
