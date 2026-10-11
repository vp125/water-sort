class_name UiKit
extends RefCounted
## Small factory helpers so screens built in code look consistent.

const ACCENT := Color("#6366f1")
const NEON := Color("#22d3ee")
const LAVENDER := Color("#b4aee8")  # muted secondary text

static var _bold: Font


## Bold UI font: first available system font, falling back to the engine default.
static func bold_font() -> Font:
	if _bold == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI", "SF Pro Display", "Roboto", "Helvetica Neue", "Arial"])
		f.font_weight = 700
		_bold = f
	return _bold


static func make_button(text: String, font_size: int = 30, min_size: Vector2 = Vector2(0, 88),
		fill: Color = Color(1, 1, 1, 0.10)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", bold_font())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	b.add_theme_stylebox_override("normal", _box(fill))
	b.add_theme_stylebox_override("hover", _box(fill.lightened(0.14)))
	b.add_theme_stylebox_override("pressed", _box(fill.darkened(0.15)))
	b.add_theme_stylebox_override("disabled", _box(Color(1, 1, 1, 0.04)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# Subtle press feedback: shrink slightly while held.
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func() -> void: _scale_to(b, 0.95))
	b.button_up.connect(func() -> void: _scale_to(b, 1.0))
	return b


## `glow` (alpha > 0) adds a soft neon halo behind the text.
static func make_label(text: String, font_size: int = 32, color: Color = Color.WHITE,
		glow: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", bold_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if glow.a > 0.0:
		l.add_theme_color_override("font_shadow_color", glow)
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func make_icon_button(kind: String, caption: String = "", boxed: bool = true,
		min_size: Vector2 = Vector2(0, 112)) -> IconButton:
	var b := IconButton.new()
	b.kind = kind
	b.caption = caption
	b.boxed = boxed
	b.custom_minimum_size = min_size
	return b


static func make_background(parent: Control) -> void:
	parent.add_child(FancyBackground.new())


static func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#141a4a", 0.96)
	s.set_border_width_all(2)
	s.border_color = Color(NEON, 0.35)
	s.set_corner_radius_all(32)
	s.set_content_margin_all(36)
	s.shadow_color = Color(NEON, 0.18)
	s.shadow_size = 30
	return s


static func _scale_to(node: Control, target: float) -> void:
	node.create_tween().tween_property(node, "scale", Vector2.ONE * target, 0.08)


static func _box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_border_width_all(2)
	s.border_color = Color(1, 1, 1, 0.16)
	s.set_corner_radius_all(22)
	return s
