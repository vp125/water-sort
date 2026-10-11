class_name PuzzleSolver
extends RefCounted
## Depth-first solver used to verify generated levels are solvable.
## Returns an Array[Vector2i] of (from, to) moves, or null if none found within budget.


static func solve(tubes: Array, capacity: int, max_nodes: int = 5000) -> Variant:
	var start := _copy(tubes)
	var nodes: Array = [{"tubes": start, "parent": -1, "move": Vector2i(-1, -1)}]
	var visited := {_key(start): true}
	var stack: Array = [0]
	var expanded := 0

	while not stack.is_empty():
		var idx: int = stack.pop_back()
		var current: Array = nodes[idx]["tubes"]
		if PuzzleState.all_sorted(current, capacity):
			return _path(nodes, idx)
		expanded += 1
		if expanded > max_nodes:
			return null
		var moves := _moves(current, capacity)
		# Push in reverse so the most promising move is explored first.
		for m in range(moves.size() - 1, -1, -1):
			var move: Vector2i = moves[m]
			var next := _copy(current)
			PuzzleState.apply_pour(next, capacity, move.x, move.y)
			var key := _key(next)
			if visited.has(key):
				continue
			visited[key] = true
			nodes.append({"tubes": next, "parent": idx, "move": move})
			stack.append(nodes.size() - 1)
	return null


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
