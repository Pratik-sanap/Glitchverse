## game.gd  —  The ONE Node in the logic layer.
## Registered as autoload "Game" in project.godot.
## Owns all game state, runs physics in _physics_process,
## forwards input, and emits signals.
## Role A owns this file.
extends Node

# ── Signals ───────────────────────────────────────────────
signal state_changed
signal points_changed(new_points: int)
signal player_died(lives_left: int)
@warning_ignore("unused_signal")
signal level_cleared(points: int)
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

# ── Spawn tracking (used by respawn in Step 6) ───────────
var _last_spawn: Vector2 = Vector2.ZERO

func load_level(id: int) -> void:
	var data: Dictionary = LevelLoader.load(id)
	if data.is_empty():
		push_error("Game.load_level: failed to load level %d" % id)
		return

	var sp: Dictionary = data["spawn"]
	_last_spawn = Vector2(sp["x"], sp["y"])

	# ── Build full game state ─────────────────────────────
	_state = {
		"level_id": data["id"],
		"world":    "A",
		"player": {
			"x":        _last_spawn.x,
			"y":        _last_spawn.y,
			"vx":       0.0,
			"vy":       0.0,
			"on_ground": false,
			"facing":   1.0
		},
		"points":   data["startPoints"],
		"lives":    data["lives"],
		"parts": {
			"collected": 0,
			"total":     data["parts"]
		},
		"entities":  data["entities"],   # already typed by LevelLoader
		"platforms": data["platforms"],
		"portals":   data["portals"],
		"levelSize": data["levelSize"],
		"gravity":   data["gravity"],
		"objective": data["objective"],
		"status":    "playing",
		"time":      0.0
	}

	# Reset input and timers for a clean start
	_move_axis        = 0.0
	_jump_pressed     = false
	_coyote_timer     = 0.0
	_jump_buffer_timer = 0.0
	_was_on_ground    = false

	emit_signal("state_changed")
	print("Game: level %d (%s) loaded — %d entities, %d platforms." % [
		data["id"], data.get("planet","?"),
		data["entities"].size(), data["platforms"].size()
	])


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

	# ── Advance level timer ────────────────────────────────
	_state["time"] = _state.get("time", 0.0) + delta

	var p: Dictionary = _state["player"]
	var level_gravity: float = float(_state.get("gravity", Config.GRAVITY))

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
	vy += level_gravity * delta

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

	# ── Integrate position then resolve platform collisions ─
	p["x"] = p.get("x", 0.0) + vx * delta
	p["y"] = p.get("y", 0.0) + vy * delta
	p = _move_and_collide(p)

	_was_on_ground = on_ground
	_state["player"] = p

	# ── Hazard checks (spike / monster / pit) ─────────────
	_check_hazards(p)

	emit_signal("state_changed")


# ─────────────────────────────────────────────────────────
# COLLISION  (AABB — no Godot physics engine needed)
# ─────────────────────────────────────────────────────────

# Returns player rect as {x, y, w, h} where (x,y) is top-left corner.
func _player_rect(p: Dictionary) -> Dictionary:
	return {
		"x": p["x"] - Config.PLAYER_WIDTH  * 0.5,
		"y": p["y"] - Config.PLAYER_HEIGHT,
		"w": Config.PLAYER_WIDTH,
		"h": Config.PLAYER_HEIGHT
	}


# Returns true when two rects {x,y,w,h} overlap.
func _rects_overlap(a: Dictionary, b: Dictionary) -> bool:
	return (a["x"] < b["x"] + b["w"] and a["x"] + a["w"] > b["x"] and
			a["y"] < b["y"] + b["h"] and a["y"] + a["h"] > b["y"])


