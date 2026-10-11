class_name TutorialOverlay
extends Control
## Coach overlay: an instruction card above the footer plus an animated pointing hand.
## It never blocks taps outside the card, so the game underneath stays playable.
## The game decides *what* to say and point at; this class only presents it.

signal skipped
signal dismissed  # "Got it"

## Footer row of the game screen; the card sits just above it.
var footer: Control

var _card: PanelContainer
var _label: Label
var _got_it: Button
var _skip: Button
var _target: Control
var _target_anchor := Vector2(0.5, 0.45)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_card = PanelContainer.new()
	var style := UiKit.panel_style()
	style.set_content_margin_all(22)
	_card.add_theme_stylebox_override("panel", style)
	_card.custom_minimum_size = Vector2(640, 0)
	_card.visible = false
	add_child(_card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_card.add_child(row)

	_label = UiKit.make_label("", 28)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(380, 0)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buttons)
	_got_it = UiKit.make_button("Got it", 26, Vector2(140, 70), UiKit.ACCENT)
	_got_it.pressed.connect(func() -> void: dismissed.emit())
	buttons.add_child(_got_it)
	_skip = UiKit.make_button("Skip", 24, Vector2(140, 60))
	_skip.pressed.connect(func() -> void: skipped.emit())
	buttons.add_child(_skip)


func show_card(text: String, with_got_it: bool, with_skip: bool) -> void:
	var changed := _label.text != text
	_label.text = text
	_got_it.visible = with_got_it
	_skip.visible = with_skip
	_card.visible = true
	if changed:
		_card.modulate.a = 0.0
		create_tween().tween_property(_card, "modulate:a", 1.0, 0.25)


## Height of the card while it is showing (0 when hidden); the game keeps the tubes clear of it.
func card_height() -> float:
	return _card.size.y if _card.visible else 0.0


func hide_card() -> void:
	_card.visible = false
	_label.text = ""


func point_at(target: Control, anchor: Vector2 = Vector2(0.5, 0.45)) -> void:
	_target = target
	_target_anchor = anchor


func clear_pointer() -> void:
	_target = null
	queue_redraw()


func _process(_delta: float) -> void:
	if _card.visible and footer != null:
		var footer_top := footer.global_position.y - global_position.y
		_card.position = Vector2((size.x - _card.size.x) * 0.5, footer_top - 16.0 - _card.size.y)
	if _target != null:
		queue_redraw()


func _draw() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var world := _target.global_position + _target.size * _target_anchor
	var p := get_global_transform().affine_inverse() * world
	var t := Time.get_ticks_msec() / 1000.0

	# Tap ripple under the fingertip.
	var phase := fposmod(t * 1.1, 1.0)
	draw_arc(p, 16.0 + 40.0 * phase, 0.0, TAU, 40, Color(UiKit.NEON, 0.75 * (1.0 - phase)), 4.0, true)

	# Pointing hand that presses down and lifts off again.
	var press := 0.5 + 0.5 * sin(t * 4.5)
	var tip := p + Vector2(0, 10.0 + 14.0 * press)
	draw_set_transform(tip, -0.3, Vector2.ONE)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color.WHITE
	skin.set_border_width_all(3)
	skin.border_color = Color(0.1, 0.12, 0.35, 0.85)
	skin.set_corner_radius_all(13)
	draw_style_box(skin, Rect2(-24, 40, 48, 46))  # palm
	skin.set_corner_radius_all(12)
	draw_style_box(skin, Rect2(-12, 0, 24, 62))  # index finger
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
