extends Character
class_name Nonon


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [3]
	character_name = "Nonon Jakazure"
	path_name = "nonon"
	universe = CharacterConcept.Universe.KILL_LA_KILL
	description = "Nonon Jakazure, one of the Elite Four of Honnoji Academy's Student Council. Her Three-Star Goku uniform transforms into a gigantic LRAD capable of launching barrages of musical attacks."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
