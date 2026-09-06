extends Character
class_name Shiro


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = []
	character_name = "Shiro"
	path_name = "shiro"
	universe = CharacterConcept.Universe.DEADMAN_WONDERLAND
	description = "Shiro is a childhood friend of Ganta Igarashi. Carefree, loyal and friendly, Shiro loves sweets and will do anything to protect Ganta from harm."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
