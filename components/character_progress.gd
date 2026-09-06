class_name CharacterProgress
extends RefCounted

# Core data: { character_path_name: int (total XP) }
var xp_data: Dictionary = {}


func get_xp(character_path: String) -> int:
	if character_path in xp_data:
		return int(xp_data[character_path])
	return 0


func get_level(character_path: String) -> int:
	return MasteryConfig.xp_to_level(get_xp(character_path))


func get_progress_fraction(character_path: String) -> float:
	return MasteryConfig.level_progress_fraction(get_xp(character_path))


func get_xp_to_next_level(character_path: String) -> int:
	return MasteryConfig.xp_to_next_level(get_xp(character_path))


func award_xp(character_path: String, amount: int):
	var current = get_xp(character_path)
	xp_data[character_path] = current + amount


func deduct_xp(character_path: String, amount: int):
	var current = get_xp(character_path)
	xp_data[character_path] = max(current - amount, MasteryConfig.XP_FLOOR)


func to_dict() -> Dictionary:
	return xp_data.duplicate()


func from_dict(data: Dictionary):
	xp_data = data.duplicate()
