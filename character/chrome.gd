extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Chrome Dokuro"
	character_colors = [1]
	universe = CharacterConcept.Universe.KATEKYO_HITMAN_REBORN
	path_name = "chrome"
	description = "Chrome Dokuro, one of the Vongola Mist Guardians. Despite being physically frail, Chrome is the vessel for Rokudo Mukuro, one of the most powerful illusionists in the world. Through her connection to Mukuro, Chrome can create devastatingly real illusions."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
