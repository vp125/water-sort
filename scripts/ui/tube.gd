class_name Tube
extends Control
## Glass test tube visual. Holds no game logic: the screen feeds it layers and listens for taps.
##
## Pour animation support: the game keeps the tube showing its *pre-pour* layers and animates
##  - `drain`: fractional units removed from the top (source tube)
##  - `fill`:  fractional units of `fill_color` added on top (target tube)
##  - a falling stream drawn into this tube (target tube)
##
## Liquid is drawn as one smooth gradient layer per contiguous colour run, with a softly
## moving surface that sloshes after a pour.

signal tapped(index: int)

const LIFT := 30.0
const PAD := 8.0  # space under the liquid
const TOP_PAD := 20.0  # space above a full tube (rim)
const RIM_H := 14.0
const STREAM_WIDTH := 12.0
const SURFACE_POINTS := 9
const GLOW_RINGS := 6
const IDLE_REDRAW_FPS := 20.0  # resting tubes only shimmer slightly; matches the background rate so they share frames
const CORNER_DETAIL := 4  # segments per rounded corner (engine default is 8)
const SELECT_COLOR := Color("#22d3ee")  # neon cyan
const HINT_COLOR := Color("#e879f9")  # neon magenta

var index := 0
var capacity := 4
var layers: Array = []
var selected := false
var hinted := false
var base_pos := Vector2.ZERO

var drain := 0.0:
	set(value):
		drain = value
		queue_redraw()
var fill := 0.0:
	set(value):
		fill = value
		queue_redraw()
var fill_color := 0

var _streaming := false
var _stream_x := 0.0
var _stream_top := 0.0
var _tween: Tween
var _time := 0.0
var _slosh := 0.0  # 1 right after a pour, decays to 0
var _glass := StyleBoxFlat.new()
var _rim := StyleBoxFlat.new()
var _glow_rings: Array[StyleBoxFlat] = []
var _cap := StyleBoxFlat.new()  # reused for the rounded bottom of the lowest liquid layer
var _shine := StyleBoxFlat.new()  # reused for the glossy streaks
var _redraw_clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_time = randf() * 10.0  # de-sync the surface waves between tubes
	_glass.bg_color = Color(0.75, 0.88, 1.0, 0.08)
	_glass.set_border_width_all(3)
	_glass.corner_radius_top_left = 4
	_glass.corner_radius_top_right = 4
	_rim.bg_color = Color("#cfd8e8", 0.5)
	_rim.set_border_width_all(2)
	_rim.border_color = Color(1, 1, 1, 0.9)
	_rim.set_corner_radius_all(7)
	_shine.set_corner_radius_all(4)
	for style in [_glass, _rim, _cap, _shine]:
		style.corner_detail = CORNER_DETAIL
	for _i in GLOW_RINGS:
		var ring := StyleBoxFlat.new()
		ring.bg_color = Color(0, 0, 0, 0)
		ring.set_border_width_all(3)
		ring.corner_detail = CORNER_DETAIL
		ring.anti_aliasing = false  # soft, low-alpha rings: edge smoothing is invisible and costs geometry
		_glow_rings.append(ring)
	_update_styles()


func _process(delta: float) -> void:
	_time += delta
	_slosh = maxf(0.0, _slosh - delta * 0.9)
	# Redraw every frame only while something is animating; a resting tube just shimmers gently.
	var busy := selected or hinted or _streaming or drain > 0.0 or fill > 0.0 or _slosh > 0.0
	_redraw_clock += delta
	if (busy or not layers.is_empty()) and (busy or _redraw_clock >= 1.0 / IDLE_REDRAW_FPS):
		_redraw_clock = 0.0
		queue_redraw()


func set_layers(p_layers: Array) -> void:
	layers = p_layers.duplicate()
	queue_redraw()


func set_base(pos: Vector2, p_size: Vector2) -> void:
	base_pos = pos
	size = p_size
	position = pos + Vector2(0, -LIFT if selected else 0.0)
	_update_styles()


