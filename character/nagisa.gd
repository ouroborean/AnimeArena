extends Character
class_name Nagisa


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1, 2]
	character_name = "Nagisa Shiota"
	path_name = "nagisa"
	universe = CharacterConcept.Universe.ASSASSINATION_CLASSROOM
	description = "Nagisa is a calm and somewhat reserved boy, with a sharp eye and a kind heart. Despite all this, after a chance meeting with Koro-sensei, he discovers that he has a natural talent for assassination. Thanks to: Fghop"
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