# Resolves player position against all solid platforms.
# Player origin is feet-centre (x = centre, y = bottom).
func _move_and_collide(p: Dictionary) -> Dictionary:
	var platforms: Array = _state.get("platforms", [])

	# Also treat active "wall" entities in the current world as solid.
	var extra_solids: Array = []
	var current_world: String = _state.get("world", "A")
	for ent in _state.get("entities", []):
		if (ent.get("type","") == "wall"
				and ent.get("world", "A") == current_world
				and ent.get("active", true)
				and not ent.get("deleted", false)):
			extra_solids.append({
				"x": float(ent["x"]), "y": float(ent["y"]),
				"w": float(ent.get("w", 32)), "h": float(ent.get("h", 32))
			})

	var all_solids: Array = platforms + extra_solids

	var pr: Dictionary = _player_rect(p)
	p["on_ground"] = false

	for solid in all_solids:
		if not _rects_overlap(pr, solid):
			continue

		# Overlap depths
		var overlap_left:   float = (pr["x"] + pr["w"]) - solid["x"]
		var overlap_right:  float = (solid["x"] + solid["w"]) - pr["x"]
		var overlap_top:    float = (pr["y"] + pr["h"]) - solid["y"]
		var overlap_bottom: float = (solid["y"] + solid["h"]) - pr["y"]

		# Resolve on the axis with the smallest penetration
		var min_h: float = minf(overlap_left, overlap_right)
		var min_v: float = minf(overlap_top,  overlap_bottom)

		if min_v <= min_h:
			# Vertical resolution
			if overlap_top < overlap_bottom:
				# Player landed on top of solid
				p["y"] -= overlap_top
				if p.get("vy", 0.0) > 0.0:
					p["vy"] = 0.0
				p["on_ground"] = true
			else:
				# Player hit ceiling
				p["y"] += overlap_bottom
				if p.get("vy", 0.0) < 0.0:
					p["vy"] = 0.0
		else:
			# Horizontal resolution — push sideways, no velocity zeroing
			if overlap_left < overlap_right:
				p["x"] -= overlap_left
			else:
				p["x"] += overlap_right

		# Recalculate rect after each resolution pass
		pr = _player_rect(p)

	return p


# ─────────────────────────────────────────────────────────
# HAZARDS  (spike, monster, pit)
# ─────────────────────────────────────────────────────────

func _check_hazards(p: Dictionary) -> void:
	if _state.get("status", "playing") != "playing":
		return

	var pr: Dictionary = _player_rect(p)
	var current_world: String = _state.get("world", "A")

	# ── Pit / falling off the bottom ───────────────────────
	var level_h: float = float(_state.get("levelSize", {"h": 720})["h"])
	if p["y"] > level_h + 60.0:
		_kill_player()
		return

	# ── Spikes and monsters in the current world ───────────
	for ent in _state.get("entities", []):
		if ent.get("world", "A") != current_world:
			continue
		if not ent.get("active", true) or ent.get("deleted", false):
			continue

		var etype: String = ent.get("type", "")
		if etype != "spike" and etype != "monster" and etype != "pit":
			continue

		var er: Dictionary = {
			"x": float(ent["x"]), "y": float(ent["y"]),
			"w": float(ent.get("w", 32)), "h": float(ent.get("h", 32))
		}
		if _rects_overlap(pr, er):
			_kill_player()
			return  # one death per frame is enough


# ─────────────────────────────────────────────────────────
# DEATH  (cost + respawn — full EP/life logic in Step 6)
# ─────────────────────────────────────────────────────────

func _kill_player() -> void:
	if _state.get("status", "playing") != "playing":
		return

	# ── Deduct EP ─────────────────────────────────────────
	var pts: int = _state.get("points", 0)
	pts = maxi(pts - Config.DEATH_COST, 0)
	_state["points"] = pts
	emit_signal("points_changed", pts)

	# ── Deduct life ────────────────────────────────────────
	var lives: int = _state.get("lives", 0) - 1
	_state["lives"] = lives

	if lives <= 0:
		_state["status"] = "lost"
		emit_signal("game_over")
		return

	# ── Respawn at last portal / spawn ────────────────────
	var sp: Vector2 = _last_spawn
	_state["player"] = {
		"x":         sp.x,
		"y":         sp.y,
		"vx":        0.0,
		"vy":        0.0,
		"on_ground": false,
		"facing":    1.0
	}
	_coyote_timer      = 0.0
	_jump_buffer_timer = 0.0

	emit_signal("player_died", lives)
	emit_signal("state_changed")

