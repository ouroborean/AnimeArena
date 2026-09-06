extends Character
class_name Noelle


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1]
	character_name = "Noelle Silva"
	path_name = "noelle"
	universe = CharacterConcept.Universe.BLACK_CLOVER
	description = "Noelle Silva is a noblewoman and junior Magic Knight of the Royal Knights. Though proud and reserved, Noelle is driven by kindness and a desire to prove herself to the world."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
