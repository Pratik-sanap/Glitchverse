class_name PuzzleSystem
extends RefCounted

## Decoupled Puzzle Verification & Economy System for Rift Runner.
## Handles Dimension B puzzle objectives (e.g. pushing a block to a target),
## move limit bonuses, and point payouts.
## Pure GDScript - no scene/drawing dependencies.

const ConfigScript = preload("res://src/logic/config.gd")
const GridSystemScript = preload("res://src/logic/grid_system.gd")

## Evaluates whether the B-dimension puzzle conditions are met.
static func is_puzzle_condition_met(puzzle_data: Dictionary, objects: Array, world_b_grid: Array) -> bool:
	if puzzle_data.is_empty():
		return false

	var puzzle_type: String = str(puzzle_data.get("type", "push_block"))

	match puzzle_type:
		"push_block":
			# If a target position is explicitly provided:
			if puzzle_data.has("targetPos"):
				var tp: Dictionary = puzzle_data["targetPos"]
				var target_coord: Vector2i = Vector2i(int(tp.get("x", -1)), int(tp.get("y", -1)))
				for obj in objects:
					if obj is Dictionary and not obj.get("deleted", false):
						var opos: Dictionary = obj.get("pos", {})
						if int(opos.get("x", -1)) == target_coord.x and int(opos.get("y", -1)) == target_coord.y:
							return true

			# If target tiles 'T' are placed in worldB:
			for y in range(world_b_grid.size()):
				var row: String = str(world_b_grid[y])
				for x in range(row.length()):
					if row[x] == "T":
						for obj in objects:
							if obj is Dictionary and not obj.get("deleted", false):
								var opos: Dictionary = obj.get("pos", {})
								if int(opos.get("x", -1)) == x and int(opos.get("y", -1)) == y:
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
