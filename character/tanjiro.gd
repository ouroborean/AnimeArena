extends Character
class_name Tanjiro


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1]
	character_name = "Kamado Tanjiro"
	path_name = "tanjiro"
	universe = CharacterConcept.Universe.DEMON_SLAYER
	description = "A kind-hearted and determined young man, Tanjiro Kamado is a demon slayer in search of a cure for his sister's demon curse. His journey is filled with danger and difficulty as he battles demons and uncovers the secrets of his past."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
