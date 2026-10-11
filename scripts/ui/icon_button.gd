class_name IconButton
extends Control
## Rounded translucent button with a vector icon and optional caption, drawn entirely in code.
## `kind`: back | undo | restart | hint | plus | sound | music | marker | help | gear   (`muted` draws a slash through it)
## Feedback: brightens on hover, shrinks while held, and emits a soft ring on release.

signal pressed

var kind := "undo"
var caption := ""
var boxed := true

var muted := false:
	set(value):
		muted = value
		queue_redraw()

var disabled := false:
	set(value):
		disabled = value
		queue_redraw()

var _hover := false
var _down := false
var _pulse := 0.0:  # 0 = idle, 0..1 = ring expanding
	set(value):
		_pulse = value
		queue_redraw()
var _scale_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hover = false; _set_down(false))


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_set_down(event.pressed)
		if not event.pressed and Rect2(Vector2.ZERO, size).has_point(event.position):
			_play_pulse()
			pressed.emit()
		accept_event()


func _set_down(value: bool) -> void:
	_down = value
	if _scale_tween:
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2.ONE * (0.93 if value else 1.0), 0.08)
	queue_redraw()


func _play_pulse() -> void:
	_pulse = 0.001
	var tw := create_tween()
	tw.tween_property(self, "_pulse", 1.0, 0.35)
	tw.tween_callback(func() -> void: _pulse = 0.0)


func _draw() -> void:
	var col := Color(1, 1, 1, 0.4 if disabled else 1.0)
	var rect := Rect2(Vector2.ZERO, size)
	if boxed:
		var box := StyleBoxFlat.new()
		var a := 0.18 if _down else (0.13 if _hover and not disabled else 0.08)
		box.bg_color = Color(1, 1, 1, a)
		box.set_border_width_all(2)
		box.border_color = Color(UiKit.NEON, 0.45) if (_hover and not disabled) else Color(1, 1, 1, 0.16)
		box.set_corner_radius_all(22)
		if _hover and not disabled:
			box.shadow_color = Color(UiKit.NEON, 0.22)
			box.shadow_size = 10
		draw_style_box(box, rect)
	if _pulse > 0.0:
		var ring := StyleBoxFlat.new()
		ring.bg_color = Color(0, 0, 0, 0)
		ring.set_border_width_all(3)
		ring.border_color = Color(UiKit.NEON, 0.6 * (1.0 - _pulse))
		ring.set_corner_radius_all(22 + int(14 * _pulse))
		var grow := 14.0 * _pulse
		draw_style_box(ring, rect.grow(grow))
	var center := Vector2(size.x * 0.5, size.y * (0.4 if caption != "" else 0.5))
	_draw_icon(center, col)
	if muted:
		draw_line(center + Vector2(-17, -17), center + Vector2(17, 17), Color("#fb7185", col.a), 4.0, true)
	if caption != "":
		draw_string(UiKit.bold_font(), Vector2(0, size.y - 16.0), caption,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(UiKit.LAVENDER, col.a))


func _draw_icon(c: Vector2, col: Color) -> void:
	match kind:
		"back":
			draw_polyline(PackedVector2Array([c + Vector2(-2, -13), c + Vector2(-15, 0), c + Vector2(-2, 13)]), col, 4.0, true)
			draw_line(c + Vector2(-14, 0), c + Vector2(16, 0), col, 4.0, true)
		"undo":
			var a0 := -PI * 0.95
			draw_arc(c, 15.0, a0, PI * 0.3, 24, col, 4.0, true)
			_arrow_head(c + Vector2.from_angle(a0) * 15.0, Vector2(sin(a0), -cos(a0)), col)
		"restart":
			var a0 := -PI * 0.25
			var a1 := a0 + PI * 1.55
			draw_arc(c, 15.0, a0, a1, 28, col, 4.0, true)
			_arrow_head(c + Vector2.from_angle(a1) * 15.0, Vector2(-sin(a1), cos(a1)), col)
		"hint":
			var bulb := c + Vector2(0, -4)
			draw_circle(bulb, 12.0, Color(col.r, col.g, col.b, col.a * 0.25))
			draw_arc(bulb, 12.0, 0.0, TAU, 28, col, 3.5, true)
			draw_line(c + Vector2(-6, 13), c + Vector2(6, 13), col, 3.5, true)
			draw_line(c + Vector2(-4, 19), c + Vector2(4, 19), col, 3.5, true)
		"sound":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-15, -5), c + Vector2(-8, -5), c + Vector2(0, -13),
				c + Vector2(0, 13), c + Vector2(-8, 5), c + Vector2(-15, 5)]), col)
			if not muted:
				draw_arc(c + Vector2(2, 0), 8.0, -0.9, 0.9, 10, col, 3.0, true)
				draw_arc(c + Vector2(2, 0), 15.0, -0.9, 0.9, 12, col, 3.0, true)
		"music":
			draw_circle(c + Vector2(-6, 10), 6.5, col)
			draw_line(c + Vector2(0, 10), c + Vector2(0, -14), col, 3.5, true)
			draw_polyline(PackedVector2Array([c + Vector2(0, -14), c + Vector2(11, -8), c + Vector2(11, -1)]), col, 3.5, true)
		"gear":
			draw_arc(c, 8.5, 0.0, TAU, 24, col, 3.5, true)
			for k in 8:
				var dir := Vector2.from_angle(k * PI / 4.0)
				draw_line(c + dir * 12.5, c + dir * 18.0, col, 5.0, true)
			draw_arc(c, 13.0, 0.0, TAU, 28, col, 3.5, true)
		"help":
			draw_string(UiKit.bold_font(), Vector2(0, c.y + 15.0), "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, 44, col)
		"marker":
			var ink := Color(0, 0, 0)  # dark base -> ColorMarker draws white symbols
			ColorMarker.draw(self, 0, c + Vector2(-10, -8), 7.0, ink)
			ColorMarker.draw(self, 1, c + Vector2(11, -8), 7.0, ink)
			ColorMarker.draw(self, 4, c + Vector2(0, 11), 7.5, ink)
		"plus":
			draw_arc(c, 17.0, 0.0, TAU, 28, col, 3.5, true)
			draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), col, 4.0, true)
			draw_line(c + Vector2(0, -8), c + Vector2(0, 8), col, 4.0, true)


func _arrow_head(tip_base: Vector2, dir: Vector2, col: Color) -> void:
	var n := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([tip_base + dir * 10.0, tip_base + n * 8.0, tip_base - n * 8.0]), col)
