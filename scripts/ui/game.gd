extends Control
## Gameplay screen: owns a PuzzleState and renders it with Tube nodes.

const TUBE_MAX_W := 104.0
const GAP := 44.0
const ROW_GAP := 64.0
const LAYER_H := 72.0
const PAD_TOTAL := Tube.TOP_PAD + Tube.PAD
const MIN_LAYOUT_SCALE := 0.45  # smallest uniform shrink applied to fit short screens
const POUR_ANGLE := 0.75  # radians the source tube tilts while pouring
const POUR_HEIGHT := 50.0  # how far above the target's top the lip hovers
const HINT_BUDGET := 8000  # solver node limit for a hint
const POUR_BASE_TIME := 0.2  # stream time = base + per_unit * units; matches the pour sounds
const POUR_TIME_PER_UNIT := 0.15

var _level := 1
var _initial: Array = []
var _state: PuzzleState
var _tubes: Array[Tube] = []
var _selected := -1
var _won := false
var _busy := false  # true while a pour animation is playing; input is locked
var _extra_used := false
var _status_tween: Tween

# Tutorial state: "" (off) | "select" | "pour" (guided first move) | "tip" | "footer".
var _tut := ""
var _tut_move := Vector2i(-1, -1)  # first move of a solution: (from, to)
var _tut_after_pour := false
var _overlay: TutorialOverlay
var _footer: HBoxContainer
var _settings: SettingsPanel
var _bottom_reserve := 0.0  # board space kept free for the tutorial card sitting above the footer

var _board: Control
var _level_label: Label
var _moves_label: Label
var _status_label: Label
var _undo_btn: IconButton
var _restart_btn: IconButton
var _hint_btn: IconButton
var _tube_btn: IconButton
var _win_panel: Control
var _win_title: Label
var _win_detail: Label
var _next_btn: Button


func _ready() -> void:
	_level = GameState.current_level
	_build_ui()
	_initial = LevelGenerator.generate(_level)
	_reset_state()


# --- UI construction --------------------------------------------------------

func _build_ui() -> void:
	UiKit.make_background(self)

	var margin := SafeMargin.new()
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var back := UiKit.make_icon_button("back", "", false, Vector2(88, 88))
	back.pressed.connect(GameState.go_to_menu)
	header.add_child(back)
	_level_label = UiKit.make_label("", 44, Color.WHITE, Color(UiKit.NEON, 0.45))
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(_level_label)
	var settings_btn := UiKit.make_icon_button("gear", "", false, Vector2(88, 88))
	settings_btn.pressed.connect(_open_settings)
	header.add_child(settings_btn)
	_moves_label = UiKit.make_label("", 30, UiKit.LAVENDER)
	header.add_child(_moves_label)

	_board = Control.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.resized.connect(_layout_tubes)
	root.add_child(_board)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	root.add_child(footer)
	_footer = footer
	_undo_btn = _footer_button(footer, "undo", "Undo", _on_undo)
	_restart_btn = _footer_button(footer, "restart", "Restart", _on_restart)
	_hint_btn = _footer_button(footer, "hint", "Hint", _on_hint)
	_tube_btn = _footer_button(footer, "plus", "Add Tube", _on_add_tube)

	_status_label = UiKit.make_label("", 26, UiKit.LAVENDER)
	root.add_child(_status_label)

	_build_win_panel()


func _open_settings() -> void:
	if _settings != null and is_instance_valid(_settings):
		return
	_settings = SettingsPanel.new()
	add_child(_settings)  # last child, so it sits above everything else on screen


func _footer_button(parent: Control, kind: String, caption: String, handler: Callable) -> IconButton:
	var b := UiKit.make_icon_button(kind, caption)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(handler)
	parent.add_child(b)
	return b


