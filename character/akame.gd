extends Character
class_name Akame


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 2, 3]
	character_name = "Akame"
	path_name = "akame"
	universe = CharacterConcept.Universe.AKAME_GA_KILL
	description = "Akame, the most talented killer of the assassin group Night Raid. Raised from a young age by the corrupt Empire, a chance assignment saw Akame turning on the nation that raised her. Now, she wields the fearsome blade Murasame to free the oppressed people from the tyranny of the Prime Minister."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
