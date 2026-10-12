class_name FancyBackground
extends Control
## Deep navy gradient with large blurred colour glows and small floating, twinkling particles.
## Purely decorative.

const SKY_TOP := Color("#050a22")
const SKY_MID := Color("#0b1a4a")
const SKY_BOTTOM := Color("#1a1760")
const GLOW_COLORS: Array[Color] = [
	Color("#3b82f6"),  # blue
	Color("#8b5cf6"),  # purple
	Color("#22d3ee"),  # cyan
	Color("#e879f9"),  # magenta
]
const BLOB_COUNT := 9
const PARTICLE_COUNT := 34
const REDRAW_FPS := 20.0  # slow drifting lights look identical at 20 fps and cost a third of the frames

var _glow_tex: GradientTexture2D
var _blobs: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _time := 0.0
var _redraw_clock := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# One soft radial texture, reused (tinted) for every blurred light.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = grad
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 128
	_glow_tex.height = 128

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in BLOB_COUNT:
		_blobs.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"radius": rng.randf_range(110.0, 240.0),
			"alpha": rng.randf_range(0.16, 0.30),
			"color": GLOW_COLORS[i % GLOW_COLORS.size()],
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(0.08, 0.22),
		})
	for i in PARTICLE_COUNT:
		_particles.append({
			"x": rng.randf(),
			"y": rng.randf(),
			"radius": rng.randf_range(2.0, 6.0),
			"rise": rng.randf_range(0.004, 0.014),  # fraction of screen height per second
			"sway": rng.randf_range(6.0, 22.0),
			"phase": rng.randf() * TAU,
			"color": GLOW_COLORS[rng.randi() % GLOW_COLORS.size()].lerp(Color.WHITE, 0.35),
		})


func _process(delta: float) -> void:
	_time += delta
	_redraw_clock += delta
	if _redraw_clock >= 1.0 / REDRAW_FPS:
		_redraw_clock = 0.0
		queue_redraw()


func _draw() -> void:
	var half := size.y * 0.55
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, half), Vector2(0, half)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_MID, SKY_MID]))
	draw_polygon(
		PackedVector2Array([Vector2(0, half), Vector2(size.x, half), size, Vector2(0, size.y)]),
		PackedColorArray([SKY_MID, SKY_MID, SKY_BOTTOM, SKY_BOTTOM]))

	for blob in _blobs:
		var drift := Vector2(
			sin(_time * blob["speed"] + blob["phase"]),
			cos(_time * blob["speed"] * 0.8 + blob["phase"])) * 30.0
		var r: float = blob["radius"]
		var tint: Color = blob["color"]
		tint.a = blob["alpha"]
		draw_texture_rect(_glow_tex, Rect2(blob["pos"] * size + drift - Vector2(r, r), Vector2(r, r) * 2.0), false, tint)

	for p in _particles:
		var y := fposmod(p["y"] - _time * p["rise"], 1.0)
		var x: float = p["x"] * size.x + sin(_time * 0.5 + p["phase"]) * p["sway"]
		var twinkle := 0.55 + 0.45 * sin(_time * 1.6 + p["phase"] * 3.0)
		var c: Color = p["color"]
		var pos := Vector2(x, y * size.y)
		var r: float = p["radius"]
		draw_texture_rect(_glow_tex, Rect2(pos - Vector2(r, r) * 4.0, Vector2(r, r) * 8.0), false,
			Color(c.r, c.g, c.b, 0.28 * twinkle))
		draw_circle(pos, r * 0.5, Color(c.r, c.g, c.b, 0.85 * twinkle))
