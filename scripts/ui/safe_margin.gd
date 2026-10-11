class_name SafeMargin
extends MarginContainer
## Full-screen margin container for a screen's content. It keeps the content
##  - inside the device safe area (notch / home indicator), and
##  - no wider than `max_content_width`, centred, so tablets and landscape don't get absurdly
##    stretched buttons.

const BASE_MARGIN := 28
const MAX_CONTENT_WIDTH := 1000.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var ins := SafeArea.current(get_viewport())
	var view_w := get_viewport().get_visible_rect().size.x
	var extra := maxf(0.0, (view_w - ins.x - ins.z - MAX_CONTENT_WIDTH) * 0.5)
	add_theme_constant_override("margin_left", BASE_MARGIN + int(ins.x + extra))
	add_theme_constant_override("margin_right", BASE_MARGIN + int(ins.z + extra))
	add_theme_constant_override("margin_top", BASE_MARGIN + int(ins.y))
	add_theme_constant_override("margin_bottom", BASE_MARGIN + int(ins.w))
