extends Control
## Level grid. Locked levels are disabled; completed ones show their best move count.

const COLUMNS := 5


func _ready() -> void:
	UiKit.make_background(self)

	var margin := SafeMargin.new()
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	root.add_child(UiKit.make_label("Water Sort", 68, Color.WHITE, Color(UiKit.NEON, 0.5)))
	root.add_child(UiKit.make_label(
		"%d / %d completed" % [GameState.best_moves.size(), LevelGenerator.LEVEL_COUNT],
		28, UiKit.LAVENDER))

	var toggles := HBoxContainer.new()
	toggles.alignment = BoxContainer.ALIGNMENT_CENTER
	toggles.add_theme_constant_override("separation", 16)
	root.add_child(toggles)
	_add_toggle(toggles, "music", AudioManager.music_enabled, AudioManager.set_music_enabled)
	_add_toggle(toggles, "sound", AudioManager.sfx_enabled, AudioManager.set_sfx_enabled)
	_add_toggle(toggles, "marker", Settings.show_markers, Settings.set_show_markers)
	var help := UiKit.make_icon_button("help", "", true, Vector2(88, 88))
	help.pressed.connect(func() -> void:
		Settings.reset_tutorial()
		GameState.start_level(1))
	toggles.add_child(help)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)

	var next_tile: LevelTile = null
	for level in range(1, LevelGenerator.LEVEL_COUNT + 1):
		var tile := LevelTile.new()
		tile.level = level
		tile.custom_minimum_size = Vector2(0, 120)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not GameState.is_unlocked(level):
			tile.state = LevelTile.State.LOCKED
		elif GameState.best_moves.has(level):
			tile.state = LevelTile.State.DONE
			tile.best_moves = GameState.best_moves[level]
		elif level == GameState.highest_unlocked:
			tile.state = LevelTile.State.NEXT
			next_tile = tile
		else:
			tile.state = LevelTile.State.OPEN
		tile.pressed.connect(GameState.start_level.bind(level))
		grid.add_child(tile)

	# Open scrolled to the level you're up to (otherwise level 70 would start 14 rows down).
	if next_tile != null:
		await get_tree().process_frame
		scroll.scroll_vertical = maxi(0, int(next_tile.position.y) - 240)


## Square icon toggle; `setter` receives the new enabled state.
func _add_toggle(parent: Control, kind: String, enabled: bool, setter: Callable) -> void:
	var b := UiKit.make_icon_button(kind, "", true, Vector2(88, 88))
	b.muted = not enabled
	b.pressed.connect(func() -> void:
		b.muted = not b.muted
		setter.call(not b.muted)
		AudioManager.play("select"))
	parent.add_child(b)
