class_name GameConfig
extends RefCounted
## Central gameplay tuning values.
##
## Units: distances in meters, times in seconds, angles in radians, speeds in m/s.
## Everything that defines "game feel" lives here so it can be tuned in one place
## and referenced by tests.

# --- Arena -------------------------------------------------------------------
const ARENA_RADIUS := 42.0            ## Radius of the playable island (wall at this radius).
const SPAWN_CLEAR_RADIUS := 11.0      ## No obstacles within this radius of the spawn point.
const SPAWN_CORRIDOR_LENGTH := 22.0   ## Free corridor in front of the spawn heading.
const WATER_LEVEL := -0.55

# --- Snake body ----------------------------------------------------------------
const SPINE_SPACING := 0.2            ## Arc-length between recorded spine points.
const SPINE_CAPACITY := 1024          ## Ring-buffer capacity (=> ~200 m of body).
const BODY_RADIUS := 0.42             ## Visual body radius.
const HEAD_COLLISION_RADIUS := 0.30   ## Slightly forgiving head hit-sphere.
const BODY_COLLISION_RADIUS := 0.36   ## Slightly forgiving body hit-sphere.
const NECK_SKIP := 1.8                ## Body arc-length behind the head ignored for self-collision.
const START_LENGTH := 5.0
const GROWTH_PER_FOOD := 1.05
const GROWTH_PER_RARE := 2.0
const MAX_LENGTH := 190.0
const GROWTH_RATE := 3.5              ## m/s at which the body extends toward its target length.

# --- Movement ------------------------------------------------------------------
const BASE_SPEED := 7.0
const SPEED_PER_STAGE := 0.42
const MAX_CRUISE_SPEED := 12.0
const TURN_RATE := 2.85               ## rad/s at base speed (≈163°/s).
const TURN_RATE_SPEED_GAIN := 0.11    ## Extra rad/s per m/s above base speed.
const STEER_RESPONSE := 0.045         ## Time constant (s) of steering smoothing. Low = snappy.
const SPEED_RESPONSE := 0.35          ## Time constant (s) for speed changes (boost in/out).
const MAX_SIM_STEP := 1.0 / 90.0      ## Simulation sub-step upper bound.

# --- Boost / Surge ---------------------------------------------------------------
const BOOST_MULTIPLIER := 1.55        ## Manual sprint (costs stamina).
const STAMINA_DRAIN := 0.45           ## Stamina per second while boosting (max 1.0).
const STAMINA_REGEN := 0.14           ## Stamina per second while not boosting.
const STAMINA_REGEN_DELAY := 0.8
const STAMINA_MIN_TO_START := 0.12
const SURGE_MULTIPLIER := 1.35        ## Energy-crystal power-up.
const SURGE_DURATION := 5.0
const SURGE_SCORE_MULTIPLIER := 2

# --- Collectibles ----------------------------------------------------------------
const FOOD_COUNT := 3
const PICKUP_RADIUS := 1.25           ## Head-to-collectible distance for pickup.
const MAGNET_RADIUS := 2.4            ## Collectibles drift toward the head inside this radius.
const FOOD_MIN_DIST_FROM_HEAD := 7.0
const FOOD_MIN_DIST_FROM_BODY := 1.6
const FOOD_MIN_DIST_FROM_OBSTACLE := 1.7
const FOOD_MIN_DIST_FROM_WALL := 3.0
const ENERGY_INTERVAL := Vector2(16.0, 24.0)
const ENERGY_LIFETIME := 14.0
const RARE_INTERVAL := Vector2(38.0, 55.0)
const RARE_LIFETIME := 11.0

# --- Scoring ---------------------------------------------------------------------
const SCORE_FOOD := 10
const SCORE_ENERGY := 25
const SCORE_RARE := 150
const SCORE_STAGE_BONUS := 50
const COMBO_WINDOW := 3.2             ## Seconds between pickups to keep a combo alive.
const COMBO_STEP := 0.25              ## Multiplier gained per chained pickup.
const COMBO_MAX := 3.0
const NEAR_MISS_DISTANCE := 0.55      ## Extra clearance that still counts as a "close call".
const NEAR_MISS_SCORE := 5
const NEAR_MISS_COOLDOWN := 1.2

# --- Difficulty --------------------------------------------------------------------
const FOOD_PER_STAGE := 6
const MAX_STAGE := 14
const RISING_OBSTACLES_PER_STAGE := 2
const MAX_RISING_OBSTACLES := 18
const RISE_WARNING_TIME := 1.4
const RISE_DURATION := 1.1
const OBSTACLE_MIN_GAP := 4.2         ## Minimum free gap between obstacle edges.

# --- Session flow --------------------------------------------------------------------
const INTRO_DURATION := 1.6
const DEATH_SEQUENCE_DURATION := 1.9
const DEATH_TIME_SCALE := 0.35


## Cruise speed for a given stage (1-based).
static func cruise_speed_for_stage(stage: int) -> float:
	return minf(BASE_SPEED + SPEED_PER_STAGE * float(maxi(stage, 1) - 1), MAX_CRUISE_SPEED)


## Maximum turn rate (rad/s) at a given speed. Slightly faster turning at higher
## speeds keeps the turning radius from growing too much.
static func turn_rate_for_speed(speed: float) -> float:
	return TURN_RATE + maxf(speed - BASE_SPEED, 0.0) * TURN_RATE_SPEED_GAIN
