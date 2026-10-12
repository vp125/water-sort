class_name PuzzleSolver
extends RefCounted
## Depth-first solver used to verify generated levels and to power hints.
## A solution is an Array[Vector2i] of (from, to) moves; null if none was found within the budget.


## Search state, so a search can be run in short slices (see `step`) instead of freezing the game.
var done := false
var solution: Variant = null  # Array[Vector2i] once found; null if none within the node budget
var _capacity := 4
var _max_nodes := 5000
var _nodes: Array = []
var _visited := {}
var _stack: Array = []
var _expanded := 0


## Runs the whole search at once.
static func solve(tubes: Array, capacity: int, max_nodes: int = 5000) -> Variant:
	var job := begin(tubes, capacity, max_nodes)
	job.step(0)
	return job.solution


## Prepares a search without running any of it. Call `step()` until `done`.
static func begin(tubes: Array, capacity: int, max_nodes: int = 5000) -> PuzzleSolver:
	var job := PuzzleSolver.new()
	job._capacity = capacity
	job._max_nodes = max_nodes
	var start := _copy(tubes)
	job._nodes = [{"tubes": start, "parent": -1, "move": Vector2i(-1, -1)}]
	job._visited = {_key(start): true}
	job._stack = [0]
	return job


## Searches for at most `budget_usec` microseconds (0 = until finished). Safe to call after `done`.
func step(budget_usec: int = 0) -> void:
	if done:
		return
	var started := Time.get_ticks_usec()
	while not _stack.is_empty():
		var idx: int = _stack.pop_back()
		var current: Array = _nodes[idx]["tubes"]
		if PuzzleState.all_sorted(current, _capacity):
			solution = _path(_nodes, idx)
			done = true
			return
		_expanded += 1
		if _expanded > _max_nodes:
			done = true
			return
		var moves := _moves(current, _capacity)
		# Push in reverse so the most promising move is explored first.
		for m in range(moves.size() - 1, -1, -1):
			var move: Vector2i = moves[m]
			var next := _copy(current)
			PuzzleState.apply_pour(next, _capacity, move.x, move.y)
			var key := _key(next)
			if _visited.has(key):
				continue
			_visited[key] = true
			_nodes.append({"tubes": next, "parent": idx, "move": move})
			_stack.append(_nodes.size() - 1)
		if budget_usec > 0 and Time.get_ticks_usec() - started >= budget_usec:
			return
	done = true


static func _moves(tubes: Array, capacity: int) -> Array[Vector2i]:
	var merges: Array[Vector2i] = []
	var to_empty: Array[Vector2i] = []
	for from in tubes.size():
		var src: Array = tubes[from]
		if src.is_empty():
			continue
		var uniform := PuzzleState.run_length(src) == src.size()
		for to in tubes.size():
			if not PuzzleState.can_pour_between(tubes, capacity, from, to):
				continue
			if (tubes[to] as Array).is_empty():
				if uniform:
					continue  # moving a uniform tube into an empty one gains nothing
				to_empty.append(Vector2i(from, to))
			else:
				merges.append(Vector2i(from, to))
	return merges + to_empty


static func _copy(tubes: Array) -> Array:
	var out: Array = []
	for tube: Array in tubes:
		out.append(tube.duplicate())
	return out


## Order-independent key: tubes sorted so permutations of tubes count as one state.
static func _key(tubes: Array) -> String:
	var parts := PackedStringArray()
	for tube: Array in tubes:
		var s := ""
		for c: int in tube:
			s += char(65 + c)
		parts.append(s)
	parts.sort()
	return "|".join(parts)


static func _path(nodes: Array, last: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var i := last
	while nodes[i]["parent"] != -1:
		path.push_front(nodes[i]["move"])
		i = nodes[i]["parent"]
	return path