func set_selected(value: bool) -> void:
	selected = value
	if value:
		hinted = false
	_update_styles()
	kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "position:y", base_pos.y - (LIFT if value else 0.0), 0.12)


func set_hinted(value: bool) -> void:
	hinted = value
	_update_styles()


func kill_tween() -> void:
	if _tween:
		_tween.kill()


## `x`/`top_y` are in this tube's local coordinates (where the stream leaves the pouring lip).
func start_stream(x: float, top_y: float, color: int) -> void:
	_stream_x = x
	_stream_top = top_y
	fill_color = color
	_streaming = true
	queue_redraw()


func stop_stream() -> void:
	_streaming = false
	queue_redraw()


## Return to the resting look after a pour animation (layers are set separately).
func reset_pour_visuals() -> void:
	kill_tween()
	drain = 0.0
	fill = 0.0
	_streaming = false
	rotation = 0.0
	z_index = 0
	position = base_pos
	_slosh = 1.0
	queue_redraw()


func _update_styles() -> void:
	_glass.corner_radius_bottom_left = int(size.x * 0.5)
	_glass.corner_radius_bottom_right = int(size.x * 0.5)
	for i in _glow_rings.size():
		var grow := (i + 1) * 3
		var ring := _glow_rings[i]
		ring.corner_radius_bottom_left = int(size.x * 0.5) + grow
		ring.corner_radius_bottom_right = int(size.x * 0.5) + grow
		ring.corner_radius_top_left = 4 + grow
		ring.corner_radius_top_right = 4 + grow
	queue_redraw()


## Border colour for the current state, plus the glow (colour, strength) drawn outside the glass.
## The glow is a stack of fading rings rather than a shadow so it never tints the inside of the tube.
func _apply_glow_style() -> Dictionary:
	var glow := {"color": SELECT_COLOR, "strength": 0.12}
	if selected:
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		_glass.border_color = SELECT_COLOR
		glow = {"color": SELECT_COLOR, "strength": 0.55 + 0.2 * pulse}
	elif hinted:
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		_glass.border_color = HINT_COLOR
		glow = {"color": HINT_COLOR, "strength": 0.5 + 0.2 * pulse}
	else:
		_glass.border_color = Color(0.85, 0.93, 1.0, 0.6)
	return glow


func _draw() -> void:
	var glow := _apply_glow_style()
	var body := Rect2(0, RIM_H * 0.5, size.x, size.y - RIM_H * 0.5)
	if selected or hinted:  # an idle tube's glow is too faint to be worth drawing
		for i in _glow_rings.size():
			var falloff := 1.0 - float(i) / _glow_rings.size()
			_glow_rings[i].border_color = Color(glow["color"], glow["strength"] * falloff * falloff)
			draw_style_box(_glow_rings[i], body.grow((i + 1) * 3.0))
	var layer_h := (size.y - TOP_PAD - PAD) / capacity
	var radius := size.x * 0.5
	draw_style_box(_glass, body)

	var runs := _liquid_runs()
	for r in runs.size():
		_draw_run(runs[r], layer_h, r == runs.size() - 1)
	_draw_bubbles(layer_h)
	if Settings.show_markers:
		_draw_markers(layer_h)

	# Inner shadow on the right, light bounce on the left.
	var inner_bottom := size.y - radius
	_draw_h_gradient(Rect2(size.x - 17, TOP_PAD, 14, inner_bottom - TOP_PAD),
		Color(0.02, 0.04, 0.2, 0.0), Color(0.02, 0.04, 0.2, 0.30))
	_draw_h_gradient(Rect2(3, TOP_PAD, 12, inner_bottom - TOP_PAD),
		Color(0.8, 0.9, 1.0, 0.12), Color(0.8, 0.9, 1.0, 0.0))

	_draw_highlights(radius)
	_draw_rim()

	if _streaming:
		var level := 0.0 if runs.is_empty() else float(runs[-1]["upper"])
		var surface := size.y - PAD - level * layer_h
		if surface > _stream_top:
			var c := Palette.color_of(fill_color)
			draw_rect(Rect2(_stream_x - STREAM_WIDTH * 0.5, _stream_top, STREAM_WIDTH, surface - _stream_top), c)
			draw_rect(Rect2(_stream_x - STREAM_WIDTH * 0.5 + 2, _stream_top, 3, surface - _stream_top),
				Color(1, 1, 1, 0.35))

	if selected:
		_draw_check_badge(Vector2(size.x * 0.5, -22.0))


