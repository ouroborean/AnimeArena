extends Character
class_name Ganta


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [3]
	character_name = "Ganta Igarashi"
	path_name = "ganta"
	universe = CharacterConcept.Universe.DEADMAN_WONDERLAND
	description = "Ganta Igarashi, the Deadman known as Woodpecker. After being framed for the murder of his classmates, Ganta is taken to the prison known as Deadman Wonderland, where he finds himself at the heart of a literal bloodbath."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
