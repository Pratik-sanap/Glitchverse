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
		"time":      0.0,
		"shielded":  false,
		"invulnerable_timer": 0.0
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
	if _state.is_empty() or _state.get("status","playing") != "playing":
		return

	# Rule: can only switch while standing inside a portal zone
	var p: Dictionary = _state["player"]
	if not _check_portal_zone(p):
		return   # silently ignore — no warning spam while playing

	# Toggle dimension
	var new_world: String = "B" if _state["world"] == "A" else "A"
	_state["world"] = new_world

	# Update _last_spawn to this portal's centre so death respawns here
	var portals: Array = _state.get("portals", [])
	var pr: Dictionary = _player_rect(p)
	for portal in portals:
		if _rects_overlap(pr, portal):
			_last_spawn = Vector2(
				float(portal["x"]) + float(portal["w"]) * 0.5,
				float(portal["y"]) + float(portal["h"])   # feet at bottom of portal
			)
			break

	emit_signal("state_changed")



func use_skill(skill_name: String, target_id: String = "") -> void:
	if _state.is_empty() or _state.get("status", "playing") != "playing":
		return

	var current_world: String = _state.get("world", "A")

	# World restrictions:
	# delete, duplicate, move can ONLY be used in Dimension B
	# shield can ONLY be used in Dimension A
	if skill_name == "shield":
		if current_world != "A":
			return
	else:
		if current_world != "B":
			return

	# Cost check
	var cost: int = 0
	match skill_name:
		"delete":    cost = Config.COST_DELETE
		"duplicate": cost = Config.COST_DUPLICATE
		"move":      cost = Config.COST_MOVE
		"shield":    cost = Config.COST_SHIELD
		_:           return

	var pts: int = _state.get("points", 0)
	if pts < cost:
		return   # cannot afford skill

	# Handle shield skill (affects Nova directly, no target entity needed)
	if skill_name == "shield":
		if _state.get("shielded", false):
			return   # Shield is already active, don't charge EP again
		_state["points"] = pts - cost
		_state["shielded"] = true
		emit_signal("points_changed", _state["points"])
		emit_signal("state_changed")
		return

	# Locate target entity in World B
	var target: Dictionary = {}
	if target_id.is_empty():
		target = _find_nearest_skill_target(skill_name)
	else:
		target = _find_entity_by_id(target_id)

	if target.is_empty():
		return

	# Target must be in current world and not already deleted
	if target.get("world", "") != current_world:
		return
	if target.get("deleted", false):
		return
	if skill_name == "duplicate" and target.get("duplicated", false):
		return

	# Verify range to target
	var p: Dictionary = _state.get("player", {})
	if not _is_in_skill_range(p, target):
		return

	# Deduct cost
	pts -= cost

	# Apply skill effects
	match skill_name:
		"delete":
			target["deleted"] = true
			target["active"]  = false
			_sync_twin(target)
			pts += Config.REWARD_CLEAR_OBSTACLE

		"duplicate":
			target["duplicated"] = true
			var twin_id: String = str(target.get("twinId", ""))
			var twin: Dictionary = _find_entity_by_id(twin_id) if not twin_id.is_empty() else {}
			if not twin.is_empty():
				if twin.get("type", "") == "pit":
					twin["deleted"] = true
					twin["active"]  = false
				elif twin.get("type", "") == "wall":
					twin["active"]  = true
					twin["deleted"] = false

			# Ensure a solid wall platform exists in World A across the gap
			var wall_id: String = "dup_wall_" + str(target.get("id", ""))
			var existing_wall: Dictionary = _find_entity_by_id(wall_id)
			if existing_wall.is_empty() and (twin.is_empty() or twin.get("type", "") != "wall"):
				var bridge_wall: Dictionary = {
					"id": wall_id,
					"type": "wall",
					"world": "A",
					"x": target["x"],
					"y": target["y"],
					"w": target.get("w", 32),
					"h": target.get("h", 32),
					"active": true,
					"deleted": false
				}
				_state["entities"].append(bridge_wall)

			pts += Config.REWARD_CLEAR_OBSTACLE

		"move":
			# Shift obstacle upward / out of the way
			var shift: float = float(target.get("h", 200.0))
			target["y"] = float(target.get("y", 0.0)) - shift
			_sync_twin(target)
			pts += Config.REWARD_CLEAR_OBSTACLE

	_state["points"] = pts
	emit_signal("points_changed", pts)
	emit_signal("state_changed")

func reset_level() -> void:
	if _state.is_empty():
		return
	var lvl_id: int = int(_state.get("level_id", 1))
	load_level(lvl_id)

func get_state() -> Dictionary:
	return _state.duplicate(true)

# ─────────────────────────────────────────────────────────
# PORTAL & TWIN HELPERS  (Step 4)
# ─────────────────────────────────────────────────────────