## Contiguous same-colour units merged into runs: [{color, lower, upper}] in unit levels,
## with `drain` removed from the top and `fill` added on top.
func _liquid_runs() -> Array:
	var runs: Array = []
	var n := layers.size()
	var src_level := n - drain
	var i := 0
	while i < n:
		var j := i
		while j + 1 < n and layers[j + 1] == layers[i]:
			j += 1
		var upper := minf(j + 1.0, src_level)
		if upper > i:
			runs.append({"color": layers[i], "lower": float(i), "upper": upper})
		i = j + 1
	if fill > 0.0:
		if not runs.is_empty() and runs[-1]["color"] == fill_color and is_equal_approx(runs[-1]["upper"], n):
			runs[-1]["upper"] = n + fill
		else:
			runs.append({"color": fill_color, "lower": float(n), "upper": n + fill})
	return runs


func _wave_amplitude() -> float:
	var calm := 1.1
	var active := 2.2 if (drain > 0.0 or fill > 0.0) else 0.0
	return calm + active + _slosh * 4.5


func _draw_run(run: Dictionary, layer_h: float, is_top: bool) -> void:
	var base := Palette.color_of(run["color"])
	var top_c := base.lightened(0.20)
	var bot_c := base.darkened(0.18)
	var x0 := 5.0
	var x1 := size.x - 5.0
	var y_top := size.y - PAD - float(run["upper"]) * layer_h
	var y_bot := size.y - PAD - float(run["lower"]) * layer_h
	var radius := (x1 - x0) * 0.5
	var cap_top := size.y - PAD - radius  # where the rounded bottom begins
	var rounded := float(run["lower"]) <= 0.0
	var y_flat_bot := minf(y_bot, cap_top) if rounded else y_bot
	var span := maxf(y_bot - y_top, 1.0)

	# Rounded bottom cap, flat colour matching the gradient at that depth.
	if rounded:
		_cap.bg_color = top_c.lerp(bot_c, clampf((cap_top - y_top) / span, 0.0, 1.0))
		_cap.corner_radius_bottom_left = int(radius)
		_cap.corner_radius_bottom_right = int(radius)
		var cap_y := maxf(y_top, cap_top - 1.0)
		draw_style_box(_cap, Rect2(x0, cap_y, x1 - x0, y_bot - cap_y))

	# Gradient body whose top edge ripples gently (only the topmost layer moves).
	if y_flat_bot - y_top < 2.0:
		return  # sliver (e.g. nearly drained): nothing worth drawing, and it can't be triangulated
	var amp := minf(_wave_amplitude(), (y_flat_bot - y_top) * 0.4) if is_top else 0.0
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var edge := PackedVector2Array()
	for k in SURFACE_POINTS:
		var f := float(k) / (SURFACE_POINTS - 1)
		var x := lerpf(x0, x1, f)
		var y := y_top + sin(_time * 2.4 + f * 5.0 + index) * amp * sin(f * PI)
		pts.append(Vector2(x, y))
		edge.append(Vector2(x, y))
		cols.append(top_c)
	var end_c := top_c.lerp(bot_c, clampf((y_flat_bot - y_top) / span, 0.0, 1.0))
	pts.append(Vector2(x1, y_flat_bot))
	cols.append(end_c)
	pts.append(Vector2(x0, y_flat_bot))
	cols.append(end_c)
	draw_polygon(pts, cols)

	# Meniscus: soft light line along the surface where this colour meets air / the next colour.
	draw_polyline(edge, Color(1, 1, 1, 0.45), 2.5, false)


