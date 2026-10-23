class_name Config
extends RefCounted

## Game configuration and balance constants for Rift Runner.
## All costs, rewards, and starting values must be defined here.

# Starting values
const STARTING_POINTS: int = 30
const STARTING_LIVES: int = 3
const MAX_LIVES: int = 3
const TOTAL_LEVELS: int = 4

# Earning Energy Points (EP)
const REWARD_PUZZLE_SOLVE: int = 25
const REWARD_PUZZLE_MOVE_BONUS: int = 10
const REWARD_ENERGY_CELL: int = 5
const REWARD_CLEAR_OBSTACLE_SKILL: int = 10
const REWARD_SHIP_PART: int = 30
const REWARD_PER_LIFE_AT_LEVEL_END: int = 10

# Spending & Penalty Energy Points (EP)
const COST_DELETE: int = 15      # Used in Dimension B
const COST_DUPLICATE: int = 20   # Used in Dimension B
const COST_MOVE: int = 10        # Used in Dimension B
const COST_SHIELD: int = 10      # Used in Dimension A
const PENALTY_DEATH: int = 20    # EP lost on death (along with -1 life)
