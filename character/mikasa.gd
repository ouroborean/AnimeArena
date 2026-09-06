extends Character
class_name Mikasa


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [3]
	character_name = "Mikasa Ackerman"
	path_name = "mikasa"
	universe = CharacterConcept.Universe.ATTACK_ON_TITAN
	description = "Mikasa Ackerman, a symbol of resilience, strength, and unwavering loyalty, lived in a world plagued by the constant threat of Titans. Her life, marked by battles and the quest for survival, made her one of the most skilled fighters of her time."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