func _draw_bubbles(layer_h: float) -> void:
	var src_level := layers.size() - drain
	for i in layers.size():
		if i + 1.0 > src_level:
			continue
		for b in 2:
			var seed_v := float(index * 31 + i * 7 + b * 13)
			var fx := fposmod(sin(seed_v * 12.9898) * 43758.5453, 1.0)
			var fy := fposmod(sin(seed_v * 78.233) * 24634.6345, 1.0)
			var bob := sin(_time * 1.2 + seed_v) * 1.8
			var p := Vector2(5.0 + 8.0 + fx * (size.x - 26.0),
				size.y - PAD - i * layer_h - 12.0 - fy * (layer_h - 24.0) + bob)
			draw_circle(p, 2.2 + fx * 2.0, Color(1, 1, 1, 0.30))


## Colourblind symbols, one per unit that is (nearly) fully present in the tube.
func _draw_markers(layer_h: float) -> void:
	var n := layers.size()
	var src_level := n - drain
	var r := clampf(minf(size.x - 10.0, layer_h) * 0.2, 8.0, 14.0)
	for k in n + ceili(fill):
		var from_layers := k < n
		var top_level := src_level if from_layers else n + fill
		if top_level < k + 0.75:
			continue
		var color_id: int = layers[k] if from_layers else fill_color
		var centre := Vector2(size.x * 0.5, size.y - PAD - (k + 0.5) * layer_h)
		ColorMarker.draw(self, color_id, centre, r, Palette.color_of(color_id))


func _draw_highlights(radius: float) -> void:
	# Long glossy streak down the left side, with a small companion dot.
	_shine.bg_color = Color(1, 1, 1, 0.34)
	draw_style_box(_shine, Rect2(9, TOP_PAD + 6, 6, size.y * 0.46))
	_shine.bg_color = Color(1, 1, 1, 0.26)
	draw_style_box(_shine, Rect2(9, TOP_PAD + 6 + size.y * 0.46 + 8, 6, 9))
	# Curved reflection hugging the rounded bottom, plus a faint streak on the right.
	var centre := Vector2(size.x * 0.5, size.y - radius)
	draw_arc(centre, radius - 9.0, PI * 0.62, PI * 0.88, 10, Color(1, 1, 1, 0.34), 3.0, true)
	draw_line(Vector2(size.x - 9, TOP_PAD + 14), Vector2(size.x - 9, TOP_PAD + 14 + size.y * 0.16),
		Color(1, 1, 1, 0.18), 2.5, true)


## Silver-white reflective rim: base band plus left-to-right light falloff and a top sheen.
func _draw_rim() -> void:
	var rect := Rect2(-4, 0, size.x + 8, RIM_H)
	draw_style_box(_rim, rect)
	var mid := rect.position.x + rect.size.x * 0.4
	_draw_h_gradient(Rect2(rect.position.x + 2, 2, mid - rect.position.x - 2, RIM_H - 4),
		Color(1, 1, 1, 0.55), Color(0.82, 0.88, 0.98, 0.25))
	_draw_h_gradient(Rect2(mid, 2, rect.end.x - mid - 2, RIM_H - 4),
		Color(0.82, 0.88, 0.98, 0.25), Color(0.45, 0.52, 0.7, 0.45))
	draw_line(Vector2(2, 3), Vector2(size.x - 2, 3), Color(1, 1, 1, 0.8), 1.5, true)


func _draw_h_gradient(rect: Rect2, left: Color, right: Color) -> void:
	draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([left, right, right, left]))


func _draw_check_badge(c: Vector2) -> void:
	draw_circle(c, 20.0, Color(SELECT_COLOR, 0.25))
	draw_circle(c, 16.0, Color.WHITE)
	draw_circle(c, 13.5, SELECT_COLOR.darkened(0.25))
	draw_polyline(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-2, 5), c + Vector2(7, -5)]),
		Color.WHITE, 3.5, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(index)
		accept_event()
