class_name PuzzleSystem
extends RefCounted

## Decoupled Puzzle Verification & Economy System for Rift Runner.
## Handles Dimension B puzzle objectives (pushBlockToTarget),
## move limit bonuses, and point payouts.
## Pure GDScript - no scene/drawing dependencies.

const ConfigScript = preload("res://src/logic/config.gd")
const GridSystemScript = preload("res://src/logic/grid_system.gd")

## Evaluates whether the B-dimension puzzle conditions are met.
## Standard agreed type: "pushBlockToTarget" (also accepts "push_to_target", "push_block")
## Verifies that a block object specifically sits on a target object/tile.
static func is_puzzle_condition_met(puzzle_data: Dictionary, objects: Array, world_b_grid: Array) -> bool:
	if puzzle_data.is_empty():
		return false

	var puzzle_type: String = str(puzzle_data.get("type", "pushBlockToTarget")).to_lower()

	if puzzle_type in ["pushblocktotarget", "push_to_target", "push_block"]:
		var target_coords: Array[Vector2i] = []

		# 1. Target from object with type == "target"
		for obj in objects:
			if obj is Dictionary and not obj.get("deleted", false) and str(obj.get("type", "")).to_lower() == "target":
				var opos: Dictionary = obj.get("pos", {})
				target_coords.append(Vector2i(int(opos.get("x", -1)), int(opos.get("y", -1))))

		# 2. Target from puzzle_data["targetPos"]
		if puzzle_data.has("targetPos"):
			var tp: Dictionary = puzzle_data["targetPos"]
			target_coords.append(Vector2i(int(tp.get("x", -1)), int(tp.get("y", -1))))

		# 3. Target tiles 'T' in worldB
		for y in range(world_b_grid.size()):
			var row: String = str(world_b_grid[y])
			for x in range(row.length()):
				if row[x] == "T":
					target_coords.append(Vector2i(x, y))

		if target_coords.is_empty():
			return false

		# Check: does a block object (not just any object) sit on the target?
		for t_coord in target_coords:
			for obj in objects:
				if not (obj is Dictionary) or obj.get("deleted", false):
					continue
				var obj_type: String = str(obj.get("type", "")).to_lower()
				if obj_type in ["pushblock", "block", "crate"]:
					var opos: Dictionary = obj.get("pos", {})
					if int(opos.get("x", -1)) == t_coord.x and int(opos.get("y", -1)) == t_coord.y:
						return true

	return false

## Calculates puzzle reward and move-limit bonus.
static func calculate_rewards(puzzle_data: Dictionary, moves_taken: int) -> Dictionary:
	var base_reward: int = ConfigScript.REWARD_PUZZLE_SOLVE
	var bonus_reward: int = 0
	var move_limit: int = int(puzzle_data.get("moveLimit", 0))

	if move_limit > 0 and moves_taken <= move_limit:
		bonus_reward = ConfigScript.REWARD_PUZZLE_MOVE_BONUS

	return {
		"base": base_reward,
		"bonus": bonus_reward,
		"total": base_reward + bonus_reward
	}
