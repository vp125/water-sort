extends SceneTree
## Renders the app icon (1024x1024, opaque, square: iOS applies its own rounded mask).
##   godot --path . -s tools/make_icon.gd      (needs a window/GPU; not --headless)
## Output: assets/icons/app_icon_1024.png

const SIZE := 1024
const OUT := "res://assets/icons/app_icon_1024.png"


func _init() -> void:
	_render()


func _render() -> void:
	await process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(stage)
	# Loaded at runtime: when run via -s, autoloads (used by Tube) only exist after the first frame.
	stage.add_child(load("res://scripts/ui/fancy_background.gd").new())

	# Three tubes, the middle one taller and in front: purple / orange / yellow / ice blue.
	var layouts := [
		{"x": 150.0, "w": 210.0, "h": 640.0, "y": 250.0, "layers": [0, 3, 1, 2]},
		{"x": 407.0, "w": 210.0, "h": 700.0, "y": 190.0, "layers": [1, 2, 3, 0]},
		{"x": 664.0, "w": 210.0, "h": 640.0, "y": 250.0, "layers": [3, 0, 2, 1]},
	]
	for l in layouts:
		var tube: Control = load("res://scripts/ui/tube.gd").new()
		tube.capacity = 4
		stage.add_child(tube)
		tube.set_layers(l["layers"])
		tube.set_base(Vector2(l["x"], l["y"]), Vector2(l["w"], l["h"]))

	for _i in 6:
		await process_frame
	var image := vp.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)  # App Store icons must not have an alpha channel
	var err := image.save_png(OUT)
	print("saved %s (%dx%d) err=%d" % [OUT, image.get_width(), image.get_height(), err])
	quit(err)
