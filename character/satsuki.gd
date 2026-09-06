extends Character
class_name Satsuki


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 1]
	character_name = "Satsuki Kiryuin"
	path_name = "satsuki"
	universe = CharacterConcept.Universe.KILL_LA_KILL
	description = "Satsuki Kiryuin, the president of Honnoji Academy's Student Council. A revered figure of absolute authority, Satsuki is a talented user of her inherited Kamui, a proud perfectionist who does not tolerate mistakes."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
