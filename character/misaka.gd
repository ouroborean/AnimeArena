extends Character
class_name Misaka


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1, 2]
	character_name = "Misaka Mikoto"
	path_name = "misaka"
	universe = CharacterConcept.Universe.A_CERTAIN_SCIENTIFIC_RAILGUN
	description = "Misaka Mikoto, the ace of Tokiwadai Middle School. Misaka is one of seven Level 5 espers in Academy City, the world's bastion of esper research. Her abilities as an electromaster have her ranked third among the city's top espers."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
