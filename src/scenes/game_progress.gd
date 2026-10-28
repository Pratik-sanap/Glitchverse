## game_progress.gd — Progression and persistence for Rift Runner.
## Role C owns this file.
class_name GameProgress
extends RefCounted

const SAVE_PATH: String = "user://rift_progress.json"

static var unlocked_level: int = 1
static var selected_level: int = 1
static var total_campaign_score: int = 0
static var level_scores: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
static var intro_shown: bool = false
static var touch_controls_mode: String = "auto" # "auto", "on", "off"


static func unlock_next_level(current_id: int, score: int = 0) -> void:
	level_scores[current_id] = maxi(int(level_scores.get(current_id, 0)), score)
	if current_id >= unlocked_level and unlocked_level < 4:
		unlocked_level = current_id + 1
	_recalc_total_score()
	save_progress()


static func _recalc_total_score() -> void:
	var total: int = 0
	for lvl in level_scores.keys():
		total += int(level_scores[lvl])
	total_campaign_score = total


static func is_unlocked(level_id: int) -> bool:
	return level_id <= unlocked_level


static func save_progress() -> void:
	var data: Dictionary = {
		"unlocked_level": unlocked_level,
		"level_scores": level_scores,
		"total_campaign_score": total_campaign_score,
		"touch_controls_mode": touch_controls_mode
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


static func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		unlocked_level = int(parsed.get("unlocked_level", 1))
		var scores: Variant = parsed.get("level_scores", {})
		if scores is Dictionary:
			for k in scores.keys():
				level_scores[int(k)] = int(scores[k])
		touch_controls_mode = str(parsed.get("touch_controls_mode", "auto"))
		_recalc_total_score()
