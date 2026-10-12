extends SceneTree
## Renders store/itch.io artwork from the real game:
##   godot --path . -s tools/make_store_art.gd      (needs a window/GPU; not --headless)
## Output in assets/store/: cover_630x500.png, shot_*.png (720x1280 portrait screenshots)

const OUT_DIR := "res://assets/store/"
var _gs: Node


func _init() -> void:
	_render()


func _render() -> void:
	await process_frame
	_gs = root.get_node("GameState")
	root.get_node("AudioManager").sfx_enabled = false
	root.get_node("AudioManager").music_enabled = false
	var settings = root.get_node("Settings")
	settings.tutorial_done = true  # in memory only: keep the tutorial card out of the shots
	settings.buttons_tip_seen = true

	await _cover()
	await _shot("shot_1_level6", 6, true)
	await _shot("shot_2_level50", 50, true)
	await _shot("shot_3_level76_tall", 76, true)
	await _menu_shot("shot_4_levels")
	print("store art written to ", OUT_DIR)
	quit()


func _viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	return vp


func _save(vp: SubViewport, name: String) -> void:
	var image := vp.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png(OUT_DIR + name + ".png")
	print("saved ", name, " ", image.get_size())
	vp.queue_free()


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _shot(name: String, level: int, select_first: bool) -> void:
	var vp := _viewport(Vector2i(720, 1280))
	_gs.current_level = level
	var game: Node = load("res://scenes/game.tscn").instantiate()
	vp.add_child(game)
	await _frames(40)
	if select_first:
		game._select(0, true)
	await _frames(25)
	_save(vp, name)


func _menu_shot(name: String) -> void:
	var vp := _viewport(Vector2i(720, 1280))
	_gs.highest_unlocked = 18
	_gs.best_moves = {}
	for i in range(1, 18):
		_gs.best_moves[i] = 9 + (i * 7) % 14
	var menu: Node = load("res://scenes/level_select.tscn").instantiate()
	vp.add_child(menu)
	await _frames(40)
	_save(vp, name)


func _cover() -> void:
	var vp := _viewport(Vector2i(630, 500))
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(stage)
	stage.add_child(load("res://scripts/ui/fancy_background.gd").new())

	var tube_script := load("res://scripts/ui/tube.gd")
	var tubes := [
		{"x": 355.0, "y": 150.0, "w": 76.0, "h": 250.0, "layers": [0, 3, 1, 2]},
		{"x": 445.0, "y": 105.0, "w": 76.0, "h": 280.0, "layers": [1, 2, 3, 0]},
		{"x": 535.0, "y": 150.0, "w": 76.0, "h": 250.0, "layers": [3, 0, 2, 1]},
	]
	for t in tubes:
		var tube: Control = tube_script.new()
		tube.capacity = 4
		stage.add_child(tube)
		tube.set_layers(t["layers"])
		tube.set_base(Vector2(t["x"], t["y"]), Vector2(t["w"], t["h"]))

	var ui_kit = load("res://scripts/ui/ui_kit.gd")
	var title: Label = ui_kit.make_label("Water\nSort", 92, Color.WHITE, Color(0.133, 0.827, 0.933, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.position = Vector2(34, 92)
	title.size = Vector2(300, 220)
	stage.add_child(title)
	var sub: Label = ui_kit.make_label("100 relaxing puzzles", 26, ui_kit.LAVENDER)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub.position = Vector2(38, 368)
	sub.size = Vector2(320, 40)
	stage.add_child(sub)

	await _frames(30)
	_save(vp, "cover_630x500")
