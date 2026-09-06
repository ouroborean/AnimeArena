extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Sailor Saturn"
	character_colors = [2]
	path_name = "saturn"
	universe = CharacterConcept.Universe.SAILOR_MOON
	description = "Tomoe Hotaru, the girl known as Sailor Saturn. After being killed in a laboratory accident as a child, Hotaru's father makes a sinister bargain to restore her to life. Armed with the Silence Glaive, Sailor Saturn fights with the power of death itself."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "saturn_unlock" in player.unlocks
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
