extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Impmon"
	character_colors = [3]
	universe = CharacterConcept.Universe.DIGIMON
	path_name = "impmon"
	description = "Impmon, a small but vicious Rookie Digimon with a chip on its shoulder. Quick to anger and eager to prove itself, it hurls Badaboom fireballs at anyone who looks down on it - and when pushed to the brink, Warp Digivolves into the demon lord Beelzemon."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
		# Badaboom (skill 1, index 0) heals Impmon when it is countered. counter_response_trigger
		# must be wired from the character file (see character/alphamon.gd:22-26).
		moveset.base_abilities[0].counter_response_trigger = badaboom_counter_response

func badaboom_counter_response(target):
	# Fires from Character.countered() when Badaboom is countered. `self` is Impmon (the callback
	# is bound to the character); `target` (the counterer) is unused.
	if used_ability == null:
		return
	var context = QueryContext.from_game_state(self, battle)
	Character.resolve_healing(context, self, 15)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
