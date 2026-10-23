## config.gd — single source of truth for every tunable number
## Role A owns this file.  Change values here to tune feel.
class_name Config
extends RefCounted

# ── Movement ──────────────────────────────────────────────
const RUN_SPEED:       float = 260.0   # max horizontal speed  (px/s)
const ACCELERATION:    float = 1800.0  # how fast we reach run speed (px/s²)
const FRICTION:        float = 2200.0  # how fast we stop       (px/s²)
const GRAVITY:         float = 1600.0  # downward acceleration  (px/s²)
const JUMP_VELOCITY:   float = -620.0  # initial jump impulse   (px/s, negative = up)
const JUMP_CUT_FACTOR: float = 0.4     # multiply vy when jump released early
const COYOTE_TIME:     float = 0.12    # seconds you can still jump after walking off an edge
const JUMP_BUFFER:     float = 0.10    # seconds a jump input is remembered before landing

# ── Skill costs (Energy Points) ───────────────────────────
const COST_DELETE:    int = 15
const COST_DUPLICATE: int = 20
const COST_MOVE:      int = 10
const COST_SHIELD:    int = 10

# ── Skill range ───────────────────────────────────────────
const SKILL_RANGE: float = 120.0  # max distance to target (px)

# ── Points / rewards ──────────────────────────────────────
const POINTS_START:         int = 30
const REWARD_B_OBJECTIVE:   int = 25
const REWARD_B_TIME_BONUS:  int = 10
const REWARD_ENERGY_CELL:   int = 5
const REWARD_CLEAR_OBSTACLE:int = 10
const REWARD_SHIP_PART:     int = 30
const REWARD_LIFE_END:      int = 10  # per life remaining at level end

# ── Death penalty ─────────────────────────────────────────
const DEATH_COST: int = 20

# ── Collision / physics ───────────────────────────────────
const PLAYER_WIDTH:  float = 28.0
const PLAYER_HEIGHT: float = 48.0
const PIT_DEPTH:     float = 9999.0  # y value beyond which the player has fallen into a pit
