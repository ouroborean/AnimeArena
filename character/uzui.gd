extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Tengen Uzui"
	path_name = "uzui"
	universe = CharacterConcept.Universe.DEMON_SLAYER
	character_colors = [3]
	description = "Tengen Uzui, the Sound Hashira of the Demon Slayer Corps. A ninja by trade, Tengen is a versatile swordsman with exceptional hearing. Using his ninja training and Sound Breathing techniques, he can orchestrate miracles on the battlefield."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "uzui_unlock" in player.unlocks
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
