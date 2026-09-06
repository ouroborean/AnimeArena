extends Character
class_name zoro


# Called when the node enters the scene tree for the first time.
func _ready():
	pass

 
func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0]
	universe = CharacterConcept.Universe.ONE_PIECE
	character_name = "Roronoa Zoro"
	path_name = "zoro"
	description = "As a master of the Three Sword Style, which he created during his childhood, Zoro is one of the most powerful combatants of the Straw Hat pirate crew. His dream is to become the greatest swordsman in the world."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
