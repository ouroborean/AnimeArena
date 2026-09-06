extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Neferpitou"
	character_colors = [0, 3]
	path_name = "neferpitou"
	universe = CharacterConcept.Universe.HUNTER_X_HUNTER
	description = "Neferpitou, firstborn of the Chimera Ant King's three Royal Guards. Though easily distracted and eager for opportunities to play, Neferpitou places the King's goals far above their own safety or life."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "neferpitou_unlock" in player.unlocks
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
