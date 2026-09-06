extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Frieren"
	character_colors = [2]
	universe = CharacterConcept.Universe.FRIEREN
	path_name = "frieren"
	description = "Frieren, Mage of the Hero's Party. After the defeat of the demon king and the death of Himmel the Hero, Frieren commits herself to getting to know humans a little more closely, despite her absurdly long lifespan and unusually strong powers."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)



func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
