extends Character
class_name Aang

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 1, 2, 3]
	character_name = "Aang"
	universe = CharacterConcept.Universe.AVATAR
	path_name = "aang"
	description = "Hailing from the Air Nomads, Aang is not just any Airbender—he's the last of his kind and the current Avatar. Gifted with the ability to master all four elements, Aang's playful demeanor belies a deep sense of responsibility and an attachment to his duty as the Avatar that will change the world."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
