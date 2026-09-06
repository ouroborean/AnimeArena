extends Character
class_name Maka


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [3]
	character_name = "Maka Albarn"
	path_name = "maka"
	universe = CharacterConcept.Universe.SOUL_EATER
	description = "Maka Albarn is a two-star meister at Death Weapon Meister Academy. The daughter of Death's weapon partner, she became a scythe-meister and partnered with the demon scythe, Soul Evans."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
