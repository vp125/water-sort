extends SceneTree
## Headless tests. Run (after one `--import`, which builds the class_name cache):
##   godot --headless --path . --import
##   godot --headless --path . -s tests/run_tests.gd

var _failures := 0


func _init() -> void:
	_test_pour_rules()
	_test_partial_pour_and_undo()
	_test_solved_detection()
	_test_audio_assets()
	_test_color_markers()
	_test_safe_area()
	_test_all_levels()
	if _failures == 0:
		print("ALL TESTS PASSED")
	else:
		printerr("%d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: " + msg)


func _test_pour_rules() -> void:
	var s := PuzzleState.new([[0, 1], [1], [], [0, 0, 0, 0], [2]], 4)
	_check(s.can_pour(0, 1), "matching top colour allowed")
	_check(not s.can_pour(4, 0), "mismatched top colour rejected")
	_check(s.can_pour(0, 2), "pour into empty allowed")
	_check(not s.can_pour(2, 0), "pour from empty rejected")
	_check(not s.can_pour(0, 0), "pour into self rejected")
	_check(not s.can_pour(0, 3), "pour into full tube rejected")


func _test_partial_pour_and_undo() -> void:
	# Source has a run of 3 reds; destination has room for only 2 more.
	var s := PuzzleState.new([[1, 0, 0, 0], [2, 0]], 4)
	_check(s.pour(0, 1), "pour succeeds")
	_check((s.tubes[1] as Array).size() == 4, "destination filled to capacity")
	_check((s.tubes[0] as Array).size() == 2, "only fitting units moved")
	_check(s.move_count() == 1, "move counted")
	s.undo()
	_check(s.tubes[0] == [1, 0, 0, 0] and s.tubes[1] == [2, 0], "undo restores state")
	_check(s.move_count() == 0, "undo removes move")


func _test_solved_detection() -> void:
	_check(PuzzleState.new([[0, 0, 0, 0], [1, 1, 1, 1], []], 4).is_solved(), "sorted is solved")
	_check(not PuzzleState.new([[0, 0, 0], [0, 1, 1, 1], []], 4).is_solved(), "mixed not solved")
	_check(not PuzzleState.new([[0, 0, 0], [], []], 4).is_solved(), "partial tube not solved")


func _test_safe_area() -> void:
	# iPhone-like: 1179x2556 px window shown in a 720x1560 viewport (scale 0.61); notch 177 px,
	# home indicator 102 px.
	var win := Vector2(1179, 2556)
	var safe := Rect2(0, 177, 1179, 2556 - 177 - 102)
	var ins := SafeArea.insets(win, safe, Vector2(720, 1560))
	_check(is_equal_approx(ins.y, 177.0 * 1560.0 / 2556.0), "safe area top inset scaled to viewport units")
	_check(is_equal_approx(ins.w, 102.0 * 1560.0 / 2556.0), "safe area bottom inset scaled")
	_check(ins.x == 0.0 and ins.z == 0.0, "no side insets in portrait")
	_check(SafeArea.insets(win, Rect2(), Vector2(720, 1560)) == Vector4.ZERO, "empty safe area -> no insets")
	_check(SafeArea.insets(win, Rect2(0, 0, 4000, 4000), Vector2(720, 1560)) == Vector4.ZERO,
		"safe area larger than window -> no negative insets")


func _test_color_markers() -> void:
	var seen := {}
	for id in 12:
		seen[ColorMarker.shape_for(id)] = true
	_check(seen.size() == 12, "12 colours map to 12 distinct marker shapes")
	_check(ColorMarker.shape_for(0) == ColorMarker.shape_for(12), "marker ids wrap like the palette")


func _test_audio_assets() -> void:
	# name -> [min, max] seconds, from the sound design brief.
	var spec := {
		"select": [0.10, 0.20], "pour_1": [0.35, 0.90], "pour_2": [0.35, 0.90],
		"pour_3": [0.35, 0.90], "pour_4": [0.35, 0.90], "progress": [0.15, 0.35],
		"tube_complete": [0.50, 0.95], "level_complete": [1.5, 2.5],
		"undo": [0.1, 1.0], "restart": [0.1, 1.0], "hint": [0.1, 1.0], "add_tube": [0.1, 1.0],
	}
	for sfx_name: String in spec:
		var path := "res://assets/audio/sfx/%s.wav" % sfx_name
		_check(ResourceLoader.exists(path), "sfx exists: " + sfx_name)
		if ResourceLoader.exists(path):
			var length: float = (load(path) as AudioStream).get_length()
			_check(length >= spec[sfx_name][0] and length <= spec[sfx_name][1],
				"sfx %s length %.2fs within %s" % [sfx_name, length, str(spec[sfx_name])])
	var music_path := "res://assets/audio/music/ambient_loop.ogg"
	_check(ResourceLoader.exists(music_path), "music exists")
	if ResourceLoader.exists(music_path):
		var m: float = (load(music_path) as AudioStream).get_length()
		_check(m >= 60.0 and m <= 120.0, "music length %.1fs within 60-120s" % m)


func _test_all_levels() -> void:
	_check(LevelGenerator.LEVEL_COUNT == 100, "100 levels")
	for level in range(1, LevelGenerator.LEVEL_COUNT + 1):
		var cfg := LevelGenerator.config_for(level)
		var capacity: int = cfg["capacity"]
		var result := LevelGenerator.generate_with_solution(level)
		var tubes: Array = result["tubes"]
		_check(tubes == LevelGenerator.generate(level), "level %d deterministic" % level)
		_check(tubes.size() == cfg["colors"] + cfg["empty"], "level %d tube count (no fallback tube)" % level)
		_check(cfg["colors"] <= Palette.COLORS.size(), "level %d colours fit the palette" % level)

		var counts := {}
		for tube: Array in tubes:
			_check(tube.size() <= capacity, "level %d tube overfull" % level)
			for c: int in tube:
				counts[c] = counts.get(c, 0) + 1
		_check(counts.size() == cfg["colors"], "level %d colour count" % level)
		for c in counts:
			_check(counts[c] == capacity, "level %d colour %d unit count" % [level, c])
		_check(not PuzzleState.all_sorted(tubes, capacity), "level %d starts unsolved" % level)

		# Replay the generator's own solution through the real game rules.
		var solution: Variant = result["solution"]
		if solution == null and not cfg["exact"]:
			solution = PuzzleSolver.solve(tubes, capacity, 100000)  # legacy boss levels: search for one
		_check(solution != null, "level %d has a solution" % level)
		if solution != null:
			var s := PuzzleState.new(tubes, capacity)
			for m: Vector2i in solution:
				if not s.pour(m.x, m.y):
					_check(false, "level %d solution move illegal" % level)
					break
			_check(s.is_solved(), "level %d solution reaches solved" % level)
