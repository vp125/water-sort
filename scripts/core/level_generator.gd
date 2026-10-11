class_name LevelGenerator
extends RefCounted
## Deterministic level generation: level N always produces the same puzzle.
##
## Difficulty curve (100 levels). Levels 1-50 are frozen: changing them would invalidate
## players' saved best-move records, so new difficulty only ever goes into levels 51+.
##
##  1-50   "Classic":   4-unit tubes, colours ramp 3 -> 12, 2 spare tubes
##                      (boss levels 30, 40, 50 have 1 spare).
##  51-75  "Squeeze":   4-unit tubes, colours ramp 10 -> 12, 1 spare tube
##                      (relief levels 55, 65, 75 have 2 spare).
##  76-100 "Tall tubes": 5-unit tubes, colours ramp 8 -> 12, 2 spare tubes
##                      (boss levels 80, 90, 100 have 1 spare).
##
## Layouts with 2 spare tubes in the classic range are random and verified with PuzzleSolver.
## Levels 51+ are built by scrambling a solved board with exact reverse pours, which guarantees
## a solution exists and records it so tests can replay it.
## The three classic boss levels (30, 40, 50) use the original scramble, which is *not* an
## exact inverse (see `exact` in _scrambled_layout); it cannot change without altering players'
## existing levels, so those are verified with PuzzleSolver in the tests instead.

const LEVEL_COUNT := 100
const CLASSIC_LEVELS := 50  # levels 1..50 use the original, frozen formula
const CAPACITY := 4  # capacity of the classic levels; later levels may differ (see config_for)
const MAX_ATTEMPTS := 40
const SOLVER_BUDGET := 8000


## {colors, empty, capacity, scrambled, exact}
static func config_for(level: int) -> Dictionary:
	if level <= CLASSIC_LEVELS:
		var t := float(level - 1) / float(CLASSIC_LEVELS - 1)
		var colors := 3 + roundi(t * 9.0)
		var empty := 1 if (level >= 30 and level % 10 == 0) else 2
		return {"colors": colors, "empty": empty, "capacity": CAPACITY, "scrambled": empty == 1, "exact": false}
	if level <= 75:
		var colors := 10 + roundi(float(level - 51) / 24.0 * 2.0)
		var relief := level % 5 == 0  # 55, 65, 75 (60 and 70 stay hard)
		var empty := 2 if (relief and level % 10 != 0) else 1
		return {"colors": colors, "empty": empty, "capacity": CAPACITY, "scrambled": true, "exact": true}
	var colors := 8 + roundi(float(level - 76) / 24.0 * 4.0)
	var empty := 1 if level % 10 == 0 else 2
	return {"colors": colors, "empty": empty, "capacity": 5, "scrambled": true, "exact": true}


## Returns Array of Array[int] (bottom -> top).
static func generate(level: int) -> Array:
	return generate_with_solution(level)["tubes"]


## {tubes, solution}: solution is an Array[Vector2i] of (from, to) pours that solves the puzzle,
## or null if not recorded (the legacy boss levels 30/40/50, and an unsolvable fallback layout).
static func generate_with_solution(level: int) -> Dictionary:
	var cfg := config_for(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000003 * level + 17

	if cfg["scrambled"]:
		return _scrambled_layout(rng, cfg)

	var capacity: int = cfg["capacity"]
	var candidate: Array = []
	for _attempt in MAX_ATTEMPTS:
		candidate = _random_layout(rng, cfg)
		if _is_trivial(candidate, capacity):
			continue
		var solution: Variant = PuzzleSolver.solve(candidate, capacity, SOLVER_BUDGET)
		if solution != null:
			return {"tubes": candidate, "solution": solution}
	# Fallback (very unlikely): give the player an extra tube so it stays winnable.
	candidate.append([])
	return {"tubes": candidate, "solution": PuzzleSolver.solve(candidate, capacity, SOLVER_BUDGET * 4)}


static func _random_layout(rng: RandomNumberGenerator, cfg: Dictionary) -> Array:
	var capacity: int = cfg["capacity"]
	var units: Array[int] = []
	for color in cfg["colors"]:
		for _i in capacity:
			units.append(color)
	# Fisher-Yates with our seeded rng (Array.shuffle would use the global rng).
	for i in range(units.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := units[i]
		units[i] = units[j]
		units[j] = tmp

	var tubes: Array = []
	for t in cfg["colors"]:
		tubes.append(units.slice(t * capacity, (t + 1) * capacity))
	for _e in cfg["empty"]:
		tubes.append([])
	return tubes


## Starts from the solved board and applies random *reverse* pours. Each reverse step is chosen
## so that the matching forward pour is legal and moves exactly the units we moved back, hence
## replaying the steps backwards solves the puzzle. Returns {tubes, solution}.
##
## A forward pour moves the *whole* top run of the source tube. So a reverse step is only an
## exact inverse when the tube receiving the units (the forward source) does not already end in
## that colour; `cfg["exact"]` enforces this. With exact=false the original (levels 30/40/50)
## behaviour is kept byte-for-byte, and no solution is recorded.
static func _scrambled_layout(rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	var capacity: int = cfg["capacity"]
	var exact: bool = cfg["exact"]
	var tubes: Array = []
	for color in cfg["colors"]:
		var full: Array = []
		for _i in capacity:
			full.append(color)
		tubes.append(full)
	for _e in cfg["empty"]:
		tubes.append([])

	var reverse_steps: Array[Vector2i] = []  # forward pours, in the order we undid them
	var steps := 0
	var max_steps := 400 + 60 * int(cfg["colors"])
	while steps < max_steps or _is_trivial(tubes, capacity):
		steps += 1
		if steps > max_steps * 4:
			break  # give up on perfect mixing; still solvable
		var from := rng.randi_range(0, tubes.size() - 1)  # forward source (gets the units back)
		var to := rng.randi_range(0, tubes.size() - 1)  # forward destination (loses the units)
		if from == to:
			continue
		var src: Array = tubes[from]
		var dst: Array = tubes[to]
		if dst.is_empty():
			continue
		var color: int = dst[-1]
		var run := PuzzleState.run_length(dst)
		var k := rng.randi_range(1, run)
		# Leftover top must still be this colour (or the tube empty) for the forward pour to be legal.
		if k == run and k != dst.size():
			continue
		if src.size() + k > capacity:
			continue
		var src_run := PuzzleState.run_length(src) if (not src.is_empty() and src[-1] == color) else 0
		if exact and src_run > 0:
			continue
		if src_run + k > capacity - (dst.size() - k):
			continue
		for _i in k:
			dst.pop_back()
			src.append(color)
		reverse_steps.append(Vector2i(from, to))

	reverse_steps.reverse()
	return {"tubes": tubes, "solution": reverse_steps if exact else null}


## Reject layouts that hand the player a free win or pre-sorted tubes.
static func _is_trivial(tubes: Array, capacity: int) -> bool:
	for tube: Array in tubes:
		if tube.size() == capacity and PuzzleState.run_length(tube) == capacity:
			return true
	return false
