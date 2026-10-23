class_name SkillSystem
extends RefCounted

## Decoupled Skill Execution & Economy System for Rift Runner.
## Manages costs, dimension requirements, and effects for:
## - Delete (Dimension B, 15 EP)
## - Duplicate (Dimension B, 20 EP)
## - Move (Dimension B, 10 EP)
## - Shield (Dimension A, 10 EP)
## All costs and rewards read directly from Config.
## Pure GDScript - no scene/drawing dependencies.

const ConfigScript = preload("res://src/logic/config.gd")
const SyncSystemScript = preload("res://src/logic/sync_system.gd")
const GridSystemScript = preload("res://src/logic/grid_system.gd")

## Returns the required dimension ("A" or "B") for a given skill.
static func get_required_world(skill_name: String) -> String:
	match skill_name.to_lower():
		"shield":
			return "A"
		"delete", "duplicate", "move":
			return "B"
		_:
			return ""

## Returns the EP cost of a skill from Config.
static func get_cost(skill_name: String) -> int:
	match skill_name.to_lower():
		"delete":
			return ConfigScript.COST_DELETE
		"duplicate":
			return ConfigScript.COST_DUPLICATE
		"move":
			return ConfigScript.COST_MOVE
		"shield":
			return ConfigScript.COST_SHIELD
		_:
			return 999999

## Validates if a skill can currently be cast given the game state.
static func can_use_skill(skill_name: String, current_world: String, current_points: int, target_id: String, objects: Array) -> bool:
	var req_world: String = get_required_world(skill_name)
	if req_world == "" or current_world != req_world:
		return false

	var cost: int = get_cost(skill_name)
	if current_points < cost:
		return false

	var s_name: String = skill_name.to_lower()
	if s_name == "shield":
		return true

	# Target object must exist and not be already deleted
	var target: Dictionary = SyncSystemScript.find_object(objects, target_id)
	if target.is_empty() or target.get("deleted", false):
		return false

	return true

## Executes the skill, synchronizing twins and calculating point changes.
## Returns a result dictionary: {"success": bool, "cost": int, "reward": int}
static func execute_skill(
	skill_name: String,
	target_id: String,
	extra_param: Variant,
	state: Dictionary,
	world_a_grid: Array
) -> Dictionary:
	var s_name: String = skill_name.to_lower()
	var current_world: String = state.get("world", "A")
	var current_points: int = int(state.get("points", 0))
	var objects: Array = state.get("objects", [])

	if not can_use_skill(s_name, current_world, current_points, target_id, objects):
		return {"success": false, "cost": 0, "reward": 0}

	var cost: int = get_cost(s_name)
	var reward: int = 0

	match s_name:
		"shield":
			# Shield handled by Game autoload state
			return {"success": true, "cost": cost, "reward": 0}

		"delete":
			var target: Dictionary = SyncSystemScript.find_object(objects, target_id)
			var twin: Dictionary = SyncSystemScript.find_twin(objects, target_id)
			var is_obstacle: bool = (
				target.get("type", "") in ["spike", "monster", "wall"] or
				twin.get("type", "") in ["spike", "monster", "wall"]
			)

			var ok: bool = SyncSystemScript.sync_delete(objects, target_id, world_a_grid)
			if not ok:
				return {"success": false, "cost": 0, "reward": 0}

			if is_obstacle:
				reward += ConfigScript.REWARD_CLEAR_OBSTACLE_SKILL

			return {"success": true, "cost": cost, "reward": reward}

		"move":
			if not (extra_param is Vector2i):
				return {"success": false, "cost": 0, "reward": 0}

			var target_pos: Vector2i = extra_param
			var ok: bool = SyncSystemScript.sync_move(objects, target_id, target_pos)
			if not ok:
				return {"success": false, "cost": 0, "reward": 0}

			return {"success": true, "cost": cost, "reward": 0}

		"duplicate":
			var target_pos: Vector2i
			if extra_param is Vector2i:
				target_pos = extra_param
			else:
				var src: Dictionary = SyncSystemScript.find_object(objects, target_id)
				var spos: Dictionary = src.get("pos", {})
				target_pos = Vector2i(int(spos.get("x", 0)) + 1, int(spos.get("y", 0)))

			var tile_in_a: String = GridSystemScript.get_tile_at(world_a_grid, target_pos)
			var bridged_gap: bool = (tile_in_a == " " or tile_in_a == "G")

			var new_obj: Dictionary = SyncSystemScript.sync_duplicate(objects, target_id, target_pos, world_a_grid)
			if new_obj.is_empty():
				return {"success": false, "cost": 0, "reward": 0}

			if bridged_gap:
				reward += ConfigScript.REWARD_CLEAR_OBSTACLE_SKILL

			return {"success": true, "cost": cost, "reward": reward}

		_:
			return {"success": false, "cost": 0, "reward": 0}