## Returns true if the player's AABB overlaps any portal zone rect.
func _check_portal_zone(p: Dictionary) -> bool:
	var pr: Dictionary = _player_rect(p)
	for portal in _state.get("portals", []):
		if _rects_overlap(pr, portal):
			return true
	return false


## O(n) lookup — returns the entity Dictionary (by reference inside the Array)
## or an empty dict if not found.
func _find_entity_by_id(entity_id: String) -> Dictionary:
	for ent in _state.get("entities", []):
		if str(ent.get("id", "")) == entity_id:
			return ent
	return {}


## Called by skills after editing a B-world entity.
## Mirrors the B entity's active/deleted/position onto its A twin.
## Only copies the fields that skills can change (deleted, active, x, y).
func _sync_twin(b_entity: Dictionary) -> void:
	var twin_id: String = str(b_entity.get("twinId", ""))
	if twin_id.is_empty():
		return
	var twin: Dictionary = _find_entity_by_id(twin_id)
	if twin.is_empty():
		return

	# Mirror deletion
	twin["deleted"] = b_entity.get("deleted", false)
	twin["active"]  = not twin["deleted"]

	# Mirror position (used by Move skill in Step 5)
	twin["x"] = b_entity.get("x", twin.get("x", 0.0))
	twin["y"] = b_entity.get("y", twin.get("y", 0.0))


# ─────────────────────────────────────────────────────────
# SKILL HELPERS  (Step 5)
# ─────────────────────────────────────────────────────────

## Returns true if the entity's AABB or center is within Config.SKILL_RANGE of the player.
func _is_in_skill_range(p: Dictionary, ent: Dictionary) -> bool:
	var px: float = float(p.get("x", 0.0))
	var py: float = float(p.get("y", 0.0)) - Config.PLAYER_HEIGHT * 0.5
	var ex: float = float(ent.get("x", 0.0)) + float(ent.get("w", 32.0)) * 0.5
	var ey: float = float(ent.get("y", 0.0)) + float(ent.get("h", 32.0)) * 0.5

	# Euclidean distance between player center and entity center
	var dist: float = Vector2(px, py).distance_to(Vector2(ex, ey))
	if dist <= Config.SKILL_RANGE:
		return true

	# Generous check: also check distance from player feet/center to entity bounding box
	var ew: float = float(ent.get("w", 32.0))
	var eh: float = float(ent.get("h", 32.0))
	var nearest_x: float = clampf(px, float(ent.get("x", 0.0)), float(ent.get("x", 0.0)) + ew)
	var nearest_y: float = clampf(py, float(ent.get("y", 0.0)), float(ent.get("y", 0.0)) + eh)
	return Vector2(px, py).distance_to(Vector2(nearest_x, nearest_y)) <= Config.SKILL_RANGE


## Finds the nearest active editBlock matching skill_name in World B within range.
func _find_nearest_skill_target(skill_name: String) -> Dictionary:
	var p: Dictionary = _state.get("player", {})
	if p.is_empty():
		return {}

	var best_ent: Dictionary = {}
	var min_dist: float = Config.SKILL_RANGE + 9999.0
	var px: float = float(p.get("x", 0.0))
	var py: float = float(p.get("y", 0.0)) - Config.PLAYER_HEIGHT * 0.5

	for ent in _state.get("entities", []):
		if ent.get("world", "") != "B":
			continue
		if ent.get("deleted", false) or not ent.get("active", true):
			continue
		if ent.get("type", "") != "editBlock":
			continue
		if skill_name != "" and ent.get("skill", "") != skill_name:
			continue

		if _is_in_skill_range(p, ent):
			var ex: float = float(ent.get("x", 0.0)) + float(ent.get("w", 32.0)) * 0.5
			var ey: float = float(ent.get("y", 0.0)) + float(ent.get("h", 32.0)) * 0.5
			var dist: float = Vector2(px, py).distance_to(Vector2(ex, ey))
			if dist < min_dist:
				min_dist = dist
				best_ent = ent

	return best_ent



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

	# ── Invulnerability timer countdown ───────────────────
	var inv_timer: float = float(_state.get("invulnerable_timer", 0.0))
	if inv_timer > 0.0:
		_state["invulnerable_timer"] = maxf(0.0, inv_timer - delta)

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

	# ── Interactions (Energy cells, Ship parts, Objective, Exit) ─
	_check_interactions(p, delta)

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
			# If player is currently invulnerable (e.g. just absorbed a hit or respawned), ignore hazard
			if float(_state.get("invulnerable_timer", 0.0)) > 0.0:
				continue

			if _state.get("shielded", false):
				_state["shielded"] = false
				# Grant invulnerability frames (1.5s) so the player can safely walk/jump past the hazard/monster
				_state["invulnerable_timer"] = 1.5
				emit_signal("state_changed")
				return
			_kill_player()
			return  # one death per frame is enough


# ─────────────────────────────────────────────────────────
# DEATH  (cost + respawn — full EP/life logic in Step 6)
# ─────────────────────────────────────────────────────────

