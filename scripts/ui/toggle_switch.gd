class_name ToggleSwitch
extends Control
## iOS-style on/off pill with a sliding knob, drawn in code.

signal toggled(on: bool)

var on := false:
	set(value):
		on = value
		_animate()

var _knob := 0.0  # 0 = off position, 1 = on position
var _hover := false
var _tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(116, 64)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_knob = 1.0 if on else 0.0
	mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hover = false; queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		on = not on
		toggled.emit(on)
		accept_event()


func _animate() -> void:
	if not is_inside_tree():
		_knob = 1.0 if on else 0.0
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void:
		_knob = v
		queue_redraw(), _knob, 1.0 if on else 0.0, 0.14)


func _draw() -> void:
	var h := size.y
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.14).lerp(Color(UiKit.NEON, 0.55), _knob)
	track.set_border_width_all(2)
	track.border_color = Color(1, 1, 1, 0.22).lerp(Color(UiKit.NEON, 0.9), _knob)
	track.set_corner_radius_all(int(h * 0.5))
	if _hover:
		track.bg_color = track.bg_color.lightened(0.12)
	draw_style_box(track, Rect2(Vector2.ZERO, size))
	var r := h * 0.5 - 7.0
	var x := lerpf(h * 0.5, size.x - h * 0.5, _knob)
	draw_circle(Vector2(x, h * 0.5 + 1.5), r, Color(0, 0, 0, 0.25))  # soft shadow
	draw_circle(Vector2(x, h * 0.5), r, Color.WHITE)
