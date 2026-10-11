class_name LevelTile
extends Control
## One cell of the level grid, drawn in code.
##   locked   - dimmed, padlock icon, small level number underneath; not clickable
##   next     - the level to play now: bright, softly pulsing outline
##   open     - unlocked but not finished
##   done     - finished: green tint, big number, best move count

signal pressed

enum State { LOCKED, NEXT, OPEN, DONE }

const DONE_FILL := Color("#10b981", 0.33)
const NEXT_FILL := Color("#6366f1", 0.60)
const OPEN_FILL := Color(1, 1, 1, 0.11)
const LOCKED_FILL := Color(1, 1, 1, 0.045)
const DRAG_TOLERANCE := 18.0  # px a press may move and still count as a tap

var level := 1
var best_moves := 0
var state := State.LOCKED:
	set(value):
		state = value
		set_process(state == State.NEXT)
		queue_redraw()

var _hover := false
var _down := false
var _dragged := false
var _press_pos := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS  # PASS (not STOP) so the ScrollContainer still sees drags
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hover = false; _set_down(false))
	set_process(state == State.NEXT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if state == State.LOCKED:
		return
	# Not accepting the events lets the parent ScrollContainer see them, so the grid can be
	# scrolled by dragging on a tile. A press that moved is a scroll, not a tap.
	if event is InputEventMouseMotion and _down:
		if event.position.distance_to(_press_pos) > DRAG_TOLERANCE:
			_set_down(false)
			_dragged = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
			_dragged = false
			_set_down(true)
		else:
			var was_tap := _down and not _dragged and Rect2(Vector2.ZERO, size).has_point(event.position)
			_set_down(false)
			if was_tap:
				pressed.emit()


func _set_down(value: bool) -> void:
	_down = value
	scale = Vector2.ONE * (0.95 if value else 1.0)
	queue_redraw()


func _draw() -> void:
	var fill := OPEN_FILL
	match state:
		State.LOCKED: fill = LOCKED_FILL
		State.NEXT: fill = NEXT_FILL
		State.DONE: fill = DONE_FILL
	if _hover and state != State.LOCKED:
		fill = fill.lightened(0.14)
	if _down:
		fill = fill.darkened(0.15)

	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_border_width_all(2)
	box.border_color = Color(1, 1, 1, 0.10) if state == State.LOCKED else Color(1, 1, 1, 0.18)
	box.set_corner_radius_all(22)
	if state == State.NEXT:
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		box.border_color = Color(UiKit.NEON, 0.55 + 0.35 * pulse)
		box.set_border_width_all(3)
		box.shadow_color = Color(UiKit.NEON, 0.15 + 0.15 * pulse)
		box.shadow_size = 10
	draw_style_box(box, Rect2(Vector2.ZERO, size))

	var font := UiKit.bold_font()
	var cx := size.x * 0.5
	match state:
		State.LOCKED:
			_draw_padlock(Vector2(cx, size.y * 0.40), Color(1, 1, 1, 0.42))
			draw_string(font, Vector2(0, size.y - 14.0), str(level),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(UiKit.LAVENDER, 0.5))
		State.DONE:
			draw_string(font, Vector2(0, size.y * 0.5), str(level),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color.WHITE)
			draw_string(font, Vector2(0, size.y * 0.5 + 30.0), "%d mv" % best_moves,
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(UiKit.LAVENDER, 0.95))
		_:
			draw_string(font, Vector2(0, size.y * 0.5 + 12.0), str(level),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 38, Color.WHITE)


## Padlock centred on `c`: closed shackle above a rounded body with a keyhole.
func _draw_padlock(c: Vector2, col: Color) -> void:
	var shackle_c := c + Vector2(0, -6)
	draw_arc(shackle_c, 11.0, PI, TAU, 18, col, 4.5, true)
	draw_line(shackle_c + Vector2(-11, 0), shackle_c + Vector2(-11, 9), col, 4.5, true)
	draw_line(shackle_c + Vector2(11, 0), shackle_c + Vector2(11, 9), col, 4.5, true)
	var body := StyleBoxFlat.new()
	body.bg_color = col
	body.set_corner_radius_all(7)
	draw_style_box(body, Rect2(c + Vector2(-18, 0), Vector2(36, 28)))
	var hole := Color(0.07, 0.09, 0.25, 0.9)
	draw_circle(c + Vector2(0, 11), 4.2, hole)
	draw_line(c + Vector2(0, 12), c + Vector2(0, 19), hole, 3.6, true)
