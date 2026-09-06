extends Character
class_name Kurapika


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset=false):

	character_colors = [0, 2, 3]
	character_name = "Kurapika"
	path_name = "kurapika"
	universe = CharacterConcept.Universe.HUNTER_X_HUNTER
	description = "Kurapika is a Blacklist Hunter on the hunt for the thieves that murdered his clan. Using a vast repertoire of knowledge and a thirst for vengeance, Kurapika is on the hunt for the Scarlet Eyes of his clan."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
