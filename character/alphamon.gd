extends Character
class_name Alphamon


func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)


func initialize(_moveset = false):
	character_colors = [0]
	character_name = "Alphamon"
	path_name = "alphamon"
	universe = CharacterConcept.Universe.DIGIMON
	description = "Alphamon, the leader of the 13 Royal Knights. The Aloof Hermit wields the Seiken Gradalpha to cleave through enemies of the digital world, and stands behind a wall of Digi-Force avoidance fields that turn aside even the strongest of attacks."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
		for i in range(4):
			moveset.base_abilities[i].counter_response_trigger = on_skill_countered


func on_skill_countered(target):
	# `used_ability` is set during action resolution and cleared at action end. Counter resolution
	# fires inside that window, so it should be populated here. Guard anyway: if engine flow ever
	# changes to clear it earlier, the refund silently no-ops instead of crashing.
	if used_ability == null:
		print("Alphamon: on_skill_countered fired with null used_ability — energy refund skipped.")
		return
	var context = QueryContext.from_game_state(self, battle)
	var costs = used_ability.cost()
	for element in costs:
		var amount = costs[element]
		for _i in range(amount):
			if element == Energy.Type.RANDOM:
				gain_random_energy()
			else:
				gain_bonus_energy(element)
	Character.resolve_healing(context, self, 15)


func is_unlocked(player):
	return true


func _process(delta):
	pass