func _build_win_panel() -> void:
	_win_panel = Control.new()
	_win_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_win_panel.visible = false
	add_child(_win_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_panel.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	panel.add_child(box)

	_win_title = UiKit.make_label("Level Complete!", 52, Color.WHITE, Color(UiKit.NEON, 0.5))
	_win_detail = UiKit.make_label("", 30, UiKit.LAVENDER)
	box.add_child(_win_title)
	box.add_child(_win_detail)

	_next_btn = UiKit.make_button("Next Level", 32, Vector2(0, 96), UiKit.ACCENT)
	_next_btn.pressed.connect(func() -> void: GameState.start_level(_level + 1))
	box.add_child(_next_btn)
	var menu := UiKit.make_button("Level Select", 30, Vector2(0, 88))
	menu.pressed.connect(GameState.go_to_menu)
	box.add_child(menu)


# --- State / rendering ------------------------------------------------------

func _reset_state() -> void:
	_state = PuzzleState.new(_initial, LevelGenerator.config_for(_level)["capacity"])
	_selected = -1
	_won = false
	_busy = false
	_extra_used = false
	_win_panel.visible = false
	_level_label.text = "Level %d" % _level
	_set_status(_default_status(), false)
	_rebuild_tubes()
	_maybe_start_tutorial()


func _default_status() -> String:
	if GameState.best_moves.has(_level):
		return "Best: %d moves" % GameState.best_moves[_level]
	return "Pour matching colours together"


func _rebuild_tubes() -> void:
	for t in _tubes:
		t.queue_free()
	_tubes.clear()
	_selected = -1
	for i in _state.tubes.size():
		var tube := Tube.new()
		tube.index = i
		tube.capacity = _state.capacity
		tube.tapped.connect(_on_tube_tapped)
		_board.add_child(tube)
		_tubes.append(tube)
	_layout_tubes()
	_refresh()


## Lays the tubes out in 1 or 2 rows, whichever gives bigger tubes for the space available, and
## shrinks everything uniformly when the board is short (small phones, landscape).
func _layout_tubes() -> void:
	if _tubes.is_empty() or _board.size.x <= 0.0 or _avail_height() <= 0.0:
		return
	var n := _tubes.size()
	var one := _plan_rows(n, 1)
	var two := _plan_rows(n, 2)
	# Keep the classic look (single row for few tubes, two rows otherwise) unless it is clearly worse.
	var plan := one if one["area"] * (1.15 if n <= 4 else 1.0) >= two["area"] * (1.0 if n <= 4 else 1.15) else two
	var rows: int = plan["rows"]
	var per_row: int = plan["per_row"]
	var w: float = plan["w"]
	var h: float = plan["h"]
	var gap: float = plan["gap"]
	var row_gap: float = plan["row_gap"]
	var total_h := rows * h + (rows - 1) * row_gap
	var reserve := Tube.LIFT + 30.0  # room above for a lifted tube and its badge
	var top := reserve + maxf(0.0, (_avail_height() - reserve - total_h) / 2.0)
	for i in n:
		var r := floori(float(i) / per_row)
		var c := i - r * per_row
		var in_row := mini(per_row, n - r * per_row)
		var row_w := in_row * w + (in_row - 1) * gap
		var x := (_board.size.x - row_w) / 2.0 + c * (w + gap)
		_tubes[i].set_base(Vector2(x, top + r * (h + row_gap)), Vector2(w, h))


## Board height the tubes may use: all of it, minus the tutorial card when one is showing.
func _avail_height() -> float:
	return _board.size.y - _bottom_reserve


func _process(_delta: float) -> void:
	# The card's height depends on its text, so follow it and re-lay out the tubes when it changes.
	# Never mid-pour: moving tubes would yank the animated one out of its path.
	if _busy:
		return
	var wanted := 0.0
	if _overlay != null and _tut != "":
		wanted = _overlay.card_height()
		if wanted > 0.0:
			wanted += 12.0  # breathing room between the tubes and the card
	if absf(wanted - _bottom_reserve) > 1.0:
		_bottom_reserve = wanted
		_layout_tubes()


func _plan_rows(n: int, rows: int) -> Dictionary:
	var per_row := ceili(float(n) / rows)
	var full_h := _state.capacity * LAYER_H + PAD_TOTAL
	var reserve := Tube.LIFT + 30.0
	var need_h := rows * full_h + (rows - 1) * ROW_GAP
	var s := clampf((_avail_height() - reserve) / need_h, MIN_LAYOUT_SCALE, 1.0)
	var gap := GAP * s
	var w := minf(TUBE_MAX_W * s, (_board.size.x - gap * (per_row - 1)) / per_row)
	w = maxf(w, 1.0)
	var h := _state.capacity * LAYER_H * s + PAD_TOTAL
	return {"rows": rows, "per_row": per_row, "w": w, "h": h, "gap": gap,
		"row_gap": ROW_GAP * s, "area": w * h}


func _refresh() -> void:
	for i in _tubes.size():
		_tubes[i].set_layers(_state.tubes[i])
	_moves_label.text = "Moves: %d" % _state.move_count()
	var locked := _won or _busy or _tutorial_locked()
	_undo_btn.disabled = locked or not _state.can_undo()
	_hint_btn.disabled = locked
	_tube_btn.disabled = locked or _extra_used
	_restart_btn.disabled = _busy or _tutorial_locked()


func _select(index: int, silent: bool = false) -> void:
	if _selected >= 0 and _selected < _tubes.size():
		_tubes[_selected].set_selected(false)
	_selected = index
	if index >= 0:
		_tubes[index].set_selected(true)
		if not silent:
			AudioManager.play("select")


func _clear_hint() -> void:
	for t in _tubes:
		if t.hinted:
			t.set_hinted(false)


## Shows a message under the buttons; transient ones revert to the default after a moment.
func _set_status(text: String, transient: bool = true) -> void:
	_status_label.text = text
	if _status_tween:
		_status_tween.kill()
	if transient:
		_status_tween = create_tween()
		_status_tween.tween_interval(2.5)
		_status_tween.tween_callback(func() -> void: _status_label.text = _default_status())


# --- Input handlers ---------------------------------------------------------

func _on_tube_tapped(index: int) -> void:
	if _won or _busy:
		return
	if _tutorial_blocks(index):
		_set_status("Tap the highlighted tube")
		return
	_handle_tube_tap(index)
	_tutorial_sync()


func _handle_tube_tap(index: int) -> void:
	_clear_hint()
	if _selected == -1:
		if not _state.is_empty(index):
			_select(index)
		return
	if _selected == index:
		_select(-1)
		return
	var from := _selected
	if _state.can_pour(from, index):
		_start_pour(from, index)
	elif not _state.is_empty(index):
		_select(index)  # switch selection
	else:
		_select(-1)


## Game logic applies the pour immediately; the tubes keep showing the old layers while the
## animation plays, then snap to the new state in _finish_pour.
func _start_pour(from: int, to: int) -> void:
	var src := _tubes[from]
	var dst := _tubes[to]
	var src_layers: Array = (_state.tubes[from] as Array).duplicate()
	var dst_layers: Array = (_state.tubes[to] as Array).duplicate()
	var color: int = src_layers[-1]
	var count := mini(PuzzleState.run_length(src_layers), _state.capacity - dst_layers.size())

	_state.pour(from, to)
	_busy = true
	if _tutorial_locked():
		_tut_after_pour = true
		_clear_tutorial_ui()
	_set_status(_default_status(), false)
	_select(-1)
	src.kill_tween()
	_refresh()
	src.set_layers(src_layers)
	dst.set_layers(dst_layers)

	# Tilt towards the target, pivoting on the lip, and hover just above its mouth.
	var right := dst.base_pos.x > src.base_pos.x
	src.pivot_offset = Vector2(src.size.x, 0.0) if right else Vector2.ZERO
	var lip := Vector2(
		dst.base_pos.x + dst.size.x * (0.3 if right else 0.7),
		dst.base_pos.y - POUR_HEIGHT)
	var angle := POUR_ANGLE if right else -POUR_ANGLE
	src.z_index = 10

	var tw := create_tween()
	tw.tween_property(src, "position", lip - src.pivot_offset, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(src, "rotation", angle, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		dst.start_stream(lip.x - dst.base_pos.x, lip.y - dst.base_pos.y, color)
		AudioManager.play(AudioManager.pour_sound_name(count)))
	tw.tween_method(func(p: float) -> void:
		src.drain = count * p
		dst.fill = count * p, 0.0, 1.0, POUR_BASE_TIME + POUR_TIME_PER_UNIT * count)
	tw.tween_callback(dst.stop_stream)
	tw.tween_property(src, "position", src.base_pos, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(src, "rotation", 0.0, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_finish_pour.bind(from, to))


func _finish_pour(from: int, to: int) -> void:
	for i in [from, to]:
		_tubes[i].reset_pour_visuals()
	_busy = false
	_refresh()
	if _state.is_solved():
		_on_win()
	else:
		_play_pour_result(to)
		if _tut_after_pour:
			_set_tut("tip")
	_tut_after_pour = false


## Rewarding sounds only for meaningful progress: a finished tube, or colours consolidating.
func _play_pour_result(to: int) -> void:
	var tube: Array = _state.tubes[to]
	var run := PuzzleState.run_length(tube)
	if tube.size() == _state.capacity and run == _state.capacity:
		AudioManager.play("tube_complete")
	elif run == tube.size() and tube.size() >= 2:
		AudioManager.play("progress")


func _on_restart() -> void:
	if _busy or _tutorial_locked():
		return
	AudioManager.play("restart")
	_reset_state()


func _on_undo() -> void:
	if _won or _busy or _tutorial_locked():
		return
	AudioManager.play("undo")
	_clear_hint()
	_select(-1)
	_state.undo()
	_refresh()


func _on_hint() -> void:
	if _won or _busy or _tutorial_locked():
		return
	_clear_hint()
	_select(-1)
	var solution: Variant = PuzzleSolver.solve(_state.tubes, _state.capacity, HINT_BUDGET)
	if solution == null or (solution as Array).is_empty():
		_set_status("No hint found - try Undo or Add Tube")
		return
	var move: Vector2i = solution[0]
	AudioManager.play("hint")
	_select(move.x, true)
	_tubes[move.y].set_hinted(true)
	_set_status("Pour the lifted tube into the glowing one")


func _on_add_tube() -> void:
	if _won or _busy or _extra_used or _tutorial_locked():
		return
	_extra_used = true
	AudioManager.play("add_tube")
	_clear_hint()
	_state.add_empty_tube()
	_rebuild_tubes()


func _on_win() -> void:
	_won = true
	_finish_tutorial_on_win()
	AudioManager.play("level_complete")
	GameState.complete_level(_level, _state.move_count())
	_refresh()
	var last := _level >= LevelGenerator.LEVEL_COUNT
	_win_title.text = "All levels complete!" if last else "Level Complete!"
	_win_detail.text = "Moves: %d   |   Best: %d" % [_state.move_count(), GameState.best_moves[_level]]
	_next_btn.visible = not last
	await get_tree().create_timer(0.4).timeout
	if is_inside_tree():
		_win_panel.visible = true


# --- Tutorial ---------------------------------------------------------------

func _tutorial_locked() -> bool:
	return _tut == "select" or _tut == "pour"


## During the guided first move only the highlighted tubes respond.
func _tutorial_blocks(index: int) -> bool:
	match _tut:
		"select":
			return index != _tut_move.x
		"pour":
			return index != _tut_move.x and index != _tut_move.y
	return false


func _maybe_start_tutorial() -> void:
	_clear_tutorial_ui()
	_tut_after_pour = false
	if _level == 1 and not Settings.tutorial_done:
		var solution: Variant = PuzzleSolver.solve(_state.tubes, _state.capacity, HINT_BUDGET)
		if solution != null and not (solution as Array).is_empty():
			_tut_move = solution[0]
			_set_tut("select")
	elif _level == 2 and Settings.tutorial_done and not Settings.buttons_tip_seen:
		_set_tut("footer")


## Keeps the guided step in line with the current selection (select -> pour -> back again).
func _tutorial_sync() -> void:
	if _busy or not _tutorial_locked():
		return
	_set_tut("pour" if _selected == _tut_move.x else "select")


func _set_tut(step: String) -> void:
	_tut = step
	_clear_hint()
	if _overlay == null:
		_overlay = TutorialOverlay.new()
		_overlay.footer = _footer
		_overlay.skipped.connect(_end_tutorial.bind(true))
		_overlay.dismissed.connect(_end_tutorial.bind(false))
		add_child(_overlay)
	match step:
		"select":
			_overlay.show_card("Tap a tube to pick it up", false, true)
			_overlay.point_at(_tubes[_tut_move.x])
		"pour":
			_overlay.show_card("Now tap the glowing tube to pour", false, true)
			_tubes[_tut_move.y].set_hinted(true)
			_overlay.point_at(_tubes[_tut_move.y])
		"tip":
			_overlay.show_card("Nice! Pour onto the same colour, or into an empty tube.", true, false)
			_overlay.clear_pointer()
		"footer":
			_overlay.show_card("Stuck? Undo a move, ask for a Hint, or add one extra tube.", true, false)
			_overlay.point_at(_hint_btn, Vector2(0.5, 0.12))
	_refresh()


func _clear_tutorial_ui() -> void:
	_tut = ""
	if _overlay != null:
		_overlay.hide_card()
		_overlay.clear_pointer()
	_clear_hint()


## `skip`: the player skipped everything; otherwise they dismissed the current tip.
func _end_tutorial(skip: bool) -> void:
	if skip:
		Settings.set_tutorial_done(true)
		Settings.set_buttons_tip_seen(true)
	elif _tut == "footer":
		Settings.set_buttons_tip_seen(true)
	else:
		Settings.set_tutorial_done(true)
	_clear_tutorial_ui()
	_select(-1, true)
	_refresh()


func _finish_tutorial_on_win() -> void:
	if _level == 1 and not Settings.tutorial_done:
		Settings.set_tutorial_done(true)
	elif _level == 2 and not Settings.buttons_tip_seen:
		Settings.set_buttons_tip_seen(true)
	_clear_tutorial_ui()
