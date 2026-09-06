extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Muichiro Tokito"
	path_name = "muichiro"
	character_colors = [1, 2]
	universe = CharacterConcept.Universe.DEMON_SLAYER
	description = "The young Mist Hashira, Muichiro Tokito, is a remarkable prodigy in the Demon Slayer Corps, achieving his high rank with incredible speed. Initially, he appears detached and forgetful; a consequence of amnesia stemming from a past tragedy. In combat, he wields the Mist Breathing style with exceptional mastery."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
