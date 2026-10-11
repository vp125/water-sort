extends Node
## Autoload: progress persistence and scene navigation.

const SAVE_PATH := "user://progress.cfg"
const GAME_SCENE := "res://scenes/game.tscn"
const MENU_SCENE := "res://scenes/level_select.tscn"

var current_level := 1
var highest_unlocked := 1
var best_moves: Dictionary = {}  # level (int) -> fewest moves (int)


func _ready() -> void:
	_load()


func is_unlocked(level: int) -> bool:
	return level <= highest_unlocked


func has_next_level() -> bool:
	return current_level < LevelGenerator.LEVEL_COUNT


func start_level(level: int) -> void:
	current_level = clampi(level, 1, LevelGenerator.LEVEL_COUNT)
	get_tree().change_scene_to_file(GAME_SCENE)


func go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func complete_level(level: int, moves: int) -> void:
	if not best_moves.has(level) or moves < best_moves[level]:
		best_moves[level] = moves
	if level == highest_unlocked and level < LevelGenerator.LEVEL_COUNT:
		highest_unlocked += 1
	_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "highest_unlocked", highest_unlocked)
	for level: int in best_moves:
		cfg.set_value("best_moves", str(level), best_moves[level])
	if cfg.save(SAVE_PATH) != OK:
		push_warning("Could not save progress to %s" % SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # first run
	highest_unlocked = clampi(
		cfg.get_value("progress", "highest_unlocked", 1), 1, LevelGenerator.LEVEL_COUNT)
	if cfg.has_section("best_moves"):
		for key in cfg.get_section_keys("best_moves"):
			best_moves[int(key)] = int(cfg.get_value("best_moves", key))
	# Levels added after a player finished the previous last level: unlock the next one.
	if best_moves.has(highest_unlocked) and highest_unlocked < LevelGenerator.LEVEL_COUNT:
		highest_unlocked += 1