func _kill_player() -> void:
	if _state.get("status", "playing") != "playing":
		return

	_state["shielded"] = false
	_state["invulnerable_timer"] = 1.0  # 1.0s grace period upon respawn

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


# ─────────────────────────────────────────────────────────
# INTERACTIONS & OBJECTIVES  (Step 6)
# ─────────────────────────────────────────────────────────

func _check_interactions(p: Dictionary, delta: float) -> void:
	if _state.get("status", "playing") != "playing":
		return

	var current_world: String = _state.get("world", "A")
	var pr: Dictionary = _player_rect(p)

	# ── Dimension B: Crate Pushing & Objective ────────────
	if current_world == "B":
		for ent in _state.get("entities", []):
			if ent.get("world", "") == "B" and ent.get("type", "") == "crate" and not ent.get("deleted", false):
				_update_crate_push(p, ent, delta)
		_check_b_objective()
		return

	# ── Dimension A: Energy Cells, Ship Parts, and Exit Portal ──
	var entities: Array = _state.get("entities", [])
	for ent in entities:
		if ent.get("world", "A") != "A":
			continue
		if ent.get("deleted", false) or not ent.get("active", true):
			continue

		var etype: String = str(ent.get("type", ""))
		var er: Dictionary = {
			"x": float(ent["x"]), "y": float(ent["y"]),
			"w": float(ent.get("w", 32)), "h": float(ent.get("h", 32))
		}

		if not _rects_overlap(pr, er):
			continue

		match etype:
			"energyCell":
				if not ent.get("collected", false):
					ent["collected"] = true
					ent["active"] = false
					_state["points"] = _state.get("points", 0) + Config.REWARD_ENERGY_CELL
					emit_signal("points_changed", _state["points"])
					emit_signal("state_changed")

			"shipPart":
				if not ent.get("collected", false):
					ent["collected"] = true
					ent["active"] = false
					var parts: Dictionary = _state.get("parts", {"collected": 0, "total": 1})
					parts["collected"] = int(parts.get("collected", 0)) + 1
					_state["parts"] = parts
					_state["points"] = _state.get("points", 0) + Config.REWARD_SHIP_PART
					emit_signal("points_changed", _state["points"])
					emit_signal("state_changed")

			"exit":
				var parts: Dictionary = _state.get("parts", {})
				var collected: int = int(parts.get("collected", 0))
				var total: int = int(parts.get("total", 1))
				if collected >= total:
					# Level Cleared!
					var lives: int = int(_state.get("lives", 3))
					var life_bonus: int = lives * Config.REWARD_LIFE_END
					_state["points"] = _state.get("points", 0) + life_bonus
					_state["status"] = "won"
					emit_signal("points_changed", _state["points"])
					emit_signal("level_cleared", _state["points"])
					emit_signal("state_changed")
					return


func _update_crate_push(p: Dictionary, crate: Dictionary, delta: float) -> void:
	var pr: Dictionary = _player_rect(p)
	var cw: float = float(crate.get("w", 56))
	var ch: float = float(crate.get("h", 56))
	var cr: Dictionary = {
		"x": float(crate["x"]), "y": float(crate["y"]),
		"w": cw, "h": ch
	}
	if _rects_overlap(pr, cr):
		var p_center_x: float = float(p.get("x", 0.0))
		var c_center_x: float = float(crate["x"]) + cw * 0.5
		var push_dir: float = 1.0 if p_center_x < c_center_x else -1.0
		var push_amount: float = Config.RUN_SPEED * 0.8 * delta * push_dir
		crate["x"] = float(crate["x"]) + push_amount


func _check_b_objective() -> void:
	var obj: Dictionary = _state.get("objective", {})
	if obj.get("completed", false):
		return

	var crate: Dictionary = {}
	var plate: Dictionary = {}
	for ent in _state.get("entities", []):
		if ent.get("world", "") != "B":
			continue
		if ent.get("type", "") == "crate" and not ent.get("deleted", false):
			crate = ent
		elif ent.get("type", "") == "plate" and not ent.get("deleted", false):
			plate = ent

	if crate.is_empty() or plate.is_empty():
		return

	var cr: Dictionary = {
		"x": float(crate["x"]), "y": float(crate["y"]),
		"w": float(crate.get("w", 56)), "h": float(crate.get("h", 56))
	}
	var plr: Dictionary = {
		"x": float(plate["x"]), "y": float(plate["y"]),
		"w": float(plate.get("w", 64)), "h": float(plate.get("h", 16))
	}

	if _rects_overlap(cr, plr):
		obj["completed"] = true
		var reward: int = Config.REWARD_B_OBJECTIVE
		var time_limit: float = float(obj.get("timeLimit", 0.0))
		if time_limit > 0.0 and float(_state.get("time", 0.0)) <= time_limit:
			reward += Config.REWARD_B_TIME_BONUS
		_state["points"] = _state.get("points", 0) + reward
		emit_signal("points_changed", _state["points"])
		emit_signal("state_changed")


