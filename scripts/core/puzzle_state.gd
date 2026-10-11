class_name PuzzleState
extends RefCounted
## Pure game rules for water sort. No nodes, no rendering, so it is easy to test.
##
## Rules:
##  - A tube holds up to `capacity` units; each unit is a colour id (int).
##  - Tubes are stored bottom -> top; the last element is the top.
##  - You may pour from tube A into tube B if A is not empty, B is not full,
##    and B is empty or B's top colour equals A's top colour.
##  - A pour moves the whole run of same-coloured units on top of A that fits in B.
##  - Solved: every tube is empty, or full with a single colour.

var capacity: int
var tubes: Array = []  # Array of Array[int]
var _history: Array = []  # Array of {from, to, count}


func _init(p_tubes: Array = [], p_capacity: int = 4) -> void:
	capacity = p_capacity
	for tube in p_tubes:
		tubes.append((tube as Array).duplicate())


# --- Instance API -----------------------------------------------------------

func is_empty(index: int) -> bool:
	return (tubes[index] as Array).is_empty()


func can_pour(from: int, to: int) -> bool:
	return can_pour_between(tubes, capacity, from, to)


func pour(from: int, to: int) -> bool:
	if not can_pour(from, to):
		return false
	var count := apply_pour(tubes, capacity, from, to)
	_history.append({"from": from, "to": to, "count": count})
	return true


func can_undo() -> bool:
	return not _history.is_empty()


func undo() -> bool:
	if _history.is_empty():
		return false
	var entry: Dictionary = _history.pop_back()
	var src: Array = tubes[entry["to"]]
	var dst: Array = tubes[entry["from"]]
	for _i in entry["count"]:
		dst.append(src.pop_back())
	return true


func move_count() -> int:
	return _history.size()


func add_empty_tube() -> void:
	tubes.append([])


func is_solved() -> bool:
	return all_sorted(tubes, capacity)


# --- Static helpers (shared with the solver) --------------------------------

static func run_length(tube: Array) -> int:
	if tube.is_empty():
		return 0
	var color = tube[-1]
	var n := 0
	for k in range(tube.size() - 1, -1, -1):
		if tube[k] != color:
			break
		n += 1
	return n


static func can_pour_between(p_tubes: Array, p_capacity: int, from: int, to: int) -> bool:
	if from == to:
		return false
	var src: Array = p_tubes[from]
	var dst: Array = p_tubes[to]
	if src.is_empty() or dst.size() >= p_capacity:
		return false
	return dst.is_empty() or dst[-1] == src[-1]


## Mutates `p_tubes`. Caller must have checked can_pour_between. Returns units moved.
static func apply_pour(p_tubes: Array, p_capacity: int, from: int, to: int) -> int:
	var src: Array = p_tubes[from]
	var dst: Array = p_tubes[to]
	var count := mini(run_length(src), p_capacity - dst.size())
	var color = src[-1]
	for _i in count:
		src.pop_back()
		dst.append(color)
	return count


static func all_sorted(p_tubes: Array, p_capacity: int) -> bool:
	for tube: Array in p_tubes:
		if tube.is_empty():
			continue
		if tube.size() != p_capacity or run_length(tube) != p_capacity:
			return false
	return true
