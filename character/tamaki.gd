extends Character
class_name Tamaki


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1]
	character_name = "Tamaki Kotatsu"
	path_name = "tamaki"
	universe = CharacterConcept.Universe.FIRE_FORCE
	description = "Tamaki Kotatsu is a Third Generation pyrokinetic firefighter who fights alongside Company 8. She uses her Nekomata Ignition to manifest feline flames for enhanced combat agility. Despite struggling with a supernatural clumsiness called Lucky Lecher Lure, she remains fiercely dedicated to protecting her allies."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
