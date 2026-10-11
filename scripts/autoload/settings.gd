extends Node
## Autoload: display/accessibility preferences and tutorial progress. Kept in its own file so it
## can never clobber the audio settings written by AudioManager.

const PATH := "user://display.cfg"

var show_markers := false  # colourblind symbols on every unit of liquid
var tutorial_done := false  # the guided first move on level 1
var buttons_tip_seen := false  # the Undo / Hint / Add Tube tip on level 2


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		show_markers = cfg.get_value("display", "show_markers", false)
		tutorial_done = cfg.get_value("tutorial", "done", false)
		buttons_tip_seen = cfg.get_value("tutorial", "buttons_tip_seen", false)
	# Players who already finished levels before the tutorial existed don't need it.
	if not cfg.has_section_key("tutorial", "done") and not GameState.best_moves.is_empty():
		tutorial_done = true
		buttons_tip_seen = true


func set_show_markers(value: bool) -> void:
	show_markers = value
	_save()


func set_tutorial_done(value: bool) -> void:
	tutorial_done = value
	_save()


func set_buttons_tip_seen(value: bool) -> void:
	buttons_tip_seen = value
	_save()


## Forget tutorial progress so it plays again from level 1.
func reset_tutorial() -> void:
	tutorial_done = false
	buttons_tip_seen = false
	_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "show_markers", show_markers)
	cfg.set_value("tutorial", "done", tutorial_done)
	cfg.set_value("tutorial", "buttons_tip_seen", buttons_tip_seen)
	if cfg.save(PATH) != OK:
		push_warning("Could not save display settings to %s" % PATH)
