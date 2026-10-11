class_name SettingsPanel
extends Control
## In-game settings dialog: music, sound effects, colour symbols. Changes apply immediately
## (the audio buses are muted/unmuted on the spot, so a pour that is playing goes quiet too).
## Tapping outside the panel or "Done" closes it.

signal closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # taps beside the panel reach the dim layer
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 0)
	panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	panel.add_child(box)

	box.add_child(UiKit.make_label("Settings", 52, Color.WHITE, Color(UiKit.NEON, 0.5)))
	_add_row(box, "Music", AudioManager.music_enabled, AudioManager.set_music_enabled)
	_add_row(box, "Sound effects", AudioManager.sfx_enabled, AudioManager.set_sfx_enabled)
	_add_row(box, "Colour symbols", Settings.show_markers, Settings.set_show_markers)

	var done := UiKit.make_button("Done", 32, Vector2(0, 92), UiKit.ACCENT)
	done.pressed.connect(close)
	box.add_child(done)


func close() -> void:
	closed.emit()
	queue_free()


func _add_row(parent: Control, text: String, enabled: bool, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)

	var label := UiKit.make_label(text, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var toggle := ToggleSwitch.new()
	toggle.on = enabled
	toggle.toggled.connect(func(on: bool) -> void:
		setter.call(on)
		AudioManager.play("select"))  # audible confirmation; silent if sound was just turned off
	row.add_child(toggle)
