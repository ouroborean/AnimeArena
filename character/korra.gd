extends Character
class_name Korra


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset=false):

	character_colors = [0, 1, 2, 3]
	character_name = "Korra"
	path_name = "korra"
	universe = CharacterConcept.Universe.AVATAR
	description = "Korra, the successor to Avatar Aang. Korra is a willful Water Tribe woman who demonstrated a prodigious talent for bending from a young age. Her adaptability and Avatar talents make her an unpredictable and implacable opponent."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
